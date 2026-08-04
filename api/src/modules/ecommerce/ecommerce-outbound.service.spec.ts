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

    // 1 initial attempt + 3 retries (1s/4s/16s) = 4 total.
    expect(fetchMock).toHaveBeenCalledTimes(4);
    expect(notifications.sendToStoreUsers).toHaveBeenCalledTimes(1);
  });

  // Regression for the whole-branch-review finding: RETRY_DELAYS_MS[2]
  // (16000) was previously unreachable because the loop ran
  // RETRY_DELAYS_MS.length (3) times total with delay index `attempt - 1`,
  // so only RETRY_DELAYS_MS[0] and [1] were ever read — real behavior was
  // 3 total attempts over ~5s, not the 1s/4s/16s spread ("до 3 повторов")
  // the design spec describes. This test pins the exact call count at each
  // specific elapsed-time checkpoint (not just "sometime within 21s total",
  // which the old fake-timer tests advanced by regardless and so never
  // caught the bug) to prove all 3 delays are genuinely exercised in order.
  it('waits exactly 1s, then 4s, then 16s between the 4 attempts — not sooner, and the 16s delay is genuinely reached', async () => {
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

    // Attempt 1 fires immediately.
    await jest.advanceTimersByTimeAsync(0);
    expect(fetchMock).toHaveBeenCalledTimes(1);

    // Just under the 1s backoff — attempt 2 must not have fired yet.
    await jest.advanceTimersByTimeAsync(999);
    expect(fetchMock).toHaveBeenCalledTimes(1);
    // Crossing 1s — attempt 2 fires.
    await jest.advanceTimersByTimeAsync(1);
    expect(fetchMock).toHaveBeenCalledTimes(2);

    // Just under the 4s backoff — attempt 3 must not have fired yet.
    await jest.advanceTimersByTimeAsync(3999);
    expect(fetchMock).toHaveBeenCalledTimes(2);
    // Crossing 4s — attempt 3 fires.
    await jest.advanceTimersByTimeAsync(1);
    expect(fetchMock).toHaveBeenCalledTimes(3);

    // Just under the 16s backoff — attempt 4 (the one RETRY_DELAYS_MS[2]
    // gated, previously unreachable) must not have fired yet.
    await jest.advanceTimersByTimeAsync(15999);
    expect(fetchMock).toHaveBeenCalledTimes(3);
    // Crossing 16s — attempt 4 fires, and that is the last one.
    await jest.advanceTimersByTimeAsync(1);
    expect(fetchMock).toHaveBeenCalledTimes(4);

    await pushPromise;
    expect(fetchMock).toHaveBeenCalledTimes(4);
  });

  it('gives up after 4 attempts (1 initial + 3 retries) and notifies the store owner once', async () => {
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

    expect(fetchMock).toHaveBeenCalledTimes(4);
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
