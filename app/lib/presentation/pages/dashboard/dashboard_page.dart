import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/router/route_names.dart';
import '../../../domain/entities/sale.dart';
import '../../blocs/dashboard/dashboard_bloc.dart';
import '../../blocs/dashboard/dashboard_event.dart';
import '../../blocs/dashboard/dashboard_state.dart';
import '../../blocs/store/store_bloc.dart';
import '../../blocs/store/store_event.dart';
import '../../blocs/store/store_state.dart';
import '../../widgets/common/app_card.dart';

class DashboardPage extends StatefulWidget {
  final ValueChanged<int>? onTabChange;

  const DashboardPage({super.key, this.onTabChange});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _loaded = false;
  String _selectedPeriod = 'today';

  static const _periods = [
    {'key': 'today', 'label': 'Сегодня'},
    {'key': 'week', 'label': 'Неделя'},
    {'key': 'month', 'label': 'Месяц'},
  ];

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  String? _getStoreId() {
    final storeState = context.read<StoreBloc>().state;
    if (storeState is StoreLoaded && storeState.selectedStore != null) {
      return storeState.selectedStore!.id;
    }
    return null;
  }

  void _loadDashboard() {
    final storeId = _getStoreId();
    if (storeId != null) {
      _loaded = true;
      context.read<DashboardBloc>().add(
        DashboardLoadRequested(storeId, period: _selectedPeriod),
      );
    }
  }

  void _onPeriodChanged(String period) {
    setState(() => _selectedPeriod = period);
    final storeId = _getStoreId();
    if (storeId != null) {
      context.read<DashboardBloc>().add(
        DashboardPeriodChanged(storeId, period),
      );
    }
  }

  String _formatPrice(double value) {
    final formatter = NumberFormat('#,##0', 'ru');
    return '${formatter.format(value)} TJS';
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<StoreBloc, StoreState>(
      listener: (context, state) {
        if (state is StoreLoaded && !_loaded) {
          _loadDashboard();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(),
              // Period tabs
              _buildPeriodTabs(),
              // Content
              Expanded(
                child: BlocBuilder<DashboardBloc, DashboardState>(
                  builder: (context, state) {
                    if (state is DashboardLoading) {
                      return const Center(
                        child: CircularProgressIndicator(color: AppColors.primary),
                      );
                    }

                    if (state is DashboardError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                            const SizedBox(height: 16),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32),
                              child: Text(state.message, textAlign: TextAlign.center),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadDashboard,
                              child: const Text('Повторить'),
                            ),
                          ],
                        ),
                      );
                    }

                    final stats = state is DashboardLoaded
                        ? state.stats
                        : const DashboardStats();

                    return RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: () async {
                        final storeId = _getStoreId();
                        if (storeId != null) {
                          context.read<DashboardBloc>().add(
                            DashboardRefreshRequested(storeId, period: _selectedPeriod),
                          );
                        }
                      },
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(AppConstants.spacingMd),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildKpiCards(stats),
                            const SizedBox(height: 20),
                            _buildQuickActionsSection(stats),
                            const SizedBox(height: 20),
                            _buildRecentSalesSection(stats),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => widget.onTabChange?.call(2),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: const Text('Новая продажа',
            style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          // Store selector dropdown
          BlocBuilder<StoreBloc, StoreState>(
            builder: (context, state) {
              if (state is StoreLoaded) {
                final stores = state.stores;
                final selected = state.selectedStore;
                return GestureDetector(
                  onTap: stores.length > 1
                      ? () => _showStoreSelector(stores, selected?.id)
                      : null,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.store_outlined,
                          size: 18, color: AppColors.primary),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        selected?.name ?? 'Магазин',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (stores.length > 1)
                        const Icon(Icons.keyboard_arrow_down,
                          color: AppColors.textSecondary),
                    ],
                  ),
                );
              }
              return const Text('DokonPro',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700));
            },
          ),
          const Spacer(),
          // Notification bell with badge
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined,
                  color: AppColors.textPrimary),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Уведомления скоро появятся')),
                  );
                },
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: const Center(
                    child: Text('3',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showStoreSelector(List stores, String? selectedId) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Выберите магазин',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            ...stores.map((store) => ListTile(
              leading: Icon(
                store.id == selectedId
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: store.id == selectedId
                    ? AppColors.primary
                    : AppColors.textSecondary,
              ),
              title: Text(store.name),
              onTap: () {
                context.read<StoreBloc>().add(StoreSelected(store.id));
                Navigator.pop(ctx);
                _loadDashboard();
              },
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          ..._periods.map((p) {
            final isActive = _selectedPeriod == p['key'];
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => _onPeriodChanged(p['key']!),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: isActive
                        ? null
                        : Border.all(color: AppColors.divider),
                  ),
                  child: Text(
                    p['label']!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isActive ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            );
          }),
          GestureDetector(
            onTap: () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2024),
                lastDate: DateTime.now(),
                locale: const Locale('ru'),
              );
              if (picked != null) {
                // Custom date range — for now reload with 'month'
                _onPeriodChanged('month');
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.divider),
              ),
              child: const Icon(Icons.calendar_today,
                size: 16, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  /// 4 KPI cards 2x2 per mockup: Продажи, Себестоимость, Расходы (red), Чистая прибыль (green)
  Widget _buildKpiCards(DashboardStats stats) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                title: 'Продажи',
                value: _formatPrice(stats.todayRevenue),
                icon: Icons.trending_up,
                valueColor: AppColors.textPrimary,
                showArrow: true,
                onTap: () => context.push('/sales/history', extra: _getStoreId()),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _KpiCard(
                title: 'Себестоимость',
                value: _formatPrice(stats.todayCost),
                icon: Icons.inventory_2_outlined,
                valueColor: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                title: 'Расходы',
                value: _formatPrice(stats.todayExpenses),
                icon: Icons.arrow_downward,
                valueColor: AppColors.error,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _KpiCard(
                title: 'Чистая прибыль',
                value: _formatPrice(stats.todayProfit),
                icon: Icons.account_balance_wallet_outlined,
                valueColor: AppColors.success,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Quick actions — horizontal scroll: Остатки, Долги поставщикам, Долги клиентов, Инвентаризация
  Widget _buildQuickActionsSection(DashboardStats stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Быстрые действия',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _QuickActionCard(
                icon: Icons.inventory_2_outlined,
                label: 'Остатки',
                subtitle: '${stats.totalProducts} товаров',
                color: AppColors.primary,
                onTap: () => widget.onTabChange?.call(1),
              ),
              const SizedBox(width: 12),
              _QuickActionCard(
                icon: Icons.arrow_upward,
                label: 'Долги\nпоставщикам',
                subtitle: stats.supplierDebtsTotal > 0
                    ? '-${_formatPrice(stats.supplierDebtsTotal)}'
                    : '0 TJS',
                subtitleColor: AppColors.error,
                color: AppColors.error,
                onTap: () => context.push(RouteNames.supplierDebts, extra: _getStoreId()),
              ),
              const SizedBox(width: 12),
              _QuickActionCard(
                icon: Icons.arrow_downward,
                label: 'Долги\nклиентов',
                subtitle: stats.customerDebtsTotal > 0
                    ? '+${_formatPrice(stats.customerDebtsTotal)}'
                    : '0 TJS',
                subtitleColor: AppColors.success,
                color: AppColors.success,
                onTap: () => context.push(RouteNames.customerDebts, extra: _getStoreId()),
              ),
              const SizedBox(width: 12),
              _QuickActionCard(
                icon: Icons.fact_check_outlined,
                label: 'Инвента-\nризация',
                subtitle: '',
                color: AppColors.info,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Инвентаризация скоро появится')),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Recent sales — 2 cards + "Все продажи >"
  Widget _buildRecentSalesSection(DashboardStats stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Последние продажи',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            if (stats.recentSales.isNotEmpty)
              GestureDetector(
                onTap: () => context.push('/sales/history', extra: _getStoreId()),
                child: const Text('Все продажи >',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  )),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (stats.recentSales.isEmpty)
          AppCard(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.receipt_long, size: 48, color: AppColors.disabled),
                    const SizedBox(height: 8),
                    const Text('Пока нет продаж',
                      style: TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ),
          )
        else
          ...stats.recentSales.take(2).map((sale) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _SaleCard(sale: sale),
          )),
      ],
    );
  }
}

// ─── KPI Card ──────────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color valueColor;
  final bool showArrow;
  final VoidCallback? onTap;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.valueColor,
    this.showArrow = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: valueColor),
              const Spacer(),
              if (showArrow)
                const Icon(Icons.chevron_right, size: 18, color: AppColors.textSecondary),
            ],
          ),
          const SizedBox(height: 8),
          Text(value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(title,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

// ─── Quick Action Card ─────────────────────────────────────────

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color? subtitleColor;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    this.subtitleColor,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(height: 8),
            Text(label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(subtitle,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: subtitleColor ?? AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Sale Card ─────────────────────────────────────────────────

class _SaleCard extends StatelessWidget {
  final Sale sale;

  const _SaleCard({required this.sale});

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('HH:mm');
    final formatter = NumberFormat('#,##0', 'ru');

    final paymentLabel = switch (sale.paymentType) {
      'CASH' => 'Наличные',
      'CARD' => 'Карта',
      'DEBT' => 'В долг',
      _ => sale.paymentType,
    };

    return AppCard(
      onTap: () => context.push('/sales/${sale.id}'),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.receipt_outlined,
              size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Чек #${sale.receiptNo}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 2),
                Text(
                  '${timeFormat.format(sale.createdAt)} · $paymentLabel',
                  style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Text('${formatter.format(sale.total)} TJS',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
            )),
        ],
      ),
    );
  }
}
