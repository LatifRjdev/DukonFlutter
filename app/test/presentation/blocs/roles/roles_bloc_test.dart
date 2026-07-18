import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dukonpro/core/errors/exceptions.dart';
import 'package:dukonpro/domain/entities/role_permission.dart';
import 'package:dukonpro/domain/repositories/staff_repository.dart';
import 'package:dukonpro/presentation/blocs/roles/roles_bloc.dart';
import 'package:dukonpro/presentation/blocs/roles/roles_event.dart';
import 'package:dukonpro/presentation/blocs/roles/roles_state.dart';

class MockStaffRepository extends Mock implements StaffRepository {}

void main() {
  late MockStaffRepository repository;

  const cashierRole = RolePermission(
    role: 'CASHIER',
    permissions: {'canViewSales': true, 'canEditProducts': false},
  );
  const ownerRole = RolePermission(
    role: 'OWNER',
    permissions: {'canViewSales': true, 'canEditProducts': true},
  );

  setUpAll(() {
    registerFallbackValue(<String, bool>{});
  });

  setUp(() {
    repository = MockStaffRepository();
  });

  group('RolesBloc', () {
    test('initial state is RolesInitial', () {
      final bloc = RolesBloc(staffRepository: repository);
      expect(bloc.state, isA<RolesInitial>());
    });

    group('LoadRoles', () {
      blocTest<RolesBloc, RolesState>(
        'emits [RolesLoading, RolesLoaded] on success',
        setUp: () {
          when(() => repository.getRoles('store-1'))
              .thenAnswer((_) async => [cashierRole, ownerRole]);
        },
        build: () => RolesBloc(staffRepository: repository),
        act: (bloc) => bloc.add(const LoadRoles(storeId: 'store-1')),
        expect: () => [
          isA<RolesLoading>(),
          isA<RolesLoaded>().having(
            (s) => s.roles,
            'roles',
            [cashierRole, ownerRole],
          ),
        ],
        verify: (_) {
          verify(() => repository.getRoles('store-1')).called(1);
        },
      );

      blocTest<RolesBloc, RolesState>(
        'emits [RolesLoading, RolesLoaded] with empty list when repository returns none',
        setUp: () {
          when(() => repository.getRoles('store-1'))
              .thenAnswer((_) async => []);
        },
        build: () => RolesBloc(staffRepository: repository),
        act: (bloc) => bloc.add(const LoadRoles(storeId: 'store-1')),
        expect: () => [
          isA<RolesLoading>(),
          isA<RolesLoaded>().having((s) => s.roles, 'roles', isEmpty),
        ],
      );

      blocTest<RolesBloc, RolesState>(
        'emits [RolesLoading, RolesError] with offline message on NetworkException',
        setUp: () {
          when(() => repository.getRoles('store-1'))
              .thenThrow(const NetworkException());
        },
        build: () => RolesBloc(staffRepository: repository),
        act: (bloc) => bloc.add(const LoadRoles(storeId: 'store-1')),
        expect: () => [
          isA<RolesLoading>(),
          isA<RolesError>().having(
            (s) => s.message,
            'message',
            'Нет подключения к интернету',
          ),
        ],
      );

      blocTest<RolesBloc, RolesState>(
        'emits [RolesLoading, RolesError] with generic message on unknown exception '
        '(never leaks raw exception text)',
        setUp: () {
          when(() => repository.getRoles('store-1')).thenThrow(
            Exception('DioException [bad response]: http://10.0.2.2:4455/roles'),
          );
        },
        build: () => RolesBloc(staffRepository: repository),
        act: (bloc) => bloc.add(const LoadRoles(storeId: 'store-1')),
        expect: () => [
          isA<RolesLoading>(),
          isA<RolesError>().having(
            (s) => s.message,
            'message',
            isNot(contains('DioException')),
          ),
        ],
      );

      blocTest<RolesBloc, RolesState>(
        'emits [RolesLoading, RolesError] with permission-denied message on 403 ServerException',
        setUp: () {
          when(() => repository.getRoles('store-1')).thenThrow(
            const ServerException('Forbidden', statusCode: 403),
          );
        },
        build: () => RolesBloc(staffRepository: repository),
        act: (bloc) => bloc.add(const LoadRoles(storeId: 'store-1')),
        expect: () => [
          isA<RolesLoading>(),
          isA<RolesError>()
              .having((s) => s.message, 'message', 'Недостаточно прав'),
        ],
      );
    });

    group('UpdatePermission', () {
      blocTest<RolesBloc, RolesState>(
        'updates only the matching role permission, leaves other roles untouched',
        build: () => RolesBloc(staffRepository: repository),
        seed: () => const RolesLoaded(roles: [cashierRole, ownerRole]),
        act: (bloc) => bloc.add(const UpdatePermission(
          storeId: 'store-1',
          role: 'CASHIER',
          permission: 'canEditProducts',
          value: true,
        )),
        expect: () => [
          isA<RolesLoaded>().having(
            (s) => s.roles,
            'roles',
            [
              const RolePermission(
                role: 'CASHIER',
                permissions: {'canViewSales': true, 'canEditProducts': true},
              ),
              ownerRole,
            ],
          ),
        ],
        verify: (_) {
          // Purely local state mutation — no network call should happen.
          verifyNever(() => repository.updateRolePermissions(any(), any(), any()));
        },
      );

      blocTest<RolesBloc, RolesState>(
        'adds a brand-new permission key when it does not yet exist on the role',
        build: () => RolesBloc(staffRepository: repository),
        seed: () => const RolesLoaded(roles: [cashierRole]),
        act: (bloc) => bloc.add(const UpdatePermission(
          storeId: 'store-1',
          role: 'CASHIER',
          permission: 'canRefund',
          value: true,
        )),
        expect: () => [
          isA<RolesLoaded>().having(
            (s) => s.roles.single.permissions,
            'permissions',
            {'canViewSales': true, 'canEditProducts': false, 'canRefund': true},
          ),
        ],
      );

      blocTest<RolesBloc, RolesState>(
        'is a no-op when current state is not RolesLoaded',
        build: () => RolesBloc(staffRepository: repository),
        seed: () => RolesLoading(),
        act: (bloc) => bloc.add(const UpdatePermission(
          storeId: 'store-1',
          role: 'CASHIER',
          permission: 'canEditProducts',
          value: true,
        )),
        expect: () => <RolesState>[],
      );

      blocTest<RolesBloc, RolesState>(
        'targeting a role not present in the loaded list leaves all roles unchanged '
        '(no state emitted since the resulting list is equal to the seeded one)',
        build: () => RolesBloc(staffRepository: repository),
        seed: () => const RolesLoaded(roles: [cashierRole]),
        act: (bloc) => bloc.add(const UpdatePermission(
          storeId: 'store-1',
          role: 'ADMIN',
          permission: 'canEditProducts',
          value: true,
        )),
        expect: () => <RolesState>[],
        verify: (bloc) {
          expect(
            (bloc.state as RolesLoaded).roles,
            [cashierRole],
          );
        },
      );
    });

    group('SavePermissions', () {
      blocTest<RolesBloc, RolesState>(
        'saves then reloads roles, ending on RolesLoaded with fresh data',
        setUp: () {
          when(() => repository.updateRolePermissions(
                'store-1',
                'CASHIER',
                {'canViewSales': true, 'canEditProducts': true},
              )).thenAnswer((_) async => cashierRole);
          when(() => repository.getRoles('store-1'))
              .thenAnswer((_) async => [cashierRole, ownerRole]);
        },
        build: () => RolesBloc(staffRepository: repository),
        act: (bloc) => bloc.add(const SavePermissions(
          storeId: 'store-1',
          role: 'CASHIER',
          permissions: {'canViewSales': true, 'canEditProducts': true},
        )),
        // The internal add(LoadRoles(...)) also emits RolesLoading() first,
        // but Bloc's emit() no-ops when the new state equals the current
        // state (Equatable), so the second RolesLoading() is swallowed —
        // only one RolesLoading is observed on the stream.
        expect: () => [
          isA<RolesLoading>(),
          isA<RolesLoaded>().having(
            (s) => s.roles,
            'roles',
            [cashierRole, ownerRole],
          ),
        ],
        verify: (_) {
          verify(() => repository.updateRolePermissions(
                'store-1',
                'CASHIER',
                {'canViewSales': true, 'canEditProducts': true},
              )).called(1);
          verify(() => repository.getRoles('store-1')).called(1);
        },
      );

      blocTest<RolesBloc, RolesState>(
        'emits [RolesLoading, RolesError] and does not reload when save fails',
        setUp: () {
          when(() => repository.updateRolePermissions(any(), any(), any()))
              .thenThrow(const ServerException('boom', statusCode: 500));
        },
        build: () => RolesBloc(staffRepository: repository),
        act: (bloc) => bloc.add(const SavePermissions(
          storeId: 'store-1',
          role: 'CASHIER',
          permissions: {'canViewSales': true},
        )),
        expect: () => [
          isA<RolesLoading>(),
          isA<RolesError>().having(
            (s) => s.message,
            'message',
            'Ошибка сервера — попробуйте позже',
          ),
        ],
        verify: (_) {
          verifyNever(() => repository.getRoles(any()));
        },
      );
    });
  });
}
