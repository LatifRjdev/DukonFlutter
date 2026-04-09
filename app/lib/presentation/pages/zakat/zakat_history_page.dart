import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../blocs/zakat/zakat_bloc.dart';
import '../../blocs/zakat/zakat_event.dart';
import '../../blocs/zakat/zakat_state.dart';

class ZakatHistoryPage extends StatefulWidget {
  final String storeId;
  const ZakatHistoryPage({super.key, required this.storeId});
  @override
  State<ZakatHistoryPage> createState() => _ZakatHistoryPageState();
}

class _ZakatHistoryPageState extends State<ZakatHistoryPage> {
  String _formatPrice(double value) {
    final formatter = NumberFormat('#,##0.00', 'ru');
    return '${formatter.format(value)} TJS';
  }

  @override
  void initState() {
    super.initState();
    context.read<ZakatBloc>().add(ZakatPaymentsRequested(storeId: widget.storeId));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
                  const Text('История закята',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                ],
              ),
            ),

            // Content
            Expanded(
              child: BlocBuilder<ZakatBloc, ZakatState>(
                builder: (context, state) {
                  if (state is ZakatLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state is ZakatError) {
                    return Center(child: Text(state.message));
                  }
                  if (state is ZakatPaymentsLoaded) {
                    if (state.payments.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.nightlight_round, size: 64, color: AppColors.disabled),
                            SizedBox(height: 16),
                            Text('Нет расчётов закята',
                              style: TextStyle(color: AppColors.lightTextSecondary, fontSize: 16)),
                            SizedBox(height: 4),
                            Text('Рассчитайте закят в калькуляторе',
                              style: TextStyle(color: AppColors.lightTextSecondary, fontSize: 13)),
                          ],
                        ),
                      );
                    }

                    final totalPaid = state.payments.fold<double>(0, (sum, p) => sum + p.amount);

                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Stats card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              const Text('Всего выплачено:',
                                style: TextStyle(fontSize: 13, color: AppColors.lightTextSecondary)),
                              const SizedBox(height: 4),
                              Text(_formatPrice(totalPaid),
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.primary)),
                              const SizedBox(height: 2),
                              Text('за ${state.payments.length} выплат',
                                style: const TextStyle(fontSize: 12, color: AppColors.lightTextSecondary)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Payment cards
                        ...state.payments.map((payment) {
                          final dateStr = DateFormat('dd.MM.yyyy').format(payment.paidAt);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: AppColors.success.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.check, size: 18, color: AppColors.success),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Выплата закята',
                                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 2),
                                      Text('Оплачен $dateStr',
                                        style: const TextStyle(fontSize: 12, color: AppColors.lightTextSecondary)),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(_formatPrice(payment.amount),
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary)),
                                    const SizedBox(height: 2),
                                    Text('Облагаемая: ${_formatPrice(payment.totalAssets)}',
                                      style: const TextStyle(fontSize: 10, color: AppColors.lightTextSecondary)),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
