import 'reflect-metadata';
import { Test } from '@nestjs/testing';
import { Logger, NotFoundException } from '@nestjs/common';
import { StoresService } from './stores.service';
import { PrismaService } from '../../prisma/prisma.service';
import { AuditLogService } from '../../common/audit/audit-log.service';

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
    it('should NOT return another owner\'s stores when listing for an owner', async () => {
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
      const created: any = await service.create('owner-1', { name: 'Shop' } as any);
      const result: any = await service.softDelete(created.id);
      expect(result.isActive).toBe(false);
    });
  });

  describe('receipt template settings', () => {
    it('should return default receipt template when store has no custom template', async () => {
      const created: any = await service.create('owner-1', {
        name: 'X',
      } as any);
      const result = await service.getReceiptTemplate(created.id);
      expect(result.receiptTemplate).toMatchObject({
        footer: 'Thank you for your purchase!',
        showLogo: true,
        showBarcode: true,
      });
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

      expect(result.receiptTemplate).toMatchObject({
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
  });
});
