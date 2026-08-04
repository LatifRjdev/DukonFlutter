import 'reflect-metadata';
import { ExecutionContext, ForbiddenException } from '@nestjs/common';
import { GUARDS_METADATA } from '@nestjs/common/constants';
import { Reflector } from '@nestjs/core';
import { EcommerceIntegrationController } from './ecommerce-integration.controller';
import { PermissionsGuard } from '../../common/guards/permissions.guard';
import { PERMISSIONS_KEY } from '../../common/decorators/permissions.decorator';

// Whole-branch review flagged that EcommerceIntegrationController — which
// exposes the plaintext apiKey, lets any caller regenerate it (breaking the
// live integration), and lets any caller repoint outboundWebhookUrl — only
// carried JwtAuthGuard/StoreAccessGuard/SubscriptionGuard, so any active
// staff member (even a cashier) had full access. Fixed by adding
// PermissionsGuard + @Permissions('store.manage') at the class level,
// matching stores.controller.ts's receipt-template routes. These specs
// pin that wiring (metadata-reflection, following the pattern established
// in subscriptions.controller.spec.ts for AuditInterceptor wiring) and
// prove the guard actually rejects an under-permissioned staff member.
describe('EcommerceIntegrationController — permission gating', () => {
  it('carries PermissionsGuard in its class-level @UseGuards stack', () => {
    const guards = Reflect.getMetadata(
      GUARDS_METADATA,
      EcommerceIntegrationController,
    );
    expect(guards).toContain(PermissionsGuard);
  });

  it("carries @Permissions('store.manage') at the class level", () => {
    const permissions = Reflect.getMetadata(
      PERMISSIONS_KEY,
      EcommerceIntegrationController,
    );
    expect(permissions).toEqual(['store.manage']);
  });

  // Exercises the real PermissionsGuard (not a fake) against the actual
  // metadata the controller carries, proving the wiring rejects a CASHIER
  // (who has no store.manage permission in the default matrix — see
  // permissions-matrix.ts) rather than just asserting the decorator is
  // present.
  describe('guard actually rejects an under-permissioned staff member', () => {
    function makeContext(opts: {
      userId: string;
      storeId: string;
    }): ExecutionContext {
      const request = {
        user: { id: opts.userId },
        params: { storeId: opts.storeId },
      };
      return {
        switchToHttp: () => ({ getRequest: () => request }),
        getHandler: () => EcommerceIntegrationController.prototype.getSettings,
        getClass: () => EcommerceIntegrationController,
      } as unknown as ExecutionContext;
    }

    it('rejects a CASHIER staff member with a 403', async () => {
      const prisma = {
        store: {
          findUnique: jest.fn(async () => ({
            id: 'store-1',
            ownerId: 'owner-1',
          })),
        },
        staff: {
          findUnique: jest.fn(async () => ({
            storeId: 'store-1',
            userId: 'cashier-1',
            role: 'CASHIER',
            isActive: true,
          })),
        },
        rolePermission: {
          findMany: jest.fn(async () => []),
        },
      } as any;

      const guard = new PermissionsGuard(new Reflector(), prisma);
      const ctx = makeContext({ userId: 'cashier-1', storeId: 'store-1' });

      await expect(guard.canActivate(ctx)).rejects.toBeInstanceOf(
        ForbiddenException,
      );
    });

    it('allows the store owner through', async () => {
      const prisma = {
        store: {
          findUnique: jest.fn(async () => ({
            id: 'store-1',
            ownerId: 'owner-1',
          })),
        },
        staff: { findUnique: jest.fn(async () => null) },
        rolePermission: { findMany: jest.fn(async () => []) },
      } as any;

      const guard = new PermissionsGuard(new Reflector(), prisma);
      const ctx = makeContext({ userId: 'owner-1', storeId: 'store-1' });

      await expect(guard.canActivate(ctx)).resolves.toBe(true);
    });
  });
});
