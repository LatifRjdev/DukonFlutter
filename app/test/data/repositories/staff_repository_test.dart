import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dukonpro/core/errors/exceptions.dart';
import 'package:dukonpro/data/datasources/remote/staff_remote_datasource.dart';
import 'package:dukonpro/data/repositories/staff_repository_impl.dart';
import 'package:dukonpro/domain/entities/role_permission.dart';
import 'package:dukonpro/domain/entities/staff_member.dart';

class _MockStaffRemoteDatasource extends Mock
    implements StaffRemoteDatasource {}

void main() {
  late StaffRepositoryImpl repo;
  late _MockStaffRemoteDatasource remote;

  StaffMember mkStaff({String id = 'staff-1', String role = 'CASHIER'}) =>
      StaffMember(
        id: id,
        storeId: 'store-1',
        name: 'Ali',
        role: role,
        createdAt: DateTime(2026, 4, 11),
      );

  setUp(() {
    remote = _MockStaffRemoteDatasource();
    repo = StaffRepositoryImpl(remoteDatasource: remote);
  });

  group('StaffRepositoryImpl.getStaff', () {
    test('delegates to remote datasource and returns its result', () async {
      final staffList = [mkStaff()];
      when(() => remote.getStaff(
            any(),
            page: any(named: 'page'),
            search: any(named: 'search'),
            role: any(named: 'role'),
          )).thenAnswer((_) async => (
            data: staffList,
            total: 1,
            totalPages: 1,
          ));

      final result = await repo.getStaff('store-1');

      expect(result.data, staffList);
      expect(result.total, 1);
      expect(result.totalPages, 1);
    });

    test('passes storeId/page/search/role through unchanged', () async {
      when(() => remote.getStaff(
            any(),
            page: any(named: 'page'),
            search: any(named: 'search'),
            role: any(named: 'role'),
          )).thenAnswer((_) async => (
            data: <StaffMember>[],
            total: 0,
            totalPages: 0,
          ));

      await repo.getStaff('store-9', page: 2, search: 'ali', role: 'ADMIN');

      verify(() => remote.getStaff(
            'store-9',
            page: 2,
            search: 'ali',
            role: 'ADMIN',
          )).called(1);
    });

    test('defaults page to 1 when not supplied', () async {
      when(() => remote.getStaff(
            any(),
            page: any(named: 'page'),
            search: any(named: 'search'),
            role: any(named: 'role'),
          )).thenAnswer((_) async => (
            data: <StaffMember>[],
            total: 0,
            totalPages: 0,
          ));

      await repo.getStaff('store-1');

      verify(() => remote.getStaff(
            'store-1',
            page: 1,
            search: null,
            role: null,
          )).called(1);
    });

    test('propagates NetworkException from the remote datasource', () async {
      when(() => remote.getStaff(
            any(),
            page: any(named: 'page'),
            search: any(named: 'search'),
            role: any(named: 'role'),
          )).thenThrow(const NetworkException());

      expect(() => repo.getStaff('store-1'), throwsA(isA<NetworkException>()));
    });
  });

  group('StaffRepositoryImpl.getStaffMember', () {
    test('delegates to remote datasource and returns its result', () async {
      final member = mkStaff(id: 'staff-9');
      when(() => remote.getStaffMember(any(), any()))
          .thenAnswer((_) async => member);

      final result = await repo.getStaffMember('store-1', 'staff-9');

      expect(result, member);
      verify(() => remote.getStaffMember('store-1', 'staff-9')).called(1);
    });

    test('propagates ServerException with statusCode', () async {
      when(() => remote.getStaffMember(any(), any())).thenThrow(
        const ServerException('Not found', statusCode: 404),
      );

      expect(
        () => repo.getStaffMember('store-1', 'missing'),
        throwsA(isA<ServerException>()
            .having((e) => e.statusCode, 'statusCode', 404)),
      );
    });
  });

  group('StaffRepositoryImpl.createStaff', () {
    test('delegates to remote datasource with the given payload', () async {
      final created = mkStaff(id: 'new-id');
      final data = {'name': 'New', 'role': 'CASHIER'};
      when(() => remote.createStaff(any(), any()))
          .thenAnswer((_) async => created);

      final result = await repo.createStaff('store-1', data);

      expect(result, created);
      verify(() => remote.createStaff('store-1', data)).called(1);
    });

    test('propagates UnauthorizedException from the remote datasource',
        () async {
      when(() => remote.createStaff(any(), any()))
          .thenThrow(const UnauthorizedException());

      expect(
        () => repo.createStaff('store-1', {'name': 'x'}),
        throwsA(isA<UnauthorizedException>()),
      );
    });
  });

  group('StaffRepositoryImpl.updateStaff', () {
    test('delegates to remote datasource with storeId/id/payload', () async {
      final updated = mkStaff(id: 'staff-1');
      final data = {'name': 'Updated'};
      when(() => remote.updateStaff(any(), any(), any()))
          .thenAnswer((_) async => updated);

      final result = await repo.updateStaff('store-1', 'staff-1', data);

      expect(result, updated);
      verify(() => remote.updateStaff('store-1', 'staff-1', data)).called(1);
    });

    test('propagates ServerException from the remote datasource', () async {
      when(() => remote.updateStaff(any(), any(), any())).thenThrow(
        const ServerException('boom', statusCode: 500),
      );

      expect(
        () => repo.updateStaff('store-1', 'staff-1', {'name': 'x'}),
        throwsA(isA<ServerException>()),
      );
    });
  });

  group('StaffRepositoryImpl.deleteStaff', () {
    test('delegates to remote datasource', () async {
      when(() => remote.deleteStaff(any(), any())).thenAnswer((_) async {});

      await repo.deleteStaff('store-1', 'staff-1');

      verify(() => remote.deleteStaff('store-1', 'staff-1')).called(1);
    });

    test('propagates NetworkException from the remote datasource', () async {
      when(() => remote.deleteStaff(any(), any()))
          .thenThrow(const NetworkException());

      expect(
        () => repo.deleteStaff('store-1', 'staff-1'),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  group('StaffRepositoryImpl.getRoles', () {
    test('delegates to remote datasource and returns its result', () async {
      const roles = [
        RolePermission(role: 'ADMIN', permissions: {'pos': true}),
        RolePermission(role: 'CASHIER', permissions: {'pos': true}),
      ];
      when(() => remote.getRoles(any())).thenAnswer((_) async => roles);

      final result = await repo.getRoles('store-1');

      expect(result, roles);
      verify(() => remote.getRoles('store-1')).called(1);
    });

    test('propagates NetworkException from the remote datasource', () async {
      when(() => remote.getRoles(any())).thenThrow(const NetworkException());

      expect(() => repo.getRoles('store-1'), throwsA(isA<NetworkException>()));
    });
  });

  group('StaffRepositoryImpl.getRolePermissions', () {
    test('delegates to remote datasource with storeId/role', () async {
      const permission =
          RolePermission(role: 'ADMIN', permissions: {'pos': true});
      when(() => remote.getRolePermissions(any(), any()))
          .thenAnswer((_) async => permission);

      final result = await repo.getRolePermissions('store-1', 'ADMIN');

      expect(result, permission);
      verify(() => remote.getRolePermissions('store-1', 'ADMIN')).called(1);
    });
  });

  group('StaffRepositoryImpl.updateRolePermissions', () {
    test('delegates to remote datasource with storeId/role/permissions',
        () async {
      const updated =
          RolePermission(role: 'ADMIN', permissions: {'pos': false});
      const permissions = {'pos': false};
      when(() => remote.updateRolePermissions(any(), any(), any()))
          .thenAnswer((_) async => updated);

      final result =
          await repo.updateRolePermissions('store-1', 'ADMIN', permissions);

      expect(result, updated);
      verify(() => remote.updateRolePermissions(
            'store-1',
            'ADMIN',
            permissions,
          )).called(1);
    });

    test('propagates ServerException from the remote datasource', () async {
      when(() => remote.updateRolePermissions(any(), any(), any())).thenThrow(
        const ServerException('boom', statusCode: 400),
      );

      expect(
        () => repo.updateRolePermissions('store-1', 'ADMIN', {'pos': false}),
        throwsA(isA<ServerException>()),
      );
    });
  });
}
