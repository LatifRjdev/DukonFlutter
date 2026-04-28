import 'reflect-metadata';
import { Test } from '@nestjs/testing';
import { NotFoundException } from '@nestjs/common';
import { ExpensesService } from './expenses.service';
import { PrismaService } from '../../prisma/prisma.service';
import { ExpenseCategory } from './dto/create-expense.dto';

// Map-backed Prisma fake. Tracks expenses per id and supports the where-shape
// used by ExpensesService: storeId, category, date range, description search.
function makePrismaFake() {
  type Row = {
    id: string;
    storeId: string;
    category: string;
    amount: number;
    description?: string | null;
    notes?: string | null;
    receiptUrl?: string | null;
    isRecurring?: boolean;
    recurringDay?: number | null;
    date: Date;
    createdAt: Date;
    updatedAt: Date;
  };

  const rows = new Map<string, Row>();
  let idSeq = 0;
  const newId = () => `exp-${++idSeq}`;

  const inRange = (d: Date, gte?: Date, lte?: Date) => {
    const t = d.getTime();
    if (gte && t < gte.getTime()) return false;
    if (lte && t > lte.getTime()) return false;
    return true;
  };

  const filter = (where: any = {}) =>
    Array.from(rows.values()).filter((r) => {
      if (where.storeId && r.storeId !== where.storeId) return false;
      if (where.category && r.category !== where.category) return false;
      if (where.date && !inRange(r.date, where.date.gte, where.date.lte))
        return false;
      if (where.description?.contains) {
        const needle = where.description.contains.toLowerCase();
        if (!(r.description ?? '').toLowerCase().includes(needle)) return false;
      }
      return true;
    });

  return {
    _rows: rows,
    expense: {
      create: jest.fn(async ({ data }: any) => {
        const id = newId();
        const row: Row = {
          id,
          storeId: data.storeId,
          category: data.category,
          amount: Number(data.amount),
          description: data.description ?? null,
          notes: data.notes ?? null,
          receiptUrl: data.receiptUrl ?? null,
          isRecurring: data.isRecurring ?? false,
          recurringDay: data.recurringDay ?? null,
          date: data.date ? new Date(data.date) : new Date(),
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
      findMany: jest.fn(async ({ where, skip = 0, take = 20 }: any = {}) => {
        const matched = filter(where).sort(
          (a, b) => b.date.getTime() - a.date.getTime(),
        );
        return matched.slice(skip, skip + take);
      }),
      count: jest.fn(async ({ where }: any = {}) => filter(where).length),
      update: jest.fn(async ({ where, data }: any) => {
        const r = rows.get(where.id);
        if (!r) throw new Error('not found');
        Object.assign(r, data, {
          amount: data.amount !== undefined ? Number(data.amount) : r.amount,
          date: data.date ? new Date(data.date) : r.date,
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
}

describe('ExpensesService', () => {
  let service: ExpensesService;
  let prisma: ReturnType<typeof makePrismaFake>;

  beforeEach(async () => {
    prisma = makePrismaFake();
    const moduleRef = await Test.createTestingModule({
      providers: [
        ExpensesService,
        { provide: PrismaService, useValue: prisma },
      ],
    }).compile();
    service = moduleRef.get(ExpensesService);
  });

  const seed = (overrides: Partial<any> = {}) => {
    const id = overrides.id ?? `seed-${prisma._rows.size + 1}`;
    const row = {
      id,
      storeId: 'store-A',
      category: ExpenseCategory.OTHER,
      amount: 100,
      description: null,
      notes: null,
      receiptUrl: null,
      isRecurring: false,
      recurringDay: null,
      date: new Date('2026-04-15T00:00:00Z'),
      createdAt: new Date(),
      updatedAt: new Date(),
      ...overrides,
    };
    prisma._rows.set(id, row as any);
    return row;
  };

  describe('findAll', () => {
    it('should return only expenses scoped to storeId when listing across multiple stores', async () => {
      seed({ id: 'a1', storeId: 'store-A', amount: 100 });
      seed({ id: 'a2', storeId: 'store-A', amount: 200 });
      seed({ id: 'b1', storeId: 'store-B', amount: 9999 });

      const res = await service.findAll('store-A', {
        page: 1,
        limit: 20,
        get skip() {
          return 0;
        },
      } as any);

      expect(res.total).toBe(2);
      expect(res.data.every((e: any) => e.storeId === 'store-A')).toBe(true);
    });

    it('should filter by inclusive startDate and endDate boundaries when given a date range', async () => {
      seed({ id: 'before', date: new Date('2026-03-31T23:59:59Z') });
      seed({
        id: 'on-start',
        date: new Date('2026-04-01T00:00:00Z'),
      });
      seed({
        id: 'on-end',
        date: new Date('2026-04-30T00:00:00Z'),
      });
      seed({ id: 'after', date: new Date('2026-05-01T00:00:01Z') });

      const res = await service.findAll('store-A', {
        startDate: '2026-04-01T00:00:00Z',
        endDate: '2026-04-30T00:00:00Z',
        get skip() {
          return 0;
        },
      } as any);

      const ids = res.data.map((d: any) => d.id).sort();
      expect(ids).toEqual(['on-end', 'on-start']);
    });

    it('should filter by category when category is supplied in query', async () => {
      seed({ id: 'e1', category: ExpenseCategory.RENT });
      seed({ id: 'e2', category: ExpenseCategory.UTILITIES });
      seed({ id: 'e3', category: ExpenseCategory.RENT });

      const res = await service.findAll('store-A', {
        category: ExpenseCategory.RENT,
        get skip() {
          return 0;
        },
      } as any);

      expect(res.total).toBe(2);
      expect(res.data.every((e: any) => e.category === ExpenseCategory.RENT)).toBe(
        true,
      );
    });
  });

  describe('findOne', () => {
    it('should throw NotFoundException when expense belongs to a different store', async () => {
      seed({ id: 'leak', storeId: 'store-OTHER' });
      await expect(service.findOne('store-A', 'leak')).rejects.toBeInstanceOf(
        NotFoundException,
      );
    });
  });

  describe('create', () => {
    it('should persist amount as a positive number when creating an expense with decimals', async () => {
      const created = await service.create('store-A', {
        category: ExpenseCategory.SALARY,
        amount: 1234.56,
        description: 'April salary',
      } as any);

      expect(Number(created.amount)).toBeCloseTo(1234.56, 2);
      expect((created as any).storeId).toBe('store-A');
    });
  });

  describe('remove', () => {
    it('should throw NotFoundException when removing a non-existent expense for the given store', async () => {
      await expect(
        service.remove('store-A', 'does-not-exist'),
      ).rejects.toBeInstanceOf(NotFoundException);
    });
  });
});
