# Deferred Items Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close out 6 backlog items deliberately deferred during code review of the admin-panel-enhancements and e-commerce-integration branches (both already merged to `main`) — each item mirrors an existing, proven pattern already in the codebase, so no new design decisions are required, only implementation.

**Architecture:** Six independent, small tasks touching admin backend/frontend and mobile. No new modules, no schema changes. Task 1 is backend+admin-frontend; Tasks 2–5 are mobile-only; Task 6 is backend-only. Tasks are independent of each other and can be done in any order, though the plan lists them in a sensible sequence.

**Tech Stack:** NestJS/Prisma (backend), Next.js/TanStack Query (admin — Task 1 only), Flutter/Dio/flutter_bloc (mobile — Tasks 2–5).

---

## Origin of each item

| Task | Deferred from | Why it was deferred then |
|---|---|---|
| 1 | admin-panel-enhancements code review | `hasZakat`/`hasInvestments`/`hasLoyalty`/`hasBatchProfitability` never got the same admin-UI wiring `hasEcommerceIntegration` did — pre-existing gap, out of scope for that specific task |
| 2 | e-commerce-integration final review | `channelBreakdown` field shipped with zero consumers; design spec wanted a dashboard summary row, no task built it |
| 3 | e-commerce-integration code review | Non-PREMIUM merchants hit a generic "Недостаточно прав" error instead of an upgrade prompt — required `SubscriptionBloc` wiring not in that task's scope |
| 4 | e-commerce-integration code review | API key shown in plaintext with no mask/reveal — flagged Minor, no in-app precedent existed at the time to point to |
| 5 | e-commerce-integration code review | No search on the product-mapping screen — flagged Minor, low priority for typical catalog sizes |
| 6 | e-commerce-integration final review | `dto.totalAmount` trusted verbatim with no cross-check against computed item sum — flagged Minor, reports now surface this figure so it's worth closing |

---

## Task 1: Surface `hasZakat`/`hasInvestments`/`hasLoyalty`/`hasBatchProfitability` in the admin plan-config UI

**Context:** `SubscriptionPlanConfig` in `api/prisma/schema.prisma` already has these four boolean flags (`@default(false)`), but — unlike `hasEcommerceIntegration`, which was recently wired through as the reference pattern — none of them reach the admin UI. Confirmed via direct inspection: they're absent from `UpdatePlanDto`, from `AdminService.updatePlan()`'s whitelist, from the admin frontend's `Plan` TypeScript interface, and from the admin UI's feature-label map and fallback-data array. This task replicates the exact `hasEcommerceIntegration` pattern for all four flags at once.

**Files:**
- Modify: `api/src/modules/admin/dto/update-plan.dto.ts`
- Modify: `api/src/modules/admin/admin.service.ts`
- Modify: `api/src/modules/admin/admin.service.spec.ts`
- Modify: `admin/lib/types.ts`
- Modify: `admin/app/(admin)/subscriptions/plans/page.tsx`

- [ ] **Step 1: Add the four fields to `UpdatePlanDto`**

In `api/src/modules/admin/dto/update-plan.dto.ts`, add after the existing `hasEcommerceIntegration?: boolean;` field (the last one in the class):
```typescript
  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  hasZakat?: boolean;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  hasInvestments?: boolean;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  hasLoyalty?: boolean;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  hasBatchProfitability?: boolean;
```

- [ ] **Step 2: Add the four whitelist branches in `AdminService.updatePlan()`**

In `api/src/modules/admin/admin.service.ts`, inside `updatePlan()`, add after the existing `if (dto.hasEcommerceIntegration !== undefined) updateData.hasEcommerceIntegration = dto.hasEcommerceIntegration;` line:
```typescript
    if (dto.hasZakat !== undefined) updateData.hasZakat = dto.hasZakat;
    if (dto.hasInvestments !== undefined)
      updateData.hasInvestments = dto.hasInvestments;
    if (dto.hasLoyalty !== undefined) updateData.hasLoyalty = dto.hasLoyalty;
    if (dto.hasBatchProfitability !== undefined)
      updateData.hasBatchProfitability = dto.hasBatchProfitability;
```

- [ ] **Step 3: Write the failing tests**

Find the existing `describe('AdminService — updatePlan', () => { ... })` block in `api/src/modules/admin/admin.service.spec.ts` (it already contains one test, `updates hasEcommerceIntegration when provided`, added when that flag was wired through — use its exact fixture setup as the template) and add four more tests alongside it:
```typescript
  it('updates hasZakat when provided', async () => {
    (prisma.subscriptionPlanConfig.findUnique as jest.Mock).mockResolvedValue({
      plan: 'PREMIUM',
    });
    (prisma.subscriptionPlanConfig.update as jest.Mock).mockImplementation(
      async ({ data }: any) => ({ plan: 'PREMIUM', ...data }),
    );

    const result = await service.updatePlan('PREMIUM' as any, {
      hasZakat: true,
    } as any);

    expect(prisma.subscriptionPlanConfig.update).toHaveBeenCalledWith({
      where: { plan: 'PREMIUM' },
      data: { hasZakat: true },
    });
    expect((result as any).hasZakat).toBe(true);
  });

  it('updates hasInvestments when provided', async () => {
    (prisma.subscriptionPlanConfig.findUnique as jest.Mock).mockResolvedValue({
      plan: 'PREMIUM',
    });
    (prisma.subscriptionPlanConfig.update as jest.Mock).mockImplementation(
      async ({ data }: any) => ({ plan: 'PREMIUM', ...data }),
    );

    const result = await service.updatePlan('PREMIUM' as any, {
      hasInvestments: true,
    } as any);

    expect(prisma.subscriptionPlanConfig.update).toHaveBeenCalledWith({
      where: { plan: 'PREMIUM' },
      data: { hasInvestments: true },
    });
    expect((result as any).hasInvestments).toBe(true);
  });

  it('updates hasLoyalty when provided', async () => {
    (prisma.subscriptionPlanConfig.findUnique as jest.Mock).mockResolvedValue({
      plan: 'PREMIUM',
    });
    (prisma.subscriptionPlanConfig.update as jest.Mock).mockImplementation(
      async ({ data }: any) => ({ plan: 'PREMIUM', ...data }),
    );

    const result = await service.updatePlan('PREMIUM' as any, {
      hasLoyalty: true,
    } as any);

    expect(prisma.subscriptionPlanConfig.update).toHaveBeenCalledWith({
      where: { plan: 'PREMIUM' },
      data: { hasLoyalty: true },
    });
    expect((result as any).hasLoyalty).toBe(true);
  });

  it('updates hasBatchProfitability when provided', async () => {
    (prisma.subscriptionPlanConfig.findUnique as jest.Mock).mockResolvedValue({
      plan: 'PREMIUM',
    });
    (prisma.subscriptionPlanConfig.update as jest.Mock).mockImplementation(
      async ({ data }: any) => ({ plan: 'PREMIUM', ...data }),
    );

    const result = await service.updatePlan('PREMIUM' as any, {
      hasBatchProfitability: true,
    } as any);

    expect(prisma.subscriptionPlanConfig.update).toHaveBeenCalledWith({
      where: { plan: 'PREMIUM' },
      data: { hasBatchProfitability: true },
    });
    expect((result as any).hasBatchProfitability).toBe(true);
  });
```

- [ ] **Step 4: Run the tests to verify they fail, then pass**

Run: `cd api && npx jest admin.service.spec.ts -t updatePlan`
Expected first: FAIL (fields not yet in `UpdatePlanDto`/whitelist — but since the DTO is just a plain class with no runtime validation in this unit test, the test will actually fail at the assertion on `prisma.subscriptionPlanConfig.update`'s call args, not at compile time)
Then apply Steps 1–2, rerun: PASS (5 tests total in this describe block)

- [ ] **Step 5: Add the four fields to the admin frontend `Plan` type**

In `admin/lib/types.ts`, inside `export interface Plan { ... }`, add after `hasEcommerceIntegration: boolean;`:
```typescript
  hasZakat: boolean;
  hasInvestments: boolean;
  hasLoyalty: boolean;
  hasBatchProfitability: boolean;
```

- [ ] **Step 6: Add the four labels and fallback-data entries**

In `admin/app/(admin)/subscriptions/plans/page.tsx`, inside `const FEATURE_LABELS: Record<string, string> = { ... }`, add after `hasEcommerceIntegration: 'Интернет-магазин',`:
```typescript
  hasZakat: 'Закят',
  hasInvestments: 'Инвестиции',
  hasLoyalty: 'Программа лояльности',
  hasBatchProfitability: 'Прибыльность по партиям',
```

In the same file, find the `PLAN_CONFIGS.map((c, i) => ({ ... hasEcommerceIntegration: i === 2, }))` fallback-data object (used when the real plan list hasn't loaded yet) and add four more entries after `hasEcommerceIntegration: i === 2,`. All four flags are PREMIUM-only features conceptually (same tier as `hasEcommerceIntegration`/`hasInventory`), so mirror the same `i === 2` gating:
```typescript
          hasZakat: i === 2,
          hasInvestments: i === 2,
          hasLoyalty: i === 2,
          hasBatchProfitability: i === 2,
```

- [ ] **Step 7: Verify the admin build**

Run: `cd admin && npx tsc --noEmit`
Expected: clean.

- [ ] **Step 8: Run the full backend suite**

Run: `cd api && npx jest`
Expected: PASS, same suite count, +4 tests over baseline.

- [ ] **Step 9: Commit**

```bash
cd api
git add src/modules/admin/dto/update-plan.dto.ts src/modules/admin/admin.service.ts src/modules/admin/admin.service.spec.ts
git commit -m "feat(admin): wire hasZakat/hasInvestments/hasLoyalty/hasBatchProfitability into the plan-config update path"
cd ../admin
git add lib/types.ts "app/(admin)/subscriptions/plans/page.tsx"
git commit -m "feat(admin): surface hasZakat/hasInvestments/hasLoyalty/hasBatchProfitability in the plan-config UI"
```

---

## Task 2: Fix Sales report parsing + add "В магазине / Онлайн" revenue-split row

**Context:** Investigation before writing this task turned up something important: the mobile Sales report screen's `_loadSales()` currently reads `body['rows']` and `body['top5']` from the API response, but the backend's actual `GET /stores/:storeId/reports/sales` response has no `rows`/`top5` keys — it returns `byDate`/`topProducts` (confirmed by reading `ReportsService.getSalesReport()` directly). This is a **pre-existing bug**, unrelated to any of the 8 e-commerce-integration tasks, that predates this plan — as written, the Sales tab's date table and top-5 chart always render empty because `rowsJson`/`topJson` are always `[]`. This task fixes that bug as part of adding the new channel-split row, since the new row would otherwise sit next to obviously-broken data and be unverifiable.

**Files:**
- Modify: `app/lib/presentation/pages/finance/reports_page.dart`

- [ ] **Step 1: Fix the pre-existing key-mismatch bug in `_loadSales()`**

In `app/lib/presentation/pages/finance/reports_page.dart`, find `_loadSales()` and change:
```dart
      final rowsJson = (body['rows'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final topJson = (body['top5'] as List?)?.cast<Map<String, dynamic>>() ?? [];
```
to:
```dart
      final rowsJson = (body['byDate'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final topJson = (body['topProducts'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final channelJson = (body['channelBreakdown'] as List?)?.cast<Map<String, dynamic>>() ?? [];
```

- [ ] **Step 2: Fix `_TopProduct.fromJson`'s field names to match the real API response**

The backend's `topProducts[]` entries are `{productId, productName, totalQty, totalRevenue}`, not `{name, revenue}`. Find the `_TopProduct` class and change:
```dart
class _TopProduct {
  final String name;
  final double revenue;
  const _TopProduct({required this.name, required this.revenue});
  factory _TopProduct.fromJson(Map<String, dynamic> j) => _TopProduct(
        name: j['name'] as String? ?? '',
        revenue: (j['revenue'] as num?)?.toDouble() ?? 0,
      );
}
```
to:
```dart
class _TopProduct {
  final String name;
  final double revenue;
  const _TopProduct({required this.name, required this.revenue});
  factory _TopProduct.fromJson(Map<String, dynamic> j) => _TopProduct(
        name: j['productName'] as String? ?? '',
        revenue: (j['totalRevenue'] as num?)?.toDouble() ?? 0,
      );
}
```
(`_SalesRow.fromJson`'s field names — `date`/`count`/`revenue`/`avgCheck` — already match `byDate[]` entries exactly; no change needed there.)

- [ ] **Step 3: Add a `_ChannelRevenue` model and wire it into `_SalesData`**

Add a new small class right after `_TopProduct`:
```dart
class _ChannelRevenue {
  final String channel;
  final double revenue;
  final int count;
  const _ChannelRevenue({
    required this.channel,
    required this.revenue,
    required this.count,
  });
  factory _ChannelRevenue.fromJson(Map<String, dynamic> j) => _ChannelRevenue(
        channel: j['channel'] as String? ?? '',
        revenue: (j['revenue'] as num?)?.toDouble() ?? 0,
        count: (j['count'] as num?)?.toInt() ?? 0,
      );
}
```
Then extend `_SalesData` to carry it:
```dart
class _SalesData {
  final List<_SalesRow> rows;
  final List<_TopProduct> top5;
  final List<_ChannelRevenue> channelBreakdown;
  const _SalesData({
    required this.rows,
    required this.top5,
    required this.channelBreakdown,
  });
}
```
And update the `setState` call in `_loadSales()` that constructs it:
```dart
      setState(() {
        _salesData = _SalesData(
          rows: rowsJson.map(_SalesRow.fromJson).toList(),
          top5: topJson.map(_TopProduct.fromJson).toList(),
          channelBreakdown: channelJson.map(_ChannelRevenue.fromJson).toList(),
        );
      });
```

- [ ] **Step 4: Render the split row using the existing `_KpiCard` widget**

`_KpiCard` already exists in this file (currently used only by `_ProfitTab`) and is exactly the right building block — reuse it, don't create a new widget. In `_SalesTab`'s build method, find where it starts building its `ListView`/`Column` of content (the data table + bar chart) and insert a channel-split row at the top, before the existing content. Locate the two `_ChannelRevenue` entries by `channel` (there may be 0, 1, or 2 entries depending on whether the store has any sales in each channel yet) and render:
```dart
                Builder(builder: (context) {
                  final breakdown = data.channelBreakdown;
                  double revenueFor(String channel) => breakdown
                      .firstWhere(
                        (c) => c.channel == channel,
                        orElse: () => const _ChannelRevenue(channel: '', revenue: 0, count: 0),
                      )
                      .revenue;
                  return Row(
                    children: [
                      Expanded(
                        child: _KpiCard(
                          label: 'В магазине',
                          value: fmtPrice(revenueFor('IN_STORE')),
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: AppConstants.spacingSm),
                      Expanded(
                        child: _KpiCard(
                          label: 'Онлайн',
                          value: fmtPrice(revenueFor('ONLINE')),
                          color: context.success,
                        ),
                      ),
                    ],
                  );
                }),
                const SizedBox(height: AppConstants.spacingSm),
```
(`fmtPrice` is the existing price-formatting helper already used elsewhere in this file/its tabs — confirm its exact name and signature by reading `_ProfitTab`'s usage of it before writing this step's final code, and adjust the call if the real helper has a different name or is a top-level function vs. a method on `_ReportsPageState` that needs to be passed down or accessed via `widget`/`context`.)

Locate the exact variable name that holds the parsed `_SalesData` inside `_SalesTab` (it's passed in as a constructor parameter from `_ReportsPageState.build()`, likely named `data` or `salesData` — read the actual `_SalesTab` class declaration to confirm the exact parameter name before writing this code) and use that instead of the placeholder `data` above if it differs.

- [ ] **Step 5: Run `flutter analyze` on the touched file**

Run: `cd app && flutter analyze lib/presentation/pages/finance/reports_page.dart`
Expected: No issues found.

- [ ] **Step 6: Update the existing golden test for this page**

Since this changes `_SalesTab`'s rendered layout, the existing golden fixtures need regenerating (the same step Task 7 of the e-commerce-integration plan did correctly, and Task 8 of that plan missed for a different page — don't repeat that mistake here). Run:
```bash
cd app
flutter test --update-goldens test/presentation/pages/finance/reports_page_golden_test.dart
```
Visually inspect the regenerated `reports_light.png`/`reports_dark.png` to confirm the new "В магазине / Онлайн" row renders correctly and the sales table/chart now show real data (not empty, confirming Step 1–2's bug fix worked). Rerun normally to confirm it now passes:
```bash
flutter test test/presentation/pages/finance/reports_page_golden_test.dart
```
Expected: PASS.

- [ ] **Step 7: Manual verification**

If a live backend+DB is reachable with a store that has both `IN_STORE` and `ONLINE` sales in the selected period, run the app and confirm the Sales tab now shows real data in the table/chart (proving Steps 1–2's fix) and the new split row shows correct revenue per channel. If not reachable in this environment, rely on Steps 5–6's `flutter analyze`/golden-test verification instead, and note in your report which you did.

- [ ] **Step 8: Commit**

```bash
git add app/lib/presentation/pages/finance/reports_page.dart app/test/presentation/pages/finance/goldens/
git commit -m "fix(mobile): fix sales report key mismatch and add channel revenue split row"
```

---

## Task 3: Friendly upsell for the "Интернет-магазин" tile on non-PREMIUM stores

**Context:** `settings_page.dart` currently shows the "Интернет-магазин" tile unconditionally to every merchant regardless of plan. A non-PREMIUM merchant who taps it gets a generic "Недостаточно прав" error from the backend's 403 — no indication this is a plan-upgrade opportunity, not a permissions bug. A comparable gating pattern already exists in `reports_page.dart` (a `BlocBuilder<SubscriptionBloc, SubscriptionState>` checking `sub.features.hasExport`), but it *hides* the gated option entirely rather than showing an upsell — and `SubscriptionFeatures` doesn't even parse `hasEcommerceIntegration` yet. This task adds the field, then goes one step further than the `hasExport` reference pattern: instead of hiding the tile, it stays visible with a "PREMIUM" badge (the `_buildTile` helper already supports a `badge`/`badgeColor` parameter, currently used for Telegram's "Подключён" badge) and tapping it while ineligible shows a friendly dialog directing the merchant to the "Тариф" (subscription) screen, rather than silently hiding a feature they might not know exists.

**Files:**
- Modify: `app/lib/presentation/blocs/subscription/subscription_state.dart`
- Modify: `app/lib/presentation/pages/settings/settings_page.dart`

- [ ] **Step 1: Add `hasEcommerceIntegration` to `SubscriptionFeatures`**

In `app/lib/presentation/blocs/subscription/subscription_state.dart`, extend the `SubscriptionFeatures` class — add the field to the constructor, `fromJson`, `defaults()`, `hasFeature()`, and `props`:
```dart
class SubscriptionFeatures extends Equatable {
  final bool hasReportsAll;
  final bool hasExport;
  final bool hasTelegram;
  final bool hasAllPush;
  final bool hasDelivery;
  final bool hasInventory;
  final bool hasEcommerceIntegration;

  const SubscriptionFeatures({
    required this.hasReportsAll,
    required this.hasExport,
    required this.hasTelegram,
    required this.hasAllPush,
    required this.hasDelivery,
    required this.hasInventory,
    required this.hasEcommerceIntegration,
  });

  factory SubscriptionFeatures.fromJson(Map<String, dynamic> json) =>
      SubscriptionFeatures(
        hasReportsAll: json['hasReportsAll'] as bool? ?? false,
        hasExport: json['hasExport'] as bool? ?? false,
        hasTelegram: json['hasTelegram'] as bool? ?? false,
        hasAllPush: json['hasAllPush'] as bool? ?? false,
        hasDelivery: json['hasDelivery'] as bool? ?? false,
        hasInventory: json['hasInventory'] as bool? ?? false,
        hasEcommerceIntegration: json['hasEcommerceIntegration'] as bool? ?? false,
      );

  factory SubscriptionFeatures.defaults() => const SubscriptionFeatures(
        hasReportsAll: false,
        hasExport: false,
        hasTelegram: false,
        hasAllPush: false,
        hasDelivery: false,
        hasInventory: false,
        hasEcommerceIntegration: false,
      );

  bool hasFeature(String key) {
    switch (key) {
      case 'hasReportsAll': return hasReportsAll;
      case 'hasExport': return hasExport;
      case 'hasTelegram': return hasTelegram;
      case 'hasAllPush': return hasAllPush;
      case 'hasDelivery': return hasDelivery;
      case 'hasInventory': return hasInventory;
      case 'hasEcommerceIntegration': return hasEcommerceIntegration;
      default: return true;
    }
  }

  @override
  List<Object?> get props => [
        hasReportsAll,
        hasExport,
        hasTelegram,
        hasAllPush,
        hasDelivery,
        hasInventory,
        hasEcommerceIntegration,
      ];
}
```

**Before running any tests:** this class is `required`-constructor, so search the codebase for every other place that constructs a `SubscriptionFeatures(...)` literal (not via `.fromJson()`/`.defaults()`) — e.g. test fixtures — and add `hasEcommerceIntegration: <value>` to each, or the build will fail to compile. Run `grep -rn "SubscriptionFeatures(" app/lib app/test` to find every call site before proceeding.

- [ ] **Step 2: Run `flutter analyze` to catch any missed constructor call sites**

Run: `cd app && flutter analyze`
Expected: no new "missing required argument" errors. Fix any that appear by adding `hasEcommerceIntegration: false` (or the appropriate test value) to the flagged call sites, then re-run until clean.

- [ ] **Step 3: Dispatch `SubscriptionLoadRequested` from `SettingsPage.initState()`**

Without this, `SubscriptionBloc`'s state stays `SubscriptionInitial` until the merchant separately visits the "Тариф" screen, so the gate below would always show the ineligible state even for PREMIUM merchants who haven't visited that screen yet. In `app/lib/presentation/pages/settings/settings_page.dart`, add the imports:
```dart
import '../../blocs/subscription/subscription_bloc.dart';
import '../../blocs/subscription/subscription_event.dart';
import '../../blocs/subscription/subscription_state.dart';
```
Then extend `initState()` (currently just dispatches `SettingsProfileRequested()`) to also load subscription state, mirroring `subscription_page.dart`'s own `initState()`:
```dart
  @override
  void initState() {
    super.initState();
    context.read<SettingsBloc>().add(SettingsProfileRequested());
    final storeId = _getStoreId();
    if (storeId.isNotEmpty) {
      context.read<SubscriptionBloc>().add(SubscriptionLoadRequested(storeId: storeId));
    }
  }
```
(`_getStoreId()` already exists in this file's state class — reuse it rather than duplicating its `StoreBloc` lookup logic.)

- [ ] **Step 4: Add the upsell dialog helper**

Add a new private method to `_SettingsPageState`, alongside the existing `_showLogoutDialog()`:
```dart
  void _showPremiumUpsellDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Доступно на тарифе PREMIUM'),
        content: const Text(
          'Интеграция с интернет-магазином доступна на тарифе PREMIUM. Перейдите на PREMIUM, чтобы синхронизировать остатки и заказы с вашим сайтом.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Позже'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.push(RouteNames.subscription);
            },
            child: const Text('Перейти к тарифам'),
          ),
        ],
      ),
    );
  }
```

- [ ] **Step 5: Wrap the "Интернет-магазин" tile in a `BlocBuilder`**

Find the "Интеграции" section's `_buildSectionCard([...])` block and replace the single unconditional tile:
```dart
                          _buildTile(Icons.storefront_outlined, 'Интернет-магазин',
                            onTap: () => context.push(RouteNames.ecommerceSettings, extra: _getStoreId())),
```
with a `BlocBuilder`-wrapped version that shows a "PREMIUM" badge and routes to the upsell dialog when ineligible:
```dart
                          BlocBuilder<SubscriptionBloc, SubscriptionState>(
                            builder: (_, sub) {
                              final hasEcommerce = sub is SubscriptionLoaded &&
                                  sub.features.hasEcommerceIntegration;
                              return _buildTile(
                                Icons.storefront_outlined,
                                'Интернет-магазин',
                                badge: hasEcommerce ? null : 'PREMIUM',
                                badgeColor: hasEcommerce ? null : AppColors.warning,
                                onTap: hasEcommerce
                                    ? () => context.push(RouteNames.ecommerceSettings, extra: _getStoreId())
                                    : _showPremiumUpsellDialog,
                              );
                            },
                          ),
```
(Confirm `AppColors.warning` exists — if this codebase's `AppColors` uses a different name for an amber/orange "upgrade" accent color, use the real one; check `app/lib/core/constants/app_colors.dart`.)

- [ ] **Step 6: Run `flutter analyze` on the touched files**

Run: `cd app && flutter analyze lib/presentation/pages/settings/settings_page.dart lib/presentation/blocs/subscription/subscription_state.dart`
Expected: No issues found.

- [ ] **Step 7: Update or add tests**

Check whether `app/test/presentation/pages/settings/settings_page_test.dart` (a non-golden widget test, distinct from the golden test) exists. If it does, read its existing fixture/mocking conventions and add a test confirming: (a) a `SubscriptionLoaded` state with `hasEcommerceIntegration: true` renders the tile without a badge and navigates on tap; (b) a `SubscriptionLoaded` state with `hasEcommerceIntegration: false` (or `SubscriptionInitial`) renders the tile WITH a "PREMIUM" badge and shows the upsell dialog on tap instead of navigating. If no such test file exists, it's acceptable to skip adding one for this task (don't build new test infrastructure from scratch for a settings page that has none) — but do regenerate the golden test per Step 8 below, since that will visually catch a broken badge render even without a dedicated interaction test.

- [ ] **Step 8: Regenerate the `SettingsPage` golden test**

This change alters the Settings page's rendered layout (badge on the Интернет-магазин tile). Regenerate:
```bash
cd app
flutter test --update-goldens test/presentation/pages/settings/settings_page_golden_test.dart
```
Visually confirm the badge renders correctly, then rerun normally to confirm it passes:
```bash
flutter test test/presentation/pages/settings/settings_page_golden_test.dart
```
Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add app/lib/presentation/blocs/subscription/subscription_state.dart app/lib/presentation/pages/settings/settings_page.dart app/test/presentation/pages/settings/goldens/
git commit -m "feat(mobile): show a PREMIUM upsell dialog instead of a generic error for the e-commerce settings tile"
```

---

## Task 4: Mask the API key by default with tap-to-reveal

**Context:** `EcommerceSettingsPage` displays three fields via two different widgets: the inbound webhook URL and the API key both use the shared `_CopyableField` widget; the outbound webhook URL uses a plain editable `TextField`. Only the API key — a genuine bearer credential — should be masked by default. Since `_CopyableField` is shared with the inbound-URL field (which should NOT be masked), this task adds an opt-in `obscure` parameter to `_CopyableField` rather than changing its default behavior, and passes it only from the API-key call site.

**Files:**
- Modify: `app/lib/presentation/pages/settings/ecommerce_settings_page.dart`

- [ ] **Step 1: Add an `obscure` parameter to `_CopyableField`, defaulting to `false`**

Find the `_CopyableField` class and change it to support masking with tap-to-reveal:
```dart
class _CopyableField extends StatefulWidget {
  final String value;
  final VoidCallback? onCopy;
  final bool obscure;
  const _CopyableField({
    required this.value,
    required this.onCopy,
    this.obscure = false,
  });

  @override
  State<_CopyableField> createState() => _CopyableFieldState();
}

class _CopyableFieldState extends State<_CopyableField> {
  bool _revealed = false;

  String get _displayValue {
    if (!widget.obscure || _revealed) return widget.value;
    // Mask everything except keep the string length roughly indicative —
    // a fixed-width mask avoids leaking the real key's length exactly,
    // while still visually reading as "there's a secret here".
    return '•' * 24;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: context.border),
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(_displayValue,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
          ),
          if (widget.obscure)
            IconButton(
              icon: Icon(_revealed ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
              onPressed: () => setState(() => _revealed = !_revealed),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          if (widget.onCopy != null)
            IconButton(
              icon: const Icon(Icons.copy_outlined, size: 18),
              onPressed: widget.onCopy,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }
}
```
(Converted from `StatelessWidget` to `StatefulWidget` since it now owns local `_revealed` state — this is necessary, not optional, since the reveal toggle must persist across rebuilds of just this widget without affecting the parent page's state.)

- [ ] **Step 2: Pass `obscure: true` only from the API-key call site**

Find the two `_CopyableField` usages in `EcommerceSettingsPage.build()`. Leave the inbound-URL one unchanged:
```dart
                _CopyableField(
                  value: _inboundWebhookUrl,
                  onCopy: () => _copy(_inboundWebhookUrl, 'URL'),
                ),
```
Add `obscure: true` only to the API-key one:
```dart
                _CopyableField(
                  value: _configured
                      ? (_apiKey ?? '—')
                      : 'Сохраните настройки, чтобы создать ключ',
                  onCopy: _apiKey == null ? null : () => _copy(_apiKey!, 'Ключ'),
                  obscure: _configured && _apiKey != null,
                ),
```
(`obscure` is conditioned on `_configured && _apiKey != null` so the "not yet configured" placeholder text and the reveal-toggle icon don't show together — masking a placeholder sentence would look broken.)

- [ ] **Step 3: Run `flutter analyze` on the touched file**

Run: `cd app && flutter analyze lib/presentation/pages/settings/ecommerce_settings_page.dart`
Expected: No issues found.

- [ ] **Step 4: Update the existing widget tests**

`app/test/presentation/pages/settings/ecommerce_settings_page_test.dart` already has a test asserting the clipboard copy behavior for the API key. Read that test and confirm it still passes unchanged (copying should work identically regardless of masked/revealed state — `onCopy` always copies the real `_apiKey` value, never the masked display string, since `_copy()` is called with `_apiKey!` directly, not `_displayValue`). Add one new test:
```dart
  testWidgets('API key is masked by default and reveals on tap', (tester) async {
    when(() => mockDioClient.get(any(), queryParameters: any(named: 'queryParameters')))
        .thenAnswer((_) async => Response(
              data: {
                'apiKey': 'super-secret-key-value',
                'enabled': true,
                'outboundWebhookUrl': null,
              },
              requestOptions: RequestOptions(path: ''),
            ));

    await tester.pumpWidget(makeTestableWidget(const EcommerceSettingsPage(storeId: 'store-1')));
    await tester.pumpAndSettle();

    expect(find.text('super-secret-key-value'), findsNothing);
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pump();

    expect(find.text('super-secret-key-value'), findsOneWidget);
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
  });
```
(Match the exact mock setup style — `when(() => mockDioClient.get(...))`, `makeTestableWidget(...)`, response shape — to whatever the existing tests in this file already use; read the file first and adjust this snippet's mocking calls to match the real helper names/signatures rather than assuming they're exactly as written here.)

- [ ] **Step 5: Run the tests**

Run: `cd app && flutter test test/presentation/pages/settings/ecommerce_settings_page_test.dart`
Expected: PASS, including the new test.

- [ ] **Step 6: Commit**

```bash
git add app/lib/presentation/pages/settings/ecommerce_settings_page.dart app/test/presentation/pages/settings/ecommerce_settings_page_test.dart
git commit -m "feat(mobile): mask the e-commerce API key by default with tap-to-reveal"
```

---

## Task 5: Add search to the product mapping screen

**Context:** `EcommerceProductMappingPage` fetches up to 1000 products up front and renders them all in a flat `ListView.separated` with no filtering. For a store with a large catalog, finding one product to map is tedious. This is a pure client-side addition — no backend changes, since the full list is already fetched.

**Files:**
- Modify: `app/lib/presentation/pages/settings/ecommerce_product_mapping_page.dart`

- [ ] **Step 1: Add search state**

In `_EcommerceProductMappingPageState`, add a query field and its controller, alongside the existing `_products`/`_controllers`:
```dart
  final _searchController = TextEditingController();
  String _query = '';
```
Update `dispose()` to also dispose it:
```dart
  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _searchController.dispose();
    super.dispose();
  }
```

- [ ] **Step 2: Compute the filtered list in `build()`**

At the top of `build()`, before the `Scaffold` is constructed, compute the filtered list:
```dart
    final filtered = _query.isEmpty
        ? _products
        : _products
            .where((p) => (p['name'] as String? ?? '')
                .toLowerCase()
                .contains(_query.toLowerCase()))
            .toList();
```
(`_controllers` stays keyed by product `id`, not list index, so filtering the display list doesn't disturb controller lookups — no change needed there.)

- [ ] **Step 3: Add the search field above the list**

Change the `body:` from a bare `ListView.separated` to a `Column` with a search field on top, only shown once loading completes:
```dart
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Поиск по названию товара',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Text(
                            _query.isEmpty ? 'Нет товаров' : 'Ничего не найдено',
                            style: TextStyle(color: context.textSecondary),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: filtered.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final product = filtered[index];
                            final id = product['id'] as String;
                            final name = product['name'] as String? ?? '';
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Text(name, style: const TextStyle(fontSize: 14)),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: TextField(
                                      controller: _controllers[id],
                                      decoration: const InputDecoration(
                                        hintText: 'Внешний ID',
                                        isDense: true,
                                        border: OutlineInputBorder(),
                                      ),
                                      onSubmitted: (_) => _saveMapping(id),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.check, size: 20),
                                    onPressed: () => _saveMapping(id),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
```
(The `itemBuilder` body is unchanged from the original — only the source list it reads from changed, from `_products[index]` to `filtered[index]`, and it's now nested inside the new `Column`/`Expanded` structure.)

- [ ] **Step 4: Run `flutter analyze` on the touched file**

Run: `cd app && flutter analyze lib/presentation/pages/settings/ecommerce_product_mapping_page.dart`
Expected: No issues found.

- [ ] **Step 5: Update the existing widget test**

`app/test/presentation/pages/settings/ecommerce_product_mapping_page_test.dart` already has tests covering the product list rendering and save behavior. Read them and confirm they still pass (they should, since filtering only activates when `_query` is non-empty and defaults to showing everything). Add one new test:
```dart
  testWidgets('typing in the search field filters the product list by name', (tester) async {
    when(() => mockDioClient.get(any(), queryParameters: any(named: 'queryParameters')))
        .thenAnswer((_) async => Response(
              data: {
                'data': [
                  {'id': 'p1', 'name': 'Молоко'},
                  {'id': 'p2', 'name': 'Хлеб'},
                ],
              },
              requestOptions: RequestOptions(path: ''),
            ));
    when(() => mockDioClient.get('/stores/store-1/ecommerce/mappings'))
        .thenAnswer((_) async => Response(data: [], requestOptions: RequestOptions(path: '')));

    await tester.pumpWidget(makeTestableWidget(const EcommerceProductMappingPage(storeId: 'store-1')));
    await tester.pumpAndSettle();

    expect(find.text('Молоко'), findsOneWidget);
    expect(find.text('Хлеб'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'мол');
    await tester.pump();

    expect(find.text('Молоко'), findsOneWidget);
    expect(find.text('Хлеб'), findsNothing);
  });
```
(Match the exact mock setup style to whatever the existing tests in this file already use — read the file first for the real `mockDioClient`/`makeTestableWidget` helper names and the exact query-param mocking convention already established for the products-list `GET` call, and adjust this snippet accordingly. `find.byType(TextField).first` assumes the search field is the first `TextField` on screen when the list has loaded — verify this is true given the real widget tree, or use a more specific finder like a `Key` on the search `TextField` if ambiguity is a concern.)

- [ ] **Step 6: Run the tests**

Run: `cd app && flutter test test/presentation/pages/settings/ecommerce_product_mapping_page_test.dart`
Expected: PASS, including the new test.

- [ ] **Step 7: Commit**

```bash
git add app/lib/presentation/pages/settings/ecommerce_product_mapping_page.dart app/test/presentation/pages/settings/ecommerce_product_mapping_page_test.dart
git commit -m "feat(mobile): add search to the product mapping screen"
```

---

## Task 6: Validate `dto.totalAmount` against the computed item sum in the inbound webhook

**Context:** `EcommerceOrdersService.createOrder()` currently trusts `dto.totalAmount` verbatim for `Sale.subtotal`/`total`/`paidAmount`, with no cross-check against the sum of `item.price * item.quantity` (falling back to `product.sellPrice` per item when `item.price` is omitted). Since Task 7 of the e-commerce-integration plan made this figure directly visible in per-channel revenue reports, a malformed or buggy merchant-site payload can now silently skew reported ONLINE revenue. This is genuinely new validation territory for this codebase — `SalesService.create()` never trusts a client-supplied total either, but takes the opposite approach (always computes its own total server-side and never rejects on mismatch, since over/under-payment is a legitimate state for in-store card/cash sales). The inbound webhook's `totalAmount` has no such legitimate-mismatch use case — it's meant to describe exactly what the customer paid on the external site — so rejecting a material mismatch is the right call here, following this file's own established pattern of validating and notifying *before* the transaction opens (matching the "missing mapping" and "insufficient stock" rejection paths already in this method).

**Files:**
- Modify: `api/src/modules/ecommerce/ecommerce-orders.service.ts`
- Test: `api/src/modules/ecommerce/ecommerce-orders.service.spec.ts`

- [ ] **Step 1: Write the failing test**

Add to `api/src/modules/ecommerce/ecommerce-orders.service.spec.ts`, alongside the existing "rejects the whole order (422)" tests:
```typescript
  it('rejects the whole order (422) and notifies the owner when totalAmount does not match the computed item sum', async () => {
    // makeOrderCreatedDto()'s default items ([{externalProductId: 'sku-1', quantity: 2, price: 150}])
    // compute to 300 — set totalAmount far enough off that it can't be
    // rounding noise (see the tolerance constant in Step 3).
    const dto = makeOrderCreatedDto({ totalAmount: 999 });

    await expect(service.handleWebhook('store-1', 'valid-key', dto)).rejects.toThrow();
    expect(prisma.__tx.sale.create).not.toHaveBeenCalled();
    expect(notifications.sendToStoreUsers).toHaveBeenCalledWith(
      'store-1',
      expect.any(String),
      expect.any(String),
      'ECOMMERCE_ORDER_REJECTED',
    );
  });

  it('accepts an order whose totalAmount matches the computed item sum exactly', async () => {
    const dto = makeOrderCreatedDto({ totalAmount: 300 });

    const result = await service.handleWebhook('store-1', 'valid-key', dto);

    expect((result as any).id).toBe('sale-1');
  });

  it('accepts an order whose totalAmount is within a small rounding tolerance of the computed item sum', async () => {
    const dto = makeOrderCreatedDto({ totalAmount: 300.01 });

    const result = await service.handleWebhook('store-1', 'valid-key', dto);

    expect((result as any).id).toBe('sale-1');
  });
```

- [ ] **Step 2: Run the tests to verify the first one fails**

Run: `cd api && npx jest ecommerce-orders.service.spec.ts -t "totalAmount"`
Expected: the "does not match" test FAILS (currently accepts any `totalAmount`); the other two currently PASS already (no validation exists yet, so nothing rejects them).

- [ ] **Step 3: Add the cross-check, placed before the transaction opens**

In `api/src/modules/ecommerce/ecommerce-orders.service.ts`, `createOrder()`, find the stock-sufficiency validation loop (the `for (const item of items) { ... if (!product || product.quantity < item.quantity) { ... } }` block) and add the new check immediately after it, still before the `subscription`/`planConfig` lookups:
```typescript
    // Cross-check the merchant-supplied totalAmount against what Dukon
    // independently computes from the line items, mirroring each item's
    // own price fallback (item.price ?? product.sellPrice) so an order
    // that legitimately omits per-item prices doesn't false-positive here.
    // Unlike SalesService (which always computes its own total and never
    // rejects on a paidAmount mismatch, since over/under-payment is a
    // legitimate in-store state), the webhook's totalAmount is meant to
    // describe exactly what the customer paid on the external site — a
    // material mismatch indicates a bug or tampering on the site's side,
    // not a legitimate business state, so it's rejected the same way a
    // missing mapping or insufficient stock is.
    const TOTAL_AMOUNT_TOLERANCE = 0.01;
    const computedTotal = items.reduce((sum, item) => {
      const productId = mappingByExternalId.get(item.externalProductId)!.productId;
      const product = productById.get(productId)!;
      const unitPrice = item.price ?? Number(product.sellPrice);
      return sum + unitPrice * item.quantity;
    }, 0);
    if (Math.abs(computedTotal - dto.totalAmount!) > TOTAL_AMOUNT_TOLERANCE) {
      await this.notifications.sendToStoreUsers(
        storeId,
        'Заказ с сайта отклонён',
        `Заказ ${dto.externalOrderId} отклонён — переданная сумма заказа (${dto.totalAmount}) не совпадает с суммой по товарам (${computedTotal.toFixed(2)}).`,
        'ECOMMERCE_ORDER_REJECTED',
      );
      throw new UnprocessableEntityException(
        `totalAmount (${dto.totalAmount}) does not match computed item sum (${computedTotal.toFixed(2)})`,
      );
    }
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd api && npx jest ecommerce-orders.service.spec.ts`
Expected: PASS (all tests in the file, including the 3 new ones).

- [ ] **Step 5: Run the full backend suite**

Run: `cd api && npx jest`
Expected: PASS.

- [ ] **Step 6: Run typecheck**

Run: `cd api && npx tsc --noEmit`
Expected: clean.

- [ ] **Step 7: Commit**

```bash
cd api
git add src/modules/ecommerce/ecommerce-orders.service.ts src/modules/ecommerce/ecommerce-orders.service.spec.ts
git commit -m "feat(ecommerce): reject webhook orders whose totalAmount doesn't match the computed item sum"
```

---

## Final check

- [ ] Run `cd api && npx jest` — full backend suite green.
- [ ] Run `cd api && npx tsc --noEmit` — clean.
- [ ] Run `cd admin && npx tsc --noEmit` — clean.
- [ ] Run `cd app && flutter analyze` — no new issues introduced by this plan's mobile changes.
- [ ] Confirm all 6 tasks' commits are present via `git log --oneline` since this plan's first commit.
