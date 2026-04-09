import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';

class MonthSelector extends StatelessWidget {
  final int month;
  final int year;
  final ValueChanged<({int month, int year})> onChanged;

  const MonthSelector({
    super.key,
    required this.month,
    required this.year,
    required this.onChanged,
  });

  static const _monthNames = [
    'Январь',
    'Февраль',
    'Март',
    'Апрель',
    'Май',
    'Июнь',
    'Июль',
    'Август',
    'Сентябрь',
    'Октябрь',
    'Ноябрь',
    'Декабрь',
  ];

  void _previous() {
    if (month == 1) {
      onChanged((month: 12, year: year - 1));
    } else {
      onChanged((month: month - 1, year: year));
    }
  }

  void _next() {
    if (month == 12) {
      onChanged((month: 1, year: year + 1));
    } else {
      onChanged((month: month + 1, year: year));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingSm,
        vertical: AppConstants.spacingXs,
      ),
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        boxShadow: const [
          BoxShadow(color: AppColors.overlay, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: _previous,
            icon: const Icon(Icons.chevron_left, color: AppColors.lightTextPrimary),
          ),
          Text(
            '${_monthNames[month - 1]} $year',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          IconButton(
            onPressed: _next,
            icon: const Icon(Icons.chevron_right, color: AppColors.lightTextPrimary),
          ),
        ],
      ),
    );
  }
}
