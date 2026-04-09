import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';

class PeriodSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const PeriodSelector({super.key, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final periods = [
      ('day', 'День'),
      ('week', 'Неделя'),
      ('month', 'Месяц'),
      ('year', 'Год'),
    ];

    return Row(
      children: periods.map((p) {
        final isSelected = p.$1 == selected;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(p.$1),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.card,
                borderRadius: BorderRadius.circular(AppConstants.buttonRadius),
              ),
              alignment: Alignment.center,
              child: Text(
                p.$2,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
