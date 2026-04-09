import 'package:dio/dio.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/network/dio_client.dart';
import '../../../domain/entities/customer.dart';

abstract class CustomerRemoteDatasource {
  Future<({List<Customer> data, int total, int totalPages})> getCustomers(
    String storeId, {
    int page = 1,
    int limit = 20,
    String? search,
  });

  Future<Customer> getCustomer(String storeId, String id);
  Future<Customer> createCustomer(String storeId, Map<String, dynamic> data);
  Future<Customer> updateCustomer(
    String storeId,
    String id,
    Map<String, dynamic> data,
  );
  Future<void> deleteCustomer(String storeId, String id);
}

class CustomerRemoteDatasourceImpl implements CustomerRemoteDatasource {
  final DioClient _dioClient;

  CustomerRemoteDatasourceImpl({required DioClient dioClient})
      : _dioClient = dioClient;

  @override
  Future<({List<Customer> data, int total, int totalPages})> getCustomers(
    String storeId, {
    int page = 1,
    int limit = 20,
    String? search,
  }) async {
    try {
      final response = await _dioClient.get(
        ApiEndpoints.customers(storeId),
        queryParameters: {
          'page': page,
          'limit': limit,
          if (search != null && search.isNotEmpty) 'search': search,
        },
      );

      final responseData = response.data['data'] as Map<String, dynamic>;
      final list = responseData['items'] as List;

      return (
        data: list
            .map((json) => _mapCustomer(json as Map<String, dynamic>))
            .toList(),
        total: responseData['total'] as int? ?? 0,
        totalPages: responseData['totalPages'] as int? ?? 1,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<Customer> getCustomer(String storeId, String id) async {
    try {
      final response = await _dioClient.get(
        ApiEndpoints.customer(storeId, id),
      );
      return _mapCustomer(response.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<Customer> createCustomer(
    String storeId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dioClient.post(
        ApiEndpoints.customers(storeId),
        data: data,
      );
      return _mapCustomer(response.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<Customer> updateCustomer(
    String storeId,
    String id,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dioClient.put(
        ApiEndpoints.customer(storeId, id),
        data: data,
      );
      return _mapCustomer(response.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<void> deleteCustomer(String storeId, String id) async {
    try {
      await _dioClient.delete(ApiEndpoints.customer(storeId, id));
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Customer _mapCustomer(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] as String,
      storeId: json['storeId'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      birthday: json['birthday'] != null
          ? DateTime.parse(json['birthday'] as String)
          : null,
      notes: json['notes'] as String?,
      loyaltyPoints: (json['loyaltyPoints'] as num?)?.toInt() ?? 0,
      totalSpent: (json['totalSpent'] as num?)?.toDouble() ?? 0,
      debt: (json['debt'] as num?)?.toDouble() ?? 0,
      isActive: json['isActive'] as bool? ?? true,
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
