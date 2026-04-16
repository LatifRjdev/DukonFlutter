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
import '../../widgets/common/gradient_header.dart';
import '../../widgets/common/glass_card.dart';
import '../../widgets/common/app_chip.dart';

class DashboardPage extends StatefulWidget {
  final ValueChanged<int>? onTabChange;

  const DashboardPage({super.key, this.onTabChange});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _loaded = false;
  String _selectedPeriod = 'today';
  DateTimeRange? _customDateRange;

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
        backgroundColor: AppColors.lightBackground,
        body: Column(
          children: [
            // Gradient Header
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Overlapping stat cards
                          Transform.translate(
                            offset: const Offset(0, -36),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: GlassCard(
                                      onTap: () => context.push('/sales/history', extra: _getStoreId()),
                                      padding: const EdgeInsets.all(14),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(Icons.trending_up, size: 18, color: AppColors.lightTextPrimary),
                                              const Spacer(),
                                              const Icon(Icons.chevron_right, size: 18, color: AppColors.lightTextSecondary),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            _formatPrice(stats.todayRevenue),
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.lightTextPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          const Text('Продажи',
                                            style: TextStyle(fontSize: 12, color: AppColors.lightTextSecondary)),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: GlassCard(
                                      padding: const EdgeInsets.all(14),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Icon(Icons.account_balance_wallet_outlined, size: 18, color: AppColors.success),
                                          const SizedBox(height: 8),
                                          Text(
                                            _formatPrice(stats.todayProfit),
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.success,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          const Text('Чистая прибыль',
                                            style: TextStyle(fontSize: 12, color: AppColors.lightTextSecondary)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Main content with negative top margin to account for overlap
                          Padding(
                            padding: const EdgeInsets.only(
                              left: AppConstants.spacingMd,
                              right: AppConstants.spacingMd,
                              bottom: AppConstants.spacingMd,
                            ),
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
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
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
    return BlocBuilder<StoreBloc, StoreState>(
      builder: (context, state) {
        String storeName = 'DukonPro';
        List stores = [];
        String? selectedStoreId;

        if (state is StoreLoaded) {
          stores = state.stores;
          storeName = state.selectedStore?.name ?? 'Магазин';
          selectedStoreId = state.selectedStore?.id;
        }

        return GradientHeader(
          greeting: 'Салом 👋',
          userName: storeName,
          storeName: storeName,
          onNotificationTap: () {
            context.push('/notifications', extra: _getStoreId());
          },
          onProfileTap: () => context.push(RouteNames.settings),
          onStoreTap: stores.length > 1
              ? () => _showStoreSelector(stores, selectedStoreId)
              : null,
        );
      },
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
                    : AppColors.lightTextSecondary,
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
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: AppChip(
                label: p['label']!,
                isSelected: _selectedPeriod == p['key'],
                onTap: () => _onPeriodChanged(p['key']!),
              ),
            );
          }),
          GestureDetector(
            onTap: () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2024),
                lastDate: DateTime.now(),
                initialDateRange: _customDateRange,
                locale: const Locale('ru'),
              );
              if (picked != null && mounted) {
                setState(() {
                  _selectedPeriod = 'custom';
                  _customDateRange = picked;
                });
                final storeId = _getStoreId();
                if (storeId != null) {
                  context.read<DashboardBloc>().add(
                    DashboardPeriodChanged(storeId, 'custom'),
                  );
                }
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _selectedPeriod == 'custom' ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _selectedPeriod == 'custom' ? AppColors.primary : AppColors.lightBorder,
                ),
              ),
              child: Icon(Icons.calendar_today,
                size: 16,
                color: _selectedPeriod == 'custom' ? Colors.white : AppColors.lightTextSecondary),
            ),
          ),
        ],
      ),
    );
  }

  /// 4 KPI cards 2x2 per mockup: Продажи, Себестоимость, Расходы (red), Средний чек.
  /// "Чистая прибыль" intentionally lives only in the hero header above this
  /// grid — previously it was rendered twice (FD-P1-002).
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
                valueColor: AppColors.lightTextPrimary,
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
                valueColor: AppColors.lightTextPrimary,
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
                title: 'Средний чек',
                value: _formatPrice(
                  stats.todaySalesCount > 0
                      ? stats.todayRevenue / stats.todaySalesCount
                      : 0,
                ),
                icon: Icons.receipt_long_outlined,
                valueColor: AppColors.lightTextPrimary,
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
                  context.push(RouteNames.inventoryCount, extra: _getStoreId());
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
                      style: TextStyle(color: AppColors.lightTextSecondary)),
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
                const Icon(Icons.chevron_right, size: 18, color: AppColors.lightTextSecondary),
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
            style: const TextStyle(fontSize: 12, color: AppColors.lightTextSecondary)),
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
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: SizedBox(
        width: 96,
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
                color: AppColors.lightTextPrimary,
              ),
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(subtitle,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: subtitleColor ?? AppColors.lightTextSecondary,
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

    return GlassCard(
      elevated: true,
      onTap: () => context.push('/sales/${sale.id}'),
      padding: const EdgeInsets.all(10),
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
                    fontSize: 12, color: AppColors.lightTextSecondary),
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
