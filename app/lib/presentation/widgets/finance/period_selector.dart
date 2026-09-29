import 'package:dukonpro/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/constants/app_constants.dart';

class PeriodSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const PeriodSelector({super.key, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final periods = [
      ('day', l10n.day),
      ('week', l10n.week),
      ('month', l10n.month),
      ('year', l10n.year),
    ];

    return Row(
      children: periods.map((p) {
        final isSelected = p.$1 == selected;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(p.$1),
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(vertical: 10),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : context.surface,
                borderRadius: BorderRadius.circular(AppConstants.radiusLg),
              ),
              alignment: Alignment.center,
              child: Text(
                p.$2,
                style: TextStyle(
                  color: isSelected ? context.onPrimary : context.textSecondary,
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
