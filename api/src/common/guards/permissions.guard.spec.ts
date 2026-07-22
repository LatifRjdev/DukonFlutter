import 'reflect-metadata';
import { ExecutionContext, ForbiddenException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { PermissionsGuard } from './permissions.guard';
import { PERMISSIONS_KEY } from '../decorators/permissions.decorator';

// BE-P1-011: PermissionsGuard is the actual enforcement point for every
// @Permissions(...) route, but until this fix it never actually consulted
// the RolePermission overrides written by RolesService — the guard queried
// for dotted `resource.action` keys while RolesService persists legacy
// snake_case keys (`manage_products`, ...). Revoking/granting a permission
// via `PUT /stores/:id/roles/:role/permissions` therefore looked like it
// worked (200, persisted, reflected on GET) but had zero effect on access.
// These specs exercise the guard directly against a Prisma fake to prove
// the DB override now actually gates the route.

type StoreRow = { id: string; ownerId: string };
type StaffRow = {
  storeId: string;
  userId: string;
  role: 'OWNER' | 'ADMIN' | 'CASHIER' | 'WAREHOUSE';
  isActive: boolean;
};
type RolePermRow = {
  storeId: string;
  role: 'ADMIN' | 'CASHIER' | 'WAREHOUSE';
  permission: string;
  isGranted: boolean;
};

function makePrismaFake(opts: {
  stores?: StoreRow[];
  staff?: StaffRow[];
  rolePermissions?: RolePermRow[];
}) {
  const stores = opts.stores ?? [];
  const staff = opts.staff ?? [];
  const rolePermissions = opts.rolePermissions ?? [];

  return {
    store: {
      findUnique: jest.fn(async ({ where }: any) => {
        return stores.find((s) => s.id === where.id) ?? null;
      }),
    },
    staff: {
      findUnique: jest.fn(async ({ where }: any) => {
        const key = where.storeId_userId;
        return (
          staff.find(
            (s) => s.storeId === key.storeId && s.userId === key.userId,
          ) ?? null
        );
      }),
    },
    rolePermission: {
      findMany: jest.fn(async ({ where }: any) => {
        return rolePermissions.filter((rp) => {
          if (rp.storeId !== where.storeId) return false;
          if (rp.role !== where.role) return false;
          if (
            where.permission?.in &&
            !where.permission.in.includes(rp.permission)
          ) {
            return false;
          }
          return true;
        });
      }),
    },
  } as any;
}

function makeContext(opts: {
  permissions: string[];
  userId?: string;
  storeId?: string;
}): ExecutionContext {
  const handler = function handlerFn() {
    /* noop */
  };
  const cls = class FakeController {};
  Reflect.defineMetadata(PERMISSIONS_KEY, opts.permissions, handler);

  const request = {
    user: opts.userId ? { id: opts.userId } : undefined,
    params: opts.storeId ? { storeId: opts.storeId } : {},
  };

  return {
    switchToHttp: () => ({ getRequest: () => request }),
    getHandler: () => handler,
    getClass: () => cls,
  } as unknown as ExecutionContext;
}

describe('PermissionsGuard', () => {
  let reflector: Reflector;

  beforeEach(() => {
    reflector = new Reflector();
  });

  describe('bug scenario (BE-P1-011): DB overrides must actually gate routes', () => {
    it('blocks WAREHOUSE from products.manage once manage_products is revoked via the Roles API', async () => {
      const prisma = makePrismaFake({
        stores: [{ id: 'store-1', ownerId: 'owner-1' }],
        staff: [
          {
            storeId: 'store-1',
            userId: 'wh-1',
            role: 'WAREHOUSE',
            isActive: true,
          },
        ],
        // This is exactly what RolesService.updateRolePermissions writes
        // when an owner calls PUT /stores/store-1/roles/WAREHOUSE/permissions
        // { "manage_products": false } — WAREHOUSE has products.manage in
        // the hardcoded default matrix, so this DB row must win.
        rolePermissions: [
          {
            storeId: 'store-1',
            role: 'WAREHOUSE',
            permission: 'manage_products',
            isGranted: false,
          },
        ],
      });
      const guard = new PermissionsGuard(reflector, prisma);

      const ctx = makeContext({
        permissions: ['products.manage'],
        userId: 'wh-1',
        storeId: 'store-1',
      });

      await expect(guard.canActivate(ctx)).rejects.toBeInstanceOf(
        ForbiddenException,
      );
    });

    it('allows CASHIER to manage products once manage_products is granted via the Roles API', async () => {
      // CASHIER does NOT have products.manage in the default matrix —
      // this proves a grant can add access the role wouldn't otherwise have.
      const prisma = makePrismaFake({
        stores: [{ id: 'store-1', ownerId: 'owner-1' }],
        staff: [
          {
            storeId: 'store-1',
            userId: 'cash-1',
            role: 'CASHIER',
            isActive: true,
          },
        ],
        rolePermissions: [
          {
            storeId: 'store-1',
            role: 'CASHIER',
            permission: 'manage_products',
            isGranted: true,
          },
        ],
      });
      const guard = new PermissionsGuard(reflector, prisma);

      const ctx = makeContext({
        permissions: ['products.manage'],
        userId: 'cash-1',
        storeId: 'store-1',
      });

      await expect(guard.canActivate(ctx)).resolves.toBe(true);
    });
  });

  describe('OWNER is unaffected', () => {
    it('always allows the store owner regardless of any DB role-permission rows', async () => {
      const prisma = makePrismaFake({
        stores: [{ id: 'store-1', ownerId: 'owner-1' }],
        // No staff row for the owner at all — and even if a WAREHOUSE row
        // denies the permission, it must not matter for the owner.
        rolePermissions: [
          {
            storeId: 'store-1',
            role: 'WAREHOUSE',
            permission: 'manage_products',
            isGranted: false,
          },
        ],
      });
      const guard = new PermissionsGuard(reflector, prisma);

      const ctx = makeContext({
        permissions: ['products.manage', 'products.delete'],
        userId: 'owner-1',
        storeId: 'store-1',
      });

      await expect(guard.canActivate(ctx)).resolves.toBe(true);
      expect(prisma.rolePermission.findMany).not.toHaveBeenCalled();
    });

    it('always allows a staff record with role OWNER', async () => {
      const prisma = makePrismaFake({
        stores: [{ id: 'store-1', ownerId: 'someone-else' }],
        staff: [
          {
            storeId: 'store-1',
            userId: 'owner-staff-1',
            role: 'OWNER',
            isActive: true,
          },
        ],
      });
      const guard = new PermissionsGuard(reflector, prisma);

      const ctx = makeContext({
        permissions: ['roles.manage'],
        userId: 'owner-staff-1',
        storeId: 'store-1',
      });

      await expect(guard.canActivate(ctx)).resolves.toBe(true);
    });
  });

  describe('fallback to the hardcoded default matrix when no DB override exists', () => {
    it('allows ADMIN to manage products with no RolePermission rows at all', async () => {
      const prisma = makePrismaFake({
        stores: [{ id: 'store-1', ownerId: 'owner-1' }],
        staff: [
          {
            storeId: 'store-1',
            userId: 'admin-1',
            role: 'ADMIN',
            isActive: true,
          },
        ],
        rolePermissions: [],
      });
      const guard = new PermissionsGuard(reflector, prisma);

      const ctx = makeContext({
        permissions: ['products.manage'],
        userId: 'admin-1',
        storeId: 'store-1',
      });

      await expect(guard.canActivate(ctx)).resolves.toBe(true);
    });

    it('falls back to the matrix for a permission not mentioned by any DB row, even when other rows exist for the role', async () => {
      const prisma = makePrismaFake({
        stores: [{ id: 'store-1', ownerId: 'owner-1' }],
        staff: [
          {
            storeId: 'store-1',
            userId: 'wh-1',
            role: 'WAREHOUSE',
            isActive: true,
          },
        ],
        // Only manage_products has an override; suppliers.manage has none.
        rolePermissions: [
          {
            storeId: 'store-1',
            role: 'WAREHOUSE',
            permission: 'manage_products',
            isGranted: false,
          },
        ],
      });
      const guard = new PermissionsGuard(reflector, prisma);

      const ctx = makeContext({
        permissions: ['suppliers.manage'],
        userId: 'wh-1',
        storeId: 'store-1',
      });

      // WAREHOUSE has suppliers.manage in the default matrix.
      await expect(guard.canActivate(ctx)).resolves.toBe(true);
    });
  });

  describe('default-matrix denial still holds (QA report contrast test)', () => {
    it('denies WAREHOUSE products.delete by default (not in the matrix, no legacy alias exists to override it)', async () => {
      const prisma = makePrismaFake({
        stores: [{ id: 'store-1', ownerId: 'owner-1' }],
        staff: [
          {
            storeId: 'store-1',
            userId: 'wh-1',
            role: 'WAREHOUSE',
            isActive: true,
          },
        ],
      });
      const guard = new PermissionsGuard(reflector, prisma);

      const ctx = makeContext({
        permissions: ['products.delete'],
        userId: 'wh-1',
        storeId: 'store-1',
      });

      await expect(guard.canActivate(ctx)).rejects.toBeInstanceOf(
        ForbiddenException,
      );
    });
  });

  describe('products.viewProfitability (new permission)', () => {
    it('allows ADMIN by default-matrix fallback (no DB override needed)', async () => {
      const prisma = makePrismaFake({
        stores: [{ id: 'store-1', ownerId: 'owner-1' }],
        staff: [
          { storeId: 'store-1', userId: 'admin-1', role: 'ADMIN', isActive: true },
        ],
      });
      const guard = new PermissionsGuard(reflector, prisma);
      const ctx = makeContext({
        permissions: ['products.viewProfitability'],
        userId: 'admin-1',
        storeId: 'store-1',
      });

      await expect(guard.canActivate(ctx)).resolves.toBe(true);
    });

    it('denies WAREHOUSE by default (it has products.manage but not products.viewProfitability)', async () => {
      const prisma = makePrismaFake({
        stores: [{ id: 'store-1', ownerId: 'owner-1' }],
        staff: [
          { storeId: 'store-1', userId: 'wh-1', role: 'WAREHOUSE', isActive: true },
        ],
      });
      const guard = new PermissionsGuard(reflector, prisma);
      const ctx = makeContext({
        permissions: ['products.viewProfitability'],
        userId: 'wh-1',
        storeId: 'store-1',
      });

      await expect(guard.canActivate(ctx)).rejects.toBeInstanceOf(ForbiddenException);
    });

    it('denies CASHIER by default', async () => {
      const prisma = makePrismaFake({
        stores: [{ id: 'store-1', ownerId: 'owner-1' }],
        staff: [
          { storeId: 'store-1', userId: 'cash-1', role: 'CASHIER', isActive: true },
        ],
      });
      const guard = new PermissionsGuard(reflector, prisma);
      const ctx = makeContext({
        permissions: ['products.viewProfitability'],
        userId: 'cash-1',
        storeId: 'store-1',
      });

      await expect(guard.canActivate(ctx)).rejects.toBeInstanceOf(ForbiddenException);
    });
  });

  describe('unauthenticated / no store context', () => {
    it('throws when there is no authenticated user', async () => {
      const prisma = makePrismaFake({});
      const guard = new PermissionsGuard(reflector, prisma);

      const ctx = makeContext({
        permissions: ['products.manage'],
        storeId: 'store-1',
      });

      await expect(guard.canActivate(ctx)).rejects.toBeInstanceOf(
        ForbiddenException,
      );
    });

    it('allows the request through when the route has no @Permissions decorator', async () => {
      const prisma = makePrismaFake({});
      const guard = new PermissionsGuard(reflector, prisma);

      const ctx = makeContext({ permissions: [] });

      await expect(guard.canActivate(ctx)).resolves.toBe(true);
    });
  });
});
