import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../domain/entities/sale.dart';
import '../../blocs/sales/sales_history_bloc.dart';
import '../../blocs/sales/sales_history_event.dart';
import '../../blocs/sales/sales_history_state.dart';
import '../../blocs/store/store_bloc.dart';
import '../../blocs/store/store_state.dart';

class SalesHistoryPage extends StatefulWidget {
  const SalesHistoryPage({super.key});

  @override
  State<SalesHistoryPage> createState() => _SalesHistoryPageState();
}

class _SalesHistoryPageState extends State<SalesHistoryPage> {
  String _selectedPeriod = 'today';

  String get _storeId {
    final storeState = context.read<StoreBloc>().state;
    return storeState is StoreLoaded
        ? storeState.selectedStore?.id ?? ''
        : '';
  }

  String _formatPrice(double value) {
    final formatter = NumberFormat('#,##0', 'ru');
    return '${formatter.format(value)} TJS';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SalesHistoryBloc>().add(
        SalesHistoryLoadRequested(storeId: _storeId),
      );
    });
  }

  void _onPeriodSelected(String period) {
    setState(() => _selectedPeriod = period);
    context.read<SalesHistoryBloc>().add(
      SalesHistoryLoadRequested(storeId: _storeId),
    );
  }

  Future<void> _onRefresh() async {
    context.read<SalesHistoryBloc>().add(
      SalesHistoryLoadRequested(storeId: _storeId),
    );
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
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              child: Row(
                children: [
                  const Text('История продаж',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.filter_list_outlined),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: const Icon(Icons.file_download_outlined),
                    onPressed: () {},
                  ),
                ],
              ),
            ),

            // Period filter chips
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
              child: SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _periodChip('Сегодня', 'today'),
                    const SizedBox(width: 8),
                    _periodChip('Неделя', 'week'),
                    const SizedBox(width: 8),
                    _periodChip('Месяц', 'month'),
                    const SizedBox(width: 8),
                    _periodChip('Выбрать', 'custom'),
                  ],
                ),
              ),
            ),

            // Sales content
            Expanded(
              child: BlocBuilder<SalesHistoryBloc, SalesHistoryState>(
                builder: (context, state) {
                  if (state is SalesHistoryLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state is SalesHistoryError) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(state.message,
                            style: const TextStyle(color: AppColors.error),
                            textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          TextButton(onPressed: _onRefresh, child: const Text('Повторить')),
                        ],
                      ),
                    );
                  }
                  if (state is SalesHistoryLoaded) {
                    if (state.sales.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 64, color: AppColors.disabled),
                            SizedBox(height: 16),
                            Text('Нет продаж', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                            SizedBox(height: 8),
                            Text('История продаж появится здесь',
                              style: TextStyle(color: AppColors.lightTextSecondary)),
                          ],
                        ),
                      );
                    }

                    // Calculate stats
                    final totalSales = state.sales.length;
                    final totalAmount = state.sales.fold<double>(0, (sum, s) => sum + s.total);

                    return RefreshIndicator(
                      onRefresh: _onRefresh,
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          // Stats card
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$totalSales продаж  |  ${_formatPrice(totalAmount)}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Sales list
                          ...state.sales.map((sale) => _SaleCard(
                            sale: sale,
                            formatPrice: _formatPrice,
                            onTap: () => context.push('/sales/${sale.id}', extra: sale),
                          )),
                          if (state.isLoadingMore)
                            const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator()),
                            ),
                        ],
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
    );
  }

  Widget _periodChip(String label, String period) {
    final isSelected = _selectedPeriod == period;
    return GestureDetector(
      onTap: () {
        if (period == 'custom') {
          _showDatePicker();
        } else {
          _onPeriodSelected(period);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: isSelected ? null : Border.all(color: AppColors.lightBorder),
        ),
        child: Text(label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.lightTextSecondary,
          )),
      ),
    );
  }

  Future<void> _showDatePicker() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (range != null) {
      setState(() => _selectedPeriod = 'custom');
    }
  }
}

class _SaleCard extends StatelessWidget {
  final Sale sale;
  final String Function(double) formatPrice;
  final VoidCallback onTap;

  const _SaleCard({
    required this.sale,
    required this.formatPrice,
    required this.onTap,
  });

  IconData _statusIcon() {
    if (sale.status == 'REFUNDED') return Icons.undo;
    if (sale.paymentType == 'DEBT') return Icons.access_time;
    return Icons.check_circle;
  }

  Color _statusColor() {
    if (sale.status == 'REFUNDED') return AppColors.error;
    if (sale.paymentType == 'DEBT') return const Color(0xFFFF9800);
    return AppColors.success;
  }

  String _paymentLabel() {
    switch (sale.paymentType.toUpperCase()) {
      case 'CASH': return 'Наличные';
      case 'CARD': return 'Карта';
      case 'DEBT': return 'В долг';
      case 'MIXED': return 'Смешанная';
      default: return sale.paymentType;
    }
  }

  IconData _paymentIcon() {
    switch (sale.paymentType.toUpperCase()) {
      case 'CASH': return Icons.payments_outlined;
      case 'CARD': return Icons.credit_card;
      case 'DEBT': return Icons.access_time;
      default: return Icons.payment;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd.MM HH:mm');
    final isRefund = sale.status == 'REFUNDED';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: AppColors.overlay, blurRadius: 4, offset: Offset(0, 1)),
          ],
        ),
        child: Row(
          children: [
            // Status icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _statusColor().withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(_statusIcon(), size: 18, color: _statusColor()),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Чек ${sale.receiptNo}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      Text(dateFormat.format(sale.createdAt),
                        style: const TextStyle(fontSize: 12, color: AppColors.lightTextSecondary)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${sale.customerName ?? 'Розничный'}  •  ${sale.items.length} товаров',
                        style: const TextStyle(fontSize: 12, color: AppColors.lightTextSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isRefund ? '-${formatPrice(sale.total)}' : formatPrice(sale.total),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isRefund ? AppColors.error : AppColors.lightTextPrimary,
                        ),
                      ),
                      Row(
                        children: [
                          Icon(_paymentIcon(), size: 14, color: AppColors.lightTextSecondary),
                          const SizedBox(width: 4),
                          Text(isRefund ? 'Возврат' : _paymentLabel(),
                            style: TextStyle(
                              fontSize: 12,
                              color: isRefund ? AppColors.error : AppColors.lightTextSecondary,
                            )),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
