import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../blocs/store/store_bloc.dart';
import '../../blocs/store/store_event.dart';
import '../../blocs/store/store_state.dart';
import '../../widgets/common/app_bottom_nav_bar.dart';
import '../../widgets/common/offline_banner.dart';
import '../dashboard/dashboard_page.dart';
import '../dashboard/more_page.dart';
import '../product/product_list_page.dart';
import '../pos/pos_checkout_page.dart';
import '../finance/finance_dashboard_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Load stores on app startup — required for all API calls
    context.read<StoreBloc>().add(StoreLoadRequested());
  }

  void _onTabChange(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardPage(onTabChange: _onTabChange),
      const ProductListPage(),
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
        body: Column(
          children: [
            const OfflineBanner(),
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: pages,
              ),
            ),
          ],
        ),
        bottomNavigationBar: AppBottomNavBar(
          currentIndex: _currentIndex,
          onTap: _onTabChange,
        ),
      ),
    );
  }
}
