import 'package:bloc_test/bloc_test.dart';
import 'package:dukonpro/presentation/blocs/store/store_bloc.dart';
import 'package:dukonpro/presentation/blocs/subscription/subscription_bloc.dart';
import 'package:dukonpro/presentation/blocs/subscription/subscription_event.dart';
import 'package:dukonpro/presentation/blocs/subscription/subscription_state.dart';
import 'package:dukonpro/presentation/pages/dashboard/more_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mocktail/mocktail.dart';

import '../../../fixtures/mock_blocs.dart';
import '../../../helpers/golden_pump_helper.dart';

class _MockSubscriptionBloc
    extends MockBloc<SubscriptionEvent, SubscriptionState>
    implements SubscriptionBloc {}

// The Закят tile is now gated on hasZakat (Task 5). Loaded with the flag
// granted so this golden keeps showing the tile exactly as it rendered
// before gating existed — this file verifies MorePage's pixels, not the
// gate itself (see plan_gate_test.dart for that).
const _featuresWithZakat = SubscriptionFeatures(
  hasReportsAll: false,
  hasExport: false,
  hasTelegram: false,
  hasAllPush: false,
  hasDelivery: false,
  hasInventory: false,
  hasZakat: true,
  hasInvestments: false,
  hasLoyalty: false,
  hasBatchProfitability: false,
  hasEcommerceIntegration: false,
);

const _subscriptionLoaded = SubscriptionLoaded(
  plan: 'BUSINESS',
  status: 'ACTIVE',
  limits: SubscriptionLimits(maxProducts: 500, maxStaff: 2, maxDiscounts: 0),
  features: _featuresWithZakat,
  payments: [],
  availablePlans: [],
);

void main() {
  late MockStoreBloc storeBloc;
  late _MockSubscriptionBloc subscriptionBloc;

  setUp(() {
    storeBloc = MockStoreBloc();
    when(() => storeBloc.state).thenReturn(fakeStoreLoaded());
    subscriptionBloc = _MockSubscriptionBloc();
    when(() => subscriptionBloc.state).thenReturn(_subscriptionLoaded);
  });

  const page = MorePage();

  Widget wrapWithBlocs(Widget child) => MultiBlocProvider(
        providers: [
          BlocProvider<StoreBloc>.value(value: storeBloc),
          BlocProvider<SubscriptionBloc>.value(value: subscriptionBloc),
        ],
        child: child,
      );

  group('MorePage goldens', () {
    testGoldens('light theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page,
        brightness: Brightness.light,
        wrap: wrapWithBlocs,
      );
      await screenMatchesGolden(tester, 'more_light');
    });

    testGoldens('dark theme', (tester) async {
      await pumpPageWithTheme(
        tester,
        page,
        brightness: Brightness.dark,
        wrap: wrapWithBlocs,
      );
      await screenMatchesGolden(tester, 'more_dark');
    });
  });
}
