import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../domain/entities/payroll_entry.dart';
import '../common/app_card.dart';

class PayrollStaffCard extends StatelessWidget {
  final PayrollEntry entry;
  final VoidCallback? onTap;
  final VoidCallback? onPay;

  const PayrollStaffCard({super.key, required this.entry, this.onTap, this.onPay});

  String _roleLabel(String? role) {
    switch (role) {
      case 'OWNER':
        return 'Владелец';
      case 'ADMIN':
        return 'Админ';
      case 'CASHIER':
        return 'Кассир';
      case 'WAREHOUSE':
        return 'Складовщик';
      default:
        return role ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                backgroundImage: entry.staffAvatar != null ? NetworkImage(entry.staffAvatar!) : null,
                child: entry.staffAvatar == null
                    ? Text(
                        entry.staffName.isNotEmpty ? entry.staffName[0].toUpperCase() : '?',
                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
              const SizedBox(width: AppConstants.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.staffName,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    if (entry.staffRole != null)
                      Text(
                        _roleLabel(entry.staffRole),
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (entry.isPaid ? AppColors.success : AppColors.warning).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                ),
                child: Text(
                  entry.isPaid ? 'Оплачено' : 'Не оплачено',
                  style: TextStyle(
                    color: entry.isPaid ? AppColors.success : AppColors.warning,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingMd),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: AppConstants.spacingSm),
          Row(
            children: [
              _PayrollItem(label: 'Оклад', value: '${entry.baseSalary.toStringAsFixed(0)} TJS'),
              _PayrollItem(label: 'Комиссия', value: '${entry.commission.toStringAsFixed(0)} TJS'),
              _PayrollItem(
                label: 'Итого',
                value: '${entry.totalAmount.toStringAsFixed(0)} TJS',
                isBold: true,
              ),
            ],
          ),
          if (entry.adjustments.isNotEmpty) ...[
            const SizedBox(height: AppConstants.spacingSm),
            ...entry.adjustments.map((adj) => Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Icon(
                    adj.type == 'BONUS' ? Icons.add_circle_outline : Icons.remove_circle_outline,
                    size: 14,
                    color: adj.type == 'BONUS' ? AppColors.success : AppColors.error,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      adj.description,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
                  Text(
                    '${adj.type == 'BONUS' ? '+' : '-'}${adj.amount.toStringAsFixed(0)} TJS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: adj.type == 'BONUS' ? AppColors.success : AppColors.error,
                    ),
                  ),
                ],
              ),
            )),
          ],
          if (!entry.isPaid && onPay != null) ...[
            const SizedBox(height: AppConstants.spacingSm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onPay,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                  ),
                ),
                child: const Text('Выплатить'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PayrollItem extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;

  const _PayrollItem({required this.label, required this.value, this.isBold = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              fontSize: isBold ? 15 : 13,
              color: isBold ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
