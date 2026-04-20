import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_extensions.dart';
import '../common/app_card.dart';

class StatSummaryRow extends StatelessWidget {
  final int salesCount;
  final double avgCheck;

  const StatSummaryRow({super.key, required this.salesCount, required this.avgCheck});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AppCard(
            child: Column(
              children: [
                const Icon(Icons.receipt_long, color: AppColors.primary),
                const SizedBox(height: 4),
                Text('$salesCount', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                Text('Продаж', style: TextStyle(fontSize: 12, color: context.textSecondary)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: AppCard(
            child: Column(
              children: [
                const Icon(Icons.trending_up, color: AppColors.primary),
                const SizedBox(height: 4),
                Text(avgCheck.toStringAsFixed(0), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                Text('Средний чек', style: TextStyle(fontSize: 12, color: context.textSecondary)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
