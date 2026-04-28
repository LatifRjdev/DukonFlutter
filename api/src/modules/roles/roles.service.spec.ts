import { Test } from '@nestjs/testing';
import { BadRequestException } from '@nestjs/common';
import { RolesService } from './roles.service';
import { PrismaService } from '../../prisma/prisma.service';

type RolePermRow = {
  id: string;
  storeId: string;
  role: 'OWNER' | 'ADMIN' | 'CASHIER' | 'WAREHOUSE';
  permission: string;
  isGranted: boolean;
};

function makePrismaFake() {
  const rows: RolePermRow[] = [];
  let seq = 0;

  const rolePermission = {
    findMany: jest.fn(async ({ where }: any) => {
      return rows
        .filter((r) => {
          if (where.storeId && r.storeId !== where.storeId) return false;
          if (where.role && r.role !== where.role) return false;
          return true;
        })
        .sort((a, b) => {
          if (a.role !== b.role) return a.role.localeCompare(b.role);
          return a.permission.localeCompare(b.permission);
        });
    }),
    count: jest.fn(async ({ where }: any) => {
      return rows.filter((r) => r.storeId === where.storeId).length;
    }),
    createMany: jest.fn(async ({ data }: any) => {
      for (const d of data) {
        rows.push({ id: `rp-${++seq}`, ...d });
      }
      return { count: data.length };
    }),
    upsert: jest.fn(async ({ where, update, create }: any) => {
      const key = where.storeId_role_permission;
      const existing = rows.find(
        (r) =>
          r.storeId === key.storeId &&
          r.role === key.role &&
          r.permission === key.permission,
      );
      if (existing) {
        Object.assign(existing, update);
        return existing;
      }
      const row: RolePermRow = { id: `rp-${++seq}`, ...create };
      rows.push(row);
      return row;
    }),
  };

  return {
    rolePermission,
    $transaction: jest.fn(async (ops: Promise<any>[]) => Promise.all(ops)),
    __rows: rows,
  } as any;
}

describe('RolesService', () => {
  let service: RolesService;
  let prisma: ReturnType<typeof makePrismaFake>;

  beforeEach(async () => {
    prisma = makePrismaFake();
    const moduleRef = await Test.createTestingModule({
      providers: [
        RolesService,
        { provide: PrismaService, useValue: prisma },
      ],
    }).compile();
    service = moduleRef.get(RolesService);
  });

  describe('getAllRoles — default permission flag math', () => {
    it('should grant manage_staff only to OWNER (not ADMIN/CASHIER/WAREHOUSE) by default', async () => {
      const all = await service.getAllRoles('store-A');
      const byRole = Object.fromEntries(all.map((r) => [r.role, r.permissions]));

      expect(byRole.OWNER.manage_staff).toBe(true);
      expect(byRole.ADMIN.manage_staff).toBe(false);
      expect(byRole.CASHIER.manage_staff).toBe(false);
      expect(byRole.WAREHOUSE.manage_staff).toBe(false);
    });

    it('should give OWNER every permission by default (synthesized, not stored)', async () => {
      const all = await service.getAllRoles('store-A');
      const owner = all.find((r) => r.role === 'OWNER')!;
      const granted = Object.values(owner.permissions);
      expect(granted.every((v) => v === true)).toBe(true);
      // OWNER has no DB rows — only the configurable roles seeded
      const ownerRows = prisma.__rows.filter(
        (r: RolePermRow) => r.role === 'OWNER',
      );
      expect(ownerRows.length).toBe(0);
    });

    it('should give CASHIER no view_profit / no manage_products by default', async () => {
      const all = await service.getAllRoles('store-A');
      const cashier = all.find((r) => r.role === 'CASHIER')!;
      expect(cashier.permissions.view_profit).toBe(false);
      expect(cashier.permissions.manage_products).toBe(false);
      expect(cashier.permissions.create_sales).toBe(true);
    });
  });

  describe('seeding — storeId scoping', () => {
    it('should seed defaults only for the requested store and not leak across stores', async () => {
      await service.getAllRoles('store-A');
      await service.getAllRoles('store-B');

      const aRows = prisma.__rows.filter(
        (r: RolePermRow) => r.storeId === 'store-A',
      );
      const bRows = prisma.__rows.filter(
        (r: RolePermRow) => r.storeId === 'store-B',
      );
      expect(aRows.length).toBeGreaterThan(0);
      expect(bRows.length).toBeGreaterThan(0);
      // Same shape per store, but isolated
      expect(aRows.length).toBe(bRows.length);
    });

    it('should not re-seed when permissions already exist for the store', async () => {
      await service.getAllRoles('store-A');
      const firstSize = prisma.__rows.length;

      await service.getAllRoles('store-A');
      expect(prisma.__rows.length).toBe(firstSize);
    });
  });

  describe('updateRolePermissions', () => {
    it('should reject modifying OWNER permissions with BadRequestException', async () => {
      await expect(
        service.updateRolePermissions('store-A', 'OWNER', {
          permissions: { manage_staff: false },
        }),
      ).rejects.toBeInstanceOf(BadRequestException);
    });

    it('should reject unknown role names with BadRequestException', async () => {
      await expect(
        service.updateRolePermissions('store-A', 'SUPERHERO', {
          permissions: { view_sales: true },
        }),
      ).rejects.toBeInstanceOf(BadRequestException);
    });

    it('should reject unknown permission keys with BadRequestException', async () => {
      await expect(
        service.updateRolePermissions('store-A', 'CASHIER', {
          permissions: { fly_to_moon: true },
        }),
      ).rejects.toBeInstanceOf(BadRequestException);
    });

    it('should flip a permission flag and persist it scoped to the calling store', async () => {
      // Seed both stores first
      await service.getAllRoles('store-A');
      await service.getAllRoles('store-B');

      const updated = await service.updateRolePermissions(
        'store-A',
        'CASHIER',
        { permissions: { cancel_sales: true } },
      );

      expect(updated.permissions.cancel_sales).toBe(true);
      // Store B remained untouched
      const bResult = await service.getRolePermissions('store-B', 'CASHIER');
      expect(bResult.permissions.cancel_sales).toBe(false);
    });
  });

  describe('getRolePermissions', () => {
    it('should return full set for OWNER without seeding the DB', async () => {
      const result = await service.getRolePermissions('store-A', 'OWNER');
      expect(result.role).toBe('OWNER');
      expect(Object.values(result.permissions).every((v) => v === true)).toBe(
        true,
      );
      // No DB seeding triggered for an OWNER-only call
      expect(prisma.__rows.length).toBe(0);
    });
  });
});
