import {
  Injectable,
  CanActivate,
  ExecutionContext,
  ForbiddenException,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { PrismaService } from '../../prisma/prisma.service';

const PLAN_HIERARCHY: Record<string, number> = {
  START: 1,
  BUSINESS: 2,
  PREMIUM: 3,
};

export const REQUIRED_PLAN_KEY = 'requiredPlan';
export const REQUIRED_FEATURE_KEY = 'requiredFeature';

@Injectable()
export class SubscriptionGuard implements CanActivate {
  constructor(
    private reflector: Reflector,
    private prisma: PrismaService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest();
    const storeId = request.params?.storeId;

    if (!storeId) {
      return true; // No store context — skip guard
    }

    // F.2: read handler-then-class metadata explicitly. The previous
    // `getAllAndOverride([handler, class])` skipped class-level
    // decorators in some controller configurations, leaving methods
    // ungated when the controller author put @RequiresFeature on
    // the class instead of every method. Explicit lookup avoids the
    // surprise.
    const requiredPlan =
      this.reflector.get<string>(REQUIRED_PLAN_KEY, context.getHandler()) ??
      this.reflector.get<string>(REQUIRED_PLAN_KEY, context.getClass());

    const requiredFeature =
      this.reflector.get<string>(REQUIRED_FEATURE_KEY, context.getHandler()) ??
      this.reflector.get<string>(REQUIRED_FEATURE_KEY, context.getClass());

    // If no subscription requirements, allow
    if (!requiredPlan && !requiredFeature) {
      return true;
    }

    const subscription = await this.prisma.subscription.findUnique({
      where: { storeId },
    });

    if (!subscription) {
      throw new ForbiddenException({
        code: 'SUBSCRIPTION_REQUIRED',
        message: 'No subscription found for this store',
        requiredPlan,
        requiredFeature,
        currentPlan: null,
      });
    }

    // Check status
    if (!['ACTIVE', 'TRIAL'].includes(subscription.status)) {
      throw new ForbiddenException({
        code: 'SUBSCRIPTION_REQUIRED',
        message: `Subscription is ${subscription.status}`,
        requiredPlan,
        requiredFeature,
        currentPlan: subscription.plan,
      });
    }

    // Check plan hierarchy
    if (requiredPlan) {
      const currentLevel = PLAN_HIERARCHY[subscription.plan] ?? 0;
      const requiredLevel = PLAN_HIERARCHY[requiredPlan] ?? 0;
      if (currentLevel < requiredLevel) {
        throw new ForbiddenException({
          code: 'SUBSCRIPTION_REQUIRED',
          message: `This feature requires ${requiredPlan} plan or higher`,
          requiredPlan,
          currentPlan: subscription.plan,
        });
      }
    }

    // Check feature flag
    if (requiredFeature) {
      const planConfig = await this.prisma.subscriptionPlanConfig.findUnique({
        where: { plan: subscription.plan },
      });

      if (!planConfig) {
        throw new ForbiddenException({
          code: 'SUBSCRIPTION_REQUIRED',
          message: 'Plan configuration not found',
          requiredFeature,
          currentPlan: subscription.plan,
        });
      }

      const featureEnabled = (planConfig as any)[requiredFeature];
      if (!featureEnabled) {
        throw new ForbiddenException({
          code: 'SUBSCRIPTION_REQUIRED',
          message: `This feature (${requiredFeature}) is not available on your current plan`,
          requiredFeature,
          currentPlan: subscription.plan,
        });
      }
    }

    return true;
  }
}
