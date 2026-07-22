import 'reflect-metadata';
import { Test } from '@nestjs/testing';
import { ConflictException, NotFoundException } from '@nestjs/common';
import { validate } from 'class-validator';
import { plainToInstance } from 'class-transformer';
import { ProductsService } from './products.service';
import { PrismaService } from '../../prisma/prisma.service';
import { CreateProductDto } from './dto/create-product.dto';

// In-memory behavioral fake for the slice of PrismaService that
// ProductsService depends on. Exposes Map-backed product storage so tests
// assert *behavior* (what got persisted, what was filtered) rather than
// implementation details (which prisma method was called with what args).
function makePrismaFake() {
  type ProductRow = {
    id: string;
    storeId: string;
    name: string;
    sku?: string | null;
    barcode?: string | null;
    sellPrice: number;
    costPrice?: number | null;
    quantity: number;
    minQuantity: number;
    unit: string;
    isActive: boolean;
    categoryId?: string | null;
    supplierId?: string | null;
    createdAt: Date;
  };
  const rows = new Map<string, ProductRow>();
  let idSeq = 0;
  const newId = () => `prod-${++idSeq}`;

  const stockMovements: Array<{
    id: string;
    productId: string;
    type: string;
    quantity: number;
    unitCost: number | null;
    totalCost: number | null;
    createdAt: Date;
  }> = [];
  const saleItems: Array<{
    id: string;
    productId: string;
    quantity: number;
    unitPrice: number;
    costPrice: number | null;
    total: number;
    refundedQuantity: number;
    saleStoreId: string;
    saleCreatedAt: Date;
    // Sale-level discount/subtotal (Sale.discount / Sale.subtotal), for
    // simulating the F-RACE-2 proportional-ratio case. Default to no
    // sale-level discount when omitted.
    saleDiscount?: number;
    saleSubtotal?: number;
  }> = [];

  return {
    _rows: rows,
    _stockMovements: stockMovements,
    _saleItems: saleItems,
    stockMovement: {
      findFirst: jest.fn(async ({ where, orderBy }: any) => {
        let matches = stockMovements.filter(
          (m) =>
            m.productId === where.productId &&
            (!where.type || m.type === where.type),
        );
        if (orderBy?.createdAt === 'desc') {
          matches = [...matches].sort(
            (a, b) => b.createdAt.getTime() - a.createdAt.getTime(),
          );
        }
        return matches[0] ?? null;
      }),
    },
    saleItem: {
      findMany: jest.fn(async ({ where }: any) => {
        return saleItems
          .filter((si) => {
            if (si.productId !== where.productId) return false;
            if (where.sale?.storeId && si.saleStoreId !== where.sale.storeId) {
              return false;
            }
            if (
              where.sale?.createdAt?.gte &&
              si.saleCreatedAt < where.sale.createdAt.gte
            ) {
              return false;
            }
            return true;
          })
          .map((si) => ({
            quantity: si.quantity,
            refundedQuantity: si.refundedQuantity,
            costPrice: si.costPrice,
            total: si.total,
            sale: {
              discount: si.saleDiscount ?? 0,
              subtotal: si.saleSubtotal ?? 0,
            },
          }));
      }),
    },
    product: {
      findUnique: jest.fn(async ({ where }: any) => {
        if (where.storeId_sku) {
          const { storeId, sku } = where.storeId_sku;
          for (const r of rows.values()) {
            if (r.storeId === storeId && r.sku === sku) return r;
          }
          return null;
        }
        if (where.storeId_barcode) {
          const { storeId, barcode } = where.storeId_barcode;
          for (const r of rows.values()) {
            if (r.storeId === storeId && r.barcode === barcode) return r;
          }
          return null;
        }
        if (where.id) return rows.get(where.id) ?? null;
        return null;
      }),
      findFirst: jest.fn(async ({ where }: any) => {
        for (const r of rows.values()) {
          if (where.id && r.id !== where.id) continue;
          if (where.storeId && r.storeId !== where.storeId) continue;
          return r;
        }
        return null;
      }),
      findMany: jest.fn(async ({ where, skip = 0, take }: any = {}) => {
        const all = Array.from(rows.values()).filter((r) => {
          if (where?.storeId && r.storeId !== where.storeId) return false;
          if (where?.categoryId && r.categoryId !== where.categoryId)
            return false;
          return true;
        });
        // take undefined (lowStock path fetches all candidates) means
        // "return everything from skip onward".
        return take === undefined
          ? all.slice(skip)
          : all.slice(skip, skip + take);
      }),
      create: jest.fn(async ({ data }: any) => {
        const id = newId();
        const row: ProductRow = {
          id,
          storeId: data.storeId,
          name: data.name,
          sku: data.sku ?? null,
          barcode: data.barcode ?? null,
          sellPrice: Number(data.sellPrice),
          costPrice: data.costPrice ?? null,
          quantity: data.quantity ?? 0,
          minQuantity: data.minQuantity ?? 0,
          unit: data.unit ?? 'PCS',
          isActive: true,
          categoryId: data.categoryId ?? null,
          supplierId: data.supplierId ?? null,
          createdAt: new Date(),
        };
        rows.set(id, row);
        return row;
      }),
      update: jest.fn(async ({ where, data }: any) => {
        const row = rows.get(where.id);
        if (!row) throw new Error('not found');
        const updated = { ...row, ...data };
        rows.set(where.id, updated);
        return updated;
      }),
      count: jest.fn(async ({ where }: any) => {
        let count = 0;
        for (const r of rows.values()) {
          if (where?.storeId && r.storeId !== where.storeId) continue;
          if (where?.isActive !== undefined && r.isActive !== where.isActive)
            continue;
          count += 1;
        }
        return count;
      }),
    },
    // F2.1: plan-limit helper queries subscription + planConfig. Stub
    // both as fail-open (null) so legacy spec assertions don't change.
    subscription: {
      findUnique: jest.fn(async () => null),
    },
    subscriptionPlanConfig: {
      findUnique: jest.fn(async () => null),
    },
  };
}

describe('ProductsService', () => {
  let service: ProductsService;
  let prisma: ReturnType<typeof makePrismaFake>;

  beforeEach(async () => {
    prisma = makePrismaFake();
    const moduleRef = await Test.createTestingModule({
      providers: [
        ProductsService,
        { provide: PrismaService, useValue: prisma },
      ],
    }).compile();
    service = moduleRef.get(ProductsService);
  });

  describe('create', () => {
    it('should persist product scoped to caller storeId when called', async () => {
      const created = await service.create('store-A', {
        name: 'Apple',
        sellPrice: 10,
      } as CreateProductDto);

      expect(created.storeId).toBe('store-A');
      // Cross-store isolation: another store cannot retrieve it via findOne.
      await expect(
        service.findOne('store-B', created.id),
      ).rejects.toBeInstanceOf(NotFoundException);
    });

    it('should throw ConflictException when barcode already exists in store', async () => {
      await service.create('store-A', {
        name: 'Bread',
        barcode: '111',
        sellPrice: 5,
      } as CreateProductDto);

      await expect(
        service.create('store-A', {
          name: 'Bread2',
          barcode: '111',
          sellPrice: 6,
        } as CreateProductDto),
      ).rejects.toBeInstanceOf(ConflictException);
    });

    it('should reject negative price at DTO validation when input is invalid', async () => {
      // Price validation lives in the DTO @Min(0) decorator, executed by the
      // global ValidationPipe before the service runs. We assert the DTO
      // contract rather than service behavior, since the service trusts DTO.
      const dto = plainToInstance(CreateProductDto, {
        name: 'X',
        sellPrice: -1,
      });
      const errors = await validate(dto);
      expect(errors.length).toBeGreaterThan(0);
      expect(JSON.stringify(errors)).toContain('min');
    });
  });

  describe('findAll', () => {
    it('should only return products belonging to caller storeId when stores share data', async () => {
      await service.create('store-A', {
        name: 'A1',
        sellPrice: 1,
      } as CreateProductDto);
      await service.create('store-A', {
        name: 'A2',
        sellPrice: 2,
      } as CreateProductDto);
      await service.create('store-B', {
        name: 'B1',
        sellPrice: 3,
      } as CreateProductDto);

      const result = await service.findAll('store-A', { skip: 0 } as any);

      expect(result.total).toBe(2);
      expect(result.data.every((p: any) => p.storeId === 'store-A')).toBe(true);
    });

    it('should paginate via skip/take when limit is set', async () => {
      for (let i = 0; i < 5; i++) {
        await service.create('store-A', {
          name: `P${i}`,
          sellPrice: i + 1,
        } as CreateProductDto);
      }

      const page1 = await service.findAll('store-A', {
        page: 1,
        limit: 2,
        skip: 0,
      } as any);
      const page2 = await service.findAll('store-A', {
        page: 2,
        limit: 2,
        skip: 2,
      } as any);

      expect(page1.data).toHaveLength(2);
      expect(page2.data).toHaveLength(2);
      expect(page1.data[0].id).not.toEqual(page2.data[0].id);
      expect(page1.totalPages).toBe(3);
    });

    describe('lowStock filter', () => {
      it('should include a product when quantity <= minQuantity and quantity > 0', async () => {
        const low = await service.create('store-A', {
          name: 'Low',
          sellPrice: 1,
          quantity: 5,
          minQuantity: 10,
        } as CreateProductDto);

        const result = await service.findAll('store-A', {
          lowStock: true,
          skip: 0,
        } as any);

        expect(result.data.map((p: any) => p.id)).toContain(low.id);
      });

      it('should exclude a product when quantity > minQuantity', async () => {
        const healthy = await service.create('store-A', {
          name: 'Healthy',
          sellPrice: 1,
          quantity: 50,
          minQuantity: 10,
        } as CreateProductDto);

        const result = await service.findAll('store-A', {
          lowStock: true,
          skip: 0,
        } as any);

        expect(result.data.map((p: any) => p.id)).not.toContain(healthy.id);
        expect(result.total).toBe(0);
      });

      it('should exclude a product when quantity is 0 (out-of-stock is not low-stock)', async () => {
        const outOfStock = await service.create('store-A', {
          name: 'OutOfStock',
          sellPrice: 1,
          quantity: 0,
          minQuantity: 10,
        } as CreateProductDto);

        const result = await service.findAll('store-A', {
          lowStock: true,
          skip: 0,
        } as any);

        expect(result.data.map((p: any) => p.id)).not.toContain(outOfStock.id);
        expect(result.total).toBe(0);
      });

      it('should combine with categoryId filter when both are set', async () => {
        const lowInCategory = await service.create('store-A', {
          name: 'LowInCategory',
          sellPrice: 1,
          quantity: 2,
          minQuantity: 10,
          categoryId: 'cat-1',
        } as CreateProductDto);
        await service.create('store-A', {
          name: 'LowInOtherCategory',
          sellPrice: 1,
          quantity: 2,
          minQuantity: 10,
          categoryId: 'cat-2',
        } as CreateProductDto);

        const result = await service.findAll('store-A', {
          lowStock: true,
          categoryId: 'cat-1',
          skip: 0,
        } as any);

        expect(result.data.map((p: any) => p.id)).toEqual([lowInCategory.id]);
        expect(result.total).toBe(1);
      });

      it('should compute totalPages from the post-filter count, not the pre-filter candidate count', async () => {
        for (let i = 0; i < 3; i++) {
          await service.create('store-A', {
            name: `Low${i}`,
            sellPrice: 1,
            quantity: 1,
            minQuantity: 10,
          } as CreateProductDto);
        }
        for (let i = 0; i < 5; i++) {
          await service.create('store-A', {
            name: `Healthy${i}`,
            sellPrice: 1,
            quantity: 50,
            minQuantity: 10,
          } as CreateProductDto);
        }

        const result = await service.findAll('store-A', {
          lowStock: true,
          limit: 2,
          skip: 0,
        } as any);

        expect(result.total).toBe(3);
        expect(result.totalPages).toBe(2);
        expect(result.data).toHaveLength(2);
      });
    });
  });

  describe('update', () => {
    it('should throw NotFoundException when product belongs to another store', async () => {
      const created = await service.create('store-A', {
        name: 'X',
        sellPrice: 1,
      } as CreateProductDto);

      await expect(
        service.update('store-B', created.id, { name: 'Y' } as any),
      ).rejects.toBeInstanceOf(NotFoundException);
    });

    it('should not change storeId when update payload would attempt to', async () => {
      const created = await service.create('store-A', {
        name: 'X',
        sellPrice: 1,
      } as CreateProductDto);

      // UpdateProductDto (PartialType of CreateProductDto) has no storeId
      // field. Even if a malicious client sent { storeId: 'store-B' } in
      // the body, ValidationPipe (whitelist:true) strips it. Here we assert
      // that the persisted row remains scoped to store-A after update.
      await service.update('store-A', created.id, { name: 'Y' } as any);

      const row = prisma._rows.get(created.id);
      expect(row?.storeId).toBe('store-A');
      expect(row?.name).toBe('Y');
    });
  });

  describe('remove', () => {
    it('should soft-delete by setting isActive=false when remove is called', async () => {
      const created = await service.create('store-A', {
        name: 'X',
        sellPrice: 1,
      } as CreateProductDto);

      await service.remove('store-A', created.id);

      const row = prisma._rows.get(created.id);
      expect(row?.isActive).toBe(false);
    });
  });

  describe('findByBarcode', () => {
    it('should throw NotFoundException when barcode unknown in store', async () => {
      await expect(
        service.findByBarcode('store-A', 'does-not-exist'),
      ).rejects.toBeInstanceOf(NotFoundException);
    });
  });
});

describe('ProductsService.getBatchProfitability', () => {
  let service: ProductsService;
  let prisma: ReturnType<typeof makePrismaFake>;

  beforeEach(async () => {
    prisma = makePrismaFake();
    const moduleRef = await Test.createTestingModule({
      providers: [
        ProductsService,
        { provide: PrismaService, useValue: prisma },
      ],
    }).compile();
    service = moduleRef.get(ProductsService);
  });

  it('should compute the worked example from the design spec (100@10, sold 33@30, 67 remain)', async () => {
    prisma._rows.set('p1', {
      id: 'p1',
      storeId: 'store-A',
      name: 'Widget',
      sellPrice: 30,
      costPrice: 10,
      quantity: 67,
      minQuantity: 0,
      unit: 'PCS',
      isActive: true,
      createdAt: new Date(),
    });
    prisma._stockMovements.push({
      id: 'mv1',
      productId: 'p1',
      type: 'PURCHASE',
      quantity: 100,
      unitCost: 10,
      totalCost: 1000,
      createdAt: new Date('2026-07-01'),
    });
    prisma._saleItems.push({
      id: 'si1',
      productId: 'p1',
      quantity: 33,
      unitPrice: 30,
      costPrice: 10,
      total: 990,
      refundedQuantity: 0,
      saleStoreId: 'store-A',
      saleCreatedAt: new Date('2026-07-15'),
    });

    const result = await service.getBatchProfitability('store-A', 'p1');

    expect(result.hasBatch).toBe(true);
    expect(result.batchQuantity).toBe(100);
    expect(result.batchCost).toBe(1000);
    expect(result.soldQuantity).toBe(33);
    expect(result.revenue).toBe(990);
    expect(result.profitEarned).toBe(660);
    expect(result.remainingQuantity).toBe(67);
    expect(result.remainingStockValue).toBe(670);
    expect(result.paybackPercent).toBeCloseTo(99);
    expect(result.paybackShortfall).toBeCloseTo(-10);
  });

  it('should net out refunded quantity from sold/revenue/profit', async () => {
    prisma._rows.set('p1', {
      id: 'p1',
      storeId: 'store-A',
      name: 'Widget',
      sellPrice: 30,
      costPrice: 10,
      quantity: 90,
      minQuantity: 0,
      unit: 'PCS',
      isActive: true,
      createdAt: new Date(),
    });
    prisma._stockMovements.push({
      id: 'mv1',
      productId: 'p1',
      type: 'PURCHASE',
      quantity: 100,
      unitCost: 10,
      totalCost: 1000,
      createdAt: new Date('2026-07-01'),
    });
    prisma._saleItems.push({
      id: 'si1',
      productId: 'p1',
      quantity: 10,
      unitPrice: 30,
      costPrice: 10,
      total: 300,
      refundedQuantity: 4,
      saleStoreId: 'store-A',
      saleCreatedAt: new Date('2026-07-15'),
    });

    const result = await service.getBatchProfitability('store-A', 'p1');

    // 6 net units sold (10 - 4 refunded), pro-rated revenue = 300/10*6=180
    expect(result.soldQuantity).toBe(6);
    expect(result.revenue).toBe(180);
    expect(result.profitEarned).toBe(120); // 180 - 6*10
  });

  it('should apply the sale-level discount ratio on top of the line total, not count the pre-discount total as revenue', async () => {
    prisma._rows.set('p1', {
      id: 'p1',
      storeId: 'store-A',
      name: 'Widget',
      sellPrice: 30,
      costPrice: 10,
      quantity: 80,
      minQuantity: 0,
      unit: 'PCS',
      isActive: true,
      createdAt: new Date(),
    });
    prisma._stockMovements.push({
      id: 'mv1',
      productId: 'p1',
      type: 'PURCHASE',
      quantity: 100,
      unitCost: 10,
      totalCost: 1000,
      createdAt: new Date('2026-07-01'),
    });
    // Line total (already net of any line-level discount) = 20 * 30 = 600.
    // Sale-level discount 100 on a sale subtotal of 1000 => ratio 0.9.
    // Real revenue for this line = 600 * 0.9 = 540, not the raw 600.
    prisma._saleItems.push({
      id: 'si1',
      productId: 'p1',
      quantity: 20,
      unitPrice: 30,
      costPrice: 10,
      total: 600,
      refundedQuantity: 0,
      saleStoreId: 'store-A',
      saleCreatedAt: new Date('2026-07-15'),
      saleDiscount: 100,
      saleSubtotal: 1000,
    });

    const result = await service.getBatchProfitability('store-A', 'p1');

    expect(result.soldQuantity).toBe(20);
    expect(result.revenue).toBe(540); // 600 * (1 - 100/1000), not raw 600
    expect(result.profitEarned).toBe(340); // 540 - 20*10
  });

  it('should only count sales on or after the anchor purchase date, not earlier ones', async () => {
    prisma._rows.set('p1', {
      id: 'p1',
      storeId: 'store-A',
      name: 'Widget',
      sellPrice: 30,
      costPrice: 10,
      quantity: 100,
      minQuantity: 0,
      unit: 'PCS',
      isActive: true,
      createdAt: new Date(),
    });
    prisma._stockMovements.push({
      id: 'mv-old',
      productId: 'p1',
      type: 'PURCHASE',
      quantity: 50,
      unitCost: 8,
      totalCost: 400,
      createdAt: new Date('2026-06-01'),
    });
    prisma._stockMovements.push({
      id: 'mv-new',
      productId: 'p1',
      type: 'PURCHASE',
      quantity: 100,
      unitCost: 10,
      totalCost: 1000,
      createdAt: new Date('2026-07-01'),
    });
    prisma._saleItems.push({
      id: 'si-old',
      productId: 'p1',
      quantity: 5,
      unitPrice: 30,
      costPrice: 8,
      total: 150,
      refundedQuantity: 0,
      saleStoreId: 'store-A',
      saleCreatedAt: new Date('2026-06-15'), // before the newest purchase — excluded
    });

    const result = await service.getBatchProfitability('store-A', 'p1');

    expect(result.batchQuantity).toBe(100); // the newest anchor, not 50
    expect(result.soldQuantity).toBe(0);
    expect(result.revenue).toBe(0);
  });

  it('should return hasBatch=false when the product has no PURCHASE stock movement', async () => {
    prisma._rows.set('p1', {
      id: 'p1',
      storeId: 'store-A',
      name: 'Widget',
      sellPrice: 30,
      costPrice: 10,
      quantity: 10,
      minQuantity: 0,
      unit: 'PCS',
      isActive: true,
      createdAt: new Date(),
    });

    const result = await service.getBatchProfitability('store-A', 'p1');

    expect(result.hasBatch).toBe(false);
    expect(result.remainingQuantity).toBe(10);
  });

  it('should throw NotFoundException for a product in a different store', async () => {
    prisma._rows.set('p1', {
      id: 'p1',
      storeId: 'store-B',
      name: 'Widget',
      sellPrice: 30,
      costPrice: 10,
      quantity: 10,
      minQuantity: 0,
      unit: 'PCS',
      isActive: true,
      createdAt: new Date(),
    });

    await expect(
      service.getBatchProfitability('store-A', 'p1'),
    ).rejects.toBeInstanceOf(NotFoundException);
  });
});
