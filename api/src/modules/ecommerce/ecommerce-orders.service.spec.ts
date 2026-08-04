import 'reflect-metadata';
import { Test } from '@nestjs/testing';
import {
  ForbiddenException,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { EcommerceOrdersService } from './ecommerce-orders.service';
import { PrismaService } from '../../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { EcommerceOutboundService } from './ecommerce-outbound.service';

// pushStockUpdate is deliberately fire-and-forget (void, not awaited) in
// EcommerceOrdersService — per the design spec, the merchant's own webhook
// endpoint being slow/down must never block or delay Dukon's webhook
// response. That means its internal chain of mocked-but-still-real
// microtask hops (findMany -> findUnique -> findUnique -> fetch) is still
// in flight when handleWebhook's own promise resolves. Flushing via
// setImmediate lets the whole pending microtask queue drain (Node always
// empties microtasks before running a macrotask/timer callback) before we
// assert on the outbound call.
const flushPromises = () => new Promise((resolve) => setImmediate(resolve));

function makePrismaFake() {
  const tx = {
    customer: {
      upsert: jest.fn(async ({ create }: any) => ({ id: 'cust-1', ...create })),
    },
    sale: {
      create: jest.fn(async ({ data }: any) => ({
        id: 'sale-1',
        ...data,
        items: [],
      })),
      findUnique: jest.fn(async () => null as any),
      update: jest.fn(async ({ data }: any) => ({ id: 'sale-1', ...data })),
    },
    saleItem: {
      findMany: jest.fn(async () => [] as any[]),
    },
    product: {
      updateMany: jest.fn(async () => ({ count: 1 })),
      update: jest.fn(async () => ({})),
    },
    stockMovement: {
      createMany: jest.fn(async () => ({ count: 1 })),
    },
    delivery: {
      create: jest.fn(async () => ({ id: 'del-1' })),
    },
  };

  return {
    ecommerceIntegration: {
      findUnique: jest.fn(async () => ({
        storeId: 'store-1',
        apiKey: 'valid-key',
        enabled: true,
      })),
    },
    subscription: {
      findUnique: jest.fn(async () => ({
        storeId: 'store-1',
        plan: 'PREMIUM',
        status: 'ACTIVE',
      })),
    },
    subscriptionPlanConfig: {
      findUnique: jest.fn(async () => ({
        plan: 'PREMIUM',
        hasEcommerceIntegration: true,
        hasDelivery: false,
      })),
    },
    externalProductMapping: {
      findMany: jest.fn(
        async () => [{ externalProductId: 'sku-1', productId: 'p1' }] as any[],
      ),
    },
    product: {
      findMany: jest.fn(
        async () =>
          [
            {
              id: 'p1',
              name: 'Товар 1',
              quantity: 10,
              sellPrice: 150,
              costPrice: 100,
            },
          ] as any[],
      ),
    },
    sale: {
      findUnique: jest.fn(async () => null as any),
    },
    $transaction: jest.fn(async (cb: any) => cb(tx)),
    __tx: tx,
  };
}

function makeOrderCreatedDto(overrides: Partial<any> = {}): any {
  return {
    event: 'order.created',
    externalOrderId: 'site-order-1',
    items: [{ externalProductId: 'sku-1', quantity: 2, price: 150 }],
    customer: {
      name: 'Иван Иванов',
      phone: '+992900000000',
      address: 'ул. Рудаки 1',
    },
    totalAmount: 300,
    ...overrides,
  };
}

describe('EcommerceOrdersService', () => {
  let service: EcommerceOrdersService;
  let prisma: ReturnType<typeof makePrismaFake>;
  let notifications: { sendToStoreUsers: jest.Mock };
  let outbound: { pushStockUpdate: jest.Mock };

  beforeEach(async () => {
    prisma = makePrismaFake();
    notifications = { sendToStoreUsers: jest.fn(async () => undefined) };
    outbound = { pushStockUpdate: jest.fn(async () => undefined) };

    const moduleRef = await Test.createTestingModule({
      providers: [
        EcommerceOrdersService,
        { provide: PrismaService, useValue: prisma },
        { provide: NotificationsService, useValue: notifications },
        { provide: EcommerceOutboundService, useValue: outbound },
      ],
    }).compile();
    service = moduleRef.get(EcommerceOrdersService);
  });

  it('rejects with UnauthorizedException when the api key does not match', async () => {
    await expect(
      service.handleWebhook('store-1', 'wrong-key', makeOrderCreatedDto()),
    ).rejects.toThrow(UnauthorizedException);
  });

  it('rejects with ForbiddenException when the store plan lacks hasEcommerceIntegration', async () => {
    (prisma.subscriptionPlanConfig.findUnique as jest.Mock).mockResolvedValue({
      plan: 'START',
      hasEcommerceIntegration: false,
    });
    await expect(
      service.handleWebhook('store-1', 'valid-key', makeOrderCreatedDto()),
    ).rejects.toThrow(ForbiddenException);
  });

  it('creates a sale, decrements stock, and links a customer on a valid order.created', async () => {
    const result = await service.handleWebhook(
      'store-1',
      'valid-key',
      makeOrderCreatedDto(),
    );

    expect(prisma.__tx.customer.upsert).toHaveBeenCalledWith(
      expect.objectContaining({
        where: {
          storeId_phone: { storeId: 'store-1', phone: '+992900000000' },
        },
      }),
    );
    expect(prisma.__tx.sale.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          channel: 'ONLINE',
          paymentType: 'CARD',
          externalOrderId: 'site-order-1',
          status: 'COMPLETED',
        }),
      }),
    );
    expect(prisma.__tx.product.updateMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: 'p1', quantity: { gte: 2 } },
        data: { quantity: { decrement: 2 } },
      }),
    );
    expect((result as any).id).toBe('sale-1');
  });

  it('creates a Delivery when the plan has hasDelivery enabled', async () => {
    (prisma.subscriptionPlanConfig.findUnique as jest.Mock).mockResolvedValue({
      plan: 'PREMIUM',
      hasEcommerceIntegration: true,
      hasDelivery: true,
    });

    await service.handleWebhook('store-1', 'valid-key', makeOrderCreatedDto());

    expect(prisma.__tx.delivery.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          address: 'ул. Рудаки 1',
          status: 'NEW',
        }),
      }),
    );
  });

  it('rejects the whole order (422) and notifies the owner when a line item has no mapping', async () => {
    const dto = makeOrderCreatedDto({
      items: [{ externalProductId: 'unmapped-sku', quantity: 1, price: 100 }],
    });

    await expect(
      service.handleWebhook('store-1', 'valid-key', dto),
    ).rejects.toThrow();
    expect(prisma.__tx.sale.create).not.toHaveBeenCalled();
    expect(notifications.sendToStoreUsers).toHaveBeenCalled();
  });

  it('rejects the whole order (422) and notifies the owner when stock is insufficient', async () => {
    (prisma.product.findMany as jest.Mock).mockResolvedValue([
      {
        id: 'p1',
        name: 'Товар 1',
        quantity: 1,
        sellPrice: 150,
        costPrice: 100,
      },
    ]);
    const dto = makeOrderCreatedDto({
      items: [{ externalProductId: 'sku-1', quantity: 5, price: 150 }],
    });

    await expect(
      service.handleWebhook('store-1', 'valid-key', dto),
    ).rejects.toThrow();
    expect(prisma.__tx.sale.create).not.toHaveBeenCalled();
    expect(notifications.sendToStoreUsers).toHaveBeenCalled();
  });

  // Whole-branch review finding: the atomic updateMany() stock guard
  // catches a genuine race with a concurrent in-store sale (the
  // pre-transaction check passed, but stock changed by the time the
  // transaction actually wrote), and the transaction rolls back entirely
  // — no Sale row is ever created. Unlike the missing-mapping and
  // insufficient-stock rejection paths above, this one previously fired
  // no owner notification at all, so a real online order could vanish
  // silently if the merchant's site never retries the webhook.
  it('rejects the whole order (422) and notifies the owner when the atomic stock guard detects a concurrent race', async () => {
    (prisma.__tx.product.updateMany as jest.Mock).mockResolvedValue({
      count: 0,
    });

    await expect(
      service.handleWebhook('store-1', 'valid-key', makeOrderCreatedDto()),
    ).rejects.toThrow();
    expect(prisma.__tx.sale.create).toHaveBeenCalled(); // sale.create ran, then the transaction rolled back
    expect(notifications.sendToStoreUsers).toHaveBeenCalledWith(
      'store-1',
      expect.any(String),
      expect.stringContaining('site-order-1'),
      'ECOMMERCE_ORDER_REJECTED',
    );
  });

  it('is idempotent: replaying the same externalOrderId returns the existing sale without reprocessing', async () => {
    (prisma.sale.findUnique as jest.Mock).mockResolvedValue({
      id: 'sale-existing',
    });

    const result = await service.handleWebhook(
      'store-1',
      'valid-key',
      makeOrderCreatedDto(),
    );

    expect(prisma.__tx.sale.create).not.toHaveBeenCalled();
    expect((result as any).id).toBe('sale-existing');
  });

  it('cancels an existing sale, restores stock, and marks it CANCELLED', async () => {
    (prisma.sale.findUnique as jest.Mock).mockResolvedValue({
      id: 'sale-1',
      status: 'COMPLETED',
      externalOrderId: 'site-order-1',
    });
    (prisma.__tx.saleItem.findMany as jest.Mock).mockResolvedValue([
      { productId: 'p1', quantity: 2 },
    ]);

    await service.handleWebhook('store-1', 'valid-key', {
      event: 'order.cancelled',
      externalOrderId: 'site-order-1',
    });

    expect(prisma.__tx.product.update).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: 'p1' },
        data: { quantity: { increment: 2 } },
      }),
    );
    expect(prisma.__tx.sale.update).toHaveBeenCalledWith(
      expect.objectContaining({ data: { status: 'CANCELLED' } }),
    );
  });

  it('returns 404 (idempotent) when cancelling an order Dukon never saw', async () => {
    (prisma.sale.findUnique as jest.Mock).mockResolvedValue(null);

    await expect(
      service.handleWebhook('store-1', 'valid-key', {
        event: 'order.cancelled',
        externalOrderId: 'unknown-order',
      }),
    ).rejects.toThrow(NotFoundException);
  });

  it('pushes an outbound stock update for every affected product after a successful order.created', async () => {
    await service.handleWebhook('store-1', 'valid-key', makeOrderCreatedDto());
    expect(outbound.pushStockUpdate).toHaveBeenCalledWith('p1', 'store-1');
  });
});

describe('EcommerceOrdersService — end-to-end scenario (real EcommerceOutboundService)', () => {
  let service: EcommerceOrdersService;
  let prisma: ReturnType<typeof makePrismaFake>;
  let fetchMock: jest.Mock;

  beforeEach(async () => {
    prisma = makePrismaFake();
    (prisma as any).ecommerceIntegration.findUnique = jest.fn(async () => ({
      storeId: 'store-1',
      apiKey: 'valid-key',
      enabled: true,
      outboundWebhookUrl: 'https://site.example/webhook',
    }));
    (prisma as any).externalProductMapping.findMany = jest.fn(async () => [
      { externalProductId: 'sku-1', productId: 'p1' },
    ]);
    (prisma as any).product = {
      ...prisma.product,
      findUnique: jest.fn(async () => ({ id: 'p1', quantity: 8 })),
    };

    fetchMock = jest.fn().mockResolvedValue({ ok: true, status: 200 });
    global.fetch = fetchMock as any;

    const moduleRef = await Test.createTestingModule({
      providers: [
        EcommerceOrdersService,
        EcommerceOutboundService,
        { provide: PrismaService, useValue: prisma },
        {
          provide: NotificationsService,
          useValue: { sendToStoreUsers: jest.fn() },
        },
      ],
    }).compile();
    service = moduleRef.get(EcommerceOrdersService);
  });

  it('order.created decrements stock and pushes the new quantity; order.cancelled restores stock and pushes again', async () => {
    await service.handleWebhook('store-1', 'valid-key', makeOrderCreatedDto());
    await flushPromises();
    expect(fetchMock).toHaveBeenCalledWith(
      'https://site.example/webhook',
      expect.objectContaining({
        body: JSON.stringify({ externalProductId: 'sku-1', quantity: 8 }),
      }),
    );

    fetchMock.mockClear();
    (prisma.sale.findUnique as jest.Mock).mockResolvedValue({
      id: 'sale-1',
      status: 'COMPLETED',
      externalOrderId: 'site-order-1',
    });
    (prisma.__tx.saleItem.findMany as jest.Mock).mockResolvedValue([
      { productId: 'p1', quantity: 2 },
    ]);

    await service.handleWebhook('store-1', 'valid-key', {
      event: 'order.cancelled',
      externalOrderId: 'site-order-1',
    });
    await flushPromises();

    expect(fetchMock).toHaveBeenCalledWith(
      'https://site.example/webhook',
      expect.objectContaining({
        body: JSON.stringify({ externalProductId: 'sku-1', quantity: 8 }),
      }),
    );
  });
});
