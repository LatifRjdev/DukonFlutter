import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/constants/app_constants.dart';
import '../common/app_card.dart';

class ProfitSummaryCard extends StatelessWidget {
  final double income;
  final double expenses;
  final double profit;
  final String currency;

  const ProfitSummaryCard({
    super.key,
    required this.income,
    required this.expenses,
    required this.profit,
    this.currency = 'TJS',
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          _buildRow(context, 'Доход', income, AppColors.success),
          const SizedBox(height: AppConstants.spacingSm),
          _buildRow(context, 'Расходы', expenses, AppColors.error),
          const Divider(),
          _buildRow(context, 'Прибыль', profit, profit >= 0 ? AppColors.success : AppColors.error, isBold: true),
        ],
      ),
    );
  }

  Widget _buildRow(BuildContext context, String label, double value, Color color, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(
          fontSize: isBold ? 16 : 14,
          fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
          color: context.textPrimary,
        )),
        Text(
          '${value.toStringAsFixed(2)} $currency',
          style: TextStyle(
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
