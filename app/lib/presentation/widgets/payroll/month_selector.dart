import 'package:flutter/material.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/constants/app_constants.dart';
import 'package:dukonpro/l10n/app_localizations.dart';

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

  List<String> _monthNames(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return [
      l10n.monthJanuary,
      l10n.monthFebruary,
      l10n.monthMarch,
      l10n.monthApril,
      l10n.monthMay,
      l10n.monthJune,
      l10n.monthJuly,
      l10n.monthAugust,
      l10n.monthSeptember,
      l10n.monthOctober,
      l10n.monthNovember,
      l10n.monthDecember,
    ];
  }

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
        color: context.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        boxShadow: context.elevationSm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: _previous,
            icon: Icon(Icons.chevron_left, color: context.textPrimary),
          ),
          Text(
            '${_monthNames(context)[month - 1]} $year',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          IconButton(
            onPressed: _next,
            icon: Icon(Icons.chevron_right, color: context.textPrimary),
          ),
        ],
      ),
    );
  }
}
