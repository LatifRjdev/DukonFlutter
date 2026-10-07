import { readFileSync } from 'fs';
import { join } from 'path';
import { PLAN_FEATURE_FLAGS, discountedPrice, toPlanView } from './plan-view';

// Guards the defect this file was extracted for. getSubscription used to list
// seven flag keys by hand while SubscriptionPlanConfig had eleven, and the four
// it missed included three the server enforces with @RequiresFeature — so the
// app could not gate zakat, loyalty or batch profitability, and merchants met a
// 403 instead of an explanation.
describe('PlanView', () => {
  it('should carry every has* column the schema defines', () => {
    // Reads the schema rather than restating it. A hardcoded list is where
    // someone has to REMEMBER; this is where the build tells them. Same
    // technique as payment_status_test.dart and subscription_status_test.dart.
    const schema = readFileSync(
      join(__dirname, '../../../prisma/schema.prisma'),
      'utf8',
    );
    const block = /^model SubscriptionPlanConfig\s*\{([^}]*)\}/m.exec(schema);
    expect(block).not.toBeNull();

    const fromSchema = block![1]
      .split('\n')
      .map((l) => l.replace(/\/\/.*$/, '').trim())
      .filter((l) => l.startsWith('has'))
      .map((l) => l.split(/\s+/)[0]);

    // Counts must match exactly, not merely be non-empty. `> 0` rules out the
    // regex failing outright but NOT a partial capture: if a schema edit ever
    // made `[^}]*` stop early and pick up 5 of 12 flags, every one of those 5
    // would be in the array and the test would pass while missing the other 7
    // — silently failing in exactly the drift scenario it exists to catch.
    expect(fromSchema).toHaveLength(PLAN_FEATURE_FLAGS.length);
    for (const flag of fromSchema) {
      expect(PLAN_FEATURE_FLAGS).toContain(flag);
    }
  });

  it('should apply a discount to the price', () => {
    expect(discountedPrice(200, 25)).toBe(150);
  });

  it('should round a discount that does not divide evenly', () => {
    // 33% of 200 is 134.00000000000003 in IEEE 754. getSubscription used to
    // round and requestChange did not; Decimal(12,2) hid the difference on
    // write. One helper, one rounding rule.
    expect(discountedPrice(200, 33)).toBe(134);
  });

  it('should treat a null or zero discount as full price', () => {
    expect(discountedPrice(200, 0)).toBe(200);
    expect(discountedPrice(200, null)).toBe(200);
  });

  it('should make a full discount free rather than nearly free', () => {
    expect(discountedPrice(200, 100)).toBe(0);
  });

  it('should never produce a negative price', () => {
    // Unreachable today — SetDiscountDto is @Min(0) @Max(100) and is the only
    // writer. Pinned anyway because this is the one place a merchant's price
    // is decided, and "the caller validates" is not something a pricing
    // function should have to assume.
    expect(discountedPrice(200, 150)).toBe(0);
  });

  it('should ignore a negative discount rather than inflating the price', () => {
    expect(discountedPrice(200, -25)).toBe(200);
  });

  it('should expose the discounted price and every flag on the view', () => {
    const config = {
      plan: 'BUSINESS',
      price: 400,
      maxProducts: 2000,
      maxStaff: 10,
      maxDiscounts: 5,
      hasReportsAll: true,
      hasExport: false,
      hasTelegram: true,
      hasAllPush: false,
      hasDelivery: true,
      hasInventory: true,
      hasZakat: true,
      hasInvestments: true,
      hasLoyalty: true,
      hasBatchProfitability: true,
      hasEcommerceIntegration: false,
    } as any;

    const view = toPlanView(config, 25);

    expect(view.plan).toBe('BUSINESS');
    expect(view.price).toBe(300);
    expect(view.listPrice).toBe(400);
    expect(view.maxProducts).toBe(2000);
    expect(view.features.hasZakat).toBe(true);
    expect(view.features.hasEcommerceIntegration).toBe(false);
    // Every flag the schema defines, not a subset.
    expect(Object.keys(view.features).sort()).toEqual(
      [...PLAN_FEATURE_FLAGS].sort(),
    );
  });
});
