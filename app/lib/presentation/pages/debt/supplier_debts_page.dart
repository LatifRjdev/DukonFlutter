import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/constants/app_constants.dart';
import '../../blocs/debt/debt_bloc.dart';
import '../../blocs/debt/debt_event.dart';
import '../../blocs/debt/debt_state.dart';
import '../../widgets/common/app_snackbar.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/debt/payment_form.dart';

class SupplierDebtsPage extends StatefulWidget {
  final String storeId;
  final String supplierId;
  final String supplierName;

  const SupplierDebtsPage({
    super.key,
    required this.storeId,
    required this.supplierId,
    required this.supplierName,
  });

  @override
  State<SupplierDebtsPage> createState() => _SupplierDebtsPageState();
}

class _SupplierDebtsPageState extends State<SupplierDebtsPage> {
  @override
  void initState() {
    super.initState();
    context.read<DebtBloc>().add(SupplierDebtsRequested(storeId: widget.storeId, supplierId: widget.supplierId));
  }

  void _showPaymentSheet(double maxAmount) {
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
            context.read<DebtBloc>().add(SupplierPaymentSubmitted(
              storeId: widget.storeId,
              supplierId: widget.supplierId,
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
      appBar: AppBar(title: Text(widget.supplierName)),
      body: BlocConsumer<DebtBloc, DebtState>(
        listener: (context, state) {
          if (state is DebtPaymentSuccess) {
            AppSnackbar.success(context, state.message);
            context.read<DebtBloc>().add(SupplierDebtsRequested(storeId: widget.storeId, supplierId: widget.supplierId));
          }
          if (state is DebtError) {
            AppSnackbar.error(context, state.message);
          }
        },
        builder: (context, state) {
          if (state is DebtLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is SupplierDebtsLoaded) {
            return ListView(
              padding: const EdgeInsets.all(AppConstants.spacingMd),
              children: [
                // Debt summary
                Container(
                  padding: const EdgeInsets.all(AppConstants.spacingLg),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                  ),
                  child: Column(
                    children: [
                      Text('Наш долг', style: TextStyle(fontSize: 14, color: context.textSecondary)),
                      const SizedBox(height: 4),
                      Text(
                        '${state.debt.toStringAsFixed(2)} TJS',
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.warning),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppConstants.spacingMd),
                if (state.debt > 0)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _showPaymentSheet(state.debt),
                      icon: const Icon(Icons.payment),
                      label: const Text('Записать оплату'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusLg)),
                      ),
                    ),
                  ),
                const SizedBox(height: AppConstants.spacingLg),
                const Text('История оплат', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: AppConstants.spacingSm),
                if (state.payments.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppConstants.spacingXl),
                      child: Text('Нет записей об оплате', style: TextStyle(color: context.textSecondary)),
                    ),
                  )
                else
                  ...state.payments.map((p) {
                    final amount = (p['amount'] as num?)?.toDouble() ?? 0;
                    final method = p['method'] as String? ?? '';
                    final notes = p['notes'] as String?;
                    final date = p['createdAt'] as String? ?? '';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppConstants.spacingSm),
                      child: AppCard(
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                              ),
                              child: const Icon(Icons.check, color: AppColors.success, size: 20),
                            ),
                            const SizedBox(width: AppConstants.spacingMd),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(method == 'CASH' ? 'Наличные' : 'Карта', style: const TextStyle(fontWeight: FontWeight.w500)),
                                  if (notes != null && notes.isNotEmpty)
                                    Text(notes, style: TextStyle(fontSize: 12, color: context.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('${amount.toStringAsFixed(2)} TJS', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.success)),
                                if (date.isNotEmpty)
                                  Text(date.substring(0, 10), style: TextStyle(fontSize: 12, color: context.textSecondary)),
                              ],
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
