import 'reflect-metadata';
import { Test } from '@nestjs/testing';
import {
  Logger,
  BadRequestException,
  NotFoundException,
} from '@nestjs/common';
import { SuppliersService } from './suppliers.service';
import { PrismaService } from '../../prisma/prisma.service';

// Behavioral fake of the Prisma slice SuppliersService uses. Map-backed,
// asserts persisted state and the no-go-below-zero debt invariant.
function makePrismaFake() {
  type SupplierRow = {
    id: string;
    storeId: string;
    name: string;
    phone: string | null;
    email: string | null;
    address: string | null;
    contact: string | null;
    notes: string | null;
    debt: number;
    createdAt: Date;
  };
  type SupplierPaymentRow = {
    id: string;
    storeId: string;
    supplierId: string;
    amount: number;
    method: string;
    notes: string | null;
    createdAt: Date;
  };

  const suppliers = new Map<string, SupplierRow>();
  const payments = new Map<string, SupplierPaymentRow>();
  let supSeq = 0;
  let paySeq = 0;

  const tx = {
    supplierPayment: {
      create: jest.fn(async ({ data }: any) => {
        const id = `pay-${++paySeq}`;
        const row: SupplierPaymentRow = {
          id,
          storeId: data.storeId,
          supplierId: data.supplierId,
          amount: data.amount,
          method: data.method,
          notes: data.notes ?? null,
          createdAt: new Date(),
        };
        payments.set(id, row);
        return row;
      }),
    },
    supplier: {
      update: jest.fn(async ({ where, data }: any) => {
        const s = suppliers.get(where.id);
        if (!s) throw new Error('not found');
        if (data.debt?.decrement !== undefined) {
          s.debt = s.debt - data.debt.decrement;
        } else if (typeof data.debt === 'number') {
          s.debt = data.debt;
        }
        return { ...s };
      }),
      updateMany: jest.fn(async ({ where, data }: any) => {
        let count = 0;
        for (const s of suppliers.values()) {
          if (where.id && s.id !== where.id) continue;
          if (where.debt?.lt !== undefined) {
            if (!(s.debt < where.debt.lt)) continue;
          }
          if (typeof data.debt === 'number') {
            s.debt = data.debt;
            count++;
          }
        }
        return { count };
      }),
    },
  };

  return {
    _suppliers: suppliers,
    _payments: payments,
    supplier: {
      findFirst: jest.fn(async ({ where }: any) => {
        for (const s of suppliers.values()) {
          if (where.id && s.id !== where.id) continue;
          if (where.storeId && s.storeId !== where.storeId) continue;
          return { ...s, products: [] };
        }
        return null;
      }),
      findMany: jest.fn(async ({ where, skip = 0, take = 20 }: any = {}) => {
        const all = Array.from(suppliers.values()).filter((s) => {
          if (where?.storeId && s.storeId !== where.storeId) return false;
          return true;
        });
        return all.slice(skip, skip + take);
      }),
      count: jest.fn(async ({ where }: any = {}) => {
        return Array.from(suppliers.values()).filter((s) => {
          if (where?.storeId && s.storeId !== where.storeId) return false;
          return true;
        }).length;
      }),
      create: jest.fn(async ({ data }: any) => {
        const id = `sup-${++supSeq}`;
        const row: SupplierRow = {
          id,
          storeId: data.storeId,
          name: data.name,
          phone: data.phone ?? null,
          email: data.email ?? null,
          address: data.address ?? null,
          contact: data.contact ?? null,
          notes: data.notes ?? null,
          debt: data.debt ?? 0,
          createdAt: new Date(),
        };
        suppliers.set(id, row);
        return { ...row };
      }),
      update: jest.fn(async ({ where, data }: any) => {
        const s = suppliers.get(where.id);
        if (!s) throw new Error('not found');
        for (const k of Object.keys(data)) {
          (s as any)[k] = data[k];
        }
        return { ...s };
      }),
      delete: jest.fn(async ({ where }: any) => {
        const s = suppliers.get(where.id);
        if (!s) throw new Error('not found');
        suppliers.delete(where.id);
        return s;
      }),
    },
    supplierPayment: {
      findMany: jest.fn(async ({ where }: any) => {
        return Array.from(payments.values()).filter((p) => {
          if (where?.supplierId && p.supplierId !== where.supplierId)
            return false;
          if (where?.storeId && p.storeId !== where.storeId) return false;
          return true;
        });
      }),
    },
    $transaction: jest.fn(async (fn: any) => fn(tx)),
  };
}

describe('SuppliersService', () => {
  let service: SuppliersService;
  let prisma: ReturnType<typeof makePrismaFake>;

  const seedSupplier = (overrides: Partial<any> = {}) => {
    const row = {
      id: 'sup-A',
      storeId: 'store-A',
      name: 'Acme Wholesale',
      phone: null,
      email: null,
      address: null,
      contact: null,
      notes: null,
      debt: 200,
      createdAt: new Date(),
      ...overrides,
    };
    prisma._suppliers.set(row.id, row);
    return row;
  };

  beforeEach(async () => {
    jest.spyOn(Logger.prototype, 'log').mockImplementation(() => {});
    prisma = makePrismaFake();
    const moduleRef = await Test.createTestingModule({
      providers: [
        SuppliersService,
        { provide: PrismaService, useValue: prisma },
      ],
    }).compile();
    service = moduleRef.get(SuppliersService);
  });

  describe('findOne (scoping)', () => {
    it('should throw NotFoundException when supplier belongs to a different store', async () => {
      seedSupplier({ id: 'sup-A', storeId: 'store-A' });
      await expect(
        service.findOne('store-B', 'sup-A'),
      ).rejects.toBeInstanceOf(NotFoundException);
    });
  });

  describe('findAll (scoping)', () => {
    it('should NOT return another store\'s suppliers when listing for a store', async () => {
      seedSupplier({ id: 'sup-A', storeId: 'store-A', name: 'AcmeA' });
      seedSupplier({ id: 'sup-B', storeId: 'store-B', name: 'OtherB' });

      const result = await service.findAll('store-A');
      const names = (result.data as any[]).map((s) => s.name);
      expect(names).toContain('AcmeA');
      expect(names).not.toContain('OtherB');
    });
  });

  describe('update (scoping)', () => {
    it('should throw NotFoundException when updating a supplier that belongs to a different store', async () => {
      seedSupplier({ id: 'sup-A', storeId: 'store-A' });
      await expect(
        service.update('store-B', 'sup-A', { name: 'Hijacked' } as any),
      ).rejects.toBeInstanceOf(NotFoundException);
      // Original record is untouched.
      expect(prisma._suppliers.get('sup-A')!.name).toBe('Acme Wholesale');
    });
  });

  describe('addPayment', () => {
    it('should decrement supplier.debt and create a SupplierPayment when payment is valid', async () => {
      seedSupplier({ debt: 200 });

      const result: any = await service.addPayment('store-A', 'sup-A', {
        amount: 75,
        method: 'CASH',
      } as any);

      expect(result.amount).toBe(75);
      expect(result.supplierId).toBe('sup-A');
      expect(prisma._suppliers.get('sup-A')!.debt).toBe(125);
      expect(prisma._payments.size).toBe(1);
    });

    it('should throw BadRequestException when payment exceeds outstanding supplier debt', async () => {
      seedSupplier({ debt: 50 });

      await expect(
        service.addPayment('store-A', 'sup-A', {
          amount: 100,
          method: 'CASH',
        } as any),
      ).rejects.toBeInstanceOf(BadRequestException);

      // Debt untouched on rejection.
      expect(prisma._suppliers.get('sup-A')!.debt).toBe(50);
      expect(prisma._payments.size).toBe(0);
    });

    it('should throw BadRequestException when supplier has zero outstanding debt', async () => {
      seedSupplier({ debt: 0 });
      await expect(
        service.addPayment('store-A', 'sup-A', {
          amount: 10,
          method: 'CASH',
        } as any),
      ).rejects.toBeInstanceOf(BadRequestException);
    });

    it('should throw NotFoundException when adding payment to a supplier in another store (scoping)', async () => {
      seedSupplier({ id: 'sup-A', storeId: 'store-A', debt: 200 });
      await expect(
        service.addPayment('store-B', 'sup-A', {
          amount: 10,
          method: 'CASH',
        } as any),
      ).rejects.toBeInstanceOf(NotFoundException);
    });
  });
});
