class RouteNames {
  RouteNames._();

  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String register = '/register';
  static const String otp = '/otp';
  static const String forgotPassword = '/forgot-password';
  static const String createPassword = '/create-password';
  static const String createStore = '/create-store';

  // Main tabs
  static const String home = '/home';
  static const String dashboard = '/dashboard';
  static const String products = '/products';
  static const String pos = '/pos';
  static const String sales = '/sales';
  static const String more = '/more';

  // Products
  static const String productDetail = '/products/:id';
  static const String addProduct = '/products/add';
  static const String editProduct = '/products/:id/edit';
  static const String categories = '/categories';
  static const String importProducts = '/products/import';

  // POS
  static const String cashPayment = '/pos/cash-payment';
  static const String creditSale = '/pos/credit-sale';
  static const String saleSuccess = '/pos/success';
  static const String receiptPreview = '/pos/receipt';

  // Sales
  static const String salesHistory = '/sales/history';
  static const String transactionDetail = '/sales/:id';
  static const String refund = '/sales/:id/refund';

  // Stock
  static const String stockIntake = '/stock/intake';

  // Finance
  static const String financeDashboard = '/finance';
  static const String expenses = '/finance/expenses';
  static const String addExpense = '/finance/expenses/add';
  static const String financeBalance = '/finance/balance';
  static const String financeCredits = '/finance/credits';
  static const String financeReports = '/finance/reports';
  static const String financeCurrencies = '/finance/currencies';
  static const String notifications = '/notifications';
  static const String notificationSettings = '/notifications/settings';

  // Debts
  static const String debtsOverview = '/debts';
  static const String customerDebts = '/debts/customer';
  static const String supplierDebts = '/debts/supplier';

  // Zakat
  static const String zakatCalculator = '/zakat';
  static const String zakatSettings = '/zakat/settings';
  static const String zakatHistory = '/zakat/history';

  // Customer/Supplier
  static const String customerList = '/customers';
  static const String customerDetail = '/customers/:id';
  static const String customerForm = '/customers/form';
  static const String supplierList = '/suppliers';
  static const String supplierDetail = '/suppliers/:id';

  // Staff
  static const String staffList = '/staff';
  static const String addStaff = '/staff/add';
  static const String staffDetail = '/staff/:id';
  static const String roles = '/roles';

  // Shifts
  static const String shifts = '/shifts';
  static const String openShift = '/shifts/open';
  static const String zReport = '/shifts/:id/z-report';

  // Payroll
  static const String payroll = '/payroll';
  static const String addAdjustment = '/payroll/:periodId/adjustment';

  // Delivery
  static const String deliveryList = '/deliveries';
  static const String deliveryDetail = '/deliveries/:id';
  static const String deliveryCreate = '/deliveries/create';

  // Inventory
  static const String inventoryCount = '/inventory/count';

  // Settings
  static const String settings = '/settings';
  static const String editProfile = '/settings/profile';
  static const String changePassword = '/settings/password';
  static const String printerSettings = '/settings/printer';
  static const String myStores = '/settings/stores';
  static const String discounts = '/settings/discounts';
  static const String receiptTemplate = '/settings/receipt-template';
  static const String kkmSettings = '/settings/kkm';
  static const String scannerSettings = '/settings/scanner';
  static const String telegramBot = '/settings/telegram-bot';
  static const String languageSettings = '/settings/language';
  static const String offlineMode = '/settings/offline';
  static const String subscription = '/settings/subscription';
}
