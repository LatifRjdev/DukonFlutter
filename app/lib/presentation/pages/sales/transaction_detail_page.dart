import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../domain/entities/sale.dart';

class TransactionDetailPage extends StatelessWidget {
  final Sale sale;

  const TransactionDetailPage({super.key, required this.sale});

  String _formatPrice(double value) {
    final formatter = NumberFormat('#,##0', 'ru');
    return '${formatter.format(value)} TJS';
  }

  String _paymentTypeLabel(String type) {
    switch (type.toUpperCase()) {
      case 'CASH': return 'Наличные';
      case 'CARD': return 'Карта';
      case 'DEBT': return 'В долг';
      case 'MIXED': return 'Смешанная';
      default: return type;
    }
  }

  String _statusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETED': return 'Оплачен';
      case 'REFUNDED': return 'Возвращён';
      case 'PARTIALLY_REFUNDED': return 'Частичный возврат';
      default: return status;
    }
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETED': return AppColors.success;
      case 'REFUNDED': return AppColors.error;
      case 'PARTIALLY_REFUNDED': return AppColors.warning;
      default: return AppColors.lightTextSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd.MM.yyyy, HH:mm');

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
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => context.pop(),
                  ),
                  Text('Чек ${sale.receiptNo}',
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
                          color: _statusColor(sale.status),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(_statusLabel(sale.status),
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
                        color: AppColors.lightSurface,
                        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Информация',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 12),
                          _InfoRow(label: 'Дата', value: dateFormat.format(sale.createdAt)),
                          const Divider(height: 20),
                          _InfoRow(label: 'Кассир', value: sale.staffId ?? '—'),
                          const Divider(height: 20),
                          _InfoRow(label: 'Клиент', value: sale.customerName ?? 'Розничный'),
                          const Divider(height: 20),
                          _InfoRow(label: 'Оплата', value: _paymentTypeLabel(sale.paymentType)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Items card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.lightSurface,
                        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Товары',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 12),
                          if (sale.items.isEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Text('Нет данных о товарах',
                                  style: TextStyle(color: AppColors.lightTextSecondary)),
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
                                            Text('${item.quantity} шт × ${_formatPrice(item.unitPrice)}',
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: AppColors.lightTextSecondary,
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
                        color: AppColors.lightSurface,
                        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Итого',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 12),
                          _TotalRow(label: 'Подытог', value: _formatPrice(sale.subtotal)),
                          const SizedBox(height: 8),
                          _TotalRow(label: 'Скидка', value: _formatPrice(sale.discount)),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Divider(),
                          ),
                          _TotalRow(label: 'Итого', value: _formatPrice(sale.total), isBold: true),
                          const SizedBox(height: 8),
                          _TotalRow(label: 'Оплачено', value: _formatPrice(sale.paidAmount)),
                          const SizedBox(height: 8),
                          _TotalRow(label: 'Сдача', value: _formatPrice(sale.change)),
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
              decoration: const BoxDecoration(
                color: AppColors.lightSurface,
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
                      label: const Text('Печатать чек',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  ),
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
                      label: const Text('Возврат',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
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

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.lightTextSecondary, fontSize: 14)),
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
            color: AppColors.lightTextSecondary,
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
