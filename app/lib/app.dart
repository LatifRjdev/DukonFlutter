import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'l10n/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'injection.dart';
import 'presentation/widgets/common/offline_banner.dart';
import 'presentation/blocs/auth/auth_bloc.dart';
import 'presentation/blocs/auth/auth_event.dart';
import 'presentation/blocs/auth/auth_state.dart';
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
import 'presentation/blocs/settings/settings_event.dart';
import 'presentation/blocs/settings/settings_state.dart';
import 'presentation/blocs/customer_detail/customer_detail_bloc.dart';
import 'presentation/blocs/customer/customer_list_bloc.dart';
import 'presentation/blocs/supplier/supplier_list_bloc.dart';
import 'presentation/blocs/staff/staff_bloc.dart';
import 'presentation/blocs/roles/roles_bloc.dart';
import 'presentation/blocs/shift/shift_bloc.dart';
import 'presentation/blocs/payroll/payroll_bloc.dart';
import 'presentation/blocs/staff_form/staff_form_bloc.dart';
import 'presentation/blocs/printer/printer_bloc.dart';
import 'presentation/blocs/subscription/subscription_bloc.dart';
import 'presentation/blocs/loyalty/loyalty_settings_bloc.dart';

class DukonProApp extends StatelessWidget {
  const DukonProApp({super.key, this.locale = const Locale('ru')});

  /// SPEC.md #14 — the language saved via the language settings screen,
  /// resolved by `main.dart`'s `loadSavedLocale()` before `runApp`. Defaults
  /// to Russian so any other caller (tests, previews) that omits it keeps
  /// the previous hardcoded behavior.
  final Locale locale;

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
        BlocProvider(
          create: (_) => sl<SettingsBloc>()..add(SettingsProfileRequested()),
        ),
        BlocProvider(create: (_) => sl<CustomerDetailBloc>()),
        BlocProvider(create: (_) => sl<CustomerListBloc>()),
        BlocProvider(create: (_) => sl<SupplierListBloc>()),
        BlocProvider(create: (_) => sl<StaffBloc>()),
        BlocProvider(create: (_) => sl<RolesBloc>()),
        BlocProvider(create: (_) => sl<ShiftBloc>()),
        BlocProvider(create: (_) => sl<PayrollBloc>()),
        BlocProvider(create: (_) => sl<StaffFormBloc>()),
        BlocProvider(create: (_) => sl<PrinterBloc>()),
        BlocProvider(create: (_) => sl<SubscriptionBloc>()),
        BlocProvider(create: (_) => sl<LoyaltySettingsBloc>()),
      ],
      child: _AuthLifecycleWatcher(
        child: BlocBuilder<SettingsBloc, SettingsState>(
        buildWhen: (prev, curr) {
          // Only react to SettingsLoaded state transitions with a real
          // themeMode change. Transient states (Loading, ActionSuccess,
          // Error) must not trigger a rebuild — that was causing the
          // MaterialApp.router to reset navigation back to splash.
          if (curr is! SettingsLoaded) return false;
          final prevTheme = prev is SettingsLoaded ? prev.themeMode : null;
          return prevTheme != curr.themeMode;
        },
        builder: (context, state) {
          final themeMode =
              state is SettingsLoaded ? state.themeMode : ThemeMode.system;
          return MaterialApp.router(
            title: 'DukonPro',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: themeMode,
            routerConfig: AppRouter.router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: locale,
            // Stack the offline banner above every route so sub-pages
            // (Оплата наличными, success, settings, …) keep showing it
            // when connectivity drops mid-flow. Previously the banner
            // lived only on the HomePage Scaffold.
            builder: (context, child) {
              return MediaQuery(
                data: MediaQuery.of(context),
                child: SafeArea(
                  top: false,
                  bottom: false,
                  child: Column(
                    children: [
                      const OfflineBanner(),
                      Expanded(child: child ?? const SizedBox.shrink()),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      ),
    );
  }
}

/// Pings `GET /users/me` whenever the app returns to the foreground
/// (`AppLifecycleState.resumed`) so that server-side token revocation —
/// e.g. the user changed their password from another device while the
/// app was in the background — is detected immediately and the router
/// redirects to /login, instead of the dashboard staying stale until
/// the next outbound API call surfaces a 401.
///
/// Lives inside [MultiBlocProvider] so [context.read<AuthBloc>] resolves
/// to the same instance the rest of the UI uses, regardless of whether
/// the bloc is registered as a factory or a singleton in GetIt.
class _AuthLifecycleWatcher extends StatefulWidget {
  const _AuthLifecycleWatcher({required this.child});

  final Widget child;

  @override
  State<_AuthLifecycleWatcher> createState() => _AuthLifecycleWatcherState();
}

class _AuthLifecycleWatcherState extends State<_AuthLifecycleWatcher>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (!mounted) return;
    final auth = context.read<AuthBloc>();
    // Skip the round-trip unless we currently believe we're logged in —
    // a logged-out splash / login screen has nothing to verify.
    if (auth.state is AuthAuthenticated) {
      auth.add(AuthVerifyRequested());
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
