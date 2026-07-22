import 'reflect-metadata';
import { Test } from '@nestjs/testing';
import { StockAlertsService } from './stock-alerts.service';
import { PrismaService } from '../../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';

function makePrismaFake() {
  const stores: any[] = [];
  const products: any[] = [];
  const stockMovements: any[] = [];
  const saleItems: any[] = [];
  const subscriptions: any[] = [];
  const planConfigs: any[] = [];

  return {
    _stores: stores,
    _products: products,
    _stockMovements: stockMovements,
    _saleItems: saleItems,
    _subscriptions: subscriptions,
    _planConfigs: planConfigs,
    store: {
      findMany: jest.fn(async ({ where }: any) =>
        stores.filter((s) => !where?.isActive || s.isActive === where.isActive),
      ),
    },
    product: {
      findMany: jest.fn(async ({ where }: any) =>
        products.filter(
          (p) =>
            p.storeId === where.storeId &&
            p.isActive === where.isActive &&
            (!where.quantity?.gt || p.quantity > where.quantity.gt),
        ),
      ),
    },
    stockMovement: {
      findFirst: jest.fn(async ({ where, orderBy }: any) => {
        let matches = stockMovements.filter(
          (m) => m.productId === where.productId && m.type === where.type,
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
      findFirst: jest.fn(async ({ where, orderBy }: any) => {
        let matches = saleItems.filter((si) => {
          if (si.productId !== where.productId) return false;
          if (where.sale?.storeId && si.saleStoreId !== where.sale.storeId)
            return false;
          if (
            where.sale?.createdAt?.gte &&
            si.saleCreatedAt < where.sale.createdAt.gte
          )
            return false;
          return true;
        });
        if (orderBy?.sale?.createdAt === 'desc') {
          matches = [...matches].sort(
            (a, b) => b.saleCreatedAt.getTime() - a.saleCreatedAt.getTime(),
          );
        }
        return matches[0]
          ? { sale: { createdAt: matches[0].saleCreatedAt } }
          : null;
      }),
    },
    subscription: {
      findUnique: jest.fn(
        async ({ where }: any) =>
          subscriptions.find((s) => s.storeId === where.storeId) ?? null,
      ),
    },
    subscriptionPlanConfig: {
      findUnique: jest.fn(
        async ({ where }: any) =>
          planConfigs.find((c) => c.plan === where.plan) ?? null,
      ),
    },
  } as any;
}

describe('StockAlertsService.checkSlowMovingStock', () => {
  let service: StockAlertsService;
  let prisma: ReturnType<typeof makePrismaFake>;
  let sendToStoreUsers: jest.Mock;

  beforeEach(async () => {
    prisma = makePrismaFake();
    sendToStoreUsers = jest.fn().mockResolvedValue(undefined);
    const moduleRef = await Test.createTestingModule({
      providers: [
        StockAlertsService,
        { provide: PrismaService, useValue: prisma },
        { provide: NotificationsService, useValue: { sendToStoreUsers } },
      ],
    }).compile();
    service = moduleRef.get(StockAlertsService);
  });

  it('should notify for a product that has not sold in 32 days and still has 67% of its batch left', async () => {
    prisma._stores.push({ id: 'store-1', isActive: true });
    prisma._subscriptions.push({ storeId: 'store-1', plan: 'BUSINESS' });
    prisma._planConfigs.push({ plan: 'BUSINESS', hasBatchProfitability: true });
    prisma._products.push({
      id: 'p1',
      storeId: 'store-1',
      name: 'Куртка',
      quantity: 67,
      isActive: true,
    });
    const oldDate = new Date(Date.now() - 40 * 24 * 60 * 60 * 1000);
    prisma._stockMovements.push({
      id: 'mv1',
      productId: 'p1',
      type: 'PURCHASE',
      quantity: 100,
      createdAt: oldDate,
    });
    prisma._saleItems.push({
      productId: 'p1',
      saleStoreId: 'store-1',
      saleCreatedAt: new Date(Date.now() - 32 * 24 * 60 * 60 * 1000),
    });

    await service.checkSlowMovingStock();

    expect(sendToStoreUsers).toHaveBeenCalledTimes(1);
    expect(sendToStoreUsers).toHaveBeenCalledWith(
      'store-1',
      expect.any(String),
      expect.stringContaining('Куртка'),
      'SLOW_MOVING_STOCK',
    );
  });

  it('should NOT notify when the product sold recently', async () => {
    prisma._stores.push({ id: 'store-1', isActive: true });
    prisma._subscriptions.push({ storeId: 'store-1', plan: 'BUSINESS' });
    prisma._planConfigs.push({ plan: 'BUSINESS', hasBatchProfitability: true });
    prisma._products.push({
      id: 'p1',
      storeId: 'store-1',
      name: 'Куртка',
      quantity: 67,
      isActive: true,
    });
    prisma._stockMovements.push({
      id: 'mv1',
      productId: 'p1',
      type: 'PURCHASE',
      quantity: 100,
      createdAt: new Date(Date.now() - 40 * 24 * 60 * 60 * 1000),
    });
    prisma._saleItems.push({
      productId: 'p1',
      saleStoreId: 'store-1',
      saleCreatedAt: new Date(Date.now() - 2 * 24 * 60 * 60 * 1000), // 2 days ago
    });

    await service.checkSlowMovingStock();

    expect(sendToStoreUsers).not.toHaveBeenCalled();
  });

  it('should NOT notify when remaining quantity is below the 50% threshold', async () => {
    prisma._stores.push({ id: 'store-1', isActive: true });
    prisma._subscriptions.push({ storeId: 'store-1', plan: 'BUSINESS' });
    prisma._planConfigs.push({ plan: 'BUSINESS', hasBatchProfitability: true });
    prisma._products.push({
      id: 'p1',
      storeId: 'store-1',
      name: 'Куртка',
      quantity: 10,
      isActive: true,
    }); // only 10%
    prisma._stockMovements.push({
      id: 'mv1',
      productId: 'p1',
      type: 'PURCHASE',
      quantity: 100,
      createdAt: new Date(Date.now() - 40 * 24 * 60 * 60 * 1000),
    });

    await service.checkSlowMovingStock();

    expect(sendToStoreUsers).not.toHaveBeenCalled();
  });

  it('should NOT notify for a store whose plan lacks hasBatchProfitability', async () => {
    prisma._stores.push({ id: 'store-1', isActive: true });
    prisma._subscriptions.push({ storeId: 'store-1', plan: 'START' });
    prisma._planConfigs.push({ plan: 'START', hasBatchProfitability: false });
    prisma._products.push({
      id: 'p1',
      storeId: 'store-1',
      name: 'Куртка',
      quantity: 67,
      isActive: true,
    });
    prisma._stockMovements.push({
      id: 'mv1',
      productId: 'p1',
      type: 'PURCHASE',
      quantity: 100,
      createdAt: new Date(Date.now() - 40 * 24 * 60 * 60 * 1000),
    });

    await service.checkSlowMovingStock();

    expect(sendToStoreUsers).not.toHaveBeenCalled();
  });

  it('should respect a store-configured custom threshold', async () => {
    prisma._stores.push({
      id: 'store-1',
      isActive: true,
      settings: {
        notifications: {
          daysWithoutSaleThreshold: 10,
          remainingPercentThreshold: 20,
        },
      },
    });
    prisma._subscriptions.push({ storeId: 'store-1', plan: 'BUSINESS' });
    prisma._planConfigs.push({ plan: 'BUSINESS', hasBatchProfitability: true });
    prisma._products.push({
      id: 'p1',
      storeId: 'store-1',
      name: 'Куртка',
      quantity: 25,
      isActive: true,
    }); // 25% >= 20%
    prisma._stockMovements.push({
      id: 'mv1',
      productId: 'p1',
      type: 'PURCHASE',
      quantity: 100,
      createdAt: new Date(Date.now() - 40 * 24 * 60 * 60 * 1000),
    });
    prisma._saleItems.push({
      productId: 'p1',
      saleStoreId: 'store-1',
      saleCreatedAt: new Date(Date.now() - 15 * 24 * 60 * 60 * 1000), // 15 days ago >= 10-day threshold
    });

    await service.checkSlowMovingStock();

    expect(sendToStoreUsers).toHaveBeenCalledTimes(1);
  });

  it('should fall back to default thresholds when stored settings are non-numeric', async () => {
    prisma._stores.push({
      id: 'store-1',
      isActive: true,
      settings: {
        notifications: {
          daysWithoutSaleThreshold: 'not-a-number',
          remainingPercentThreshold: 'also-not-a-number',
        },
      },
    });
    prisma._subscriptions.push({ storeId: 'store-1', plan: 'BUSINESS' });
    prisma._planConfigs.push({ plan: 'BUSINESS', hasBatchProfitability: true });
    prisma._products.push({
      id: 'p1',
      storeId: 'store-1',
      name: 'Куртка',
      quantity: 67,
      isActive: true,
    });
    prisma._stockMovements.push({
      id: 'mv1',
      productId: 'p1',
      type: 'PURCHASE',
      quantity: 100,
      createdAt: new Date(Date.now() - 40 * 24 * 60 * 60 * 1000),
    });
    prisma._saleItems.push({
      productId: 'p1',
      saleStoreId: 'store-1',
      saleCreatedAt: new Date(Date.now() - 2 * 24 * 60 * 60 * 1000), // 2 days ago — within the default 30-day threshold
    });

    await service.checkSlowMovingStock();

    // With malformed settings falling back to the documented defaults
    // (30 days / 50%), a product sold 2 days ago must NOT trigger a
    // notification. If the non-numeric values were used as-is instead
    // of being guarded, `cutoff` would be an Invalid Date and this
    // assertion would fail.
    expect(sendToStoreUsers).not.toHaveBeenCalled();
  });
});
