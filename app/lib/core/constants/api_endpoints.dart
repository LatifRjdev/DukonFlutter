class ApiEndpoints {
  ApiEndpoints._();

  /// API base URL. Override with `--dart-define=API_BASE_URL=https://...`
  /// for staging / production builds. The default value is the Android
  /// emulator loopback and must NEVER be used for a real deploy.
  ///
  /// A release-mode assertion in `main.dart` enforces HTTPS so shipping a
  /// build without overriding this constant will fail loudly.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:4455/api',
  );

  // Auth
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';

  // Users
  static const String userMe = '/users/me';

  // Stores
  static const String stores = '/stores';
  static String store(String id) => '/stores/$id';

  // Categories
  static String categories(String storeId) => '/stores/$storeId/categories';
  static String category(String storeId, String id) => '/stores/$storeId/categories/$id';

  // Products
  static String products(String storeId) => '/stores/$storeId/products';
  static String product(String storeId, String id) => '/stores/$storeId/products/$id';
  static String productByBarcode(String storeId, String barcode) =>
      '/stores/$storeId/products/barcode/$barcode';
  static String productImport(String storeId) => '/stores/$storeId/products/import';

  // Stock Movements
  static String stockMovements(String storeId, String productId) =>
      '/stores/$storeId/products/$productId/stock-movements';

  // Sales
  static String sales(String storeId) => '/stores/$storeId/sales';
  static String sale(String storeId, String id) => '/stores/$storeId/sales/$id';
  static String saleRefund(String storeId, String id) => '/stores/$storeId/sales/$id/refund';

  // Customers
  static String customers(String storeId) => '/stores/$storeId/customers';
  static String customer(String storeId, String id) => '/stores/$storeId/customers/$id';

  // Suppliers
  static String suppliers(String storeId) => '/stores/$storeId/suppliers';
  static String supplier(String storeId, String id) => '/stores/$storeId/suppliers/$id';

  // Finances
  static String financeOverview(String storeId) => '/stores/$storeId/finances/overview';
  static String financeDashboard(String storeId) => '/stores/$storeId/finances/dashboard';
  static String financeSummary(String storeId) => '/stores/$storeId/finances/summary';

  // Expenses
  static String expenses(String storeId) => '/stores/$storeId/expenses';
  static String expense(String storeId, String id) => '/stores/$storeId/expenses/$id';

  // Customer Debts & Payments
  static String customerDebts(String storeId, String customerId) => '/stores/$storeId/customers/$customerId/debts';
  static String customerPayments(String storeId, String customerId) => '/stores/$storeId/customers/$customerId/payments';

  // Supplier Debts & Payments
  static String supplierDebts(String storeId, String supplierId) => '/stores/$storeId/suppliers/$supplierId/debts';
  static String supplierPayments(String storeId, String supplierId) => '/stores/$storeId/suppliers/$supplierId/payments';

  // Zakat
  static String zakatCalculate(String storeId) => '/stores/$storeId/zakat/calculate';
  static String zakatSettings(String storeId) => '/stores/$storeId/zakat/settings';
  static String zakatPayments(String storeId) => '/stores/$storeId/zakat/payments';

  // User password
  static const String changePassword = '/users/me/password';

  // Staff
  static String staff(String storeId) => '/stores/$storeId/staff';
  static String staffMember(String storeId, String id) => '/stores/$storeId/staff/$id';

  // Roles
  static String roles(String storeId) => '/stores/$storeId/roles';
  static String rolePermissions(String storeId, String role) => '/stores/$storeId/roles/$role/permissions';

  // Shifts
  static String shifts(String storeId) => '/stores/$storeId/shifts';
  static String shiftOpen(String storeId) => '/stores/$storeId/shifts/open';
  static String shiftClose(String storeId, String id) => '/stores/$storeId/shifts/$id/close';
  static String shiftCurrent(String storeId) => '/stores/$storeId/shifts/current';
  static String shiftDetail(String storeId, String id) => '/stores/$storeId/shifts/$id';
  static String shiftZReport(String storeId, String id) => '/stores/$storeId/shifts/$id/z-report';

  // Payroll
  static String payrollPeriods(String storeId) => '/stores/$storeId/payroll';
  static String payrollCalculate(String storeId) => '/stores/$storeId/payroll/calculate';
  static String payrollPeriod(String storeId, String periodId) => '/stores/$storeId/payroll/$periodId';
  static String payrollAdjustments(String storeId, String periodId) => '/stores/$storeId/payroll/$periodId/adjustments';
  static String payrollAdjustment(String storeId, String periodId, String adjId) => '/stores/$storeId/payroll/$periodId/adjustments/$adjId';
  static String payrollPay(String storeId, String periodId, String payrollId) => '/stores/$storeId/payroll/$periodId/pay/$payrollId';
  static String payrollPayAll(String storeId, String periodId) => '/stores/$storeId/payroll/$periodId/pay-all';
}
