import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dukonpro/core/errors/exceptions.dart';
import 'package:dukonpro/domain/entities/staff_member.dart';
import 'package:dukonpro/domain/repositories/staff_repository.dart';
import 'package:dukonpro/presentation/blocs/staff/staff_bloc.dart';
import 'package:dukonpro/presentation/blocs/staff/staff_event.dart';
import 'package:dukonpro/presentation/blocs/staff/staff_state.dart';

class MockStaffRepository extends Mock implements StaffRepository {}

void main() {
  late MockStaffRepository repository;

  StaffMember mkStaff({
    String id = 'staff-1',
    String storeId = 'store-1',
    String name = 'Ali',
    String role = 'CASHIER',
  }) =>
      StaffMember(
        id: id,
        storeId: storeId,
        name: name,
        role: role,
        createdAt: DateTime(2026, 4, 11),
      );

  setUp(() {
    repository = MockStaffRepository();
  });

  group('StaffBloc', () {
    test('initial state is StaffInitial', () {
      final bloc = StaffBloc(staffRepository: repository);
      expect(bloc.state, isA<StaffInitial>());
    });

    group('LoadStaff', () {
      blocTest<StaffBloc, StaffState>(
        'emits [StaffLoading, StaffLoaded] on success',
        setUp: () {
          when(() => repository.getStaff(
                any(),
                page: any(named: 'page'),
                search: any(named: 'search'),
                role: any(named: 'role'),
              )).thenAnswer((_) async => (
                data: [mkStaff()],
                total: 1,
                totalPages: 1,
              ));
        },
        build: () => StaffBloc(staffRepository: repository),
        act: (bloc) => bloc.add(const LoadStaff(storeId: 'store-1')),
        expect: () => [
          isA<StaffLoading>(),
          isA<StaffLoaded>()
              .having((s) => s.staff.length, 'staff.length', 1)
              .having((s) => s.total, 'total', 1)
              .having((s) => s.totalPages, 'totalPages', 1),
        ],
      );

      blocTest<StaffBloc, StaffState>(
        'passes page/search/role through to the repository',
        setUp: () {
          when(() => repository.getStaff(
                any(),
                page: any(named: 'page'),
                search: any(named: 'search'),
                role: any(named: 'role'),
              )).thenAnswer((_) async => (
                data: <StaffMember>[],
                total: 0,
                totalPages: 0,
              ));
        },
        build: () => StaffBloc(staffRepository: repository),
        act: (bloc) => bloc.add(const LoadStaff(
          storeId: 'store-9',
          page: 3,
          search: 'ali',
          role: 'CASHIER',
        )),
        verify: (_) {
          verify(() => repository.getStaff(
                'store-9',
                page: 3,
                search: 'ali',
                role: 'CASHIER',
              )).called(1);
        },
      );

      blocTest<StaffBloc, StaffState>(
        'emits [StaffLoading, StaffError] with mapped message on '
        'NetworkException',
        setUp: () {
          when(() => repository.getStaff(
                any(),
                page: any(named: 'page'),
                search: any(named: 'search'),
                role: any(named: 'role'),
              )).thenThrow(const NetworkException());
        },
        build: () => StaffBloc(staffRepository: repository),
        act: (bloc) => bloc.add(const LoadStaff(storeId: 'store-1')),
        expect: () => [
          isA<StaffLoading>(),
          isA<StaffError>().having(
            (s) => s.message,
            'message',
            'Нет подключения к интернету',
          ),
        ],
      );

      blocTest<StaffBloc, StaffState>(
        'never leaks raw exception text into StaffError.message',
        setUp: () {
          when(() => repository.getStaff(
                any(),
                page: any(named: 'page'),
                search: any(named: 'search'),
                role: any(named: 'role'),
              )).thenThrow(
            Exception('DioException [bad response]: http://10.0.2.2:4455/staff'),
          );
        },
        build: () => StaffBloc(staffRepository: repository),
        act: (bloc) => bloc.add(const LoadStaff(storeId: 'store-1')),
        expect: () => [
          isA<StaffLoading>(),
          isA<StaffError>().having(
            (s) => s.message,
            'message',
            isNot(contains('DioException')),
          ),
        ],
      );
    });

    group('LoadStaffDetail', () {
      blocTest<StaffBloc, StaffState>(
        'emits [StaffLoading, StaffDetailLoaded] on success',
        setUp: () {
          when(() => repository.getStaffMember(any(), any()))
              .thenAnswer((_) async => mkStaff(id: 'staff-9'));
        },
        build: () => StaffBloc(staffRepository: repository),
        act: (bloc) => bloc.add(
          const LoadStaffDetail(storeId: 'store-1', id: 'staff-9'),
        ),
        expect: () => [
          isA<StaffLoading>(),
          isA<StaffDetailLoaded>()
              .having((s) => s.staffMember.id, 'staffMember.id', 'staff-9'),
        ],
        verify: (_) {
          verify(() => repository.getStaffMember('store-1', 'staff-9'))
              .called(1);
        },
      );

      blocTest<StaffBloc, StaffState>(
        'emits [StaffLoading, StaffError] on ServerException 404',
        setUp: () {
          when(() => repository.getStaffMember(any(), any())).thenThrow(
            const ServerException('Not found', statusCode: 404),
          );
        },
        build: () => StaffBloc(staffRepository: repository),
        act: (bloc) => bloc.add(
          const LoadStaffDetail(storeId: 'store-1', id: 'missing'),
        ),
        expect: () => [
          isA<StaffLoading>(),
          isA<StaffError>()
              .having((s) => s.message, 'message', 'Объект не найден'),
        ],
      );
    });

    group('DeleteStaff', () {
      blocTest<StaffBloc, StaffState>(
        'deletes then re-triggers LoadStaff for the same store, emitting '
        'StaffLoaded (the second StaffLoading is a no-op: Bloc skips '
        're-emitting an equal consecutive state)',
        setUp: () {
          when(() => repository.deleteStaff(any(), any()))
              .thenAnswer((_) async {});
          when(() => repository.getStaff(
                any(),
                page: any(named: 'page'),
                search: any(named: 'search'),
                role: any(named: 'role'),
              )).thenAnswer((_) async => (
                data: <StaffMember>[],
                total: 0,
                totalPages: 0,
              ));
        },
        build: () => StaffBloc(staffRepository: repository),
        act: (bloc) => bloc.add(
          const DeleteStaff(storeId: 'store-1', id: 'staff-1'),
        ),
        expect: () => [
          isA<StaffLoading>(),
          isA<StaffLoaded>(),
        ],
        verify: (_) {
          verify(() => repository.deleteStaff('store-1', 'staff-1'))
              .called(1);
          verify(() => repository.getStaff(
                'store-1',
                page: 1,
                search: null,
                role: null,
              )).called(1);
        },
      );

      blocTest<StaffBloc, StaffState>(
        'emits [StaffLoading, StaffError] when delete fails and does not '
        'reload the list',
        setUp: () {
          when(() => repository.deleteStaff(any(), any()))
              .thenThrow(const NetworkException());
        },
        build: () => StaffBloc(staffRepository: repository),
        act: (bloc) => bloc.add(
          const DeleteStaff(storeId: 'store-1', id: 'staff-1'),
        ),
        expect: () => [
          isA<StaffLoading>(),
          isA<StaffError>().having(
            (s) => s.message,
            'message',
            'Нет подключения к интернету',
          ),
        ],
        verify: (_) {
          verifyNever(() => repository.getStaff(
                any(),
                page: any(named: 'page'),
                search: any(named: 'search'),
                role: any(named: 'role'),
              ));
        },
      );
    });
  });
}
