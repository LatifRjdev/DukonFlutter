import 'reflect-metadata';
import { Test } from '@nestjs/testing';
import { NotFoundException } from '@nestjs/common';
import { InvestmentsService } from './investments.service';
import { PrismaService } from '../../prisma/prisma.service';
import { AuditLogService } from '../../common/audit/audit-log.service';

// Map-backed Prisma fake for InvestmentsService. Supports findFirst, findMany,
// count, create, update, delete, and aggregate filtered by storeId + status.
function makePrismaFake() {
  type Row = {
    id: string;
    storeId: string;
    name: string;
    description?: string | null;
    amount: number;
    returnAmount?: number | null;
    investorName: string;
    investorPhone?: string | null;
    status: 'ACTIVE' | 'COMPLETED' | 'CANCELLED';
    startDate: Date;
    endDate?: Date | null;
    createdAt: Date;
    updatedAt: Date;
  };

  const rows = new Map<string, Row>();
  let idSeq = 0;
  const newId = () => `inv-${++idSeq}`;

  const inRange = (d: Date, gte?: Date, lte?: Date) => {
    const t = d.getTime();
    if (gte && t < gte.getTime()) return false;
    if (lte && t > lte.getTime()) return false;
    return true;
  };

  const filter = (where: any = {}) =>
    Array.from(rows.values()).filter((r) => {
      if (where.storeId && r.storeId !== where.storeId) return false;
      if (where.status && r.status !== where.status) return false;
      if (where.startDate && !inRange(r.startDate, where.startDate.gte, where.startDate.lte))
        return false;
      return true;
    });

  const api: any = {
    _rows: rows,
    // Spec D: service now wraps update/remove in $transaction. Run
    // the callback synchronously against the same fake so existing
    // tests keep working.
    $transaction: jest.fn(async (cb: any) => cb(api)),
    investment: {
      create: jest.fn(async ({ data }: any) => {
        const id = newId();
        const row: Row = {
          id,
          storeId: data.storeId,
          name: data.name,
          description: data.description ?? null,
          amount: Number(data.amount),
          returnAmount: data.returnAmount != null ? Number(data.returnAmount) : null,
          investorName: data.investorName,
          investorPhone: data.investorPhone ?? null,
          status: data.status ?? 'ACTIVE',
          startDate: new Date(data.startDate),
          endDate: data.endDate ? new Date(data.endDate) : null,
          createdAt: new Date(),
          updatedAt: new Date(),
        };
        rows.set(id, row);
        return row;
      }),
      findFirst: jest.fn(async ({ where }: any) => {
        for (const r of rows.values()) {
          if (where.id && r.id !== where.id) continue;
          if (where.storeId && r.storeId !== where.storeId) continue;
          return r;
        }
        return null;
      }),
      // Spec D: idempotent create looks up by (storeId, localId).
      findUnique: jest.fn(async ({ where }: any) => {
        const composite = where.storeId_localId;
        if (composite) {
          for (const r of rows.values()) {
            if (
              r.storeId === composite.storeId &&
              (r as any).localId === composite.localId
            ) {
              return r;
            }
          }
        }
        return null;
      }),
      findMany: jest.fn(async ({ where, skip = 0, take = 20 }: any = {}) => {
        const matched = filter(where).sort(
          (a, b) => b.createdAt.getTime() - a.createdAt.getTime(),
        );
        return matched.slice(skip, skip + take);
      }),
      count: jest.fn(async ({ where }: any = {}) => filter(where).length),
      aggregate: jest.fn(async ({ where, _sum }: any = {}) => {
        const matched = filter(where);
        const out: any = { _count: matched.length, _sum: {} };
        if (_sum?.amount) {
          out._sum.amount = matched.reduce((s, r) => s + Number(r.amount), 0);
        }
        if (_sum?.returnAmount) {
          out._sum.returnAmount = matched.reduce(
            (s, r) => s + Number(r.returnAmount ?? 0),
            0,
          );
        }
        return out;
      }),
      update: jest.fn(async ({ where, data }: any) => {
        const r = rows.get(where.id);
        if (!r) throw new Error('not found');
        Object.assign(r, data, {
          amount: data.amount !== undefined ? Number(data.amount) : r.amount,
          startDate: data.startDate ? new Date(data.startDate) : r.startDate,
          endDate:
            data.endDate !== undefined
              ? data.endDate
                ? new Date(data.endDate)
                : null
              : r.endDate,
          updatedAt: new Date(),
        });
        return r;
      }),
      delete: jest.fn(async ({ where }: any) => {
        const r = rows.get(where.id);
        rows.delete(where.id);
        return r;
      }),
    },
  };
  return api;
}

describe('InvestmentsService', () => {
  let service: InvestmentsService;
  let prisma: ReturnType<typeof makePrismaFake>;
  let audit: { record: jest.Mock };

  beforeEach(async () => {
    prisma = makePrismaFake();
    // Spec D: AuditLogService is now a constructor dep. Provide a
    // no-op fake — we only need DI to resolve, not real persistence.
    audit = { record: jest.fn(async () => undefined) };
    const moduleRef = await Test.createTestingModule({
      providers: [
        InvestmentsService,
        { provide: PrismaService, useValue: prisma },
        { provide: AuditLogService, useValue: audit },
      ],
    }).compile();
    service = moduleRef.get(InvestmentsService);
  });

  const seed = (overrides: Partial<any> = {}) => {
    const id = overrides.id ?? `seed-${prisma._rows.size + 1}`;
    const row = {
      id,
      storeId: 'store-A',
      name: 'Seed Inv',
      description: null,
      amount: 1000,
      returnAmount: null,
      investorName: 'Investor',
      investorPhone: null,
      status: 'ACTIVE' as const,
      startDate: new Date('2026-01-01T00:00:00Z'),
      endDate: null,
      createdAt: new Date(),
      updatedAt: new Date(),
      ...overrides,
    };
    prisma._rows.set(id, row as any);
    return row;
  };

  describe('findAll', () => {
    it('should not return investments from other stores when listing by storeId', async () => {
      seed({ id: 'a1', storeId: 'store-A' });
      seed({ id: 'b1', storeId: 'store-B', amount: 99999 });

      const res = await service.findAll('store-A', {
        page: 1,
        limit: 20,
        get skip() {
          return 0;
        },
      } as any);

      expect(res.total).toBe(1);
      expect(res.data[0].id).toBe('a1');
    });

    it('should filter investments by startDate inclusive boundaries when given a range', async () => {
      seed({ id: 'before', startDate: new Date('2025-12-31T23:59:59Z') });
      seed({ id: 'on-start', startDate: new Date('2026-01-01T00:00:00Z') });
      seed({ id: 'on-end', startDate: new Date('2026-03-31T00:00:00Z') });
      seed({ id: 'after', startDate: new Date('2026-04-01T00:00:01Z') });

      const res = await service.findAll('store-A', {
        startDate: '2026-01-01T00:00:00Z',
        endDate: '2026-03-31T00:00:00Z',
        get skip() {
          return 0;
        },
      } as any);

      const ids = res.data.map((d: any) => d.id).sort();
      expect(ids).toEqual(['on-end', 'on-start']);
    });
  });

  describe('findOne', () => {
    it('should throw NotFoundException when investment belongs to a different store', async () => {
      seed({ id: 'foreign', storeId: 'store-OTHER' });
      await expect(
        service.findOne('store-A', 'foreign'),
      ).rejects.toBeInstanceOf(NotFoundException);
    });
  });

  describe('summary', () => {
    it('should aggregate amounts by status without leaking other stores when summarizing', async () => {
      seed({ id: 'a1', storeId: 'store-A', status: 'ACTIVE', amount: 1000 });
      seed({ id: 'a2', storeId: 'store-A', status: 'ACTIVE', amount: 500 });
      seed({
        id: 'a3',
        storeId: 'store-A',
        status: 'COMPLETED',
        amount: 2000,
        returnAmount: 2400,
      });
      seed({ id: 'b1', storeId: 'store-B', status: 'ACTIVE', amount: 9999 });

      const summary = await service.summary('store-A');

      expect(Number(summary.total.amount)).toBe(3500);
      expect(summary.total.count).toBe(3);
      expect(Number(summary.active.amount)).toBe(1500);
      expect(summary.active.count).toBe(2);
      expect(Number(summary.completed.amount)).toBe(2000);
      expect(Number(summary.completed.returnAmount)).toBe(2400);
      expect(summary.completed.count).toBe(1);
    });

    it('should compute decimal sums correctly when investments use fractional amounts', async () => {
      seed({ id: 'd1', amount: 100.25, status: 'ACTIVE' });
      seed({ id: 'd2', amount: 50.5, status: 'ACTIVE' });

      const summary = await service.summary('store-A');

      expect(Number(summary.active.amount)).toBeCloseTo(150.75, 2);
    });
  });

  describe('remove', () => {
    it('should throw NotFoundException when removing a non-existent investment', async () => {
      await expect(
        service.remove('store-A', 'missing', 'user-1'),
      ).rejects.toBeInstanceOf(NotFoundException);
    });
  });

  describe('Spec D — investments hardening', () => {
    beforeEach(() => {
      jest.clearAllMocks();
    });

    it('create: passes localId through to prisma.create.data', async () => {
      const createSpy = (prisma.investment.create as jest.Mock).mockResolvedValue({
        id: 'inv-1',
        amount: { toString: () => '1000' },
        name: 'Test',
        storeId: 's1',
      });
      await service.create(
        's1',
        {
          name: 'Test',
          amount: 1000,
          investorName: 'A',
          startDate: '2026-01-01',
          status: 'ACTIVE',
          localId: 'abc-123',
        } as any,
        'user-1',
      );
      expect(createSpy.mock.calls[0][0].data.localId).toBe('abc-123');
    });

    it('create: returns existing row when localId already used (idempotent)', async () => {
      (prisma.investment.findUnique as jest.Mock).mockResolvedValue({
        id: 'existing-1',
        name: 'Old',
      });
      const createSpy = prisma.investment.create as jest.Mock;

      const result = await service.create(
        's1',
        {
          name: 'Test',
          amount: 1000,
          investorName: 'A',
          startDate: '2026-01-01',
          status: 'ACTIVE',
          localId: 'abc-123',
        } as any,
        'user-1',
      );

      expect((result as any).id).toBe('existing-1');
      expect(createSpy).not.toHaveBeenCalled();
    });

    it('create: writes investment.create audit log with userId', async () => {
      (prisma.investment.findUnique as jest.Mock).mockResolvedValue(null);
      (prisma.investment.create as jest.Mock).mockResolvedValue({
        id: 'inv-1',
        amount: { toString: () => '500' },
        name: 'X',
        storeId: 's1',
      });
      const auditMock = audit.record as jest.Mock;
      await service.create(
        's1',
        {
          name: 'X',
          amount: 500,
          investorName: 'A',
          startDate: '2026-01-01',
          status: 'ACTIVE',
        } as any,
        'admin-42',
      );
      // Positional signature: (userId, action, entityType, entityId, details)
      expect(auditMock).toHaveBeenCalledWith(
        'admin-42',
        'investment.create',
        'investment',
        'inv-1',
        expect.any(Object),
      );
    });

    it('update: throws NotFound when row missing', async () => {
      (prisma.investment.findFirst as jest.Mock).mockResolvedValue(null);
      await expect(
        service.update('s1', 'missing-id', { name: 'New' } as any, 'user-1'),
      ).rejects.toThrow(/not found/i);
    });

    it('update: writes investment.update audit log', async () => {
      (prisma.investment.findFirst as jest.Mock).mockResolvedValue({
        id: 'inv-1',
        amount: 100,
      });
      (prisma.investment.update as jest.Mock).mockResolvedValue({
        id: 'inv-1',
        amount: { toString: () => '200' },
        status: 'ACTIVE',
      });
      const auditMock = audit.record as jest.Mock;
      await service.update('s1', 'inv-1', { amount: 200 } as any, 'admin-42');
      expect(auditMock).toHaveBeenCalledWith(
        'admin-42',
        'investment.update',
        'investment',
        'inv-1',
        expect.any(Object),
      );
    });

    it('remove: writes investment.delete audit log', async () => {
      (prisma.investment.findFirst as jest.Mock).mockResolvedValue({
        id: 'inv-1',
        amount: { toString: () => '100' },
        name: 'X',
        storeId: 's1',
      });
      (prisma.investment.delete as jest.Mock).mockResolvedValue({});
      const auditMock = audit.record as jest.Mock;
      await service.remove('s1', 'inv-1', 'admin-42');
      expect(auditMock).toHaveBeenCalledWith(
        'admin-42',
        'investment.delete',
        'investment',
        'inv-1',
        expect.any(Object),
      );
    });
  });
});
