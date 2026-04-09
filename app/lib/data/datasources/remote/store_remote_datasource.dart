import 'package:dio/dio.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/network/dio_client.dart';
import '../../../domain/entities/store.dart';

abstract class StoreRemoteDatasource {
  Future<Store> createStore({
    required String name,
    required String category,
    String currency,
    String? address,
    String? phone,
  });

  Future<List<Store>> getStores();
  Future<Store> getStore(String id);
  Future<Store> updateStore(String id, Map<String, dynamic> data);
  Future<void> deleteStore(String id);
}

class StoreRemoteDatasourceImpl implements StoreRemoteDatasource {
  final DioClient _dioClient;

  StoreRemoteDatasourceImpl({required DioClient dioClient})
      : _dioClient = dioClient;

  @override
  Future<Store> createStore({
    required String name,
    required String category,
    String currency = 'TJS',
    String? address,
    String? phone,
  }) async {
    try {
      final response = await _dioClient.post(
        ApiEndpoints.stores,
        data: {
          'name': name,
          'category': category,
          'currency': currency,
          if (address != null) 'address': address,
          if (phone != null) 'phone': phone,
        },
      );

      return _mapStore(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<List<Store>> getStores() async {
    try {
      final response = await _dioClient.get(ApiEndpoints.stores);
      final list = response.data as List;
      return list
          .map((json) => _mapStore(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<Store> getStore(String id) async {
    try {
      final response = await _dioClient.get(ApiEndpoints.store(id));
      return _mapStore(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<Store> updateStore(String id, Map<String, dynamic> data) async {
    try {
      final response = await _dioClient.put(
        ApiEndpoints.store(id),
        data: data,
      );
      return _mapStore(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<void> deleteStore(String id) async {
    try {
      await _dioClient.delete(ApiEndpoints.store(id));
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Store _mapStore(Map<String, dynamic> json) {
    return Store(
      id: json['id'] as String,
      ownerId: json['ownerId'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      currency: json['currency'] as String? ?? 'TJS',
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      logoUrl: json['logoUrl'] as String?,
      settings: (json['settings'] as Map<String, dynamic>?) ?? {},
      isActive: json['isActive'] as bool? ?? true,
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
    final rawMessage = (e.response?.data is Map) ? e.response?.data['message'] : null;
    final String message;
    if (rawMessage is List) {
      message = rawMessage.join(', ');
    } else if (rawMessage is String) {
      message = rawMessage;
    } else {
      message = e.message ?? 'Unknown error';
    }

    if (statusCode == 401) {
      return UnauthorizedException(message);
    }

    return ServerException(message, statusCode: statusCode);
  }
}
