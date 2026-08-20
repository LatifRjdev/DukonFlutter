import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dukonpro/l10n/app_localizations.dart';
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

  List<_OnboardingSlide> _buildSlides(AppLocalizations l10n) => [
        _OnboardingSlide(
          icon: Icons.point_of_sale,
          title: l10n.onboardingTitle2,
          description: l10n.onboardingSalesDesc,
        ),
        _OnboardingSlide(
          icon: Icons.inventory_2,
          title: l10n.onboardingTitle3,
          description: l10n.onboardingInventoryDesc,
        ),
        _OnboardingSlide(
          icon: Icons.analytics,
          title: l10n.onboardingTitle4,
          description: l10n.onboardingAnalyticsDesc,
        ),
        _OnboardingSlide(
          icon: Icons.cloud_sync,
          title: l10n.onboardingOfflineTitle,
          description: l10n.onboardingOfflineDesc,
        ),
      ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final slides = _buildSlides(l10n);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: slides.length,
                itemBuilder: (_, i) => slides[i],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppConstants.spacingLg),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      slides.length,
                      (i) => AnimatedContainer(
                        duration: AppConstants.animationFast,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == i ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == i ? AppColors.primary : context.border,
                          borderRadius: BorderRadius.circular(AppConstants.radiusXs),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  AppButton(
                    text: _currentPage == slides.length - 1 ? l10n.getStarted : l10n.next,
                    onPressed: () {
                      if (_currentPage == slides.length - 1) {
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
                  if (_currentPage < slides.length - 1)
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: Text(l10n.skip),
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
