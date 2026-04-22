import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/network/dio_client.dart';
import '../../widgets/common/glass_card.dart';
import '../../../injection.dart';
import 'package:dokonpro/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class _CurrencyRate {
  final String code;
  final double rate;
  final String flag;
  final String label;

  const _CurrencyRate({
    required this.code,
    required this.rate,
    required this.flag,
    required this.label,
  });

  factory _CurrencyRate.fromJson(Map<String, dynamic> j, String code) {
    const flags = {
      'USD': '🇺🇸',
      'RUB': '🇷🇺',
      'EUR': '🇪🇺',
      'CNY': '🇨🇳',
    };
    const labels = {
      'USD': 'Доллар США',
      'RUB': 'Российский рубль',
      'EUR': 'Евро',
      'CNY': 'Китайский юань',
    };
    return _CurrencyRate(
      code: code,
      rate: (j[code] as num?)?.toDouble() ?? 0.0,
      flag: flags[code] ?? '🏳️',
      label: labels[code] ?? code,
    );
  }
}

class _HistoryPoint {
  final String date;
  final double rate;
  const _HistoryPoint({required this.date, required this.rate});

  factory _HistoryPoint.fromJson(Map<String, dynamic> j) => _HistoryPoint(
        date: j['date'] as String? ?? '',
        rate: (j['nbtRate'] as num?)?.toDouble() ?? (j['rate'] as num?)?.toDouble() ?? 0,
      );
}

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

class CurrenciesPage extends StatefulWidget {
  const CurrenciesPage({super.key});

  @override
  State<CurrenciesPage> createState() => _CurrenciesPageState();
}

class _CurrenciesPageState extends State<CurrenciesPage> {
  static const _codes = ['USD', 'RUB', 'EUR', 'CNY'];

  bool _loading = false;
  String? _error;
  Map<String, _CurrencyRate> _rates = {};
  String? _expandedCode;
  final Map<String, List<_HistoryPoint>> _history = {};
  bool _historyLoading = false;

  // Converter state
  double _inputAmount = 1.0;
  String _selectedCode = 'USD';
  final _inputController = TextEditingController(text: '1');

  @override
  void initState() {
    super.initState();
    _loadRates();
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _loadRates() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dio = sl<DioClient>();
      final response = await dio.get('/currencies/rates');
      final data = response.data;
      final rates = <String, _CurrencyRate>{};
      // API returns array of {currency, buyRate, sellRate, nbtRate, date}
      if (data is List) {
        for (final item in data) {
          final m = item as Map<String, dynamic>;
          final code = m['currency'] as String;
          if (_codes.contains(code)) {
            rates[code] = _CurrencyRate.fromJson({code: (m['nbtRate'] as num).toDouble()}, code);
          }
        }
      } else if (data is Map<String, dynamic>) {
        for (final code in _codes) {
          rates[code] = _CurrencyRate.fromJson(data, code);
        }
      }
      setState(() {
        _rates = rates;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadHistory(String code) async {
    if (_history.containsKey(code)) return;
    setState(() => _historyLoading = true);
    try {
      final dio = sl<DioClient>();
      final response = await dio.get(
        '/currencies/rates/history',
        queryParameters: {'currency': code, 'days': 30},
      );
      final list = (response.data as List?) ?? [];
      setState(() {
        _history[code] = list
            .map((e) => _HistoryPoint.fromJson(e as Map<String, dynamic>))
            .toList();
        _historyLoading = false;
      });
    } catch (_) {
      setState(() => _historyLoading = false);
    }
  }

  void _toggleCard(String code) {
    setState(() {
      if (_expandedCode == code) {
        _expandedCode = null;
      } else {
        _expandedCode = code;
        _loadHistory(code);
      }
    });
  }

  String _formatRate(double rate) {
    return NumberFormat('#,##0.00', 'ru').format(rate);
  }

  double get _convertedBase {
    final rate = _rates[_selectedCode]?.rate ?? 1.0;
    return rate > 0 ? _inputAmount * rate : 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        title: const Text('Курсы валют'),
        backgroundColor: context.surface,
        foregroundColor: context.textPrimary,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _loadRates,
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
          Text(_error!,
              style: TextStyle(color: context.textSecondary),
              textAlign: TextAlign.center),
          const SizedBox(height: AppConstants.spacingMd),
          TextButton(onPressed: _loadRates, child: const Text('Повторить')),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'НБТ — Национальный банк Таджикистана',
            style: TextStyle(fontSize: 12, color: context.textSecondary),
          ),
          const SizedBox(height: AppConstants.spacingMd),
          ..._codes.map((code) => _buildCurrencyCard(code)),
          const SizedBox(height: AppConstants.spacingLg),
          _buildConverter(),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildCurrencyCard(String code) {
    final rate = _rates[code];
    if (rate == null) return const SizedBox.shrink();
    final isExpanded = _expandedCode == code;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            Semantics(
              label: AppLocalizations.of(context)!.a11ySelectCurrency(rate.code),
              button: true,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                onTap: () => _toggleCard(code),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Text(rate.flag, style: const TextStyle(fontSize: 28)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              rate.code,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: context.textPrimary,
                              ),
                            ),
                            Text(
                              rate.label,
                              style: TextStyle(
                                fontSize: 12,
                                color: context.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${_formatRate(rate.rate)} TJS',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                          Text(
                            '1 ${rate.code}',
                            style: TextStyle(
                              fontSize: 12,
                              color: context.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      AnimatedRotation(
                        turns: isExpanded ? 0.5 : 0,
                        duration: AppConstants.motionMedium,
                        child: Icon(
                          Icons.keyboard_arrow_down,
                          color: context.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (isExpanded) ...[
              Divider(height: 1, color: context.border),
              _buildHistoryChart(code),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryChart(String code) {
    final points = _history[code];

    if (_historyLoading && points == null) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (points == null || points.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            'Нет данных за 30 дней',
            style: TextStyle(color: context.textSecondary),
          ),
        ),
      );
    }

    double minRate = points.first.rate;
    double maxRate = points.first.rate;
    for (final p in points) {
      if (p.rate < minRate) minRate = p.rate;
      if (p.rate > maxRate) maxRate = p.rate;
    }
    final padding = (maxRate - minRate) * 0.2;
    final minY = (minRate - padding).clamp(0, double.infinity).toDouble();
    final maxY = maxRate + padding;

    final spots = <FlSpot>[];
    for (int i = 0; i < points.length; i++) {
      spots.add(FlSpot(i.toDouble(), points[i].rate));
    }

    String fmtDate(String raw) {
      try {
        final dt = DateTime.parse(raw);
        return DateFormat('dd.MM').format(dt);
      } catch (_) {
        return raw;
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Динамика за 30 дней',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 160,
            child: LineChart(
              LineChartData(
                minY: minY,
                maxY: maxY,
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => context.textPrimary,
                    getTooltipItems: (spots) => spots
                        .map((s) => LineTooltipItem(
                              _formatRate(s.y),
                              const TextStyle(
                                  color: Colors.white, fontSize: 12),
                            ))
                        .toList(),
                  ),
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: (points.length / 5)
                          .ceilToDouble()
                          .clamp(1, double.infinity),
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= points.length) {
                          return const Text('');
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            fmtDate(points[idx].date),
                            style: TextStyle(
                              fontSize: 12,
                              color: context.textSecondary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: (maxY - minY) / 4,
                  getDrawingHorizontalLine: (_) => FlLine(
                      color: context.border, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AppColors.primary,
                    barWidth: 2.5,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.primary.withValues(alpha: 0.08),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConverter() {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Конвертер',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inputController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Сумма',
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusMd),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                  onChanged: (v) {
                    setState(() {
                      _inputAmount = double.tryParse(v) ?? 0;
                    });
                  },
                ),
              ),
              const SizedBox(width: 10),
              DropdownButton<String>(
                value: _selectedCode,
                items: _codes
                    .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(c),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _selectedCode = v);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Результат (в TJS):',
            style: TextStyle(
                fontSize: 13, color: context.textSecondary),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            ),
            child: Text(
              '${_formatRate(_convertedBase)} TJS',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
          if (_rates.isNotEmpty) ...[
            const SizedBox(height: 12),
            Divider(color: context.border),
            const SizedBox(height: 8),
            ...(_codes
                .where((c) => c != _selectedCode)
                .map((c) {
              final from = _rates[_selectedCode]?.rate ?? 1;
              final to = _rates[c]?.rate ?? 1;
              final converted = to > 0 && from > 0
                  ? _inputAmount * from / to
                  : 0.0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_rates[c]?.flag ?? ''} $c',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500),
                    ),
                    Text(
                      _formatRate(converted),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimary,
                      ),
                    ),
                  ],
                ),
              );
            })),
          ],
        ],
      ),
    );
  }
}
