import 'reflect-metadata';
import { NotFoundException } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { AdminService } from './admin.service';
import { PrismaService } from '../../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { StoresService } from '../stores/stores.service';

function makePrismaFake(opts: { withSubscription: boolean }) {
  const subscriptions = new Map<string, any>();
  if (opts.withSubscription) {
    subscriptions.set('store-1', {
      id: 'sub-1',
      storeId: 'store-1',
      plan: 'PREMIUM',
      status: 'TRIAL',
      trialEndsAt: new Date('2026-01-08T00:00:00.000Z'),
      currentPeriodStart: new Date('2026-01-01T00:00:00.000Z'),
      currentPeriodEnd: new Date('2026-01-08T00:00:00.000Z'),
    });
  }
  return {
    _subscriptions: subscriptions,
    store: {
      findUnique: jest.fn(async ({ where }: any) =>
        where.id === 'store-1' ? { id: 'store-1', name: 'Магазин' } : null,
      ),
    },
    subscription: {
      upsert: jest.fn(async ({ where, update, create }: any) => {
        const existing = subscriptions.get(where.storeId);
        const row = existing
          ? { ...existing, ...update }
          : { id: 'sub-new', storeId: where.storeId, ...create };
        subscriptions.set(where.storeId, row);
        return row;
      }),
    },
  };
}

async function buildService(prisma: any) {
  const moduleRef = await Test.createTestingModule({
    providers: [
      AdminService,
      { provide: PrismaService, useValue: prisma },
      { provide: NotificationsService, useValue: { sendPush: jest.fn() } },
      { provide: StoresService, useValue: { create: jest.fn() } },
    ],
  }).compile();
  return moduleRef.get(AdminService);
}

describe('AdminService.updateStoreSubscription', () => {
  it('should set plan, status and period together', async () => {
    // Setting plan alone is the obvious minimal design and it is wrong: the
    // server-side guards consult status and period, so granting BUSINESS to an
    // EXPIRED subscription would change the plan and still deny every feature.
    const prisma = makePrismaFake({ withSubscription: true });
    const service = await buildService(prisma);

    const result = await service.updateStoreSubscription('store-1', {
      plan: 'BUSINESS',
      status: 'ACTIVE',
      currentPeriodEnd: '2027-01-01T00:00:00.000Z',
    } as any);

    expect(result.plan).toBe('BUSINESS');
    expect(result.status).toBe('ACTIVE');
    expect(new Date(result.currentPeriodEnd).toISOString()).toBe(
      '2027-01-01T00:00:00.000Z',
    );
  });

  it('should leave trialEndsAt untouched', async () => {
    // trialEndsAt records when the original trial ended. An admin grant is not
    // a trial and must not rewrite that history.
    const prisma = makePrismaFake({ withSubscription: true });
    const service = await buildService(prisma);

    const result = await service.updateStoreSubscription('store-1', {
      plan: 'BUSINESS',
      status: 'ACTIVE',
      currentPeriodEnd: '2027-01-01T00:00:00.000Z',
    } as any);

    // Optional chaining, not `!`: trialEndsAt is nullable on the model. If the
    // implementation ever wiped it, this reads `undefined` and still fails.
    expect(result.trialEndsAt?.toISOString()).toBe('2026-01-08T00:00:00.000Z');
    const updateArg = prisma.subscription.upsert.mock.calls[0][0].update;
    expect(updateArg).not.toHaveProperty('trialEndsAt');
  });

  it('should create a subscription when the store has none', async () => {
    // Every store made by StoresService.create has one, but a store from an
    // older path or a half-failed migration might not. An admin tool that
    // cannot repair that state is less useful than one that can.
    const prisma = makePrismaFake({ withSubscription: false });
    const service = await buildService(prisma);

    const result = await service.updateStoreSubscription('store-1', {
      plan: 'START',
      status: 'ACTIVE',
      currentPeriodEnd: '2027-01-01T00:00:00.000Z',
    } as any);

    expect(result.plan).toBe('START');
    const createArg = prisma.subscription.upsert.mock.calls[0][0].create;
    expect(createArg.currentPeriodStart).toBeInstanceOf(Date);
  });

  it('should throw NotFoundException when the store does not exist', async () => {
    const prisma = makePrismaFake({ withSubscription: true });
    const service = await buildService(prisma);

    await expect(
      service.updateStoreSubscription('nope', {
        plan: 'BUSINESS',
        status: 'ACTIVE',
        currentPeriodEnd: '2027-01-01T00:00:00.000Z',
      } as any),
    ).rejects.toBeInstanceOf(NotFoundException);

    expect(prisma.subscription.upsert).not.toHaveBeenCalled();
  });
});
