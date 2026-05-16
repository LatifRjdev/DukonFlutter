# Spec E "Flutter UX Cleanup" Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Drain the user-facing G.2 P2/P3 backlog: zakat calculator/history/settings polish + investment_bloc UX flicker + bloc tests + l10n keys + 1 dead-code deletion.

**Architecture:** Mostly surgical edits. One backend slice (`ZakatSettings.cashOnHand` schema + service + DTO) so the existing `includeCash` flag has a real value to read. Established `now: DateTime Function()?` injection pattern reused (5th time). New `InvestmentLoaded.isRefreshing` field eliminates filter-tap flicker. 3 new l10n keys move bloc strings out of source.

**Tech Stack:** NestJS 10 + Prisma 6.19 + Postgres 16 (backend slice). Flutter 3.x with Bloc + AppLocalizations.

**Spec:** `docs/superpowers/specs/2026-05-16-spec-e-flutter-ux-cleanup-design.md` (commit 7f6a6e6).

---

## File Structure

**Backend (sub-section A.2 + B.3 + E):**
- Modify: `api/prisma/schema.prisma` — `ZakatSettings.cashOnHand`
- Create: `api/prisma/migrations/20260516200000_zakat_cash_on_hand/migration.sql`
- Modify: `api/src/modules/zakat/dto/upsert-zakat-settings.dto.ts`
- Modify: `api/src/modules/zakat/zakat.service.ts` — `calculate()` reads `settings.cashOnHand`
- Modify: `api/src/modules/zakat/zakat.service.spec.ts` — new test for cashOnHand inclusion
- DELETE: `api/src/modules/products/stock-movements.controller.ts` (Spec B finding)

**Flutter:**
- Modify: `app/lib/presentation/pages/zakat/zakat_calculator_page.dart` (A.1 + A.3)
- Modify: `app/lib/presentation/pages/zakat/zakat_settings_page.dart` (C.1 + C.2 + C.3 + cash-on-hand input from A.2)
- Modify: `app/lib/presentation/pages/zakat/zakat_history_page.dart` (B.1 + B.2)
- Modify: `app/lib/presentation/blocs/zakat/zakat_event.dart` (pagination event field)
- Modify: `app/lib/presentation/blocs/zakat/zakat_state.dart` (pagination state fields)
- Modify: `app/lib/presentation/blocs/zakat/zakat_bloc.dart` (pagination handler)
- Modify: `app/lib/presentation/blocs/investment/investment_state.dart` (`isRefreshing`)
- Modify: `app/lib/presentation/blocs/investment/investment_bloc.dart` (D.1 + D.2 + D.4)
- Create: `app/lib/presentation/blocs/investment/investment_l10n_key.dart` (enum)
- Modify: `app/lib/presentation/pages/finance/investment_list_page.dart` (consume isRefreshing + resolve l10n)
- Modify: `app/lib/l10n/app_ru.arb` + `app_tg.arb` + `app_uz.arb` (3 new keys)
- Auto-regen: `app/lib/l10n/app_localizations*.dart`
- Create: `app/test/presentation/blocs/investment/investment_bloc_test.dart`

---

## Task E.1: Delete dead `stock-movements.controller.ts`

**Files:**
- DELETE: `api/src/modules/products/stock-movements.controller.ts`

- [ ] **Step 1: Verify it's truly unreachable**

```bash
grep -rn "StockMovementsController\b" /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/src/
```
Expected: only the file itself defines the class. NO `imports: [...]`, NO `controllers: [...]` arrays reference it.

If grep finds another reference, STOP — file is reachable. Escalate.

- [ ] **Step 2: Delete the file**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git rm api/src/modules/products/stock-movements.controller.ts
```

- [ ] **Step 3: Verify build still passes**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api
npx tsc --noEmit 2>&1 | grep "error TS" | head
npm test 2>&1 | grep "Tests:" | tail
```
Expected: 0 new errors; tests count unchanged at 222.

- [ ] **Step 4: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git commit -m "chore(stock-movements): delete dead controller (Spec B finding)

Spec E: this file declared @Controller('stores/:storeId/stock-movements')
but was never registered in any module. The real stock-movement
endpoint lives on ProductsController at
POST /stores/:storeId/products/:productId/stock-movements."
```

---

## Task A.2.1: Schema + migration for `ZakatSettings.cashOnHand`

**Files:**
- Modify: `api/prisma/schema.prisma`
- Create: `api/prisma/migrations/20260516200000_zakat_cash_on_hand/migration.sql`

- [ ] **Step 1: Edit schema**

Find `model ZakatSettings`. Insert `cashOnHand` field BEFORE `includeStock`:

```prisma
  zakatRate     Decimal   @default(2.5) @db.Decimal(5, 2)
  // Spec E: merchant-supplied cash on hand. Calculated into
  // totalAssets when includeCash=true. Default 0 so existing
  // rows continue to compute correctly until merchant fills in.
  cashOnHand    Decimal   @default(0) @db.Decimal(12, 2)
  includeStock  Boolean   @default(true)
  includeCash   Boolean   @default(true)
```

- [ ] **Step 2: Verify schema validates**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api
npx prisma format 2>&1 | tail -3
npx prisma validate 2>&1 | tail -3
```
Expected: `Schema is valid`.

- [ ] **Step 3: Create migration directory + SQL**

```bash
mkdir -p /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/prisma/migrations/20260516200000_zakat_cash_on_hand
```

Write `api/prisma/migrations/20260516200000_zakat_cash_on_hand/migration.sql`:
```sql
-- Spec E A.2: cash-on-hand for zakat calculation.
-- Default 0 so existing rows compute correctly until merchant
-- fills it in. CHECK constraint matches the other zakat money
-- columns.
ALTER TABLE "zakat_settings" ADD COLUMN "cashOnHand" DECIMAL(12,2) NOT NULL DEFAULT 0;
ALTER TABLE "zakat_settings"
  ADD CONSTRAINT zakat_settings_cash_on_hand_non_negative
    CHECK ("cashOnHand" >= 0);
```

- [ ] **Step 4: Apply via psql**

```bash
cat /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/prisma/migrations/20260516200000_zakat_cash_on_hand/migration.sql | docker exec -i dukonpro-db psql -U dukonpro -d dukonpro 2>&1
```
Expected: 2 `ALTER TABLE` lines.

- [ ] **Step 5: Register + regen client**

```bash
docker exec dukonpro-db psql -U dukonpro -d dukonpro -c \
  "INSERT INTO _prisma_migrations (id, checksum, finished_at, migration_name, logs, rolled_back_at, started_at, applied_steps_count) VALUES (gen_random_uuid()::text, 'manual-zakat-cash-on-hand', NOW(), '20260516200000_zakat_cash_on_hand', NULL, NULL, NOW(), 1);"
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api
npx prisma generate 2>&1 | tail -3
```

- [ ] **Step 6: Verify**

```bash
docker exec dukonpro-db psql -U dukonpro -d dukonpro -c \
  "\\d zakat_settings" | grep -i "cashOnHand"
```
Expected: row showing `cashOnHand | numeric(12,2) | NOT NULL | 0`.

- [ ] **Step 7: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git add api/prisma/schema.prisma api/prisma/migrations/20260516200000_zakat_cash_on_hand/
git commit -m "schema(zakat): cashOnHand column + CHECK constraint"
```

---

## Task A.2.2: DTO + service `calculate()` reads `cashOnHand`

**Files:**
- Modify: `api/src/modules/zakat/dto/upsert-zakat-settings.dto.ts`
- Modify: `api/src/modules/zakat/zakat.service.ts`

- [ ] **Step 1: Add `cashOnHand` to DTO**

Edit `api/src/modules/zakat/dto/upsert-zakat-settings.dto.ts`. Add:
```typescript
@ApiPropertyOptional({ description: 'Cash on hand (TJS) included in total assets when includeCash=true' })
@IsOptional()
@IsNumber()
@Min(0)
cashOnHand?: number;
```

(Imports `IsOptional, IsNumber, Min, ApiPropertyOptional` should already be present from earlier sprints — verify via grep.)

- [ ] **Step 2: Update service `calculate()` to read settings.cashOnHand**

Edit `api/src/modules/zakat/zakat.service.ts`. Find the `calculate` method. Locate the `cashOnHand` line:

```typescript
const cashOnHand = new Decimal(settings?.cashOnHand ?? 0);
```

The current code likely reads it as `0` literal. Change to read from settings, gated by `includeCash`:

```typescript
// Spec E A.2: cashOnHand from settings, gated by includeCash flag.
const cashOnHand = settings?.includeCash === false
  ? new Decimal(0)
  : new Decimal(settings?.cashOnHand ?? 0);
```

(If existing code already has this gating, just remove the literal-0 fallback. Read carefully first.)

- [ ] **Step 3: Add a unit test asserting cashOnHand inclusion**

Edit `api/src/modules/zakat/zakat.service.spec.ts`. Add a new test inside the existing calculate describe block:

```typescript
it('includes cashOnHand in totalAssets when includeCash is true', async () => {
  // Setup: ZakatSettings with cashOnHand=1500, includeCash=true,
  // and zero products/customers/suppliers so totalAssets=cashOnHand.
  const settings = {
    storeId: 'store-1',
    nisabAmount: new Decimal('100'),
    nisabGold: new Decimal(85),
    nisabSilver: new Decimal(595),
    nisabCurrency: 'TJS',
    haulStartDate: null,
    zakatRate: new Decimal('2.5'),
    cashOnHand: new Decimal('1500'),
    includeStock: true,
    includeCash: true,
    includeDebts: true,
  };
  (prisma.zakatSettings.findUnique as jest.Mock).mockResolvedValue(settings);
  (prisma.product.aggregate as jest.Mock).mockResolvedValue({ _sum: { quantity: 0 } });
  (prisma.$queryRaw as jest.Mock).mockResolvedValue([{ total: '0' }]);
  (prisma.customer.aggregate as jest.Mock).mockResolvedValue({ _sum: { debt: null } });
  (prisma.supplier.aggregate as jest.Mock).mockResolvedValue({ _sum: { debt: null } });

  const result = await service.calculate('store-1');
  expect(num(result.breakdown.cashOnHand)).toBe(1500);
  expect(num(result.totalAssets)).toBe(1500);
});

it('excludes cashOnHand when includeCash is false', async () => {
  const settings = {
    storeId: 'store-1', nisabAmount: new Decimal('100'),
    nisabGold: new Decimal(85), nisabSilver: new Decimal(595),
    nisabCurrency: 'TJS', haulStartDate: null,
    zakatRate: new Decimal('2.5'), cashOnHand: new Decimal('1500'),
    includeStock: true, includeCash: false, includeDebts: true,
  };
  (prisma.zakatSettings.findUnique as jest.Mock).mockResolvedValue(settings);
  (prisma.product.aggregate as jest.Mock).mockResolvedValue({ _sum: { quantity: 0 } });
  (prisma.$queryRaw as jest.Mock).mockResolvedValue([{ total: '0' }]);
  (prisma.customer.aggregate as jest.Mock).mockResolvedValue({ _sum: { debt: null } });
  (prisma.supplier.aggregate as jest.Mock).mockResolvedValue({ _sum: { debt: null } });

  const result = await service.calculate('store-1');
  expect(num(result.breakdown.cashOnHand)).toBe(0);
});
```

(Use the `num()` helper if present in the spec; otherwise inline `Number(v?.toString() ?? '0')`.)

- [ ] **Step 4: Run tests**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api
npm test -- zakat 2>&1 | tail -10
```
Expected: existing tests + 2 new = pass.

- [ ] **Step 5: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git add api/src/modules/zakat/
git commit -m "feat(zakat): cashOnHand included in totalAssets when includeCash=true

Spec E A.2 backend slice: settings.cashOnHand is now actually
used (was hardcoded to 0). Gated by existing includeCash flag.
2 new unit tests cover both branches."
```

---

## Task A.1+A.3: Calculator UI fixes (zakatRate dynamic + currency)

**Files:**
- Modify: `app/lib/presentation/pages/zakat/zakat_calculator_page.dart`

- [ ] **Step 1: Read current page + locate the 2 hardcoded "2.5%" + `_formatPrice`**

```bash
grep -n "2.5%\|_formatPrice\|TJS" /Users/latifrjdev/Downloads/01_Проекты/Dukon/app/lib/presentation/pages/zakat/zakat_calculator_page.dart | head -10
```

- [ ] **Step 2: Fix the 2 hardcoded `2.5%` strings**

Find:
```dart
'Закят — 2.5% от имущества, хранящегося 1 лунный год'
```
Replace with (inside a context where `calc` is in scope):
```dart
'Закят — ${calc.zakatRate.toStringAsFixed(1)}% от имущества, хранящегося 1 лунный год'
```

Find:
```dart
'СУММА ЗАКЯТА (2.5%):'
```
Replace with:
```dart
'СУММА ЗАКЯТА (${calc.zakatRate.toStringAsFixed(1)}%):'
```

If `calc.zakatRate` is missing from the `Calculation` entity, add it. Check via:
```bash
grep -n "zakatRate" /Users/latifrjdev/Downloads/01_Проекты/Dukon/app/lib/domain/entities/zakat_calculation.dart 2>/dev/null
```

If not present, add `final double zakatRate;` to entity + map from `data['zakatRate']` in remote datasource.

- [ ] **Step 3: Make `_formatPrice` accept currency**

Find:
```dart
String _formatPrice(double v) {
  final formatter = NumberFormat('#,##0', 'ru');
  return '${formatter.format(v)} TJS';
}
```

Replace with:
```dart
String _formatPrice(double v, String currency) {
  final formatter = NumberFormat('#,##0', 'ru');
  return '${formatter.format(v)} $currency';
}
```

Update every call site in the file. Get `currency` from `StoreBloc`:
```dart
final storeState = context.watch<StoreBloc>().state;
final currency = (storeState is StoreLoaded && storeState.selectedStore != null)
    ? storeState.selectedStore!.currency
    : 'TJS';
```
(Place `currency` derivation inside the `build` method near where `calc` is destructured.)

Then change every `_formatPrice(value)` call to `_formatPrice(value, currency)`.

If `Store.currency` is typed `String` already (likely), the `.currency` access works. If it's an enum, call `.name`.

- [ ] **Step 4: Verify**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/app
dart analyze lib/presentation/pages/zakat/zakat_calculator_page.dart 2>&1 | tail -3
flutter test --reporter=compact 2>&1 | tail -3
```
Expected: 0 issues; ≥435 tests pass.

- [ ] **Step 5: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git add app/lib/presentation/pages/zakat/zakat_calculator_page.dart \
        app/lib/domain/entities/zakat_calculation.dart \
        app/lib/data/datasources/remote/zakat_remote_datasource.dart 2>/dev/null
# stage only what's actually modified — `git add -A` on this dir is fine
git status --short
git commit -m "fix(zakat-calculator): dynamic zakatRate% + currency from store

Spec E A.1+A.3: replaces 2 hardcoded '2.5%' UI strings with
\${calc.zakatRate.toStringAsFixed(1)}%. _formatPrice now takes a
currency arg derived from StoreBloc.state.selectedStore.currency
so USD/RUB stores display the right suffix."
```

---

## Task C.1+C.2+C.3+A.2-UI: Settings page (validators + currency + clock + cashOnHand input)

**Files:**
- Modify: `app/lib/presentation/pages/zakat/zakat_settings_page.dart`

- [ ] **Step 1: Read current page**

```bash
cat /Users/latifrjdev/Downloads/01_Проекты/Dukon/app/lib/presentation/pages/zakat/zakat_settings_page.dart | head -80
```

Identify:
- The nisab `TextFormField` (no validator)
- All hardcoded `'TJS'` strings
- `_pickDate` method using `DateTime.now()`
- The save button submission flow

- [ ] **Step 2: Add `now` constructor param + `_now()` helper**

Apply the established pattern (used in CurrentShiftCard, ShiftCard, CreditSalePage, AddExpensePage, AddInvestmentPage).

Find:
```dart
class ZakatSettingsPage extends StatefulWidget {
  const ZakatSettingsPage({super.key});
```

Replace with:
```dart
class ZakatSettingsPage extends StatefulWidget {
  /// Optional clock for deterministic golden tests. Defaults to [DateTime.now].
  final DateTime Function()? now;
  const ZakatSettingsPage({super.key, this.now});
```

Inside `_ZakatSettingsPageState`, add helper:
```dart
DateTime _now() => (widget.now ?? DateTime.now)();
```

In `_pickDate`, replace `initialDate: DateTime.now()` with `initialDate: _now()`.

- [ ] **Step 3: Add validator to nisab field**

Find the `TextFormField` for `nisabAmount`. Add the `validator` parameter:
```dart
TextFormField(
  controller: _nisabController,
  keyboardType: TextInputType.number,
  validator: (v) {
    if (v == null || v.isEmpty) return 'Обязательное поле';
    final parsed = double.tryParse(v);
    if (parsed == null) return 'Введите число';
    if (parsed < 0) return 'Не может быть отрицательным';
    return null;
  },
  decoration: InputDecoration(...
)
```

(Preserve existing decoration — only add the `validator:` line.)

- [ ] **Step 4: Add cashOnHand input field**

After the nisab field block, add a new `TextFormField` for `cashOnHand`:
```dart
const SizedBox(height: 16),
TextFormField(
  controller: _cashOnHandController,
  keyboardType: TextInputType.number,
  validator: (v) {
    if (v == null || v.isEmpty) return null; // Optional
    final parsed = double.tryParse(v);
    if (parsed == null) return 'Введите число';
    if (parsed < 0) return 'Не может быть отрицательным';
    return null;
  },
  decoration: InputDecoration(
    labelText: 'Наличные в кассе',
    helperText: 'Учитывается в активах при расчёте закята',
    suffixText: currency,
  ),
),
```

Add the controller field at the top of `_ZakatSettingsPageState`:
```dart
final _cashOnHandController = TextEditingController();
```

In `initState`, populate from settings:
```dart
_cashOnHandController.text = (settings.cashOnHand ?? 0).toString();
```

In `dispose`, dispose the controller:
```dart
_cashOnHandController.dispose();
```

In the save handler, include `cashOnHand`:
```dart
final payload = {
  ...existing fields...
  'cashOnHand': double.tryParse(_cashOnHandController.text) ?? 0,
};
```

(Adapt to actual save handler shape — read it first.)

- [ ] **Step 5: Replace hardcoded TJS suffixes with currency from store**

In `build`, derive currency once:
```dart
final storeState = context.watch<StoreBloc>().state;
final currency = (storeState is StoreLoaded && storeState.selectedStore != null)
    ? storeState.selectedStore!.currency
    : 'TJS';
```

Find every `suffixText: 'TJS'` and replace with `suffixText: currency`.
Find every literal `'TJS'` in helper text and replace with `currency`.

- [ ] **Step 6: Verify build + tests**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/app
dart analyze lib/presentation/pages/zakat/zakat_settings_page.dart 2>&1 | tail -3
flutter test --reporter=compact 2>&1 | tail -3
```
Expected: 0 issues; ≥435 pass.

- [ ] **Step 7: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git add app/lib/presentation/pages/zakat/zakat_settings_page.dart
git commit -m "fix(zakat-settings): validators + currency from store + clock injection + cashOnHand input

Spec E C.1+C.2+C.3+A.2-UI: nisab field gets a validator (required
+ numeric + non-negative). suffixText for TJS pulled from
StoreBloc.state.selectedStore.currency. _pickDate accepts an
injectable now callback (5th time using this pattern). New
cashOnHand TextFormField wires the backend slice from A.2."
```

---

## Task B.1+B.2+B.3: zakat_history pagination + RefreshIndicator + sort assertion

**Files:**
- Modify: `app/lib/presentation/blocs/zakat/zakat_event.dart`
- Modify: `app/lib/presentation/blocs/zakat/zakat_state.dart`
- Modify: `app/lib/presentation/blocs/zakat/zakat_bloc.dart`
- Modify: `app/lib/presentation/pages/zakat/zakat_history_page.dart`
- Modify: `api/src/modules/zakat/zakat.service.spec.ts` (sort assertion)

- [ ] **Step 1: Verify backend endpoint accepts `page/limit`**

```bash
grep -B 2 -A 10 "@Get('payments')" /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/src/modules/zakat/zakat.controller.ts
echo "---service==="
grep -B 1 -A 15 "getPayments" /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/src/modules/zakat/zakat.service.ts | head -25
```

If the endpoint doesn't accept `page/limit`, add them. The service likely needs:
```typescript
async getPayments(storeId: string, page = 1, limit = 20) {
  const skip = (page - 1) * limit;
  const [data, total] = await this.prisma.$transaction([
    this.prisma.zakatPayment.findMany({
      where: { storeId },
      orderBy: { paidAt: 'desc' },
      skip,
      take: limit,
    }),
    this.prisma.zakatPayment.count({ where: { storeId } }),
  ]);
  return { data, total, totalPages: Math.ceil(total / limit), currentPage: page };
}
```

Controller:
```typescript
@Get('payments')
getPayments(
  @Param('storeId') storeId: string,
  @Query('page') page?: string,
  @Query('limit') limit?: string,
) {
  return this.zakatService.getPayments(
    storeId,
    page ? Math.max(1, parseInt(page, 10)) : 1,
    limit ? Math.min(100, Math.max(1, parseInt(limit, 10))) : 20,
  );
}
```

- [ ] **Step 2: Add B.3 sort assertion test**

Add inside the `describe('getPayments', ...)` block in `zakat.service.spec.ts`:

```typescript
it('returns payments sorted by paidAt desc', async () => {
  const findManySpy = (prisma.zakatPayment.findMany as jest.Mock).mockResolvedValue([]);
  (prisma.zakatPayment.count as jest.Mock).mockResolvedValue(0);
  await service.getPayments('store-1');
  expect(findManySpy.mock.calls[0][0].orderBy).toEqual({ paidAt: 'desc' });
});
```

- [ ] **Step 3: Add pagination fields to event/state/bloc**

`zakat_event.dart` — `ZakatPaymentsRequested`:
```dart
class ZakatPaymentsRequested extends ZakatEvent {
  final String storeId;
  final int page;
  final int limit;
  const ZakatPaymentsRequested({required this.storeId, this.page = 1, this.limit = 20});
  @override
  List<Object?> get props => [storeId, page, limit];
}
```

`zakat_state.dart` — extend `ZakatPaymentsLoaded` (or current state name) with pagination:
```dart
class ZakatPaymentsLoaded extends ZakatState {
  final List<ZakatPayment> payments;
  final int total;
  final int totalPages;
  final int currentPage;
  const ZakatPaymentsLoaded({
    required this.payments,
    required this.total,
    required this.totalPages,
    this.currentPage = 1,
  });
  bool get hasMore => currentPage < totalPages;
  @override
  List<Object?> get props => [payments, total, totalPages, currentPage];
}
```

`zakat_bloc.dart` — pass page/limit to remote:
```dart
on<ZakatPaymentsRequested>((event, emit) async {
  emit(ZakatLoading());
  try {
    final result = await _remote.getPayments(
      event.storeId,
      page: event.page,
      limit: event.limit,
    );
    emit(ZakatPaymentsLoaded(
      payments: result.data,
      total: result.total,
      totalPages: result.totalPages,
      currentPage: event.page,
    ));
  } catch (e) {
    emit(ZakatError(mapErrorToUserMessage(e)));
  }
});
```

(Adapt to actual remote datasource signature — read it first.)

- [ ] **Step 4: Wrap history list in RefreshIndicator + add load-more**

In `zakat_history_page.dart`, find the `ListView` (or `ListView.builder`) and wrap:
```dart
RefreshIndicator(
  onRefresh: () async {
    context.read<ZakatBloc>().add(ZakatPaymentsRequested(storeId: widget.storeId, page: 1));
    // Wait until next emission — simple approach: small delay
    await Future.delayed(const Duration(milliseconds: 300));
  },
  child: ListView(...),
)
```

After the list, add load-more button:
```dart
if (state is ZakatPaymentsLoaded && state.hasMore)
  Padding(
    padding: const EdgeInsets.all(16),
    child: ElevatedButton(
      onPressed: () => context.read<ZakatBloc>().add(
        ZakatPaymentsRequested(storeId: widget.storeId, page: state.currentPage + 1),
      ),
      child: const Text('Загрузить ещё'),
    ),
  ),
```

(Adapt — if list is `ListView.builder` with `itemCount`, append load-more as the last item via conditional `itemCount + 1`.)

- [ ] **Step 5: Verify**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/app
dart analyze lib/ 2>&1 | tail -3
flutter test --reporter=compact 2>&1 | tail -3
echo "---API==="
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api
npm test -- zakat 2>&1 | grep "Tests:" | tail
```
Expected: 0 issues; ≥435 flutter pass; zakat unit tests +1 (sort assertion).

- [ ] **Step 6: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git add app/lib/presentation/blocs/zakat/ \
        app/lib/presentation/pages/zakat/zakat_history_page.dart \
        api/src/modules/zakat/zakat.controller.ts \
        api/src/modules/zakat/zakat.service.ts \
        api/src/modules/zakat/zakat.service.spec.ts
git commit -m "feat(zakat-history): pagination + RefreshIndicator + sort assertion

Spec E B.1+B.2+B.3: GET /zakat/payments accepts ?page=&limit=,
returns total + totalPages. Bloc state carries hasMore. UI wraps
list in RefreshIndicator + appends 'Загрузить ещё' button.
Service test asserts orderBy: { paidAt: desc }."
```

---

## Task D.1+D.2: investment_bloc UX fixes

**Files:**
- Modify: `app/lib/presentation/blocs/investment/investment_state.dart`
- Modify: `app/lib/presentation/blocs/investment/investment_bloc.dart`
- Modify: `app/lib/presentation/pages/finance/investment_list_page.dart`

- [ ] **Step 1: Add `isRefreshing` to InvestmentLoaded**

Edit `investment_state.dart`. Find `InvestmentLoaded`:
```dart
class InvestmentLoaded extends InvestmentState {
  final List<Investment> investments;
  final int total;
  final int totalPages;
  final int currentPage;
  final String? selectedStatus;
  const InvestmentLoaded({
    required this.investments,
    required this.total,
    required this.totalPages,
    this.currentPage = 1,
    this.selectedStatus,
  });
  ...
}
```

Add `isRefreshing` field with default false + copyWith:
```dart
class InvestmentLoaded extends InvestmentState {
  final List<Investment> investments;
  final int total;
  final int totalPages;
  final int currentPage;
  final String? selectedStatus;
  final bool isRefreshing;
  const InvestmentLoaded({
    required this.investments,
    required this.total,
    required this.totalPages,
    this.currentPage = 1,
    this.selectedStatus,
    this.isRefreshing = false,
  });

  InvestmentLoaded copyWith({
    List<Investment>? investments,
    int? total,
    int? totalPages,
    int? currentPage,
    String? selectedStatus,
    bool? isRefreshing,
  }) {
    return InvestmentLoaded(
      investments: investments ?? this.investments,
      total: total ?? this.total,
      totalPages: totalPages ?? this.totalPages,
      currentPage: currentPage ?? this.currentPage,
      selectedStatus: selectedStatus ?? this.selectedStatus,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }

  @override
  List<Object?> get props => [investments, total, totalPages, currentPage, selectedStatus, isRefreshing];
}
```

- [ ] **Step 2: Update `_onListRequested` to use isRefreshing on subsequent fetches**

In `investment_bloc.dart`, replace the start of `_onListRequested`:
```dart
Future<void> _onListRequested(InvestmentListRequested event, Emitter<InvestmentState> emit) async {
  // Spec E D.1: avoid Loading flicker on filter switch by reusing
  // the previous list with isRefreshing=true.
  if (state is InvestmentLoaded) {
    emit((state as InvestmentLoaded).copyWith(isRefreshing: true));
  } else {
    emit(InvestmentLoading());
  }
  try {
    final result = await _investmentRepository.getInvestments(
      event.storeId, page: event.page, status: event.status,
    );
    emit(InvestmentLoaded(
      investments: result.data,
      total: result.total,
      totalPages: result.totalPages,
      currentPage: event.page,
      selectedStatus: event.status,
      isRefreshing: false,
    ));
  } catch (e) {
    emit(InvestmentError(mapErrorToUserMessage(e)));
  }
}
```

- [ ] **Step 3: D.2 — `Future.microtask` between Success + chained reload**

In each of the 3 mutation handlers (`_onCreateRequested`, `_onUpdateRequested`, `_onDeleteRequested`), find the pattern:
```dart
emit(const InvestmentActionSuccess('...'));
add(InvestmentListRequested(storeId: event.storeId));
```

Replace with:
```dart
emit(const InvestmentActionSuccess(...));
// Spec E D.2: yield to event loop so BlocBuilder consumers see
// the success state before it's overwritten by the chained reload.
await Future<void>.delayed(Duration.zero);
add(InvestmentListRequested(storeId: event.storeId));
```

(D.4 will replace the literal strings in the next task.)

- [ ] **Step 4: UI consume isRefreshing**

Edit `investment_list_page.dart`. Find the `BlocBuilder<InvestmentBloc, InvestmentState>`. The current branch likely renders `Loading` for `InvestmentLoading` and the list for `InvestmentLoaded`. Add a small spinner overlay when `isRefreshing`:

```dart
if (state is InvestmentLoaded) {
  return Stack(
    children: [
      _buildList(state.investments),  // existing list builder
      if (state.isRefreshing)
        const Positioned(
          top: 8,
          right: 8,
          child: SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
    ],
  );
}
```

(Adapt to actual page structure — keep existing scaffold/AppBar.)

- [ ] **Step 5: Verify**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/app
dart analyze lib/ 2>&1 | tail -3
flutter test --reporter=compact 2>&1 | tail -3
```
Expected: 0 issues; existing tests pass.

- [ ] **Step 6: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git add app/lib/presentation/blocs/investment/ app/lib/presentation/pages/finance/investment_list_page.dart
git commit -m "fix(investment-bloc): no flicker on filter + ActionSuccess survives reload

Spec E D.1+D.2:
- InvestmentLoaded gains isRefreshing flag; bloc reuses previous
  state on subsequent fetches instead of emitting Loading
- Future.delayed(Duration.zero) between ActionSuccess and chained
  list-reload so BlocBuilder consumers see the Success state."
```

---

## Task D.3: investment_bloc_test.dart

**Files:**
- Create: `app/test/presentation/blocs/investment/investment_bloc_test.dart`

- [ ] **Step 1: Inspect bloc constructor + repo interface**

```bash
sed -n '1,40p' /Users/latifrjdev/Downloads/01_Проекты/Dukon/app/lib/presentation/blocs/investment/investment_bloc.dart
echo "---"
cat /Users/latifrjdev/Downloads/01_Проекты/Dukon/app/lib/domain/repositories/investment_repository.dart 2>/dev/null
```

Note exact constructor + repo method signatures.

- [ ] **Step 2: Write 6 tests**

Create `app/test/presentation/blocs/investment/investment_bloc_test.dart`:

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dukonpro/domain/entities/investment.dart';
import 'package:dukonpro/domain/repositories/investment_repository.dart';
import 'package:dukonpro/presentation/blocs/investment/investment_bloc.dart';
import 'package:dukonpro/presentation/blocs/investment/investment_event.dart';
import 'package:dukonpro/presentation/blocs/investment/investment_state.dart';

class _MockRepo extends Mock implements InvestmentRepository {}

void main() {
  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
  });

  Investment _inv(String id) => Investment(
    id: id,
    storeId: 's1',
    name: 'Test $id',
    amount: 100,
    investorName: 'A',
    status: 'ACTIVE',
    startDate: DateTime(2026, 1, 1),
  );

  blocTest<InvestmentBloc, InvestmentState>(
    'list happy: emits Loading then Loaded',
    build: () {
      when(() => repo.getInvestments(any(), page: any(named: 'page'), status: any(named: 'status')))
        .thenAnswer((_) async => (data: [_inv('1')], total: 1, totalPages: 1));
      return InvestmentBloc(investmentRepository: repo);
    },
    act: (b) => b.add(InvestmentListRequested(storeId: 's1')),
    expect: () => [isA<InvestmentLoading>(), isA<InvestmentLoaded>()],
  );

  blocTest<InvestmentBloc, InvestmentState>(
    'list refresh: prev Loaded → Loaded(isRefreshing:true) → Loaded(isRefreshing:false)',
    build: () {
      when(() => repo.getInvestments(any(), page: any(named: 'page'), status: any(named: 'status')))
        .thenAnswer((_) async => (data: [_inv('1')], total: 1, totalPages: 1));
      return InvestmentBloc(investmentRepository: repo);
    },
    seed: () => const InvestmentLoaded(investments: [], total: 0, totalPages: 1),
    act: (b) => b.add(InvestmentListRequested(storeId: 's1')),
    expect: () => [
      predicate<InvestmentLoaded>((s) => s.isRefreshing == true),
      predicate<InvestmentLoaded>((s) => s.isRefreshing == false),
    ],
  );

  blocTest<InvestmentBloc, InvestmentState>(
    'list failure: emits Loading then Error',
    build: () {
      when(() => repo.getInvestments(any(), page: any(named: 'page'), status: any(named: 'status')))
        .thenThrow(Exception('boom'));
      return InvestmentBloc(investmentRepository: repo);
    },
    act: (b) => b.add(InvestmentListRequested(storeId: 's1')),
    expect: () => [isA<InvestmentLoading>(), isA<InvestmentError>()],
  );

  blocTest<InvestmentBloc, InvestmentState>(
    'create: emits ActionSuccess and chained reload',
    build: () {
      when(() => repo.createInvestment(any(), any())).thenAnswer((_) async {});
      when(() => repo.getInvestments(any(), page: any(named: 'page'), status: any(named: 'status')))
        .thenAnswer((_) async => (data: <Investment>[], total: 0, totalPages: 1));
      return InvestmentBloc(investmentRepository: repo);
    },
    act: (b) => b.add(InvestmentCreateRequested(storeId: 's1', data: const {'name': 'X', 'amount': 100})),
    expect: () => [
      isA<InvestmentLoading>(),
      isA<InvestmentActionSuccess>(),
      isA<InvestmentLoading>(),  // from chained reload
      isA<InvestmentLoaded>(),
    ],
  );

  blocTest<InvestmentBloc, InvestmentState>(
    'delete failure: emits Loading then Error',
    build: () {
      when(() => repo.deleteInvestment(any(), any())).thenThrow(Exception('boom'));
      return InvestmentBloc(investmentRepository: repo);
    },
    act: (b) => b.add(InvestmentDeleteRequested(storeId: 's1', id: 'i1')),
    expect: () => [isA<InvestmentLoading>(), isA<InvestmentError>()],
  );

  blocTest<InvestmentBloc, InvestmentState>(
    'filter switch: passes selectedStatus to repo',
    build: () {
      when(() => repo.getInvestments(any(), page: any(named: 'page'), status: any(named: 'status')))
        .thenAnswer((_) async => (data: <Investment>[], total: 0, totalPages: 1));
      return InvestmentBloc(investmentRepository: repo);
    },
    act: (b) => b.add(InvestmentListRequested(storeId: 's1', status: 'COMPLETED')),
    verify: (_) {
      verify(() => repo.getInvestments('s1', page: any(named: 'page'), status: 'COMPLETED')).called(1);
    },
  );
}
```

**ADAPT** to actual repo signatures:
- `getInvestments` may return a different shape (e.g. typed wrapper class instead of record) — match exactly
- Method names like `createInvestment`, `deleteInvestment` may differ
- `Investment` entity constructor params

If the bloc requires multiple deps in the constructor (e.g. `mapErrorToUserMessage` is injected), construct accordingly.

- [ ] **Step 3: Run + verify**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/app
flutter test test/presentation/blocs/investment/investment_bloc_test.dart --reporter=compact 2>&1 | tail -5
```
Expected: 6 passed.

- [ ] **Step 4: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git add app/test/presentation/blocs/investment/investment_bloc_test.dart
git commit -m "test(investment-bloc): 6 tests covering list/create/filter/error paths"
```

---

## Task D.4: l10n keys for investment-bloc strings

**Files:**
- Create: `app/lib/presentation/blocs/investment/investment_l10n_key.dart`
- Modify: `app/lib/presentation/blocs/investment/investment_bloc.dart`
- Modify: `app/lib/presentation/pages/finance/investment_list_page.dart`
- Modify: `app/lib/l10n/app_ru.arb`, `app_tg.arb`, `app_uz.arb`
- Auto-regen: `app/lib/l10n/app_localizations*.dart`

- [ ] **Step 1: Add 3 keys to all 3 ARB files**

Edit `app/lib/l10n/app_ru.arb`. Add:
```json
  "investmentCreated": "Вложение добавлено",
  "investmentUpdated": "Вложение обновлено",
  "investmentDeleted": "Вложение удалено",
```

Same shape for `app_tg.arb`:
```json
  "investmentCreated": "Маблағгузорӣ илова шуд",
  "investmentUpdated": "Маблағгузорӣ нав карда шуд",
  "investmentDeleted": "Маблағгузорӣ нест карда шуд",
```

For `app_uz.arb`:
```json
  "investmentCreated": "Investitsiya qoʻshildi",
  "investmentUpdated": "Investitsiya yangilandi",
  "investmentDeleted": "Investitsiya oʻchirildi",
```

(Match existing JSON key style — likely each key has a sibling `@key` metadata; keep consistent.)

- [ ] **Step 2: Regenerate AppLocalizations**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/app
flutter gen-l10n 2>&1 | tail -3
```
Expected: success message. Check `git status` — if `app_localizations*.dart` files are NOT in `.gitignore`, they'll show as modified.

- [ ] **Step 3: Create the key enum**

Create `app/lib/presentation/blocs/investment/investment_l10n_key.dart`:

```dart
// app/lib/presentation/blocs/investment/investment_l10n_key.dart
//
// Spec E D.4: bloc emits these keys instead of raw localized
// strings. Page resolves via AppLocalizations.of(context).
enum InvestmentL10nKey {
  created,
  updated,
  deleted,
}
```

- [ ] **Step 4: Bloc emits keys, not strings**

Edit `investment_bloc.dart`. Find:
```dart
emit(const InvestmentActionSuccess('Вложение добавлено'));
emit(const InvestmentActionSuccess('Вложение обновлено'));
emit(const InvestmentActionSuccess('Вложение удалено'));
```

If `InvestmentActionSuccess` currently takes a `String message`, change it to take `InvestmentL10nKey key`:

`investment_state.dart`:
```dart
class InvestmentActionSuccess extends InvestmentState {
  final InvestmentL10nKey key;
  const InvestmentActionSuccess(this.key);
  @override
  List<Object?> get props => [key];
}
```

`investment_bloc.dart`:
```dart
import 'investment_l10n_key.dart';

// In each handler:
emit(const InvestmentActionSuccess(InvestmentL10nKey.created));
emit(const InvestmentActionSuccess(InvestmentL10nKey.updated));
emit(const InvestmentActionSuccess(InvestmentL10nKey.deleted));
```

- [ ] **Step 5: Page resolves key → localized string**

In `investment_list_page.dart` (and any other page consuming
`InvestmentActionSuccess`), find the `BlocListener` snackbar
trigger:
```dart
} else if (state is InvestmentActionSuccess) {
  final l10n = AppLocalizations.of(context)!;
  final message = switch (state.key) {
    InvestmentL10nKey.created => l10n.investmentCreated,
    InvestmentL10nKey.updated => l10n.investmentUpdated,
    InvestmentL10nKey.deleted => l10n.investmentDeleted,
  };
  AppSnackbar.success(context, message);
}
```

(Adapt to actual l10n usage pattern — if `AppLocalizations` isn't imported, add it.)

- [ ] **Step 6: Update the bloc test from D.3 if needed**

The test for `create` uses `isA<InvestmentActionSuccess>()` — that still passes regardless of the inner type. No change needed unless the test asserts the message content (it doesn't in our D.3 spec).

- [ ] **Step 7: Verify**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/app
dart analyze lib/ 2>&1 | tail -3
flutter test --reporter=compact 2>&1 | tail -3
```
Expected: 0 issues; tests pass.

- [ ] **Step 8: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git add app/lib/l10n/ app/lib/presentation/blocs/investment/ app/lib/presentation/pages/finance/investment_list_page.dart
git commit -m "fix(investment): l10n keys for success messages

Spec E D.4: bloc emits InvestmentL10nKey enum (created/updated/
deleted) instead of hardcoded Russian strings. Page resolves via
AppLocalizations. Adds 3 keys to ru/tg/uz ARB files."
```

---

## Task F.1: Final verification gate

**Files:**
- None (verification only)

- [ ] **Step 1: Full test gate**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api
npx tsc --noEmit 2>&1 | grep -v "\.spec\." | grep "error TS" | head
npm test 2>&1 | grep "Tests:" | tail
npm run test:e2e 2>&1 | grep "Tests:" | tail

cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/app
dart analyze lib/ 2>&1 | tail -3
flutter test --reporter=compact 2>&1 | tail -3
```
Expected:
- 0 tsc errors
- ≥225 unit (was 222, +3 zakat tests: cashOnHand × 2 + sort)
- ≥11 e2e
- 0 dart analyze issues
- ≥441 flutter pass (was 435, +6 investment_bloc_test)

- [ ] **Step 2: Live verification probes**

```bash
lsof -i:4455 -t | xargs kill -9 2>/dev/null
sleep 2
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api && nohup npm run start:dev > /tmp/dukon-api.log 2>&1 & disown
until curl -sf -m 2 http://localhost:4455/api/health >/dev/null 2>&1; do sleep 2; done

T_BIZ=$(curl -sf -X POST http://localhost:4455/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"phone":"+992910001002","password":"qatest1234"}' | \
  python3 -c 'import sys,json;print(json.load(sys.stdin).get("accessToken",""))')
SID="d169d2e8-0a24-4a23-844a-5d5e7b690d8c"

# 1. Set zakat settings with cashOnHand + custom rate
curl -sf -X POST "http://localhost:4455/api/stores/$SID/zakat/settings" \
  -H "Authorization: Bearer $T_BIZ" -H 'Content-Type: application/json' \
  -d '{"nisabAmount":1000,"zakatRate":3.5,"cashOnHand":2000,"includeCash":true}' \
  -w "\nHTTP=%{http_code}\n" | tail -3

# 2. Calculate — totalAssets should include cashOnHand
echo "=== zakat calculate ==="
curl -sf "http://localhost:4455/api/stores/$SID/zakat/calculate" \
  -H "Authorization: Bearer $T_BIZ" | python3 -m json.tool 2>&1 | grep -E "totalAssets|cashOnHand|zakatRate" | head -5

# 3. Pagination on history
echo "=== zakat payments page=1 limit=5 ==="
curl -sf "http://localhost:4455/api/stores/$SID/zakat/payments?page=1&limit=5" \
  -H "Authorization: Bearer $T_BIZ" -w "\nHTTP=%{http_code}\n" | python3 -m json.tool 2>&1 | head -15
```
Expected:
- POST settings → HTTP 200/201
- calculate response contains `cashOnHand: 2000`, `zakatRate: 3.5`, `totalAssets >= 2000`
- payments response is `{ data: [], total: N, totalPages: M, currentPage: 1 }` shape

- [ ] **Step 3: Final summary commit (only if anything uncommitted)**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git status --short
git log --oneline 7f6a6e6..HEAD | head -20
```

If clean, just print the commit list.

---

## Self-Review

**Spec coverage:**
- ✅ Sub-section A (zakat_calculator + cashOnHand backend) — Tasks A.2.1 (schema/migration), A.2.2 (DTO/service), A.1+A.3 (calculator UI)
- ✅ Sub-section B (zakat_history) — Task B.1+B.2+B.3
- ✅ Sub-section C (zakat_settings) — Task C.1+C.2+C.3+A.2-UI (cash-on-hand input lives here)
- ✅ Sub-section D (investment_bloc) — Tasks D.1+D.2 (bloc UX), D.3 (tests), D.4 (l10n)
- ✅ Sub-section E (dead code) — Task E.1
- ✅ Final verification — Task F.1 (5 acceptance criteria covered in step 2)

**Type / name consistency:**
- `cashOnHand`: schema (A.2.1) → DTO (A.2.2) → service (A.2.2) → settings UI (C task) → calculator reads via `calc.breakdown.cashOnHand` (A.1+A.3) ✓
- `currency` derived from `StoreLoaded.selectedStore!.currency` — same access pattern in calculator (A.1+A.3) and settings (C) ✓
- `_now()` helper + `widget.now` — same as previous 5 implementations ✓
- `isRefreshing` field on `InvestmentLoaded` — defined D.1, consumed D.1 page edit + asserted D.3 test ✓
- `InvestmentL10nKey` enum (D.4) → emitted in bloc (D.4) → resolved in page (D.4) ✓

**Placeholders:** none — all steps have concrete code or shell.

Plan complete and saved to `docs/superpowers/plans/2026-05-16-spec-e-flutter-ux-cleanup.md`.
