import 'package:bloc_test/bloc_test.dart';
import 'package:dukonpro/core/theme/app_theme.dart';
import 'package:dukonpro/l10n/app_localizations.dart';
import 'package:dukonpro/presentation/blocs/store/store_bloc.dart';
import 'package:dukonpro/presentation/blocs/subscription/subscription_bloc.dart';
import 'package:dukonpro/presentation/blocs/subscription/subscription_event.dart';
import 'package:dukonpro/presentation/blocs/subscription/subscription_state.dart';
import 'package:dukonpro/presentation/pages/settings/subscription_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../fixtures/mock_blocs.dart';

// The card's numbers must come from the state, not from constants. They WERE
// constants: the cards read 49/149/299 TJS from translation strings while
// subscription_plan_configs charged 200/400/600, so tapping a card reading
// "49 TJS/мес" created a payment for 200.
//
// Every number in the fixture matches NONE of the old hardcoded values, so a
// surviving constant fails rather than coincidentally agreeing. 500/2/5 would
// have passed against the bug.

class _MockSubscriptionBloc
    extends MockBloc<SubscriptionEvent, SubscriptionState>
    implements SubscriptionBloc {}

SubscriptionLoaded _loadedWithPlans(List<SubscriptionPlanOption> plans) =>
    SubscriptionLoaded(
      plan: 'START',
      status: 'ACTIVE',
      limits: const SubscriptionLimits(
        maxProducts: 777,
        maxStaff: 3,
        maxDiscounts: 9,
      ),
      features: SubscriptionFeatures.defaults(),
      payments: const [],
      availablePlans: plans,
    );

// Pulled out of `_start` rather than read back off it via `_start.features`:
// Dart does not treat field access on a const instance as itself a constant
// expression, so `features: _start.features` inside another `const`
// SubscriptionPlanOption below fails to compile ("Not a constant
// expression").
const _features = SubscriptionFeatures(
  hasReportsAll: false,
  hasExport: false,
  hasTelegram: false,
  hasAllPush: false,
  hasDelivery: false,
  hasInventory: false,
  hasZakat: false,
  hasInvestments: false,
  hasLoyalty: false,
  hasBatchProfitability: false,
  hasEcommerceIntegration: false,
);

const _start = SubscriptionPlanOption(
  plan: 'START',
  price: 134,
  listPrice: 200,
  maxProducts: 777,
  maxStaff: 3,
  maxDiscounts: 9,
  features: _features,
);

void main() {
  late _MockSubscriptionBloc subscriptionBloc;
  late MockStoreBloc storeBloc;

  setUp(() {
    subscriptionBloc = _MockSubscriptionBloc();
    storeBloc = MockStoreBloc();
    when(() => storeBloc.state).thenReturn(fakeStoreLoaded());
  });

  tearDown(() {
    subscriptionBloc.close();
    storeBloc.close();
  });

  Future<void> pumpWithPlans(
    WidgetTester tester,
    List<SubscriptionPlanOption> plans,
  ) async {
    when(() => subscriptionBloc.state).thenReturn(_loadedWithPlans(plans));

    await tester.binding.setSurfaceSize(const Size(412, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // Tear the tree down first. A second `pumpWidget` with a structurally
    // identical tree reuses the elements, and the page's `BlocBuilder` rebuilds
    // on stream events — which a MockBloc never emits — so it would keep
    // rendering the PREVIOUS state while `state` already returns the new one.
    await tester.pumpWidget(const SizedBox.shrink());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ru'),
        home: MultiBlocProvider(
          providers: [
            BlocProvider<SubscriptionBloc>.value(value: subscriptionBloc),
            BlocProvider<StoreBloc>.value(value: storeBloc),
          ],
          child: const SubscriptionPage(),
        ),
      ),
    );
    // Two frames rather than pumpAndSettle: the page hosts a RefreshIndicator,
    // which never settles. Mirrors the status test's harness.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('should price the card from the server, not from a constant', (
    tester,
  ) async {
    await pumpWithPlans(tester, const [_start]);

    expect(find.text('134 TJS/мес'), findsOneWidget);
    // The constant it replaced. Four times lower than what was charged.
    expect(find.text('49 TJS/мес'), findsNothing);
  });

  testWidgets('should take every limit on the card from the server', (
    tester,
  ) async {
    await pumpWithPlans(tester, const [_start]);

    expect(find.text('777 товаров'), findsOneWidget);
    expect(find.text('3 сотрудников'), findsOneWidget);
    expect(find.text('9 скидок'), findsOneWidget);
    // The old constants, none of which the fixture uses.
    expect(find.text('500 товаров'), findsNothing);
    expect(find.text('2 сотрудника'), findsNothing);
    expect(find.text('5 скидок'), findsNothing);
  });

  testWidgets('should not advertise a store limit the server dropped in May', (
    tester,
  ) async {
    await pumpWithPlans(tester, const [_start]);

    // maxStores was removed from SubscriptionPlanConfig in 2026-05 and is
    // enforced nowhere; the previous branch deleted the client's dead field
    // and the advertisement of it survived in the marketing copy.
    expect(find.textContaining('магазин'), findsNothing);
  });

  testWidgets('should render -1 as unlimited rather than as minus one', (
    tester,
  ) async {
    await pumpWithPlans(tester, const [
      SubscriptionPlanOption(
        plan: 'PREMIUM',
        price: 402,
        listPrice: 600,
        maxProducts: -1,
        maxStaff: -1,
        maxDiscounts: -1,
        features: _features,
      ),
    ]);

    expect(find.text('Без ограничений'), findsWidgets);
    expect(find.textContaining('-1'), findsNothing);
  });

  testWidgets('should show no price at all when the plans did not load', (
    tester,
  ) async {
    await pumpWithPlans(tester, const []);

    // Showing an unverified price is the defect being fixed, so an empty list
    // must produce no number — not a hardcoded fallback.
    expect(find.textContaining('TJS/мес'), findsNothing);
  });
}
