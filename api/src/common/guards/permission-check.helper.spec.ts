import { checkStaffPermission } from './permission-check.helper';

// Direct unit tests for checkStaffPermission() itself, independent of
// PermissionsGuard/HTTP layer — this helper's whole reason for existing is
// to be callable directly (e.g. from ProductsService to decide whether to
// include a profitability field), so it needs its own coverage rather than
// relying solely on the guard's route-level specs.

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

describe('checkStaffPermission', () => {
  it('returns true immediately for an empty requiredPermissions array', async () => {
    const prisma = makePrismaFake({});

    await expect(
      checkStaffPermission(prisma, 'store-1', 'user-1', []),
    ).resolves.toBe(true);
    expect(prisma.store.findUnique).not.toHaveBeenCalled();
  });

  it('short-circuits to true for the store owner, regardless of staff/DB state', async () => {
    const prisma = makePrismaFake({
      stores: [{ id: 'store-1', ownerId: 'owner-1' }],
      rolePermissions: [
        {
          storeId: 'store-1',
          role: 'WAREHOUSE',
          permission: 'manage_products',
          isGranted: false,
        },
      ],
    });

    await expect(
      checkStaffPermission(prisma, 'store-1', 'owner-1', [
        'products.manage',
        'products.delete',
      ]),
    ).resolves.toBe(true);
    expect(prisma.staff.findUnique).not.toHaveBeenCalled();
  });

  it('short-circuits to true for a staff record with role OWNER', async () => {
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

    await expect(
      checkStaffPermission(prisma, 'store-1', 'owner-staff-1', [
        'roles.manage',
      ]),
    ).resolves.toBe(true);
    expect(prisma.rolePermission.findMany).not.toHaveBeenCalled();
  });

  it('returns false when there is no staff record for the user at this store', async () => {
    const prisma = makePrismaFake({
      stores: [{ id: 'store-1', ownerId: 'owner-1' }],
      staff: [],
    });

    await expect(
      checkStaffPermission(prisma, 'store-1', 'stranger-1', [
        'products.view',
      ]),
    ).resolves.toBe(false);
  });

  it('returns false when the staff record is inactive', async () => {
    const prisma = makePrismaFake({
      stores: [{ id: 'store-1', ownerId: 'owner-1' }],
      staff: [
        {
          storeId: 'store-1',
          userId: 'wh-1',
          role: 'WAREHOUSE',
          isActive: false,
        },
      ],
    });

    await expect(
      checkStaffPermission(prisma, 'store-1', 'wh-1', ['products.view']),
    ).resolves.toBe(false);
  });

  it('returns true when a DB RolePermission row grants a permission not in the default matrix', async () => {
    // CASHIER does not have products.manage in the default matrix.
    const prisma = makePrismaFake({
      stores: [{ id: 'store-1', ownerId: 'owner-1' }],
      staff: [
        { storeId: 'store-1', userId: 'cash-1', role: 'CASHIER', isActive: true },
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

    await expect(
      checkStaffPermission(prisma, 'store-1', 'cash-1', ['products.manage']),
    ).resolves.toBe(true);
  });

  it('returns false when a DB RolePermission row revokes a permission the default matrix would otherwise grant', async () => {
    // WAREHOUSE has products.manage in the default matrix.
    const prisma = makePrismaFake({
      stores: [{ id: 'store-1', ownerId: 'owner-1' }],
      staff: [
        { storeId: 'store-1', userId: 'wh-1', role: 'WAREHOUSE', isActive: true },
      ],
      rolePermissions: [
        {
          storeId: 'store-1',
          role: 'WAREHOUSE',
          permission: 'manage_products',
          isGranted: false,
        },
      ],
    });

    await expect(
      checkStaffPermission(prisma, 'store-1', 'wh-1', ['products.manage']),
    ).resolves.toBe(false);
  });

  it('falls back to the default matrix when no DB row mentions the permission', async () => {
    const prisma = makePrismaFake({
      stores: [{ id: 'store-1', ownerId: 'owner-1' }],
      staff: [
        { storeId: 'store-1', userId: 'admin-1', role: 'ADMIN', isActive: true },
      ],
      rolePermissions: [],
    });

    await expect(
      checkStaffPermission(prisma, 'store-1', 'admin-1', [
        'products.viewProfitability',
      ]),
    ).resolves.toBe(true);
  });

  it('falls back to the default matrix (deny) when no DB row mentions the permission and the role lacks it', async () => {
    const prisma = makePrismaFake({
      stores: [{ id: 'store-1', ownerId: 'owner-1' }],
      staff: [
        { storeId: 'store-1', userId: 'wh-1', role: 'WAREHOUSE', isActive: true },
      ],
      rolePermissions: [],
    });

    await expect(
      checkStaffPermission(prisma, 'store-1', 'wh-1', [
        'products.viewProfitability',
      ]),
    ).resolves.toBe(false);
  });
});
