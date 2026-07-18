import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dukonpro/core/errors/exceptions.dart';
import 'package:dukonpro/core/network/dio_client.dart';
import 'package:dukonpro/data/datasources/remote/staff_remote_datasource.dart';

class _MockDioClient extends Mock implements DioClient {}

void main() {
  late _MockDioClient dio;
  late StaffRemoteDatasourceImpl ds;

  setUp(() {
    dio = _MockDioClient();
    ds = StaffRemoteDatasourceImpl(dioClient: dio);
  });

  Response<dynamic> resp(dynamic body) => Response(
        requestOptions: RequestOptions(path: ''),
        statusCode: 200,
        data: body,
      );

  Map<String, dynamic> validStaffJson({String id = 'staff-1'}) => {
        'id': id,
        'storeId': 'store-1',
        'userId': 'user-1',
        'name': 'Ali',
        'phone': '+992900000000',
        'role': 'CASHIER',
        'salary': 1000,
        'commission': 5,
        'isActive': true,
        'isOnShift': false,
        'createdAt': '2026-04-11T10:00:00.000Z',
      };

  void mockGet(dynamic body) {
    when(() => dio.get<dynamic>(
          any(),
          queryParameters: any(named: 'queryParameters'),
        )).thenAnswer((_) async => resp(body));
  }

  group('StaffRemoteDatasourceImpl.getStaff', () {
    test('parses a full list response', () async {
      mockGet({
        'data': [validStaffJson()],
        'total': 1,
        'totalPages': 1,
      });

      final result = await ds.getStaff('store-1');

      expect(result.data.length, 1);
      expect(result.total, 1);
      expect(result.totalPages, 1);
      final member = result.data.first;
      expect(member.id, 'staff-1');
      expect(member.name, 'Ali');
      expect(member.role, 'CASHIER');
      expect(member.salary, 1000.0);
    });

    test('parses a bare JSON array response (no pagination envelope)',
        () async {
      mockGet([validStaffJson(id: 's1'), validStaffJson(id: 's2')]);

      final result = await ds.getStaff('store-1');

      expect(result.data.length, 2);
      expect(result.data.map((m) => m.id), ['s1', 's2']);
    });

    test('parses nested user.* identity shape from the backend', () async {
      mockGet({
        'data': [
          {
            'id': 's3',
            'storeId': 'store-1',
            'role': 'OWNER',
            'createdAt': '2026-04-11T10:00:00.000Z',
            'user': {'id': 'u3', 'name': 'Gulnora', 'phone': '+992911111111'},
          },
        ],
        'total': 1,
        'totalPages': 1,
      });

      final result = await ds.getStaff('store-1');

      expect(result.data.single.name, 'Gulnora');
      expect(result.data.single.userId, 'u3');
      expect(result.data.single.phone, '+992911111111');
    });

    test('returns an empty list when the data field is empty', () async {
      mockGet({'data': <dynamic>[], 'total': 0, 'totalPages': 0});

      final result = await ds.getStaff('store-1');

      expect(result.data, isEmpty);
      expect(result.total, 0);
    });

    test('passes page/search/role as query parameters when provided',
        () async {
      mockGet({'data': <dynamic>[]});

      await ds.getStaff('store-1', page: 2, search: 'ali', role: 'CASHIER');

      final captured = verify(() => dio.get<dynamic>(
            any(),
            queryParameters: captureAny(named: 'queryParameters'),
          )).captured;
      final params = captured.single as Map<String, dynamic>;
      expect(params['page'], 2);
      expect(params['search'], 'ali');
      expect(params['role'], 'CASHIER');
    });

    test('omits search/role query params when not provided', () async {
      mockGet({'data': <dynamic>[]});

      await ds.getStaff('store-1');

      final captured = verify(() => dio.get<dynamic>(
            any(),
            queryParameters: captureAny(named: 'queryParameters'),
          )).captured;
      final params = captured.single as Map<String, dynamic>;
      expect(params['page'], 1);
      expect(params.containsKey('search'), isFalse);
      expect(params.containsKey('role'), isFalse);
    });

    test('requests the correct endpoint for the given storeId', () async {
      mockGet({'data': <dynamic>[]});

      await ds.getStaff('store-42');

      verify(() => dio.get<dynamic>(
            '/stores/store-42/staff',
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

      expect(() => ds.getStaff('store-1'), throwsA(isA<NetworkException>()));
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
        () => ds.getStaff('store-1'),
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
        () => ds.getStaff('store-1'),
        throwsA(
          isA<ServerException>().having((e) => e.statusCode, 'statusCode', 500),
        ),
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
            'message': ['name is required', 'role is required'],
          },
        ),
      ));

      await expectLater(
        () => ds.getStaff('store-1'),
        throwsA(isA<ServerException>().having(
          (e) => e.message,
          'message',
          'name is required, role is required',
        )),
      );
    });
  });

  group('StaffRemoteDatasourceImpl.getStaffMember', () {
    test('parses a single staff member response', () async {
      when(() => dio.get<dynamic>(any()))
          .thenAnswer((_) async => resp(validStaffJson()));

      final member = await ds.getStaffMember('store-1', 'staff-1');

      expect(member.id, 'staff-1');
      expect(member.name, 'Ali');
    });

    test('requests the correct endpoint', () async {
      when(() => dio.get<dynamic>(any()))
          .thenAnswer((_) async => resp(validStaffJson()));

      await ds.getStaffMember('store-1', 'staff-9');

      verify(() => dio.get<dynamic>('/stores/store-1/staff/staff-9'))
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
        () => ds.getStaffMember('store-1', 'missing'),
        throwsA(
          isA<ServerException>().having((e) => e.statusCode, 'statusCode', 404),
        ),
      );
    });
  });

  group('StaffRemoteDatasourceImpl.createStaff', () {
    test('posts data and parses the created staff member', () async {
      when(() => dio.post<dynamic>(
            any(),
            data: any(named: 'data'),
          )).thenAnswer((_) async => resp(validStaffJson()));

      final data = {'name': 'Ali', 'role': 'CASHIER'};
      final member = await ds.createStaff('store-1', data);

      expect(member.id, 'staff-1');
      verify(() => dio.post<dynamic>(
            '/stores/store-1/staff',
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
        () => ds.createStaff('store-1', {'name': 'Ali'}),
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
          data: {'message': 'Phone already in use'},
        ),
      ));

      await expectLater(
        () => ds.createStaff('store-1', {'phone': '+992900000000'}),
        throwsA(isA<ServerException>().having(
          (e) => e.message,
          'message',
          'Phone already in use',
        )),
      );
    });
  });

  group('StaffRemoteDatasourceImpl.updateStaff', () {
    test('puts data and parses the updated staff member', () async {
      when(() => dio.put<dynamic>(
            any(),
            data: any(named: 'data'),
          )).thenAnswer((_) async => resp(validStaffJson()));

      final data = {'salary': 1200};
      final member = await ds.updateStaff('store-1', 'staff-1', data);

      expect(member.id, 'staff-1');
      verify(() => dio.put<dynamic>(
            '/stores/store-1/staff/staff-1',
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
        () => ds.updateStaff('store-1', 'staff-1', {'salary': 1}),
        throwsA(isA<UnauthorizedException>()),
      );
    });
  });

  group('StaffRemoteDatasourceImpl.deleteStaff', () {
    test('calls delete on the correct endpoint', () async {
      when(() => dio.delete<dynamic>(any()))
          .thenAnswer((_) async => resp(null));

      await ds.deleteStaff('store-1', 'staff-1');

      verify(() => dio.delete<dynamic>('/stores/store-1/staff/staff-1'))
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
        () => ds.deleteStaff('store-1', 'staff-1'),
        throwsA(isA<ServerException>()),
      );
    });

    test('throws NetworkException on send timeout', () async {
      when(() => dio.delete<dynamic>(any())).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.sendTimeout,
      ));

      expect(
        () => ds.deleteStaff('store-1', 'staff-1'),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  group('StaffRemoteDatasourceImpl.getRoles', () {
    test('parses a bare JSON array of role permissions', () async {
      when(() => dio.get<dynamic>(any())).thenAnswer((_) async => resp([
            {
              'role': 'ADMIN',
              'permissions': {'pos': true, 'reports': true},
            },
            {
              'role': 'CASHIER',
              'permissions': {'pos': true, 'reports': false},
            },
          ]));

      final roles = await ds.getRoles('store-1');

      expect(roles.length, 2);
      expect(roles[0].role, 'ADMIN');
      expect(roles[0].permissions['reports'], isTrue);
      expect(roles[1].role, 'CASHIER');
      expect(roles[1].permissions['reports'], isFalse);
    });

    test('requests the correct endpoint', () async {
      when(() => dio.get<dynamic>(any())).thenAnswer((_) async => resp([]));

      await ds.getRoles('store-1');

      verify(() => dio.get<dynamic>('/stores/store-1/roles')).called(1);
    });

    test('throws NetworkException on connection timeout', () async {
      when(() => dio.get<dynamic>(any())).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.connectionTimeout,
      ));

      expect(() => ds.getRoles('store-1'), throwsA(isA<NetworkException>()));
    });
  });

  group('StaffRemoteDatasourceImpl.getRolePermissions', () {
    test('parses a single role permission response', () async {
      when(() => dio.get<dynamic>(any())).thenAnswer((_) async => resp({
            'role': 'ADMIN',
            'permissions': {'pos': true},
          }));

      final permission = await ds.getRolePermissions('store-1', 'ADMIN');

      expect(permission.role, 'ADMIN');
      expect(permission.permissions['pos'], isTrue);
    });

    test('requests the correct endpoint for storeId/role', () async {
      when(() => dio.get<dynamic>(any())).thenAnswer((_) async => resp({
            'role': 'ADMIN',
            'permissions': <String, dynamic>{},
          }));

      await ds.getRolePermissions('store-1', 'ADMIN');

      verify(() => dio.get<dynamic>('/stores/store-1/roles/ADMIN/permissions'))
          .called(1);
    });

    test('throws ServerException on 404 response', () async {
      when(() => dio.get<dynamic>(any())).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 404,
          data: {'message': 'Role not found'},
        ),
      ));

      expect(
        () => ds.getRolePermissions('store-1', 'MISSING'),
        throwsA(isA<ServerException>()),
      );
    });
  });

  group('StaffRemoteDatasourceImpl.updateRolePermissions', () {
    test('puts permissions wrapped in a "permissions" key and parses the '
        'response', () async {
      when(() => dio.put<dynamic>(
            any(),
            data: any(named: 'data'),
          )).thenAnswer((_) async => resp({
            'role': 'ADMIN',
            'permissions': {'pos': false},
          }));

      final permissions = {'pos': false};
      final result =
          await ds.updateRolePermissions('store-1', 'ADMIN', permissions);

      expect(result.permissions['pos'], isFalse);
      verify(() => dio.put<dynamic>(
            '/stores/store-1/roles/ADMIN/permissions',
            data: {'permissions': permissions},
          )).called(1);
    });

    test('throws ServerException with message from response on 400',
        () async {
      when(() => dio.put<dynamic>(
            any(),
            data: any(named: 'data'),
          )).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 400,
          data: {'message': 'Invalid permission key'},
        ),
      ));

      await expectLater(
        () => ds.updateRolePermissions('store-1', 'ADMIN', {'bad': true}),
        throwsA(isA<ServerException>().having(
          (e) => e.message,
          'message',
          'Invalid permission key',
        )),
      );
    });
  });
}
