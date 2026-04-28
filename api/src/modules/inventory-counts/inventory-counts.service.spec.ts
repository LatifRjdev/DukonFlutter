import { Test } from '@nestjs/testing';
import { BadRequestException, NotFoundException } from '@nestjs/common';
import { InventoryCountsService } from './inventory-counts.service';
import { PrismaService } from '../../prisma/prisma.service';

type ProductRow = {
  id: string;
  storeId: string;
  isActive: boolean;
  quantity: number;
  name: string;
  sku: string | null;
  barcode: string | null;
  unit: string;
  sellPrice: number;
  costPrice: number | null;
};

type CountRow = {
  id: string;
  storeId: string;
  status: 'IN_PROGRESS' | 'COMPLETED' | 'CANCELLED';
  createdAt: Date;
  completedAt: Date | null;
};

type ItemRow = {
  id: string;
  inventoryCountId: string;
  productId: string;
  expectedQty: number;
  actualQty: number | null;
};

function makePrismaFake() {
  const products = new Map<string, ProductRow>();
  const counts = new Map<string, CountRow>();
  const items = new Map<string, ItemRow>();
  let cSeq = 0;
  let iSeq = 0;

  const filterCountItems = (count: CountRow) => {
    const arr: any[] = [];
    for (const it of items.values()) {
      if (it.inventoryCountId !== count.id) continue;
      const p = products.get(it.productId);
      arr.push({
        ...it,
        product: p
          ? {
              id: p.id,
              name: p.name,
              sku: p.sku,
              barcode: p.barcode,
              unit: p.unit,
              quantity: p.quantity,
              sellPrice: p.sellPrice,
              costPrice: p.costPrice,
            }
          : null,
      });
    }
    arr.sort((a, b) =>
      (a.product?.name ?? '').localeCompare(b.product?.name ?? ''),
    );
    return arr;
  };

  const product = {
    findMany: jest.fn(async ({ where, select }: any) => {
      void select;
      return Array.from(products.values()).filter((p) => {
        if (where.storeId && p.storeId !== where.storeId) return false;
        if (where.isActive !== undefined && p.isActive !== where.isActive)
          return false;
        return true;
      });
    }),
    update: jest.fn(async ({ where, data }: any) => {
      const p = products.get(where.id);
      if (!p) throw new Error('Product not found');
      Object.assign(p, data);
      return p;
    }),
  };

  const inventoryCount = {
    create: jest.fn(async ({ data, include }: any) => {
      void include;
      const id = `ic-${++cSeq}`;
      const row: CountRow = {
        id,
        storeId: data.storeId,
        status: 'IN_PROGRESS',
        createdAt: new Date(),
        completedAt: null,
      };
      counts.set(id, row);
      if (data.items?.create) {
        for (const it of data.items.create) {
          const itemId = `ici-${++iSeq}`;
          items.set(itemId, {
            id: itemId,
            inventoryCountId: id,
            productId: it.productId,
            expectedQty: it.expectedQty,
            actualQty: it.actualQty ?? null,
          });
        }
      }
      return { ...row, items: filterCountItems(row) };
    }),
    findFirst: jest.fn(async ({ where, include }: any) => {
      const row = counts.get(where.id);
      if (!row) return null;
      if (where.storeId && row.storeId !== where.storeId) return null;
      if (!include) return row;
      return { ...row, items: filterCountItems(row) };
    }),
    update: jest.fn(async ({ where, data }: any) => {
      const row = counts.get(where.id);
      if (!row) throw new Error('Count not found');
      Object.assign(row, data);
      return row;
    }),
  };

  const inventoryCountItem = {
    updateMany: jest.fn(async ({ where, data }: any) => {
      let count = 0;
      for (const it of items.values()) {
        if (it.inventoryCountId !== where.inventoryCountId) continue;
        if (where.productId && it.productId !== where.productId) continue;
        Object.assign(it, data);
        count++;
      }
      return { count };
    }),
  };

  const prisma: any = {
    product,
    inventoryCount,
    inventoryCountItem,
    $transaction: jest.fn(async (ops: Promise<any>[]) => Promise.all(ops)),
    __products: products,
    __counts: counts,
    __items: items,
  };
  return prisma;
}

describe('InventoryCountsService', () => {
  let service: InventoryCountsService;
  let prisma: ReturnType<typeof makePrismaFake>;

  beforeEach(async () => {
    prisma = makePrismaFake();
    const moduleRef = await Test.createTestingModule({
      providers: [
        InventoryCountsService,
        { provide: PrismaService, useValue: prisma },
      ],
    }).compile();
    service = moduleRef.get(InventoryCountsService);
  });

  const seedProduct = (
    overrides: Partial<ProductRow> & { id: string; storeId: string },
  ) => {
    const row: ProductRow = {
      isActive: true,
      quantity: 10,
      name: overrides.id,
      sku: null,
      barcode: null,
      unit: 'PCS',
      sellPrice: 100,
      costPrice: 50,
      ...overrides,
    };
    prisma.__products.set(row.id, row);
    return row;
  };

  describe('create', () => {
    it('should create count session with expectedQty mirroring product quantities when products exist', async () => {
      seedProduct({ id: 'p1', storeId: 'store-A', quantity: 25 });
      seedProduct({ id: 'p2', storeId: 'store-A', quantity: 7 });

      const result = await service.create('store-A');

      expect(result.storeId).toBe('store-A');
      expect(result.status).toBe('IN_PROGRESS');
      const expectedMap = Object.fromEntries(
        result.items.map((i: any) => [i.productId, i.expectedQty]),
      );
      expect(expectedMap).toEqual({ p1: 25, p2: 7 });
      // actualQty starts as null — variance not yet recorded
      expect(result.items.every((i: any) => i.actualQty === null)).toBe(true);
    });

    it('should throw BadRequestException when store has no active products', async () => {
      seedProduct({ id: 'p1', storeId: 'store-A', isActive: false });
      await expect(service.create('store-A')).rejects.toBeInstanceOf(
        BadRequestException,
      );
    });
  });

  describe('findOne — storeId scoping', () => {
    it('should throw NotFoundException when count session belongs to a different store', async () => {
      seedProduct({ id: 'p1', storeId: 'store-A' });
      const created = await service.create('store-A');

      await expect(
        service.findOne('store-OTHER', created.id),
      ).rejects.toBeInstanceOf(NotFoundException);
    });

    it('should return the session with items when storeId matches', async () => {
      seedProduct({ id: 'p1', storeId: 'store-A', quantity: 5 });
      const created = await service.create('store-A');
      const fetched = await service.findOne('store-A', created.id);
      expect(fetched.id).toBe(created.id);
      expect(fetched.items).toHaveLength(1);
    });
  });

  describe('updateItems — variance recording', () => {
    it('should persist actualQty so variance (expected - actual) can be derived', async () => {
      seedProduct({ id: 'p1', storeId: 'store-A', quantity: 50 });
      seedProduct({ id: 'p2', storeId: 'store-A', quantity: 10 });
      const created = await service.create('store-A');

      const updated = await service.updateItems('store-A', created.id, {
        items: [
          { productId: 'p1', actualQty: 47 }, // shrinkage of 3
          { productId: 'p2', actualQty: 12 }, // overage of 2
        ],
      });

      const byProduct = Object.fromEntries(
        updated.items.map((i: any) => [
          i.productId,
          { expected: i.expectedQty, actual: i.actualQty },
        ]),
      );
      expect(byProduct.p1).toEqual({ expected: 50, actual: 47 });
      expect(byProduct.p1.expected - byProduct.p1.actual).toBe(3);
      expect(byProduct.p2).toEqual({ expected: 10, actual: 12 });
      expect(byProduct.p2.actual - byProduct.p2.expected).toBe(2);
    });

    it('should throw BadRequestException when session is already COMPLETED', async () => {
      seedProduct({ id: 'p1', storeId: 'store-A', quantity: 10 });
      const created = await service.create('store-A');
      // Force-complete via fake
      prisma.__counts.get(created.id)!.status = 'COMPLETED';

      await expect(
        service.updateItems('store-A', created.id, {
          items: [{ productId: 'p1', actualQty: 9 }],
        }),
      ).rejects.toBeInstanceOf(BadRequestException);
    });
  });

  describe('apply — write back to product quantity', () => {
    it('should update product.quantity to actualQty (rounded) and mark session COMPLETED', async () => {
      seedProduct({ id: 'p1', storeId: 'store-A', quantity: 50 });
      seedProduct({ id: 'p2', storeId: 'store-A', quantity: 10 });
      const created = await service.create('store-A');
      await service.updateItems('store-A', created.id, {
        items: [
          { productId: 'p1', actualQty: 47.4 }, // rounds to 47
          { productId: 'p2', actualQty: 12.6 }, // rounds to 13
        ],
      });

      const result = await service.apply('store-A', created.id);

      expect(prisma.__products.get('p1')!.quantity).toBe(47);
      expect(prisma.__products.get('p2')!.quantity).toBe(13);
      expect(result.status).toBe('COMPLETED');
      expect(result.completedAt).not.toBeNull();
    });

    it('should throw BadRequestException when no items have actualQty filled in', async () => {
      seedProduct({ id: 'p1', storeId: 'store-A', quantity: 10 });
      const created = await service.create('store-A');
      // No updateItems call — actualQty stays null

      await expect(service.apply('store-A', created.id)).rejects.toBeInstanceOf(
        BadRequestException,
      );
      // Ensure product wasn't touched
      expect(prisma.__products.get('p1')!.quantity).toBe(10);
    });
  });
});
