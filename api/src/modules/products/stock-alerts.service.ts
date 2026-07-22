import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { PrismaService } from '../../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { hasFeatureFlag } from '../../common/guards/feature-flag.helper';

const MS_PER_DAY = 24 * 60 * 60 * 1000;

@Injectable()
export class StockAlertsService {
  private readonly logger = new Logger(StockAlertsService.name);

  constructor(
    private prisma: PrismaService,
    private notifications: NotificationsService,
  ) {}

  // Other crons in this codebase run at 0/2/9 — 8 is a distinct slot to
  // avoid clustering.
  @Cron('0 8 * * *')
  async checkSlowMovingStock(): Promise<void> {
    const stores = await this.prisma.store.findMany({
      where: { isActive: true },
      select: { id: true, settings: true },
    });

    for (const store of stores) {
      try {
        await this.checkStoreForSlowMovingStock(store);
      } catch (err) {
        this.logger.error(
          `checkSlowMovingStock failed for store ${store.id}`,
          err,
        );
      }
    }
  }

  private async checkStoreForSlowMovingStock(store: {
    id: string;
    settings: unknown;
  }) {
    const planHasFlag = await hasFeatureFlag(
      this.prisma,
      store.id,
      'hasBatchProfitability',
    );
    if (!planHasFlag) return;

    const notif = (store.settings as any)?.notifications ?? {};
    const daysThreshold =
      typeof notif.daysWithoutSaleThreshold === 'number'
        ? notif.daysWithoutSaleThreshold
        : 30;
    const percentThreshold =
      typeof notif.remainingPercentThreshold === 'number'
        ? notif.remainingPercentThreshold
        : 50;
    const cutoff = new Date(Date.now() - daysThreshold * MS_PER_DAY);

    const products = await this.prisma.product.findMany({
      where: { storeId: store.id, isActive: true, quantity: { gt: 0 } },
      select: { id: true, name: true, quantity: true },
    });

    // One product at a time (N+1 queries) — acceptable for a once-daily
    // background job; not something a request handler should ever do.
    for (const product of products) {
      const anchor = await this.prisma.stockMovement.findFirst({
        where: { productId: product.id, type: 'PURCHASE' },
        orderBy: { createdAt: 'desc' },
        select: { quantity: true, createdAt: true },
      });
      if (!anchor || anchor.quantity <= 0) continue;

      const remainingPercent = (product.quantity / anchor.quantity) * 100;
      if (remainingPercent < percentThreshold) continue;

      const lastSale = await this.prisma.saleItem.findFirst({
        where: {
          productId: product.id,
          sale: { storeId: store.id, createdAt: { gte: anchor.createdAt } },
        },
        orderBy: { sale: { createdAt: 'desc' } },
        select: { sale: { select: { createdAt: true } } },
      });
      const referenceDate = lastSale?.sale.createdAt ?? anchor.createdAt;
      if (referenceDate > cutoff) continue;

      const daysSince = Math.floor(
        (Date.now() - referenceDate.getTime()) / MS_PER_DAY,
      );

      void this.notifications.sendToStoreUsers(
        store.id,
        '📉 Товар не продаётся',
        `Товар "${product.name}" не продаётся ${daysSince} дней, осталось ${product.quantity} из ${anchor.quantity} шт. Возможно, стоит снизить цену.`,
        'SLOW_MOVING_STOCK',
      );
    }
  }
}
