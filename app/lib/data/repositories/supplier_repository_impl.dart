import 'package:dio/dio.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/errors/exceptions.dart';
import '../../core/network/api_list_response.dart';
import '../../core/network/dio_client.dart';
import '../../core/network/network_info.dart';
import '../../domain/entities/supplier.dart';
import '../../domain/repositories/supplier_repository.dart';
import '../sync/sync_queue.dart';

class SupplierRepositoryImpl implements SupplierRepository {
  final DioClient _dioClient;
  final NetworkInfo _networkInfo;
  final SyncQueue _syncQueue;

  SupplierRepositoryImpl({
    required DioClient dioClient,
    required NetworkInfo networkInfo,
    required SyncQueue syncQueue,
  })  : _dioClient = dioClient,
        _networkInfo = networkInfo,
        _syncQueue = syncQueue;

  @override
  Future<({List<Supplier> data, int total, int totalPages})> getSuppliers(
    String storeId, {
    int page = 1,
    int limit = 20,
    String? search,
  }) async {
    try {
      final response = await _dioClient.get(
        ApiEndpoints.suppliers(storeId),
        queryParameters: {
          'page': page,
          'limit': limit,
          if (search != null && search.isNotEmpty) 'search': search,
        },
      );

      final decoded =
          ApiListResponse.decode<Supplier>(response.data, _mapSupplier);
      return (
        data: decoded.items,
        total: decoded.total,
        totalPages: decoded.totalPages,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<Supplier> getSupplier(String storeId, String id) async {
    try {
      final response = await _dioClient.get(
        ApiEndpoints.supplier(storeId, id),
      );
      final json = decodeApiObject(response.data);
      if (json == null) {
        throw ServerException('Unexpected empty supplier response');
      }
      return _mapSupplier(json);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<Supplier> createSupplier(
    String storeId,
    Map<String, dynamic> data,
  ) async {
    try {
      if (await _networkInfo.isConnected) {
        final response = await _dioClient.post(
          ApiEndpoints.suppliers(storeId),
          data: data,
        );
        final json = decodeApiObject(response.data);
        if (json == null) {
          throw ServerException('Unexpected empty supplier response');
        }
        return _mapSupplier(json);
      } else {
        final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
        await _syncQueue.enqueue(
          entityType: 'supplier',
          entityId: '$storeId:$tempId',
          operation: 'CREATE',
          payload: data,
        );
        return Supplier(
          id: tempId,
          storeId: storeId,
          name: data['name'] as String? ?? '',
          phone: data['phone'] as String?,
          email: data['email'] as String?,
          address: data['address'] as String?,
          notes: data['notes'] as String?,
        );
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<Supplier> updateSupplier(
    String storeId,
    String id,
    Map<String, dynamic> data,
  ) async {
    try {
      if (await _networkInfo.isConnected) {
        final response = await _dioClient.put(
          ApiEndpoints.supplier(storeId, id),
          data: data,
        );
        final json = decodeApiObject(response.data);
        if (json == null) {
          throw ServerException('Unexpected empty supplier response');
        }
        return _mapSupplier(json);
      } else {
        await _syncQueue.enqueue(
          entityType: 'supplier',
          entityId: '$storeId:$id',
          operation: 'UPDATE',
          payload: data,
        );
        // Re-fetch will fail offline; throw so callers know the update is queued
        throw const NetworkException();
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<void> deleteSupplier(String storeId, String id) async {
    try {
      if (await _networkInfo.isConnected) {
        await _dioClient.delete(ApiEndpoints.supplier(storeId, id));
      } else {
        await _syncQueue.enqueue(
          entityType: 'supplier',
          entityId: '$storeId:$id',
          operation: 'DELETE',
        );
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Supplier _mapSupplier(Map<String, dynamic> json) {
    return Supplier(
      id: json['id'] as String,
      storeId: json['storeId'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      address: json['address'] as String?,
      notes: json['notes'] as String?,
      debt: (json['debt'] as num?)?.toDouble() ?? 0,
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
