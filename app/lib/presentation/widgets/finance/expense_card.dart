import 'package:dukonpro/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/constants/app_constants.dart';
import '../../../domain/entities/expense.dart';
import '../common/app_card.dart';

class ExpenseCard extends StatelessWidget {
  final Expense expense;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const ExpenseCard({super.key, required this.expense, this.onTap, this.onDelete});

  String _categoryLabel(BuildContext context, String category) {
    final l10n = AppLocalizations.of(context)!;
    switch (category) {
      case 'PURCHASE': return l10n.purchase;
      case 'RENT': return l10n.rent;
      case 'SALARY': return l10n.salary;
      case 'UTILITIES': return l10n.utilities;
      case 'TRANSPORT': return l10n.transport;
      case 'MARKETING': return l10n.marketing;
      default: return l10n.other;
    }
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'PURCHASE': return Icons.shopping_cart;
      case 'RENT': return Icons.home;
      case 'SALARY': return Icons.people;
      case 'UTILITIES': return Icons.flash_on;
      case 'TRANSPORT': return Icons.local_shipping;
      case 'MARKETING': return Icons.campaign;
      default: return Icons.receipt;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            ),
            child: Icon(_categoryIcon(expense.category), color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: AppConstants.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_categoryLabel(context, expense.category), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                if (expense.description != null)
                  Text(expense.description!, style: TextStyle(fontSize: 12, color: context.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('-${expense.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.error, fontSize: 14)),
              Text('${expense.date.day}.${expense.date.month}.${expense.date.year}', style: TextStyle(fontSize: 12, color: context.textSecondary)),
            ],
          ),
          if (onDelete != null) ...[
            const SizedBox(width: 4),
            IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error), onPressed: onDelete),
          ],
        ],
      ),
    );
  }
}
