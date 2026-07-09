import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../domain/entities/loyalty_analytics.dart';
import '../../blocs/loyalty/loyalty_analytics_bloc.dart';
import '../../blocs/loyalty/loyalty_analytics_event.dart';
import '../../blocs/loyalty/loyalty_analytics_state.dart';

enum _Period { week, month, year }

class LoyaltyAnalyticsPage extends StatefulWidget {
  final String storeId;
  const LoyaltyAnalyticsPage({super.key, required this.storeId});

  @override
  State<LoyaltyAnalyticsPage> createState() => _LoyaltyAnalyticsPageState();
}

class _LoyaltyAnalyticsPageState extends State<LoyaltyAnalyticsPage> {
  _Period _period = _Period.month;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final now = DateTime.now();
    final (from, to) = switch (_period) {
      _Period.week => (now.subtract(const Duration(days: 7)), now),
      _Period.month => (DateTime(now.year, now.month, 1), now),
      _Period.year => (DateTime(now.year, 1, 1), now),
    };
    context.read<LoyaltyAnalyticsBloc>().add(
          LoyaltyAnalyticsLoadRequested(
              storeId: widget.storeId, from: from, to: to),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Аналитика баллов')),
      body: Column(
        children: [
          _PeriodChips(
            selected: _period,
            onChanged: (p) {
              setState(() => _period = p);
              _load();
            },
          ),
          Expanded(
            child: BlocBuilder<LoyaltyAnalyticsBloc, LoyaltyAnalyticsState>(
              builder: (context, state) {
                if (state is LoyaltyAnalyticsLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state is LoyaltyAnalyticsError) {
                  return Center(child: Text(state.message));
                }
                if (state is LoyaltyAnalyticsLoaded) {
                  return _Body(data: state.data);
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodChips extends StatelessWidget {
  final _Period selected;
  final ValueChanged<_Period> onChanged;
  const _PeriodChips({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacingMd, vertical: AppConstants.spacingSm),
      child: Row(
        children: [
          for (final (label, p) in [
            ('Неделя', _Period.week),
            ('Месяц', _Period.month),
            ('Год', _Period.year),
          ])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(label),
                selected: selected == p,
                onSelected: (_) => onChanged(p),
              ),
            ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final LoyaltyAnalytics data;
  const _Body({required this.data});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.2,
          children: [
            _StatCard(label: 'Начислено', value: '${data.totalEarned} баллов'),
            _StatCard(label: 'Списано', value: '${data.totalRedeemed} баллов'),
            _StatCard(label: 'Сгорело', value: '${data.totalExpired} баллов'),
            _StatCard(
                label: 'Экономия',
                value: '${data.discountValue.toStringAsFixed(0)} сом'),
          ],
        ),
        const SizedBox(height: AppConstants.spacingMd),
        Text('Активных участников: ${data.activeParticipants}',
            style:
                const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        const SizedBox(height: AppConstants.spacingMd),
        if (data.topCustomers.isNotEmpty) ...[
          const Text('Топ клиентов',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: AppConstants.spacingSm),
          ...data.topCustomers.map((c) {
            final maxBalance = data.topCustomers.first.balance
                .toDouble()
                .clamp(1, double.infinity);
            return Padding(
              padding:
                  const EdgeInsets.only(bottom: AppConstants.spacingSm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(c.name,
                          style:
                              const TextStyle(fontWeight: FontWeight.w600)),
                      Text('${c.balance} баллов',
                          style:
                              const TextStyle(color: AppColors.primary)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: c.balance / maxBalance,
                    backgroundColor:
                        AppColors.primary.withValues(alpha: 0.1),
                    valueColor:
                        const AlwaysStoppedAnimation(AppColors.primary),
                    minHeight: 4,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingSm),
      decoration: BoxDecoration(
        color: context.surfaceMuted,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  TextStyle(fontSize: 12, color: context.textSecondary)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
