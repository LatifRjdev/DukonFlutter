import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'route_names.dart';
import '../../injection.dart';
import '../../data/datasources/local/auth_local_datasource.dart';

import '../../presentation/pages/onboarding/splash_page.dart';
import '../../presentation/pages/onboarding/onboarding_page.dart';
import '../../presentation/pages/auth/login_page.dart';
import '../../presentation/pages/auth/register_page.dart';
import '../../presentation/pages/auth/otp_page.dart';
import '../../presentation/pages/auth/forgot_password_page.dart';
import '../../presentation/pages/auth/create_password_page.dart';
import '../../presentation/pages/store/create_store_page.dart';
import '../../presentation/pages/dashboard/home_page.dart';
import '../../presentation/pages/product/product_detail_page.dart';
import '../../presentation/pages/product/add_product_step1_page.dart';
import '../../presentation/pages/product/add_product_step2_page.dart';
import '../../presentation/pages/product/add_product_step3_page.dart';
import '../../presentation/pages/product/categories_page.dart';
import '../../presentation/pages/product/import_products_page.dart';
import '../../presentation/pages/product/empty_products_page.dart';
import '../../presentation/pages/pos/cash_payment_page.dart';
import '../../presentation/pages/pos/credit_sale_page.dart';
import '../../presentation/pages/pos/sale_success_page.dart';
import '../../presentation/pages/pos/receipt_preview_page.dart';
import '../../presentation/pages/settings/printer_settings_page.dart';
import '../../domain/entities/sale.dart';
import '../../presentation/pages/sales/sales_history_page.dart';
import '../../presentation/pages/sales/transaction_detail_page.dart';
import '../../presentation/pages/sales/refund_page.dart';
import '../../presentation/pages/sales/empty_sales_page.dart';
import '../../presentation/pages/stock/stock_intake_page.dart';
import '../../presentation/pages/finance/finance_dashboard_page.dart';
import '../../presentation/pages/finance/expense_list_page.dart';
import '../../presentation/pages/finance/add_expense_page.dart';
import '../../presentation/pages/finance/balance_page.dart';
import '../../presentation/pages/finance/credits_page.dart';
import '../../presentation/pages/finance/reports_page.dart';
import '../../presentation/pages/debt/debts_overview_page.dart';
import '../../presentation/pages/debt/customer_debts_page.dart';
import '../../presentation/pages/debt/supplier_debts_page.dart';
import '../../presentation/pages/zakat/zakat_calculator_page.dart';
import '../../presentation/pages/zakat/zakat_settings_page.dart';
import '../../presentation/pages/zakat/zakat_history_page.dart';
import '../../presentation/pages/customer/customer_list_page.dart';
import '../../presentation/pages/customer/customer_detail_page.dart';
import '../../presentation/pages/customer/customer_form_page.dart';
import '../../presentation/pages/supplier/supplier_list_page.dart';
import '../../presentation/pages/supplier/supplier_detail_page.dart';
import '../../presentation/pages/settings/settings_page.dart';
import '../../presentation/pages/settings/edit_profile_page.dart';
import '../../presentation/pages/settings/change_password_page.dart';
import '../../presentation/pages/staff/staff_list_page.dart';
import '../../presentation/pages/staff/add_staff_page.dart';
import '../../presentation/pages/staff/staff_detail_page.dart';
import '../../presentation/pages/roles/roles_page.dart';
import '../../presentation/pages/shifts/shifts_page.dart';
import '../../presentation/pages/shifts/open_shift_page.dart';
import '../../presentation/pages/shifts/z_report_page.dart';
import '../../presentation/pages/payroll/payroll_page.dart';
import '../../presentation/pages/payroll/add_adjustment_page.dart';
import '../../presentation/pages/delivery/delivery_list_page.dart';
import '../../presentation/pages/delivery/delivery_detail_page.dart';
import '../../presentation/pages/delivery/create_delivery_page.dart';
import '../../presentation/pages/inventory/inventory_count_page.dart';

class AppRouter {
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();

  static const _publicPaths = {
    RouteNames.splash,
    RouteNames.onboarding,
    RouteNames.login,
    RouteNames.register,
    RouteNames.otp,
    RouteNames.forgotPassword,
    RouteNames.createPassword,
  };

  static GoRouter get router => GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: RouteNames.splash,
    debugLogDiagnostics: true,
    redirect: (context, state) async {
      final path = state.uri.path;
      final isPublic = _publicPaths.contains(path);
      final hasTokens = await sl<AuthLocalDatasource>().hasTokens();

      // Don't redirect from splash — it handles its own navigation
      if (path == RouteNames.splash) return null;

      // Not authenticated → redirect to login (unless already on public page)
      if (!hasTokens && !isPublic) return RouteNames.login;

      // Authenticated → redirect away from login/register
      if (hasTokens && (path == RouteNames.login || path == RouteNames.register)) {
        return RouteNames.home;
      }

      return null;
    },
    routes: [
      // Onboarding
      GoRoute(
        path: RouteNames.splash,
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: RouteNames.onboarding,
        builder: (context, state) => const OnboardingPage(),
      ),

      // Auth
      GoRoute(
        path: RouteNames.login,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: RouteNames.register,
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: RouteNames.otp,
        builder: (context, state) {
          final phone = state.extra as String? ?? '';
          return OtpPage(phone: phone);
        },
      ),
      GoRoute(
        path: RouteNames.forgotPassword,
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: RouteNames.createPassword,
        builder: (context, state) {
          final extra = state.extra as Map<String, String>? ?? {};
          return CreatePasswordPage(
            phone: extra['phone'] ?? '',
            otp: extra['otp'] ?? '',
          );
        },
      ),

      // Store
      GoRoute(
        path: RouteNames.createStore,
        builder: (context, state) => const CreateStorePage(),
      ),

      // Home (with bottom nav + IndexedStack)
      GoRoute(
        path: RouteNames.home,
        builder: (context, state) => const HomePage(),
      ),

      // Products - static routes MUST come before dynamic :id route
      GoRoute(
        path: RouteNames.addProduct,
        builder: (context, state) => const AddProductStep1Page(),
      ),
      GoRoute(
        path: '/products/add/step2',
        builder: (context, state) => const AddProductStep2Page(),
      ),
      GoRoute(
        path: '/products/add/step3',
        builder: (context, state) => const AddProductStep3Page(),
      ),
      GoRoute(
        path: RouteNames.categories,
        builder: (context, state) => const CategoriesPage(),
      ),
      GoRoute(
        path: RouteNames.importProducts,
        builder: (context, state) => const ImportProductsPage(),
      ),
      GoRoute(
        path: '/products/empty',
        builder: (context, state) => const EmptyProductsPage(),
      ),
      // Dynamic route MUST be last
      GoRoute(
        path: '/products/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ProductDetailPage(productId: id);
        },
      ),

      // POS
      GoRoute(
        path: RouteNames.cashPayment,
        builder: (context, state) => const CashPaymentPage(),
      ),
      GoRoute(
        path: RouteNames.creditSale,
        builder: (context, state) => const CreditSalePage(),
      ),
      GoRoute(
        path: RouteNames.saleSuccess,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final sale = extra['sale'] as Sale;
          return SaleSuccessPage(sale: sale);
        },
      ),
      GoRoute(
        path: RouteNames.receiptPreview,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final sale = extra['sale'] as Sale;
          return ReceiptPreviewPage(sale: sale);
        },
      ),

      // Sales
      GoRoute(
        path: '/sales/history',
        builder: (context, state) => const SalesHistoryPage(),
      ),
      GoRoute(
        path: '/sales/:id',
        builder: (context, state) {
          final sale = state.extra as Sale;
          return TransactionDetailPage(sale: sale);
        },
      ),
      GoRoute(
        path: '/sales/:id/refund',
        builder: (context, state) {
          final sale = state.extra as Sale;
          return RefundPage(sale: sale);
        },
      ),
      GoRoute(
        path: '/sales/empty',
        builder: (context, state) => const EmptySalesPage(),
      ),

      // Stock
      GoRoute(
        path: RouteNames.stockIntake,
        builder: (context, state) => const StockIntakePage(),
      ),

      // Finance
      GoRoute(
        path: RouteNames.financeDashboard,
        builder: (context, state) {
          final storeId = state.extra as String?;
          return FinanceDashboardPage(storeId: storeId);
        },
      ),
      GoRoute(
        path: RouteNames.expenses,
        builder: (context, state) {
          final storeId = state.extra as String? ?? '';
          return ExpenseListPage(storeId: storeId);
        },
      ),
      GoRoute(
        path: RouteNames.addExpense,
        builder: (context, state) {
          final storeId = state.extra as String? ?? '';
          return AddExpensePage(storeId: storeId);
        },
      ),
      GoRoute(
        path: RouteNames.financeBalance,
        builder: (context, state) {
          final storeId = state.extra as String? ?? '';
          return BalancePage(storeId: storeId);
        },
      ),
      GoRoute(
        path: RouteNames.financeCredits,
        builder: (context, state) {
          final storeId = state.extra as String? ?? '';
          return CreditsPage(storeId: storeId);
        },
      ),
      GoRoute(
        path: RouteNames.financeReports,
        builder: (context, state) {
          final storeId = state.extra as String? ?? '';
          return ReportsPage(storeId: storeId.isEmpty ? null : storeId);
        },
      ),

      // Debts
      GoRoute(
        path: RouteNames.debtsOverview,
        builder: (context, state) {
          final storeId = state.extra as String? ?? '';
          return DebtsOverviewPage(storeId: storeId);
        },
      ),
      GoRoute(
        path: '/debts/customer',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return CustomerDebtsPage(
            storeId: extra['storeId'] as String? ?? '',
            customerId: extra['customerId'] as String? ?? '',
            customerName: extra['customerName'] as String? ?? '',
            customerPhone: extra['customerPhone'] as String?,
          );
        },
      ),
      GoRoute(
        path: '/debts/supplier',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return SupplierDebtsPage(
            storeId: extra['storeId'] as String? ?? '',
            supplierId: extra['supplierId'] as String? ?? '',
            supplierName: extra['supplierName'] as String? ?? '',
          );
        },
      ),

      // Zakat
      GoRoute(
        path: RouteNames.zakatCalculator,
        builder: (context, state) {
          final storeId = state.extra as String? ?? '';
          return ZakatCalculatorPage(storeId: storeId);
        },
      ),
      GoRoute(
        path: RouteNames.zakatSettings,
        builder: (context, state) {
          final storeId = state.extra as String? ?? '';
          return ZakatSettingsPage(storeId: storeId);
        },
      ),
      GoRoute(
        path: RouteNames.zakatHistory,
        builder: (context, state) {
          final storeId = state.extra as String? ?? '';
          return ZakatHistoryPage(storeId: storeId);
        },
      ),

      // Customer/Supplier
      GoRoute(
        path: RouteNames.customerList,
        builder: (context, state) => const CustomerListPage(),
      ),
      // Static customer form route MUST come before dynamic :id route
      GoRoute(
        path: RouteNames.customerForm,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return CustomerFormPage(
            storeId: extra['storeId'] as String? ?? '',
            customerId: extra['customerId'] as String?,
            existingCustomer: extra['customer'] as dynamic,
          );
        },
      ),
      GoRoute(
        path: RouteNames.supplierList,
        builder: (context, state) => const SupplierListPage(),
      ),
      GoRoute(
        path: '/customers/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final storeId = state.extra as String? ?? '';
          return CustomerDetailPage(customerId: id, storeId: storeId);
        },
      ),
      GoRoute(
        path: '/suppliers/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final storeId = state.extra as String? ?? '';
          return SupplierDetailPage(supplierId: id, storeId: storeId);
        },
      ),

      // Staff
      GoRoute(
        path: RouteNames.staffList,
        builder: (context, state) {
          final storeId = state.extra as String? ?? '';
          return StaffListPage(storeId: storeId);
        },
      ),
      GoRoute(
        path: RouteNames.addStaff,
        builder: (context, state) {
          final storeId = state.extra as String? ?? '';
          return AddStaffPage(storeId: storeId);
        },
      ),
      GoRoute(
        path: '/staff/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final storeId = state.extra as String? ?? '';
          return StaffDetailPage(staffId: id, storeId: storeId);
        },
      ),
      GoRoute(
        path: RouteNames.roles,
        builder: (context, state) {
          final storeId = state.extra as String? ?? '';
          return RolesPage(storeId: storeId);
        },
      ),

      // Shifts
      GoRoute(
        path: RouteNames.shifts,
        builder: (context, state) {
          final storeId = state.extra as String? ?? '';
          return ShiftsPage(storeId: storeId);
        },
      ),
      GoRoute(
        path: RouteNames.openShift,
        builder: (context, state) {
          final storeId = state.extra as String? ?? '';
          return OpenShiftPage(storeId: storeId);
        },
      ),
      GoRoute(
        path: '/shifts/:id/z-report',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final storeId = state.extra as String? ?? '';
          return ZReportPage(storeId: storeId, shiftId: id);
        },
      ),

      // Payroll
      GoRoute(
        path: RouteNames.payroll,
        builder: (context, state) {
          final storeId = state.extra as String? ?? '';
          return PayrollPage(storeId: storeId);
        },
      ),
      GoRoute(
        path: '/payroll/:periodId/adjustment',
        builder: (context, state) {
          final periodId = state.pathParameters['periodId']!;
          final storeId = state.extra as String? ?? '';
          return AddAdjustmentPage(storeId: storeId, periodId: periodId);
        },
      ),

      // Delivery — static routes before dynamic :id
      GoRoute(
        path: RouteNames.deliveryCreate,
        builder: (context, state) {
          final storeId = state.extra as String? ?? '';
          return CreateDeliveryPage(storeId: storeId);
        },
      ),
      GoRoute(
        path: RouteNames.deliveryList,
        builder: (context, state) {
          final storeId = state.extra as String? ?? '';
          return DeliveryListPage(storeId: storeId);
        },
      ),
      GoRoute(
        path: '/deliveries/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final storeId = extra['storeId'] as String? ?? '';
          return DeliveryDetailPage(storeId: storeId, deliveryId: id);
        },
      ),

      // Inventory
      GoRoute(
        path: RouteNames.inventoryCount,
        builder: (context, state) {
          final storeId = state.extra as String? ?? '';
          return InventoryCountPage(storeId: storeId);
        },
      ),

      // Settings
      GoRoute(
        path: RouteNames.settings,
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        path: RouteNames.editProfile,
        builder: (context, state) => const EditProfilePage(),
      ),
      GoRoute(
        path: RouteNames.changePassword,
        builder: (context, state) => const ChangePasswordPage(),
      ),
      GoRoute(
        path: RouteNames.printerSettings,
        builder: (context, state) => const PrinterSettingsPage(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.uri}'),
      ),
    ),
  );
}
