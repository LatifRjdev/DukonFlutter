import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../blocs/store/store_bloc.dart';
import '../../blocs/store/store_event.dart';
import '../../blocs/store/store_state.dart';
import '../../widgets/common/app_bottom_nav_bar.dart';
import '../dashboard/dashboard_page.dart';
import '../dashboard/more_page.dart';
import '../product/product_list_page.dart';
import '../pos/pos_checkout_page.dart';
import '../finance/finance_dashboard_page.dart';
import 'cart_restore_prompt.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  // BUG #26: when the dashboard "Остатки на складе" tile is tapped we
  // switch to the products tab AND apply a preset filter. The preset
  // is consumed once on next build of ProductListPage.
  String? _productsInitialFilter;

  void _switchToProducts({String? initialFilter}) {
    setState(() {
      _currentIndex = 1; // products tab index
      _productsInitialFilter = initialFilter;
    });
    // Reset on next frame so ProductListPage.initState (which reads
    // widget.initialFilter once) has consumed it. Keeps the field
    // honestly "consumed once" — a future refactor that destroys and
    // rebuilds ProductListPage won't surprise the user with a stale
    // pre-filter.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _productsInitialFilter = null);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    // Load stores on app startup — required for all API calls
    context.read<StoreBloc>().add(StoreLoadRequested());
    // E.4 follow-up: ask the cashier whether to restore a persisted
    // cart from the previous session. Post-frame so BlocProvider
    // ancestors are mounted before we read<CartBloc>().
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) CartRestorePrompt.showIfNeeded(context);
    });
  }

  void _onTabChange(int index) {
    setState(() {
      _currentIndex = index;
      _productsInitialFilter = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardPage(
        onTabChange: _onTabChange,
        onSwitchToProducts: _switchToProducts,
      ),
      ProductListPage(initialFilter: _productsInitialFilter),
      const PosCheckoutPage(),
      const FinanceDashboardPage(),
      const MorePage(),
    ];

    return BlocListener<StoreBloc, StoreState>(
      listener: (context, state) {
        if (state is StoreInitial) {
          // After logout/reset, reload stores for new user
          context.read<StoreBloc>().add(StoreLoadRequested());
          return;
        }
        if (state is StoreLoaded && state.stores.isEmpty) {
          context.go('/create-store');
          return;
        }
        if (state is StoreLoaded && state.selectedStore != null) {
          setState(() {});
        }
      },
      child: Scaffold(
        // Offline banner is mounted globally in MaterialApp.builder so it
        // also shows on push'd routes (Оплата, success, settings…). Don't
        // re-add it here.
        body: IndexedStack(
          index: _currentIndex,
          children: pages,
        ),
        bottomNavigationBar: AppBottomNavBar(
          currentIndex: _currentIndex,
          onTap: _onTabChange,
        ),
      ),
    );
  }
}
