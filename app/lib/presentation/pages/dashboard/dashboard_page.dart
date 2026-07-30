import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_extensions.dart';
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
import '../../widgets/common/app_error_widget.dart';
import '../../widgets/home/active_banner.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_shadows.dart';

class DashboardPage extends StatefulWidget {
  final ValueChanged<int>? onTabChange;
  final void Function({String? initialFilter})? onSwitchToProducts;

  const DashboardPage({
    super.key,
    this.onTabChange,
    this.onSwitchToProducts,
  });

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
        backgroundColor: context.bg,
        body: Column(
          children: [
            // Gradient Header
            _buildHeader(),
            // Active in-app banner (admin-targeted by plan/status), if any
            _buildActiveBanner(),
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
                    return AppErrorWidget(
                      message: state.message,
                      onRetry: _loadDashboard,
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
                          // Hero revenue card — overlaps the gradient header
                          Transform.translate(
                            offset: const Offset(0, -36),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: _HeroRevenueCard(
                                stats: stats,
                                period: _selectedPeriod,
                                formatPrice: _formatPrice,
                                onTap: () => context.push(
                                  '/sales/history',
                                  extra: _getStoreId(),
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(
                              left: AppConstants.spacingMd,
                              right: AppConstants.spacingMd,
                              bottom: AppConstants.spacingXl,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _build3UpMetrics(stats),
                                const SizedBox(height: 24),
                                _buildActionTiles(stats),
                                const SizedBox(height: 24),
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
          foregroundColor: context.onPrimary,
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
          onProfileTap: () => widget.onTabChange?.call(4),
          onStoreTap: stores.length > 1
              ? () => _showStoreSelector(stores, selectedStoreId)
              : null,
        );
      },
    );
  }

  Widget _buildActiveBanner() {
    return BlocBuilder<StoreBloc, StoreState>(
      builder: (context, state) {
        final storeId =
            state is StoreLoaded ? state.selectedStore?.id : null;
        if (storeId == null) return const SizedBox.shrink();
        return ActiveBanner(storeId: storeId);
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
                    : ctx.textSecondary,
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
          Semantics(
            label: 'Выбрать период',
            button: true,
            child: GestureDetector(
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
                constraints: const BoxConstraints(minHeight: 44),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _selectedPeriod == 'custom' ? AppColors.primary : context.surface,
                  borderRadius: BorderRadius.circular(AppConstants.radiusXl),
                  border: Border.all(
                    color: _selectedPeriod == 'custom' ? AppColors.primary : context.border,
                  ),
                ),
                child: Icon(Icons.calendar_today,
                  size: 16,
                  color: _selectedPeriod == 'custom' ? context.onPrimary : context.textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 3-up metric row: Прибыль (green) · Себестоимость (neutral) · Расходы (red).
  /// Revenue lives in the hero card above; avg check is shown inside the hero.
  Widget _build3UpMetrics(DashboardStats stats) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _MetricTile(
            label: 'Прибыль',
            value: _formatPrice(stats.todayProfit),
            accent: AppColors.success,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricTile(
            label: 'Себестоимость',
            value: _formatPrice(stats.todayCost),
            accent: AppColors.info,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricTile(
            label: 'Расходы',
            value: _formatPrice(stats.todayExpenses),
            accent: AppColors.error,
          ),
        ),
      ],
      ),
    );
  }

  /// Actionable list tiles — full-width rows with icon badge, title/subtitle,
  /// and a right-aligned value or chevron. Much more scannable than the
  /// previous horizontal strip of tiny cards.
  Widget _buildActionTiles(DashboardStats stats) {
    final hasCustomerDebt = stats.customerDebtsTotal > 0;
    final hasSupplierDebt = stats.supplierDebtsTotal > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 10),
          child: Text('Операции',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        ),
        _ActionTile(
          icon: Icons.inventory_2_outlined,
          accent: AppColors.primary,
          title: 'Остатки на складе',
          subtitle: stats.lowStockProducts > 0
              ? '${stats.totalProducts} товаров · ${stats.lowStockProducts} мало'
              : '${stats.totalProducts} товаров',
          subtitleColor: stats.lowStockProducts > 0
              ? AppColors.warning
              : context.textSecondary,
          onTap: () =>
              widget.onSwitchToProducts?.call(initialFilter: 'attention'),
        ),
        _ActionTile(
          icon: Icons.arrow_downward_rounded,
          accent: AppColors.success,
          title: 'Вам должны',
          subtitle: hasCustomerDebt
              ? 'Долги клиентов по продажам'
              : 'Нет активных долгов',
          trailingValue: hasCustomerDebt
              ? _formatPrice(stats.customerDebtsTotal)
              : null,
          trailingColor: AppColors.success,
          // BUG #30 (2026-05-11 final click test): the tile is the
          // "all customers who owe us" entry-point, NOT a single-
          // customer detail. Route to /debts (DebtsOverviewPage)
          // which has tabs for receivables vs payables. Previously
          // routed to /debts/customer which expects a customerId
          // (single-customer page) and showed an empty error.
          onTap: () => context.push(
            RouteNames.debtsOverview,
            extra: _getStoreId() ?? '',
          ),
        ),
        _ActionTile(
          icon: Icons.arrow_upward_rounded,
          accent: AppColors.error,
          title: 'Вы должны',
          subtitle: hasSupplierDebt
              ? 'Долги поставщикам'
              : 'Нет активных долгов',
          trailingValue: hasSupplierDebt
              ? _formatPrice(stats.supplierDebtsTotal)
              : null,
          trailingColor: AppColors.error,
          // BUG #30: same as "Вам должны" — route to /debts overview
          // which has both Нам должны / Мы должны tabs in one view.
          onTap: () => context.push(
            RouteNames.debtsOverview,
            extra: _getStoreId() ?? '',
          ),
        ),
        _ActionTile(
          icon: Icons.fact_check_outlined,
          accent: AppColors.info,
          title: 'Инвентаризация',
          subtitle: 'Проверить фактические остатки',
          onTap: () => context.push(RouteNames.inventoryCount, extra: _getStoreId()),
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
                child: Container(
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                  alignment: Alignment.center,
                  child: const Text('Все продажи >',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    )),
                ),
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
                    Text('Пока нет продаж',
                      style: TextStyle(color: context.textSecondary)),
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

// ─── Hero Revenue Card ─────────────────────────────────────────

class _HeroRevenueCard extends StatelessWidget {
  final DashboardStats stats;
  final String period;
  final String Function(double) formatPrice;
  final VoidCallback? onTap;

  const _HeroRevenueCard({
    required this.stats,
    required this.period,
    required this.formatPrice,
    this.onTap,
  });

  String get _periodLabel {
    switch (period) {
      case 'week':
        return 'Выручка за неделю';
      case 'month':
        return 'Выручка за месяц';
      case 'custom':
        return 'Выручка за период';
      default:
        return 'Выручка сегодня';
    }
  }

  @override
  Widget build(BuildContext context) {
    final avgCheck = stats.todaySalesCount > 0
        ? stats.todayRevenue / stats.todaySalesCount
        : 0.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          decoration: BoxDecoration(
            gradient: AppGradients.primaryFull,
            borderRadius: BorderRadius.circular(AppConstants.radiusLg),
            boxShadow: AppShadows.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    _periodLabel,
                    style: const TextStyle(
                      color: Color(0xCCFFFFFF),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.chevron_right,
                    size: 20, color: Color(0xCCFFFFFF)),
                ],
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  formatPrice(stats.todayRevenue),
                  style: TextStyle(
                    color: context.onPrimary,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    height: 1.0,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _HeroMeta(
                    icon: Icons.receipt_long_outlined,
                    label: '${stats.todaySalesCount} продаж',
                  ),
                  const SizedBox(width: 16),
                  _HeroMeta(
                    icon: Icons.payments_outlined,
                    label: 'Средний чек ${formatPrice(avgCheck)}',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroMeta extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeroMeta({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xCCFFFFFF)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xE6FFFFFF),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Metric Tile ───────────────────────────────────────────────

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 16,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: context.textSecondary,
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: accent,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Action Tile ───────────────────────────────────────────────

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final Color? subtitleColor;
  final String? trailingValue;
  final Color? trailingColor;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    this.subtitleColor,
    this.trailingValue,
    this.trailingColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: context.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                  ),
                  child: Icon(icon, size: 20, color: accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: subtitleColor ?? context.textSecondary,
                          fontWeight: subtitleColor != null
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailingValue != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    trailingValue!,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: trailingColor ?? context.textPrimary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
                const SizedBox(width: 4),
                Icon(Icons.chevron_right,
                  size: 20, color: context.textMuted),
              ],
            ),
          ),
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
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
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
                  style: TextStyle(
                    fontSize: 12, color: context.textSecondary),
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
