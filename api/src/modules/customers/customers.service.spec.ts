import 'reflect-metadata';
import { Test } from '@nestjs/testing';
import {
  Logger,
  BadRequestException,
  ConflictException,
  NotFoundException,
} from '@nestjs/common';
import { CustomersService } from './customers.service';
import { PrismaService } from '../../prisma/prisma.service';

// Behavioral fake. Tracks customers, sales, and debtPayments in Maps so we
// can assert debt decrement, scoping (storeId), and the no-go-below-zero
// invariant inside the addPayment $transaction.
function makePrismaFake() {
  type CustomerRow = {
    id: string;
    storeId: string;
    name: string;
    phone: string | null;
    email: string | null;
    birthday: Date | null;
    notes: string | null;
    isActive: boolean;
    debt: number;
    createdAt: Date;
  };
  type SaleRow = {
    id: string;
    storeId: string;
    customerId: string | null;
    debtAmount: number;
    total: number;
    status: 'COMPLETED' | 'PENDING';
    receiptNo: string;
    createdAt: Date;
  };
  type DebtPaymentRow = {
    id: string;
    saleId: string;
    amount: number;
    method: string;
    notes: string | null;
    createdAt: Date;
  };

  const customers = new Map<string, CustomerRow>();
  const sales = new Map<string, SaleRow>();
  const payments = new Map<string, DebtPaymentRow>();
  let custSeq = 0;
  let paySeq = 0;

  // The transactional client uses the same underlying maps, so writes
  // propagate without explicit commit semantics. Sufficient for behavior tests.
  const tx = {
    debtPayment: {
      create: jest.fn(async ({ data }: any) => {
        const id = `pay-${++paySeq}`;
        const row: DebtPaymentRow = {
          id,
          saleId: data.saleId,
          amount: data.amount,
          method: data.method,
          notes: data.notes ?? null,
          createdAt: new Date(),
        };
        payments.set(id, row);
        return row;
      }),
    },
    sale: {
      update: jest.fn(async ({ where, data }: any) => {
        const sale = sales.get(where.id);
        if (!sale) throw new Error('not found');
        if (data.debtAmount?.decrement !== undefined) {
          sale.debtAmount = sale.debtAmount - data.debtAmount.decrement;
        } else if (typeof data.debtAmount === 'number') {
          sale.debtAmount = data.debtAmount;
        }
        return { ...sale };
      }),
      updateMany: jest.fn(async ({ where, data }: any) => {
        let count = 0;
        for (const sale of sales.values()) {
          if (where.id && sale.id !== where.id) continue;
          if (where.debtAmount?.lt !== undefined) {
            if (!(sale.debtAmount < where.debtAmount.lt)) continue;
          }
          // F-RACE-3: addPayment now uses conditional `gte` +
          // `decrement` for atomic check-and-pay.
          if (where.debtAmount?.gte !== undefined) {
            if (!(sale.debtAmount >= where.debtAmount.gte)) continue;
          }
          if (typeof data.debtAmount === 'number') {
            sale.debtAmount = data.debtAmount;
            count++;
          } else if (data.debtAmount?.decrement !== undefined) {
            sale.debtAmount = sale.debtAmount - data.debtAmount.decrement;
            count++;
          }
        }
        return { count };
      }),
    },
    customer: {
      update: jest.fn(async ({ where, data }: any) => {
        const c = customers.get(where.id);
        if (!c) throw new Error('not found');
        if (data.debt?.decrement !== undefined) {
          c.debt = c.debt - data.debt.decrement;
        } else if (typeof data.debt === 'number') {
          c.debt = data.debt;
        }
        return { ...c };
      }),
      updateMany: jest.fn(async ({ where, data }: any) => {
        let count = 0;
        for (const c of customers.values()) {
          if (where.id && c.id !== where.id) continue;
          if (where.debt?.lt !== undefined) {
            if (!(c.debt < where.debt.lt)) continue;
          }
          if (where.debt?.gte !== undefined) {
            if (!(c.debt >= where.debt.gte)) continue;
          }
          if (typeof data.debt === 'number') {
            c.debt = data.debt;
            count++;
          } else if (data.debt?.decrement !== undefined) {
            c.debt = c.debt - data.debt.decrement;
            count++;
          }
        }
        return { count };
      }),
    },
  };

  return {
    _customers: customers,
    _sales: sales,
    _payments: payments,
    customer: {
      findUnique: jest.fn(async ({ where, select }: any) => {
        if (where.storeId_phone) {
          const { storeId, phone } = where.storeId_phone;
          for (const c of customers.values()) {
            if (c.storeId === storeId && c.phone === phone) return { ...c };
          }
          return null;
        }
        const c = customers.get(where.id);
        if (!c) return null;
        if (select) {
          const out: any = {};
          for (const k of Object.keys(select)) {
            if (select[k]) out[k] = (c as any)[k];
          }
          return out;
        }
        return { ...c };
      }),
      findFirst: jest.fn(async ({ where }: any) => {
        for (const c of customers.values()) {
          if (where.id && c.id !== where.id) continue;
          if (where.storeId && c.storeId !== where.storeId) continue;
          return { ...c, sales: [] };
        }
        return null;
      }),
      findMany: jest.fn(async ({ where, skip = 0, take = 20 }: any = {}) => {
        const all = Array.from(customers.values()).filter((c) => {
          if (where?.storeId && c.storeId !== where.storeId) return false;
          if (where?.isActive !== undefined && c.isActive !== where.isActive)
            return false;
          return true;
        });
        return all.slice(skip, skip + take);
      }),
      count: jest.fn(async ({ where }: any = {}) => {
        return Array.from(customers.values()).filter((c) => {
          if (where?.storeId && c.storeId !== where.storeId) return false;
          if (where?.isActive !== undefined && c.isActive !== where.isActive)
            return false;
          return true;
        }).length;
      }),
      create: jest.fn(async ({ data }: any) => {
        const id = `cust-${++custSeq}`;
        const row: CustomerRow = {
          id,
          storeId: data.storeId,
          name: data.name,
          phone: data.phone ?? null,
          email: data.email ?? null,
          birthday: data.birthday ?? null,
          notes: data.notes ?? null,
          isActive: true,
          debt: 0,
          createdAt: new Date(),
        };
        customers.set(id, row);
        return { ...row };
      }),
      update: jest.fn(async ({ where, data }: any) => {
        const c = customers.get(where.id);
        if (!c) throw new Error('not found');
        for (const k of Object.keys(data)) {
          (c as any)[k] = data[k];
        }
        return { ...c };
      }),
    },
    sale: {
      findFirst: jest.fn(async ({ where }: any) => {
        for (const s of sales.values()) {
          if (where.id && s.id !== where.id) continue;
          if (where.customerId && s.customerId !== where.customerId) continue;
          if (where.storeId && s.storeId !== where.storeId) continue;
          return { ...s };
        }
        return null;
      }),
      findMany: jest.fn(async () => []),
    },
    debtPayment: {
      findMany: jest.fn(async () => Array.from(payments.values())),
    },
    $transaction: jest.fn(async (fn: any) => fn(tx)),
  };
}

describe('CustomersService', () => {
  let service: CustomersService;
  let prisma: ReturnType<typeof makePrismaFake>;

  const seedCustomer = (overrides: Partial<any> = {}) => {
    const row = {
      id: 'cust-A',
      storeId: 'store-A',
      name: 'Bob',
      phone: '+992900111222',
      email: null,
      birthday: null,
      notes: null,
      isActive: true,
      debt: 100,
      createdAt: new Date(),
      ...overrides,
    };
    prisma._customers.set(row.id, row);
    return row;
  };

  const seedSale = (overrides: Partial<any> = {}) => {
    const row = {
      id: 'sale-1',
      storeId: 'store-A',
      customerId: 'cust-A',
      debtAmount: 100,
      total: 100,
      status: 'COMPLETED' as const,
      receiptNo: 'R-1',
      createdAt: new Date(),
      ...overrides,
    };
    prisma._sales.set(row.id, row);
    return row;
  };

  beforeEach(async () => {
    jest.spyOn(Logger.prototype, 'log').mockImplementation(() => {});
    prisma = makePrismaFake();
    const moduleRef = await Test.createTestingModule({
      providers: [
        CustomersService,
        { provide: PrismaService, useValue: prisma },
      ],
    }).compile();
    service = moduleRef.get(CustomersService);
  });

  describe('create', () => {
    it('should throw ConflictException when customer with the same phone already exists in the same store', async () => {
      seedCustomer({ phone: '+992900111222' });
      await expect(
        service.create('store-A', {
          name: 'Other',
          phone: '+992900111222',
        } as any),
      ).rejects.toBeInstanceOf(ConflictException);
    });

    it('should allow same phone across different stores when scoping is per-store', async () => {
      seedCustomer({ storeId: 'store-A', phone: '+992900111222' });
      const result = await service.create('store-B', {
        name: 'Other',
        phone: '+992900111222',
      } as any);
      expect(result.storeId).toBe('store-B');
    });
  });

  describe('findOne (scoping)', () => {
    it('should throw NotFoundException when customer belongs to a different store', async () => {
      seedCustomer({ id: 'cust-A', storeId: 'store-A' });
      await expect(
        service.findOne('store-B', 'cust-A'),
      ).rejects.toBeInstanceOf(NotFoundException);
    });
  });

  describe('remove (soft delete)', () => {
    it('should mark customer isActive=false rather than hard-deleting when remove is called', async () => {
      seedCustomer();
      await service.remove('store-A', 'cust-A');
      expect(prisma._customers.get('cust-A')!.isActive).toBe(false);
      // Row still exists — no hard delete.
      expect(prisma._customers.has('cust-A')).toBe(true);
    });
  });

  describe('addPayment', () => {
    it('should decrement both sale.debtAmount and customer.debt by payment amount when payment is valid', async () => {
      seedCustomer({ debt: 100 });
      seedSale({ debtAmount: 100 });

      await service.addPayment('store-A', 'cust-A', {
        saleId: 'sale-1',
        amount: 40,
        method: 'CASH',
      } as any);

      expect(prisma._sales.get('sale-1')!.debtAmount).toBe(60);
      expect(prisma._customers.get('cust-A')!.debt).toBe(60);
    });

    it('should throw BadRequestException when payment amount exceeds the outstanding debt on a sale', async () => {
      seedCustomer({ debt: 100 });
      seedSale({ debtAmount: 30 });

      await expect(
        service.addPayment('store-A', 'cust-A', {
          saleId: 'sale-1',
          amount: 50,
          method: 'CASH',
        } as any),
      ).rejects.toBeInstanceOf(BadRequestException);

      // Critical invariant: nothing was mutated on a rejected payment.
      expect(prisma._sales.get('sale-1')!.debtAmount).toBe(30);
      expect(prisma._customers.get('cust-A')!.debt).toBe(100);
    });

    it('should throw BadRequestException when sale already has zero debt', async () => {
      seedCustomer({ debt: 0 });
      seedSale({ debtAmount: 0 });
      await expect(
        service.addPayment('store-A', 'cust-A', {
          saleId: 'sale-1',
          amount: 10,
          method: 'CASH',
        } as any),
      ).rejects.toBeInstanceOf(BadRequestException);
    });

    it('should throw NotFoundException when saleId does not belong to the customer/store', async () => {
      seedCustomer();
      seedSale({ id: 'sale-1', storeId: 'store-OTHER' });
      await expect(
        service.addPayment('store-A', 'cust-A', {
          saleId: 'sale-1',
          amount: 10,
          method: 'CASH',
        } as any),
      ).rejects.toBeInstanceOf(NotFoundException);
    });
  });
});
