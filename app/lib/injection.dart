import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'core/network/api_interceptor.dart';
import 'core/network/dio_client.dart';
import 'core/network/network_info.dart';
import 'core/router/app_router.dart';

import 'data/datasources/local/auth_local_datasource.dart';
import 'data/datasources/local/cart_local_datasource.dart';
import 'data/datasources/local/category_local_datasource.dart';
import 'data/datasources/local/product_local_datasource.dart';
import 'data/datasources/local/sale_local_datasource.dart';
import 'data/datasources/remote/auth_remote_datasource.dart';
import 'data/datasources/remote/category_remote_datasource.dart';
import 'data/datasources/remote/customer_remote_datasource.dart';
import 'data/datasources/remote/product_remote_datasource.dart';
import 'data/datasources/remote/sale_remote_datasource.dart';
import 'data/datasources/remote/store_remote_datasource.dart';
import 'data/repositories/auth_repository_impl.dart';
import 'data/repositories/category_repository_impl.dart';
import 'data/repositories/customer_repository_impl.dart';
import 'data/repositories/debt_repository_impl.dart';
import 'data/repositories/product_repository_impl.dart';
import 'data/repositories/sale_repository_impl.dart';
import 'data/repositories/stock_repository_impl.dart';
import 'data/repositories/store_repository_impl.dart';
import 'data/repositories/supplier_repository_impl.dart';
import 'data/sync/conflict_resolver.dart';
import 'data/sync/sync_engine.dart';
import 'data/sync/sync_queue.dart';

import 'domain/repositories/auth_repository.dart';
import 'domain/repositories/category_repository.dart';
import 'domain/repositories/customer_repository.dart';
import 'domain/repositories/debt_repository.dart';
import 'domain/repositories/product_repository.dart';
import 'domain/repositories/sale_repository.dart';
import 'domain/repositories/stock_repository.dart';
import 'domain/repositories/store_repository.dart';
import 'domain/repositories/supplier_repository.dart';

import 'presentation/blocs/auth/auth_bloc.dart';
import 'presentation/blocs/category/category_bloc.dart';
import 'presentation/blocs/pos/cart_bloc.dart';
import 'presentation/blocs/product/product_list_bloc.dart';
import 'presentation/blocs/store/store_bloc.dart';
import 'presentation/blocs/dashboard/dashboard_bloc.dart';
import 'data/datasources/remote/dashboard_remote_datasource.dart';
import 'data/datasources/remote/finance_remote_datasource.dart';
import 'data/datasources/remote/expense_remote_datasource.dart';
import 'data/datasources/remote/investment_remote_datasource.dart';
import 'data/datasources/remote/notification_remote_datasource.dart';
import 'data/datasources/remote/zakat_remote_datasource.dart';
import 'data/repositories/dashboard_repository_impl.dart';
import 'data/repositories/finance_repository_impl.dart';
import 'data/repositories/expense_repository_impl.dart';
import 'data/repositories/investment_repository_impl.dart';
import 'data/repositories/zakat_repository_impl.dart';
import 'domain/repositories/dashboard_repository.dart';
import 'domain/repositories/finance_repository.dart';
import 'domain/repositories/expense_repository.dart';
import 'domain/repositories/investment_repository.dart';
import 'domain/repositories/zakat_repository.dart';
import 'presentation/blocs/finance/finance_bloc.dart';
import 'presentation/blocs/expense/expense_bloc.dart';
import 'presentation/blocs/investment/investment_bloc.dart';
import 'presentation/blocs/debt/debt_bloc.dart';
import 'presentation/blocs/zakat/zakat_bloc.dart';
import 'presentation/blocs/settings/settings_bloc.dart';
import 'presentation/blocs/customer_detail/customer_detail_bloc.dart';
import 'presentation/blocs/supplier_detail/supplier_detail_bloc.dart';
import 'data/datasources/remote/currency_remote_datasource.dart';
import 'data/datasources/remote/staff_remote_datasource.dart';
import 'data/datasources/remote/shift_remote_datasource.dart';
import 'data/datasources/remote/payroll_remote_datasource.dart';
import 'data/repositories/staff_repository_impl.dart';
import 'data/repositories/shift_repository_impl.dart';
import 'data/repositories/payroll_repository_impl.dart';
import 'domain/repositories/staff_repository.dart';
import 'domain/repositories/shift_repository.dart';
import 'domain/repositories/payroll_repository.dart';
import 'presentation/blocs/customer/customer_list_bloc.dart';
import 'presentation/blocs/supplier/supplier_list_bloc.dart';
import 'presentation/blocs/staff/staff_bloc.dart';
import 'presentation/blocs/roles/roles_bloc.dart';
import 'presentation/blocs/shift/shift_bloc.dart';
import 'presentation/blocs/payroll/payroll_bloc.dart';
import 'presentation/blocs/staff_form/staff_form_bloc.dart';
import 'presentation/blocs/printer/printer_bloc.dart';
import 'presentation/blocs/subscription/subscription_bloc.dart';
import 'data/datasources/remote/loyalty_remote_datasource.dart';
import 'data/repositories/loyalty_repository_impl.dart';
import 'domain/repositories/loyalty_repository.dart';
import 'presentation/blocs/loyalty/loyalty_settings_bloc.dart';
import 'presentation/blocs/pos/checkout_bloc.dart';
import 'presentation/blocs/sales/sales_history_bloc.dart';
import 'presentation/blocs/stock/stock_intake_bloc.dart';
import 'presentation/blocs/product/product_form_bloc.dart';
import 'presentation/blocs/import/import_bloc.dart';
import 'core/services/receipt_pdf_service.dart';
import 'core/services/thermal_printer_service.dart';
import 'core/services/receipt_share_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/debt_reminder_service.dart';

final sl = GetIt.instance;

Future<void> initDependencies() async {
  // ---------------------------------------------------------------------------
  // External
  // ---------------------------------------------------------------------------

  const secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  sl.registerLazySingleton<FlutterSecureStorage>(() => secureStorage);

  // E.4: register SharedPreferences as a singleton so the cart
  // persistence layer (and others) can take it via DI without
  // awaiting on every call.
  final sharedPrefs = await SharedPreferences.getInstance();
  sl.registerSingleton<SharedPreferences>(sharedPrefs);

  sl.registerLazySingleton<Connectivity>(() => Connectivity());

  // SQLite database
  final database = await _initDatabase();
  sl.registerLazySingleton<Database>(() => database);

  // ---------------------------------------------------------------------------
  // Core
  // ---------------------------------------------------------------------------

  sl.registerLazySingleton<NetworkInfo>(
    () => NetworkInfoImpl(sl<Connectivity>()),
  );

  sl.registerLazySingleton<ApiInterceptor>(
    () => ApiInterceptor(
      storage: sl<FlutterSecureStorage>(),
      onSessionExpired: () {
        sl<FlutterSecureStorage>().deleteAll();
        AppRouter.router.go('/login');
      },
    ),
  );

  sl.registerLazySingleton<DioClient>(
    () => DioClient(apiInterceptor: sl<ApiInterceptor>()),
  );

  // ---------------------------------------------------------------------------
  // Sync
  // ---------------------------------------------------------------------------

  sl.registerLazySingleton<SyncQueue>(
    () => SyncQueue(database: sl<Database>()),
  );

  sl.registerLazySingleton<ConflictResolver>(
    () => const ConflictResolver(),
  );

  sl.registerLazySingleton<SyncEngine>(
    () => SyncEngine(
      syncQueue: sl<SyncQueue>(),
      dioClient: sl<DioClient>(),
      networkInfo: sl<NetworkInfo>(),
      conflictResolver: sl<ConflictResolver>(),
    ),
  );

  // ---------------------------------------------------------------------------
  // Datasources — Local
  // ---------------------------------------------------------------------------

  sl.registerLazySingleton<AuthLocalDatasource>(
    () => AuthLocalDatasourceImpl(storage: sl<FlutterSecureStorage>()),
  );

  sl.registerLazySingleton<ProductLocalDatasource>(
    () => ProductLocalDatasourceImpl(database: sl<Database>()),
  );

  sl.registerLazySingleton<SaleLocalDatasource>(
    () => SaleLocalDatasourceImpl(database: sl<Database>()),
  );

  sl.registerLazySingleton<CategoryLocalDatasource>(
    () => CategoryLocalDatasourceImpl(database: sl<Database>()),
  );

  // E.4: cart persistence — uses SharedPreferences fetched lazily on
  // first save to keep init() synchronous.
  sl.registerLazySingleton<CartLocalDatasource>(
    () => CartLocalDatasource(sl<SharedPreferences>()),
  );

  // ---------------------------------------------------------------------------
  // Datasources — Remote
  // ---------------------------------------------------------------------------

  sl.registerLazySingleton<AuthRemoteDatasource>(
    () => AuthRemoteDatasourceImpl(dioClient: sl<DioClient>()),
  );

  sl.registerLazySingleton<StoreRemoteDatasource>(
    () => StoreRemoteDatasourceImpl(dioClient: sl<DioClient>()),
  );

  sl.registerLazySingleton<ProductRemoteDatasource>(
    () => ProductRemoteDatasourceImpl(dioClient: sl<DioClient>()),
  );

  sl.registerLazySingleton<CategoryRemoteDatasource>(
    () => CategoryRemoteDatasourceImpl(dioClient: sl<DioClient>()),
  );

  sl.registerLazySingleton<SaleRemoteDatasource>(
    () => SaleRemoteDatasourceImpl(dioClient: sl<DioClient>()),
  );

  sl.registerLazySingleton<CustomerRemoteDatasource>(
    () => CustomerRemoteDatasourceImpl(dioClient: sl<DioClient>()),
  );

  sl.registerLazySingleton<DashboardRemoteDatasource>(
    () => DashboardRemoteDatasourceImpl(dioClient: sl<DioClient>()),
  );

  sl.registerLazySingleton<FinanceRemoteDatasource>(
    () => FinanceRemoteDatasourceImpl(dioClient: sl<DioClient>()),
  );

  sl.registerLazySingleton<ExpenseRemoteDatasource>(
    () => ExpenseRemoteDatasourceImpl(dioClient: sl<DioClient>()),
  );

  sl.registerLazySingleton<InvestmentRemoteDatasource>(
    () => InvestmentRemoteDatasourceImpl(dioClient: sl<DioClient>()),
  );

  sl.registerLazySingleton<ZakatRemoteDatasource>(
    () => ZakatRemoteDatasourceImpl(dioClient: sl<DioClient>()),
  );

  sl.registerLazySingleton<StaffRemoteDatasource>(
    () => StaffRemoteDatasourceImpl(dioClient: sl<DioClient>()),
  );

  sl.registerLazySingleton<ShiftRemoteDatasource>(
    () => ShiftRemoteDatasourceImpl(dioClient: sl<DioClient>()),
  );

  sl.registerLazySingleton<PayrollRemoteDatasource>(
    () => PayrollRemoteDatasourceImpl(dioClient: sl<DioClient>()),
  );

  sl.registerLazySingleton<CurrencyRemoteDatasource>(
    () => CurrencyRemoteDatasourceImpl(dioClient: sl<DioClient>()),
  );

  sl.registerLazySingleton<NotificationRemoteDatasource>(
    () => NotificationRemoteDatasourceImpl(dioClient: sl<DioClient>()),
  );

  // ---------------------------------------------------------------------------
  // Repositories
  // ---------------------------------------------------------------------------

  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      remoteDatasource: sl<AuthRemoteDatasource>(),
      localDatasource: sl<AuthLocalDatasource>(),
    ),
  );

  sl.registerLazySingleton<StoreRepository>(
    () => StoreRepositoryImpl(
      remoteDatasource: sl<StoreRemoteDatasource>(),
    ),
  );

  sl.registerLazySingleton<ProductRepository>(
    () => ProductRepositoryImpl(
      remoteDatasource: sl<ProductRemoteDatasource>(),
      localDatasource: sl<ProductLocalDatasource>(),
      networkInfo: sl<NetworkInfo>(),
      syncQueue: sl<SyncQueue>(),
    ),
  );

  sl.registerLazySingleton<CategoryRepository>(
    () => CategoryRepositoryImpl(
      remoteDatasource: sl<CategoryRemoteDatasource>(),
      localDatasource: sl<CategoryLocalDatasource>(),
      networkInfo: sl<NetworkInfo>(),
      syncQueue: sl<SyncQueue>(),
    ),
  );

  sl.registerLazySingleton<SaleRepository>(
    () => SaleRepositoryImpl(
      remoteDatasource: sl<SaleRemoteDatasource>(),
      localDatasource: sl<SaleLocalDatasource>(),
      networkInfo: sl<NetworkInfo>(),
      syncQueue: sl<SyncQueue>(),
    ),
  );

  sl.registerLazySingleton<CustomerRepository>(
    () => CustomerRepositoryImpl(
      remoteDatasource: sl<CustomerRemoteDatasource>(),
      networkInfo: sl<NetworkInfo>(),
      syncQueue: sl<SyncQueue>(),
    ),
  );

  sl.registerLazySingleton<DebtRepository>(
    () => DebtRepositoryImpl(
      dioClient: sl<DioClient>(),
      networkInfo: sl<NetworkInfo>(),
      syncQueue: sl<SyncQueue>(),
    ),
  );

  sl.registerLazySingleton<SupplierRepository>(
    () => SupplierRepositoryImpl(
      dioClient: sl<DioClient>(),
      networkInfo: sl<NetworkInfo>(),
      syncQueue: sl<SyncQueue>(),
    ),
  );

  sl.registerLazySingleton<StockRepository>(
    () => StockRepositoryImpl(
      dioClient: sl<DioClient>(),
      networkInfo: sl<NetworkInfo>(),
      syncQueue: sl<SyncQueue>(),
    ),
  );

  sl.registerLazySingleton<DashboardRepository>(
    () => DashboardRepositoryImpl(remoteDatasource: sl<DashboardRemoteDatasource>()),
  );

  sl.registerLazySingleton<FinanceRepository>(
    () => FinanceRepositoryImpl(remoteDatasource: sl<FinanceRemoteDatasource>()),
  );

  sl.registerLazySingleton<ExpenseRepository>(
    () => ExpenseRepositoryImpl(remoteDatasource: sl<ExpenseRemoteDatasource>()),
  );

  sl.registerLazySingleton<InvestmentRepository>(
    () => InvestmentRepositoryImpl(remoteDatasource: sl<InvestmentRemoteDatasource>()),
  );

  sl.registerLazySingleton<ZakatRepository>(
    () => ZakatRepositoryImpl(remoteDatasource: sl<ZakatRemoteDatasource>()),
  );

  sl.registerLazySingleton<StaffRepository>(
    () => StaffRepositoryImpl(remoteDatasource: sl<StaffRemoteDatasource>()),
  );

  sl.registerLazySingleton<ShiftRepository>(
    () => ShiftRepositoryImpl(
      remoteDatasource: sl<ShiftRemoteDatasource>(),
      networkInfo: sl<NetworkInfo>(),
      syncQueue: sl<SyncQueue>(),
    ),
  );

  sl.registerLazySingleton<PayrollRepository>(
    () => PayrollRepositoryImpl(remoteDatasource: sl<PayrollRemoteDatasource>()),
  );

  // ---------------------------------------------------------------------------
  // Blocs
  // ---------------------------------------------------------------------------

  sl.registerFactory<AuthBloc>(
    () => AuthBloc(authRepository: sl<AuthRepository>()),
  );

  sl.registerFactory<StoreBloc>(
    () => StoreBloc(storeRepository: sl<StoreRepository>()),
  );

  sl.registerFactory<ProductListBloc>(
    () => ProductListBloc(productRepository: sl<ProductRepository>()),
  );

  sl.registerFactory<CategoryBloc>(
    () => CategoryBloc(categoryRepository: sl<CategoryRepository>()),
  );

  sl.registerFactory<CartBloc>(
    () => CartBloc(persistence: sl<CartLocalDatasource>()),
  );

  sl.registerFactory<DashboardBloc>(
    () => DashboardBloc(dashboardRepository: sl<DashboardRepository>()),
  );

  sl.registerFactory<FinanceBloc>(
    () => FinanceBloc(financeRepository: sl<FinanceRepository>()),
  );

  sl.registerFactory<ExpenseBloc>(
    () => ExpenseBloc(expenseRepository: sl<ExpenseRepository>()),
  );

  sl.registerFactory<InvestmentBloc>(
    () => InvestmentBloc(investmentRepository: sl<InvestmentRepository>()),
  );

  sl.registerFactory<DebtBloc>(
    () => DebtBloc(
      dioClient: sl<DioClient>(),
      debtRepository: sl<DebtRepository>(),
      networkInfo: sl<NetworkInfo>(),
    ),
  );

  sl.registerFactory<ZakatBloc>(
    () => ZakatBloc(zakatRepository: sl<ZakatRepository>()),
  );

  sl.registerFactory<SettingsBloc>(
    () => SettingsBloc(dioClient: sl<DioClient>()),
  );

  sl.registerFactory<CustomerDetailBloc>(
    () => CustomerDetailBloc(dioClient: sl<DioClient>()),
  );

  sl.registerFactory<SupplierDetailBloc>(
    () => SupplierDetailBloc(dioClient: sl()),
  );

  sl.registerFactory<CustomerListBloc>(
    () => CustomerListBloc(customerRepository: sl<CustomerRepository>()),
  );

  sl.registerFactory<SupplierListBloc>(
    () => SupplierListBloc(supplierRepository: sl<SupplierRepository>()),
  );

  sl.registerFactory<StaffBloc>(
    () => StaffBloc(staffRepository: sl<StaffRepository>()),
  );

  sl.registerFactory<RolesBloc>(
    () => RolesBloc(staffRepository: sl<StaffRepository>()),
  );

  sl.registerFactory<ShiftBloc>(
    () => ShiftBloc(shiftRepository: sl<ShiftRepository>()),
  );

  sl.registerFactory<PayrollBloc>(
    () => PayrollBloc(payrollRepository: sl<PayrollRepository>()),
  );

  sl.registerFactory<StaffFormBloc>(
    () => StaffFormBloc(staffRepository: sl<StaffRepository>()),
  );

  sl.registerFactory<CheckoutBloc>(
    () => CheckoutBloc(saleRepository: sl<SaleRepository>()),
  );

  sl.registerFactory<SalesHistoryBloc>(
    () => SalesHistoryBloc(saleRepository: sl<SaleRepository>()),
  );

  sl.registerFactory<StockIntakeBloc>(
    () => StockIntakeBloc(
      stockRepository: sl<StockRepository>(),
      productRepository: sl<ProductRepository>(),
    ),
  );

  sl.registerFactory<ProductFormBloc>(
    () => ProductFormBloc(productRepository: sl<ProductRepository>()),
  );

  sl.registerFactory<ImportBloc>(
    () => ImportBloc(productDatasource: sl<ProductRemoteDatasource>()),
  );

  // ---------------------------------------------------------------------------
  // Services — Receipt, Printer, Notifications
  // ---------------------------------------------------------------------------

  sl.registerLazySingleton<ReceiptPdfService>(() => ReceiptPdfService());

  sl.registerLazySingleton<ThermalPrinterService>(() => ThermalPrinterService());

  sl.registerLazySingleton<ReceiptShareService>(
    () => ReceiptShareService(pdfService: sl<ReceiptPdfService>()),
  );

  sl.registerLazySingleton<NotificationService>(() => NotificationService());

  sl.registerLazySingleton<DebtReminderService>(
    () => DebtReminderService(notificationService: sl<NotificationService>()),
  );

  // ---------------------------------------------------------------------------
  // Blocs — Printer
  // ---------------------------------------------------------------------------

  sl.registerFactory<PrinterBloc>(
    () => PrinterBloc(printerService: sl<ThermalPrinterService>()),
  );

  sl.registerFactory<SubscriptionBloc>(
    () => SubscriptionBloc(dioClient: sl<DioClient>()),
  );

  sl.registerLazySingleton<LoyaltyRemoteDatasource>(
    () => LoyaltyRemoteDatasourceImpl(dioClient: sl<DioClient>()),
  );

  sl.registerLazySingleton<LoyaltyRepository>(
    () => LoyaltyRepositoryImpl(remote: sl<LoyaltyRemoteDatasource>()),
  );

  sl.registerFactory<LoyaltySettingsBloc>(
    () => LoyaltySettingsBloc(repository: sl<LoyaltyRepository>()),
  );
}

Future<Database> _initDatabase() async {
  final dbPath = await getDatabasesPath();
  final path = '$dbPath/dukonpro.db';

  return await openDatabase(
    path,
    version: 1,
    onCreate: (db, version) async {
      await ProductLocalDatasourceImpl.createTable(db);
      await SaleLocalDatasourceImpl.createTable(db);
      await CategoryLocalDatasourceImpl.createTable(db);
      await SyncQueue.createTable(db);
    },
  );
}
