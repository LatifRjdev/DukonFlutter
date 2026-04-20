import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/constants/app_constants.dart';
import '../../widgets/common/app_button.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _pageController = PageController();
  int _currentPage = 0;

  final _slides = const [
    _OnboardingSlide(
      icon: Icons.point_of_sale,
      title: 'Быстрые продажи',
      description: 'Проводите продажи за секунды через удобный POS-интерфейс',
    ),
    _OnboardingSlide(
      icon: Icons.inventory_2,
      title: 'Учёт товаров',
      description: 'Полный контроль склада: приход, расход, остатки в реальном времени',
    ),
    _OnboardingSlide(
      icon: Icons.analytics,
      title: 'Аналитика',
      description: 'Выручка, прибыль и статистика продаж на одном экране',
    ),
    _OnboardingSlide(
      icon: Icons.cloud_sync,
      title: 'Работает офлайн',
      description: 'Продавайте без интернета — данные синхронизируются автоматически',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: _slides.length,
                itemBuilder: (_, i) => _slides[i],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppConstants.spacingLg),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _slides.length,
                      (i) => AnimatedContainer(
                        duration: AppConstants.animationFast,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == i ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == i ? AppColors.primary : context.border,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  AppButton(
                    text: _currentPage == _slides.length - 1 ? 'Начать' : 'Далее',
                    onPressed: () {
                      if (_currentPage == _slides.length - 1) {
                        context.go('/login');
                      } else {
                        _pageController.nextPage(
                          duration: AppConstants.animationNormal,
                          curve: Curves.easeInOut,
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  if (_currentPage < _slides.length - 1)
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: const Text('Пропустить'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingSlide extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _OnboardingSlide({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 60, color: AppColors.primary),
          ),
          const SizedBox(height: 40),
          Text(title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(description,
            style: TextStyle(fontSize: 16, color: context.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
