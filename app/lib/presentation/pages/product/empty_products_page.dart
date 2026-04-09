import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../widgets/common/app_button.dart';

class EmptyProductsPage extends StatelessWidget {
  const EmptyProductsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Товары'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.spacingXl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.inventory_2_outlined,
                    size: 56, color: AppColors.primary),
              ),
              const SizedBox(height: 24),
              const Text(
                'Добавьте свой первый товар',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Начните добавлять товары в ваш магазин, чтобы управлять продажами и складом',
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 15, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              AppButton(
                text: 'Добавить товар',
                icon: Icons.add,
                width: 220,
                onPressed: () => context.push('/products/add'),
              ),
              const SizedBox(height: 12),
              AppButton(
                text: 'Импорт из Excel',
                type: AppButtonType.outlined,
                icon: Icons.upload_file,
                width: 220,
                onPressed: () => context.push('/products/import'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
