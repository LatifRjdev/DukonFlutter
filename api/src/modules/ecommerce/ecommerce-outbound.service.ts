import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';

const RETRY_DELAYS_MS = [1000, 4000, 16000];
const FAILURE_NOTIFICATION_COOLDOWN_MS = 15 * 60 * 1000;

@Injectable()
export class EcommerceOutboundService {
  private readonly logger = new Logger(EcommerceOutboundService.name);

  // In-memory per-store cooldown for the "push failed" owner notification.
  // Single-instance-only (no Redis/queue infra exists in this project —
  // see the design spec's explicit non-goals). If this service ever runs
  // on more than one instance, each instance tracks its own cooldown
  // independently, so an owner could in theory get one notification per
  // instance within the same 15-minute window — an acceptable, documented
  // limitation, not something to fix here.
  private readonly lastFailureNotifiedAt = new Map<string, number>();

  constructor(
    private prisma: PrismaService,
    private notifications: NotificationsService,
  ) {}

  /**
   * Called after any successful change to Product.quantity (sale, refund,
   * purchase, adjustment, or an e-commerce order itself — self-echo from
   * the last case is harmless, just one extra outbound check). Fire-and-
   * forget from the caller's perspective — this method itself awaits its
   * own retries internally but never throws.
   */
  async pushStockUpdate(productId: string, storeId: string): Promise<void> {
    try {
      const mappings = await this.prisma.externalProductMapping.findMany({
        where: { productId, storeId },
      });
      if (mappings.length === 0) return;

      const integration = await this.prisma.ecommerceIntegration.findUnique({
        where: { storeId },
      });
      if (
        !integration ||
        !integration.enabled ||
        !integration.outboundWebhookUrl
      ) {
        return;
      }

      const product = await this.prisma.product.findUnique({
        where: { id: productId },
        select: { quantity: true },
      });
      if (!product) return;

      for (const mapping of mappings) {
        const succeeded = await this.postWithRetry(
          integration.outboundWebhookUrl,
          {
            externalProductId: mapping.externalProductId,
            quantity: product.quantity,
          },
        );
        if (!succeeded) {
          await this.notifyFailureIfNotRecentlyNotified(storeId);
        }
      }
    } catch (err) {
      // Never let an outbound-push failure affect the caller — this is
      // explicitly a best-effort side channel, not part of the operation
      // that changed stock in Dukon.
      this.logger.warn(
        `pushStockUpdate failed for product ${productId}: ${err}`,
      );
    }
  }

  private async postWithRetry(
    url: string,
    body: { externalProductId: string; quantity: number },
  ): Promise<boolean> {
    for (let attempt = 0; attempt < RETRY_DELAYS_MS.length; attempt++) {
      if (attempt > 0) {
        await this.sleep(RETRY_DELAYS_MS[attempt - 1]);
      }
      try {
        const res = await fetch(url, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(body),
        });
        if (res.ok) return true;
        this.logger.warn(
          `Outbound stock push to ${url} returned ${res.status} (attempt ${attempt + 1}/${RETRY_DELAYS_MS.length})`,
        );
      } catch (err) {
        this.logger.warn(
          `Outbound stock push to ${url} failed (attempt ${attempt + 1}/${RETRY_DELAYS_MS.length}): ${err}`,
        );
      }
    }
    return false;
  }

  private sleep(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }

  private async notifyFailureIfNotRecentlyNotified(
    storeId: string,
  ): Promise<void> {
    const now = Date.now();
    const last = this.lastFailureNotifiedAt.get(storeId);
    if (last && now - last < FAILURE_NOTIFICATION_COOLDOWN_MS) return;

    this.lastFailureNotifiedAt.set(storeId, now);
    await this.notifications.sendToStoreUsers(
      storeId,
      'Не удалось обновить остатки на сайте',
      'Проверьте настройки интеграции с интернет-магазином — обновление остатков не дошло до вашего сайта.',
      'ECOMMERCE_PUSH_FAILED',
    );
  }
}
