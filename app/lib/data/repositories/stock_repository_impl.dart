import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/errors/exceptions.dart';
import '../../core/network/dio_client.dart';
import '../../core/network/network_info.dart';
import '../../domain/entities/stock_movement.dart';
import '../../domain/repositories/stock_repository.dart';
import '../sync/sync_queue.dart';

/// Spec B E.2: offline-aware. Online → POST. Offline → enqueue with
/// client-generated `localId` so the server returns the existing row
/// on retry instead of double-counting stock.
class StockRepositoryImpl implements StockRepository {
  final DioClient _dioClient;
  final NetworkInfo _networkInfo;
  final SyncQueue _syncQueue;

  StockRepositoryImpl({
    required DioClient dioClient,
    required NetworkInfo networkInfo,
    required SyncQueue syncQueue,
  })  : _dioClient = dioClient,
        _networkInfo = networkInfo,
        _syncQueue = syncQueue;

  @override
  Future<StockMovement> createStockMovement(
    String storeId,
    String productId,
    Map<String, dynamic> data,
  ) async {
    final payload = Map<String, dynamic>.from(data);
    payload['localId'] ??= const Uuid().v4();

    try {
      if (await _networkInfo.isConnected) {
        final response = await _dioClient.post(
          ApiEndpoints.stockMovements(storeId, productId),
          data: payload,
        );
        return _mapStockMovement(
          response.data['data'] as Map<String, dynamic>,
        );
      }
    } on NetworkException {
      // Fall through to offline path.
    } on DioException catch (e) {
      throw _handleDioError(e);
    }

    // Offline: enqueue + return temp StockMovement so UI updates.
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final tempMovement = StockMovement(
      id: tempId,
      productId: productId,
      type: data['type'] as String? ?? 'PURCHASE',
      quantity: (data['quantity'] as num?)?.toInt() ?? 0,
      unitCost: (data['unitCost'] as num?)?.toDouble(),
      totalCost: (data['totalCost'] as num?)?.toDouble(),
      supplierId: data['supplierId'] as String?,
      reference: data['reference'] as String?,
      notes: data['notes'] as String?,
      createdAt: DateTime.now(),
    );

    await _syncQueue.enqueue(
      entityType: 'stock_movement',
      entityId: '$storeId:$productId:$tempId',
      operation: 'CREATE',
      payload: payload,
    );

    return tempMovement;
  }

  @override
  Future<({List<StockMovement> data, int total, int totalPages})>
      getStockMovements(
    String storeId,
    String productId, {
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _dioClient.get(
        ApiEndpoints.stockMovements(storeId, productId),
        queryParameters: {
          'page': page,
          'limit': limit,
        },
      );

      final responseData = response.data['data'] as Map<String, dynamic>;
      final list = responseData['items'] as List;

      return (
        data: list
            .map(
                (json) => _mapStockMovement(json as Map<String, dynamic>))
            .toList(),
        total: responseData['total'] as int? ?? 0,
        totalPages: responseData['totalPages'] as int? ?? 1,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  StockMovement _mapStockMovement(Map<String, dynamic> json) {
    return StockMovement(
      id: json['id'] as String,
      productId: json['productId'] as String,
      type: json['type'] as String,
      quantity: (json['quantity'] as num).toInt(),
      unitCost: (json['unitCost'] as num?)?.toDouble(),
      totalCost: (json['totalCost'] as num?)?.toDouble(),
      supplierId: json['supplierId'] as String?,
      reference: json['reference'] as String?,
      notes: json['notes'] as String?,
      createdBy: json['createdBy'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Exception _handleDioError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.connectionError) {
      return const NetworkException();
    }

    final statusCode = e.response?.statusCode;
    final message =
        (e.response?.data is Map)
            ? (e.response?.data['message'] as String? ?? e.message ?? 'Unknown error')
            : (e.message ?? 'Unknown error');

    if (statusCode == 401) {
      return UnauthorizedException(message);
    }

    return ServerException(message, statusCode: statusCode);
  }
}
