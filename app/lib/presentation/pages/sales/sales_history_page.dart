import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/route_names.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../domain/entities/sale.dart';
import '../../blocs/sales/sales_history_bloc.dart';
import '../../blocs/sales/sales_history_event.dart';
import '../../blocs/sales/sales_history_state.dart';
import '../../blocs/store/store_bloc.dart';
import '../../blocs/store/store_state.dart';
import '../../widgets/common/app_chip.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/app_error_widget.dart';
import '../../widgets/pos/sales_filter_sheet.dart';

class SalesHistoryPage extends StatefulWidget {
  const SalesHistoryPage({super.key});

  @override
  State<SalesHistoryPage> createState() => _SalesHistoryPageState();
}

class _SalesHistoryPageState extends State<SalesHistoryPage> {
  String _selectedPeriod = 'today';
  SalesFilter _activeFilter = const SalesFilter();

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
      backgroundColor: context.bg,
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
                    onPressed: () => SalesFilterSheet.show(
                      context,
                      initial: _activeFilter,
                      onApply: (filter) {
                        setState(() => _activeFilter = filter);
                        context.read<SalesHistoryBloc>().add(
                          SalesHistoryFilterByDate(
                            dateFrom: filter.from,
                            dateTo: filter.to,
                          ),
                        );
                        if (filter.paymentTypeValue != null ||
                            filter.payment == SalesFilterPayment.all) {
                          context.read<SalesHistoryBloc>().add(
                            SalesHistoryFilterByPaymentMethod(
                              filter.paymentTypeValue,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.file_download_outlined),
                    onPressed: () {
                      final storeState = context.read<StoreBloc>().state;
                      final storeId = storeState is StoreLoaded
                          ? (storeState.selectedStore?.id ?? '')
                          : '';
                      context.push(RouteNames.financeReports, extra: storeId);
                    },
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
                    AppChip(
                      label: 'Сегодня',
                      isSelected: _selectedPeriod == 'today',
                      onTap: () => _onPeriodSelected('today'),
                    ),
                    const SizedBox(width: 8),
                    AppChip(
                      label: 'Неделя',
                      isSelected: _selectedPeriod == 'week',
                      onTap: () => _onPeriodSelected('week'),
                    ),
                    const SizedBox(width: 8),
                    AppChip(
                      label: 'Месяц',
                      isSelected: _selectedPeriod == 'month',
                      onTap: () => _onPeriodSelected('month'),
                    ),
                    const SizedBox(width: 8),
                    AppChip(
                      label: 'Выбрать',
                      isSelected: _selectedPeriod == 'custom',
                      onTap: _showDatePicker,
                    ),
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
                    return AppErrorWidget(
                      message: state.message,
                      onRetry: _onRefresh,
                    );
                  }
                  if (state is SalesHistoryLoaded) {
                    if (state.sales.isEmpty) {
                      return const AppEmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'Нет продаж',
                        subtitle: 'История продаж появится здесь после первой транзакции',
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
    if (sale.paymentType == 'DEBT') return AppColors.warning;
    return AppColors.success;
  }

  Color _statusBgColor(BuildContext context) {
    if (sale.status == 'REFUNDED') return context.dangerBg;
    if (sale.paymentType == 'DEBT') return context.warningBg;
    return context.successBg;
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
          color: context.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppShadows.sm,
        ),
        child: Row(
          children: [
            // Status icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _statusBgColor(context),
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
                        style: TextStyle(fontSize: 12, color: context.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${sale.customerName ?? 'Розничный'}  •  ${sale.items.length} товаров',
                        style: TextStyle(fontSize: 12, color: context.textSecondary),
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
                          color: isRefund ? AppColors.error : context.textPrimary,
                        ),
                      ),
                      Row(
                        children: [
                          Icon(_paymentIcon(), size: 14, color: context.textSecondary),
                          const SizedBox(width: 4),
                          Text(isRefund ? 'Возврат' : _paymentLabel(),
                            style: TextStyle(
                              fontSize: 12,
                              color: isRefund ? AppColors.error : context.textSecondary,
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
