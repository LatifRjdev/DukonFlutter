import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/constants/app_constants.dart';

class SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Color? iconColor;

  const SettingsTile({super.key, required this.icon, required this.title, this.subtitle, this.onTap, this.trailing, this.iconColor});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: (iconColor ?? AppColors.primary).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        ),
        child: Icon(icon, color: iconColor ?? AppColors.primary, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
      subtitle: subtitle != null ? Text(subtitle!, style: TextStyle(fontSize: 12, color: context.textSecondary)) : null,
      trailing: trailing ?? Icon(Icons.chevron_right, color: context.textSecondary),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingMd, vertical: 2),
    );
  }
}
