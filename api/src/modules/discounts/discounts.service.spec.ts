import 'reflect-metadata';
import { Test } from '@nestjs/testing';
import { NotFoundException } from '@nestjs/common';
import { DiscountsService } from './discounts.service';
import { PrismaService } from '../../prisma/prisma.service';
import {
  DiscountCondition,
  DiscountType,
} from './dto/create-discount.dto';

// Map-backed Prisma fake. Discount.findMany supports the
// startDate/endDate/active filters used by findApplicable, plus storeId scoping
// for the rest of the service.
function makePrismaFake() {
  type Row = {
    id: string;
    storeId: string;
    name: string;
    type: string;
    value: number;
    condition: string;
    categoryId: string | null;
    productId: string | null;
    minTotal: number | null;
    startDate: Date;
    endDate: Date | null;
    active: boolean;
    createdAt: Date;
  };

  const rows = new Map<string, Row>();
  let idSeq = 0;
  const newId = () => `disc-${++idSeq}`;

  return {
    _rows: rows,
    discount: {
      create: jest.fn(async ({ data }: any) => {
        const id = newId();
        const row: Row = {
          id,
          storeId: data.storeId,
          name: data.name,
          type: data.type,
          value: Number(data.value),
          condition: data.condition,
          categoryId: data.categoryId ?? null,
          productId: data.productId ?? null,
          minTotal: data.minTotal != null ? Number(data.minTotal) : null,
          startDate: new Date(data.startDate),
          endDate: data.endDate ? new Date(data.endDate) : null,
          active: data.active ?? true,
          createdAt: new Date(),
        };
        rows.set(id, row);
        return row;
      }),
      findMany: jest.fn(async ({ where }: any = {}) => {
        return Array.from(rows.values()).filter((r) => {
          if (where?.storeId && r.storeId !== where.storeId) return false;
          if (where?.active !== undefined && r.active !== where.active) return false;
          if (where?.startDate?.lte && r.startDate.getTime() > where.startDate.lte.getTime())
            return false;
          if (where?.OR) {
            // OR: [{ endDate: null }, { endDate: { gte: now } }]
            const matchesNullEnd = r.endDate === null;
            const gte = where.OR.find((o: any) => o.endDate?.gte)?.endDate?.gte;
            const matchesFutureEnd =
              gte && r.endDate && r.endDate.getTime() >= gte.getTime();
            if (!matchesNullEnd && !matchesFutureEnd) return false;
          }
          return true;
        });
      }),
      findFirst: jest.fn(async ({ where }: any) => {
        for (const r of rows.values()) {
          if (where.id && r.id !== where.id) continue;
          if (where.storeId && r.storeId !== where.storeId) continue;
          return r;
        }
        return null;
      }),
      update: jest.fn(async ({ where, data }: any) => {
        const r = rows.get(where.id);
        if (!r) throw new Error('not found');
        if (data.name !== undefined) r.name = data.name;
        if (data.type !== undefined) r.type = data.type;
        if (data.value !== undefined) r.value = Number(data.value);
        if (data.condition !== undefined) r.condition = data.condition;
        if (data.categoryId !== undefined) r.categoryId = data.categoryId;
        if (data.productId !== undefined) r.productId = data.productId;
        if (data.minTotal !== undefined)
          r.minTotal = data.minTotal === null ? null : Number(data.minTotal);
        if (data.startDate !== undefined) r.startDate = new Date(data.startDate);
        if (data.endDate !== undefined)
          r.endDate = data.endDate ? new Date(data.endDate) : null;
        if (data.active !== undefined) r.active = data.active;
        return r;
      }),
    },
  };
}

describe('DiscountsService', () => {
  let service: DiscountsService;
  let prisma: ReturnType<typeof makePrismaFake>;

  beforeEach(async () => {
    prisma = makePrismaFake();
    const moduleRef = await Test.createTestingModule({
      providers: [
        DiscountsService,
        { provide: PrismaService, useValue: prisma },
      ],
    }).compile();
    service = moduleRef.get(DiscountsService);
  });

  const seed = (overrides: Partial<any> = {}) => {
    const id = overrides.id ?? `seed-${prisma._rows.size + 1}`;
    const row = {
      id,
      storeId: 'store-A',
      name: 'Seed',
      type: DiscountType.PERCENTAGE,
      value: 10,
      condition: DiscountCondition.CART,
      categoryId: null,
      productId: null,
      minTotal: null,
      startDate: new Date('2026-01-01T00:00:00Z'),
      endDate: null,
      active: true,
      createdAt: new Date(),
      ...overrides,
    };
    prisma._rows.set(id, row as any);
    return row;
  };

  describe('findAll', () => {
    it('should return only discounts for the requested store when listing', async () => {
      seed({ id: 'a1', storeId: 'store-A' });
      seed({ id: 'b1', storeId: 'store-B' });

      const res = await service.findAll('store-A');
      expect(res.length).toBe(1);
      expect(res[0].id).toBe('a1');
    });
  });

  describe('findApplicable', () => {
    it('should exclude discounts with startDate in the future when filtering applicable', async () => {
      const future = new Date(Date.now() + 1000 * 60 * 60 * 24 * 30); // +30d
      const past = new Date('2026-01-01T00:00:00Z');
      seed({ id: 'future', startDate: future, condition: DiscountCondition.CART });
      seed({ id: 'past', startDate: past, condition: DiscountCondition.CART });

      const res = await service.findApplicable('store-A', { total: 0 } as any);
      const ids = res.map((r) => r.id);

      expect(ids).toContain('past');
      expect(ids).not.toContain('future');
    });

    it('should exclude discounts when cart total is below minTotal threshold', async () => {
      seed({
        id: 'big-cart-only',
        condition: DiscountCondition.CART,
        minTotal: 1000,
      });
      seed({ id: 'no-min', condition: DiscountCondition.CART, minTotal: null });

      const lowCart = await service.findApplicable('store-A', {
        total: 500,
      } as any);
      const highCart = await service.findApplicable('store-A', {
        total: 1500,
      } as any);

      expect(lowCart.map((r) => r.id)).toEqual(['no-min']);
      expect(highCart.map((r) => r.id).sort()).toEqual([
        'big-cart-only',
        'no-min',
      ]);
    });

    it('should match CATEGORY discounts only when the discount.categoryId is in the cart categoryIds', async () => {
      seed({
        id: 'cat-electronics',
        condition: DiscountCondition.CATEGORY,
        categoryId: 'cat-electronics',
      });
      seed({
        id: 'cat-other',
        condition: DiscountCondition.CATEGORY,
        categoryId: 'cat-toys',
      });

      const res = await service.findApplicable('store-A', {
        total: 100,
        categoryIds: 'cat-electronics, cat-furniture',
      } as any);

      expect(res.map((r) => r.id)).toEqual(['cat-electronics']);
    });

    it('should match PRODUCT discounts only when discount.productId is among cart productIds', async () => {
      seed({
        id: 'prod-A',
        condition: DiscountCondition.PRODUCT,
        productId: 'p-1',
      });
      seed({
        id: 'prod-B',
        condition: DiscountCondition.PRODUCT,
        productId: 'p-99',
      });

      const res = await service.findApplicable('store-A', {
        total: 100,
        productIds: 'p-1,p-2',
      } as any);

      expect(res.map((r) => r.id)).toEqual(['prod-A']);
    });

    it('should not return discounts from other stores when finding applicable', async () => {
      seed({ id: 'mine', storeId: 'store-A', condition: DiscountCondition.CART });
      seed({ id: 'leak', storeId: 'store-B', condition: DiscountCondition.CART });

      const res = await service.findApplicable('store-A', { total: 0 } as any);
      const ids = res.map((r) => r.id);
      expect(ids).toContain('mine');
      expect(ids).not.toContain('leak');
    });
  });

  describe('findOne', () => {
    it('should throw NotFoundException when discount belongs to another store', async () => {
      seed({ id: 'foreign', storeId: 'store-OTHER' });
      await expect(
        service.findOne('store-A', 'foreign'),
      ).rejects.toBeInstanceOf(NotFoundException);
    });
  });

  describe('remove', () => {
    it('should set active=false rather than hard delete when removing a discount', async () => {
      seed({ id: 'soft', storeId: 'store-A', active: true });

      await service.remove('store-A', 'soft');

      const row = prisma._rows.get('soft')!;
      expect(row.active).toBe(false);
    });
  });
});
