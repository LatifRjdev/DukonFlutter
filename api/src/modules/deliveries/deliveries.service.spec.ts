import 'reflect-metadata';
import { Test } from '@nestjs/testing';
import { BadRequestException, NotFoundException } from '@nestjs/common';
import { DeliveriesService } from './deliveries.service';
import { PrismaService } from '../../prisma/prisma.service';
import { DeliveryStatus } from '@prisma/client';

// Behavioral fake of the Prisma slice DeliveriesService uses. Stores
// Deliveries, Sales, and Staff in Maps so we can exercise storeId scoping,
// the one-delivery-per-sale invariant, and the NEW -> IN_TRANSIT ->
// DELIVERED / CANCELLED status transition machine without a real DB.
function makePrismaFake() {
  type SaleRow = {
    id: string;
    storeId: string;
    receiptNo: string;
    total: number;
    customer: { id: string; name: string; phone: string } | null;
    items: {
      id: string;
      product: { id: string; name: string; barcode: string; unit: string };
    }[];
  };
  type StaffRow = {
    id: string;
    storeId: string;
    role: string;
    user: { name: string; phone: string };
  };
  type DeliveryRow = {
    id: string;
    storeId: string;
    saleId: string;
    address: string;
    courierId: string | null;
    status: DeliveryStatus;
    notes: string | null;
    createdAt: Date;
    updatedAt: Date;
  };

  const sales = new Map<string, SaleRow>();
  const staff = new Map<string, StaffRow>();
  const deliveries = new Map<string, DeliveryRow>();
  let seq = 0;
  const newId = () => `delivery-${++seq}`;

  // Mirrors the `include` shape used by create/findAll/updateStatus (summary
  // sale + summary courier).
  const buildListInclude = (row: DeliveryRow) => {
    const sale = sales.get(row.saleId);
    const courier = row.courierId ? staff.get(row.courierId) : undefined;
    return {
      ...row,
      sale: sale
        ? {
            id: sale.id,
            receiptNo: sale.receiptNo,
            total: sale.total,
            customer: sale.customer,
          }
        : null,
      courier: courier
        ? { id: row.courierId, user: { name: courier.user.name }, role: courier.role }
        : null,
    };
  };

  // Mirrors the deeper `include` shape used by findOne (sale.items.product,
  // full courier contact info).
  const buildDetailInclude = (row: DeliveryRow) => {
    const sale = sales.get(row.saleId);
    const courier = row.courierId ? staff.get(row.courierId) : undefined;
    return {
      ...row,
      sale: sale ? { ...sale, items: sale.items, customer: sale.customer } : null,
      courier: courier
        ? {
            id: row.courierId,
            role: courier.role,
            user: { name: courier.user.name, phone: courier.user.phone },
          }
        : null,
    };
  };

  return {
    _sales: sales,
    _staff: staff,
    _deliveries: deliveries,
    sale: {
      findFirst: jest.fn(async ({ where }: any) => {
        for (const s of sales.values()) {
          if (where.id && s.id !== where.id) continue;
          if (where.storeId && s.storeId !== where.storeId) continue;
          return { ...s };
        }
        return null;
      }),
    },
    staff: {
      findFirst: jest.fn(async ({ where }: any) => {
        for (const s of staff.values()) {
          if (where.id && s.id !== where.id) continue;
          if (where.storeId && s.storeId !== where.storeId) continue;
          return { ...s };
        }
        return null;
      }),
    },
    delivery: {
      findUnique: jest.fn(async ({ where }: any) => {
        if (where.saleId) {
          for (const d of deliveries.values()) {
            if (d.saleId === where.saleId) return { ...d };
          }
          return null;
        }
        const d = deliveries.get(where.id);
        return d ? { ...d } : null;
      }),
      findFirst: jest.fn(async ({ where }: any) => {
        for (const d of deliveries.values()) {
          if (where.id && d.id !== where.id) continue;
          if (where.storeId && d.storeId !== where.storeId) continue;
          return buildDetailInclude(d);
        }
        return null;
      }),
      findMany: jest.fn(
        async ({ where, orderBy, skip = 0, take = 20 }: any = {}) => {
          let all = Array.from(deliveries.values()).filter((d) => {
            if (where?.storeId && d.storeId !== where.storeId) return false;
            if (where?.status && d.status !== where.status) return false;
            if (where?.createdAt?.gte && d.createdAt < where.createdAt.gte)
              return false;
            if (where?.createdAt?.lte && d.createdAt > where.createdAt.lte)
              return false;
            return true;
          });
          if (orderBy?.createdAt === 'desc') {
            all = all.sort(
              (a, b) => b.createdAt.getTime() - a.createdAt.getTime(),
            );
          }
          return all.slice(skip, skip + take).map(buildListInclude);
        },
      ),
      count: jest.fn(async ({ where }: any = {}) => {
        return Array.from(deliveries.values()).filter((d) => {
          if (where?.storeId && d.storeId !== where.storeId) return false;
          if (where?.status && d.status !== where.status) return false;
          if (where?.createdAt?.gte && d.createdAt < where.createdAt.gte)
            return false;
          if (where?.createdAt?.lte && d.createdAt > where.createdAt.lte)
            return false;
          return true;
        }).length;
      }),
      create: jest.fn(async ({ data }: any) => {
        const id = newId();
        const now = new Date();
        const row: DeliveryRow = {
          id,
          storeId: data.storeId,
          saleId: data.saleId,
          address: data.address,
          courierId: data.courierId ?? null,
          notes: data.notes ?? null,
          status: DeliveryStatus.NEW,
          createdAt: now,
          updatedAt: now,
        };
        deliveries.set(id, row);
        return buildListInclude(row);
      }),
      update: jest.fn(async ({ where, data }: any) => {
        const row = deliveries.get(where.id);
        if (!row) throw new Error('not found');
        if (data.status) row.status = data.status;
        row.updatedAt = new Date();
        return buildListInclude(row);
      }),
    },
  };
}

describe('DeliveriesService', () => {
  let service: DeliveriesService;
  let prisma: ReturnType<typeof makePrismaFake>;

  const seedSale = (overrides: Partial<any> = {}) => {
    const row = {
      id: 'sale-1',
      storeId: 'store-A',
      receiptNo: 'R-1',
      total: 100,
      customer: { id: 'cust-1', name: 'Bob', phone: '+992900111222' },
      items: [
        {
          id: 'item-1',
          product: { id: 'prod-1', name: 'Bread', barcode: '111', unit: 'pcs' },
        },
      ],
      ...overrides,
    };
    prisma._sales.set(row.id, row);
    return row;
  };

  const seedStaff = (overrides: Partial<any> = {}) => {
    const row = {
      id: 'staff-1',
      storeId: 'store-A',
      role: 'COURIER',
      user: { name: 'Courier Joe', phone: '+992900333444' },
      ...overrides,
    };
    prisma._staff.set(row.id, row);
    return row;
  };

  const seedDelivery = (overrides: Partial<any> = {}) => {
    const now = new Date();
    const row = {
      id: 'delivery-A',
      storeId: 'store-A',
      saleId: 'sale-1',
      address: '123 Main St',
      courierId: null,
      status: DeliveryStatus.NEW,
      notes: null,
      createdAt: now,
      updatedAt: now,
      ...overrides,
    };
    prisma._deliveries.set(row.id, row);
    return row;
  };

  beforeEach(async () => {
    prisma = makePrismaFake();
    const moduleRef = await Test.createTestingModule({
      providers: [
        DeliveriesService,
        { provide: PrismaService, useValue: prisma },
      ],
    }).compile();
    service = moduleRef.get(DeliveriesService);
  });

  describe('create', () => {
    it('should create a delivery with NEW status when the sale exists in the store and has no existing delivery', async () => {
      seedSale();
      const result: any = await service.create('store-A', {
        saleId: 'sale-1',
        address: '123 Main St',
      } as any);

      expect(result.status).toBe(DeliveryStatus.NEW);
      expect(result.storeId).toBe('store-A');
      expect(result.saleId).toBe('sale-1');
      expect(prisma._deliveries.size).toBe(1);
    });

    it('should throw NotFoundException when the sale does not belong to this store (cross-store scoping)', async () => {
      seedSale({ id: 'sale-1', storeId: 'store-OTHER' });
      await expect(
        service.create('store-A', {
          saleId: 'sale-1',
          address: '123 Main St',
        } as any),
      ).rejects.toBeInstanceOf(NotFoundException);
      expect(prisma._deliveries.size).toBe(0);
    });

    it('should throw BadRequestException when the sale already has a delivery', async () => {
      seedSale();
      seedDelivery({ id: 'delivery-existing', saleId: 'sale-1' });

      await expect(
        service.create('store-A', {
          saleId: 'sale-1',
          address: '456 Other St',
        } as any),
      ).rejects.toBeInstanceOf(BadRequestException);
      // No second delivery was created for the same sale.
      expect(prisma._deliveries.size).toBe(1);
    });

    it('should throw NotFoundException when courierId does not belong to this store', async () => {
      seedSale();
      seedStaff({ id: 'staff-1', storeId: 'store-OTHER' });

      await expect(
        service.create('store-A', {
          saleId: 'sale-1',
          address: '123 Main St',
          courierId: 'staff-1',
        } as any),
      ).rejects.toBeInstanceOf(NotFoundException);
      expect(prisma._deliveries.size).toBe(0);
    });

    it('should attach the courier when courierId belongs to the store', async () => {
      seedSale();
      seedStaff({ id: 'staff-1', storeId: 'store-A' });

      const result: any = await service.create('store-A', {
        saleId: 'sale-1',
        address: '123 Main St',
        courierId: 'staff-1',
      } as any);

      expect(result.courierId).toBe('staff-1');
      expect(result.courier.user.name).toBe('Courier Joe');
    });
  });

  describe('findAll (scoping and filters)', () => {
    it('should NOT return another store\'s deliveries when listing for a store', async () => {
      seedSale({ id: 'sale-1', storeId: 'store-A' });
      seedSale({ id: 'sale-2', storeId: 'store-B', customer: null });
      seedDelivery({ id: 'delivery-A', storeId: 'store-A', saleId: 'sale-1' });
      seedDelivery({ id: 'delivery-B', storeId: 'store-B', saleId: 'sale-2' });

      const result = await service.findAll('store-A', {} as any);
      const ids = (result.data as any[]).map((d) => d.id);
      expect(ids).toContain('delivery-A');
      expect(ids).not.toContain('delivery-B');
      expect(result.total).toBe(1);
    });

    it('should filter by status when a status query param is provided', async () => {
      seedSale();
      seedDelivery({ id: 'delivery-new', status: DeliveryStatus.NEW });
      seedDelivery({ id: 'delivery-transit', status: DeliveryStatus.IN_TRANSIT });

      const result = await service.findAll('store-A', {
        status: DeliveryStatus.IN_TRANSIT,
      } as any);

      const ids = (result.data as any[]).map((d) => d.id);
      expect(ids).toEqual(['delivery-transit']);
    });

    it('should filter by createdAt date range when from/to are provided', async () => {
      seedSale();
      seedDelivery({
        id: 'delivery-old',
        createdAt: new Date('2026-01-01T00:00:00Z'),
      });
      seedDelivery({
        id: 'delivery-in-range',
        createdAt: new Date('2026-06-15T00:00:00Z'),
      });
      seedDelivery({
        id: 'delivery-future',
        createdAt: new Date('2026-12-01T00:00:00Z'),
      });

      const result = await service.findAll('store-A', {
        from: '2026-06-01',
        to: '2026-06-30',
      } as any);

      const ids = (result.data as any[]).map((d) => d.id);
      expect(ids).toEqual(['delivery-in-range']);
    });

    it('should paginate results using page/limit and compute totalPages', async () => {
      seedSale();
      for (let i = 0; i < 5; i++) {
        seedDelivery({
          id: `delivery-${i}`,
          createdAt: new Date(2026, 0, i + 1),
        });
      }

      const result = await service.findAll('store-A', {
        page: 2,
        limit: 2,
      } as any);

      expect(result.data).toHaveLength(2);
      expect(result.total).toBe(5);
      expect(result.page).toBe(2);
      expect(result.limit).toBe(2);
      expect(result.totalPages).toBe(3);
    });
  });

  describe('findOne (scoping)', () => {
    it('should throw NotFoundException when the delivery belongs to a different store', async () => {
      seedSale();
      seedDelivery({ id: 'delivery-A', storeId: 'store-A' });

      await expect(
        service.findOne('store-B', 'delivery-A'),
      ).rejects.toBeInstanceOf(NotFoundException);
    });

    it('should return delivery detail including sale items and courier when found in store', async () => {
      seedSale();
      seedStaff({ id: 'staff-1' });
      seedDelivery({ id: 'delivery-A', storeId: 'store-A', courierId: 'staff-1' });

      const result: any = await service.findOne('store-A', 'delivery-A');

      expect(result.id).toBe('delivery-A');
      expect(result.sale.items).toHaveLength(1);
      expect(result.courier.user.phone).toBe('+992900333444');
    });
  });

  describe('updateStatus (transitions)', () => {
    it('should transition NEW to IN_TRANSIT when requested', async () => {
      seedSale();
      seedDelivery({ id: 'delivery-A', status: DeliveryStatus.NEW });

      const result: any = await service.updateStatus('store-A', 'delivery-A', {
        status: DeliveryStatus.IN_TRANSIT,
      } as any);

      expect(result.status).toBe(DeliveryStatus.IN_TRANSIT);
    });

    it('should transition IN_TRANSIT to DELIVERED when requested', async () => {
      seedSale();
      seedDelivery({ id: 'delivery-A', status: DeliveryStatus.IN_TRANSIT });

      const result: any = await service.updateStatus('store-A', 'delivery-A', {
        status: DeliveryStatus.DELIVERED,
      } as any);

      expect(result.status).toBe(DeliveryStatus.DELIVERED);
    });

    it('should transition NEW to CANCELLED when requested', async () => {
      seedSale();
      seedDelivery({ id: 'delivery-A', status: DeliveryStatus.NEW });

      const result: any = await service.updateStatus('store-A', 'delivery-A', {
        status: DeliveryStatus.CANCELLED,
      } as any);

      expect(result.status).toBe(DeliveryStatus.CANCELLED);
    });

    it('should throw BadRequestException when transitioning from NEW directly to DELIVERED (skipping IN_TRANSIT)', async () => {
      seedSale();
      seedDelivery({ id: 'delivery-A', status: DeliveryStatus.NEW });

      await expect(
        service.updateStatus('store-A', 'delivery-A', {
          status: DeliveryStatus.DELIVERED,
        } as any),
      ).rejects.toBeInstanceOf(BadRequestException);
      // Status untouched on rejection.
      expect(prisma._deliveries.get('delivery-A')!.status).toBe(
        DeliveryStatus.NEW,
      );
    });

    it('should throw BadRequestException when transitioning out of a terminal DELIVERED status', async () => {
      seedSale();
      seedDelivery({ id: 'delivery-A', status: DeliveryStatus.DELIVERED });

      await expect(
        service.updateStatus('store-A', 'delivery-A', {
          status: DeliveryStatus.IN_TRANSIT,
        } as any),
      ).rejects.toBeInstanceOf(BadRequestException);
    });

    it('should throw NotFoundException when the delivery belongs to a different store', async () => {
      seedSale();
      seedDelivery({ id: 'delivery-A', storeId: 'store-A' });

      await expect(
        service.updateStatus('store-B', 'delivery-A', {
          status: DeliveryStatus.IN_TRANSIT,
        } as any),
      ).rejects.toBeInstanceOf(NotFoundException);
    });
  });
});
