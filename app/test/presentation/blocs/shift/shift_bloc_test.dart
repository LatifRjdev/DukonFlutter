import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dukonpro/core/errors/exceptions.dart';
import 'package:dukonpro/domain/entities/shift.dart';
import 'package:dukonpro/domain/entities/z_report.dart';
import 'package:dukonpro/domain/repositories/shift_repository.dart';
import 'package:dukonpro/presentation/blocs/shift/shift_bloc.dart';
import 'package:dukonpro/presentation/blocs/shift/shift_event.dart';
import 'package:dukonpro/presentation/blocs/shift/shift_state.dart';

class MockShiftRepository extends Mock implements ShiftRepository {}

void main() {
  late MockShiftRepository repository;

  ShiftModel shift({String status = 'OPEN', String id = 'shift-1'}) =>
      ShiftModel(
        id: id,
        storeId: 's1',
        staffId: 'staff-1',
        openedAt: DateTime(2026, 7, 17, 8),
        openingCash: 500,
        status: status,
      );

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    repository = MockShiftRepository();
  });

  group('ShiftBloc', () {
    test('initial state is ShiftInitial', () {
      final bloc = ShiftBloc(shiftRepository: repository);
      expect(bloc.state, isA<ShiftInitial>());
    });

    group('LoadCurrentShift', () {
      blocTest<ShiftBloc, ShiftState>(
        'emits [ShiftLoading, ShiftLoaded] with the current shift on success',
        setUp: () {
          when(() => repository.getCurrentShift(any()))
              .thenAnswer((_) async => shift());
        },
        build: () => ShiftBloc(shiftRepository: repository),
        act: (bloc) => bloc.add(const LoadCurrentShift(storeId: 's1')),
        expect: () => [
          isA<ShiftLoading>(),
          isA<ShiftLoaded>()
              .having((s) => s.currentShift?.id, 'currentShift.id', 'shift-1'),
        ],
      );

      blocTest<ShiftBloc, ShiftState>(
        'emits ShiftLoaded with currentShift=null when no shift is open',
        setUp: () {
          when(() => repository.getCurrentShift(any()))
              .thenAnswer((_) async => null);
        },
        build: () => ShiftBloc(shiftRepository: repository),
        act: (bloc) => bloc.add(const LoadCurrentShift(storeId: 's1')),
        expect: () => [
          isA<ShiftLoading>(),
          isA<ShiftLoaded>().having(
              (s) => s.currentShift, 'currentShift', isNull),
        ],
      );

      blocTest<ShiftBloc, ShiftState>(
        'emits [ShiftLoading, ShiftError] with offline message on '
        'NetworkException',
        setUp: () {
          when(() => repository.getCurrentShift(any()))
              .thenThrow(const NetworkException());
        },
        build: () => ShiftBloc(shiftRepository: repository),
        act: (bloc) => bloc.add(const LoadCurrentShift(storeId: 's1')),
        expect: () => [
          isA<ShiftLoading>(),
          isA<ShiftError>().having(
              (s) => s.message, 'message', 'Нет подключения к интернету'),
        ],
      );
    });

    group('OpenShift', () {
      blocTest<ShiftBloc, ShiftState>(
        'emits [ShiftLoading, ShiftOpened] on success and forwards '
        'openingCash to the repository',
        setUp: () {
          when(() => repository.openShift(any(), any()))
              .thenAnswer((_) async => shift());
        },
        build: () => ShiftBloc(shiftRepository: repository),
        act: (bloc) =>
            bloc.add(const OpenShift(storeId: 's1', openingCash: 500)),
        expect: () => [
          isA<ShiftLoading>(),
          isA<ShiftOpened>().having((s) => s.shift.id, 'shift.id', 'shift-1'),
        ],
        verify: (_) {
          final captured = verify(
            () => repository.openShift('s1', captureAny()),
          ).captured;
          final payload = captured.single as Map<String, dynamic>;
          expect(payload['openingCash'], 500);
        },
      );

      blocTest<ShiftBloc, ShiftState>(
        'emits ShiftError with a conflict message when a shift is already '
        'open (409)',
        setUp: () {
          when(() => repository.openShift(any(), any())).thenThrow(
            const ServerException('Shift already open', statusCode: 409),
          );
        },
        build: () => ShiftBloc(shiftRepository: repository),
        act: (bloc) =>
            bloc.add(const OpenShift(storeId: 's1', openingCash: 500)),
        expect: () => [
          isA<ShiftLoading>(),
          isA<ShiftError>().having((s) => s.message, 'message',
              'Конфликт — объект уже существует'),
        ],
      );

      blocTest<ShiftBloc, ShiftState>(
        'never leaks raw exception text into ShiftError.message',
        setUp: () {
          when(() => repository.openShift(any(), any())).thenThrow(
            Exception('DioException [bad response]: http://10.0.2.2:4455'),
          );
        },
        build: () => ShiftBloc(shiftRepository: repository),
        act: (bloc) =>
            bloc.add(const OpenShift(storeId: 's1', openingCash: 500)),
        expect: () => [
          isA<ShiftLoading>(),
          predicate<ShiftState>((s) {
            if (s is! ShiftError) return false;
            return !s.message.contains('10.0.2.2') &&
                !s.message.contains('DioException') &&
                s.message.isNotEmpty;
          }, 'error set but no leaky internal text'),
        ],
      );
    });

    group('CloseShift', () {
      blocTest<ShiftBloc, ShiftState>(
        'emits [ShiftLoading, ShiftClosed] on success and forwards '
        'closingCash to the repository',
        setUp: () {
          when(() => repository.closeShift(any(), any(), any()))
              .thenAnswer((_) async => shift(status: 'CLOSED'));
        },
        build: () => ShiftBloc(shiftRepository: repository),
        act: (bloc) => bloc.add(const CloseShift(
          storeId: 's1',
          shiftId: 'shift-1',
          closingCash: 1200,
        )),
        expect: () => [
          isA<ShiftLoading>(),
          isA<ShiftClosed>()
              .having((s) => s.shift.status, 'shift.status', 'CLOSED'),
        ],
        verify: (_) {
          final captured = verify(
            () => repository.closeShift('s1', 'shift-1', captureAny()),
          ).captured;
          final payload = captured.single as Map<String, dynamic>;
          expect(payload['closingCash'], 1200);
        },
      );

      blocTest<ShiftBloc, ShiftState>(
        'emits ShiftError with an offline message when closing fails due to '
        'no connectivity — the cashier must be told to retry, not silently '
        'lose the close',
        setUp: () {
          when(() => repository.closeShift(any(), any(), any()))
              .thenThrow(const NetworkException());
        },
        build: () => ShiftBloc(shiftRepository: repository),
        act: (bloc) => bloc.add(const CloseShift(
          storeId: 's1',
          shiftId: 'shift-1',
          closingCash: 1200,
        )),
        expect: () => [
          isA<ShiftLoading>(),
          isA<ShiftError>().having(
              (s) => s.message, 'message', 'Нет подключения к интернету'),
        ],
      );

      blocTest<ShiftBloc, ShiftState>(
        'emits ShiftError with server-error message on 500',
        setUp: () {
          when(() => repository.closeShift(any(), any(), any())).thenThrow(
            const ServerException('boom', statusCode: 500),
          );
        },
        build: () => ShiftBloc(shiftRepository: repository),
        act: (bloc) => bloc.add(const CloseShift(
          storeId: 's1',
          shiftId: 'shift-1',
          closingCash: 1200,
        )),
        expect: () => [
          isA<ShiftLoading>(),
          isA<ShiftError>().having((s) => s.message, 'message',
              'Ошибка сервера — попробуйте позже'),
        ],
      );
    });

    group('LoadShifts', () {
      blocTest<ShiftBloc, ShiftState>(
        'emits [ShiftLoading, ShiftLoaded] with shifts/total/totalPages',
        setUp: () {
          when(() => repository.getShifts(
                any(),
                page: any(named: 'page'),
                staffId: any(named: 'staffId'),
                dateFrom: any(named: 'dateFrom'),
                dateTo: any(named: 'dateTo'),
              )).thenAnswer((_) async =>
              (data: [shift(), shift(id: 'shift-2', status: 'CLOSED')],
                total: 2,
                totalPages: 1));
        },
        build: () => ShiftBloc(shiftRepository: repository),
        act: (bloc) => bloc.add(const LoadShifts(storeId: 's1', page: 1)),
        expect: () => [
          isA<ShiftLoading>(),
          isA<ShiftLoaded>()
              .having((s) => s.shifts.length, 'shifts.length', 2)
              .having((s) => s.total, 'total', 2)
              .having((s) => s.totalPages, 'totalPages', 1),
        ],
      );

      blocTest<ShiftBloc, ShiftState>(
        'forwards staffId/date filters and page to the repository',
        setUp: () {
          when(() => repository.getShifts(
                any(),
                page: any(named: 'page'),
                staffId: any(named: 'staffId'),
                dateFrom: any(named: 'dateFrom'),
                dateTo: any(named: 'dateTo'),
              )).thenAnswer((_) async => (data: <ShiftModel>[], total: 0, totalPages: 0));
        },
        build: () => ShiftBloc(shiftRepository: repository),
        act: (bloc) => bloc.add(const LoadShifts(
          storeId: 's1',
          page: 3,
          staffId: 'staff-1',
          dateFrom: '2026-07-01',
          dateTo: '2026-07-31',
        )),
        expect: () => [isA<ShiftLoading>(), isA<ShiftLoaded>()],
        verify: (_) {
          verify(() => repository.getShifts(
                's1',
                page: 3,
                staffId: 'staff-1',
                dateFrom: '2026-07-01',
                dateTo: '2026-07-31',
              )).called(1);
        },
      );

      blocTest<ShiftBloc, ShiftState>(
        'emits ShiftError when the repository throws',
        setUp: () {
          when(() => repository.getShifts(
                any(),
                page: any(named: 'page'),
                staffId: any(named: 'staffId'),
                dateFrom: any(named: 'dateFrom'),
                dateTo: any(named: 'dateTo'),
              )).thenThrow(const ServerException('boom', statusCode: 500));
        },
        build: () => ShiftBloc(shiftRepository: repository),
        act: (bloc) => bloc.add(const LoadShifts(storeId: 's1')),
        expect: () => [isA<ShiftLoading>(), isA<ShiftError>()],
      );
    });

    group('LoadZReport', () {
      ZReport zReport({double difference = 0}) => ZReport(
            staffName: 'Ali',
            openedAt: DateTime(2026, 7, 17, 8),
            closedAt: DateTime(2026, 7, 17, 20),
            duration: '12h',
            expectedCash: 1000,
            actualCash: 1000 + difference,
            difference: difference,
          );

      blocTest<ShiftBloc, ShiftState>(
        'emits [ShiftLoading, ZReportLoaded] on success',
        setUp: () {
          when(() => repository.getZReport(any(), any()))
              .thenAnswer((_) async => zReport());
        },
        build: () => ShiftBloc(shiftRepository: repository),
        act: (bloc) =>
            bloc.add(const LoadZReport(storeId: 's1', shiftId: 'shift-1')),
        expect: () => [
          isA<ShiftLoading>(),
          isA<ZReportLoaded>()
              .having((s) => s.report.staffName, 'report.staffName', 'Ali'),
        ],
      );

      blocTest<ShiftBloc, ShiftState>(
        'carries a cash overage (positive difference) through to the state '
        'unmodified',
        setUp: () {
          when(() => repository.getZReport(any(), any()))
              .thenAnswer((_) async => zReport(difference: 50));
        },
        build: () => ShiftBloc(shiftRepository: repository),
        act: (bloc) =>
            bloc.add(const LoadZReport(storeId: 's1', shiftId: 'shift-1')),
        expect: () => [
          isA<ShiftLoading>(),
          isA<ZReportLoaded>()
              .having((s) => s.report.difference, 'report.difference', 50),
        ],
      );

      blocTest<ShiftBloc, ShiftState>(
        'carries a cash shortage (negative difference) through to the '
        'state unmodified',
        setUp: () {
          when(() => repository.getZReport(any(), any()))
              .thenAnswer((_) async => zReport(difference: -75));
        },
        build: () => ShiftBloc(shiftRepository: repository),
        act: (bloc) =>
            bloc.add(const LoadZReport(storeId: 's1', shiftId: 'shift-1')),
        expect: () => [
          isA<ShiftLoading>(),
          isA<ZReportLoaded>()
              .having((s) => s.report.difference, 'report.difference', -75),
        ],
      );

      blocTest<ShiftBloc, ShiftState>(
        'emits ShiftError when the report cannot be loaded',
        setUp: () {
          when(() => repository.getZReport(any(), any()))
              .thenThrow(const ServerException('not found', statusCode: 404));
        },
        build: () => ShiftBloc(shiftRepository: repository),
        act: (bloc) =>
            bloc.add(const LoadZReport(storeId: 's1', shiftId: 'shift-1')),
        expect: () => [
          isA<ShiftLoading>(),
          isA<ShiftError>()
              .having((s) => s.message, 'message', 'Объект не найден'),
        ],
      );
    });
  });
}
