# Flutter Screens Redesign — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Apply the new Vibrant Gradient design system (GradientHeader, GlassCard, AppChip, AppShadows, gradient accents) to all key Flutter screens. Wire the settings dark mode toggle to BLoC.

**Architecture:** Screen-by-screen updates using existing design system components. Each task updates one screen or group of related screens. No new components — only integration of components from Design System Core.

**Tech Stack:** Flutter, Material 3, flutter_bloc, GlassCard, GradientHeader, AppChip, AppShadows

**Spec:** `docs/superpowers/specs/2026-04-09-dokonpro-redesign.md`

---

## File Structure

All modifications — no new files needed.

| File | Change |
|------|--------|
| `pages/settings/settings_page.dart` | Wire dark toggle to BLoC |
| `pages/dashboard/dashboard_page.dart` | GradientHeader + GlassCard + AppChip |
| `pages/dashboard/home_page.dart` | Minor — verify bottom nav integration |
| `pages/pos/pos_checkout_page.dart` | GlassCard search + AppButton + AppShadows |
| `pages/product/product_list_page.dart` | AppChip filters + AppShadows cards |
| `pages/sales/sales_history_page.dart` | AppChip period + consistent cards |
| `pages/finance/finance_dashboard_page.dart` | GlassCard KPIs + AppChip periods |
| `pages/auth/login_page.dart` | Gradient accent on logo/header area |
| `pages/debt/debts_overview_page.dart` | GlassCard + theme colors |
| `pages/zakat/zakat_calculator_page.dart` | GlassCard + theme colors |
| `pages/staff/staff_list_page.dart` | Theme-aware cards |
| `pages/shifts/shifts_page.dart` | Theme-aware cards |
| `pages/payroll/payroll_page.dart` | Theme-aware cards |

---

## Task 1: Settings — Wire Dark Mode Toggle to BLoC

**Files:**
- Modify: `app/lib/presentation/pages/settings/settings_page.dart`

- [ ] **Step 1: Read settings_page.dart and find the dark theme toggle**

The current toggle uses a local `_darkThemeEnabled` bool in a StatefulWidget. We need to replace it with `BlocBuilder<SettingsBloc, SettingsState>` reading `themeMode` from state and dispatching `SettingsThemeChanged` on toggle.

- [ ] **Step 2: Replace the dark theme toggle section**

Find the `SwitchListTile` or similar widget for dark theme. Replace with:

```dart
BlocBuilder<SettingsBloc, SettingsState>(
  builder: (context, state) {
    final isDark = state is SettingsLoaded &&
        state.themeMode == ThemeMode.dark;
    return _buildToggleTile(
      icon: Icons.dark_mode_outlined,
      title: 'Тёмная тема',
      value: isDark,
      onChanged: (value) {
        context.read<SettingsBloc>().add(
          SettingsThemeChanged(value ? ThemeMode.dark : ThemeMode.light),
        );
      },
    );
  },
),
```

Add imports at top:
```dart
import '../../blocs/settings/settings_event.dart';
import '../../blocs/settings/settings_state.dart';
```

- [ ] **Step 3: Remove the local `_darkThemeEnabled` state variable**

Delete the `bool _darkThemeEnabled = false;` field and any setState calls related to it.

- [ ] **Step 4: Update section cards to use GlassCard in dark mode**

For each `_buildSectionCard` or similar method, check if it uses hardcoded background colors. Replace manual Container backgrounds with theme-aware colors:

```dart
// Instead of hardcoded white
color: Theme.of(context).colorScheme.surface,
```

- [ ] **Step 5: Commit**

```bash
git add app/lib/presentation/pages/settings/settings_page.dart
git commit -m "feat(settings): wire dark mode toggle to SettingsBloc + theme-aware cards"
```

---

## Task 2: Dashboard — GradientHeader + GlassCard

**Files:**
- Modify: `app/lib/presentation/pages/dashboard/dashboard_page.dart`

- [ ] **Step 1: Read dashboard_page.dart fully**

Understand the current structure: header area, KPI cards, quick actions, recent sales, period filter.

- [ ] **Step 2: Add GradientHeader at top**

Replace the current header section (greeting text, store name, etc.) with:

```dart
import '../../widgets/common/gradient_header.dart';
import '../../widgets/common/glass_card.dart';
import '../../widgets/common/app_chip.dart';
```

At the top of the page body, use:

```dart
GradientHeader(
  greeting: 'Салом 👋',
  userName: userName, // from StoreBloc/AuthBloc state
  storeName: storeName, // from StoreBloc state
  onNotificationTap: () { /* navigate to notifications */ },
  onProfileTap: () { /* navigate to profile */ },
  onStoreTap: () { /* show store selector */ },
),
```

- [ ] **Step 3: Wrap KPI cards with overlapping layout**

After GradientHeader, use negative margin to overlap:

```dart
Transform.translate(
  offset: const Offset(0, -36),
  child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(
      children: [
        Expanded(child: StatCard(icon: Icons.payments, label: 'Сегодня', value: todayRevenue)),
        const SizedBox(width: 10),
        Expanded(child: StatCard(icon: Icons.receipt_long, label: 'Продажи', value: salesCount)),
      ],
    ),
  ),
),
```

- [ ] **Step 4: Replace period filter chips with AppChip**

Find the manual period filter implementation and replace with:

```dart
Row(
  children: [
    AppChip(label: 'Сегодня', isSelected: selectedPeriod == 0, onTap: () => _selectPeriod(0)),
    const SizedBox(width: 8),
    AppChip(label: 'Неделя', isSelected: selectedPeriod == 1, onTap: () => _selectPeriod(1)),
    const SizedBox(width: 8),
    AppChip(label: 'Месяц', isSelected: selectedPeriod == 2, onTap: () => _selectPeriod(2)),
  ],
),
```

- [ ] **Step 5: Replace quick action cards with GlassCard**

For each quick action item, wrap in GlassCard:

```dart
GlassCard(
  onTap: () => onTap(),
  padding: const EdgeInsets.all(14),
  child: Column(
    children: [
      Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          gradient: isMainAction ? AppGradients.primary : null,
          color: isMainAction ? null : AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: isMainAction ? Colors.white : AppColors.primary, size: 22),
      ),
      const SizedBox(height: 6),
      Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
    ],
  ),
),
```

- [ ] **Step 6: Replace recent sales items with GlassCard elevated**

For each sale list item, use:

```dart
GlassCard(
  elevated: true,
  padding: const EdgeInsets.all(10),
  child: Row(/* existing sale item content */),
),
```

- [ ] **Step 7: Commit**

```bash
git add app/lib/presentation/pages/dashboard/dashboard_page.dart
git commit -m "feat(dashboard): add GradientHeader, GlassCard, AppChip to dashboard"
```

---

## Task 3: POS Checkout — Modern Search + Gradient Actions

**Files:**
- Modify: `app/lib/presentation/pages/pos/pos_checkout_page.dart`

- [ ] **Step 1: Read pos_checkout_page.dart fully**

- [ ] **Step 2: Replace search section with AppSearchBar or GlassCard wrapper**

Wrap the product search TextField in a styled container:

```dart
GlassCard(
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
  radius: AppConstants.buttonRadius,
  child: TextField(/* existing search field, remove its own border/background */),
),
```

- [ ] **Step 3: Update cart summary card**

Replace manual Container with shadow to use AppCard or GlassCard:

```dart
GlassCard(
  padding: const EdgeInsets.all(16),
  child: Column(/* existing subtotal, discount, total rows */),
),
```

- [ ] **Step 4: Ensure "Proceed to Payment" button uses AppButton**

Check that the main action button uses `AppButton(type: AppButtonType.primary)` which now renders with gradient.

- [ ] **Step 5: Update payment method selector styling**

Replace manual Container buttons with gradient-outlined selection:

```dart
// For each payment method option
GestureDetector(
  onTap: () => selectMethod(method),
  child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      gradient: isSelected ? AppGradients.primary : null,
      color: isSelected ? null : Colors.transparent,
      border: isSelected ? null : Border.all(color: Theme.of(context).colorScheme.outline),
      borderRadius: BorderRadius.circular(AppConstants.buttonRadius),
    ),
    child: Text(
      method.label,
      style: TextStyle(
        color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
    ),
  ),
),
```

- [ ] **Step 6: Replace any remaining hardcoded hex colors**

Search for `Color(0x` patterns in the file and replace with AppColors tokens.

- [ ] **Step 7: Commit**

```bash
git add app/lib/presentation/pages/pos/pos_checkout_page.dart
git commit -m "feat(pos): modernize POS checkout with GlassCard search and gradient actions"
```

---

## Task 4: Product List — AppChip Filters + Shadows

**Files:**
- Modify: `app/lib/presentation/pages/product/product_list_page.dart`

- [ ] **Step 1: Read product_list_page.dart fully**

- [ ] **Step 2: Replace stock filter chips with AppChip**

Find the filter section (StockFilter enum: all, inStock, lowStock, outOfStock) and replace manual containers:

```dart
SingleChildScrollView(
  scrollDirection: Axis.horizontal,
  child: Row(
    children: _StockFilter.values.map((filter) {
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: AppChip(
          label: filter.label,
          isSelected: _selectedFilter == filter,
          onTap: () => setState(() => _selectedFilter = filter),
        ),
      );
    }).toList(),
  ),
),
```

- [ ] **Step 3: Replace product card shadows with AppShadows**

For each product card Container, replace manual `BoxShadow` with:

```dart
boxShadow: Theme.of(context).brightness == Brightness.light ? AppShadows.sm : null,
```

- [ ] **Step 4: Replace header with styled AppBar or gradient accent**

Add a gradient accent line at the top of the page, or use a simpler AppBar with gradient overlay.

- [ ] **Step 5: Ensure add product FAB uses gradient**

If there's a FloatingActionButton, style it:

```dart
FloatingActionButton(
  onPressed: _addProduct,
  child: Container(
    decoration: BoxDecoration(gradient: AppGradients.primary, shape: BoxShape.circle),
    child: const Icon(Icons.add, color: Colors.white),
  ),
),
```

- [ ] **Step 6: Commit**

```bash
git add app/lib/presentation/pages/product/product_list_page.dart
git commit -m "feat(products): add AppChip filters and gradient accents to product list"
```

---

## Task 5: Sales History — Period Chips + Consistent Cards

**Files:**
- Modify: `app/lib/presentation/pages/sales/sales_history_page.dart`

- [ ] **Step 1: Read sales_history_page.dart**

- [ ] **Step 2: Replace period filter chips with AppChip**

Same pattern as dashboard:

```dart
AppChip(label: 'Сегодня', isSelected: period == 'today', onTap: () => _setPeriod('today')),
```

- [ ] **Step 3: Update transaction cards to use AppShadows**

Replace manual BoxShadow with `AppShadows.sm` in light mode.

- [ ] **Step 4: Ensure status badges use correct theme colors**

Payment status badges should use:
- Paid/Cash: `AppColors.success` / `AppColors.successBg`
- Debt: `AppColors.warning` / `AppColors.warningBg`
- Refunded: `AppColors.error` / `AppColors.errorBg`

- [ ] **Step 5: Commit**

```bash
git add app/lib/presentation/pages/sales/sales_history_page.dart
git commit -m "feat(sales): add AppChip period filters and consistent card styling"
```

---

## Task 6: Finance Dashboard — GlassCard KPIs

**Files:**
- Modify: `app/lib/presentation/pages/finance/finance_dashboard_page.dart`

- [ ] **Step 1: Read finance_dashboard_page.dart**

- [ ] **Step 2: Replace KPI cards with GlassCard**

Wrap each KPI card (Total Income, Total Expenses, Profit, Debt) in GlassCard:

```dart
GlassCard(
  padding: const EdgeInsets.all(16),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const Spacer(),
          // trend badge
        ],
      ),
      const SizedBox(height: 12),
      Text(value, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
      Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
    ],
  ),
),
```

- [ ] **Step 3: Replace period chips with AppChip**

Same pattern as Tasks 2 and 5.

- [ ] **Step 4: Wrap chart in GlassCard**

```dart
GlassCard(
  padding: const EdgeInsets.all(16),
  child: SizedBox(height: 200, child: LineChart(/* existing chart config */)),
),
```

- [ ] **Step 5: Remove any hardcoded hex colors**

Search for `Color(0xFF` in the file and replace with AppColors tokens.

- [ ] **Step 6: Commit**

```bash
git add app/lib/presentation/pages/finance/finance_dashboard_page.dart
git commit -m "feat(finance): GlassCard KPIs, AppChip filters, modern chart wrapper"
```

---

## Task 7: Login — Gradient Accent

**Files:**
- Modify: `app/lib/presentation/pages/auth/login_page.dart`

- [ ] **Step 1: Read login_page.dart**

- [ ] **Step 2: Add gradient accent to the top section**

Add a gradient header/logo area above the form:

```dart
Container(
  width: double.infinity,
  padding: const EdgeInsets.symmetric(vertical: 48),
  decoration: const BoxDecoration(
    gradient: AppGradients.primary,
    borderRadius: BorderRadius.only(
      bottomLeft: Radius.circular(32),
      bottomRight: Radius.circular(32),
    ),
  ),
  child: Column(
    children: [
      Text('DokonPro', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      Text('Управление магазином', style: TextStyle(color: Color(0xB3FFFFFF), fontSize: 14)),
    ],
  ),
),
```

- [ ] **Step 3: Ensure form fields and button use new design**

Verify `AppTextField` and `AppButton` are used (they should already render with gradient styles from Design System Core).

- [ ] **Step 4: Commit**

```bash
git add app/lib/presentation/pages/auth/login_page.dart
git commit -m "feat(auth): add gradient header accent to login page"
```

---

## Task 8: Remaining Screens — Theme Consistency Pass

**Files:**
- Modify: `pages/debt/debts_overview_page.dart`
- Modify: `pages/debt/customer_debts_page.dart`
- Modify: `pages/debt/supplier_debts_page.dart`
- Modify: `pages/zakat/zakat_calculator_page.dart`
- Modify: `pages/zakat/zakat_settings_page.dart`
- Modify: `pages/zakat/zakat_history_page.dart`
- Modify: `pages/staff/staff_list_page.dart`
- Modify: `pages/staff/staff_detail_page.dart`
- Modify: `pages/staff/add_staff_page.dart`
- Modify: `pages/shifts/shifts_page.dart`
- Modify: `pages/shifts/open_shift_page.dart`
- Modify: `pages/shifts/z_report_page.dart`
- Modify: `pages/payroll/payroll_page.dart`
- Modify: `pages/payroll/add_adjustment_page.dart`
- Modify: `pages/customer/customer_list_page.dart`
- Modify: `pages/customer/customer_detail_page.dart`
- Modify: `pages/supplier/supplier_list_page.dart`
- Modify: `pages/supplier/supplier_detail_page.dart`
- Modify: `pages/stock/stock_intake_page.dart`
- Modify: `pages/store/create_store_page.dart`
- Modify: `pages/roles/roles_page.dart`
- Modify: `pages/product/product_detail_page.dart`
- Modify: `pages/product/add_product_step1_page.dart`
- Modify: `pages/product/add_product_step2_page.dart`
- Modify: `pages/product/add_product_step3_page.dart`
- Modify: `pages/product/categories_page.dart`
- Modify: `pages/product/import_products_page.dart`
- Modify: `pages/pos/cash_payment_page.dart`
- Modify: `pages/pos/credit_sale_page.dart`
- Modify: `pages/pos/sale_success_page.dart`
- Modify: `pages/pos/receipt_preview_page.dart`
- Modify: `pages/sales/transaction_detail_page.dart`
- Modify: `pages/sales/refund_page.dart`
- Modify: `pages/finance/expense_list_page.dart`
- Modify: `pages/finance/add_expense_page.dart`
- Modify: `pages/settings/edit_profile_page.dart`
- Modify: `pages/settings/change_password_page.dart`
- Modify: `pages/settings/printer_settings_page.dart`
- Modify: `pages/onboarding/onboarding_page.dart`
- Modify: `pages/onboarding/splash_page.dart`
- Modify: `pages/dashboard/more_page.dart`

- [ ] **Step 1: For each file, ensure these patterns:**

1. **No hardcoded colors** — all colors from `Theme.of(context)` or `AppColors.*` new tokens
2. **Cards use AppShadows** — replace manual `BoxShadow` with `AppShadows.sm` or `.md`
3. **Backgrounds use theme** — `Theme.of(context).scaffoldBackgroundColor` not hardcoded
4. **Borders use theme** — `Theme.of(context).colorScheme.outline` not `AppColors.divider`
5. **Text styles use theme** — `theme.textTheme.*` not manual `TextStyle(color: AppColors.textPrimary)`

- [ ] **Step 2: Focus on visual impact screens first:**

Priority order:
1. `more_page.dart` — settings menu
2. `product_detail_page.dart` — product view
3. `transaction_detail_page.dart` — sale detail
4. `onboarding_page.dart` + `splash_page.dart` — first impression
5. `sale_success_page.dart` — success celebration
6. All remaining screens

- [ ] **Step 3: Commit in batches of ~10 files**

```bash
git commit -m "feat(screens): theme consistency pass — batch 1 (core screens)"
git commit -m "feat(screens): theme consistency pass — batch 2 (product/pos screens)"
git commit -m "feat(screens): theme consistency pass — batch 3 (finance/staff/debt screens)"
git commit -m "feat(screens): theme consistency pass — batch 4 (remaining screens)"
```

---

## Task 9: Final Verification

- [ ] **Step 1: Search for any remaining issues**

```bash
grep -rn "BoxShadow" app/lib/presentation/pages/ --include="*.dart" | grep -v "AppShadows"
grep -rn "Color(0x" app/lib/presentation/pages/ --include="*.dart"
```

Fix any remaining manual colors or shadows.

- [ ] **Step 2: Verify all screens compile**

```bash
cd /Users/latifrjdev/Downloads/Dukon/app && flutter analyze
```

- [ ] **Step 3: Final commit**

```bash
git commit -m "feat(screens): complete Flutter screens redesign — Vibrant Gradient applied to all screens"
```
