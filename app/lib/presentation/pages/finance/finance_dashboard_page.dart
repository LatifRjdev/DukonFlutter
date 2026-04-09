import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/constants/app_colors.dart';
import '../../blocs/finance/finance_bloc.dart';
import '../../blocs/finance/finance_event.dart';
import '../../blocs/finance/finance_state.dart';
import '../../blocs/store/store_bloc.dart';
import '../../blocs/store/store_state.dart';

class FinanceDashboardPage extends StatefulWidget {
  final String? storeId;
  const FinanceDashboardPage({super.key, this.storeId});
  @override
  State<FinanceDashboardPage> createState() => _FinanceDashboardPageState();
}

class _FinanceDashboardPageState extends State<FinanceDashboardPage> {
  String _period = 'month';
  bool _loaded = false;

  String? get _storeId {
    if (widget.storeId != null && widget.storeId!.isNotEmpty) return widget.storeId;
    final storeState = context.read<StoreBloc>().state;
    return storeState is StoreLoaded ? storeState.selectedStore?.id : null;
  }

  String _formatPrice(double value) {
    final formatter = NumberFormat('#,##0', 'ru');
    return '${formatter.format(value)} TJS';
  }

  @override
  void initState() {
    super.initState();
    _loadFinance();
  }

  void _loadFinance() {
    final id = _storeId;
    if (id != null) {
      _loaded = true;
      context.read<FinanceBloc>().add(FinanceDashboardRequested(storeId: id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<StoreBloc, StoreState>(
      listener: (context, state) {
        if (state is StoreLoaded && !_loaded) {
          _loadFinance();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                child: Row(
                  children: [
                    const Text('Финансы',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.file_download_outlined),
                      onPressed: () {},
                    ),
                  ],
                ),
              ),

              Expanded(
                child: BlocBuilder<FinanceBloc, FinanceState>(
                  builder: (context, state) {
                    if (state is FinanceLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (state is FinanceError) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(state.message, style: const TextStyle(color: AppColors.error)),
                            const SizedBox(height: 16),
                            TextButton(onPressed: _loadFinance, child: const Text('Повторить')),
                          ],
                        ),
                      );
                    }
                    if (state is FinanceLoaded) {
                      final s = state.summary;
                      return RefreshIndicator(
                        onRefresh: () async => _loadFinance(),
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Sections grid
                              _buildSectionsGrid(),
                              const SizedBox(height: 16),

                              // Period tabs
                              SizedBox(
                                height: 36,
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  children: [
                                    _periodChip('День', 'day'),
                                    const SizedBox(width: 8),
                                    _periodChip('Неделя', 'week'),
                                    const SizedBox(width: 8),
                                    _periodChip('Месяц', 'month'),
                                    const SizedBox(width: 8),
                                    _periodChip('6 мес', 'half_year'),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // 4 KPI cards 2x2
                              Row(
                                children: [
                                  Expanded(
                                    child: _KpiCard(
                                      label: 'Общий доход',
                                      value: _formatPrice(s.totalIncome),
                                      bgColor: const Color(0xFFE0F7FA),
                                      textColor: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _KpiCard(
                                      label: 'Общие расходы',
                                      value: _formatPrice(s.totalExpenses),
                                      bgColor: const Color(0xFFFCE4EC),
                                      textColor: AppColors.error,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _KpiCard(
                                      label: 'Валовая прибыль',
                                      value: _formatPrice(s.profit),
                                      bgColor: const Color(0xFFFFF3E0),
                                      textColor: const Color(0xFFFF9800),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _KpiCard(
                                      label: 'Чистая прибыль',
                                      value: _formatPrice(s.profit - s.totalExpenses),
                                      bgColor: const Color(0xFFE8F5E9),
                                      textColor: AppColors.success,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),

                              // Bar chart
                              const Text('Динамика',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 12),
                              Container(
                                height: 200,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: BarChart(
                                  BarChartData(
                                    alignment: BarChartAlignment.spaceAround,
                                    maxY: (s.totalIncome > s.totalExpenses ? s.totalIncome : s.totalExpenses) * 1.2,
                                    barTouchData: BarTouchData(enabled: true),
                                    titlesData: FlTitlesData(
                                      show: true,
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          getTitlesWidget: (value, meta) {
                                            const labels = ['Доход', 'Расход', 'Прибыль'];
                                            if (value.toInt() >= 0 && value.toInt() < labels.length) {
                                              return Padding(
                                                padding: const EdgeInsets.only(top: 8),
                                                child: Text(labels[value.toInt()],
                                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                              );
                                            }
                                            return const Text('');
                                          },
                                        ),
                                      ),
                                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    ),
                                    borderData: FlBorderData(show: false),
                                    gridData: const FlGridData(show: false),
                                    barGroups: [
                                      BarChartGroupData(x: 0, barRods: [
                                        BarChartRodData(
                                          toY: s.totalIncome,
                                          color: AppColors.primary,
                                          width: 32,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                      ]),
                                      BarChartGroupData(x: 1, barRods: [
                                        BarChartRodData(
                                          toY: s.totalExpenses,
                                          color: AppColors.error,
                                          width: 32,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                      ]),
                                      BarChartGroupData(x: 2, barRods: [
                                        BarChartRodData(
                                          toY: s.profit > 0 ? s.profit : 0,
                                          color: AppColors.success,
                                          width: 32,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                      ]),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Top products
                              if (s.topProducts.isNotEmpty) ...[
                                const Text('Топ товары',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 8),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Column(
                                    children: [
                                      for (int i = 0; i < s.topProducts.length; i++) ...[
                                        if (i > 0) const Divider(height: 1),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                          child: Row(
                                            children: [
                                              Text('${i + 1}',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.textSecondary,
                                                )),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(s.topProducts[i].name,
                                                  style: const TextStyle(fontWeight: FontWeight.w500)),
                                              ),
                                              Text('${s.topProducts[i].quantity} шт',
                                                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                                              const SizedBox(width: 12),
                                              Text(_formatPrice(s.topProducts[i].revenue),
                                                style: const TextStyle(fontWeight: FontWeight.w600)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 80),
                            ],
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionsGrid() {
    final storeId = _storeId ?? '';
    final sections = [
      _SectionItem('Баланс', Icons.account_balance_wallet_outlined, () {}),
      _SectionItem('Кредиты', Icons.credit_card_outlined, () {}),
      _SectionItem('Вложения', Icons.trending_up_outlined, () {}),
      _SectionItem('Закят', Icons.volunteer_activism_outlined, () => context.push('/zakat', extra: storeId)),
      _SectionItem('Валюты', Icons.currency_exchange_outlined, () {}),
      _SectionItem('Доставка', Icons.local_shipping_outlined, () {}),
      _SectionItem('Отчёт', Icons.bar_chart_outlined, () {}),
      _SectionItem('Расходы', Icons.money_off_outlined, () => context.push('/expenses', extra: storeId)),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 0.9,
      children: sections.map((s) => GestureDetector(
        onTap: s.onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(s.icon, size: 24, color: AppColors.primary),
              const SizedBox(height: 4),
              Text(s.label,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center),
            ],
          ),
        ),
      )).toList(),
    );
  }

  Widget _periodChip(String label, String period) {
    final isSelected = _period == period;
    return GestureDetector(
      onTap: () {
        setState(() => _period = period);
        final id = _storeId;
        if (id != null) {
          context.read<FinanceBloc>().add(FinancePeriodChanged(storeId: id, period: period));
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: isSelected ? null : Border.all(color: AppColors.divider),
        ),
        child: Text(label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          )),
      ),
    );
  }
}

class _SectionItem {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  _SectionItem(this.label, this.icon, this.onTap);
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final Color bgColor;
  final Color textColor;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.bgColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
            style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.7))),
          const SizedBox(height: 4),
          Text(value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: textColor,
            )),
        ],
      ),
    );
  }
}
