import 'package:dio/dio.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/errors/exceptions.dart';
import '../../core/network/dio_client.dart';
import '../../domain/entities/stock_movement.dart';
import '../../domain/repositories/stock_repository.dart';

class StockRepositoryImpl implements StockRepository {
  final DioClient _dioClient;

  StockRepositoryImpl({required DioClient dioClient})
      : _dioClient = dioClient;

  @override
  Future<StockMovement> createStockMovement(
    String storeId,
    String productId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dioClient.post(
        ApiEndpoints.stockMovements(storeId, productId),
        data: data,
      );
      return _mapStockMovement(
        response.data['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
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
