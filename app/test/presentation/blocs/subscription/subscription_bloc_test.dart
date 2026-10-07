import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dukonpro/core/errors/app_message.dart';
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

  /// The bloc issues TWO gets: /subscription for the plan, and
  /// /subscription/payments for the history, which the first has never
  /// carried. Routed by path so a test can supply either independently.
  void mockGet(dynamic body, {List<dynamic> payments = const []}) {
    when(() => dioClient.get<dynamic>(any())).thenAnswer((invocation) async {
      final path = invocation.positionalArguments.first as String;
      return resp(path.endsWith('/payments') ? payments : body);
    });
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
    // Real key names. The fixture used to say 'expiresAt' and 'trialDaysLeft',
    // neither of which this endpoint sends — the same fiction that let
    // 'CONFIRMED' survive, two keys further along.
    'currentPeriodEnd': '2026-08-01T00:00:00.000Z',
    'adminDiscount': 10.5,
    'limits': {'maxProducts': 2000, 'maxStaff': 10, 'maxDiscounts': 5},
    'features': {
      'hasReportsAll': true,
      'hasExport': true,
      'hasTelegram': false,
      'hasAllPush': true,
      'hasDelivery': false,
      'hasInventory': true,
    },
  };

  // Served by GET /subscription/payments, newest first. A pending payment is
  // a row in here, not a `pendingPayment` key on the main response — that key
  // has never been sent, so the awaiting-approval banner never appeared.
  final paymentsFixture = <dynamic>[
    {
      'id': 'p2',
      'amount': 200.0,
      'method': 'CARD',
      'status': 'PENDING',
      'createdAt': '2026-07-10T00:00:00.000Z',
    },
    {
      'id': 'p1',
      'amount': 100.0,
      'method': 'CARD',
      'status': 'APPROVED',
      'createdAt': '2026-07-01T00:00:00.000Z',
      'receiptImage': 'uploads/receipts/abc.jpg',
    },
  ];

  group('SubscriptionBloc', () {
    test('initial state is SubscriptionInitial', () {
      final bloc = SubscriptionBloc(dioClient: dioClient);
      expect(bloc.state, isA<SubscriptionInitial>());
    });

    group('SubscriptionLoadRequested', () {
      blocTest<SubscriptionBloc, SubscriptionState>(
        'should emit loading then loaded with mapped plan/limits/features/payments when request succeeds',
        setUp: () => mockGet(fullData, payments: paymentsFixture),
        build: () => SubscriptionBloc(dioClient: dioClient),
        act: (bloc) =>
            bloc.add(const SubscriptionLoadRequested(storeId: 'store-1')),
        expect: () => [
          isA<SubscriptionLoading>(),
          isA<SubscriptionLoaded>()
              .having((s) => s.plan, 'plan', 'BUSINESS')
              .having((s) => s.status, 'status', 'ACTIVE')
              .having((s) => s.adminDiscount, 'adminDiscount', 10.5)
              .having(
                (s) => s.expiresAt,
                'expiresAt',
                DateTime.parse('2026-08-01T00:00:00.000Z').toLocal(),
              )
              .having((s) => s.limits.maxProducts, 'limits.maxProducts', 2000)
              .having((s) => s.limits.maxStaff, 'limits.maxStaff', 10)
              .having((s) => s.limits.maxDiscounts, 'limits.maxDiscounts', 5)
              .having(
                (s) => s.features.hasReportsAll,
                'features.hasReportsAll',
                true,
              )
              .having(
                (s) => s.features.hasDelivery,
                'features.hasDelivery',
                false,
              )
              .having((s) => s.payments.length, 'payments.length', 2)
              .having((s) => s.payments.first.id, 'payments.first.id', 'p2')
              .having((s) => s.pendingPayment?.id, 'pendingPayment.id', 'p2')
              .having((s) => s.isActive, 'isActive', true)
              .having((s) => s.isExpired, 'isExpired', false),
        ],
        verify: (_) {
          verify(
            () => dioClient.get<dynamic>('/stores/store-1/subscription'),
          ).called(1);
        },
      );

      blocTest<SubscriptionBloc, SubscriptionState>(
        'should fall back to plan/status/limits/features defaults when response body is empty',
        setUp: () => mockGet(<String, dynamic>{}),
        build: () => SubscriptionBloc(dioClient: dioClient),
        act: (bloc) =>
            bloc.add(const SubscriptionLoadRequested(storeId: 'store-1')),
        expect: () => [
          isA<SubscriptionLoading>(),
          isA<SubscriptionLoaded>()
              .having((s) => s.plan, 'plan', 'START')
              .having((s) => s.status, 'status', 'ACTIVE')
              .having((s) => s.trialDaysLeft, 'trialDaysLeft', isNull)
              .having((s) => s.adminDiscount, 'adminDiscount', isNull)
              .having((s) => s.expiresAt, 'expiresAt', isNull)
              .having((s) => s.limits.maxProducts, 'limits.maxProducts', 500)
              .having((s) => s.limits.maxStaff, 'limits.maxStaff', 2)
              .having((s) => s.limits.maxDiscounts, 'limits.maxDiscounts', 0)
              .having(
                (s) => s.features.hasReportsAll,
                'features.hasReportsAll',
                false,
              )
              .having((s) => s.payments, 'payments', isEmpty)
              .having((s) => s.pendingPayment, 'pendingPayment', isNull),
        ],
      );

      blocTest<SubscriptionBloc, SubscriptionState>(
        'should treat a limit of -1 as unlimited without special-casing it away',
        setUp: () => mockGet(<String, dynamic>{
          'plan': 'PREMIUM',
          'limits': {'maxProducts': -1, 'maxStaff': -1, 'maxDiscounts': -1},
        }),
        build: () => SubscriptionBloc(dioClient: dioClient),
        act: (bloc) =>
            bloc.add(const SubscriptionLoadRequested(storeId: 'store-1')),
        expect: () => [
          isA<SubscriptionLoading>(),
          isA<SubscriptionLoaded>()
              .having((s) => s.limits.maxProducts, 'limits.maxProducts', -1)
              .having((s) => s.limits.maxStaff, 'limits.maxStaff', -1)
              .having((s) => s.limits.maxDiscounts, 'limits.maxDiscounts', -1),
        ],
      );

      blocTest<SubscriptionBloc, SubscriptionState>(
        'should report a PAST_DUE subscription as lapsed, not as active',
        setUp: () => mockGet(<String, dynamic>{
          'plan': 'BUSINESS',
          'status': 'PAST_DUE',
        }),
        build: () => SubscriptionBloc(dioClient: dioClient),
        act: (bloc) =>
            bloc.add(const SubscriptionLoadRequested(storeId: 'store-1')),
        expect: () => [
          isA<SubscriptionLoading>(),
          // BOTH directions. Asserting only isActive == false passed on the old
          // code — PAST_DUE was in neither list — and that half-assertion is
          // exactly what let a lapsed merchant keep the full-colour card, since
          // the gradient is chosen by isExpired.
          isA<SubscriptionLoaded>()
              .having((s) => s.isActive, 'isActive', false)
              .having((s) => s.isExpired, 'isExpired', true),
        ],
      );

      blocTest<SubscriptionBloc, SubscriptionState>(
        'should treat a status it does not recognise as lapsed rather than active',
        setUp: () => mockGet(<String, dynamic>{
          'plan': 'BUSINESS',
          'status': 'SOMETHING_NEW',
        }),
        build: () => SubscriptionBloc(dioClient: dioClient),
        act: (bloc) =>
            bloc.add(const SubscriptionLoadRequested(storeId: 'store-1')),
        expect: () => [
          isA<SubscriptionLoading>(),
          isA<SubscriptionLoaded>()
              .having((s) => s.isActive, 'isActive', false)
              .having((s) => s.isExpired, 'isExpired', true),
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
        act: (bloc) =>
            bloc.add(const SubscriptionLoadRequested(storeId: 'store-1')),
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
        act: (bloc) =>
            bloc.add(const SubscriptionLoadRequested(storeId: 'store-1')),
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
        act: (bloc) =>
            bloc.add(const SubscriptionLoadRequested(storeId: 'store-1')),
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
        act: (bloc) =>
            bloc.add(const SubscriptionLoadRequested(storeId: 'store-1')),
        expect: () => [
          isA<SubscriptionLoading>(),
          const SubscriptionError(AppMessage.offline),
        ],
      );

      blocTest<SubscriptionBloc, SubscriptionState>(
        'should map a 404 ServerException to "not found" instead of leaking raw message',
        setUp: () => mockGetError(
          const ServerException('subscription not found', statusCode: 404),
        ),
        build: () => SubscriptionBloc(dioClient: dioClient),
        act: (bloc) =>
            bloc.add(const SubscriptionLoadRequested(storeId: 'store-1')),
        expect: () => [
          isA<SubscriptionLoading>(),
          const SubscriptionError(AppMessage.notFound),
        ],
      );

      blocTest<SubscriptionBloc, SubscriptionState>(
        'should fall back to the generic failure message for an unrecognized error type',
        setUp: () => mockGetError(Exception('boom')),
        build: () => SubscriptionBloc(dioClient: dioClient),
        act: (bloc) =>
            bloc.add(const SubscriptionLoadRequested(storeId: 'store-1')),
        expect: () => [
          isA<SubscriptionLoading>(),
          const SubscriptionError(AppMessage.unknownError),
        ],
      );
    });

    group('SubscriptionPlanChangeRequested (cash, no receipt)', () {
      blocTest<SubscriptionBloc, SubscriptionState>(
        'should submit the change request directly and reload without touching the upload endpoint',
        setUp: () {
          when(
            () => dioClient.post<dynamic>(
              '/stores/store-1/subscription/request-change',
              data: any(named: 'data'),
            ),
          ).thenAnswer((_) async => resp({'ok': true}));
          mockGet(fullData, payments: paymentsFixture);
        },
        build: () => SubscriptionBloc(dioClient: dioClient),
        act: (bloc) => bloc.add(
          const SubscriptionPlanChangeRequested(
            storeId: 'store-1',
            plan: 'BUSINESS',
            paymentMethod: 'CASH',
          ),
        ),
        expect: () => [
          isA<SubscriptionUploading>(),
          const SubscriptionActionSuccess(AppMessage.subscriptionRequestSent),
          isA<SubscriptionLoading>(),
          isA<SubscriptionLoaded>(),
        ],
        verify: (_) {
          verify(
            () => dioClient.post<dynamic>(
              '/stores/store-1/subscription/request-change',
              data: {'plan': 'BUSINESS', 'paymentMethod': 'CASH'},
            ),
          ).called(1);
          verifyNever(
            () => dioClient.post<dynamic>(
              '/stores/store-1/subscription/upload-receipt',
              data: any(named: 'data'),
            ),
          );
        },
      );

      blocTest<SubscriptionBloc, SubscriptionState>(
        'should emit SubscriptionError when the change request fails',
        setUp: () {
          when(
            () => dioClient.post<dynamic>(
              '/stores/store-1/subscription/request-change',
              data: any(named: 'data'),
            ),
          ).thenThrow(const ServerException('boom', statusCode: 500));
        },
        build: () => SubscriptionBloc(dioClient: dioClient),
        act: (bloc) => bloc.add(
          const SubscriptionPlanChangeRequested(
            storeId: 'store-1',
            plan: 'PREMIUM',
            paymentMethod: 'CASH',
          ),
        ),
        expect: () => [
          isA<SubscriptionUploading>(),
          const SubscriptionError(AppMessage.serverError),
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

      // Every test in this group needs an explicit `wait`. The bloc emits
      // SubscriptionUploading and then does real filesystem I/O
      // (`await MultipartFile.fromFile(event.receiptPath)`) before it reaches
      // the mocked `post`, so the terminal state arrives one async file read
      // later. bloc_test's default assertion window can close before that read
      // completes on a loaded CI runner, yielding a spurious
      // "Expected [Uploading, Error] / Actual [Uploading]" — this failed ~1 run
      // in 6 locally and broke CI on main. The read is a 4-byte temp file, so
      // 200ms is ample.

      // Records every post in order, so a test can assert the SEQUENCE and the
      // URL the bloc built from the first response. The replaced tests matched
      // `'/stores/store-1/subscription/upload-receipt'` exactly — a path the
      // server does not have — and then verified that same literal, which is
      // why three real mismatches stayed green for months.
      late List<({String path, Object? data})> posts;

      void recordPosts({
        String? requestChangeId = 'pay-7',
        Object? uploadThrows,
      }) {
        posts = [];
        when(
          () => dioClient.post<dynamic>(any(), data: any(named: 'data')),
        ).thenAnswer((invocation) async {
          final path = invocation.positionalArguments.first as String;
          final data = invocation.namedArguments[const Symbol('data')];
          posts.add((path: path, data: data));
          if (path.contains('/upload-receipt')) {
            if (uploadThrows != null) throw uploadThrows;
            return resp({'ok': true});
          }
          return resp(
            requestChangeId == null
                ? <String, dynamic>{}
                : <String, dynamic>{'id': requestChangeId},
          );
        });
      }

      blocTest<SubscriptionBloc, SubscriptionState>(
        'should create the change request first, then upload the receipt to that payment',
        wait: const Duration(milliseconds: 200),
        setUp: () {
          recordPosts();
          mockGet(fullData, payments: paymentsFixture);
        },
        build: () => SubscriptionBloc(dioClient: dioClient),
        act: (bloc) => bloc.add(
          SubscriptionReceiptUploaded(
            storeId: 'store-1',
            plan: 'BUSINESS',
            paymentMethod: 'CARD',
            receiptPath: receiptPath,
          ),
        ),
        expect: () => [
          isA<SubscriptionUploading>(),
          const SubscriptionActionSuccess(AppMessage.subscriptionRequestSent),
          isA<SubscriptionLoading>(),
          isA<SubscriptionLoaded>(),
        ],
        verify: (_) {
          // The order and the id in the URL, in one assertion. The receipt
          // attaches to a Payment row that request-change creates, so an upload
          // sent first has no id to carry — the old code sent it first and
          // discarded the response that held the id.
          expect(posts.map((p) => p.path).toList(), [
            '/stores/store-1/subscription/request-change',
            '/stores/store-1/subscription/upload-receipt/pay-7',
          ]);
          expect(posts.first.data, {
            'plan': 'BUSINESS',
            'paymentMethod': 'CARD',
          });
        },
      );

      blocTest<SubscriptionBloc, SubscriptionState>(
        'should name the multipart field file, as the route interceptor requires',
        wait: const Duration(milliseconds: 200),
        setUp: () {
          recordPosts();
          mockGet(fullData, payments: paymentsFixture);
        },
        build: () => SubscriptionBloc(dioClient: dioClient),
        act: (bloc) => bloc.add(
          SubscriptionReceiptUploaded(
            storeId: 'store-1',
            plan: 'BUSINESS',
            paymentMethod: 'CARD',
            receiptPath: receiptPath,
          ),
        ),
        verify: (_) {
          // Reaches INTO the FormData. `any(named: 'data')` never looked, which
          // is how a field named 'receipt' survived against
          // FileInterceptor('file', ...) in subscriptions.controller.ts:95.
          final upload = posts.firstWhere(
            (p) => p.path.contains('/upload-receipt'),
          );
          final formData = upload.data as FormData;
          expect(formData.files.map((e) => e.key).toList(), ['file']);
        },
      );

      blocTest<SubscriptionBloc, SubscriptionState>(
        'should tell the merchant the request went through when only the receipt upload fails',
        wait: const Duration(milliseconds: 200),
        setUp: () {
          recordPosts(uploadThrows: const NetworkException());
          mockGet(fullData, payments: paymentsFixture);
        },
        build: () => SubscriptionBloc(dioClient: dioClient),
        act: (bloc) => bloc.add(
          SubscriptionReceiptUploaded(
            storeId: 'store-1',
            plan: 'BUSINESS',
            paymentMethod: 'CARD',
            receiptPath: receiptPath,
          ),
        ),
        // Not an error state: the request EXISTS. request-change does not
        // de-duplicate pending payments, so reporting a flat failure would make
        // the merchant resubmit and create a second request for the same plan.
        expect: () => [
          isA<SubscriptionUploading>(),
          const SubscriptionActionSuccess(
            AppMessage.subscriptionRequestSentWithoutReceipt,
          ),
          isA<SubscriptionLoading>(),
          isA<SubscriptionLoaded>(),
        ],
      );

      blocTest<SubscriptionBloc, SubscriptionState>(
        'should emit an error and never upload when the change request itself fails',
        wait: const Duration(milliseconds: 200),
        setUp: () {
          posts = [];
          when(
            () => dioClient.post<dynamic>(any(), data: any(named: 'data')),
          ).thenAnswer((invocation) async {
            posts.add((
              path: invocation.positionalArguments.first as String,
              data: invocation.namedArguments[const Symbol('data')],
            ));
            throw const NetworkException();
          });
        },
        build: () => SubscriptionBloc(dioClient: dioClient),
        act: (bloc) => bloc.add(
          SubscriptionReceiptUploaded(
            storeId: 'store-1',
            plan: 'BUSINESS',
            paymentMethod: 'CARD',
            receiptPath: receiptPath,
          ),
        ),
        expect: () => [
          isA<SubscriptionUploading>(),
          const SubscriptionError(AppMessage.offline),
        ],
        verify: (_) {
          // The name of this test used to be the whole of its claim: the old
          // body had no verify at all, and a stray upload added inside the
          // error path did not fail it.
          expect(posts.map((p) => p.path).toList(), [
            '/stores/store-1/subscription/request-change',
          ]);
        },
      );

      blocTest<SubscriptionBloc, SubscriptionState>(
        'should report the request as sent without a receipt when the response carries no payment id',
        wait: const Duration(milliseconds: 200),
        setUp: () {
          recordPosts(requestChangeId: null);
          mockGet(fullData, payments: paymentsFixture);
        },
        build: () => SubscriptionBloc(dioClient: dioClient),
        act: (bloc) => bloc.add(
          SubscriptionReceiptUploaded(
            storeId: 'store-1',
            plan: 'BUSINESS',
            paymentMethod: 'CARD',
            receiptPath: receiptPath,
          ),
        ),
        // A 2xx from request-change means the Payment row exists, so this is
        // the same situation as a failed upload and gets the same answer. A
        // flat error here would invite a resubmission, and two pending payments
        // can each be approved and each extend the period.
        expect: () => [
          isA<SubscriptionUploading>(),
          const SubscriptionActionSuccess(
            AppMessage.subscriptionRequestSentWithoutReceipt,
          ),
          isA<SubscriptionLoading>(),
          isA<SubscriptionLoaded>(),
        ],
        verify: (_) {
          // Posting to a path ending in `/null` would 404 exactly like the bug
          // being fixed, and look identical in the logs.
          expect(
            posts.where((p) => p.path.contains('/upload-receipt')),
            isEmpty,
          );
        },
      );

      blocTest<SubscriptionBloc, SubscriptionState>(
        'should report the request as sent without a receipt when the response body is not a map',
        wait: const Duration(milliseconds: 200),
        setUp: () {
          posts = [];
          when(
            () => dioClient.post<dynamic>(any(), data: any(named: 'data')),
          ).thenAnswer((invocation) async {
            posts.add((
              path: invocation.positionalArguments.first as String,
              data: invocation.namedArguments[const Symbol('data')],
            ));
            // A list, not a map: the cast that reads `id` throws. The request
            // still returned 2xx, so the row exists and the merchant must not
            // be told otherwise.
            return resp(<dynamic>['not', 'a', 'map']);
          });
          mockGet(fullData, payments: paymentsFixture);
        },
        build: () => SubscriptionBloc(dioClient: dioClient),
        act: (bloc) => bloc.add(
          SubscriptionReceiptUploaded(
            storeId: 'store-1',
            plan: 'BUSINESS',
            paymentMethod: 'CARD',
            receiptPath: receiptPath,
          ),
        ),
        expect: () => [
          isA<SubscriptionUploading>(),
          const SubscriptionActionSuccess(
            AppMessage.subscriptionRequestSentWithoutReceipt,
          ),
          isA<SubscriptionLoading>(),
          isA<SubscriptionLoaded>(),
        ],
        verify: (_) {
          expect(
            posts.where((p) => p.path.contains('/upload-receipt')),
            isEmpty,
          );
        },
      );
    });
  });

  group('fields the response really carries', () {
    // Three keys the bloc read were never sent. The plan card's expiry line
    // has two branches and BOTH depended on them, so it rendered as an empty
    // string; the pending-payment banner never appeared at all.

    test('should take the expiry date from currentPeriodEnd', () async {
      mockGet(<String, dynamic>{
        'plan': 'BUSINESS',
        'status': 'ACTIVE',
        'currentPeriodEnd': '2027-12-31T00:00:00.000Z',
      });
      final bloc = SubscriptionBloc(dioClient: dioClient);
      addTearDown(bloc.close);

      bloc.add(const SubscriptionLoadRequested(storeId: 's1'));
      final loaded =
          await bloc.stream.firstWhere((s) => s is SubscriptionLoaded)
              as SubscriptionLoaded;

      expect(loaded.expiresAt, isNotNull);
      expect(loaded.expiresAt!.toUtc().year, 2027);
    });

    test('should count the trial days left from trialEndsAt', () async {
      // Five days and three hours. inHours truncates, so a one-hour margin
      // would land back on 120h exactly and read as 5 either way; three hours
      // keeps the fixture clear of the boundary so the expectation pins the
      // rounding rather than the truncation.
      final endsIn5Days = DateTime.now().toUtc().add(
        const Duration(days: 5, hours: 3),
      );
      mockGet(<String, dynamic>{
        'plan': 'PREMIUM',
        'status': 'TRIAL',
        'trialEndsAt': endsIn5Days.toIso8601String(),
      });
      final bloc = SubscriptionBloc(dioClient: dioClient);
      addTearDown(bloc.close);

      bloc.add(const SubscriptionLoadRequested(storeId: 's1'));
      final loaded =
          await bloc.stream.firstWhere((s) => s is SubscriptionLoaded)
              as SubscriptionLoaded;

      expect(loaded.trialDaysLeft, 6);
    });

    test('should report a whole week on the day a trial is created', () async {
      // Trials are created as now + 7 days, so the difference is seven days
      // minus milliseconds. Truncating told a merchant who had just signed up
      // that six days remained.
      mockGet(<String, dynamic>{
        'plan': 'PREMIUM',
        'status': 'TRIAL',
        'trialEndsAt': DateTime.now()
            .toUtc()
            .add(const Duration(days: 7))
            .subtract(const Duration(milliseconds: 5))
            .toIso8601String(),
      });
      final bloc = SubscriptionBloc(dioClient: dioClient);
      addTearDown(bloc.close);

      bloc.add(const SubscriptionLoadRequested(storeId: 's1'));
      final loaded =
          await bloc.stream.firstWhere((s) => s is SubscriptionLoaded)
              as SubscriptionLoaded;

      expect(loaded.trialDaysLeft, 7);
    });

    test(
      'should still report a day left on the final day of a trial',
      () async {
        // Ten hours left truncated to 0, which reads as "over" on a trial that
        // still works.
        mockGet(<String, dynamic>{
          'plan': 'PREMIUM',
          'status': 'TRIAL',
          'trialEndsAt': DateTime.now()
              .toUtc()
              .add(const Duration(hours: 10))
              .toIso8601String(),
        });
        final bloc = SubscriptionBloc(dioClient: dioClient);
        addTearDown(bloc.close);

        bloc.add(const SubscriptionLoadRequested(storeId: 's1'));
        final loaded =
            await bloc.stream.firstWhere((s) => s is SubscriptionLoaded)
                as SubscriptionLoaded;

        expect(loaded.trialDaysLeft, 1);
      },
    );

    test('should take the newest of two pending payments, whatever order the '
        'server sends them in', () async {
      // requestChange creates a PENDING row without checking for an existing
      // one, so two are reachable. The oldest is listed first here on purpose.
      mockGet(
        <String, dynamic>{'plan': 'BUSINESS', 'status': 'ACTIVE'},
        payments: <dynamic>[
          {
            'id': 'pay-older',
            'amount': 149.0,
            'method': 'CARD',
            'status': 'PENDING',
            'createdAt': '2026-09-01T00:00:00.000Z',
          },
          {
            'id': 'pay-newer',
            'amount': 299.0,
            'method': 'CARD',
            'status': 'PENDING',
            'createdAt': '2026-10-05T00:00:00.000Z',
          },
        ],
      );
      final bloc = SubscriptionBloc(dioClient: dioClient);
      addTearDown(bloc.close);

      bloc.add(const SubscriptionLoadRequested(storeId: 's1'));
      final loaded =
          await bloc.stream.firstWhere((s) => s is SubscriptionLoaded)
              as SubscriptionLoaded;

      expect(loaded.pendingPayment?.id, 'pay-newer');
    });

    test('should report no days left rather than a negative count when the '
        'trial has already ended', () async {
      mockGet(<String, dynamic>{
        'plan': 'PREMIUM',
        'status': 'TRIAL',
        'trialEndsAt': DateTime.now()
            .toUtc()
            .subtract(const Duration(days: 3))
            .toIso8601String(),
      });
      final bloc = SubscriptionBloc(dioClient: dioClient);
      addTearDown(bloc.close);

      bloc.add(const SubscriptionLoadRequested(storeId: 's1'));
      final loaded =
          await bloc.stream.firstWhere((s) => s is SubscriptionLoaded)
              as SubscriptionLoaded;

      expect(loaded.trialDaysLeft, 0);
    });

    test('should surface a pending payment from the history', () async {
      // The response has no pendingPayment key; it is derived from the
      // payments list, which is where a PENDING row actually lives.
      mockGet(
        <String, dynamic>{'plan': 'BUSINESS', 'status': 'ACTIVE'},
        payments: <dynamic>[
          {
            'id': 'pay-pending',
            'amount': 400.0,
            'method': 'CASH',
            'status': 'PENDING',
            'createdAt': '2026-10-05T21:18:33.301Z',
          },
          {
            'id': 'pay-old',
            'amount': 400.0,
            'method': 'CASH',
            'status': 'APPROVED',
            'createdAt': '2026-09-05T21:18:33.301Z',
          },
        ],
      );
      final bloc = SubscriptionBloc(dioClient: dioClient);
      addTearDown(bloc.close);

      bloc.add(const SubscriptionLoadRequested(storeId: 's1'));
      final loaded =
          await bloc.stream.firstWhere((s) => s is SubscriptionLoaded)
              as SubscriptionLoaded;

      expect(loaded.pendingPayment?.id, 'pay-pending');
    });

    test(
      'should report no pending payment when every payment is settled',
      () async {
        mockGet(
          <String, dynamic>{'plan': 'BUSINESS', 'status': 'ACTIVE'},
          payments: <dynamic>[
            {
              'id': 'pay-old',
              'amount': 400.0,
              'method': 'CASH',
              'status': 'APPROVED',
              'createdAt': '2026-09-05T21:18:33.301Z',
            },
          ],
        );
        final bloc = SubscriptionBloc(dioClient: dioClient);
        addTearDown(bloc.close);

        bloc.add(const SubscriptionLoadRequested(storeId: 's1'));
        final loaded =
            await bloc.stream.firstWhere((s) => s is SubscriptionLoaded)
                as SubscriptionLoaded;

        expect(loaded.pendingPayment, isNull);
      },
    );
  });
}
