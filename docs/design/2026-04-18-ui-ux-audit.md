# Dukon UI/UX Audit — 2026-04-18

## TL;DR

Dukon's design foundation is **well-structured** with strong token coverage (spacing, radius, typography all centralized), good dark mode parity via Material 3, and solid component encapsulation via AppButton, AppCard, AppTextField. However, **medium-severity gaps** exist: (1) only 1 of 77 screens uses AppEmptyState, leaving 20+ list screens with missing empty/error handling; (2) login & auth pages bypass AppTextField in favor of direct TextField; (3) GradientHeader doesn't adapt to dark mode; (4) button styles inconsistently use ElevatedButton in error flows vs AppButton elsewhere; (5) Russian text length risks remain unaddressed in several layouts. The POS checkout screen (highest-stakes) has solid UX but minimal state feedback.

---

## Design System Health

### Strengths
- **Token completeness**: `AppConstants` covers spacing (Xs–Xxl), radius (Sm–Round), button height/width, animations, pagination
- **Dark mode parity**: Material 3 ColorScheme with separate light/dark text colors, surfaces, borders. `AppCard` and `AppButton` respect `Theme.of(context).brightness`
- **Typography scale**: `_textTheme` (headlineLarge → labelSmall) in Google Inter, well-distributed
- **Status colors**: Semantic palette defined (`success`, `warning`, `error`, `info`) with tints
- **Component quality**: AppButton, AppCard, AppTextField, AppEmptyState, GlassCard are well-encapsulated
- **Shadow elevation**: `AppShadows` has sm/md/lg/button presets with consistent opacity and blur

### Gaps & Inconsistencies
| # | Issue | Evidence | Severity |
|---|-------|----------|----------|
| 1 | Empty state handling missing across list screens | Only `categories_page.dart` uses AppEmptyState. 20+ list screens lack fallback UI | 🔴 High |
| 2 | Auth pages bypass AppTextField | `login_page.dart:69–101`, `create_password_page.dart`, etc. use direct `TextField()` | 🟡 Medium |
| 3 | GradientHeader not dark-mode aware | Always applies `AppGradients.primary` + hardcoded white text, no brightness check | 🟡 Medium |
| 4 | Inconsistent error button styling | `dashboard_page.dart:117` uses bare `ElevatedButton`, others use AppButton | 🟡 Medium |
| 5 | Missing error state widget in data screens | `AppErrorWidget` referenced in 0 of 77 screens | 🟡 Medium |
| 6 | Russian text truncation risk | Missing `overflow: TextOverflow.ellipsis` in list tiles, card titles | 🟡 Medium |
| 7 | Hardcoded colors in login_page | `login_page.dart:51, :73` hardcoded `AppColors.error`, white | 🟢 Low |
| 8 | TextField in customer_list AlertDialog | Lines 69–87 bypass AppTextField | 🟢 Low |
| 9 | No loading state in AppCard | Unlike AppButton, AppCard doesn't support `isLoading` | 🟢 Low |
| 10 | Hardcoded padding in several screens | `EdgeInsets.fromLTRB(16, 8, 8, 0)` instead of `spacingMd`/`spacingSm` | 🟢 Low |

---

## Screen-by-Screen Findings (12 sampled)

### 1. LoginPage (`auth/login_page.dart`)
**First impression:** Gradient header with "DukonPro" + "Управление магазином" is eye-catching and clear.
- 🟡 Dark mode fails: hardcoded `AppGradients.primary` + `Colors.white` text
- 🟡 Uses `AppTextField` correctly in lines 93–102 (good), but other auth pages bypass it
- 🟢 No validation feedback until submit (only snackbar)
- 🟢 Hardcoded typography: `fontSize: 14, color: Color(0xB3FFFFFF)` not using theme

### 2. DashboardPage (`dashboard/dashboard_page.dart`)
**First impression:** Gradient header + period chips + 3-column stat cards overlapping header. Clean, modern.
- 🟡 Line 117 uses bare `ElevatedButton` for retry (should be AppButton)
- 🟡 GradientHeader dark mode fail
- 🟡 No AppErrorWidget usage — error UI built inline
- 🟢 Stat card titles may truncate in Russian on <360dp screens

### 3. PosCheckoutPage (`pos/pos_checkout_page.dart`) — **HIGHEST STAKES**
**First impression:** Header + search + cart list. Simple, clear intent.
- 🔴 **No empty cart state** — blank UI with no CTA
- 🟡 Payment method selected implicitly (`_selectedPaymentMethod = 'CASH'`) but no visual indicator
- 🟡 Customer modal (lines 121–203) has no loading state
- 🟢 Uses `TextButton` for "Без клиента" instead of consistent styling

### 4. SaleSuccessPage (`pos/sale_success_page.dart`)
**First impression:** Animated checkmark, large green amount, Print/Share buttons. Celebratory.
- 🟡 No "New Sale" button — user must tap Android back
- 🟢 Hardcoded `EdgeInsets.all(24)` instead of `spacingLg`
- 🟢 Animation controller recreated on every mount

### 5. ProductListPage (`product/product_list_page.dart`)
**First impression:** Header + search + filter chips + grid/list. Clear, task-focused.
- 🔴 No empty state — blank screen for new store
- 🟡 Filter chips don't visually indicate active state
- 🟡 Product names likely truncate without ellipsis
- 🟢 Barcode scanner tightly coupled

### 6. AddProductStep1Page (`product/add_product_step1_page.dart`)
**First impression:** Multi-step form. Clear intent.
- ✅ Uses AppTextField correctly with validators
- 🟡 Image picker: no permission request UI, no error handling for denied permissions
- 🟢 Category selector visibility unclear

### 7. SalesHistoryPage (`sales/sales_history_page.dart`)
**First impression:** Header + period chips + sale list. Functional.
- 🔴 No empty state
- 🟡 Filter icon doesn't show if filters are active
- 🟡 Customer name + phone truncation risk in Russian
- 🟢 Date formatting not locale-aware

### 8. FinanceDashboardPage (`finance/finance_dashboard_page.dart`)
**First impression:** Period tabs + revenue/profit/expenses cards. Data-heavy but scannable.
- 🟡 Single `CircularProgressIndicator` for entire screen (should be skeleton loaders)
- 🟡 FlChart may not adapt to dark theme
- 🟡 Financial labels may truncate in Russian
- 🟢 No chart error boundary

### 9. SettingsPage (`settings/settings_page.dart`)
**First impression:** Profile card + menu list. Long, needs scrolling.
- 🟡 Profile card uses bare `Container(decoration: BoxDecoration(...))` instead of AppCard
- 🟡 Menu items don't show ripple/highlight on tap
- 🟡 Menu labels may truncate
- 🟢 Bare AlertDialog for logout

### 10. CustomerListPage (`customer/customer_list_page.dart`)
**First impression:** Header + search + customer list. Simple.
- 🔴 No empty state
- 🟡 Search bar uses bare `TextFormField()` instead of AppTextField
- 🟡 Add customer dialog (lines 69–87) uses bare TextField
- 🟢 No visual validation feedback on empty name

### 11. DebtsOverviewPage (`debt/debts_overview_page.dart`)
**First impression:** Summary cards (Нам должны / Мы должны) + customer debts + supplier debts. Clear hierarchy.
- 🟡 Summary cards (lines 61–98) use bare Container instead of reusable component
- 🟡 No empty state
- 🟢 Debt name truncation risk

### 12. DashboardPage Shell (`dashboard/home_page.dart`)
**First impression:** Bottom nav with 5 icons, IndexedStack. Clear navigation.
- 🟡 _POSButton has custom gradient + shadow (not standard Material)
- 🟡 No page transition animations (instant switch)
- 🟢 Hardcoded `fontSize: 10` for nav labels instead of theme

---

## Cross-Cutting Patterns

| Pattern | Count | Impact |
|---------|-------|--------|
| No AppEmptyState | 76/77 screens | 🔴 High |
| No AppErrorWidget | 77/77 screens | 🔴 High |
| Bare TextField (not AppTextField) | 20+ occurrences | 🟡 Medium |
| ElevatedButton usage | 11 occurrences | 🟡 Medium |
| GradientHeader dark mode fail | 2 screens | 🟡 Medium |
| Russian text without overflow | 15+ screens | 🟡 Medium |
| Hardcoded padding (not AppConstants) | 25+ screens | 🟢 Low |
| Hardcoded colors (Color(0xFF...)) | 3 files | 🟢 Low |

---

## Prioritized Improvement Roadmap

### 1. 🔴 Add AppEmptyState to all list screens
- **Affects:** 20+ screens (product_list, customer_list, sales_history, supplier_list, staff_list, delivery_list, etc.)
- **Effort:** M
- **How:** Replace empty checks with `AppEmptyState(icon, title, subtitle, buttonText, onButtonPressed)`

### 2. 🔴 Centralize error state UI via AppErrorWidget
- **Affects:** finance, dashboard, sales, customer, debt screens
- **Effort:** M
- **How:** Use `AppErrorWidget(message, onRetry)` in all BlocBuilder error branches

### 3. 🔴 Add empty cart state to POS checkout
- **Affects:** pos_checkout_page
- **Effort:** S
- **Why:** Core business screen — user shouldn't see blank cart and guess next action

### 4. 🟡 Migrate auth pages to AppTextField
- **Affects:** login_page, register_page, create_password_page, forgot_password_page, customer dialog
- **Effort:** M

### 5. 🟡 Fix GradientHeader dark mode
- **Affects:** dashboard_page, login_page
- **Effort:** S
- **How:** Add `isDark` check; use darker gradient + theme-aware text color

### 6. 🟡 Add Russian text overflow handling
- **Affects:** product_list, customer_list, sales_history, finance, debt, supplier screens
- **Effort:** M
- **How:** Audit 10 key list screens; add `overflow: TextOverflow.ellipsis, maxLines: 1`; test on 320dp width

### 7. 🟡 Unify button styles (ElevatedButton → AppButton)
- **Affects:** dashboard, finance, settings, error states
- **Effort:** S

### 8. 🟢 Extract hardcoded card styles to reusable components
- **Affects:** debts_overview_page, settings_page
- **Effort:** S

### 9. 🟢 Test dark mode across all screens
- **Affects:** All 77 screens
- **Effort:** M

### 10. 🟢 Standardize padding/margin to AppConstants
- **Affects:** ~25 screens
- **Effort:** L

---

## What's Already Great

- Material 3 integration with proper ColorScheme, TextTheme, ThemeData
- Gradient + shadow system (AppGradients, AppShadows) is polished and consistent
- Custom _POSButton in bottom nav is visually distinct and delightful
- BLoC state management used consistently
- Localization (AppLocalizations) ready for multi-language
- PhoneInputField handles Tajik prefix correctly
- BarcodeScannerSheet encapsulates scanner logic
- Validation in forms (AddProductStep1Page, LoginPage) with proper validators
