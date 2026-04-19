import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/router/route_names.dart';
import '../../blocs/store/store_bloc.dart';
import '../../blocs/store/store_state.dart';

class MorePage extends StatelessWidget {
  const MorePage({super.key});

  String _getStoreId(BuildContext context) {
    final storeState = context.read<StoreBloc>().state;
    if (storeState is StoreLoaded && storeState.selectedStore != null) {
      return storeState.selectedStore!.id;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ещё'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _SectionHeader(title: 'Продажи и Финансы'),
          _MenuItem(
            icon: Icons.receipt_long,
            label: 'История продаж',
            color: AppColors.info,
            onTap: () => context.push('/sales/history', extra: _getStoreId(context)),
          ),
          _MenuItem(
            icon: Icons.analytics_outlined,
            label: 'Финансы',
            color: AppColors.primary,
            onTap: () => context.push(RouteNames.financeDashboard, extra: _getStoreId(context)),
          ),
          _MenuItem(
            icon: Icons.money_off_outlined,
            label: 'Расходы',
            color: AppColors.error,
            onTap: () => context.push(RouteNames.expenses, extra: _getStoreId(context)),
          ),
          _MenuItem(
            icon: Icons.account_balance_outlined,
            label: 'Долги',
            color: AppColors.warning,
            onTap: () => context.push(RouteNames.debtsOverview, extra: _getStoreId(context)),
          ),
          _MenuItem(
            icon: Icons.volunteer_activism_outlined,
            label: 'Закят',
            color: AppColors.success,
            onTap: () => context.push(RouteNames.zakatCalculator, extra: _getStoreId(context)),
          ),
          const Divider(height: 24),
          _SectionHeader(title: 'Персонал'),
          _MenuItem(
            icon: Icons.people_outlined,
            label: 'Сотрудники',
            color: AppColors.info,
            onTap: () => context.push(RouteNames.staffList, extra: _getStoreId(context)),
          ),
          _MenuItem(
            icon: Icons.access_time_outlined,
            label: 'Смены',
            color: AppColors.primary,
            onTap: () => context.push(RouteNames.shifts, extra: _getStoreId(context)),
          ),
          _MenuItem(
            icon: Icons.payments_outlined,
            label: 'Зарплата',
            color: AppColors.success,
            onTap: () => context.push(RouteNames.payroll, extra: _getStoreId(context)),
          ),
          _MenuItem(
            icon: Icons.admin_panel_settings_outlined,
            label: 'Роли и права',
            color: AppColors.warning,
            onTap: () => context.push(RouteNames.roles, extra: _getStoreId(context)),
          ),
          const Divider(height: 24),
          _SectionHeader(title: 'Контрагенты'),
          _MenuItem(
            icon: Icons.people_outlined,
            label: 'Клиенты',
            color: AppColors.primary,
            onTap: () => context.push(RouteNames.customerList, extra: _getStoreId(context)),
          ),
          _MenuItem(
            icon: Icons.local_shipping_outlined,
            label: 'Поставщики',
            color: AppColors.primary,
            onTap: () => context.push(RouteNames.supplierList, extra: _getStoreId(context)),
          ),
          const Divider(height: 24),
          _SectionHeader(title: 'Магазин'),
          _MenuItem(
            icon: Icons.store_outlined,
            label: 'Мои магазины',
            color: AppColors.primary,
            onTap: () => context.push(RouteNames.myStores),
          ),
          const Divider(height: 24),
          _SectionHeader(title: 'Настройки'),
          _MenuItem(
            icon: Icons.settings_outlined,
            label: 'Настройки',
            color: context.textSecondary,
            onTap: () => context.push(RouteNames.settings),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: context.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: Icon(Icons.chevron_right, color: context.textSecondary),
      onTap: onTap,
    );
  }
}
