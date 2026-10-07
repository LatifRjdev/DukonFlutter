import 'package:dukonpro/presentation/blocs/subscription/subscription_state.dart';
import 'package:dukonpro/presentation/pages/settings/plan_gate.dart';
import 'package:flutter_test/flutter_test.dart';

// Pure-logic coverage for cheapestPlanWith: given a list of
// SubscriptionPlanOption and a flag selector, which is the cheapest plan that
// carries it. No widgets, no BuildContext — PlanGate's UI-facing behaviour
// (onTap: null while undetermined, badge hidden when there is nothing honest
// to upsell) is exercised at each call site instead.

const _noFeatures = SubscriptionFeatures(
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

SubscriptionFeatures _featuresWithZakat(bool value) => SubscriptionFeatures(
  hasReportsAll: _noFeatures.hasReportsAll,
  hasExport: _noFeatures.hasExport,
  hasTelegram: _noFeatures.hasTelegram,
  hasAllPush: _noFeatures.hasAllPush,
  hasDelivery: _noFeatures.hasDelivery,
  hasInventory: _noFeatures.hasInventory,
  hasZakat: value,
  hasInvestments: _noFeatures.hasInvestments,
  hasLoyalty: _noFeatures.hasLoyalty,
  hasBatchProfitability: _noFeatures.hasBatchProfitability,
  hasEcommerceIntegration: _noFeatures.hasEcommerceIntegration,
);

SubscriptionPlanOption _plan({
  required String plan,
  required double listPrice,
  required bool hasZakat,
}) => SubscriptionPlanOption(
  plan: plan,
  price: listPrice,
  listPrice: listPrice,
  maxProducts: 0,
  maxStaff: 0,
  maxDiscounts: 0,
  features: _featuresWithZakat(hasZakat),
);

bool _zakatSelector(SubscriptionFeatures f) => f.hasZakat;

void main() {
  group('cheapestPlanWith', () {
    test(
      'should return BUSINESS when START lacks zakat and BUSINESS/PREMIUM have it',
      () {
        final plans = [
          _plan(plan: 'START', listPrice: 200, hasZakat: false),
          _plan(plan: 'BUSINESS', listPrice: 400, hasZakat: true),
          _plan(plan: 'PREMIUM', listPrice: 600, hasZakat: true),
        ];

        expect(cheapestPlanWith(plans, _zakatSelector), 'BUSINESS');
      },
    );

    test('should return PREMIUM when only PREMIUM has the flag', () {
      final plans = [
        _plan(plan: 'START', listPrice: 200, hasZakat: false),
        _plan(plan: 'BUSINESS', listPrice: 400, hasZakat: false),
        _plan(plan: 'PREMIUM', listPrice: 600, hasZakat: true),
      ];

      expect(cheapestPlanWith(plans, _zakatSelector), 'PREMIUM');
    });

    test(
      'should return null when no plan has the flag, so the caller must not promise a plan that does not exist',
      () {
        final plans = [
          _plan(plan: 'START', listPrice: 200, hasZakat: false),
          _plan(plan: 'BUSINESS', listPrice: 400, hasZakat: false),
          _plan(plan: 'PREMIUM', listPrice: 600, hasZakat: false),
        ];

        expect(cheapestPlanWith(plans, _zakatSelector), isNull);
      },
    );

    test(
      'should order by price rather than by list order, so a reversed list still answers BUSINESS',
      () {
        final plans = [
          _plan(plan: 'PREMIUM', listPrice: 600, hasZakat: true),
          _plan(plan: 'BUSINESS', listPrice: 400, hasZakat: true),
          _plan(plan: 'START', listPrice: 200, hasZakat: false),
        ];

        expect(cheapestPlanWith(plans, _zakatSelector), 'BUSINESS');
      },
    );
  });
}
