import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/constants/app_constants.dart';

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

  static String permissionLabel(String key) {
    switch (key) {
      case 'manage_products':
        return 'Управление товарами';
      case 'manage_sales':
        return 'Продажи';
      case 'manage_returns':
        return 'Возвраты';
      case 'view_reports':
        return 'Просмотр отчётов';
      case 'manage_staff':
        return 'Управление персоналом';
      case 'manage_expenses':
        return 'Управление расходами';
      case 'manage_customers':
        return 'Управление покупателями';
      case 'manage_suppliers':
        return 'Управление поставщиками';
      case 'manage_stock':
        return 'Управление складом';
      case 'manage_debts':
        return 'Управление долгами';
      case 'manage_settings':
        return 'Настройки магазина';
      case 'open_close_shift':
        return 'Открытие/закрытие смены';
      case 'apply_discounts':
        return 'Применение скидок';
      case 'manage_payroll':
        return 'Управление зарплатой';
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
