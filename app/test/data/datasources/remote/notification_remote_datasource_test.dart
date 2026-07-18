import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dukonpro/core/errors/exceptions.dart';
import 'package:dukonpro/core/network/dio_client.dart';
import 'package:dukonpro/data/datasources/remote/notification_remote_datasource.dart';

class _MockDioClient extends Mock implements DioClient {}

void main() {
  late _MockDioClient dio;
  late NotificationRemoteDatasourceImpl ds;

  setUp(() {
    dio = _MockDioClient();
    ds = NotificationRemoteDatasourceImpl(dioClient: dio);
  });

  Response<dynamic> resp(dynamic body) => Response(
        requestOptions: RequestOptions(path: ''),
        statusCode: 200,
        data: body,
      );

  group('NotificationRemoteDatasourceImpl.getNotifications', () {
    test('returns data + total when response has "data" key', () async {
      when(() => dio.get<dynamic>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((_) async => resp({
            'data': [
              {'id': 'n1', 'title': 'Hi'},
              {'id': 'n2', 'title': 'Bye'},
            ],
            'total': 2,
          }));

      final result = await ds.getNotifications('store-1');

      expect(result.data.length, 2);
      expect(result.data[0]['id'], 'n1');
      expect(result.total, 2);
    });

    test('falls back to "items" key when "data" is absent', () async {
      when(() => dio.get<dynamic>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((_) async => resp({
            'items': [
              {'id': 'n1'},
            ],
          }));

      final result = await ds.getNotifications('store-1');

      expect(result.data.length, 1);
      expect(result.data[0]['id'], 'n1');
      // total falls back to items.length since 'total' key missing.
      expect(result.total, 1);
    });

    test('returns empty list and zero total when neither key present',
        () async {
      when(() => dio.get<dynamic>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((_) async => resp(<String, dynamic>{}));

      final result = await ds.getNotifications('store-1');

      expect(result.data, isEmpty);
      expect(result.total, 0);
    });

    test('sends page and limit as query parameters', () async {
      when(() => dio.get<dynamic>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((_) async => resp({'data': [], 'total': 0}));

      await ds.getNotifications('store-1', page: 3, limit: 50);

      final captured = verify(() => dio.get<dynamic>(
            '/stores/store-1/notifications',
            queryParameters: captureAny(named: 'queryParameters'),
          )).captured;
      final params = captured.single as Map<String, dynamic>;
      expect(params['page'], 3);
      expect(params['limit'], 50);
    });

    test('defaults to page 1 and limit 20 when not specified', () async {
      when(() => dio.get<dynamic>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((_) async => resp({'data': [], 'total': 0}));

      await ds.getNotifications('store-1');

      final captured = verify(() => dio.get<dynamic>(
            any(),
            queryParameters: captureAny(named: 'queryParameters'),
          )).captured;
      final params = captured.single as Map<String, dynamic>;
      expect(params['page'], 1);
      expect(params['limit'], 20);
    });

    test('maps connection timeout DioException to NetworkException', () async {
      when(() => dio.get<dynamic>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.connectionTimeout,
      ));

      expect(
        () => ds.getNotifications('store-1'),
        throwsA(isA<NetworkException>()),
      );
    });

    test('maps 401 DioException to UnauthorizedException', () async {
      when(() => dio.get<dynamic>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 401,
          data: {'message': 'Unauthorized'},
        ),
      ));

      expect(
        () => ds.getNotifications('store-1'),
        throwsA(isA<UnauthorizedException>()),
      );
    });

    test('maps generic error DioException to ServerException with statusCode',
        () async {
      when(() => dio.get<dynamic>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 500,
          data: {'message': 'Boom'},
        ),
      ));

      try {
        await ds.getNotifications('store-1');
        fail('should have thrown');
      } on ServerException catch (e) {
        expect(e.statusCode, 500);
        expect(e.message, 'Boom');
      }
    });

    test('joins list-shaped error message field with a comma', () async {
      when(() => dio.get<dynamic>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 400,
          data: {
            'message': ['bad page', 'bad limit'],
          },
        ),
      ));

      try {
        await ds.getNotifications('store-1');
        fail('should have thrown');
      } on ServerException catch (e) {
        expect(e.message, 'bad page, bad limit');
      }
    });

    test('falls back to DioException.message when response data has no message field',
        () async {
      when(() => dio.get<dynamic>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.badResponse,
        message: 'raw dio failure',
        response: Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 502,
          data: 'not a map',
        ),
      ));

      try {
        await ds.getNotifications('store-1');
        fail('should have thrown');
      } on ServerException catch (e) {
        expect(e.message, 'raw dio failure');
        expect(e.statusCode, 502);
      }
    });
  });

  group('NotificationRemoteDatasourceImpl.markAsRead', () {
    test('calls the mark-as-read endpoint', () async {
      when(() => dio.put<dynamic>(any()))
          .thenAnswer((_) async => resp(null));

      await ds.markAsRead('store-1', 'n1');

      verify(() =>
              dio.put<dynamic>('/stores/store-1/notifications/n1/read'))
          .called(1);
    });

    test('maps DioException to ServerException', () async {
      when(() => dio.put<dynamic>(any())).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 404,
          data: {'message': 'Not found'},
        ),
      ));

      expect(
        () => ds.markAsRead('store-1', 'n1'),
        throwsA(isA<ServerException>()),
      );
    });
  });

  group('NotificationRemoteDatasourceImpl.getSettings', () {
    test('returns the settings map on success', () async {
      when(() => dio.get<dynamic>(any()))
          .thenAnswer((_) async => resp({'lowStock': true, 'debtDue': false}));

      final settings = await ds.getSettings('store-1');

      expect(settings['lowStock'], true);
      expect(settings['debtDue'], false);
    });

    test('returns empty map when response data is null', () async {
      when(() => dio.get<dynamic>(any()))
          .thenAnswer((_) async => resp(null));

      final settings = await ds.getSettings('store-1');

      expect(settings, isEmpty);
    });

    test('maps DioException to NetworkException on connection error',
        () async {
      when(() => dio.get<dynamic>(any())).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.connectionError,
      ));

      expect(
        () => ds.getSettings('store-1'),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  group('NotificationRemoteDatasourceImpl.saveSettings', () {
    test('puts the settings payload to the endpoint', () async {
      when(() => dio.put<dynamic>(any(), data: any(named: 'data')))
          .thenAnswer((_) async => resp(null));

      await ds.saveSettings('store-1', {'lowStock': false});

      verify(() => dio.put<dynamic>(
            '/stores/store-1/notifications/settings',
            data: {'lowStock': false},
          )).called(1);
    });

    test('maps DioException to ServerException', () async {
      when(() => dio.put<dynamic>(any(), data: any(named: 'data')))
          .thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 400,
          data: {'message': 'Invalid settings'},
        ),
      ));

      expect(
        () => ds.saveSettings('store-1', {'lowStock': false}),
        throwsA(isA<ServerException>()),
      );
    });
  });

  group('NotificationRemoteDatasourceImpl.saveFcmToken', () {
    test('posts token and platform when platform is provided', () async {
      when(() => dio.post<dynamic>(any(), data: any(named: 'data')))
          .thenAnswer((_) async => resp(null));

      await ds.saveFcmToken('tok-123', platform: 'ANDROID');

      final captured = verify(() => dio.post<dynamic>(
            '/users/me/fcm-token',
            data: captureAny(named: 'data'),
          )).captured;
      final data = captured.single as Map<String, dynamic>;
      expect(data['token'], 'tok-123');
      expect(data['platform'], 'ANDROID');
    });

    test('omits platform key from payload when platform is null', () async {
      when(() => dio.post<dynamic>(any(), data: any(named: 'data')))
          .thenAnswer((_) async => resp(null));

      await ds.saveFcmToken('tok-123');

      final captured = verify(() => dio.post<dynamic>(
            '/users/me/fcm-token',
            data: captureAny(named: 'data'),
          )).captured;
      final data = captured.single as Map<String, dynamic>;
      expect(data['token'], 'tok-123');
      expect(data.containsKey('platform'), isFalse);
    });

    test('maps DioException to NetworkException on send timeout', () async {
      when(() => dio.post<dynamic>(any(), data: any(named: 'data')))
          .thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.sendTimeout,
      ));

      expect(
        () => ds.saveFcmToken('tok-123'),
        throwsA(isA<NetworkException>()),
      );
    });
  });
}
