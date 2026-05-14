import { ExecutionContext, ForbiddenException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import {
  REQUIRED_FEATURE_KEY,
  REQUIRED_PLAN_KEY,
  SubscriptionGuard,
} from './subscription.guard';

// F.2.2: spec coverage for the class-level metadata fallback added in
// F.2.1. SubscriptionGuard now reads @RequiresFeature/@RequiresPlan
// from either the route handler or the controller class — method-level
// wins, class-level acts as a controller-wide default.

type FakeSubscription = {
  storeId: string;
  status: string;
  plan: string;
};

type FakePlanConfig = Record<string, unknown> & { plan: string };

function makeContext(opts: {
  storeId?: string;
  handlerMetadata?: Record<string, unknown>;
  classMetadata?: Record<string, unknown>;
}): ExecutionContext {
  const handler = function handlerFn() {
    /* noop */
  };
  const cls = class FakeController {};

  // Stamp metadata via Reflect so the real Reflector reads it back.
  for (const [key, value] of Object.entries(opts.handlerMetadata ?? {})) {
    Reflect.defineMetadata(key, value, handler);
  }
  for (const [key, value] of Object.entries(opts.classMetadata ?? {})) {
    Reflect.defineMetadata(key, value, cls);
  }

  const request = { params: opts.storeId ? { storeId: opts.storeId } : {} };

  return {
    switchToHttp: () => ({
      getRequest: () => request,
    }),
    getHandler: () => handler,
    getClass: () => cls,
  } as unknown as ExecutionContext;
}

function makePrisma(opts: {
  subscription?: FakeSubscription | null;
  planConfig?: FakePlanConfig | null;
}): {
  subscription: { findUnique: jest.Mock };
  subscriptionPlanConfig: { findUnique: jest.Mock };
} {
  return {
    subscription: {
      findUnique: jest.fn().mockResolvedValue(opts.subscription ?? null),
    },
    subscriptionPlanConfig: {
      findUnique: jest.fn().mockResolvedValue(opts.planConfig ?? null),
    },
  };
}

describe('SubscriptionGuard', () => {
  let reflector: Reflector;

  beforeEach(() => {
    reflector = new Reflector();
  });

  it('falls back to class-level metadata when method has no decorator', async () => {
    // Class declares @RequiresFeature('reports'); method has no decorator.
    // Subscription is ACTIVE on PREMIUM plan with reports enabled —
    // guard should grant access using class-level metadata.
    const prisma = makePrisma({
      subscription: { storeId: 's1', status: 'ACTIVE', plan: 'PREMIUM' },
      planConfig: { plan: 'PREMIUM', reports: true },
    });
    const guard = new SubscriptionGuard(reflector, prisma as never);

    const ctx = makeContext({
      storeId: 's1',
      handlerMetadata: {},
      classMetadata: { [REQUIRED_FEATURE_KEY]: 'reports' },
    });

    await expect(guard.canActivate(ctx)).resolves.toBe(true);
    expect(prisma.subscriptionPlanConfig.findUnique).toHaveBeenCalledWith({
      where: { plan: 'PREMIUM' },
    });
  });

  it('rejects when class-level feature is not enabled on the current plan', async () => {
    // Class declares @RequiresFeature('reports') but the START plan
    // does not have reports — guard must throw, proving the class-level
    // metadata is actually consulted.
    const prisma = makePrisma({
      subscription: { storeId: 's1', status: 'ACTIVE', plan: 'START' },
      planConfig: { plan: 'START', reports: false },
    });
    const guard = new SubscriptionGuard(reflector, prisma as never);

    const ctx = makeContext({
      storeId: 's1',
      classMetadata: { [REQUIRED_FEATURE_KEY]: 'reports' },
    });

    await expect(guard.canActivate(ctx)).rejects.toBeInstanceOf(
      ForbiddenException,
    );
  });

  it('method-level metadata overrides class-level', async () => {
    // Class says @RequiresPlan('START') (cheap), method says
    // @RequiresPlan('PREMIUM') (expensive). Subscription on BUSINESS
    // satisfies START but not PREMIUM — guard must use the method-level
    // value and reject.
    const prisma = makePrisma({
      subscription: { storeId: 's1', status: 'ACTIVE', plan: 'BUSINESS' },
    });
    const guard = new SubscriptionGuard(reflector, prisma as never);

    const ctx = makeContext({
      storeId: 's1',
      handlerMetadata: { [REQUIRED_PLAN_KEY]: 'PREMIUM' },
      classMetadata: { [REQUIRED_PLAN_KEY]: 'START' },
    });

    await expect(guard.canActivate(ctx)).rejects.toBeInstanceOf(
      ForbiddenException,
    );
  });
});
