import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/constants/app_constants.dart';
import '../common/app_card.dart';

class DebtCard extends StatelessWidget {
  final String name;
  final double debt;
  final String? phone;
  final VoidCallback? onTap;
  final bool isSupplier;

  const DebtCard({super.key, required this.name, required this.debt, this.phone, this.onTap, this.isSupplier = false});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: (isSupplier ? Colors.orange : AppColors.primary).withValues(alpha: 0.1),
            child: Icon(isSupplier ? Icons.business : Icons.person, color: isSupplier ? Colors.orange : AppColors.primary, size: 20),
          ),
          const SizedBox(width: AppConstants.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                if (phone != null) Text(phone!, style: TextStyle(fontSize: 12, color: context.textSecondary)),
              ],
            ),
          ),
          Text(
            '${debt.toStringAsFixed(2)} TJS',
            style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.error, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
