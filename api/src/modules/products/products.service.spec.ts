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

  return {
    _rows: rows,
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
      findMany: jest.fn(async ({ where, skip = 0, take = 20 }: any = {}) => {
        const all = Array.from(rows.values()).filter((r) => {
          if (where?.storeId && r.storeId !== where.storeId) return false;
          if (where?.categoryId && r.categoryId !== where.categoryId)
            return false;
          return true;
        });
        return all.slice(skip, skip + take);
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
