import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dukonpro/core/errors/exceptions.dart';
import 'package:dukonpro/core/network/dio_client.dart';
import 'package:dukonpro/data/datasources/remote/expense_remote_datasource.dart';

class _MockDioClient extends Mock implements DioClient {}

void main() {
  late _MockDioClient dio;
  late ExpenseRemoteDatasourceImpl ds;

  setUp(() {
    dio = _MockDioClient();
    ds = ExpenseRemoteDatasourceImpl(dioClient: dio);
  });

  Response<dynamic> resp(dynamic body) => Response(
        requestOptions: RequestOptions(path: ''),
        statusCode: 200,
        data: body,
      );

  Map<String, dynamic> validExpenseJson({String id = 'exp-1'}) => {
        'id': id,
        'storeId': 'store-1',
        'category': 'RENT',
        'amount': 500,
        'description': 'Office rent',
        'notes': 'Paid in cash',
        'receiptUrl': 'https://example.com/r.png',
        'isRecurring': true,
        'recurringDay': 1,
        'createdBy': 'user-1',
        'date': '2026-05-01T00:00:00.000Z',
        'createdAt': '2026-05-01T00:00:00.000Z',
      };

  void mockGet(Map<String, dynamic> body) {
    when(() => dio.get<dynamic>(
          any(),
          queryParameters: any(named: 'queryParameters'),
        )).thenAnswer((_) async => resp(body));
  }

  group('ExpenseRemoteDatasourceImpl.getExpenses', () {
    test('parses a full list response', () async {
      mockGet({
        'data': [validExpenseJson()],
        'total': 1,
        'totalPages': 1,
      });

      final result = await ds.getExpenses('store-1');

      expect(result.data.length, 1);
      expect(result.total, 1);
      expect(result.totalPages, 1);
      final expense = result.data.first;
      expect(expense.id, 'exp-1');
      expect(expense.storeId, 'store-1');
      expect(expense.category, 'RENT');
      expect(expense.amount, 500.0);
      expect(expense.description, 'Office rent');
      expect(expense.notes, 'Paid in cash');
      expect(expense.receiptUrl, 'https://example.com/r.png');
      expect(expense.isRecurring, isTrue);
      expect(expense.recurringDay, 1);
      expect(expense.createdBy, 'user-1');
    });

    test('defaults total to 0 and totalPages to 1 when absent', () async {
      mockGet({'data': <dynamic>[]});

      final result = await ds.getExpenses('store-1');

      expect(result.data, isEmpty);
      expect(result.total, 0);
      expect(result.totalPages, 1);
    });

    test('defaults isRecurring to false and leaves optional fields null '
        'when absent from the row', () async {
      mockGet({
        'data': [
          {
            'id': 'exp-2',
            'storeId': 'store-1',
            'category': 'UTILITIES',
            'amount': 42,
            'date': '2026-05-01T00:00:00.000Z',
            'createdAt': '2026-05-01T00:00:00.000Z',
          }
        ],
        'total': 1,
        'totalPages': 1,
      });

      final result = await ds.getExpenses('store-1');

      final expense = result.data.single;
      expect(expense.isRecurring, isFalse);
      expect(expense.recurringDay, isNull);
      expect(expense.description, isNull);
      expect(expense.notes, isNull);
      expect(expense.receiptUrl, isNull);
      expect(expense.createdBy, isNull);
    });

    test('coerces integer amount to double', () async {
      mockGet({
        'data': [
          {
            'id': 'exp-3',
            'storeId': 'store-1',
            'category': 'OTHER',
            'amount': 10,
            'date': '2026-05-01T00:00:00.000Z',
            'createdAt': '2026-05-01T00:00:00.000Z',
          }
        ],
        'total': 1,
        'totalPages': 1,
      });

      final result = await ds.getExpenses('store-1');

      expect(result.data.single.amount, 10.0);
      expect(result.data.single.amount, isA<double>());
    });

    test('passes page/limit/category/startDate/endDate/search as query '
        'parameters when provided', () async {
      mockGet({'data': <dynamic>[]});
      final start = DateTime(2026, 1, 1);
      final end = DateTime(2026, 1, 31);

      await ds.getExpenses(
        'store-1',
        page: 2,
        limit: 10,
        category: 'RENT',
        startDate: start,
        endDate: end,
        search: 'office',
      );

      final captured = verify(() => dio.get<dynamic>(
            any(),
            queryParameters: captureAny(named: 'queryParameters'),
          )).captured;
      final params = captured.single as Map<String, dynamic>;
      expect(params['page'], 2);
      expect(params['limit'], 10);
      expect(params['category'], 'RENT');
      expect(params['startDate'], start.toIso8601String());
      expect(params['endDate'], end.toIso8601String());
      expect(params['search'], 'office');
    });

    test('omits category/startDate/endDate/search query params when not '
        'provided', () async {
      mockGet({'data': <dynamic>[]});

      await ds.getExpenses('store-1');

      final captured = verify(() => dio.get<dynamic>(
            any(),
            queryParameters: captureAny(named: 'queryParameters'),
          )).captured;
      final params = captured.single as Map<String, dynamic>;
      expect(params['page'], 1);
      expect(params['limit'], 20);
      expect(params.containsKey('category'), isFalse);
      expect(params.containsKey('startDate'), isFalse);
      expect(params.containsKey('endDate'), isFalse);
      expect(params.containsKey('search'), isFalse);
    });

    test('requests the correct endpoint for the given storeId', () async {
      mockGet({'data': <dynamic>[]});

      await ds.getExpenses('store-42');

      verify(() => dio.get<dynamic>(
            '/stores/store-42/expenses',
            queryParameters: any(named: 'queryParameters'),
          )).called(1);
    });

    test('throws NetworkException on connection timeout', () async {
      when(() => dio.get<dynamic>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.connectionTimeout,
      ));

      expect(
        () => ds.getExpenses('store-1'),
        throwsA(isA<NetworkException>()),
      );
    });

    test('throws UnauthorizedException on 401 response', () async {
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
        () => ds.getExpenses('store-1'),
        throwsA(isA<UnauthorizedException>()),
      );
    });

    test('throws ServerException with statusCode on 500 response', () async {
      when(() => dio.get<dynamic>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 500,
          data: {'message': 'Internal error'},
        ),
      ));

      await expectLater(
        () => ds.getExpenses('store-1'),
        throwsA(isA<ServerException>()
            .having((e) => e.statusCode, 'statusCode', 500)),
      );
    });

    test('joins list-shaped error message with comma', () async {
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
            'message': ['category is required', 'amount is required']
          },
        ),
      ));

      await expectLater(
        () => ds.getExpenses('store-1'),
        throwsA(isA<ServerException>().having(
          (e) => e.message,
          'message',
          'category is required, amount is required',
        )),
      );
    });
  });

  group('ExpenseRemoteDatasourceImpl.getExpense', () {
    test('parses a single expense response', () async {
      when(() => dio.get<dynamic>(any()))
          .thenAnswer((_) async => resp(validExpenseJson()));

      final expense = await ds.getExpense('store-1', 'exp-1');

      expect(expense.id, 'exp-1');
      expect(expense.category, 'RENT');
    });

    test('requests the correct endpoint', () async {
      when(() => dio.get<dynamic>(any()))
          .thenAnswer((_) async => resp(validExpenseJson()));

      await ds.getExpense('store-1', 'exp-9');

      verify(() => dio.get<dynamic>('/stores/store-1/expenses/exp-9'))
          .called(1);
    });

    test('throws ServerException on 404 response', () async {
      when(() => dio.get<dynamic>(any())).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 404,
          data: {'message': 'Not found'},
        ),
      ));

      expect(
        () => ds.getExpense('store-1', 'missing'),
        throwsA(isA<ServerException>()
            .having((e) => e.statusCode, 'statusCode', 404)),
      );
    });
  });

  group('ExpenseRemoteDatasourceImpl.createExpense', () {
    test('posts data and parses the created expense', () async {
      when(() => dio.post<dynamic>(
            any(),
            data: any(named: 'data'),
          )).thenAnswer((_) async => resp(validExpenseJson()));

      final data = {'category': 'RENT', 'amount': 500};
      final expense = await ds.createExpense('store-1', data);

      expect(expense.id, 'exp-1');
      verify(() => dio.post<dynamic>(
            '/stores/store-1/expenses',
            data: data,
          )).called(1);
    });

    test('throws NetworkException on connection error', () async {
      when(() => dio.post<dynamic>(
            any(),
            data: any(named: 'data'),
          )).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.connectionError,
      ));

      expect(
        () => ds.createExpense('store-1', {'category': 'RENT'}),
        throwsA(isA<NetworkException>()),
      );
    });

    test('throws ServerException with message from response on 400',
        () async {
      when(() => dio.post<dynamic>(
            any(),
            data: any(named: 'data'),
          )).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 400,
          data: {'message': 'Amount must be positive'},
        ),
      ));

      await expectLater(
        () => ds.createExpense('store-1', {'amount': -1}),
        throwsA(isA<ServerException>().having(
          (e) => e.message,
          'message',
          'Amount must be positive',
        )),
      );
    });
  });

  group('ExpenseRemoteDatasourceImpl.updateExpense', () {
    test('puts data and parses the updated expense', () async {
      when(() => dio.put<dynamic>(
            any(),
            data: any(named: 'data'),
          )).thenAnswer((_) async => resp(validExpenseJson()));

      final data = {'amount': 600};
      final expense = await ds.updateExpense('store-1', 'exp-1', data);

      expect(expense.id, 'exp-1');
      verify(() => dio.put<dynamic>(
            '/stores/store-1/expenses/exp-1',
            data: data,
          )).called(1);
    });

    test('throws UnauthorizedException on 401 response', () async {
      when(() => dio.put<dynamic>(
            any(),
            data: any(named: 'data'),
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
        () => ds.updateExpense('store-1', 'exp-1', {'amount': 1}),
        throwsA(isA<UnauthorizedException>()),
      );
    });
  });

  group('ExpenseRemoteDatasourceImpl.deleteExpense', () {
    test('calls delete on the correct endpoint', () async {
      when(() => dio.delete<dynamic>(any()))
          .thenAnswer((_) async => resp(null));

      await ds.deleteExpense('store-1', 'exp-1');

      verify(() => dio.delete<dynamic>('/stores/store-1/expenses/exp-1'))
          .called(1);
    });

    test('throws ServerException on server error', () async {
      when(() => dio.delete<dynamic>(any())).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 500,
          data: {'message': 'boom'},
        ),
      ));

      expect(
        () => ds.deleteExpense('store-1', 'exp-1'),
        throwsA(isA<ServerException>()),
      );
    });

    test('throws NetworkException on send timeout', () async {
      when(() => dio.delete<dynamic>(any())).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.sendTimeout,
      ));

      expect(
        () => ds.deleteExpense('store-1', 'exp-1'),
        throwsA(isA<NetworkException>()),
      );
    });
  });
}
