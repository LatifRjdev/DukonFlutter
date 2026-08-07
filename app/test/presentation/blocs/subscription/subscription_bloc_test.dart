import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dukonpro/core/errors/exceptions.dart';
import 'package:dukonpro/core/network/dio_client.dart';
import 'package:dukonpro/presentation/blocs/subscription/subscription_bloc.dart';
import 'package:dukonpro/presentation/blocs/subscription/subscription_event.dart';
import 'package:dukonpro/presentation/blocs/subscription/subscription_state.dart';

class _MockDioClient extends Mock implements DioClient {}

void main() {
  late _MockDioClient dioClient;

  Response<dynamic> resp(dynamic body) => Response(
        requestOptions: RequestOptions(path: ''),
        statusCode: 200,
        data: body,
      );

  void mockGet(dynamic body) {
    when(() => dioClient.get<dynamic>(any())).thenAnswer((_) async => resp(body));
  }

  void mockGetError(Object error) {
    when(() => dioClient.get<dynamic>(any())).thenThrow(error);
  }

  setUp(() {
    dioClient = _MockDioClient();
  });

  final fullData = <String, dynamic>{
    'plan': 'BUSINESS',
    'status': 'ACTIVE',
    'expiresAt': '2026-08-01T00:00:00.000Z',
    'trialDaysLeft': 5,
    'adminDiscount': 10.5,
    'limits': {
      'maxStores': 3,
      'maxProducts': 2000,
      'maxStaff': 10,
      'maxDiscounts': 5,
    },
    'features': {
      'hasReportsAll': true,
      'hasExport': true,
      'hasTelegram': false,
      'hasAllPush': true,
      'hasDelivery': false,
      'hasInventory': true,
    },
    'payments': [
      {
        'id': 'p1',
        'plan': 'BUSINESS',
        'amount': 100.0,
        'method': 'CARD',
        'status': 'CONFIRMED',
        'createdAt': '2026-07-01T00:00:00.000Z',
        'receiptUrl': 'http://example.com/receipt.jpg',
      },
    ],
    'pendingPayment': {
      'id': 'p2',
      'plan': 'PREMIUM',
      'amount': 200.0,
      'method': 'CARD',
      'status': 'PENDING',
      'createdAt': '2026-07-10T00:00:00.000Z',
    },
  };

  group('SubscriptionBloc', () {
    test('initial state is SubscriptionInitial', () {
      final bloc = SubscriptionBloc(dioClient: dioClient);
      expect(bloc.state, isA<SubscriptionInitial>());
    });

    group('SubscriptionLoadRequested', () {
      blocTest<SubscriptionBloc, SubscriptionState>(
        'should emit loading then loaded with mapped plan/limits/features/payments when request succeeds',
        setUp: () => mockGet(fullData),
        build: () => SubscriptionBloc(dioClient: dioClient),
        act: (bloc) => bloc.add(const SubscriptionLoadRequested(storeId: 'store-1')),
        expect: () => [
          isA<SubscriptionLoading>(),
          isA<SubscriptionLoaded>()
              .having((s) => s.plan, 'plan', 'BUSINESS')
              .having((s) => s.status, 'status', 'ACTIVE')
              .having((s) => s.trialDaysLeft, 'trialDaysLeft', 5)
              .having((s) => s.adminDiscount, 'adminDiscount', 10.5)
              .having((s) => s.expiresAt, 'expiresAt', DateTime.parse('2026-08-01T00:00:00.000Z'))
              .having((s) => s.limits.maxStores, 'limits.maxStores', 3)
              .having((s) => s.limits.maxProducts, 'limits.maxProducts', 2000)
              .having((s) => s.limits.maxStaff, 'limits.maxStaff', 10)
              .having((s) => s.limits.maxDiscounts, 'limits.maxDiscounts', 5)
              .having((s) => s.features.hasReportsAll, 'features.hasReportsAll', true)
              .having((s) => s.features.hasDelivery, 'features.hasDelivery', false)
              .having((s) => s.payments.length, 'payments.length', 1)
              .having((s) => s.payments.first.id, 'payments.first.id', 'p1')
              .having((s) => s.pendingPayment?.id, 'pendingPayment.id', 'p2')
              .having((s) => s.isActive, 'isActive', true)
              .having((s) => s.isExpired, 'isExpired', false),
        ],
        verify: (_) {
          verify(() => dioClient.get<dynamic>('/stores/store-1/subscription')).called(1);
        },
      );

      blocTest<SubscriptionBloc, SubscriptionState>(
        'should fall back to plan/status/limits/features defaults when response body is empty',
        setUp: () => mockGet(<String, dynamic>{}),
        build: () => SubscriptionBloc(dioClient: dioClient),
        act: (bloc) => bloc.add(const SubscriptionLoadRequested(storeId: 'store-1')),
        expect: () => [
          isA<SubscriptionLoading>(),
          isA<SubscriptionLoaded>()
              .having((s) => s.plan, 'plan', 'START')
              .having((s) => s.status, 'status', 'ACTIVE')
              .having((s) => s.trialDaysLeft, 'trialDaysLeft', isNull)
              .having((s) => s.adminDiscount, 'adminDiscount', isNull)
              .having((s) => s.expiresAt, 'expiresAt', isNull)
              .having((s) => s.limits.maxStores, 'limits.maxStores', 1)
              .having((s) => s.limits.maxProducts, 'limits.maxProducts', 500)
              .having((s) => s.limits.maxStaff, 'limits.maxStaff', 2)
              .having((s) => s.limits.maxDiscounts, 'limits.maxDiscounts', 0)
              .having((s) => s.features.hasReportsAll, 'features.hasReportsAll', false)
              .having((s) => s.payments, 'payments', isEmpty)
              .having((s) => s.pendingPayment, 'pendingPayment', isNull),
        ],
      );

      blocTest<SubscriptionBloc, SubscriptionState>(
        'should treat maxStores of -1 as unlimited without special-casing it away',
        setUp: () => mockGet(<String, dynamic>{
          'plan': 'PREMIUM',
          'limits': {
            'maxStores': -1,
            'maxProducts': -1,
            'maxStaff': -1,
            'maxDiscounts': -1,
          },
        }),
        build: () => SubscriptionBloc(dioClient: dioClient),
        act: (bloc) => bloc.add(const SubscriptionLoadRequested(storeId: 'store-1')),
        expect: () => [
          isA<SubscriptionLoading>(),
          isA<SubscriptionLoaded>()
              .having((s) => s.limits.maxStores, 'limits.maxStores', -1)
              .having((s) => s.limits.maxProducts, 'limits.maxProducts', -1),
        ],
      );

      blocTest<SubscriptionBloc, SubscriptionState>(
        // Regression test for a real production bug: the backend used to
        // nest feature flags under `planConfig` (e.g.
        // planConfig.hasEcommerceIntegration) while this bloc only ever
        // read a top-level `features` object, so every gate silently fell
        // back to SubscriptionFeatures.defaults() (all false) even for
        // paying PREMIUM merchants. This fixture matches the now-fixed
        // backend response shape from SubscriptionsService.getSubscription().
        'parses hasEcommerceIntegration correctly from a realistic /subscription response shape',
        setUp: () => mockGet(<String, dynamic>{
          'plan': 'PREMIUM',
          'status': 'ACTIVE',
          'features': {
            'hasReportsAll': true,
            'hasExport': true,
            'hasTelegram': true,
            'hasAllPush': true,
            'hasDelivery': true,
            'hasInventory': true,
            'hasEcommerceIntegration': true,
          },
          'limits': {'maxProducts': -1, 'maxStaff': -1, 'maxDiscounts': -1},
        }),
        build: () => SubscriptionBloc(dioClient: dioClient),
        act: (bloc) => bloc.add(const SubscriptionLoadRequested(storeId: 'store-1')),
        expect: () => [
          isA<SubscriptionLoading>(),
          isA<SubscriptionLoaded>()
              .having((s) => s.plan, 'plan', 'PREMIUM')
              .having(
                (s) => s.features.hasEcommerceIntegration,
                'features.hasEcommerceIntegration',
                true,
              ),
        ],
      );

      blocTest<SubscriptionBloc, SubscriptionState>(
        'should mark state as expired-not-active when status is EXPIRED',
        setUp: () => mockGet(<String, dynamic>{'status': 'EXPIRED'}),
        build: () => SubscriptionBloc(dioClient: dioClient),
        act: (bloc) => bloc.add(const SubscriptionLoadRequested(storeId: 'store-1')),
        expect: () => [
          isA<SubscriptionLoading>(),
          isA<SubscriptionLoaded>()
              .having((s) => s.isExpired, 'isExpired', true)
              .having((s) => s.isActive, 'isActive', false),
        ],
      );

      blocTest<SubscriptionBloc, SubscriptionState>(
        'should treat TRIAL status as active and not expired',
        setUp: () => mockGet(<String, dynamic>{'status': 'TRIAL'}),
        build: () => SubscriptionBloc(dioClient: dioClient),
        act: (bloc) => bloc.add(const SubscriptionLoadRequested(storeId: 'store-1')),
        expect: () => [
          isA<SubscriptionLoading>(),
          isA<SubscriptionLoaded>()
              .having((s) => s.isActive, 'isActive', true)
              .having((s) => s.isExpired, 'isExpired', false),
        ],
      );

      blocTest<SubscriptionBloc, SubscriptionState>(
        'should emit a friendly offline message when the request throws NetworkException',
        setUp: () => mockGetError(const NetworkException()),
        build: () => SubscriptionBloc(dioClient: dioClient),
        act: (bloc) => bloc.add(const SubscriptionLoadRequested(storeId: 'store-1')),
        expect: () => [
          isA<SubscriptionLoading>(),
          const SubscriptionError('Нет подключения к интернету'),
        ],
      );

      blocTest<SubscriptionBloc, SubscriptionState>(
        'should map a 404 ServerException to "not found" instead of leaking raw message',
        setUp: () => mockGetError(const ServerException('subscription not found', statusCode: 404)),
        build: () => SubscriptionBloc(dioClient: dioClient),
        act: (bloc) => bloc.add(const SubscriptionLoadRequested(storeId: 'store-1')),
        expect: () => [
          isA<SubscriptionLoading>(),
          const SubscriptionError('Объект не найден'),
        ],
      );

      blocTest<SubscriptionBloc, SubscriptionState>(
        'should fall back to the generic failure message for an unrecognized error type',
        setUp: () => mockGetError(Exception('boom')),
        build: () => SubscriptionBloc(dioClient: dioClient),
        act: (bloc) => bloc.add(const SubscriptionLoadRequested(storeId: 'store-1')),
        expect: () => [
          isA<SubscriptionLoading>(),
          const SubscriptionError('Не удалось выполнить операцию'),
        ],
      );
    });

    group('SubscriptionPlanChangeRequested (cash, no receipt)', () {
      blocTest<SubscriptionBloc, SubscriptionState>(
        'should submit the change request directly and reload without touching the upload endpoint',
        setUp: () {
          when(() => dioClient.post<dynamic>(
                '/stores/store-1/subscription/request-change',
                data: any(named: 'data'),
              )).thenAnswer((_) async => resp({'ok': true}));
          mockGet(fullData);
        },
        build: () => SubscriptionBloc(dioClient: dioClient),
        act: (bloc) => bloc.add(const SubscriptionPlanChangeRequested(
          storeId: 'store-1',
          plan: 'BUSINESS',
          paymentMethod: 'CASH',
        )),
        expect: () => [
          isA<SubscriptionUploading>(),
          const SubscriptionActionSuccess('Заявка отправлена, ожидайте подтверждения'),
          isA<SubscriptionLoading>(),
          isA<SubscriptionLoaded>(),
        ],
        verify: (_) {
          verify(() => dioClient.post<dynamic>(
                '/stores/store-1/subscription/request-change',
                data: {'plan': 'BUSINESS', 'paymentMethod': 'CASH'},
              )).called(1);
          verifyNever(() => dioClient.post<dynamic>(
                '/stores/store-1/subscription/upload-receipt',
                data: any(named: 'data'),
              ));
        },
      );

      blocTest<SubscriptionBloc, SubscriptionState>(
        'should emit SubscriptionError when the change request fails',
        setUp: () {
          when(() => dioClient.post<dynamic>(
                '/stores/store-1/subscription/request-change',
                data: any(named: 'data'),
              )).thenThrow(const ServerException('boom', statusCode: 500));
        },
        build: () => SubscriptionBloc(dioClient: dioClient),
        act: (bloc) => bloc.add(const SubscriptionPlanChangeRequested(
          storeId: 'store-1',
          plan: 'PREMIUM',
          paymentMethod: 'CASH',
        )),
        expect: () => [
          isA<SubscriptionUploading>(),
          const SubscriptionError('Ошибка сервера — попробуйте позже'),
        ],
      );
    });

    group('SubscriptionReceiptUploaded (card, with receipt)', () {
      late String receiptPath;

      setUp(() {
        final file = File(
          '${Directory.systemTemp.path}/subscription_bloc_test_receipt_${DateTime.now().microsecondsSinceEpoch}.jpg',
        );
        file.writeAsBytesSync([0, 1, 2, 3]);
        receiptPath = file.path;
      });

      tearDown(() {
        final file = File(receiptPath);
        if (file.existsSync()) {
          file.deleteSync();
        }
      });

      blocTest<SubscriptionBloc, SubscriptionState>(
        'should upload the receipt, submit the change request, then reload',
        setUp: () {
          when(() => dioClient.post<dynamic>(
                '/stores/store-1/subscription/upload-receipt',
                data: any(named: 'data'),
              )).thenAnswer((_) async => resp({'ok': true}));
          when(() => dioClient.post<dynamic>(
                '/stores/store-1/subscription/request-change',
                data: any(named: 'data'),
              )).thenAnswer((_) async => resp({'ok': true}));
          mockGet(fullData);
        },
        build: () => SubscriptionBloc(dioClient: dioClient),
        act: (bloc) => bloc.add(SubscriptionReceiptUploaded(
          storeId: 'store-1',
          plan: 'BUSINESS',
          paymentMethod: 'CARD',
          receiptPath: receiptPath,
        )),
        expect: () => [
          isA<SubscriptionUploading>(),
          const SubscriptionActionSuccess('Заявка отправлена, ожидайте подтверждения'),
          isA<SubscriptionLoading>(),
          isA<SubscriptionLoaded>(),
        ],
        verify: (_) {
          verify(() => dioClient.post<dynamic>(
                '/stores/store-1/subscription/upload-receipt',
                data: any(named: 'data'),
              )).called(1);
          verify(() => dioClient.post<dynamic>(
                '/stores/store-1/subscription/request-change',
                data: {'plan': 'BUSINESS', 'paymentMethod': 'CARD'},
              )).called(1);
        },
      );

      blocTest<SubscriptionBloc, SubscriptionState>(
        'should emit SubscriptionError and skip the change request when the upload itself fails',
        setUp: () {
          when(() => dioClient.post<dynamic>(
                '/stores/store-1/subscription/upload-receipt',
                data: any(named: 'data'),
              )).thenThrow(const NetworkException());
        },
        build: () => SubscriptionBloc(dioClient: dioClient),
        act: (bloc) => bloc.add(SubscriptionReceiptUploaded(
          storeId: 'store-1',
          plan: 'BUSINESS',
          paymentMethod: 'CARD',
          receiptPath: receiptPath,
        )),
        expect: () => [
          isA<SubscriptionUploading>(),
          const SubscriptionError('Нет подключения к интернету'),
        ],
        verify: (_) {
          verifyNever(() => dioClient.post<dynamic>(
                '/stores/store-1/subscription/request-change',
                data: any(named: 'data'),
              ));
        },
      );
    });
  });
}
