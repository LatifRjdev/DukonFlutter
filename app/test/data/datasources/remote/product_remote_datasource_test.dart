import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dukonpro/core/errors/exceptions.dart';
import 'package:dukonpro/core/network/dio_client.dart';
import 'package:dukonpro/data/datasources/remote/product_remote_datasource.dart';

class _MockDioClient extends Mock implements DioClient {}

void main() {
  late _MockDioClient dio;
  late ProductRemoteDatasourceImpl ds;

  setUpAll(() {
    registerFallbackValue(Options());
  });

  setUp(() {
    dio = _MockDioClient();
    ds = ProductRemoteDatasourceImpl(dioClient: dio);
  });

  Response<dynamic> resp(dynamic body, {int statusCode = 200}) => Response(
        requestOptions: RequestOptions(path: ''),
        statusCode: statusCode,
        data: body,
      );

  Map<String, dynamic> validProductJson({
    String id = 'p1',
    String storeId = 'store-1',
    String? categoryId,
    String? categoryName,
    Map<String, dynamic>? category,
    String? sku,
    String? barcode,
    num? costPrice,
    num sellPrice = 10,
    num? wholesalePrice,
    num? quantity,
    num? minQuantity,
    String? unit,
    bool? isActive,
    String createdAt = '2026-05-01T00:00:00.000Z',
  }) =>
      {
        'id': id,
        'storeId': storeId,
        'categoryId': categoryId,
        if (categoryName != null) 'categoryName': categoryName,
        if (category != null) 'category': category,
        'name': 'Apple',
        'sku': sku,
        'barcode': barcode,
        'description': null,
        'costPrice': costPrice,
        'sellPrice': sellPrice,
        'wholesalePrice': wholesalePrice,
        if (quantity != null) 'quantity': quantity,
        if (minQuantity != null) 'minQuantity': minQuantity,
        if (unit != null) 'unit': unit,
        'imageUrl': null,
        if (isActive != null) 'isActive': isActive,
        'createdAt': createdAt,
      };

  group('getProducts', () {
    test('sends page/limit/search and omits null optional filters from the query',
        () async {
      when(() => dio.get<dynamic>(any(),
              queryParameters: captureAny(named: 'queryParameters')))
          .thenAnswer((_) async => resp({
                'data': [validProductJson()],
                'total': 1,
                'totalPages': 1,
              }));

      await ds.getProducts('store-1', page: 2, limit: 10, search: 'apple');

      final captured = verify(() => dio.get<dynamic>(any(),
              queryParameters: captureAny(named: 'queryParameters')))
          .captured
          .single as Map<String, dynamic>;
      expect(captured['page'], 2);
      expect(captured['limit'], 10);
      expect(captured['search'], 'apple');
      expect(captured.containsKey('categoryId'), isFalse);
      expect(captured.containsKey('inStock'), isFalse);
      expect(captured.containsKey('lowStock'), isFalse);
      expect(captured.containsKey('sortBy'), isFalse);
      expect(captured.containsKey('sortOrder'), isFalse);
    });

    test('omits search from the query when it is an empty string', () async {
      when(() => dio.get<dynamic>(any(),
              queryParameters: captureAny(named: 'queryParameters')))
          .thenAnswer((_) async => resp({'data': [], 'total': 0, 'totalPages': 0}));

      await ds.getProducts('store-1', search: '');

      final captured = verify(() => dio.get<dynamic>(any(),
              queryParameters: captureAny(named: 'queryParameters')))
          .captured
          .single as Map<String, dynamic>;
      expect(captured.containsKey('search'), isFalse);
    });

    test('includes categoryId/inStock/lowStock/sortBy/sortOrder when provided',
        () async {
      when(() => dio.get<dynamic>(any(),
              queryParameters: captureAny(named: 'queryParameters')))
          .thenAnswer((_) async => resp({'data': [], 'total': 0, 'totalPages': 0}));

      await ds.getProducts(
        'store-1',
        categoryId: 'cat-1',
        inStock: true,
        lowStock: false,
        sortBy: 'name',
        sortOrder: 'asc',
      );

      final captured = verify(() => dio.get<dynamic>(any(),
              queryParameters: captureAny(named: 'queryParameters')))
          .captured
          .single as Map<String, dynamic>;
      expect(captured['categoryId'], 'cat-1');
      expect(captured['inStock'], true);
      expect(captured['lowStock'], false);
      expect(captured['sortBy'], 'name');
      expect(captured['sortOrder'], 'asc');
    });

    test('maps the data list to Product entities and reads total/totalPages',
        () async {
      when(() => dio.get<dynamic>(any(),
              queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => resp({
                'data': [
                  validProductJson(id: 'p1'),
                  validProductJson(id: 'p2'),
                ],
                'total': 2,
                'totalPages': 1,
              }));

      final result = await ds.getProducts('store-1');

      expect(result.data.map((p) => p.id), ['p1', 'p2']);
      expect(result.total, 2);
      expect(result.totalPages, 1);
    });

    test('defaults total to 0 and totalPages to 1 when absent from the response',
        () async {
      when(() => dio.get<dynamic>(any(),
              queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => resp({'data': []}));

      final result = await ds.getProducts('store-1');

      expect(result.total, 0);
      expect(result.totalPages, 1);
    });
  });

  group('_mapProduct JSON parsing edge cases (via getProduct)', () {
    Future<dynamic> load(Map<String, dynamic> json) async {
      when(() => dio.get<dynamic>(any())).thenAnswer((_) async => resp(json));
      return ds.getProduct('store-1', json['id'] as String);
    }

    test('reads categoryName from a flat field when present', () async {
      final product =
          await load(validProductJson(categoryName: 'Fruits'));
      expect(product.categoryName, 'Fruits');
    });

    test('falls back to nested category.name when categoryName is absent',
        () async {
      final product = await load(
          validProductJson(category: {'id': 'c1', 'name': 'Fruits'}));
      expect(product.categoryName, 'Fruits');
    });

    test('categoryName is null when neither flat field nor nested category is present',
        () async {
      final product = await load(validProductJson());
      expect(product.categoryName, isNull);
    });

    test('quantity/minQuantity accept numeric (double) JSON values and truncate to int',
        () async {
      final product =
          await load(validProductJson(quantity: 5.0, minQuantity: 2.0));
      expect(product.quantity, 5);
      expect(product.minQuantity, 2);
    });

    test('quantity/minQuantity default to 0 when absent', () async {
      final product = await load(validProductJson());
      expect(product.quantity, 0);
      expect(product.minQuantity, 0);
    });

    test('unit defaults to PCS when absent', () async {
      final product = await load(validProductJson());
      expect(product.unit, 'PCS');
    });

    test('isActive defaults to true when absent', () async {
      final product = await load(validProductJson());
      expect(product.isActive, isTrue);
    });

    test('costPrice/wholesalePrice are null when absent from JSON', () async {
      final product = await load(validProductJson());
      expect(product.costPrice, isNull);
      expect(product.wholesalePrice, isNull);
    });

    test('sellPrice accepts an int JSON value and converts to double', () async {
      final product = await load(validProductJson(sellPrice: 15));
      expect(product.sellPrice, 15.0);
      expect(product.sellPrice, isA<double>());
    });

    test('createdAt parses the ISO-8601 string from the backend', () async {
      final product = await load(
          validProductJson(createdAt: '2026-03-15T12:30:00.000Z'));
      expect(product.createdAt, DateTime.parse('2026-03-15T12:30:00.000Z'));
    });
  });

  group('getProduct / getProductByBarcode', () {
    test('getProduct requests the single-product endpoint and maps the result',
        () async {
      when(() => dio.get<dynamic>(any()))
          .thenAnswer((_) async => resp(validProductJson(id: 'p1')));

      final product = await ds.getProduct('store-1', 'p1');

      expect(product.id, 'p1');
      verify(() => dio.get<dynamic>('/stores/store-1/products/p1')).called(1);
    });

    test('getProductByBarcode requests the barcode endpoint and maps the result',
        () async {
      when(() => dio.get<dynamic>(any())).thenAnswer(
          (_) async => resp(validProductJson(id: 'p1', barcode: '12345')));

      final product = await ds.getProductByBarcode('store-1', '12345');

      expect(product.barcode, '12345');
      verify(() => dio
          .get<dynamic>('/stores/store-1/products/barcode/12345')).called(1);
    });
  });

  group('createProduct / updateProduct / deleteProduct', () {
    test('createProduct posts to the products endpoint and returns the mapped product',
        () async {
      when(() => dio.post<dynamic>(any(), data: any(named: 'data')))
          .thenAnswer((_) async => resp(validProductJson(id: 'new-id')));

      final product =
          await ds.createProduct('store-1', {'name': 'Apple', 'sellPrice': 10});

      expect(product.id, 'new-id');
      final captured = verify(() => dio.post<dynamic>(
            '/stores/store-1/products',
            data: captureAny(named: 'data'),
          )).captured.single as Map<String, dynamic>;
      expect(captured['name'], 'Apple');
    });

    test('updateProduct puts to the product endpoint and returns the mapped product',
        () async {
      when(() => dio.put<dynamic>(any(), data: any(named: 'data')))
          .thenAnswer((_) async => resp(validProductJson(id: 'p1')));

      final product =
          await ds.updateProduct('store-1', 'p1', {'name': 'New name'});

      expect(product.id, 'p1');
      verify(() => dio.put<dynamic>(
            '/stores/store-1/products/p1',
            data: {'name': 'New name'},
          )).called(1);
    });

    test('deleteProduct calls delete on the product endpoint', () async {
      when(() => dio.delete<dynamic>(any())).thenAnswer((_) async => resp(null));

      await ds.deleteProduct('store-1', 'p1');

      verify(() => dio.delete<dynamic>('/stores/store-1/products/p1')).called(1);
    });
  });

  group('Dio error mapping', () {
    test('connection timeout maps to NetworkException', () async {
      when(() => dio.get<dynamic>(any())).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.connectionTimeout,
      ));

      expect(
        () => ds.getProduct('store-1', 'p1'),
        throwsA(isA<NetworkException>()),
      );
    });

    test('connection error maps to NetworkException', () async {
      when(() => dio.get<dynamic>(any())).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.connectionError,
      ));

      expect(
        () => ds.getProduct('store-1', 'p1'),
        throwsA(isA<NetworkException>()),
      );
    });

    test('401 response maps to UnauthorizedException with server message',
        () async {
      when(() => dio.get<dynamic>(any())).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 401,
          data: {'message': 'Token expired'},
        ),
      ));

      expect(
        () => ds.getProduct('store-1', 'p1'),
        throwsA(isA<UnauthorizedException>().having(
            (e) => e.message, 'message', 'Token expired')),
      );
    });

    test('a list-typed message body is joined with ", "', () async {
      when(() => dio.get<dynamic>(any())).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 400,
          data: {
            'message': ['name is required', 'sellPrice must be positive']
          },
        ),
      ));

      expect(
        () => ds.getProduct('store-1', 'p1'),
        throwsA(isA<ServerException>().having(
          (e) => e.message,
          'message',
          'name is required, sellPrice must be positive',
        )),
      );
    });

    test('a non-Map response body falls back to the Dio-level message',
        () async {
      when(() => dio.get<dynamic>(any())).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.badResponse,
        message: 'raw dio failure',
        response: Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 500,
          data: 'plain text error body',
        ),
      ));

      expect(
        () => ds.getProduct('store-1', 'p1'),
        throwsA(isA<ServerException>().having(
            (e) => e.message, 'message', 'raw dio failure')),
      );
    });

    test('a 500 with no message and no Dio message falls back to "Unknown error"',
        () async {
      when(() => dio.get<dynamic>(any())).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 500,
          data: <String, dynamic>{},
        ),
      ));

      expect(
        () => ds.getProduct('store-1', 'p1'),
        throwsA(isA<ServerException>()
            .having((e) => e.message, 'message', 'Unknown error')
            .having((e) => e.statusCode, 'statusCode', 500)),
      );
    });
  });
}
