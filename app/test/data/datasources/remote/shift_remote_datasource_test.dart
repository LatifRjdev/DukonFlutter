import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dukonpro/core/errors/exceptions.dart';
import 'package:dukonpro/core/network/dio_client.dart';
import 'package:dukonpro/data/datasources/remote/shift_remote_datasource.dart';

class _MockDioClient extends Mock implements DioClient {}

void main() {
  late _MockDioClient dio;
  late ShiftRemoteDatasourceImpl ds;

  setUp(() {
    dio = _MockDioClient();
    ds = ShiftRemoteDatasourceImpl(dioClient: dio);
  });

  Response<dynamic> resp(dynamic body, {int statusCode = 200}) => Response(
        requestOptions: RequestOptions(path: ''),
        statusCode: statusCode,
        data: body,
      );

  Map<String, dynamic> shiftJson({String status = 'OPEN'}) => {
        'id': 'shift-1',
        'storeId': 'store-1',
        'staffId': 'staff-1',
        'openedAt': '2026-07-17T08:00:00.000Z',
        'openingCash': 500,
        'status': status,
      };

  group('ShiftRemoteDatasourceImpl.openShift', () {
    test('posts to the shift-open endpoint and parses the response',
        () async {
      when(() => dio.post<dynamic>(any(), data: any(named: 'data')))
          .thenAnswer((_) async => resp(shiftJson()));

      final shift = await ds.openShift('store-1', {'openingCash': 500});

      expect(shift.id, 'shift-1');
      expect(shift.status, 'OPEN');
      verify(() => dio.post<dynamic>(
            '/stores/store-1/shifts/open',
            data: {'openingCash': 500},
          )).called(1);
    });

    test('throws NetworkException on connection error', () async {
      when(() => dio.post<dynamic>(any(), data: any(named: 'data')))
          .thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.connectionError,
      ));

      expect(
        () => ds.openShift('store-1', {'openingCash': 500}),
        throwsA(isA<NetworkException>()),
      );
    });

    test('throws ServerException with statusCode on 409 active-shift conflict',
        () async {
      when(() => dio.post<dynamic>(any(), data: any(named: 'data')))
          .thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.badResponse,
        response: resp({'message': 'Shift already open'}, statusCode: 409),
      ));

      await expectLater(
        () => ds.openShift('store-1', {'openingCash': 500}),
        throwsA(isA<ServerException>()
            .having((e) => e.statusCode, 'statusCode', 409)
            .having((e) => e.message, 'message', 'Shift already open')),
      );
    });
  });

  group('ShiftRemoteDatasourceImpl.closeShift', () {
    test('posts closing cash to the shift-close endpoint and parses response',
        () async {
      when(() => dio.post<dynamic>(any(), data: any(named: 'data')))
          .thenAnswer((_) async => resp(shiftJson(status: 'CLOSED')));

      final shift =
          await ds.closeShift('store-1', 'shift-1', {'closingCash': 1200});

      expect(shift.status, 'CLOSED');
      verify(() => dio.post<dynamic>(
            '/stores/store-1/shifts/shift-1/close',
            data: {'closingCash': 1200},
          )).called(1);
    });

    test('throws NetworkException on send timeout', () async {
      when(() => dio.post<dynamic>(any(), data: any(named: 'data')))
          .thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.sendTimeout,
      ));

      expect(
        () => ds.closeShift('store-1', 'shift-1', {'closingCash': 1200}),
        throwsA(isA<NetworkException>()),
      );
    });

    test('throws UnauthorizedException on 401 response', () async {
      when(() => dio.post<dynamic>(any(), data: any(named: 'data')))
          .thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.badResponse,
        response: resp({'message': 'Unauthorized'}, statusCode: 401),
      ));

      expect(
        () => ds.closeShift('store-1', 'shift-1', {'closingCash': 1200}),
        throwsA(isA<UnauthorizedException>()),
      );
    });
  });

  group('ShiftRemoteDatasourceImpl.getCurrentShift', () {
    test('parses the current open shift when present', () async {
      when(() => dio.get<dynamic>(any())).thenAnswer(
        (_) async => resp(shiftJson()),
      );

      final shift = await ds.getCurrentShift('store-1');

      expect(shift, isNotNull);
      expect(shift!.id, 'shift-1');
      verify(() => dio.get<dynamic>('/stores/store-1/shifts/current'))
          .called(1);
    });

    test('returns null when the response body is null', () async {
      when(() => dio.get<dynamic>(any())).thenAnswer((_) async => resp(null));

      final shift = await ds.getCurrentShift('store-1');

      expect(shift, isNull);
    });

    test('returns null on 404 (no open shift) instead of throwing', () async {
      when(() => dio.get<dynamic>(any())).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.badResponse,
        response: resp({'message': 'Not found'}, statusCode: 404),
      ));

      final shift = await ds.getCurrentShift('store-1');

      expect(shift, isNull);
    });

    test('rethrows as ServerException on a non-404 error status', () async {
      when(() => dio.get<dynamic>(any())).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.badResponse,
        response: resp({'message': 'Internal error'}, statusCode: 500),
      ));

      expect(
        () => ds.getCurrentShift('store-1'),
        throwsA(isA<ServerException>()),
      );
    });
  });

  group('ShiftRemoteDatasourceImpl.getShifts', () {
    void mockGet(Map<String, dynamic> body) {
      when(() => dio.get<dynamic>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((_) async => resp(body));
    }

    test('parses a paginated list of shifts', () async {
      mockGet({
        'data': [shiftJson(), shiftJson(status: 'CLOSED')],
        'total': 2,
        'totalPages': 1,
      });

      final result = await ds.getShifts('store-1');

      expect(result.data, hasLength(2));
      expect(result.total, 2);
      expect(result.totalPages, 1);
    });

    test('defaults total/totalPages when absent from the response',
        () async {
      mockGet({'data': <dynamic>[]});

      final result = await ds.getShifts('store-1');

      expect(result.data, isEmpty);
      expect(result.total, 0);
      expect(result.totalPages, 1);
    });

    test('passes page/staffId/date filters as query parameters', () async {
      mockGet({'data': <dynamic>[]});

      await ds.getShifts(
        'store-1',
        page: 2,
        staffId: 'staff-1',
        dateFrom: '2026-07-01',
        dateTo: '2026-07-31',
      );

      final captured = verify(() => dio.get<dynamic>(
            any(),
            queryParameters: captureAny(named: 'queryParameters'),
          )).captured;
      final params = captured.single as Map<String, dynamic>;
      expect(params['page'], 2);
      expect(params['staffId'], 'staff-1');
      expect(params['dateFrom'], '2026-07-01');
      expect(params['dateTo'], '2026-07-31');
    });

    test('throws NetworkException on receive timeout', () async {
      when(() => dio.get<dynamic>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.receiveTimeout,
      ));

      expect(() => ds.getShifts('store-1'), throwsA(isA<NetworkException>()));
    });
  });

  group('ShiftRemoteDatasourceImpl.getShift', () {
    test('fetches a single shift by id', () async {
      when(() => dio.get<dynamic>(any()))
          .thenAnswer((_) async => resp(shiftJson()));

      final shift = await ds.getShift('store-1', 'shift-1');

      expect(shift.id, 'shift-1');
      verify(() => dio.get<dynamic>('/stores/store-1/shifts/shift-1'))
          .called(1);
    });

    test('throws ServerException joining list-shaped error messages',
        () async {
      when(() => dio.get<dynamic>(any())).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.badResponse,
        response: resp({
          'message': ['shift not found', 'store mismatch'],
        }, statusCode: 400),
      ));

      await expectLater(
        () => ds.getShift('store-1', 'shift-1'),
        throwsA(isA<ServerException>().having(
          (e) => e.message,
          'message',
          'shift not found, store mismatch',
        )),
      );
    });
  });

  group('ShiftRemoteDatasourceImpl.getZReport', () {
    Map<String, dynamic> zReportJson() => {
          'staffName': 'Ali',
          'openedAt': '2026-07-17T08:00:00.000Z',
          'closedAt': '2026-07-17T20:00:00.000Z',
          'duration': '12h 00m',
          'expectedCash': 1000,
          'actualCash': 950,
          'difference': -50,
        };

    test('fetches and parses the Z-report for a closed shift', () async {
      when(() => dio.get<dynamic>(any()))
          .thenAnswer((_) async => resp(zReportJson()));

      final report = await ds.getZReport('store-1', 'shift-1');

      expect(report.staffName, 'Ali');
      expect(report.expectedCash, 1000);
      expect(report.actualCash, 950);
      expect(report.difference, -50);
      verify(() =>
              dio.get<dynamic>('/stores/store-1/shifts/shift-1/z-report'))
          .called(1);
    });

    test('throws ServerException with default message when response body '
        'has no message field', () async {
      when(() => dio.get<dynamic>(any())).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.badResponse,
        message: 'boom',
        response: resp(<String, dynamic>{}, statusCode: 500),
      ));

      await expectLater(
        () => ds.getZReport('store-1', 'shift-1'),
        throwsA(isA<ServerException>()
            .having((e) => e.statusCode, 'statusCode', 500)),
      );
    });
  });
}
