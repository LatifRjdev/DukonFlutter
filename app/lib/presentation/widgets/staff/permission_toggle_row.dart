import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/constants/app_constants.dart';
import 'package:dukonpro/l10n/app_localizations.dart';

class PermissionToggleRow extends StatelessWidget {
  final String permissionKey;
  final String label;
  final String? description;
  final bool value;
  final bool enabled;
  final ValueChanged<bool>? onChanged;

  const PermissionToggleRow({
    super.key,
    required this.permissionKey,
    required this.label,
    this.description,
    required this.value,
    this.enabled = true,
    this.onChanged,
  });

  static String permissionLabel(BuildContext context, String key) {
    final l10n = AppLocalizations.of(context)!;
    switch (key) {
      case 'manage_products':
        return l10n.manageProducts;
      case 'manage_sales':
        return l10n.sales;
      case 'manage_returns':
        return l10n.returns;
      case 'view_reports':
        return l10n.viewReports;
      case 'manage_staff':
        return l10n.permissionManageStaffLabel;
      case 'manage_expenses':
        return l10n.permissionManageExpensesLabel;
      case 'manage_customers':
        return l10n.permissionManageCustomersLabel;
      case 'manage_suppliers':
        return l10n.permissionManageSuppliersLabel;
      case 'manage_stock':
        return l10n.permissionManageStockLabel;
      case 'manage_debts':
        return l10n.permissionManageDebtsLabel;
      case 'manage_settings':
        return l10n.permissionManageSettingsLabel;
      case 'open_close_shift':
        return l10n.permissionOpenCloseShiftLabel;
      case 'apply_discounts':
        return l10n.permissionApplyDiscountsLabel;
      case 'manage_payroll':
        return l10n.permissionManagePayrollLabel;
      default:
        return key;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingMd,
        vertical: AppConstants.spacingXs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: enabled ? context.textPrimary : AppColors.disabled,
                  ),
                ),
                if (description != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      description!,
                      style: TextStyle(fontSize: 12, color: context.textSecondary),
                    ),
                  ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: enabled ? onChanged : null,
            activeTrackColor: AppColors.primary.withValues(alpha: 0.5),
            activeThumbColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}
