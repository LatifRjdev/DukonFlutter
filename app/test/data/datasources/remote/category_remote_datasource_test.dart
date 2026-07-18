import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dukonpro/core/errors/exceptions.dart';
import 'package:dukonpro/core/network/dio_client.dart';
import 'package:dukonpro/data/datasources/remote/category_remote_datasource.dart';

class _MockDioClient extends Mock implements DioClient {}

void main() {
  late _MockDioClient dio;
  late CategoryRemoteDatasourceImpl ds;

  setUp(() {
    dio = _MockDioClient();
    ds = CategoryRemoteDatasourceImpl(dioClient: dio);
  });

  Response<dynamic> resp(dynamic body, {int statusCode = 200}) => Response(
        requestOptions: RequestOptions(path: ''),
        statusCode: statusCode,
        data: body,
      );

  Map<String, dynamic> categoryJson({
    String id = 'cat-1',
    String storeId = 'store-1',
    String name = 'Drinks',
    String? icon,
    String? color,
    num? sortOrder,
    String? parentId,
    dynamic productCount,
    dynamic count,
  }) {
    final json = <String, dynamic>{
      'id': id,
      'storeId': storeId,
      'name': name,
      'icon': icon,
      'color': color,
      'sortOrder': sortOrder,
      'parentId': parentId,
    };
    if (productCount != null) json['productCount'] = productCount;
    if (count != null) json['_count'] = count;
    return json;
  }

  group('CategoryRemoteDatasourceImpl.getCategories', () {
    test('maps a well-formed list response', () async {
      when(() => dio.get<dynamic>(any())).thenAnswer(
        (_) async => resp({
          'data': [
            categoryJson(id: 'c1', name: 'Drinks', sortOrder: 1),
            categoryJson(id: 'c2', name: 'Snacks', sortOrder: 2),
          ],
        }),
      );

      final result = await ds.getCategories('store-1');

      expect(result.length, 2);
      expect(result[0].id, 'c1');
      expect(result[0].name, 'Drinks');
      expect(result[1].id, 'c2');
    });

    test('returns an empty list when data is empty', () async {
      when(() => dio.get<dynamic>(any())).thenAnswer(
        (_) async => resp({'data': []}),
      );

      final result = await ds.getCategories('store-1');

      expect(result, isEmpty);
    });

    test('defaults sortOrder to 0 and productCount to 0 when both are absent',
        () async {
      when(() => dio.get<dynamic>(any())).thenAnswer(
        (_) async => resp({
          'data': [categoryJson(id: 'c1')],
        }),
      );

      final result = await ds.getCategories('store-1');

      expect(result.single.sortOrder, 0);
      expect(result.single.productCount, 0);
    });

    test('reads productCount from top-level productCount field when present',
        () async {
      when(() => dio.get<dynamic>(any())).thenAnswer(
        (_) async => resp({
          'data': [categoryJson(id: 'c1', productCount: 7)],
        }),
      );

      final result = await ds.getCategories('store-1');

      expect(result.single.productCount, 7);
    });

    test('falls back to _count.products when productCount is absent',
        () async {
      when(() => dio.get<dynamic>(any())).thenAnswer(
        (_) async => resp({
          'data': [
            categoryJson(id: 'c1', count: {'products': 4}),
          ],
        }),
      );

      final result = await ds.getCategories('store-1');

      expect(result.single.productCount, 4);
    });

    test('maps nullable icon, color and parentId to null when absent',
        () async {
      when(() => dio.get<dynamic>(any())).thenAnswer(
        (_) async => resp({
          'data': [categoryJson(id: 'c1')],
        }),
      );

      final result = await ds.getCategories('store-1');

      expect(result.single.icon, isNull);
      expect(result.single.color, isNull);
      expect(result.single.parentId, isNull);
    });

    test('throws NetworkException on connection timeout', () async {
      when(() => dio.get<dynamic>(any())).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ''),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      expect(
        () => ds.getCategories('store-1'),
        throwsA(isA<NetworkException>()),
      );
    });

    test('throws UnauthorizedException on 401', () async {
      when(() => dio.get<dynamic>(any())).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ''),
          response: resp({'message': 'Unauthorized'}, statusCode: 401),
          type: DioExceptionType.badResponse,
        ),
      );

      expect(
        () => ds.getCategories('store-1'),
        throwsA(isA<UnauthorizedException>()),
      );
    });

    test('throws ServerException with statusCode and joined message on 400 with list message',
        () async {
      when(() => dio.get<dynamic>(any())).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ''),
          response: resp({
            'message': ['name is required', 'storeId is required'],
          }, statusCode: 400),
          type: DioExceptionType.badResponse,
        ),
      );

      try {
        await ds.getCategories('store-1');
        fail('expected ServerException');
      } on ServerException catch (e) {
        expect(e.statusCode, 400);
        expect(e.message, 'name is required, storeId is required');
      }
    });
  });

  group('CategoryRemoteDatasourceImpl.createCategory', () {
    test('posts data and maps the created category', () async {
      when(() => dio.post<dynamic>(any(), data: any(named: 'data')))
          .thenAnswer((_) async => resp({
                'data': categoryJson(id: 'new-c', name: 'New Category'),
              }));

      final result = await ds.createCategory('store-1', {'name': 'New Category'});

      expect(result.id, 'new-c');
      expect(result.name, 'New Category');

      final captured = verify(() => dio.post<dynamic>(
            any(),
            data: captureAny(named: 'data'),
          )).captured;
      final sentData = captured.single as Map<String, dynamic>;
      expect(sentData['name'], 'New Category');
    });

    test('throws ServerException on 500', () async {
      when(() => dio.post<dynamic>(any(), data: any(named: 'data'))).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ''),
          response: resp('Internal error', statusCode: 500),
          type: DioExceptionType.badResponse,
        ),
      );

      expect(
        () => ds.createCategory('store-1', {'name': 'x'}),
        throwsA(isA<ServerException>()),
      );
    });
  });

  group('CategoryRemoteDatasourceImpl.updateCategory', () {
    test('puts data and maps the updated category', () async {
      when(() => dio.put<dynamic>(any(), data: any(named: 'data')))
          .thenAnswer((_) async => resp({
                'data': categoryJson(id: 'c1', name: 'Renamed'),
              }));

      final result = await ds.updateCategory('store-1', 'c1', {'name': 'Renamed'});

      expect(result.name, 'Renamed');
    });

    test('throws NetworkException on send timeout', () async {
      when(() => dio.put<dynamic>(any(), data: any(named: 'data'))).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ''),
          type: DioExceptionType.sendTimeout,
        ),
      );

      expect(
        () => ds.updateCategory('store-1', 'c1', {'name': 'x'}),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  group('CategoryRemoteDatasourceImpl.deleteCategory', () {
    test('sends a delete request', () async {
      when(() => dio.delete<dynamic>(any())).thenAnswer(
        (_) async => resp(null),
      );

      await ds.deleteCategory('store-1', 'c1');

      verify(() => dio.delete<dynamic>(any())).called(1);
    });

    test('throws ServerException with fallback message when response has no message field',
        () async {
      when(() => dio.delete<dynamic>(any())).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ''),
          response: resp({}, statusCode: 404),
          type: DioExceptionType.badResponse,
          message: 'Not Found',
        ),
      );

      try {
        await ds.deleteCategory('store-1', 'c1');
        fail('expected ServerException');
      } on ServerException catch (e) {
        expect(e.statusCode, 404);
        expect(e.message, 'Not Found');
      }
    });
  });
}
