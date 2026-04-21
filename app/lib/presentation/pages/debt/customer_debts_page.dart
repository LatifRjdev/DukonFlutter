import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/constants/app_constants.dart';
import '../../blocs/debt/debt_bloc.dart';
import '../../blocs/debt/debt_event.dart';
import '../../blocs/debt/debt_state.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/debt/payment_form.dart';

class CustomerDebtsPage extends StatefulWidget {
  final String storeId;
  final String customerId;
  final String customerName;
  final String? customerPhone;

  const CustomerDebtsPage({
    super.key,
    required this.storeId,
    required this.customerId,
    required this.customerName,
    this.customerPhone,
  });

  @override
  State<CustomerDebtsPage> createState() => _CustomerDebtsPageState();
}

class _CustomerDebtsPageState extends State<CustomerDebtsPage> {
  @override
  void initState() {
    super.initState();
    context.read<DebtBloc>().add(CustomerDebtsRequested(storeId: widget.storeId, customerId: widget.customerId));
  }

  Future<void> _launchPhone() async {
    if (widget.customerPhone == null || widget.customerPhone!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Номер телефона не указан')),
      );
      return;
    }
    final uri = Uri(scheme: 'tel', path: widget.customerPhone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  bool _isOverdue(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return false;
    try {
      final date = DateTime.parse(dateStr);
      final daysSinceSale = DateTime.now().difference(date).inDays;
      return daysSinceSale > 30; // Consider overdue after 30 days
    } catch (_) {
      return false;
    }
  }

  void _showPaymentSheet(String saleId, double maxAmount) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppConstants.radiusLg)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(
          AppConstants.spacingMd,
          AppConstants.spacingMd,
          AppConstants.spacingMd,
          MediaQuery.of(context).viewInsets.bottom + AppConstants.spacingMd,
        ),
        child: PaymentForm(
          maxAmount: maxAmount,
          onSubmit: (payment) {
            Navigator.pop(context);
            context.read<DebtBloc>().add(DebtPaymentSubmitted(
              storeId: widget.storeId,
              customerId: widget.customerId,
              saleId: saleId,
              amount: payment.amount,
              method: payment.method,
              notes: payment.notes,
            ));
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.customerName),
        actions: [
          if (widget.customerPhone != null && widget.customerPhone!.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.phone_outlined, color: AppColors.success),
              onPressed: _launchPhone,
            ),
        ],
      ),
      body: BlocConsumer<DebtBloc, DebtState>(
        listener: (context, state) {
          if (state is DebtPaymentSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: AppColors.success),
            );
            context.read<DebtBloc>().add(CustomerDebtsRequested(storeId: widget.storeId, customerId: widget.customerId));
          }
          if (state is DebtError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: AppColors.error),
            );
          }
        },
        builder: (context, state) {
          if (state is DebtLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is CustomerDebtsLoaded) {
            return ListView(
              padding: const EdgeInsets.all(AppConstants.spacingMd),
              children: [
                // Total debt summary
                Container(
                  padding: const EdgeInsets.all(AppConstants.spacingLg),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                  ),
                  child: Column(
                    children: [
                      Text('Общий долг', style: TextStyle(fontSize: 14, color: context.textSecondary)),
                      const SizedBox(height: 4),
                      Text(
                        '${state.totalDebt.toStringAsFixed(2)} TJS',
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.error),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppConstants.spacingLg),
                const Text('Продажи с долгом', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: AppConstants.spacingSm),
                if (state.sales.isEmpty)
                  Center(child: Text('Нет продаж с долгом', style: TextStyle(color: context.textSecondary)))
                else
                  ...state.sales.map((sale) {
                    final saleId = sale['id'] as String? ?? '';
                    final receiptNo = sale['receiptNo'] as String? ?? '';
                    final total = (sale['total'] as num?)?.toDouble() ?? 0;
                    final debtAmount = (sale['debtAmount'] as num?)?.toDouble() ?? 0;
                    final date = sale['createdAt'] as String? ?? '';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppConstants.spacingSm),
                      child: AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Text('Чек #$receiptNo', style: const TextStyle(fontWeight: FontWeight.w600)),
                                    if (_isOverdue(date)) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.error,
                                          borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                                        ),
                                        child: const Text('Просрочено',
                                          style: TextStyle(fontSize: 10, color: AppColors.onPrimary, fontWeight: FontWeight.w500)),
                                      ),
                                    ],
                                  ],
                                ),
                                Text('${debtAmount.toStringAsFixed(2)} TJS', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.error)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Итого: ${total.toStringAsFixed(2)} TJS', style: TextStyle(fontSize: 13, color: context.textSecondary)),
                                if (date.isNotEmpty)
                                  Text(date.substring(0, 10), style: TextStyle(fontSize: 12, color: context.textSecondary)),
                              ],
                            ),
                            const SizedBox(height: AppConstants.spacingSm),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () => _showPaymentSheet(saleId, debtAmount),
                                icon: const Icon(Icons.payment, size: 18),
                                label: const Text('Принять оплату'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  side: const BorderSide(color: AppColors.primary),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusLg)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}
