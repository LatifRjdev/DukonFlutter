import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../l10n/app_localizations.dart';

class AppBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AppBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final activeColor = AppColors.primary;
    final inactiveColor = isDark ? AppColors.darkTextHint : AppColors.lightTextHint;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0x0AFFFFFF) : AppColors.lightSurface,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0x0FFFFFFF) : AppColors.lightBorder,
          ),
        ),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom,
        top: 8,
        left: 8,
        right: 8,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(
            icon: Icons.home_outlined,
            activeIcon: Icons.home,
            label: l10n.navHome,
            isActive: currentIndex == 0,
            color: currentIndex == 0 ? activeColor : inactiveColor,
            onTap: () => onTap(0),
          ),
          _NavItem(
            icon: Icons.inventory_2_outlined,
            activeIcon: Icons.inventory_2,
            label: l10n.navProducts,
            isActive: currentIndex == 1,
            color: currentIndex == 1 ? activeColor : inactiveColor,
            onTap: () => onTap(1),
          ),
          _POSButton(
            isActive: currentIndex == 2,
            label: l10n.navPOS,
            onTap: () => onTap(2),
          ),
          _NavItem(
            icon: Icons.bar_chart_outlined,
            activeIcon: Icons.bar_chart,
            label: l10n.navFinance,
            isActive: currentIndex == 3,
            color: currentIndex == 3 ? activeColor : inactiveColor,
            onTap: () => onTap(3),
          ),
          _NavItem(
            icon: Icons.more_horiz,
            activeIcon: Icons.more_horiz,
            label: l10n.navMore,
            isActive: currentIndex == 4,
            color: currentIndex == 4 ? activeColor : inactiveColor,
            onTap: () => onTap(4),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final Color color;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 56,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isActive ? activeIcon : icon, color: color, size: 24),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _POSButton extends StatelessWidget {
  final bool isActive;
  final String label;
  final VoidCallback onTap;

  const _POSButton({
    required this.isActive,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.translate(
            offset: const Offset(0, -16),
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: AppGradients.primary,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppShadows.button,
              ),
              child: const Icon(Icons.point_of_sale, color: Colors.white, size: 24),
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
