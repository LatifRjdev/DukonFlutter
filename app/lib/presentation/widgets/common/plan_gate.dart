import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/router/route_names.dart';
import '../../blocs/subscription/subscription_bloc.dart';
import '../../blocs/subscription/subscription_state.dart';

/// Gates a widget behind a subscription feature flag.
///
/// Reads [SubscriptionBloc] from context. If the feature is available,
/// [child] is shown. If not, [lockedChild] is shown (or a default lock
/// overlay). Tapping the lock overlay navigates to [SubscriptionPage].
class PlanGate extends StatelessWidget {
  final String feature; // key matching SubscriptionFeatures field
  final Widget child;
  final Widget? lockedChild;

  const PlanGate({
    super.key,
    required this.feature,
    required this.child,
    this.lockedChild,
  });

  String _requiredPlan(String feature) {
    switch (feature) {
      case 'hasReportsAll':
      case 'hasTelegram':
      case 'hasDelivery':
      case 'hasInventory':
      case 'hasAllPush':
        return 'BUSINESS';
      case 'hasExport':
        return 'PREMIUM';
      default:
        return 'BUSINESS';
    }
  }

  String _planDisplayName(String plan) {
    switch (plan) {
      case 'BUSINESS':
        return 'Бизнес';
      case 'PREMIUM':
        return 'Премиум';
      default:
        return plan;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SubscriptionBloc, SubscriptionState>(
      builder: (context, state) {
        // If subscription is not yet loaded, show child (fail-open while loading)
        if (state is! SubscriptionLoaded) {
          return child;
        }

        final hasAccess = state.features.hasFeature(feature);
        if (hasAccess) return child;

        // Show locked state
        if (lockedChild != null) return lockedChild!;

        return _DefaultLockedOverlay(
          requiredPlan: _planDisplayName(_requiredPlan(feature)),
          child: child,
        );
      },
    );
  }
}

class _DefaultLockedOverlay extends StatelessWidget {
  final Widget child;
  final String requiredPlan;

  const _DefaultLockedOverlay({
    required this.child,
    required this.requiredPlan,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(RouteNames.subscription),
      child: Stack(
        children: [
          // Underlying widget (blurred/dimmed)
          IgnorePointer(child: Opacity(opacity: 0.3, child: child)),

          // Lock overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_outline_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Доступно в $requiredPlan',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
