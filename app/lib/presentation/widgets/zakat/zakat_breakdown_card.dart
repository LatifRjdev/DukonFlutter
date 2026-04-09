import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../domain/entities/zakat_calculation.dart';
import '../common/app_card.dart';

class ZakatBreakdownCard extends StatelessWidget {
  final ZakatCalculation calculation;

  const ZakatBreakdownCard({super.key, required this.calculation});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Разбивка активов', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: AppConstants.spacingMd),
          _row('Товарные запасы', calculation.stockValue),
          _row('Дебиторская задолженность', calculation.receivables),
          _row('Кредиторская задолженность', -calculation.payables, isNegative: true),
          const Divider(),
          _row('Чистые активы', calculation.netAssets, isBold: true),
          const SizedBox(height: AppConstants.spacingSm),
          _row('Нисаб', calculation.nisabAmount),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Закят (2.5%)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              Text(
                '${calculation.zakatDue.toStringAsFixed(2)} TJS',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: calculation.isAboveNisab ? AppColors.primary : AppColors.textSecondary),
              ),
            ],
          ),
          if (!calculation.isAboveNisab) ...[
            const SizedBox(height: AppConstants.spacingSm),
            const Text('Активы ниже нисаба. Закят не обязателен.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, double value, {bool isBold = false, bool isNegative = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14, fontWeight: isBold ? FontWeight.w600 : FontWeight.normal)),
          Text(
            '${isNegative ? "-" : ""}${value.abs().toStringAsFixed(2)} TJS',
            style: TextStyle(fontSize: 14, fontWeight: isBold ? FontWeight.w600 : FontWeight.w500, color: isNegative ? AppColors.error : AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}
