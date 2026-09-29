import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../domain/entities/sale.dart';
import 'package:dukonpro/l10n/app_localizations.dart';

class TransactionDetailPage extends StatelessWidget {
  final Sale sale;

  const TransactionDetailPage({super.key, required this.sale});

  String _formatPrice(double value) {
    final formatter = NumberFormat('#,##0', 'ru');
    return '${formatter.format(value)} TJS';
  }

  String _paymentTypeLabel(AppLocalizations l10n, String type) {
    switch (type.toUpperCase()) {
      case 'CASH': return l10n.cash;
      case 'CARD': return l10n.card;
      case 'DEBT': return l10n.debt;
      case 'MIXED': return l10n.paymentMixedShort;
      default: return type;
    }
  }

  String _statusLabel(AppLocalizations l10n, String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETED': return l10n.transactionDetailStatusPaid;
      case 'RETURNED': return l10n.transactionDetailStatusReturned;
      case 'PARTIALLY_RETURNED': return l10n.partiallyReturned;
      default: return status;
    }
  }

  Color _statusColor(BuildContext context, String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETED': return context.success;
      case 'RETURNED': return context.danger;
      case 'PARTIALLY_RETURNED': return context.warning;
      default: return context.textSecondary;
    }
  }

  // A sale that has already been fully returned can't be refunded again.
  // `PARTIALLY_RETURNED` sales may still have un-refunded items, so the
  // action stays available for those — full-vs-partial refund eligibility
  // is a separate business rule outside this fix's scope.
  bool _canRefund(Sale sale) => sale.status.toUpperCase() != 'RETURNED';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dateFormat = DateFormat('dd.MM.yyyy, HH:mm');
    final canRefund = _canRefund(sale);

    return Scaffold(
      backgroundColor: context.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    tooltip: l10n.back,
                    onPressed: () => context.pop(),
                  ),
                  Text(l10n.transactionDetailReceiptTitle(sale.receiptNo),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status badge
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: _statusColor(context, sale.status),
                          borderRadius: BorderRadius.circular(AppConstants.radiusXl),
                        ),
                        child: Text(_statusLabel(l10n, sale.status),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          )),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Information card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.surface,
                        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.transactionDetailInfoSectionTitle,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 12),
                          _InfoRow(label: l10n.date, value: dateFormat.format(sale.createdAt)),
                          const Divider(height: 20),
                          _InfoRow(label: l10n.cashier, value: sale.staffId ?? '—'),
                          const Divider(height: 20),
                          _InfoRow(label: l10n.deliveryDetailCustomerLabel, value: sale.customerName ?? l10n.transactionDetailRetailCustomerFallback),
                          const Divider(height: 20),
                          _InfoRow(label: l10n.payment, value: _paymentTypeLabel(l10n, sale.paymentType)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Items card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.surface,
                        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.products,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 12),
                          if (sale.items.isEmpty)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(l10n.transactionDetailNoItemsData,
                                  style: TextStyle(color: context.textSecondary)),
                              ),
                            )
                          else
                            ...sale.items.asMap().entries.map((entry) {
                              final i = entry.key;
                              final item = entry.value;
                              return Column(
                                children: [
                                  if (i > 0) const Divider(height: 16),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(item.productName,
                                              style: const TextStyle(fontWeight: FontWeight.w500)),
                                            const SizedBox(height: 2),
                                            Text(l10n.transactionDetailItemQtyLine(item.quantity.toString(), _formatPrice(item.unitPrice)),
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: context.textSecondary,
                                              )),
                                          ],
                                        ),
                                      ),
                                      Text('= ${_formatPrice(item.total)}',
                                        style: const TextStyle(fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ],
                              );
                            }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Totals card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.surface,
                        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.total,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 12),
                          _TotalRow(label: l10n.subtotal, value: _formatPrice(sale.subtotal)),
                          const SizedBox(height: 8),
                          _TotalRow(label: l10n.discount, value: _formatPrice(sale.discount)),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Divider(),
                          ),
                          _TotalRow(label: l10n.total, value: _formatPrice(sale.total), isBold: true),
                          const SizedBox(height: 8),
                          _TotalRow(label: l10n.paid, value: _formatPrice(sale.paidAmount)),
                          const SizedBox(height: 8),
                          _TotalRow(label: l10n.change, value: _formatPrice(sale.change)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),

            // Bottom buttons
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                color: context.surface,
                boxShadow: AppShadows.md,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/pos/receipt', extra: {'sale': sale}),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                        ),
                      ),
                      icon: const Icon(Icons.print_outlined, size: 20),
                      label: Text(l10n.printReceiptButton,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  if (canRefund) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => context.push('/sales/${sale.id}/refund', extra: sale),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                          ),
                        ),
                        icon: const Icon(Icons.undo, size: 20),
                        label: Text(l10n.refund,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: context.textSecondary, fontSize: 14)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
      ],
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;

  const _TotalRow({required this.label, required this.value, this.isBold = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
          style: TextStyle(
            color: context.textSecondary,
            fontSize: isBold ? 16 : 14,
          )),
        Text(value,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            fontSize: isBold ? 18 : 14,
          )),
      ],
    );
  }
}
