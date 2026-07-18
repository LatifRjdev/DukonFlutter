import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dukonpro/core/errors/exceptions.dart';
import 'package:dukonpro/core/network/dio_client.dart';
import 'package:dukonpro/data/datasources/remote/zakat_remote_datasource.dart';

// Zakat: the client never re-validates or recomputes the amounts the
// server calculates (see the "remove client zakatDue validation" fix) —
// these tests assert the datasource maps `zakatDue` (and the rest of the
// calculation/payment breakdown) straight through from the response body
// without touching the numbers.
class _MockDioClient extends Mock implements DioClient {}

void main() {
  late _MockDioClient dio;
  late ZakatRemoteDatasourceImpl ds;

  setUp(() {
    dio = _MockDioClient();
    ds = ZakatRemoteDatasourceImpl(dioClient: dio);
  });

  Response<dynamic> resp(dynamic body) => Response(
        requestOptions: RequestOptions(path: ''),
        statusCode: 200,
        data: body,
      );

  group('ZakatRemoteDatasourceImpl.calculate', () {
    test('maps a full response, taking zakatDue straight from the server',
        () async {
      when(() => dio.get<dynamic>(any())).thenAnswer(
        (_) async => resp({
          'breakdown': {
            'inventoryValue': 5000,
            'receivables': 300,
            'payables': 100,
          },
          'netAssets': 5200,
          'nisabAmount': 4000,
          'zakatDue': 130.5,
          'isAboveNisab': true,
          'zakatRate': 2.5,
        }),
      );

      final calc = await ds.calculate('store-1');

      expect(calc.stockValue, 5000);
      expect(calc.receivables, 300);
      expect(calc.payables, 100);
      expect(calc.netAssets, 5200);
      expect(calc.nisabAmount, 4000);
      // The client must not recompute this — it comes straight from the
      // server's response, unmodified.
      expect(calc.zakatDue, 130.5);
      expect(calc.isAboveNisab, isTrue);
      expect(calc.zakatRate, 2.5);
    });

    test('defaults all numeric/bool fields when body is empty', () async {
      when(() => dio.get<dynamic>(any()))
          .thenAnswer((_) async => resp(<String, dynamic>{}));

      final calc = await ds.calculate('store-1');

      expect(calc.stockValue, 0);
      expect(calc.receivables, 0);
      expect(calc.payables, 0);
      expect(calc.netAssets, 0);
      expect(calc.nisabAmount, 0);
      expect(calc.zakatDue, 0);
      expect(calc.isAboveNisab, isFalse);
      expect(calc.zakatRate, 2.5);
    });

    test('defaults breakdown-derived fields to 0 when breakdown key is absent',
        () async {
      when(() => dio.get<dynamic>(any())).thenAnswer(
        (_) async => resp({
          'netAssets': 100,
          'zakatDue': 2.5,
          'isAboveNisab': false,
        }),
      );

      final calc = await ds.calculate('store-1');

      expect(calc.stockValue, 0);
      expect(calc.receivables, 0);
      expect(calc.payables, 0);
      expect(calc.netAssets, 100);
      expect(calc.zakatDue, 2.5);
    });

    test('throws NetworkException on connection timeout', () async {
      when(() => dio.get<dynamic>(any())).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.connectionTimeout,
      ));

      expect(() => ds.calculate('store-1'), throwsA(isA<NetworkException>()));
    });

    test('throws UnauthorizedException on 401 response', () async {
      when(() => dio.get<dynamic>(any())).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 401,
          data: {'message': 'Unauthorized'},
        ),
      ));

      expect(
        () => ds.calculate('store-1'),
        throwsA(isA<UnauthorizedException>()),
      );
    });

    test('throws ServerException carrying statusCode + joined message list',
        () async {
      when(() => dio.get<dynamic>(any())).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 500,
          data: {
            'message': ['boom', 'again'],
          },
        ),
      ));

      try {
        await ds.calculate('store-1');
        fail('expected ServerException');
      } on ServerException catch (e) {
        expect(e.statusCode, 500);
        expect(e.message, 'boom, again');
      }
    });
  });

  group('ZakatRemoteDatasourceImpl.getSettings', () {
    test('returns null when response data is null', () async {
      when(() => dio.get<dynamic>(any()))
          .thenAnswer((_) async => resp(null));

      final settings = await ds.getSettings('store-1');

      expect(settings, isNull);
    });

    test('maps a full settings response', () async {
      when(() => dio.get<dynamic>(any())).thenAnswer(
        (_) async => resp({
          'id': 'zs-1',
          'storeId': 'store-1',
          'nisabGold': 90,
          'nisabSilver': 600,
          'nisabCurrency': 'USD',
          'nisabAmount': 4500,
          'haulStartDate': '2026-01-01T00:00:00.000Z',
          'zakatRate': 2.5,
          'includeStock': false,
          'includeCash': true,
          'includeDebts': false,
          'cashOnHand': 250,
        }),
      );

      final settings = await ds.getSettings('store-1');

      expect(settings, isNotNull);
      expect(settings!.id, 'zs-1');
      expect(settings.storeId, 'store-1');
      expect(settings.nisabGold, 90);
      expect(settings.nisabSilver, 600);
      expect(settings.nisabCurrency, 'USD');
      expect(settings.nisabAmount, 4500);
      expect(settings.haulStartDate, DateTime.parse('2026-01-01T00:00:00.000Z'));
      expect(settings.zakatRate, 2.5);
      expect(settings.includeStock, isFalse);
      expect(settings.includeCash, isTrue);
      expect(settings.includeDebts, isFalse);
      expect(settings.cashOnHand, 250);
    });

    test('defaults missing optional fields (no crash)', () async {
      when(() => dio.get<dynamic>(any())).thenAnswer(
        (_) async => resp(<String, dynamic>{}),
      );

      final settings = await ds.getSettings('store-1');

      expect(settings, isNotNull);
      expect(settings!.id, '');
      expect(settings.storeId, '');
      expect(settings.nisabGold, 85);
      expect(settings.nisabSilver, 595);
      expect(settings.nisabCurrency, 'TJS');
      expect(settings.nisabAmount, 0);
      expect(settings.haulStartDate, isNull);
      expect(settings.zakatRate, 2.5);
      expect(settings.includeStock, isTrue);
      expect(settings.includeCash, isTrue);
      expect(settings.includeDebts, isTrue);
      expect(settings.cashOnHand, 0);
    });

    test('leaves haulStartDate null when the field is null', () async {
      when(() => dio.get<dynamic>(any())).thenAnswer(
        (_) async => resp({
          'id': 'zs-2',
          'storeId': 'store-1',
          'haulStartDate': null,
        }),
      );

      final settings = await ds.getSettings('store-1');

      expect(settings!.haulStartDate, isNull);
    });

    test('throws NetworkException on connection error', () async {
      when(() => dio.get<dynamic>(any())).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.connectionError,
      ));

      expect(() => ds.getSettings('store-1'), throwsA(isA<NetworkException>()));
    });
  });

  group('ZakatRemoteDatasourceImpl.upsertSettings', () {
    test('posts the caller-supplied data unmodified and maps the response',
        () async {
      when(() => dio.post<dynamic>(any(), data: any(named: 'data')))
          .thenAnswer((_) async => resp({
                'id': 'zs-1',
                'storeId': 'store-1',
                'nisabAmount': 1000,
                'cashOnHand': 50,
              }));

      final input = {'cashOnHand': 50, 'includeStock': false};
      final settings = await ds.upsertSettings('store-1', input);

      expect(settings.id, 'zs-1');
      expect(settings.cashOnHand, 50);

      final captured = verify(() => dio.post<dynamic>(
            any(),
            data: captureAny(named: 'data'),
          )).captured;
      // The datasource is a pure pass-through — it must not add, remove or
      // recompute any field in the outgoing payload.
      expect(captured.single, same(input));
    });

    test('throws ServerException on 400 with generic message', () async {
      when(() => dio.post<dynamic>(any(), data: any(named: 'data')))
          .thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.badResponse,
        message: 'bad request',
        response: Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 400,
          data: <String, dynamic>{},
        ),
      ));

      try {
        await ds.upsertSettings('store-1', {'cashOnHand': -1});
        fail('expected ServerException');
      } on ServerException catch (e) {
        expect(e.statusCode, 400);
        expect(e.message, 'bad request');
      }
    });
  });

  group('ZakatRemoteDatasourceImpl.getPayments', () {
    test('maps the paginated {data,total,totalPages,currentPage} shape',
        () async {
      when(() => dio.get<dynamic>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((_) async => resp({
            'data': [_paymentJson(id: 'zp-1'), _paymentJson(id: 'zp-2')],
            'total': 5,
            'totalPages': 3,
            'currentPage': 2,
          }));

      final page = await ds.getPayments('store-1', page: 2, limit: 2);

      expect(page.data.length, 2);
      expect(page.data.map((p) => p.id), ['zp-1', 'zp-2']);
      expect(page.total, 5);
      expect(page.totalPages, 3);
      expect(page.currentPage, 2);
    });

    test('falls back to single-page semantics for the legacy list shape',
        () async {
      when(() => dio.get<dynamic>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((_) async => resp([
            _paymentJson(id: 'zp-1'),
            _paymentJson(id: 'zp-2'),
            _paymentJson(id: 'zp-3'),
          ]));

      final page = await ds.getPayments('store-1');

      expect(page.data.length, 3);
      expect(page.total, 3);
      expect(page.totalPages, 1);
      expect(page.currentPage, 1);
    });

    test('defaults total/totalPages/currentPage when absent from map shape',
        () async {
      when(() => dio.get<dynamic>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((_) async => resp({
            'data': [_paymentJson(id: 'zp-1')],
          }));

      final page = await ds.getPayments('store-1', page: 4);

      expect(page.data.length, 1);
      expect(page.total, 1);
      expect(page.totalPages, 1);
      expect(page.currentPage, 4);
    });

    test('sends page and limit as query parameters', () async {
      when(() => dio.get<dynamic>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((_) async => resp({'data': <dynamic>[]}));

      await ds.getPayments('store-1', page: 3, limit: 10);

      final captured = verify(() => dio.get<dynamic>(
            any(),
            queryParameters: captureAny(named: 'queryParameters'),
          )).captured;
      final params = captured.single as Map<String, dynamic>;
      expect(params['page'], 3);
      expect(params['limit'], 10);
    });

    test('throws NetworkException on send timeout', () async {
      when(() => dio.get<dynamic>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.sendTimeout,
      ));

      expect(() => ds.getPayments('store-1'), throwsA(isA<NetworkException>()));
    });
  });

  group('ZakatRemoteDatasourceImpl.createPayment', () {
    test(
        'posts the caller-supplied data unmodified and maps zakatDue '
        'straight from the server response', () async {
      when(() => dio.post<dynamic>(any(), data: any(named: 'data')))
          .thenAnswer((_) async => resp(_paymentJson(
                id: 'zp-9',
                amount: 77.7,
                zakatDue: 77.7,
              )));

      final input = {'amount': 77.7, 'notes': 'Ramadan payment'};
      final payment = await ds.createPayment('store-1', input);

      expect(payment.id, 'zp-9');
      expect(payment.amount, 77.7);
      // Not recomputed client-side — comes straight from the response.
      expect(payment.zakatDue, 77.7);

      final captured = verify(() => dio.post<dynamic>(
            any(),
            data: captureAny(named: 'data'),
          )).captured;
      expect(captured.single, same(input));
    });

    test('maps notes to null when absent from the response', () async {
      when(() => dio.post<dynamic>(any(), data: any(named: 'data')))
          .thenAnswer((_) async => resp(_paymentJson(id: 'zp-10')..remove('notes')));

      final payment = await ds.createPayment('store-1', {'amount': 10});

      expect(payment.notes, isNull);
    });

    test('defaults breakdown to an empty map when absent', () async {
      when(() => dio.post<dynamic>(any(), data: any(named: 'data')))
          .thenAnswer((_) async =>
              resp(_paymentJson(id: 'zp-11')..remove('breakdown')));

      final payment = await ds.createPayment('store-1', {'amount': 10});

      expect(payment.breakdown, isEmpty);
    });

    test('throws when a required field (zakatDue) is missing from the response',
        () async {
      final malformed = _paymentJson(id: 'zp-12')..remove('zakatDue');
      when(() => dio.post<dynamic>(any(), data: any(named: 'data')))
          .thenAnswer((_) async => resp(malformed));

      expect(
        () => ds.createPayment('store-1', {'amount': 10}),
        throwsA(isA<TypeError>()),
      );
    });

    test('throws UnauthorizedException on 401 response', () async {
      when(() => dio.post<dynamic>(any(), data: any(named: 'data')))
          .thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 401,
          data: {'message': 'Unauthorized'},
        ),
      ));

      expect(
        () => ds.createPayment('store-1', {'amount': 10}),
        throwsA(isA<UnauthorizedException>()),
      );
    });
  });
}

Map<String, dynamic> _paymentJson({
  String id = 'zp-1',
  String storeId = 'store-1',
  double amount = 50,
  double totalAssets = 2000,
  double zakatDue = 50,
  Map<String, dynamic>? breakdown,
  String? notes = 'note',
}) =>
    {
      'id': id,
      'storeId': storeId,
      'amount': amount,
      'totalAssets': totalAssets,
      'zakatDue': zakatDue,
      'breakdown': breakdown ?? <String, dynamic>{},
      'notes': notes,
      'paidAt': '2026-01-01T00:00:00.000Z',
      'createdAt': '2026-01-01T00:00:00.000Z',
    };
