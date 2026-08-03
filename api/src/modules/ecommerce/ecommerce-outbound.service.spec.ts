import 'reflect-metadata';
import { Test } from '@nestjs/testing';
import { EcommerceOutboundService } from './ecommerce-outbound.service';
import { PrismaService } from '../../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';

function makePrismaFake() {
  return {
    externalProductMapping: {
      findMany: jest.fn(async () => [] as any[]),
    },
    product: {
      findUnique: jest.fn(async () => ({ id: 'p1', quantity: 10 }) as any),
    },
    ecommerceIntegration: {
      findUnique: jest.fn(async () => null as any),
    },
  };
}

describe('EcommerceOutboundService', () => {
  let service: EcommerceOutboundService;
  let prisma: ReturnType<typeof makePrismaFake>;
  let notifications: { sendToStoreUsers: jest.Mock };
  let fetchMock: jest.Mock;

  beforeEach(async () => {
    prisma = makePrismaFake();
    notifications = { sendToStoreUsers: jest.fn(async () => undefined) };
    fetchMock = jest.fn();
    global.fetch = fetchMock as any;

    const moduleRef = await Test.createTestingModule({
      providers: [
        EcommerceOutboundService,
        { provide: PrismaService, useValue: prisma },
        { provide: NotificationsService, useValue: notifications },
      ],
    }).compile();
    service = moduleRef.get(EcommerceOutboundService);
  });

  afterEach(() => {
    jest.useRealTimers();
    jest.clearAllMocks();
  });

  it('does nothing when the product has no external mapping', async () => {
    (prisma.externalProductMapping.findMany as jest.Mock).mockResolvedValue([]);

    await service.pushStockUpdate('p1', 'store-1');

    expect(fetchMock).not.toHaveBeenCalled();
  });

  it('does nothing when the store has no integration, or it is disabled, or has no outboundWebhookUrl', async () => {
    (prisma.externalProductMapping.findMany as jest.Mock).mockResolvedValue([
      { externalProductId: 'sku-1' },
    ]);
    (prisma.ecommerceIntegration.findUnique as jest.Mock).mockResolvedValue({
      enabled: false,
      outboundWebhookUrl: 'https://example.com/webhook',
    });

    await service.pushStockUpdate('p1', 'store-1');

    expect(fetchMock).not.toHaveBeenCalled();
  });

  it('posts the current quantity for every mapped externalProductId on success', async () => {
    (prisma.externalProductMapping.findMany as jest.Mock).mockResolvedValue([
      { externalProductId: 'sku-1' },
    ]);
    (prisma.ecommerceIntegration.findUnique as jest.Mock).mockResolvedValue({
      enabled: true,
      outboundWebhookUrl: 'https://example.com/webhook',
    });
    (prisma.product.findUnique as jest.Mock).mockResolvedValue({
      id: 'p1',
      quantity: 7,
    });
    fetchMock.mockResolvedValue({ ok: true, status: 200 });

    await service.pushStockUpdate('p1', 'store-1');

    expect(fetchMock).toHaveBeenCalledWith(
      'https://example.com/webhook',
      expect.objectContaining({
        method: 'POST',
        body: JSON.stringify({ externalProductId: 'sku-1', quantity: 7 }),
      }),
    );
  });

  it('retries up to 3 times with backoff on network error, then succeeds on a later attempt', async () => {
    jest.useFakeTimers();
    (prisma.externalProductMapping.findMany as jest.Mock).mockResolvedValue([
      { externalProductId: 'sku-1' },
    ]);
    (prisma.ecommerceIntegration.findUnique as jest.Mock).mockResolvedValue({
      enabled: true,
      outboundWebhookUrl: 'https://example.com/webhook',
    });
    fetchMock
      .mockRejectedValueOnce(new Error('network down'))
      .mockResolvedValueOnce({ ok: true, status: 200 });

    const pushPromise = service.pushStockUpdate('p1', 'store-1');
    await jest.advanceTimersByTimeAsync(1000);
    await pushPromise;

    expect(fetchMock).toHaveBeenCalledTimes(2);
  });

  it('genuinely waits for the backoff delay before retrying — does not retry early', async () => {
    jest.useFakeTimers();
    (prisma.externalProductMapping.findMany as jest.Mock).mockResolvedValue([
      { externalProductId: 'sku-1' },
    ]);
    (prisma.ecommerceIntegration.findUnique as jest.Mock).mockResolvedValue({
      enabled: true,
      outboundWebhookUrl: 'https://example.com/webhook',
    });
    fetchMock
      .mockRejectedValueOnce(new Error('network down'))
      .mockResolvedValueOnce({ ok: true, status: 200 });

    const pushPromise = service.pushStockUpdate('p1', 'store-1');

    // Let the first (failing) attempt run, but advance LESS than the full
    // 1000ms backoff delay — the retry must not have fired yet.
    await jest.advanceTimersByTimeAsync(999);
    expect(fetchMock).toHaveBeenCalledTimes(1);

    // Now cross the 1000ms threshold — the retry should fire.
    await jest.advanceTimersByTimeAsync(1);
    await pushPromise;
    expect(fetchMock).toHaveBeenCalledTimes(2);
  });

  it('retries and eventually gives up when the endpoint responds with a non-2xx status (no thrown exception)', async () => {
    jest.useFakeTimers();
    (prisma.externalProductMapping.findMany as jest.Mock).mockResolvedValue([
      { externalProductId: 'sku-1' },
    ]);
    (prisma.ecommerceIntegration.findUnique as jest.Mock).mockResolvedValue({
      enabled: true,
      outboundWebhookUrl: 'https://example.com/webhook',
    });
    fetchMock.mockResolvedValue({ ok: false, status: 500 });

    const pushPromise = service.pushStockUpdate('p1', 'store-1');
    await jest.advanceTimersByTimeAsync(1000 + 4000 + 16000);
    await pushPromise;

    expect(fetchMock).toHaveBeenCalledTimes(3);
    expect(notifications.sendToStoreUsers).toHaveBeenCalledTimes(1);
  });

  it('gives up after 3 failed attempts and notifies the store owner once', async () => {
    jest.useFakeTimers();
    (prisma.externalProductMapping.findMany as jest.Mock).mockResolvedValue([
      { externalProductId: 'sku-1' },
    ]);
    (prisma.ecommerceIntegration.findUnique as jest.Mock).mockResolvedValue({
      enabled: true,
      outboundWebhookUrl: 'https://example.com/webhook',
    });
    fetchMock.mockRejectedValue(new Error('network down'));

    const pushPromise = service.pushStockUpdate('p1', 'store-1');
    await jest.advanceTimersByTimeAsync(1000 + 4000 + 16000);
    await pushPromise;

    expect(fetchMock).toHaveBeenCalledTimes(3);
    expect(notifications.sendToStoreUsers).toHaveBeenCalledTimes(1);
    expect(notifications.sendToStoreUsers).toHaveBeenCalledWith(
      'store-1',
      expect.any(String),
      expect.any(String),
      'ECOMMERCE_PUSH_FAILED',
    );
  });

  it('does not send a second failure notification within 15 minutes for the same store', async () => {
    jest.useFakeTimers();
    (prisma.externalProductMapping.findMany as jest.Mock).mockResolvedValue([
      { externalProductId: 'sku-1' },
    ]);
    (prisma.ecommerceIntegration.findUnique as jest.Mock).mockResolvedValue({
      enabled: true,
      outboundWebhookUrl: 'https://example.com/webhook',
    });
    fetchMock.mockRejectedValue(new Error('network down'));

    const first = service.pushStockUpdate('p1', 'store-1');
    await jest.advanceTimersByTimeAsync(1000 + 4000 + 16000);
    await first;

    const second = service.pushStockUpdate('p1', 'store-1');
    await jest.advanceTimersByTimeAsync(1000 + 4000 + 16000);
    await second;

    expect(notifications.sendToStoreUsers).toHaveBeenCalledTimes(1);
  });
});
