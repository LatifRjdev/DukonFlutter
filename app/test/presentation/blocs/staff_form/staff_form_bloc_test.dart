import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dukonpro/core/errors/exceptions.dart';
import 'package:dukonpro/domain/entities/staff_member.dart';
import 'package:dukonpro/domain/repositories/staff_repository.dart';
import 'package:dukonpro/presentation/blocs/staff_form/staff_form_bloc.dart';
import 'package:dukonpro/presentation/blocs/staff_form/staff_form_event.dart';
import 'package:dukonpro/presentation/blocs/staff_form/staff_form_state.dart';

class MockStaffRepository extends Mock implements StaffRepository {}

void main() {
  late MockStaffRepository repository;

  StaffMember mkStaff({
    String id = 'staff-1',
    String storeId = 'store-1',
    String name = 'Ali',
    String? phone = '+992900000000',
    String role = 'CASHIER',
    double? salary = 1000,
    double? commission = 5,
  }) =>
      StaffMember(
        id: id,
        storeId: storeId,
        name: name,
        phone: phone,
        role: role,
        salary: salary,
        commission: commission,
        createdAt: DateTime(2026, 4, 11),
      );

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    repository = MockStaffRepository();
  });

  group('StaffFormBloc', () {
    test('initial state is StaffFormInitial with empty defaults', () {
      final bloc = StaffFormBloc(staffRepository: repository);
      expect(bloc.state, isA<StaffFormInitial>());
      expect(bloc.state.name, '');
      expect(bloc.state.phone, '');
      expect(bloc.state.role, 'seller');
      expect(bloc.state.isEditing, isFalse);
    });

    group('InitStaffForm', () {
      blocTest<StaffFormBloc, StaffFormState>(
        'seeds the form fields from an existing StaffMember and sets '
        'isEditing/editingId',
        build: () => StaffFormBloc(staffRepository: repository),
        act: (bloc) => bloc.add(InitStaffForm(staffMember: mkStaff())),
        expect: () => [
          predicate<StaffFormState>((s) =>
              s.name == 'Ali' &&
              s.phone == '+992900000000' &&
              s.role == 'CASHIER' &&
              s.salary == 1000 &&
              s.commission == 5 &&
              s.isEditing == true &&
              s.editingId == 'staff-1'),
        ],
      );

      blocTest<StaffFormBloc, StaffFormState>(
        'defaults phone/salary/commission when the member has nulls',
        build: () => StaffFormBloc(staffRepository: repository),
        act: (bloc) => bloc.add(InitStaffForm(
          staffMember: mkStaff(phone: null, salary: null, commission: null),
        )),
        expect: () => [
          predicate<StaffFormState>(
              (s) => s.phone == '' && s.salary == 0 && s.commission == 0),
        ],
      );

      blocTest<StaffFormBloc, StaffFormState>(
        'resets to StaffFormInitial when staffMember is null (add mode)',
        build: () => StaffFormBloc(staffRepository: repository),
        seed: () => StaffFormState(
          name: 'Stale',
          phone: '+992900000001',
          role: 'CASHIER',
          salary: 500,
          commission: 1,
          isEditing: true,
          editingId: 'old-id',
        ),
        act: (bloc) => bloc.add(const InitStaffForm()),
        expect: () => [isA<StaffFormInitial>()],
      );
    });

    group('UpdateField', () {
      blocTest<StaffFormBloc, StaffFormState>(
        'updates name',
        build: () => StaffFormBloc(staffRepository: repository),
        act: (bloc) => bloc.add(const UpdateField(field: 'name', value: 'Bek')),
        expect: () => [predicate<StaffFormState>((s) => s.name == 'Bek')],
      );

      blocTest<StaffFormBloc, StaffFormState>(
        'updates phone',
        build: () => StaffFormBloc(staffRepository: repository),
        act: (bloc) => bloc.add(
          const UpdateField(field: 'phone', value: '+992911111111'),
        ),
        expect: () => [
          predicate<StaffFormState>((s) => s.phone == '+992911111111'),
        ],
      );

      blocTest<StaffFormBloc, StaffFormState>(
        'updates role',
        build: () => StaffFormBloc(staffRepository: repository),
        act: (bloc) => bloc.add(const UpdateField(field: 'role', value: 'ADMIN')),
        expect: () => [predicate<StaffFormState>((s) => s.role == 'ADMIN')],
      );

      blocTest<StaffFormBloc, StaffFormState>(
        'updates salary and coerces an int value to double',
        build: () => StaffFormBloc(staffRepository: repository),
        act: (bloc) => bloc.add(const UpdateField(field: 'salary', value: 1500)),
        expect: () => [
          predicate<StaffFormState>((s) => s.salary == 1500.0),
        ],
      );

      blocTest<StaffFormBloc, StaffFormState>(
        'updates commission and coerces an int value to double',
        build: () => StaffFormBloc(staffRepository: repository),
        act: (bloc) =>
            bloc.add(const UpdateField(field: 'commission', value: 10)),
        expect: () => [
          predicate<StaffFormState>((s) => s.commission == 10.0),
        ],
      );

      blocTest<StaffFormBloc, StaffFormState>(
        'does not emit for an unrecognized field name',
        build: () => StaffFormBloc(staffRepository: repository),
        act: (bloc) =>
            bloc.add(const UpdateField(field: 'unknown', value: 'x')),
        expect: () => <StaffFormState>[],
      );
    });

    group('SubmitStaffForm — create (isEditing=false)', () {
      blocTest<StaffFormBloc, StaffFormState>(
        'emits [StaffFormLoading, StaffFormSuccess] and calls createStaff',
        setUp: () {
          when(() => repository.createStaff(any(), any()))
              .thenAnswer((_) async => mkStaff(id: 'new-id'));
        },
        build: () => StaffFormBloc(staffRepository: repository),
        seed: () => const StaffFormState(name: 'New Staff', role: 'CASHIER'),
        act: (bloc) => bloc.add(SubmitStaffForm(
          storeId: 'store-1',
          data: const {'name': 'New Staff', 'role': 'CASHIER'},
        )),
        expect: () => [
          isA<StaffFormLoading>(),
          isA<StaffFormSuccess>()
              .having((s) => s.savedStaffMember?.id, 'savedStaffMember.id', 'new-id')
              .having((s) => s.isSuccess, 'isSuccess', isTrue),
        ],
        verify: (_) {
          verify(() => repository.createStaff(
                'store-1',
                {'name': 'New Staff', 'role': 'CASHIER'},
              )).called(1);
          verifyNever(() => repository.updateStaff(any(), any(), any()));
        },
      );

      blocTest<StaffFormBloc, StaffFormState>(
        'emits [StaffFormLoading, StaffFormError] with mapped message on '
        'failure',
        setUp: () {
          when(() => repository.createStaff(any(), any()))
              .thenThrow(const ServerException('bad', statusCode: 400));
        },
        build: () => StaffFormBloc(staffRepository: repository),
        act: (bloc) => bloc.add(SubmitStaffForm(
          storeId: 'store-1',
          data: const {'name': ''},
        )),
        expect: () => [
          isA<StaffFormLoading>(),
          isA<StaffFormError>().having(
            (s) => s.errorMessage,
            'errorMessage',
            'Некорректные данные',
          ),
        ],
      );
    });

    group('SubmitStaffForm — edit (isEditing=true)', () {
      blocTest<StaffFormBloc, StaffFormState>(
        'calls updateStaff with editingId when isEditing and editingId are set',
        setUp: () {
          when(() => repository.updateStaff(any(), any(), any()))
              .thenAnswer((_) async => mkStaff(id: 'staff-1', name: 'Updated'));
        },
        build: () => StaffFormBloc(staffRepository: repository),
        seed: () => const StaffFormState(
          name: 'Updated',
          role: 'CASHIER',
          isEditing: true,
          editingId: 'staff-1',
        ),
        act: (bloc) => bloc.add(SubmitStaffForm(
          storeId: 'store-1',
          data: const {'name': 'Updated'},
        )),
        expect: () => [
          isA<StaffFormLoading>(),
          isA<StaffFormSuccess>().having(
            (s) => s.savedStaffMember?.name,
            'savedStaffMember.name',
            'Updated',
          ),
        ],
        verify: (_) {
          verify(() => repository.updateStaff(
                'store-1',
                'staff-1',
                {'name': 'Updated'},
              )).called(1);
          verifyNever(() => repository.createStaff(any(), any()));
        },
      );

      blocTest<StaffFormBloc, StaffFormState>(
        'falls back to createStaff when isEditing is true but editingId is null',
        setUp: () {
          when(() => repository.createStaff(any(), any()))
              .thenAnswer((_) async => mkStaff(id: 'new-id'));
        },
        build: () => StaffFormBloc(staffRepository: repository),
        seed: () => const StaffFormState(
          name: 'Weird',
          role: 'CASHIER',
          isEditing: true,
        ),
        act: (bloc) => bloc.add(SubmitStaffForm(
          storeId: 'store-1',
          data: const {'name': 'Weird'},
        )),
        expect: () => [
          isA<StaffFormLoading>(),
          isA<StaffFormSuccess>(),
        ],
        verify: (_) {
          verify(() => repository.createStaff(any(), any())).called(1);
          verifyNever(() => repository.updateStaff(any(), any(), any()));
        },
      );

      blocTest<StaffFormBloc, StaffFormState>(
        'emits StaffFormError with mapped message when updateStaff throws '
        'NetworkException',
        setUp: () {
          when(() => repository.updateStaff(any(), any(), any()))
              .thenThrow(const NetworkException());
        },
        build: () => StaffFormBloc(staffRepository: repository),
        seed: () => const StaffFormState(
          name: 'Updated',
          role: 'CASHIER',
          isEditing: true,
          editingId: 'staff-1',
        ),
        act: (bloc) => bloc.add(SubmitStaffForm(
          storeId: 'store-1',
          data: const {'name': 'Updated'},
        )),
        expect: () => [
          isA<StaffFormLoading>(),
          isA<StaffFormError>().having(
            (s) => s.errorMessage,
            'errorMessage',
            'Нет подключения к интернету',
          ),
        ],
      );
    });
  });
}
