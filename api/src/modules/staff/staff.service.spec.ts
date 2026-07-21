import 'reflect-metadata';
import { Test } from '@nestjs/testing';
import {
  ConflictException,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import { StaffService } from './staff.service';
import { PrismaService } from '../../prisma/prisma.service';
import { AuditLogService } from '../../common/audit/audit-log.service';

// Behavioral fake. Tracks users, staff, shifts and sales in Maps so tests
// can assert real behavior: storeId scoping, plan-limit enforcement (only
// counting active staff), the auto-provisioned-user flow, and the
// today's-sales / on-shift aggregation StaffService.findAll performs.
function makePrismaFake() {
  type UserRow = {
    id: string;
    phone: string;
    name: string;
    password: string;
    avatar: string | null;
    isActive: boolean;
  };
  type StaffRow = {
    id: string;
    storeId: string;
    userId: string;
    role: 'OWNER' | 'ADMIN' | 'CASHIER' | 'WAREHOUSE';
    salary: number | null;
    commission: number | null;
    isActive: boolean;
    createdAt: Date;
  };
  type ShiftRow = {
    id: string;
    staffId: string;
    status: 'OPEN' | 'CLOSED';
    openedAt: Date;
  };
  type SaleRow = {
    id: string;
    staffId: string;
    total: number;
    status: 'COMPLETED' | 'PENDING';
    createdAt: Date;
  };

  const users = new Map<string, UserRow>();
  const staff = new Map<string, StaffRow>();
  const shifts = new Map<string, ShiftRow>();
  const sales = new Map<string, SaleRow>();
  let userSeq = 0;
  let staffSeq = 0;

  const userSelect = (u: UserRow) => ({
    id: u.id,
    name: u.name,
    phone: u.phone,
    avatar: u.avatar,
  });

  const attachRelations = (s: StaffRow, today: Date, tomorrow: Date) => {
    const user = users.get(s.userId) ?? null;
    const staffShifts = Array.from(shifts.values())
      .filter((sh) => sh.staffId === s.id && sh.status === 'OPEN')
      .slice(0, 1)
      .map((sh) => ({ id: sh.id, openedAt: sh.openedAt, status: sh.status }));
    const staffSales = Array.from(sales.values())
      .filter(
        (sl) =>
          sl.staffId === s.id &&
          sl.status === 'COMPLETED' &&
          sl.createdAt >= today &&
          sl.createdAt < tomorrow,
      )
      .map((sl) => ({ total: sl.total }));
    return {
      ...s,
      user: user ? userSelect(user) : null,
      shifts: staffShifts,
      sales: staffSales,
    };
  };

  return {
    _users: users,
    _staff: staff,
    _shifts: shifts,
    _sales: sales,
    user: {
      findUnique: jest.fn(async ({ where }: any) => {
        if (where.phone) {
          for (const u of users.values()) {
            if (u.phone === where.phone) return { ...u };
          }
          return null;
        }
        if (where.id) return users.get(where.id) ?? null;
        return null;
      }),
      create: jest.fn(async ({ data }: any) => {
        const id = `user-${++userSeq}`;
        const row: UserRow = {
          id,
          phone: data.phone,
          name: data.name,
          password: data.password,
          avatar: null,
          isActive: data.isActive ?? true,
        };
        users.set(id, row);
        return { ...row };
      }),
    },
    staff: {
      findUnique: jest.fn(async ({ where }: any) => {
        if (where.storeId_userId) {
          const { storeId, userId } = where.storeId_userId;
          for (const s of staff.values()) {
            if (s.storeId === storeId && s.userId === userId) return { ...s };
          }
          return null;
        }
        if (where.id) return staff.get(where.id) ?? null;
        return null;
      }),
      findFirst: jest.fn(async ({ where }: any) => {
        for (const s of staff.values()) {
          if (where.id && s.id !== where.id) continue;
          if (where.storeId && s.storeId !== where.storeId) continue;
          const today = new Date();
          today.setHours(0, 0, 0, 0);
          const tomorrow = new Date(today);
          tomorrow.setDate(tomorrow.getDate() + 1);
          return attachRelations(s, today, tomorrow);
        }
        return null;
      }),
      findMany: jest.fn(async ({ where }: any = {}) => {
        const today = new Date();
        today.setHours(0, 0, 0, 0);
        const tomorrow = new Date(today);
        tomorrow.setDate(tomorrow.getDate() + 1);

        const all = Array.from(staff.values()).filter((s) => {
          if (where?.storeId && s.storeId !== where.storeId) return false;
          if (where?.isActive !== undefined && s.isActive !== where.isActive)
            return false;
          if (where?.role && s.role !== where.role) return false;
          if (where?.user?.OR) {
            const user = users.get(s.userId);
            if (!user) return false;
            const matches = where.user.OR.some((cond: any) => {
              if (cond.name?.contains) {
                return user.name
                  .toLowerCase()
                  .includes(cond.name.contains.toLowerCase());
              }
              if (cond.phone?.contains) {
                return user.phone
                  .toLowerCase()
                  .includes(cond.phone.contains.toLowerCase());
              }
              return false;
            });
            if (!matches) return false;
          }
          return true;
        });
        return all
          .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime())
          .map((s) => attachRelations(s, today, tomorrow));
      }),
      count: jest.fn(async ({ where }: any) => {
        return Array.from(staff.values()).filter((s) => {
          if (where?.storeId && s.storeId !== where.storeId) return false;
          if (where?.isActive !== undefined && s.isActive !== where.isActive)
            return false;
          if (where?.role && s.role !== where.role) return false;
          if (where?.id?.not && s.id === where.id.not) return false;
          return true;
        }).length;
      }),
      create: jest.fn(async ({ data }: any) => {
        const id = `staff-${++staffSeq}`;
        const row: StaffRow = {
          id,
          storeId: data.storeId,
          userId: data.userId,
          role: data.role,
          salary: data.salary ?? null,
          commission: data.commission ?? null,
          isActive: true,
          createdAt: new Date(),
        };
        staff.set(id, row);
        const user = users.get(row.userId) ?? null;
        return { ...row, user: user ? userSelect(user) : null };
      }),
      update: jest.fn(async ({ where, data }: any) => {
        const s = staff.get(where.id);
        if (!s) throw new Error('not found');
        for (const k of Object.keys(data)) {
          if (data[k] !== undefined) (s as any)[k] = data[k];
        }
        const user = users.get(s.userId) ?? null;
        return { ...s, user: user ? userSelect(user) : null };
      }),
    },
    // F2.1: plan-limit helper queries subscription + planConfig. Fail-open
    // (null) by default so pre-existing behavior tests are unaffected;
    // individual tests override these to exercise the plan-limit gate.
    subscription: {
      findUnique: jest.fn(async () => null),
    },
    subscriptionPlanConfig: {
      findUnique: jest.fn(async () => null),
    },
  };
}

describe('StaffService', () => {
  let service: StaffService;
  let prisma: ReturnType<typeof makePrismaFake>;
  let audit: { record: jest.Mock };

  const seedUser = (overrides: Partial<any> = {}) => {
    const row = {
      id: 'user-A',
      phone: '+992900111222',
      name: 'Alice',
      password: 'hashed-existing',
      avatar: null,
      isActive: true,
      ...overrides,
    };
    prisma._users.set(row.id, row);
    return row;
  };

  const seedStaff = (overrides: Partial<any> = {}) => {
    const row = {
      id: 'staff-A',
      storeId: 'store-A',
      userId: 'user-A',
      role: 'CASHIER' as const,
      salary: null,
      commission: null,
      isActive: true,
      createdAt: new Date(),
      ...overrides,
    };
    prisma._staff.set(row.id, row);
    return row;
  };

  beforeEach(async () => {
    prisma = makePrismaFake();
    audit = { record: jest.fn() };
    const moduleRef = await Test.createTestingModule({
      providers: [
        StaffService,
        { provide: PrismaService, useValue: prisma },
        { provide: AuditLogService, useValue: audit },
      ],
    }).compile();
    service = moduleRef.get(StaffService);
  });

  describe('create', () => {
    it('should auto-provision an inactive user with a random (non-phone) password when phone is not registered', async () => {
      const result = await service.create('store-A', {
        name: 'New Guy',
        phone: '+992911000000',
        role: 'CASHIER',
      } as any);

      const createdUser = Array.from(prisma._users.values())[0];
      expect(createdUser).toBeDefined();
      expect(createdUser.isActive).toBe(false);
      // BE-P0-001 regression guard: password must never equal the phone
      // number (that previously allowed anyone who knew the phone to log
      // in and take the account over).
      expect(createdUser.password).not.toBe('+992911000000');
      expect(createdUser.password.length).toBeGreaterThan(20);
      expect(result.storeId).toBe('store-A');
      expect(result.role).toBe('CASHIER');
    });

    it('should reuse the existing user record (without touching its password) when phone is already registered', async () => {
      const existing = seedUser({ phone: '+992900111222' });

      await service.create('store-A', {
        name: 'Alice Clone',
        phone: '+992900111222',
        role: 'ADMIN',
      } as any);

      expect(prisma.user.create).not.toHaveBeenCalled();
      expect(prisma._users.get('user-A')!.password).toBe(existing.password);
    });

    it('should throw ConflictException when the user is already an active staff member of this store', async () => {
      seedUser();
      seedStaff({ storeId: 'store-A', userId: 'user-A' });

      await expect(
        service.create('store-A', {
          name: 'Alice',
          phone: '+992900111222',
          role: 'ADMIN',
        } as any),
      ).rejects.toBeInstanceOf(ConflictException);
    });

    it('should allow the same user to be staffed in a different store when scoping is per-store', async () => {
      seedUser();
      seedStaff({ storeId: 'store-A', userId: 'user-A' });

      const result = await service.create('store-B', {
        name: 'Alice',
        phone: '+992900111222',
        role: 'CASHIER',
      } as any);

      expect(result.storeId).toBe('store-B');
    });

    it('should throw ForbiddenException when the store is at its plan maxStaff limit', async () => {
      seedStaff({ id: 'staff-owner', storeId: 'store-A', userId: 'owner-1' });
      prisma.subscription.findUnique.mockResolvedValue({
        plan: 'START',
      } as any);
      prisma.subscriptionPlanConfig.findUnique.mockResolvedValue({
        maxStaff: 1,
      } as any);

      await expect(
        service.create('store-A', {
          name: 'New Cashier',
          phone: '+992911000000',
          role: 'CASHIER',
        } as any),
      ).rejects.toBeInstanceOf(ForbiddenException);

      // Nothing should have been created on the rejected attempt.
      expect(prisma._users.size).toBe(0);
    });

    it('should exclude soft-removed (isActive=false) staff from the plan-limit headcount', async () => {
      seedStaff({
        id: 'staff-old',
        storeId: 'store-A',
        userId: 'old-user',
        isActive: false,
      });
      prisma.subscription.findUnique.mockResolvedValue({
        plan: 'START',
      } as any);
      prisma.subscriptionPlanConfig.findUnique.mockResolvedValue({
        maxStaff: 1,
      } as any);

      // Only 0 active staff exist, so this create (bringing count to 1)
      // must be allowed even though a deactivated row also exists.
      const result = await service.create('store-A', {
        name: 'New Cashier',
        phone: '+992911000000',
        role: 'CASHIER',
      } as any);

      expect(result.storeId).toBe('store-A');
    });

    it('should allow unlimited staff when plan limit is -1', async () => {
      for (let i = 0; i < 5; i++) {
        seedStaff({
          id: `staff-${i}`,
          storeId: 'store-A',
          userId: `existing-user-${i}`,
        });
      }
      prisma.subscription.findUnique.mockResolvedValue({
        plan: 'PREMIUM',
      } as any);
      prisma.subscriptionPlanConfig.findUnique.mockResolvedValue({
        maxStaff: -1,
      } as any);

      await expect(
        service.create('store-A', {
          name: 'Another One',
          phone: '+992911000099',
          role: 'CASHIER',
        } as any),
      ).resolves.toBeDefined();
    });
  });

  describe('findAll (scoping + aggregation)', () => {
    it('should only return active staff scoped to the requested store', async () => {
      seedUser({ id: 'user-A', phone: '+992900111222', name: 'Alice' });
      seedStaff({ id: 'staff-A', storeId: 'store-A', userId: 'user-A' });
      seedStaff({
        id: 'staff-B',
        storeId: 'store-B',
        userId: 'user-A',
        isActive: true,
      });
      seedStaff({
        id: 'staff-C',
        storeId: 'store-A',
        userId: 'user-A',
        isActive: false,
      });

      const result = await service.findAll('store-A');
      expect(result.map((s: any) => s.id)).toEqual(['staff-A']);
    });

    it('should filter by role when a role query param is provided', async () => {
      seedUser({ id: 'user-A' });
      seedUser({ id: 'user-B', phone: '+992900333444', name: 'Bob' });
      seedStaff({
        id: 'staff-A',
        storeId: 'store-A',
        userId: 'user-A',
        role: 'ADMIN',
      });
      seedStaff({
        id: 'staff-B',
        storeId: 'store-A',
        userId: 'user-B',
        role: 'CASHIER',
      });

      const result = await service.findAll('store-A', undefined, 'CASHIER');
      expect(result.map((s: any) => s.id)).toEqual(['staff-B']);
    });

    it('should filter by search matching user name or phone', async () => {
      seedUser({ id: 'user-A', name: 'Alice', phone: '+992900111222' });
      seedUser({ id: 'user-B', name: 'Bob', phone: '+992900333444' });
      seedStaff({ id: 'staff-A', storeId: 'store-A', userId: 'user-A' });
      seedStaff({ id: 'staff-B', storeId: 'store-A', userId: 'user-B' });

      const result = await service.findAll('store-A', 'alice');
      expect(result.map((s: any) => s.id)).toEqual(['staff-A']);
    });

    it('should surface top-level name/phone from the related user row', async () => {
      seedUser({ id: 'user-A', name: 'Alice', phone: '+992900111222' });
      seedStaff({ id: 'staff-A', storeId: 'store-A', userId: 'user-A' });

      const [result] = await service.findAll('store-A');
      expect(result.name).toBe('Alice');
      expect(result.phone).toBe('+992900111222');
    });

    it('should report isOnShift=true and expose currentShift when staff has an OPEN shift', async () => {
      seedUser({ id: 'user-A' });
      seedStaff({ id: 'staff-A', storeId: 'store-A', userId: 'user-A' });
      prisma._shifts.set('shift-1', {
        id: 'shift-1',
        staffId: 'staff-A',
        status: 'OPEN',
        openedAt: new Date(),
      });

      const [result] = await service.findAll('store-A');
      expect(result.isOnShift).toBe(true);
      expect(result.currentShift).toEqual(
        expect.objectContaining({ id: 'shift-1', status: 'OPEN' }),
      );
    });

    it('should report isOnShift=false and null currentShift when staff has no OPEN shift', async () => {
      seedUser({ id: 'user-A' });
      seedStaff({ id: 'staff-A', storeId: 'store-A', userId: 'user-A' });

      const [result] = await service.findAll('store-A');
      expect(result.isOnShift).toBe(false);
      expect(result.currentShift).toBeNull();
    });

    it("should sum only today's COMPLETED sales into todaySalesCount/todaySalesTotal", async () => {
      seedUser({ id: 'user-A' });
      seedStaff({ id: 'staff-A', storeId: 'store-A', userId: 'user-A' });

      const yesterday = new Date();
      yesterday.setDate(yesterday.getDate() - 1);

      prisma._sales.set('sale-today-1', {
        id: 'sale-today-1',
        staffId: 'staff-A',
        total: 100,
        status: 'COMPLETED',
        createdAt: new Date(),
      });
      prisma._sales.set('sale-today-pending', {
        id: 'sale-today-pending',
        staffId: 'staff-A',
        total: 999,
        status: 'PENDING',
        createdAt: new Date(),
      });
      prisma._sales.set('sale-yesterday', {
        id: 'sale-yesterday',
        staffId: 'staff-A',
        total: 999,
        status: 'COMPLETED',
        createdAt: yesterday,
      });

      const [result] = await service.findAll('store-A');
      expect(result.todaySalesCount).toBe(1);
      expect(result.todaySalesTotal).toBe(100);
    });
  });

  describe('findOne (scoping)', () => {
    it('should throw NotFoundException when staff belongs to a different store', async () => {
      seedUser();
      seedStaff({ id: 'staff-A', storeId: 'store-A' });

      await expect(
        service.findOne('store-B', 'staff-A'),
      ).rejects.toBeInstanceOf(NotFoundException);
    });

    it('should throw NotFoundException when staff id does not exist', async () => {
      await expect(
        service.findOne('store-A', 'does-not-exist'),
      ).rejects.toBeInstanceOf(NotFoundException);
    });

    it('should return the staff record when it belongs to the requested store', async () => {
      seedUser();
      seedStaff({ id: 'staff-A', storeId: 'store-A' });

      const result = await service.findOne('store-A', 'staff-A');
      expect(result.id).toBe('staff-A');
    });
  });

  describe('update', () => {
    it('should update salary and commission when called', async () => {
      seedUser();
      seedStaff({ id: 'staff-A', storeId: 'store-A', salary: 100 });

      const result = await service.update('store-A', 'staff-A', {
        salary: 500,
        commission: 5,
      } as any);

      expect(result.salary).toBe(500);
      expect(result.commission).toBe(5);
    });

    it('should throw NotFoundException when updating staff scoped to a different store', async () => {
      seedUser();
      seedStaff({ id: 'staff-A', storeId: 'store-A' });

      await expect(
        service.update('store-B', 'staff-A', { salary: 500 } as any),
      ).rejects.toBeInstanceOf(NotFoundException);
    });

    it('should record an audit entry with from/to role when the role changes', async () => {
      seedUser();
      seedStaff({ id: 'staff-A', storeId: 'store-A', role: 'CASHIER' });

      await service.update('store-A', 'staff-A', { role: 'ADMIN' } as any);

      expect(audit.record).toHaveBeenCalledWith(
        'system',
        'staff.role_change',
        'staff',
        'staff-A',
        expect.objectContaining({
          from: 'CASHIER',
          to: 'ADMIN',
          storeId: 'store-A',
        }),
      );
    });

    it('should NOT record an audit entry when role is unchanged (only salary/commission updated)', async () => {
      seedUser();
      seedStaff({ id: 'staff-A', storeId: 'store-A', role: 'CASHIER' });

      await service.update('store-A', 'staff-A', { salary: 700 } as any);

      expect(audit.record).not.toHaveBeenCalled();
    });
  });

  describe('remove (soft delete)', () => {
    it('should mark staff isActive=false rather than hard-deleting when remove is called', async () => {
      seedUser();
      seedStaff({ id: 'staff-A', storeId: 'store-A' });

      await service.remove('store-A', 'staff-A');

      expect(prisma._staff.get('staff-A')!.isActive).toBe(false);
      expect(prisma._staff.has('staff-A')).toBe(true);
    });

    it('should throw NotFoundException when removing staff scoped to a different store', async () => {
      seedUser();
      seedStaff({ id: 'staff-A', storeId: 'store-A' });

      await expect(service.remove('store-B', 'staff-A')).rejects.toBeInstanceOf(
        NotFoundException,
      );
      // Untouched — the guard fired before any mutation.
      expect(prisma._staff.get('staff-A')!.isActive).toBe(true);
    });

    it('should throw ForbiddenException when removing the last remaining OWNER of a store', async () => {
      seedUser({ id: 'owner-user' });
      seedStaff({
        id: 'staff-owner',
        storeId: 'store-A',
        userId: 'owner-user',
        role: 'OWNER',
      });

      await expect(
        service.remove('store-A', 'staff-owner'),
      ).rejects.toBeInstanceOf(ForbiddenException);
      expect(prisma._staff.get('staff-owner')!.isActive).toBe(true);
    });

    it('should allow removing an OWNER when another active OWNER remains in the store', async () => {
      seedUser({ id: 'owner-user-1' });
      seedUser({ id: 'owner-user-2', phone: '+992900111333' });
      seedStaff({
        id: 'staff-owner-1',
        storeId: 'store-A',
        userId: 'owner-user-1',
        role: 'OWNER',
      });
      seedStaff({
        id: 'staff-owner-2',
        storeId: 'store-A',
        userId: 'owner-user-2',
        role: 'OWNER',
      });

      await service.remove('store-A', 'staff-owner-1');

      expect(prisma._staff.get('staff-owner-1')!.isActive).toBe(false);
    });

    it('should not count an already-inactive OWNER record as a remaining owner', async () => {
      seedUser({ id: 'owner-user-1' });
      seedUser({ id: 'owner-user-2', phone: '+992900111333' });
      seedStaff({
        id: 'staff-owner-1',
        storeId: 'store-A',
        userId: 'owner-user-1',
        role: 'OWNER',
      });
      seedStaff({
        id: 'staff-owner-2',
        storeId: 'store-A',
        userId: 'owner-user-2',
        role: 'OWNER',
        isActive: false,
      });

      await expect(
        service.remove('store-A', 'staff-owner-1'),
      ).rejects.toBeInstanceOf(ForbiddenException);
    });

    it('should throw ForbiddenException when a staff member tries to remove their own record', async () => {
      seedUser({ id: 'user-A' });
      seedStaff({
        id: 'staff-A',
        storeId: 'store-A',
        userId: 'user-A',
        role: 'CASHIER',
      });

      await expect(
        service.remove('store-A', 'staff-A', 'user-A'),
      ).rejects.toBeInstanceOf(ForbiddenException);
      expect(prisma._staff.get('staff-A')!.isActive).toBe(true);
    });

    it('should allow removal when callerUserId differs from the target staff record', async () => {
      seedUser({ id: 'user-A' });
      seedStaff({
        id: 'staff-A',
        storeId: 'store-A',
        userId: 'user-A',
        role: 'CASHIER',
      });

      await service.remove('store-A', 'staff-A', 'someone-else');

      expect(prisma._staff.get('staff-A')!.isActive).toBe(false);
    });
  });

  describe('update — last-owner guard', () => {
    it('should throw ForbiddenException when downgrading the last remaining OWNER to a non-owner role', async () => {
      seedUser({ id: 'owner-user' });
      seedStaff({
        id: 'staff-owner',
        storeId: 'store-A',
        userId: 'owner-user',
        role: 'OWNER',
      });

      await expect(
        service.update('store-A', 'staff-owner', { role: 'ADMIN' } as any),
      ).rejects.toBeInstanceOf(ForbiddenException);
      expect(prisma._staff.get('staff-owner')!.role).toBe('OWNER');
    });

    it('should allow downgrading an OWNER when another active OWNER remains', async () => {
      seedUser({ id: 'owner-user-1' });
      seedUser({ id: 'owner-user-2', phone: '+992900111333' });
      seedStaff({
        id: 'staff-owner-1',
        storeId: 'store-A',
        userId: 'owner-user-1',
        role: 'OWNER',
      });
      seedStaff({
        id: 'staff-owner-2',
        storeId: 'store-A',
        userId: 'owner-user-2',
        role: 'OWNER',
      });

      await service.update('store-A', 'staff-owner-1', {
        role: 'ADMIN',
      } as any);

      expect(prisma._staff.get('staff-owner-1')!.role).toBe('ADMIN');
    });

    it('should attribute staff.role_change audit entries to the real caller when provided', async () => {
      seedUser({ id: 'user-A' });
      seedStaff({
        id: 'staff-A',
        storeId: 'store-A',
        userId: 'user-A',
        role: 'CASHIER',
      });

      await service.update(
        'store-A',
        'staff-A',
        { role: 'ADMIN' } as any,
        'caller-user-id',
      );

      expect(audit.record).toHaveBeenCalledWith(
        'caller-user-id',
        'staff.role_change',
        'staff',
        'staff-A',
        expect.objectContaining({ from: 'CASHIER', to: 'ADMIN' }),
      );
    });

    it('should fall back to "system" attribution for staff.role_change when no caller is provided', async () => {
      seedUser({ id: 'user-A' });
      seedStaff({
        id: 'staff-A',
        storeId: 'store-A',
        userId: 'user-A',
        role: 'CASHIER',
      });

      await service.update('store-A', 'staff-A', { role: 'ADMIN' } as any);

      expect(audit.record).toHaveBeenCalledWith(
        'system',
        'staff.role_change',
        'staff',
        'staff-A',
        expect.objectContaining({ from: 'CASHIER', to: 'ADMIN' }),
      );
    });
  });
});
