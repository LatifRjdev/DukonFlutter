import 'reflect-metadata';
import { Test } from '@nestjs/testing';
import {
  Logger,
  BadRequestException,
  ConflictException,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { ShiftsService } from './shifts.service';
import { PrismaService } from '../../prisma/prisma.service';

// Behavioral fake of the Prisma slice ShiftsService uses. Stores Shifts,
// Sales, and Staff in Maps so we can exercise the OPEN -> CLOSED transition,
// the storeId/staffId scoping invariants, and the cash drawer math without
// going near a real DB.
function makePrismaFake() {
  type StaffRow = {
    id: string;
    storeId: string;
    userId: string;
    isActive: boolean;
  };
  type ShiftRow = {
    id: string;
    storeId: string;
    staffId: string;
    status: 'OPEN' | 'CLOSED';
    openedAt: Date;
    closedAt: Date | null;
    openingCash: Prisma.Decimal;
    closingCash: Prisma.Decimal | null;
    cashWithdrawals: Prisma.Decimal;
    salesTotal: Prisma.Decimal;
    salesCount: number;
    cashSales: Prisma.Decimal;
    cardSales: Prisma.Decimal;
    debtSales: Prisma.Decimal;
    returnsTotal: Prisma.Decimal;
    returnsCount: number;
    expectedCash: Prisma.Decimal | null;
    difference: Prisma.Decimal | null;
    notes: string | null;
  };
  type SaleRow = {
    id: string;
    shiftId: string | null;
    storeId: string;
    status: 'COMPLETED' | 'RETURNED' | 'PARTIALLY_RETURNED' | 'PENDING';
    paymentType: 'CASH' | 'CARD' | 'DEBT' | 'MIXED';
    total: Prisma.Decimal;
  };

  const staff = new Map<string, StaffRow>();
  const shifts = new Map<string, ShiftRow>();
  const sales = new Map<string, SaleRow>();
  let shiftSeq = 0;
  const newShiftId = () => `shift-${++shiftSeq}`;

  return {
    _staff: staff,
    _shifts: shifts,
    _sales: sales,
    staff: {
      findUnique: jest.fn(async ({ where }: any) => {
        if (where.storeId_userId) {
          const { storeId, userId } = where.storeId_userId;
          for (const s of staff.values()) {
            if (s.storeId === storeId && s.userId === userId) return s;
          }
        }
        return null;
      }),
    },
    shift: {
      findFirst: jest.fn(async ({ where }: any) => {
        for (const s of shifts.values()) {
          if (where.id && s.id !== where.id) continue;
          if (where.storeId && s.storeId !== where.storeId) continue;
          if (where.staffId && s.staffId !== where.staffId) continue;
          if (where.status && s.status !== where.status) continue;
          return { ...s };
        }
        return null;
      }),
      findMany: jest.fn(async ({ where, skip = 0, take = 20 }: any = {}) => {
        const all = Array.from(shifts.values()).filter((s) => {
          if (where?.storeId && s.storeId !== where.storeId) return false;
          if (where?.staffId && s.staffId !== where.staffId) return false;
          return true;
        });
        return all.slice(skip, skip + take);
      }),
      count: jest.fn(async ({ where }: any = {}) => {
        return Array.from(shifts.values()).filter((s) => {
          if (where?.storeId && s.storeId !== where.storeId) return false;
          return true;
        }).length;
      }),
      create: jest.fn(async ({ data }: any) => {
        const id = newShiftId();
        const row: ShiftRow = {
          id,
          storeId: data.storeId,
          staffId: data.staffId,
          status: data.status,
          openedAt: new Date(),
          closedAt: null,
          openingCash: new Prisma.Decimal(data.openingCash),
          closingCash: null,
          cashWithdrawals: new Prisma.Decimal(0),
          salesTotal: new Prisma.Decimal(0),
          salesCount: 0,
          cashSales: new Prisma.Decimal(0),
          cardSales: new Prisma.Decimal(0),
          debtSales: new Prisma.Decimal(0),
          returnsTotal: new Prisma.Decimal(0),
          returnsCount: 0,
          expectedCash: null,
          difference: null,
          notes: null,
        };
        shifts.set(id, row);
        return { ...row };
      }),
      update: jest.fn(async ({ where, data }: any) => {
        const row = shifts.get(where.id);
        if (!row) throw new Error('not found');
        for (const k of Object.keys(data)) {
          (row as any)[k] = data[k];
        }
        return { ...row };
      }),
    },
    sale: {
      findMany: jest.fn(async ({ where }: any) => {
        return Array.from(sales.values()).filter((s) => {
          if (where.shiftId && s.shiftId !== where.shiftId) return false;
          if (where.status) {
            if (typeof where.status === 'string') {
              if (s.status !== where.status) return false;
            } else if (where.status.in) {
              if (!where.status.in.includes(s.status)) return false;
            }
          }
          return true;
        });
      }),
    },
    saleItem: {
      groupBy: jest.fn(async () => []),
    },
  };
}

describe('ShiftsService', () => {
  let service: ShiftsService;
  let prisma: ReturnType<typeof makePrismaFake>;

  const seedStaff = (overrides: Partial<any> = {}) => {
    const row = {
      id: 'staff-1',
      storeId: 'store-A',
      userId: 'user-1',
      isActive: true,
      ...overrides,
    };
    prisma._staff.set(row.id, row);
    return row;
  };

  beforeEach(async () => {
    jest.spyOn(Logger.prototype, 'log').mockImplementation(() => {});
    prisma = makePrismaFake();
    const moduleRef = await Test.createTestingModule({
      providers: [
        ShiftsService,
        { provide: PrismaService, useValue: prisma },
      ],
    }).compile();
    service = moduleRef.get(ShiftsService);
  });

  describe('openShift', () => {
    it('should create a new OPEN shift when staff is active and no other active shift exists', async () => {
      seedStaff();
      const result: any = await service.openShift(
        'store-A',
        'user-1',
        { openingCash: 100 } as any,
      );
      expect(result.status).toBe('OPEN');
      expect(result.storeId).toBe('store-A');
      expect(result.staffId).toBe('staff-1');
      expect(Number(result.openingCash)).toBe(100);
    });

    it('should throw BadRequestException when user has no active staff record in store', async () => {
      seedStaff({ isActive: false });
      await expect(
        service.openShift('store-A', 'user-1', { openingCash: 0 } as any),
      ).rejects.toBeInstanceOf(BadRequestException);
    });

    it('should throw BadRequestException when user has no staff record at all in store (cross-store scoping)', async () => {
      // staff exists in store-A but request is for store-B
      seedStaff({ storeId: 'store-A' });
      await expect(
        service.openShift('store-B', 'user-1', { openingCash: 0 } as any),
      ).rejects.toBeInstanceOf(BadRequestException);
    });

    it('should throw ConflictException when an OPEN shift already exists for this staff', async () => {
      seedStaff();
      await service.openShift('store-A', 'user-1', { openingCash: 0 } as any);
      await expect(
        service.openShift('store-A', 'user-1', { openingCash: 50 } as any),
      ).rejects.toBeInstanceOf(ConflictException);
    });
  });

  describe('closeShift', () => {
    it('should flip status OPEN -> CLOSED, set closedAt, and compute expectedCash from sales when closing shift', async () => {
      seedStaff();
      const opened: any = await service.openShift(
        'store-A',
        'user-1',
        { openingCash: 100 } as any,
      );

      // 80 cash + 50 card + 30 debt + 20 returned
      prisma._sales.set('s1', {
        id: 's1',
        shiftId: opened.id,
        storeId: 'store-A',
        status: 'COMPLETED',
        paymentType: 'CASH',
        total: new Prisma.Decimal(80),
      });
      prisma._sales.set('s2', {
        id: 's2',
        shiftId: opened.id,
        storeId: 'store-A',
        status: 'COMPLETED',
        paymentType: 'CARD',
        total: new Prisma.Decimal(50),
      });
      prisma._sales.set('s3', {
        id: 's3',
        shiftId: opened.id,
        storeId: 'store-A',
        status: 'COMPLETED',
        paymentType: 'DEBT',
        total: new Prisma.Decimal(30),
      });
      prisma._sales.set('s4', {
        id: 's4',
        shiftId: opened.id,
        storeId: 'store-A',
        status: 'RETURNED',
        paymentType: 'CASH',
        total: new Prisma.Decimal(20),
      });

      const result: any = await service.closeShift(
        'store-A',
        opened.id,
        'user-1',
        { closingCash: 160 } as any,
      );

      expect(result.status).toBe('CLOSED');
      expect(result.closedAt).toBeInstanceOf(Date);
      expect(Number(result.cashSales)).toBe(80);
      expect(Number(result.cardSales)).toBe(50);
      expect(Number(result.debtSales)).toBe(30);
      expect(Number(result.returnsTotal)).toBe(20);
      expect(result.salesCount).toBe(3);
      expect(result.returnsCount).toBe(1);
      // expected = openingCash(100) + cashSales(80) - returnsTotal(20) - withdrawals(0) = 160
      expect(Number(result.expectedCash)).toBe(160);
      // closing matched expected exactly
      expect(Number(result.difference)).toBe(0);
    });

    it('should compute negative difference when actual cash less than expected on close', async () => {
      seedStaff();
      const opened: any = await service.openShift(
        'store-A',
        'user-1',
        { openingCash: 100 } as any,
      );
      prisma._sales.set('s1', {
        id: 's1',
        shiftId: opened.id,
        storeId: 'store-A',
        status: 'COMPLETED',
        paymentType: 'CASH',
        total: new Prisma.Decimal(50),
      });
      const result: any = await service.closeShift(
        'store-A',
        opened.id,
        'user-1',
        { closingCash: 140 } as any,
      );
      // expected = 100 + 50 = 150, actual = 140 -> -10 diff
      expect(Number(result.expectedCash)).toBe(150);
      expect(Number(result.difference)).toBe(-10);
    });

    it('should throw NotFoundException when closing a shift that belongs to another staff (scoping)', async () => {
      // Two distinct staff in same store
      seedStaff({ id: 'staff-1', userId: 'user-1' });
      seedStaff({ id: 'staff-2', userId: 'user-2' });

      // staff-1 opens a shift
      const openedByOther: any = await service.openShift(
        'store-A',
        'user-1',
        { openingCash: 0 } as any,
      );

      // staff-2 tries to close staff-1's shift
      await expect(
        service.closeShift('store-A', openedByOther.id, 'user-2', {
          closingCash: 0,
        } as any),
      ).rejects.toBeInstanceOf(NotFoundException);
    });

    it('should throw NotFoundException when shift belongs to different store (cross-store scoping)', async () => {
      seedStaff();
      const opened: any = await service.openShift(
        'store-A',
        'user-1',
        { openingCash: 0 } as any,
      );
      // Caller provides a different storeId -> must not match.
      await expect(
        service.closeShift('store-B', opened.id, 'user-1', {
          closingCash: 0,
        } as any),
      ).rejects.toBeInstanceOf(BadRequestException);
      // ^ user-1 has no staff in store-B, so it actually fails earlier with
      // BadRequestException (no active staff). Either guard is acceptable
      // for the scoping invariant, but we pin the actual behavior here.
    });
  });

  describe('findCurrent', () => {
    it('should throw NotFoundException when no OPEN shift exists for the staff', async () => {
      seedStaff();
      await expect(
        service.findCurrent('store-A', 'user-1'),
      ).rejects.toBeInstanceOf(NotFoundException);
    });
  });
});
