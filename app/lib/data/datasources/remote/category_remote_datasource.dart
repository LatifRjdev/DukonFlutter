import 'package:dio/dio.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/network/dio_client.dart';
import '../../../domain/entities/category.dart';

abstract class CategoryRemoteDatasource {
  Future<List<Category>> getCategories(String storeId);
  Future<Category> createCategory(String storeId, Map<String, dynamic> data);
  Future<Category> updateCategory(
    String storeId,
    String id,
    Map<String, dynamic> data,
  );
  Future<void> deleteCategory(String storeId, String id);
}

class CategoryRemoteDatasourceImpl implements CategoryRemoteDatasource {
  final DioClient _dioClient;

  CategoryRemoteDatasourceImpl({required DioClient dioClient})
      : _dioClient = dioClient;

  @override
  Future<List<Category>> getCategories(String storeId) async {
    try {
      final response = await _dioClient.get(
        ApiEndpoints.categories(storeId),
      );
      final list = response.data['data'] as List;
      return list
          .map((json) => _mapCategory(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<Category> createCategory(
    String storeId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dioClient.post(
        ApiEndpoints.categories(storeId),
        data: data,
      );
      return _mapCategory(response.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<Category> updateCategory(
    String storeId,
    String id,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dioClient.put(
        ApiEndpoints.category(storeId, id),
        data: data,
      );
      return _mapCategory(response.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<void> deleteCategory(String storeId, String id) async {
    try {
      await _dioClient.delete(ApiEndpoints.category(storeId, id));
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Category _mapCategory(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String,
      storeId: json['storeId'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String?,
      color: json['color'] as String?,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      parentId: json['parentId'] as String?,
      productCount: (json['productCount'] as num?)?.toInt() ??
          (json['_count'] is Map
              ? ((json['_count'] as Map)['products'] as num?)?.toInt() ?? 0
              : 0),
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
