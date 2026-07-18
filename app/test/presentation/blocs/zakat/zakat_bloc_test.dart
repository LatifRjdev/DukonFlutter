import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dukonpro/core/errors/exceptions.dart';
import 'package:dukonpro/domain/entities/zakat_calculation.dart';
import 'package:dukonpro/domain/entities/zakat_payment.dart';
import 'package:dukonpro/domain/entities/zakat_settings.dart';
import 'package:dukonpro/domain/repositories/zakat_repository.dart';
import 'package:dukonpro/presentation/blocs/zakat/zakat_bloc.dart';
import 'package:dukonpro/presentation/blocs/zakat/zakat_event.dart';
import 'package:dukonpro/presentation/blocs/zakat/zakat_state.dart';

// Per the "remove client zakatDue validation" fix (server always uses its
// own calculation), the bloc must never re-derive or adjust the amounts
// returned by the repository — it only orchestrates loading/error state
// and passes payloads through untouched. These tests assert pass-through
// behavior in addition to the usual loading/success/error transitions.
class MockZakatRepository extends Mock implements ZakatRepository {}

void main() {
  late MockZakatRepository repository;

  const calculation = ZakatCalculation(
    stockValue: 5000,
    receivables: 300,
    payables: 100,
    netAssets: 5200,
    nisabAmount: 4000,
    zakatDue: 130.5,
    isAboveNisab: true,
  );

  final settings = ZakatSettings(
    id: 'zs-1',
    storeId: 'store-1',
    nisabAmount: 4000,
    cashOnHand: 200,
  );

  final payment1 = ZakatPayment(
    id: 'zp-1',
    storeId: 'store-1',
    amount: 130.5,
    totalAssets: 5200,
    zakatDue: 130.5,
    breakdown: const {},
    paidAt: DateTime.utc(2026, 1, 1),
    createdAt: DateTime.utc(2026, 1, 1),
  );

  final payment2 = ZakatPayment(
    id: 'zp-2',
    storeId: 'store-1',
    amount: 90,
    totalAssets: 3600,
    zakatDue: 90,
    breakdown: const {},
    paidAt: DateTime.utc(2026, 2, 1),
    createdAt: DateTime.utc(2026, 2, 1),
  );

  setUp(() {
    repository = MockZakatRepository();
  });

  test('initial state is ZakatInitial', () {
    final bloc = ZakatBloc(zakatRepository: repository);
    expect(bloc.state, isA<ZakatInitial>());
  });

  group('ZakatCalculateRequested', () {
    blocTest<ZakatBloc, ZakatState>(
      'emits Loading then Calculated with zakatDue taken straight from the '
      'repository (no client-side recomputation)',
      setUp: () {
        when(() => repository.calculate('store-1'))
            .thenAnswer((_) async => calculation);
        when(() => repository.getSettings('store-1'))
            .thenAnswer((_) async => settings);
      },
      build: () => ZakatBloc(zakatRepository: repository),
      act: (bloc) => bloc.add(const ZakatCalculateRequested(storeId: 'store-1')),
      expect: () => [
        isA<ZakatLoading>(),
        predicate<ZakatState>((s) =>
            s is ZakatCalculated &&
            s.calculation.zakatDue == 130.5 &&
            identical(s.calculation, calculation) &&
            identical(s.settings, settings)),
      ],
    );

    blocTest<ZakatBloc, ZakatState>(
      'emits Loading then Calculated with null settings when settings are absent',
      setUp: () {
        when(() => repository.calculate('store-1'))
            .thenAnswer((_) async => calculation);
        when(() => repository.getSettings('store-1'))
            .thenAnswer((_) async => null);
      },
      build: () => ZakatBloc(zakatRepository: repository),
      act: (bloc) => bloc.add(const ZakatCalculateRequested(storeId: 'store-1')),
      expect: () => [
        isA<ZakatLoading>(),
        predicate<ZakatState>((s) => s is ZakatCalculated && s.settings == null),
      ],
    );

    blocTest<ZakatBloc, ZakatState>(
      'emits Loading then Error with a mapped message on NetworkException',
      setUp: () {
        when(() => repository.calculate('store-1'))
            .thenThrow(const NetworkException());
      },
      build: () => ZakatBloc(zakatRepository: repository),
      act: (bloc) => bloc.add(const ZakatCalculateRequested(storeId: 'store-1')),
      expect: () => [
        isA<ZakatLoading>(),
        const ZakatError('Нет подключения к интернету'),
      ],
    );

    blocTest<ZakatBloc, ZakatState>(
      'never leaks raw exception text into ZakatError.message',
      setUp: () {
        when(() => repository.calculate('store-1')).thenThrow(
          Exception('DioException [bad response]: http://10.0.2.2:4455/zakat'),
        );
      },
      build: () => ZakatBloc(zakatRepository: repository),
      act: (bloc) => bloc.add(const ZakatCalculateRequested(storeId: 'store-1')),
      expect: () => [
        isA<ZakatLoading>(),
        predicate<ZakatState>((s) {
          if (s is! ZakatError) return false;
          return !s.message.contains('10.0.2.2') &&
              !s.message.contains('DioException') &&
              s.message.isNotEmpty;
        }, 'error set but no leaky internal text'),
      ],
    );
  });

  group('ZakatSettingsRequested', () {
    blocTest<ZakatBloc, ZakatState>(
      'emits Loading then SettingsLoaded when settings exist',
      setUp: () {
        when(() => repository.getSettings('store-1'))
            .thenAnswer((_) async => settings);
      },
      build: () => ZakatBloc(zakatRepository: repository),
      act: (bloc) => bloc.add(const ZakatSettingsRequested(storeId: 'store-1')),
      expect: () => [
        isA<ZakatLoading>(),
        ZakatSettingsLoaded(settings),
      ],
    );

    blocTest<ZakatBloc, ZakatState>(
      'emits Loading then Initial when settings are null (not yet configured)',
      setUp: () {
        when(() => repository.getSettings('store-1'))
            .thenAnswer((_) async => null);
      },
      build: () => ZakatBloc(zakatRepository: repository),
      act: (bloc) => bloc.add(const ZakatSettingsRequested(storeId: 'store-1')),
      expect: () => [
        isA<ZakatLoading>(),
        isA<ZakatInitial>(),
      ],
    );

    blocTest<ZakatBloc, ZakatState>(
      'emits Loading then Error on repository failure',
      setUp: () {
        when(() => repository.getSettings('store-1'))
            .thenThrow(const ServerException('boom', statusCode: 500));
      },
      build: () => ZakatBloc(zakatRepository: repository),
      act: (bloc) => bloc.add(const ZakatSettingsRequested(storeId: 'store-1')),
      expect: () => [
        isA<ZakatLoading>(),
        const ZakatError('Ошибка сервера — попробуйте позже'),
      ],
    );
  });

  group('ZakatSettingsUpdated', () {
    blocTest<ZakatBloc, ZakatState>(
      'forwards data unmodified and emits ActionSuccess on save',
      setUp: () {
        when(() => repository.upsertSettings('store-1', any()))
            .thenAnswer((_) async => settings);
      },
      build: () => ZakatBloc(zakatRepository: repository),
      act: (bloc) => bloc.add(const ZakatSettingsUpdated(
        storeId: 'store-1',
        data: {'cashOnHand': 500},
      )),
      expect: () => [
        isA<ZakatLoading>(),
        const ZakatActionSuccess('Настройки закята сохранены'),
      ],
      verify: (_) {
        final captured = verify(() => repository.upsertSettings(
              'store-1',
              captureAny(),
            )).captured;
        // The bloc must pass the settings payload through untouched — no
        // client-side validation or recalculation of nisab/zakat fields.
        expect(captured.single, {'cashOnHand': 500});
      },
    );

    blocTest<ZakatBloc, ZakatState>(
      'emits Loading then Error when saving settings fails',
      setUp: () {
        when(() => repository.upsertSettings('store-1', any()))
            .thenThrow(const NetworkException());
      },
      build: () => ZakatBloc(zakatRepository: repository),
      act: (bloc) => bloc.add(const ZakatSettingsUpdated(
        storeId: 'store-1',
        data: {'cashOnHand': 500},
      )),
      expect: () => [
        isA<ZakatLoading>(),
        const ZakatError('Нет подключения к интернету'),
      ],
    );
  });

  group('ZakatPaymentSubmitted', () {
    blocTest<ZakatBloc, ZakatState>(
      'forwards data unmodified (including server-facing zakatDue) and '
      'emits ActionSuccess',
      setUp: () {
        when(() => repository.createPayment('store-1', any()))
            .thenAnswer((_) async => payment1);
      },
      build: () => ZakatBloc(zakatRepository: repository),
      act: (bloc) => bloc.add(const ZakatPaymentSubmitted(
        storeId: 'store-1',
        data: {'amount': 130.5, 'notes': 'Ramadan'},
      )),
      expect: () => [
        isA<ZakatLoading>(),
        const ZakatActionSuccess('Выплата закята записана'),
      ],
      verify: (_) {
        final captured = verify(() => repository.createPayment(
              'store-1',
              captureAny(),
            )).captured;
        // No client-side recomputation of the payment amount/zakatDue —
        // the bloc is a pure pass-through to the repository.
        expect(captured.single, {'amount': 130.5, 'notes': 'Ramadan'});
      },
    );

    blocTest<ZakatBloc, ZakatState>(
      'emits Loading then Error when submitting a payment fails',
      setUp: () {
        when(() => repository.createPayment('store-1', any()))
            .thenThrow(const ServerException('conflict', statusCode: 409));
      },
      build: () => ZakatBloc(zakatRepository: repository),
      act: (bloc) => bloc.add(const ZakatPaymentSubmitted(
        storeId: 'store-1',
        data: {'amount': 130.5},
      )),
      expect: () => [
        isA<ZakatLoading>(),
        const ZakatError('Конфликт — объект уже существует'),
      ],
    );
  });

  group('ZakatPaymentsRequested', () {
    blocTest<ZakatBloc, ZakatState>(
      'first page: emits Loading then PaymentsLoaded with pagination metadata',
      setUp: () {
        when(() => repository.getPayments(
              'store-1',
              page: 1,
              limit: 20,
            )).thenAnswer((_) async => (
              data: [payment1],
              total: 3,
              totalPages: 2,
              currentPage: 1,
            ));
      },
      build: () => ZakatBloc(zakatRepository: repository),
      act: (bloc) => bloc.add(const ZakatPaymentsRequested(storeId: 'store-1')),
      expect: () => [
        isA<ZakatLoading>(),
        predicate<ZakatState>((s) =>
            s is ZakatPaymentsLoaded &&
            s.payments.length == 1 &&
            s.total == 3 &&
            s.totalPages == 2 &&
            s.currentPage == 1 &&
            s.hasMore),
      ],
    );

    blocTest<ZakatBloc, ZakatState>(
      'load-more (page > 1 from a loaded list) appends without re-emitting '
      'Loading and does not flash the list empty',
      setUp: () {
        when(() => repository.getPayments(
              'store-1',
              page: 2,
              limit: 20,
            )).thenAnswer((_) async => (
              data: [payment2],
              total: 2,
              totalPages: 2,
              currentPage: 2,
            ));
      },
      build: () => ZakatBloc(zakatRepository: repository),
      seed: () => ZakatPaymentsLoaded(
        [payment1],
        total: 2,
        totalPages: 2,
        currentPage: 1,
      ),
      act: (bloc) => bloc.add(const ZakatPaymentsRequested(
        storeId: 'store-1',
        page: 2,
      )),
      expect: () => [
        predicate<ZakatState>((s) =>
            s is ZakatPaymentsLoaded &&
            s.payments.length == 2 &&
            s.payments.first == payment1 &&
            s.payments.last == payment2 &&
            s.currentPage == 2 &&
            !s.hasMore),
      ],
    );

    blocTest<ZakatBloc, ZakatState>(
      'page > 1 without a loaded list first still shows Loading (not treated '
      'as append)',
      setUp: () {
        when(() => repository.getPayments(
              'store-1',
              page: 2,
              limit: 20,
            )).thenAnswer((_) async => (
              data: [payment2],
              total: 2,
              totalPages: 1,
              currentPage: 2,
            ));
      },
      build: () => ZakatBloc(zakatRepository: repository),
      act: (bloc) => bloc.add(const ZakatPaymentsRequested(
        storeId: 'store-1',
        page: 2,
      )),
      expect: () => [
        isA<ZakatLoading>(),
        predicate<ZakatState>((s) =>
            s is ZakatPaymentsLoaded && s.payments.single == payment2),
      ],
    );

    blocTest<ZakatBloc, ZakatState>(
      'emits Loading then Error when fetching the first page fails',
      setUp: () {
        when(() => repository.getPayments(
              'store-1',
              page: 1,
              limit: 20,
            )).thenThrow(const NetworkException());
      },
      build: () => ZakatBloc(zakatRepository: repository),
      act: (bloc) => bloc.add(const ZakatPaymentsRequested(storeId: 'store-1')),
      expect: () => [
        isA<ZakatLoading>(),
        const ZakatError('Нет подключения к интернету'),
      ],
    );
  });
}
