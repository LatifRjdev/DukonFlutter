import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../domain/entities/staff_member.dart';
import '../common/app_card.dart';

class StaffCard extends StatelessWidget {
  final StaffMember staff;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const StaffCard({super.key, required this.staff, this.onTap, this.onDelete});

  String _roleLabel(String role) {
    switch (role) {
      case 'OWNER':
        return 'Владелец';
      case 'ADMIN':
        return 'Админ';
      case 'CASHIER':
        return 'Кассир';
      case 'WAREHOUSE':
        return 'Складовщик';
      default:
        return role;
    }
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'OWNER':
        return AppColors.accent;
      case 'ADMIN':
        return AppColors.info;
      case 'CASHIER':
        return AppColors.success;
      case 'WAREHOUSE':
        return AppColors.warning;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final roleColor = _roleColor(staff.role);

    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: roleColor.withValues(alpha: 0.15),
            backgroundImage: staff.avatar != null ? NetworkImage(staff.avatar!) : null,
            child: staff.avatar == null
                ? Text(
                    staff.name.isNotEmpty ? staff.name[0].toUpperCase() : '?',
                    style: TextStyle(color: roleColor, fontWeight: FontWeight.bold, fontSize: 18),
                  )
                : null,
          ),
          const SizedBox(width: AppConstants.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        staff.name,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (staff.isOnShift)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(left: 6),
                        decoration: const BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: roleColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                      ),
                      child: Text(
                        _roleLabel(staff.role),
                        style: TextStyle(color: roleColor, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (staff.phone != null) ...[
                      const SizedBox(width: AppConstants.spacingSm),
                      Text(
                        staff.phone!,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (staff.todaySales != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${staff.todaySales!.toStringAsFixed(0)} TJS',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.success),
                ),
                const Text(
                  'сегодня',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
