import 'reflect-metadata';
import { Test } from '@nestjs/testing';
import { Logger, NotFoundException } from '@nestjs/common';
import { StoresService } from './stores.service';
import { PrismaService } from '../../prisma/prisma.service';
import { AuditLogService } from '../../common/audit/audit-log.service';
import { ReceiptTemplateDto } from './dto/receipt-template.dto';

// Behavioral fake of Prisma slice used by StoresService. Stores the relevant
// bits in Maps so we can assert on persisted shape (trial period setup,
// settings JSON merge, soft scoping by ownerId/isActive).
function makePrismaFake() {
  type StoreRow = {
    id: string;
    ownerId: string;
    name: string;
    category: string;
    currency: string;
    address: string | null;
    phone: string | null;
    isActive: boolean;
    settings: Record<string, any> | null;
    createdAt: Date;
    subscription: {
      id: string;
      plan: string;
      status: string;
      trialEndsAt: Date;
      currentPeriodStart: Date;
      currentPeriodEnd: Date;
    } | null;
  };

  const stores = new Map<string, StoreRow>();
  let storeIdSeq = 0;
  const newId = () => `store-${++storeIdSeq}`;

  return {
    _stores: stores,
    store: {
      create: jest.fn(async ({ data }: any) => {
        const id = newId();
        const sub = data.subscription?.create
          ? {
              id: `sub-${id}`,
              plan: data.subscription.create.plan,
              status: data.subscription.create.status,
              trialEndsAt: data.subscription.create.trialEndsAt,
              currentPeriodStart: data.subscription.create.currentPeriodStart,
              currentPeriodEnd: data.subscription.create.currentPeriodEnd,
            }
          : null;
        const row: StoreRow = {
          id,
          ownerId: data.owner.connect.id,
          name: data.name,
          category: data.category ?? 'GENERAL',
          currency: data.currency ?? 'TJS',
          address: data.address ?? null,
          phone: data.phone ?? null,
          isActive: true,
          settings: null,
          createdAt: new Date(),
          subscription: sub,
        };
        stores.set(id, row);
        return { ...row };
      }),
      findMany: jest.fn(async ({ where }: any) => {
        return Array.from(stores.values()).filter((s) => {
          if (where?.ownerId && s.ownerId !== where.ownerId) return false;
          if (where?.isActive !== undefined && s.isActive !== where.isActive)
            return false;
          return true;
        });
      }),
      findUnique: jest.fn(async ({ where, select, include }: any) => {
        const s = stores.get(where.id);
        if (!s) return null;
        if (select) {
          const out: any = {};
          for (const k of Object.keys(select)) {
            if (select[k]) out[k] = (s as any)[k];
          }
          return out;
        }
        if (include?.subscription) return { ...s };
        return { ...s };
      }),
      update: jest.fn(async ({ where, data, select, include }: any) => {
        const s = stores.get(where.id);
        if (!s) throw new Error('not found');
        if (data.settings !== undefined) {
          s.settings = data.settings;
        }
        for (const k of Object.keys(data)) {
          if (k === 'settings') continue;
          (s as any)[k] = data[k];
        }
        if (select) {
          const out: any = {};
          for (const k of Object.keys(select)) {
            if (select[k]) out[k] = (s as any)[k];
          }
          return out;
        }
        if (include?.subscription) return { ...s };
        return { ...s };
      }),
    },
  };
}

describe('StoresService', () => {
  let service: StoresService;
  let prisma: ReturnType<typeof makePrismaFake>;

  beforeEach(async () => {
    jest.spyOn(Logger.prototype, 'log').mockImplementation(() => {});
    prisma = makePrismaFake();
    const moduleRef = await Test.createTestingModule({
      providers: [
        StoresService,
        { provide: PrismaService, useValue: prisma },
        { provide: AuditLogService, useValue: { record: jest.fn() } },
      ],
    }).compile();
    service = moduleRef.get(StoresService);
  });

  describe('create', () => {
    it('should create store with TRIAL subscription expiring exactly 7 days out when creating new store', async () => {
      const before = Date.now();
      const result: any = await service.create('owner-1', {
        name: 'Corner Shop',
        category: 'GROCERY',
      } as any);
      const after = Date.now();

      expect(result.ownerId).toBe('owner-1');
      expect(result.name).toBe('Corner Shop');
      expect(result.subscription.status).toBe('TRIAL');
      expect(result.subscription.plan).toBe('PREMIUM');

      const trialMs =
        result.subscription.trialEndsAt.getTime() -
        result.subscription.currentPeriodStart.getTime();
      expect(trialMs).toBe(7 * 24 * 60 * 60 * 1000);

      // trialEndsAt must be ~7 days from "now" at call time
      const expectedMin = before + 7 * 24 * 60 * 60 * 1000 - 5;
      const expectedMax = after + 7 * 24 * 60 * 60 * 1000 + 5;
      expect(result.subscription.trialEndsAt.getTime()).toBeGreaterThanOrEqual(
        expectedMin,
      );
      expect(result.subscription.trialEndsAt.getTime()).toBeLessThanOrEqual(
        expectedMax,
      );
    });

    it('should default currency to TJS when not provided in dto', async () => {
      const result: any = await service.create('owner-1', {
        name: 'No Currency Store',
      } as any);
      expect(result.currency).toBe('TJS');
    });
  });

  describe('findAll (ownership scoping)', () => {
    it("should NOT return another owner's stores when listing for an owner", async () => {
      await service.create('owner-A', { name: 'A1' } as any);
      await service.create('owner-A', { name: 'A2' } as any);
      await service.create('owner-B', { name: 'B1' } as any);

      const aResults = await service.findAll('owner-A');
      const bResults = await service.findAll('owner-B');

      expect(aResults.map((s: any) => s.name).sort()).toEqual(['A1', 'A2']);
      expect(bResults.map((s: any) => s.name)).toEqual(['B1']);
    });
  });

  describe('findOne', () => {
    it('should throw NotFoundException when store id does not exist', async () => {
      await expect(service.findOne('does-not-exist')).rejects.toBeInstanceOf(
        NotFoundException,
      );
    });
  });

  describe('softDelete', () => {
    it('should set isActive to false when softDelete is called', async () => {
      const created: any = await service.create('owner-1', {
        name: 'Shop',
      } as any);
      const result: any = await service.softDelete(created.id);
      expect(result.isActive).toBe(false);
    });

    it('should throw NotFoundException when store does not exist', async () => {
      await expect(service.softDelete('nonexistent-id')).rejects.toBeInstanceOf(
        NotFoundException,
      );
    });
  });

  describe('receipt template settings', () => {
    it('should return default receipt template when store has no custom template', async () => {
      const created: any = await service.create('owner-1', {
        name: 'X',
      } as any);
      const result = await service.getReceiptTemplate(created.id);
      expect(result).toMatchObject({
        footer: 'Thank you for your purchase!',
        showLogo: true,
        showBarcode: true,
      });
      expect((result as any).receiptTemplate).toBeUndefined();
    });

    it('should merge new fields with existing template fields when updating receipt template', async () => {
      const created: any = await service.create('owner-1', {
        name: 'X',
      } as any);
      // First write
      await service.updateReceiptTemplate(created.id, {
        footer: 'See you soon',
        showLogo: false,
      } as any);
      // Second write only changes header — must not wipe earlier fields.
      const result = await service.updateReceiptTemplate(created.id, {
        header: 'Welcome',
      } as any);

      expect(result).toMatchObject({
        header: 'Welcome',
        footer: 'See you soon',
        showLogo: false,
        showBarcode: true, // default preserved
      });
    });

    it('should throw NotFoundException when updating receipt template for missing store', async () => {
      await expect(
        service.updateReceiptTemplate('missing-store', { header: 'x' } as any),
      ).rejects.toBeInstanceOf(NotFoundException);
    });

    // Regression test for a HIGH-severity data-loss bug: a real
    // ReceiptTemplateDto instance (as produced by Nest's ValidationPipe
    // with transform:true) has every declared-but-unsent field present as
    // an own property explicitly set to `undefined` (useDefineForClassFields,
    // implied by tsconfig target ES2023). A plain-object literal in a test
    // (e.g. `{ footer: 'x' } as any`) does NOT reproduce this, since object
    // literals only have the keys actually assigned — so this must
    // construct a real class instance to catch the bug.
    it('should leave unrelated fields untouched when partially updating via a real DTO instance', async () => {
      const created: any = await service.create('owner-1', {
        name: 'X',
      } as any);

      const seed = new ReceiptTemplateDto();
      seed.storeName = 'Corner Shop';
      seed.address = '123 Main St';
      seed.phone = '+992900000000';
      seed.header = 'Welcome';
      seed.taxId = 'TIN-12345';
      seed.footer = 'Original footer';
      seed.showLogo = true;
      seed.showBarcode = true;
      await service.updateReceiptTemplate(created.id, seed);

      // Partial update: only footer + showLogo sent. All other declared
      // fields exist on the instance but are `undefined` (unsent).
      const partial = new ReceiptTemplateDto();
      partial.footer = 'custom footer';
      partial.showLogo = false;
      const result: any = await service.updateReceiptTemplate(
        created.id,
        partial,
      );

      expect(result.footer).toBe('custom footer');
      expect(result.showLogo).toBe(false);
      // Untouched fields must survive the partial update unchanged.
      expect(result.storeName).toBe('Corner Shop');
      expect(result.address).toBe('123 Main St');
      expect(result.phone).toBe('+992900000000');
      expect(result.header).toBe('Welcome');
      expect(result.taxId).toBe('TIN-12345');
      expect(result.showBarcode).toBe(true);
    });

    it('should still update an explicitly-set field to a new value via a real DTO instance', async () => {
      const created: any = await service.create('owner-1', {
        name: 'X',
      } as any);

      const seed = new ReceiptTemplateDto();
      seed.header = 'Old header';
      seed.taxId = 'TIN-OLD';
      await service.updateReceiptTemplate(created.id, seed);

      const update = new ReceiptTemplateDto();
      update.header = 'New header';
      const result: any = await service.updateReceiptTemplate(
        created.id,
        update,
      );

      expect(result.header).toBe('New header');
      // Field not present in this second call stays as previously set.
      expect(result.taxId).toBe('TIN-OLD');
    });
  });
});
