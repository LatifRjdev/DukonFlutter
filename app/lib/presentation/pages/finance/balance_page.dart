import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/errors/error_messages.dart';
import '../../blocs/store/store_bloc.dart';
import '../../blocs/store/store_state.dart';
import '../../widgets/common/app_chip.dart';
import '../../widgets/common/glass_card.dart';
import '../../../injection.dart';

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class _ChartPoint {
  final String date;
  final double income;
  final double expenses;
  const _ChartPoint({required this.date, required this.income, required this.expenses});

  factory _ChartPoint.fromJson(Map<String, dynamic> j) => _ChartPoint(
        date: j['date'] as String? ?? '',
        income: (j['income'] as num?)?.toDouble() ?? 0,
        expenses: (j['expenses'] as num?)?.toDouble() ?? 0,
      );
}

class _Transaction {
  final String id;
  final String type; // 'sale' | 'expense' | etc.
  final double amount;
  final String date;
  final String description;
  const _Transaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.date,
    required this.description,
  });

  factory _Transaction.fromJson(Map<String, dynamic> j) => _Transaction(
        id: j['id'] as String? ?? '',
        type: j['type'] as String? ?? 'sale',
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
        date: j['date'] as String? ?? '',
        description: j['description'] as String? ?? '',
      );
}

class _BalanceData {
  final double balance;
  final double income;
  final double expenses;
  final double profit;
  final List<_ChartPoint> chartData;
  final List<_Transaction> transactions;

  const _BalanceData({
    required this.balance,
    required this.income,
    required this.expenses,
    required this.profit,
    required this.chartData,
    required this.transactions,
  });

  factory _BalanceData.fromJson(Map<String, dynamic> j) => _BalanceData(
        balance: (j['balance'] as num?)?.toDouble() ?? 0,
        income: (j['income'] as num?)?.toDouble() ?? 0,
        expenses: (j['expenses'] as num?)?.toDouble() ?? 0,
        profit: (j['profit'] as num?)?.toDouble() ?? 0,
        chartData: ((j['chartData'] as List?) ?? [])
            .map((e) => _ChartPoint.fromJson(e as Map<String, dynamic>))
            .toList(),
        transactions: ((j['transactions'] as List?) ?? [])
            .map((e) => _Transaction.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

class BalancePage extends StatefulWidget {
  final String storeId;
  const BalancePage({super.key, required this.storeId});

  @override
  State<BalancePage> createState() => _BalancePageState();
}

class _BalancePageState extends State<BalancePage> {
  String _period = 'month';
  _BalanceData? _data;
  bool _loading = false;
  String? _error;

  String get _storeId {
    if (widget.storeId.isNotEmpty) return widget.storeId;
    final storeState = context.read<StoreBloc>().state;
    return storeState is StoreLoaded
        ? (storeState.selectedStore?.id ?? '')
        : '';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = _storeId;
    if (id.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dio = sl<DioClient>();
      final response = await dio.get(
        '/stores/$id/finances/balance',
        queryParameters: {'period': _period},
      );
      final json = response.data as Map<String, dynamic>;
      setState(() {
        _data = _BalanceData.fromJson(json);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = mapErrorToUserMessage(e);
        _loading = false;
      });
    }
  }

  String _formatPrice(double value) {
    final formatter = NumberFormat('#,##0', 'ru');
    return '${formatter.format(value)} TJS';
  }

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw);
      return DateFormat('dd.MM').format(dt);
    } catch (_) {
      return raw;
    }
  }

  String _formatDateFull(String raw) {
    try {
      final dt = DateTime.parse(raw);
      return DateFormat('dd.MM.yyyy HH:mm').format(dt);
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        title: const Text('Баланс'),
        backgroundColor: context.surface,
        foregroundColor: context.textPrimary,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _data == null
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: _buildContent(),
                    ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: context.danger),
          const SizedBox(height: AppConstants.spacingMd),
          Text(_error!, style: TextStyle(color: context.textSecondary), textAlign: TextAlign.center),
          const SizedBox(height: AppConstants.spacingMd),
          TextButton(onPressed: _load, child: const Text('Повторить')),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final d = _data!;
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header card – balance
          _buildBalanceCard(d),
          const SizedBox(height: AppConstants.spacingMd),

          // Period chips
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                AppChip(
                  label: 'Неделя',
                  isSelected: _period == 'week',
                  onTap: () => _changePeriod('week'),
                ),
                const SizedBox(width: 8),
                AppChip(
                  label: 'Месяц',
                  isSelected: _period == 'month',
                  onTap: () => _changePeriod('month'),
                ),
                const SizedBox(width: 8),
                AppChip(
                  label: 'Год',
                  isSelected: _period == 'year',
                  onTap: () => _changePeriod('year'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppConstants.spacingMd),

          // Line chart
          if (d.chartData.isNotEmpty) ...[
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Динамика',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  _buildLegend(),
                  const SizedBox(height: 12),
                  SizedBox(height: 200, child: _buildLineChart(d.chartData)),
                ],
              ),
            ),
            const SizedBox(height: AppConstants.spacingMd),
          ],

          // Summary row
          _buildSummaryRow(d),
          const SizedBox(height: AppConstants.spacingMd),

          // Transactions
          if (d.transactions.isNotEmpty) ...[
            Text(
              'Транзакции',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.textPrimary),
            ),
            const SizedBox(height: 8),
            _buildTransactionList(d.transactions),
          ] else
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Text('Транзакций нет', style: TextStyle(color: context.textSecondary)),
              ),
            ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(_BalanceData d) {
    final isPositive = d.balance >= 0;
    final color = isPositive ? AppColors.success : AppColors.error;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Текущий баланс', style: TextStyle(fontSize: 13, color: context.textSecondary)),
          const SizedBox(height: 8),
          Text(
            _formatPrice(d.balance),
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Row(
      children: [
        _LegendDot(color: AppColors.success, label: 'Доходы'),
        const SizedBox(width: 16),
        _LegendDot(color: AppColors.error, label: 'Расходы'),
      ],
    );
  }

  Widget _buildLineChart(List<_ChartPoint> points) {
    double maxY = 0;
    for (final p in points) {
      if (p.income > maxY) maxY = p.income;
      if (p.expenses > maxY) maxY = p.expenses;
    }
    maxY = maxY * 1.2;
    if (maxY == 0) maxY = 100;

    final incomeSpots = <FlSpot>[];
    final expenseSpots = <FlSpot>[];
    for (int i = 0; i < points.length; i++) {
      incomeSpots.add(FlSpot(i.toDouble(), points[i].income));
      expenseSpots.add(FlSpot(i.toDouble(), points[i].expenses));
    }

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => context.textPrimary,
          ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: (points.length / 5).ceilToDouble().clamp(1, double.infinity),
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= points.length) return const Text('');
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _formatDate(points[idx].date),
                    style: TextStyle(fontSize: 12, color: context.textSecondary),
                  ),
                );
              },
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 4,
          getDrawingHorizontalLine: (_) => FlLine(color: context.border, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: incomeSpots,
            isCurved: true,
            color: AppColors.success,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.success.withValues(alpha: 0.08),
            ),
          ),
          LineChartBarData(
            spots: expenseSpots,
            isCurved: true,
            color: AppColors.error,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.error.withValues(alpha: 0.08),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(_BalanceData d) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Row(
        children: [
          Expanded(
            child: _SummaryCell(
              label: 'Доходы',
              value: _formatPrice(d.income),
              color: AppColors.success,
            ),
          ),
          Container(width: 1, height: 40, color: context.border),
          Expanded(
            child: _SummaryCell(
              label: 'Расходы',
              value: _formatPrice(d.expenses),
              color: AppColors.error,
            ),
          ),
          Container(width: 1, height: 40, color: context.border),
          Expanded(
            child: _SummaryCell(
              label: 'Прибыль',
              value: _formatPrice(d.profit),
              color: d.profit >= 0 ? AppColors.primary : AppColors.error,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList(List<_Transaction> txs) {
    return Container(
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
      ),
      child: Column(
        children: [
          for (int i = 0; i < txs.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 56),
            _buildTransactionRow(txs[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildTransactionRow(_Transaction tx) {
    final isSale = tx.type == 'sale';
    final color = isSale ? AppColors.success : AppColors.error;
    final icon = isSale ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;
    final prefix = isSale ? '+' : '-';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.description.isNotEmpty ? tx.description : (isSale ? 'Продажа' : 'Расход'),
                  style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDateFull(tx.date),
                  style: TextStyle(fontSize: 12, color: context.textSecondary),
                ),
              ],
            ),
          ),
          Text(
            '$prefix${_formatPrice(tx.amount)}',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: color),
          ),
        ],
      ),
    );
  }

  void _changePeriod(String period) {
    setState(() => _period = period);
    _load();
  }
}

// ---------------------------------------------------------------------------
// Helper widgets
// ---------------------------------------------------------------------------

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: context.textSecondary)),
      ],
    );
  }
}

class _SummaryCell extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _SummaryCell({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: context.textSecondary)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }
}
