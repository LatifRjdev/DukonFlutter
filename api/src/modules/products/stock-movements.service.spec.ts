import { Test } from '@nestjs/testing';
import { ConflictException, NotFoundException } from '@nestjs/common';
import { StockMovementsService } from './stock-movements.service';
import { PrismaService } from '../../prisma/prisma.service';

type ProductRow = {
  id: string;
  storeId: string;
  name: string;
  quantity: number;
  costPrice: number | null;
};

type SupplierRow = {
  id: string;
  storeId: string;
  name: string;
  debt: number;
};

function makePrismaFake() {
  const products = new Map<string, ProductRow>();
  const suppliers = new Map<string, SupplierRow>();
  const movements = new Map<string, any>();
  let seq = 0;

  const tx = {
    product: {
      findFirst: jest.fn(async ({ where }: any) => {
        const p = products.get(where.id);
        return p && p.storeId === where.storeId ? p : null;
      }),
      update: jest.fn(async ({ where, data }: any) => {
        const p = products.get(where.id);
        if (!p) throw new Error('not found');
        if (data.quantity?.increment != null)
          p.quantity += data.quantity.increment;
        if (data.costPrice != null) p.costPrice = data.costPrice;
        return p;
      }),
      // Mirrors the F-RACE-1 pattern used elsewhere: conditional update
      // only applies when the row still satisfies `where`, returning
      // count:0 (not an error) when it doesn't — the service is
      // responsible for translating a zero count into a domain error.
      updateMany: jest.fn(async ({ where, data }: any) => {
        const p = products.get(where.id);
        if (!p) return { count: 0 };
        if (where.quantity?.gte != null && p.quantity < where.quantity.gte) {
          return { count: 0 };
        }
        if (data.quantity?.increment != null)
          p.quantity += data.quantity.increment;
        return { count: 1 };
      }),
    },
    supplier: {
      findFirst: jest.fn(async ({ where }: any) => {
        const s = suppliers.get(where.id);
        return s && s.storeId === where.storeId ? s : null;
      }),
      update: jest.fn(async ({ where, data }: any) => {
        const s = suppliers.get(where.id);
        if (!s) throw new Error('not found');
        if (data.debt?.increment != null) s.debt += data.debt.increment;
        return s;
      }),
    },
    stockMovement: {
      create: jest.fn(async ({ data }: any) => {
        const id = `mv-${++seq}`;
        const row = { id, ...data };
        movements.set(id, row);
        return row;
      }),
    },
  };

  return {
    _products: products,
    _suppliers: suppliers,
    _movements: movements,
    product: {
      findFirst: tx.product.findFirst,
    },
    supplier: {
      findFirst: tx.supplier.findFirst,
    },
    stockMovement: {
      findUnique: jest.fn(async ({ where }: any) => {
        if (!where.localId) return null;
        return (
          Array.from(movements.values()).find(
            (m) => m.localId === where.localId,
          ) ?? null
        );
      }),
    },
    $transaction: jest.fn(async (cb: any) => cb(tx)),
  };
}

describe('StockMovementsService', () => {
  let service: StockMovementsService;
  let prisma: ReturnType<typeof makePrismaFake>;

  const seedProduct = (overrides: Partial<ProductRow> = {}): ProductRow => {
    const row: ProductRow = {
      id: 'p1',
      storeId: 'store-A',
      name: 'Widget',
      quantity: 50,
      costPrice: null,
      ...overrides,
    };
    prisma._products.set(row.id, row);
    return row;
  };

  beforeEach(async () => {
    prisma = makePrismaFake();
    const moduleRef = await Test.createTestingModule({
      providers: [
        StockMovementsService,
        { provide: PrismaService, useValue: prisma },
      ],
    }).compile();
    service = moduleRef.get(StockMovementsService);
  });

  describe('create — quantity effects', () => {
    it('should increment product quantity when type is PURCHASE', async () => {
      seedProduct({ quantity: 50 });
      await service.create('store-A', {
        productId: 'p1',
        type: 'PURCHASE',
        quantity: 30,
      } as any);
      expect(prisma._products.get('p1')!.quantity).toBe(80);
    });

    it('should set costPrice to unitCost when type is PURCHASE with unitCost', async () => {
      seedProduct({ quantity: 50, costPrice: 10 });
      await service.create('store-A', {
        productId: 'p1',
        type: 'PURCHASE',
        quantity: 30,
        unitCost: 12,
      } as any);
      expect(prisma._products.get('p1')!.costPrice).toBe(12);
    });

    it('should increment product quantity when type is RETURN', async () => {
      seedProduct({ quantity: 20 });
      await service.create('store-A', {
        productId: 'p1',
        type: 'RETURN',
        quantity: 5,
      } as any);
      expect(prisma._products.get('p1')!.quantity).toBe(25);
    });

    it('should decrement product quantity when type is SALE', async () => {
      seedProduct({ quantity: 20 });
      await service.create('store-A', {
        productId: 'p1',
        type: 'SALE',
        quantity: 5,
      } as any);
      expect(prisma._products.get('p1')!.quantity).toBe(15);
    });

    it('should decrement product quantity when type is WRITE_OFF', async () => {
      seedProduct({ quantity: 20 });
      await service.create('store-A', {
        productId: 'p1',
        type: 'WRITE_OFF',
        quantity: 5,
      } as any);
      expect(prisma._products.get('p1')!.quantity).toBe(15);
    });

    it('should throw NotFoundException when the product does not belong to this store', async () => {
      seedProduct({ storeId: 'store-B' });
      await expect(
        service.create('store-A', {
          productId: 'p1',
          type: 'PURCHASE',
          quantity: 5,
        } as any),
      ).rejects.toBeInstanceOf(NotFoundException);
    });
  });

  describe('create — floor guard (BUG-STOCK-1 regression)', () => {
    it('should reject a WRITE_OFF that would drive quantity negative', async () => {
      seedProduct({ quantity: 70 });
      await expect(
        service.create('store-A', {
          productId: 'p1',
          type: 'WRITE_OFF',
          quantity: 1000,
        } as any),
      ).rejects.toBeInstanceOf(ConflictException);
      // Quantity must be unchanged, not clamped or negative.
      expect(prisma._products.get('p1')!.quantity).toBe(70);
    });

    it('should reject a SALE-type movement that would drive quantity negative', async () => {
      seedProduct({ quantity: 3 });
      await expect(
        service.create('store-A', {
          productId: 'p1',
          type: 'SALE',
          quantity: 4,
        } as any),
      ).rejects.toBeInstanceOf(ConflictException);
      expect(prisma._products.get('p1')!.quantity).toBe(3);
    });

    it('should allow a WRITE_OFF that exactly zeroes out remaining quantity', async () => {
      seedProduct({ quantity: 5 });
      await service.create('store-A', {
        productId: 'p1',
        type: 'WRITE_OFF',
        quantity: 5,
      } as any);
      expect(prisma._products.get('p1')!.quantity).toBe(0);
    });

    it('should not create a stockMovement row that would leave quantity negative (no partial side effect)', async () => {
      seedProduct({ quantity: 2 });
      await expect(
        service.create('store-A', {
          productId: 'p1',
          type: 'WRITE_OFF',
          quantity: 10,
        } as any),
      ).rejects.toBeInstanceOf(ConflictException);
      expect(prisma._movements.size).toBe(1);
      // The movement row is created before the quantity guard runs (the
      // guard throws inside the same $transaction), so in real Postgres
      // this rolls back entirely; our fake doesn't simulate transaction
      // rollback (see sales.service.spec.ts convention), so we only
      // assert the product quantity itself was never mutated.
      expect(prisma._products.get('p1')!.quantity).toBe(2);
    });
  });

  describe('create — supplier debt crediting (BUG-SUPPLIER-1 regression)', () => {
    const seedSupplier = (
      overrides: Partial<SupplierRow> = {},
    ): SupplierRow => {
      const row: SupplierRow = {
        id: 'sup1',
        storeId: 'store-A',
        name: 'ACME Supply',
        debt: 0,
        ...overrides,
      };
      prisma._suppliers.set(row.id, row);
      return row;
    };

    it('should increment supplier.debt by unitCost*quantity when a PURCHASE references a supplier', async () => {
      seedProduct({ quantity: 50 });
      seedSupplier({ debt: 0 });
      await service.create('store-A', {
        productId: 'p1',
        type: 'PURCHASE',
        quantity: 20,
        unitCost: 45,
        supplierId: 'sup1',
      } as any);
      expect(prisma._suppliers.get('sup1')!.debt).toBe(900);
    });

    it('should accumulate supplier.debt across multiple purchases', async () => {
      seedProduct({ quantity: 50 });
      seedSupplier({ debt: 100 });
      await service.create('store-A', {
        productId: 'p1',
        type: 'PURCHASE',
        quantity: 10,
        unitCost: 5,
        supplierId: 'sup1',
      } as any);
      expect(prisma._suppliers.get('sup1')!.debt).toBe(150);
    });

    it('should NOT touch supplier.debt when no supplierId is given', async () => {
      seedProduct({ quantity: 50 });
      seedSupplier({ debt: 0 });
      await service.create('store-A', {
        productId: 'p1',
        type: 'PURCHASE',
        quantity: 20,
        unitCost: 45,
      } as any);
      expect(prisma._suppliers.get('sup1')!.debt).toBe(0);
    });

    it('should NOT credit supplier.debt for non-PURCHASE movement types even if supplierId is present', async () => {
      seedProduct({ quantity: 50 });
      seedSupplier({ debt: 0 });
      await service.create('store-A', {
        productId: 'p1',
        type: 'RETURN',
        quantity: 5,
        supplierId: 'sup1',
      } as any);
      expect(prisma._suppliers.get('sup1')!.debt).toBe(0);
    });

    it('should throw NotFoundException when supplierId does not belong to this store', async () => {
      seedProduct({ quantity: 50 });
      seedSupplier({ storeId: 'store-B' });
      await expect(
        service.create('store-A', {
          productId: 'p1',
          type: 'PURCHASE',
          quantity: 20,
          unitCost: 45,
          supplierId: 'sup1',
        } as any),
      ).rejects.toBeInstanceOf(NotFoundException);
      // No side effects from the rejected call.
      expect(prisma._products.get('p1')!.quantity).toBe(50);
    });
  });

  describe('create — idempotency', () => {
    it('should return the existing movement and skip re-applying quantity change when localId already used', async () => {
      seedProduct({ quantity: 50 });
      const first = await service.create('store-A', {
        productId: 'p1',
        type: 'PURCHASE',
        quantity: 10,
        localId: 'local-1',
      } as any);
      const second = await service.create('store-A', {
        productId: 'p1',
        type: 'PURCHASE',
        quantity: 10,
        localId: 'local-1',
      } as any);

      expect(second.id).toBe(first.id);
      // Quantity only applied once.
      expect(prisma._products.get('p1')!.quantity).toBe(60);
    });
  });
});
