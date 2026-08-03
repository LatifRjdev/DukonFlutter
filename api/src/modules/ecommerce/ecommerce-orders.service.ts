import {
  Injectable,
  ForbiddenException,
  NotFoundException,
  UnauthorizedException,
  UnprocessableEntityException,
} from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { EcommerceOutboundService } from './ecommerce-outbound.service';
import { EcommerceWebhookDto } from './dto/ecommerce-webhook.dto';

@Injectable()
export class EcommerceOrdersService {
  constructor(
    private prisma: PrismaService,
    private notifications: NotificationsService,
    private outbound: EcommerceOutboundService,
  ) {}

  async handleWebhook(
    storeId: string,
    apiKey: string,
    dto: EcommerceWebhookDto,
  ) {
    await this.assertAuthorized(storeId, apiKey);

    if (dto.event === 'order.created') {
      return this.createOrder(storeId, dto);
    }
    return this.cancelOrder(storeId, dto.externalOrderId);
  }

  private async assertAuthorized(
    storeId: string,
    apiKey: string,
  ): Promise<void> {
    const integration = await this.prisma.ecommerceIntegration.findUnique({
      where: { storeId },
    });
    if (!integration || integration.apiKey !== apiKey || !integration.enabled) {
      throw new UnauthorizedException(
        'Invalid or disabled e-commerce integration API key',
      );
    }

    // Defensive re-check: the integration row can exist and even carry a
    // valid key after the store has since downgraded off PREMIUM (e.g.
    // subscription lapsed) — mirrors SubscriptionGuard's own logic
    // (subscription.guard.ts) since that guard needs a JwtAuthGuard
    // request context this public webhook doesn't have.
    const subscription = await this.prisma.subscription.findUnique({
      where: { storeId },
    });
    if (!subscription || !['ACTIVE', 'TRIAL'].includes(subscription.status)) {
      throw new ForbiddenException('Store subscription is not active');
    }
    const planConfig = await this.prisma.subscriptionPlanConfig.findUnique({
      where: { plan: subscription.plan },
    });
    if (!planConfig?.hasEcommerceIntegration) {
      throw new ForbiddenException(
        'E-commerce integration is not available on the current plan',
      );
    }
  }

  private async createOrder(storeId: string, dto: EcommerceWebhookDto) {
    const existing = await this.prisma.sale.findUnique({
      where: {
        storeId_externalOrderId: {
          storeId,
          externalOrderId: dto.externalOrderId,
        },
      },
    });
    if (existing) return existing;

    const items = dto.items!;
    const mappings = await this.prisma.externalProductMapping.findMany({
      where: {
        storeId,
        externalProductId: { in: items.map((i) => i.externalProductId) },
      },
    });
    const mappingByExternalId = new Map(
      mappings.map((m) => [m.externalProductId, m]),
    );

    const missing = items.find(
      (i) => !mappingByExternalId.has(i.externalProductId),
    );
    if (missing) {
      await this.notifications.sendToStoreUsers(
        storeId,
        'Заказ с сайта отклонён',
        `Товар "${missing.externalProductId}" не сопоставлен с товаром Dukon — заказ ${dto.externalOrderId} отклонён.`,
        'ECOMMERCE_ORDER_REJECTED',
      );
      throw new UnprocessableEntityException(
        `No product mapping for externalProductId "${missing.externalProductId}"`,
      );
    }

    const productIds = items.map(
      (i) => mappingByExternalId.get(i.externalProductId)!.productId,
    );
    const products = await this.prisma.product.findMany({
      where: { id: { in: productIds }, storeId },
    });
    const productById = new Map(products.map((p) => [p.id, p]));

    for (const item of items) {
      const productId = mappingByExternalId.get(
        item.externalProductId,
      )!.productId;
      const product = productById.get(productId);
      if (!product || product.quantity < item.quantity) {
        await this.notifications.sendToStoreUsers(
          storeId,
          'Заказ с сайта отклонён',
          `Заказ ${dto.externalOrderId} отклонён — не хватает товара "${product?.name ?? item.externalProductId}".`,
          'ECOMMERCE_ORDER_REJECTED',
        );
        throw new UnprocessableEntityException(
          `Insufficient stock for product "${product?.name ?? productId}"`,
        );
      }
    }

    const subscription = await this.prisma.subscription.findUnique({
      where: { storeId },
    });
    const planConfig = await this.prisma.subscriptionPlanConfig.findUnique({
      where: { plan: subscription!.plan },
    });

    const sale = await this.prisma.$transaction(async (tx) => {
      const customer = await tx.customer.upsert({
        where: { storeId_phone: { storeId, phone: dto.customer!.phone } },
        create: {
          storeId,
          name: dto.customer!.name,
          phone: dto.customer!.phone,
        },
        update: { name: dto.customer!.name },
      });

      const saleItemsData = items.map((item) => {
        const productId = mappingByExternalId.get(
          item.externalProductId,
        )!.productId;
        const product = productById.get(productId)!;
        const unitPrice = item.price ?? Number(product.sellPrice);
        return {
          productId,
          productName: product.name,
          quantity: item.quantity,
          unitPrice,
          costPrice: product.costPrice ?? undefined,
          total: unitPrice * item.quantity,
        };
      });

      const createdSale = await tx.sale.create({
        data: {
          storeId,
          customerId: customer.id,
          channel: 'ONLINE',
          // Deliberately not SalesService's generateReceiptNo() sequence
          // (that's for in-store cash-register receipts). externalOrderId
          // is already unique per store (Task 1's @@unique constraint),
          // so this derived value automatically satisfies Sale's own
          // @@unique([storeId, receiptNo]) with no extra query needed.
          receiptNo: `ONLINE-${dto.externalOrderId}`,
          subtotal: dto.totalAmount!,
          total: dto.totalAmount!,
          paymentType: 'CARD',
          paidAmount: dto.totalAmount!,
          status: 'COMPLETED',
          externalOrderId: dto.externalOrderId,
          items: { create: saleItemsData },
        },
        include: { items: true },
      });

      for (const item of items) {
        const productId = mappingByExternalId.get(
          item.externalProductId,
        )!.productId;
        const result = await tx.product.updateMany({
          where: { id: productId, quantity: { gte: item.quantity } },
          data: { quantity: { decrement: item.quantity } },
        });
        if (result.count === 0) {
          // Stock changed between the pre-transaction check above and
          // this write (race with an in-store sale) — abort the whole
          // transaction; the site should retry the webhook per the
          // design spec's data-integrity contract.
          throw new UnprocessableEntityException(
            `Stock for product ${productId} changed concurrently — retry the webhook`,
          );
        }
      }

      await tx.stockMovement.createMany({
        data: items.map((item) => ({
          productId: mappingByExternalId.get(item.externalProductId)!.productId,
          type: 'SALE' as const,
          quantity: item.quantity,
          reference: dto.externalOrderId,
        })),
      });

      if (planConfig?.hasDelivery && dto.customer?.address) {
        await tx.delivery.create({
          data: {
            storeId,
            saleId: createdSale.id,
            address: dto.customer.address,
            status: 'NEW',
          },
        });
      }

      return createdSale;
    });

    // Fire-and-forget per the design spec's data-integrity section: the
    // merchant's own webhook endpoint being slow or unreachable must
    // never block or delay Dukon's own webhook response. pushStockUpdate
    // never throws (see EcommerceOutboundService) and retries internally
    // with its own backoff, so it's safe to let it run in the background.
    for (const item of items) {
      const productId = mappingByExternalId.get(
        item.externalProductId,
      )!.productId;
      void this.outbound.pushStockUpdate(productId, storeId);
    }

    return sale;
  }

  private async cancelOrder(storeId: string, externalOrderId: string) {
    const sale = await this.prisma.sale.findUnique({
      where: { storeId_externalOrderId: { storeId, externalOrderId } },
    });
    if (!sale) {
      // Idempotent per the design spec: the site may have retried a
      // cancel for an order Dukon never successfully recorded due to an
      // earlier failure — treat "not found" as "already cancelled or
      // never existed", not an error the site needs to handle specially.
      throw new NotFoundException('No matching order found for this store');
    }
    if (sale.status === 'CANCELLED') {
      return sale;
    }

    const affectedProductIds: string[] = [];

    const updated = await this.prisma.$transaction(async (tx) => {
      const items = await tx.saleItem.findMany({ where: { saleId: sale.id } });
      for (const item of items) {
        await tx.product.update({
          where: { id: item.productId },
          data: { quantity: { increment: item.quantity } },
        });
        affectedProductIds.push(item.productId);
      }
      if (items.length > 0) {
        await tx.stockMovement.createMany({
          data: items.map((item) => ({
            productId: item.productId,
            type: 'RETURN' as const,
            quantity: item.quantity,
            reference: externalOrderId,
          })),
        });
      }
      return tx.sale.update({
        where: { id: sale.id },
        data: { status: 'CANCELLED' },
      });
    });

    // Fire-and-forget — see the comment in createOrder() above.
    for (const productId of affectedProductIds) {
      void this.outbound.pushStockUpdate(productId, storeId);
    }

    return updated;
  }
}
