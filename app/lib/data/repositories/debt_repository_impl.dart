// app/lib/data/repositories/debt_repository_impl.dart
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/errors/exceptions.dart';
import '../../core/network/dio_client.dart';
import '../../core/network/network_info.dart';
import '../../domain/repositories/debt_repository.dart';
import '../sync/sync_queue.dart';

/// Spec B E.3: offline-aware writes for both customer and supplier
/// debt payments. Online → POST. Offline → enqueue. Server-side
/// idempotency on (saleId|storeId, localId) makes replay safe.
class DebtRepositoryImpl implements DebtRepository {
  final DioClient _dioClient;
  final NetworkInfo _networkInfo;
  final SyncQueue _syncQueue;

  DebtRepositoryImpl({
    required DioClient dioClient,
    required NetworkInfo networkInfo,
    required SyncQueue syncQueue,
  })  : _dioClient = dioClient,
        _networkInfo = networkInfo,
        _syncQueue = syncQueue;

  @override
  Future<void> addCustomerPayment(
    String storeId,
    String customerId,
    Map<String, dynamic> data,
  ) async {
    final payload = Map<String, dynamic>.from(data);
    payload['localId'] ??= const Uuid().v4();

    try {
      if (await _networkInfo.isConnected) {
        await _dioClient.post(
          ApiEndpoints.customerPayments(storeId, customerId),
          data: payload,
        );
        return;
      }
    } on NetworkException {
      // Fall through to offline path.
    } on DioException catch (e) {
      throw _handleDioError(e);
    }

    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    await _syncQueue.enqueue(
      entityType: 'debt_payment',
      entityId: '$storeId:$customerId:$tempId',
      operation: 'CREATE',
      payload: payload,
    );
  }

  @override
  Future<void> addSupplierPayment(
    String storeId,
    String supplierId,
    Map<String, dynamic> data,
  ) async {
    final payload = Map<String, dynamic>.from(data);
    payload['localId'] ??= const Uuid().v4();

    try {
      if (await _networkInfo.isConnected) {
        await _dioClient.post(
          ApiEndpoints.supplierPayments(storeId, supplierId),
          data: payload,
        );
        return;
      }
    } on NetworkException {
      // Fall through to offline path.
    } on DioException catch (e) {
      throw _handleDioError(e);
    }

    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    await _syncQueue.enqueue(
      entityType: 'supplier_debt_payment',
      entityId: '$storeId:$supplierId:$tempId',
      operation: 'CREATE',
      payload: payload,
    );
  }

  Exception _handleDioError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.connectionError) {
      return const NetworkException('Нет соединения');
    }
    final status = e.response?.statusCode ?? 0;
    if (status == 401) return const UnauthorizedException();
    if (status >= 500) return const ServerException('Ошибка сервера');
    return ServerException(
      e.response?.data?['message']?.toString() ?? 'Не удалось выполнить операцию',
    );
  }
}
