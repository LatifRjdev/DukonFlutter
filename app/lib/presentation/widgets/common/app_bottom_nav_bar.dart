import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

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
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textSecondary,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Главная'),
        BottomNavigationBarItem(icon: Icon(Icons.inventory_2), label: 'Товары'),
        BottomNavigationBarItem(icon: Icon(Icons.point_of_sale), label: 'Касса'),
        BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Финансы'),
        BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: 'Ещё'),
      ],
    );
  }
}
