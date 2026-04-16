import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/network/dio_client.dart';
import '../../../domain/entities/product.dart';

abstract class ProductRemoteDatasource {
  Future<({List<Product> data, int total, int totalPages})> getProducts(
    String storeId, {
    int page = 1,
    int limit = 20,
    String? search,
    String? categoryId,
    bool? inStock,
    bool? lowStock,
    String? sortBy,
    String? sortOrder,
  });

  Future<Product> getProduct(String storeId, String id);
  Future<Product> getProductByBarcode(String storeId, String barcode);
  Future<Product> createProduct(String storeId, Map<String, dynamic> data);
  Future<Product> updateProduct(
    String storeId,
    String id,
    Map<String, dynamic> data,
  );
  Future<void> deleteProduct(String storeId, String id);
  Future<String> downloadTemplatePath(String storeId);
  Future<Map<String, dynamic>> importPreview(String storeId, String filePath);
  Future<Map<String, dynamic>> importProducts(String storeId, String filePath);
}

class ProductRemoteDatasourceImpl implements ProductRemoteDatasource {
  final DioClient _dioClient;

  ProductRemoteDatasourceImpl({required DioClient dioClient})
      : _dioClient = dioClient;

  @override
  Future<({List<Product> data, int total, int totalPages})> getProducts(
    String storeId, {
    int page = 1,
    int limit = 20,
    String? search,
    String? categoryId,
    bool? inStock,
    bool? lowStock,
    String? sortBy,
    String? sortOrder,
  }) async {
    try {
      final response = await _dioClient.get(
        ApiEndpoints.products(storeId),
        queryParameters: {
          'page': page,
          'limit': limit,
          if (search != null && search.isNotEmpty) 'search': search,
          if (categoryId != null) 'categoryId': categoryId,
          if (inStock != null) 'inStock': inStock,
          if (lowStock != null) 'lowStock': lowStock,
          if (sortBy != null) 'sortBy': sortBy,
          if (sortOrder != null) 'sortOrder': sortOrder,
        },
      );

      final responseData = response.data as Map<String, dynamic>;
      final list = responseData['data'] as List;

      return (
        data: list
            .map((json) => _mapProduct(json as Map<String, dynamic>))
            .toList(),
        total: responseData['total'] as int? ?? 0,
        totalPages: responseData['totalPages'] as int? ?? 1,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<Product> getProduct(String storeId, String id) async {
    try {
      final response = await _dioClient.get(
        ApiEndpoints.product(storeId, id),
      );
      return _mapProduct(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<Product> getProductByBarcode(String storeId, String barcode) async {
    try {
      final response = await _dioClient.get(
        ApiEndpoints.productByBarcode(storeId, barcode),
      );
      return _mapProduct(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<Product> createProduct(
    String storeId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dioClient.post(
        ApiEndpoints.products(storeId),
        data: data,
      );
      return _mapProduct(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<Product> updateProduct(
    String storeId,
    String id,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dioClient.put(
        ApiEndpoints.product(storeId, id),
        data: data,
      );
      return _mapProduct(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<void> deleteProduct(String storeId, String id) async {
    try {
      await _dioClient.delete(ApiEndpoints.product(storeId, id));
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<String> downloadTemplatePath(String storeId) async {
    try {
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/dukon-import-template.xlsx';
      await _dioClient.dio.download(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.productImportTemplate(storeId)}',
        filePath,
      );
      return filePath;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<Map<String, dynamic>> importPreview(
    String storeId,
    String filePath,
  ) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath),
      });
      final response = await _dioClient.post(
        ApiEndpoints.productImportPreview(storeId),
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<Map<String, dynamic>> importProducts(
    String storeId,
    String filePath,
  ) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath),
      });
      final response = await _dioClient.post(
        ApiEndpoints.productImport(storeId),
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Product _mapProduct(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      storeId: json['storeId'] as String,
      categoryId: json['categoryId'] as String?,
      categoryName: json['categoryName'] as String? ??
          (json['category'] is Map
              ? (json['category'] as Map<String, dynamic>)['name'] as String?
              : null),
      supplierId: json['supplierId'] as String?,
      name: json['name'] as String,
      sku: json['sku'] as String?,
      barcode: json['barcode'] as String?,
      description: json['description'] as String?,
      costPrice: (json['costPrice'] as num?)?.toDouble(),
      sellPrice: (json['sellPrice'] as num).toDouble(),
      wholesalePrice: (json['wholesalePrice'] as num?)?.toDouble(),
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      minQuantity: (json['minQuantity'] as num?)?.toInt() ?? 0,
      unit: json['unit'] as String? ?? 'PCS',
      imageUrl: json['imageUrl'] as String?,
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
