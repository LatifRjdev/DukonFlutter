import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'l10n/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'injection.dart';
import 'presentation/blocs/auth/auth_bloc.dart';
import 'presentation/blocs/store/store_bloc.dart';
import 'presentation/blocs/pos/cart_bloc.dart';
import 'presentation/blocs/dashboard/dashboard_bloc.dart';
import 'presentation/blocs/product/product_list_bloc.dart';
import 'presentation/blocs/product/product_form_bloc.dart';
import 'presentation/blocs/category/category_bloc.dart';
import 'presentation/blocs/pos/checkout_bloc.dart';
import 'presentation/blocs/sales/sales_history_bloc.dart';
import 'presentation/blocs/stock/stock_intake_bloc.dart';
import 'presentation/blocs/finance/finance_bloc.dart';
import 'presentation/blocs/expense/expense_bloc.dart';
import 'presentation/blocs/debt/debt_bloc.dart';
import 'presentation/blocs/zakat/zakat_bloc.dart';
import 'presentation/blocs/settings/settings_bloc.dart';
import 'presentation/blocs/customer_detail/customer_detail_bloc.dart';
import 'presentation/blocs/customer/customer_list_bloc.dart';
import 'presentation/blocs/supplier/supplier_list_bloc.dart';
import 'presentation/blocs/staff/staff_bloc.dart';
import 'presentation/blocs/roles/roles_bloc.dart';
import 'presentation/blocs/shift/shift_bloc.dart';
import 'presentation/blocs/payroll/payroll_bloc.dart';
import 'presentation/blocs/staff_form/staff_form_bloc.dart';
import 'presentation/blocs/printer/printer_bloc.dart';
class DokonProApp extends StatelessWidget {
  const DokonProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<AuthBloc>()),
        BlocProvider(create: (_) => sl<StoreBloc>()),
        BlocProvider(create: (_) => sl<CartBloc>()),
        BlocProvider(create: (_) => sl<DashboardBloc>()),
        BlocProvider(create: (_) => sl<ProductListBloc>()),
        BlocProvider(create: (_) => sl<ProductFormBloc>()),
        BlocProvider(create: (_) => sl<CategoryBloc>()),
        BlocProvider(create: (_) => sl<CheckoutBloc>()),
        BlocProvider(create: (_) => sl<SalesHistoryBloc>()),
        BlocProvider(create: (_) => sl<StockIntakeBloc>()),
        BlocProvider(create: (_) => sl<FinanceBloc>()),
        BlocProvider(create: (_) => sl<ExpenseBloc>()),
        BlocProvider(create: (_) => sl<DebtBloc>()),
        BlocProvider(create: (_) => sl<ZakatBloc>()),
        BlocProvider(create: (_) => sl<SettingsBloc>()),
        BlocProvider(create: (_) => sl<CustomerDetailBloc>()),
        BlocProvider(create: (_) => sl<CustomerListBloc>()),
        BlocProvider(create: (_) => sl<SupplierListBloc>()),
        BlocProvider(create: (_) => sl<StaffBloc>()),
        BlocProvider(create: (_) => sl<RolesBloc>()),
        BlocProvider(create: (_) => sl<ShiftBloc>()),
        BlocProvider(create: (_) => sl<PayrollBloc>()),
        BlocProvider(create: (_) => sl<StaffFormBloc>()),
        BlocProvider(create: (_) => sl<PrinterBloc>()),
      ],
      child: MaterialApp.router(
        title: 'DokonPro',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.system,
        routerConfig: AppRouter.router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ru'),
      ),
    );
  }
}
