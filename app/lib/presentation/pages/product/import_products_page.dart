import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../widgets/common/app_card.dart';

class ImportProductsPage extends StatelessWidget {
  const ImportProductsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Импорт товаров'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.spacingLg),
          child: Column(
            children: [
              const SizedBox(height: 48),
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.upload_file, size: 48, color: AppColors.primary),
              ),
              const SizedBox(height: 24),
              const Text(
                'Скоро',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              const Text(
                'Импорт товаров из Excel и CSV файлов будет доступен в следующем обновлении.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: AppColors.lightTextSecondary, height: 1.5),
              ),
              const SizedBox(height: 32),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.info_outline, color: AppColors.info, size: 20),
                        SizedBox(width: 8),
                        Text('Что будет доступно', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '• Загрузка файлов .xlsx и .csv\n'
                      '• Шаблон для заполнения\n'
                      '• Предварительный просмотр данных\n'
                      '• Массовое создание товаров',
                      style: TextStyle(color: AppColors.lightTextSecondary, height: 1.6),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
