import 'reflect-metadata';
import { Test } from '@nestjs/testing';
import { BadRequestException, NotFoundException } from '@nestjs/common';
import { PayrollService } from './payroll.service';
import { PrismaService } from '../../prisma/prisma.service';
import { AdjustmentType } from './dto/create-adjustment.dto';

// Behavioral fake: Map-backed storage for payroll periods, payrolls,
// adjustments, staff, sales, and shifts. The fake supports both top-level
// access (prisma.payroll.x) and the transaction callback form
// (prisma.$transaction(async (tx) => ...)) by reusing the same maps.
function makePrismaFake() {
  type Period = {
    id: string;
    storeId: string;
    month: number;
    year: number;
    status: string;
    totalAmount: number;
    paidAmount: number;
  };
  type StaffRow = {
    id: string;
    storeId: string;
    salary: number;
    commission: number;
    isActive: boolean;
    user: { name: string; phone: string; avatar: string | null };
  };
  type PayrollRow = {
    id: string;
    payrollPeriodId: string;
    staffId: string;
    baseSalary: number;
    commission: number;
    commissionRate: number;
    salesTotal: number;
    shiftsWorked: number;
    shiftsExpected: number;
    totalAmount: number;
    isPaid: boolean;
    paidAt: Date | null;
  };
  type AdjRow = {
    id: string;
    payrollId: string;
    type: 'BONUS' | 'DEDUCTION';
    amount: number;
    description: string;
    date: Date;
  };
  type SaleRow = {
    id: string;
    storeId: string;
    staffId: string;
    total: number;
    createdAt: Date;
  };
  type ShiftRow = {
    id: string;
    staffId: string;
    status: 'OPEN' | 'CLOSED';
    openedAt: Date;
  };

  const periods = new Map<string, Period>();
  const staffList = new Map<string, StaffRow>();
  const payrolls = new Map<string, PayrollRow>();
  const adjustments = new Map<string, AdjRow>();
  const sales = new Map<string, SaleRow>();
  const shifts = new Map<string, ShiftRow>();
  let idSeq = 0;
  const newId = (p: string) => `${p}-${++idSeq}`;

  const findPayrollByCompKey = (periodId: string, staffId: string) => {
    for (const p of payrolls.values()) {
      if (p.payrollPeriodId === periodId && p.staffId === staffId) return p;
    }
    return null;
  };

  const inRange = (d: Date, gte?: Date, lt?: Date) => {
    const t = d.getTime();
    if (gte && t < gte.getTime()) return false;
    if (lt && t >= lt.getTime()) return false;
    return true;
  };

  const api: any = {
    _periods: periods,
    _staff: staffList,
    _payrolls: payrolls,
    _adjustments: adjustments,
    _sales: sales,
    _shifts: shifts,
    payrollPeriod: {
      findFirst: jest.fn(async ({ where, include }: any) => {
        for (const p of periods.values()) {
          if (where.id && p.id !== where.id) continue;
          if (where.storeId && p.storeId !== where.storeId) continue;
          if (where.month !== undefined && p.month !== where.month) continue;
          if (where.year !== undefined && p.year !== where.year) continue;
          if (include?.payrolls) {
            const prs = Array.from(payrolls.values()).filter(
              (pr) => pr.payrollPeriodId === p.id,
            );
            return {
              ...p,
              payrolls: prs.map((pr) => ({
                ...pr,
                staff: staffList.get(pr.staffId) ?? null,
                adjustments: Array.from(adjustments.values()).filter(
                  (a) => a.payrollId === pr.id,
                ),
              })),
            };
          }
          return { ...p };
        }
        return null;
      }),
      findMany: jest.fn(async ({ where }: any = {}) =>
        Array.from(periods.values())
          .filter((p) => !where?.storeId || p.storeId === where.storeId)
          .map((p) => ({ ...p, _count: { payrolls: 0 } })),
      ),
      create: jest.fn(async ({ data }: any) => {
        const id = newId('period');
        const p: Period = {
          id,
          storeId: data.storeId,
          month: data.month,
          year: data.year,
          status: data.status ?? 'DRAFT',
          totalAmount: Number(data.totalAmount ?? 0),
          paidAmount: Number(data.paidAmount ?? 0),
        };
        periods.set(id, p);
        return { ...p };
      }),
      update: jest.fn(async ({ where, data }: any) => {
        const p = periods.get(where.id);
        if (!p) throw new Error('not found');
        if (data.totalAmount !== undefined) p.totalAmount = Number(data.totalAmount);
        if (data.paidAmount !== undefined) p.paidAmount = Number(data.paidAmount);
        if (data.status !== undefined) p.status = data.status;
        return { ...p };
      }),
    },
    staff: {
      findMany: jest.fn(async ({ where }: any = {}) =>
        Array.from(staffList.values()).filter((s) => {
          if (where?.storeId && s.storeId !== where.storeId) return false;
          if (where?.isActive !== undefined && s.isActive !== where.isActive)
            return false;
          return true;
        }),
      ),
    },
    shift: {
      count: jest.fn(async ({ where }: any) =>
        Array.from(shifts.values()).filter((s) => {
          if (where.staffId && s.staffId !== where.staffId) return false;
          if (where.status && s.status !== where.status) return false;
          if (
            where.openedAt &&
            !inRange(s.openedAt, where.openedAt.gte, where.openedAt.lt)
          )
            return false;
          return true;
        }).length,
      ),
    },
    sale: {
      aggregate: jest.fn(async ({ where, _sum }: any) => {
        const matched = Array.from(sales.values()).filter((s) => {
          if (where.staffId && s.staffId !== where.staffId) return false;
          if (where.storeId && s.storeId !== where.storeId) return false;
          if (
            where.createdAt &&
            !inRange(s.createdAt, where.createdAt.gte, where.createdAt.lt)
          )
            return false;
          return true;
        });
        return {
          _sum: {
            total: _sum?.total
              ? matched.reduce((acc, m) => acc + Number(m.total), 0)
              : 0,
          },
        };
      }),
    },
    payroll: {
      findFirst: jest.fn(async ({ where, include }: any) => {
        for (const p of payrolls.values()) {
          if (where.id && p.id !== where.id) continue;
          if (where.payrollPeriodId && p.payrollPeriodId !== where.payrollPeriodId)
            continue;
          if (where.staffId && p.staffId !== where.staffId) continue;
          if (include?.adjustments) {
            return {
              ...p,
              adjustments: Array.from(adjustments.values()).filter(
                (a) => a.payrollId === p.id,
              ),
            };
          }
          return { ...p };
        }
        return null;
      }),
      findUnique: jest.fn(async ({ where, include }: any) => {
        const p = payrolls.get(where.id);
        if (!p) return null;
        if (include?.adjustments) {
          return {
            ...p,
            adjustments: Array.from(adjustments.values()).filter(
              (a) => a.payrollId === p.id,
            ),
          };
        }
        return { ...p };
      }),
      findMany: jest.fn(async ({ where }: any = {}) =>
        Array.from(payrolls.values()).filter(
          (p) => !where?.payrollPeriodId || p.payrollPeriodId === where.payrollPeriodId,
        ),
      ),
      upsert: jest.fn(async ({ where, create, update }: any) => {
        const key = where.payrollPeriodId_staffId;
        const existing = findPayrollByCompKey(key.payrollPeriodId, key.staffId);
        if (existing) {
          Object.assign(existing, {
            ...update,
            baseSalary: Number(update.baseSalary),
            commission: Number(update.commission),
            commissionRate: Number(update.commissionRate),
            salesTotal: Number(update.salesTotal),
            totalAmount: Number(update.totalAmount),
          });
          return { ...existing };
        }
        const id = newId('payroll');
        const row: PayrollRow = {
          id,
          payrollPeriodId: create.payrollPeriodId,
          staffId: create.staffId,
          baseSalary: Number(create.baseSalary),
          commission: Number(create.commission),
          commissionRate: Number(create.commissionRate),
          salesTotal: Number(create.salesTotal),
          shiftsWorked: Number(create.shiftsWorked),
          shiftsExpected: Number(create.shiftsExpected ?? 26),
          totalAmount: Number(create.totalAmount),
          isPaid: !!create.isPaid,
          paidAt: null,
        };
        payrolls.set(id, row);
        return { ...row };
      }),
      update: jest.fn(async ({ where, data }: any) => {
        const p = payrolls.get(where.id);
        if (!p) throw new Error('not found');
        if (data.totalAmount !== undefined) p.totalAmount = Number(data.totalAmount);
        if (data.isPaid !== undefined) p.isPaid = data.isPaid;
        if (data.paidAt !== undefined) p.paidAt = data.paidAt;
        return { ...p };
      }),
      updateMany: jest.fn(async ({ where, data }: any) => {
        let updated = 0;
        for (const p of payrolls.values()) {
          if (where.payrollPeriodId && p.payrollPeriodId !== where.payrollPeriodId)
            continue;
          if (where.isPaid !== undefined && p.isPaid !== where.isPaid) continue;
          Object.assign(p, data);
          updated++;
        }
        return { count: updated };
      }),
    },
    payrollAdjustment: {
      create: jest.fn(async ({ data }: any) => {
        const id = newId('adj');
        const row: AdjRow = {
          id,
          payrollId: data.payrollId,
          type: data.type,
          amount: Number(data.amount),
          description: data.description,
          date: data.date ?? new Date(),
        };
        adjustments.set(id, row);
        return { ...row };
      }),
      findFirst: jest.fn(async ({ where }: any) => {
        for (const a of adjustments.values()) {
          if (where.id && a.id !== where.id) continue;
          if (where.payroll?.payrollPeriodId) {
            const p = payrolls.get(a.payrollId);
            if (!p || p.payrollPeriodId !== where.payroll.payrollPeriodId) continue;
          }
          return { ...a };
        }
        return null;
      }),
      delete: jest.fn(async ({ where }: any) => {
        const a = adjustments.get(where.id);
        adjustments.delete(where.id);
        return a;
      }),
    },
    $transaction: jest.fn(async (cb: any) => {
      // Service uses `prisma.$transaction(async (tx) => ...)` form for
      // adjustments / pay flows. Just pass `api` itself as `tx` since both
      // share the same Map-backed storage.
      if (typeof cb === 'function') return cb(api);
      return Promise.all(cb);
    }),
  };

  return api;
}

describe('PayrollService', () => {
  let service: PayrollService;
  let prisma: ReturnType<typeof makePrismaFake>;

  beforeEach(async () => {
    prisma = makePrismaFake();
    const moduleRef = await Test.createTestingModule({
      providers: [
        PayrollService,
        { provide: PrismaService, useValue: prisma },
      ],
    }).compile();
    service = moduleRef.get(PayrollService);
  });

  const seedStaff = (overrides: Partial<any> = {}) => {
    const s = {
      id: overrides.id ?? `staff-${prisma._staff.size + 1}`,
      storeId: 'store-A',
      salary: 5000,
      commission: 10, // 10%
      isActive: true,
      user: { name: 'Alice', phone: '+992900000001', avatar: null },
      ...overrides,
    };
    prisma._staff.set(s.id, s as any);
    return s;
  };

  describe('calculate', () => {
    it('should compute totalAmount as baseSalary + commission when staff has sales in the month', async () => {
      seedStaff({ id: 's1', salary: 1000, commission: 10 });
      // Sale of 5000 in April 2026 — commission = 5000 * 10% = 500
      prisma._sales.set('sale1', {
        id: 'sale1',
        storeId: 'store-A',
        staffId: 's1',
        total: 5000,
        createdAt: new Date('2026-04-15T12:00:00Z'),
      });
      // 2 closed shifts in the month
      prisma._shifts.set('sh1', {
        id: 'sh1',
        staffId: 's1',
        status: 'CLOSED',
        openedAt: new Date('2026-04-02T08:00:00Z'),
      });
      prisma._shifts.set('sh2', {
        id: 'sh2',
        staffId: 's1',
        status: 'CLOSED',
        openedAt: new Date('2026-04-12T08:00:00Z'),
      });

      const period = await service.calculate('store-A', { month: 4, year: 2026 });
      const pr = (period as any).payrolls[0];

      expect(Number(pr.baseSalary)).toBe(1000);
      expect(Number(pr.commission)).toBe(500);
      expect(Number(pr.salesTotal)).toBe(5000);
      expect(Number(pr.shiftsWorked)).toBe(2);
      expect(Number(pr.totalAmount)).toBe(1500);
      expect((period as any).status).toBe('CALCULATED');
    });

    it('should exclude sales outside the month boundaries when computing commission', async () => {
      seedStaff({ id: 's1', salary: 0, commission: 50 });
      // Outside-month sales should not contribute. Service computes month
      // boundaries via `new Date(year, month-1, 1)` (local timezone), so use
      // local-time Date constructors here to dodge timezone ambiguity.
      prisma._sales.set('before', {
        id: 'before',
        storeId: 'store-A',
        staffId: 's1',
        total: 10000,
        createdAt: new Date(2026, 2, 31, 12, 0, 0), // March 31, local
      });
      prisma._sales.set('inside', {
        id: 'inside',
        storeId: 'store-A',
        staffId: 's1',
        total: 200,
        createdAt: new Date(2026, 3, 15, 12, 0, 0), // April 15, local
      });
      prisma._sales.set('after', {
        id: 'after',
        storeId: 'store-A',
        staffId: 's1',
        total: 99999,
        createdAt: new Date(2026, 4, 1, 12, 0, 0), // May 1, local
      });

      const period = await service.calculate('store-A', { month: 4, year: 2026 });
      const pr = (period as any).payrolls[0];

      // Only 200 contributed → commission = 200 * 50% = 100
      expect(Number(pr.salesTotal)).toBe(200);
      expect(Number(pr.commission)).toBe(100);
    });

    it('should not include staff from other stores when calculating a payroll period', async () => {
      seedStaff({ id: 's1', storeId: 'store-A', salary: 100, commission: 0 });
      seedStaff({ id: 's-leak', storeId: 'store-B', salary: 9999, commission: 0 });

      const period = await service.calculate('store-A', { month: 4, year: 2026 });

      const ids = (period as any).payrolls.map((p: any) => p.staffId);
      expect(ids).toContain('s1');
      expect(ids).not.toContain('s-leak');
    });
  });

  describe('payOne', () => {
    it('should throw BadRequestException when paying an already-paid payroll', async () => {
      seedStaff({ id: 's1', salary: 100, commission: 0 });
      await service.calculate('store-A', { month: 4, year: 2026 });
      const period = Array.from(prisma._periods.values())[0];
      const payroll = Array.from(prisma._payrolls.values())[0];
      payroll.isPaid = true;

      await expect(
        service.payOne('store-A', period.id, payroll.id),
      ).rejects.toBeInstanceOf(BadRequestException);
    });

    it('should throw NotFoundException when the period belongs to another store', async () => {
      seedStaff({ id: 's1', salary: 100, commission: 0 });
      await service.calculate('store-A', { month: 4, year: 2026 });
      const period = Array.from(prisma._periods.values())[0];
      const payroll = Array.from(prisma._payrolls.values())[0];

      await expect(
        service.payOne('store-OTHER', period.id, payroll.id),
      ).rejects.toBeInstanceOf(NotFoundException);
    });
  });

  describe('addAdjustment', () => {
    it('should add a BONUS adjustment and increase the payroll totalAmount when applied', async () => {
      seedStaff({ id: 's1', salary: 1000, commission: 0 });
      await service.calculate('store-A', { month: 4, year: 2026 });
      const period = Array.from(prisma._periods.values())[0];

      await service.addAdjustment('store-A', period.id, {
        staffId: 's1',
        type: AdjustmentType.BONUS,
        amount: 250,
        description: 'Quarter bonus',
      } as any);

      const payroll = Array.from(prisma._payrolls.values())[0];
      // 1000 base + 0 commission + 250 bonus = 1250
      expect(Number(payroll.totalAmount)).toBe(1250);
    });
  });
});
