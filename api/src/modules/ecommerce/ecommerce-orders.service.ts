import {
  Injectable,
  ConflictException,
  ForbiddenException,
  NotFoundException,
  UnauthorizedException,
  UnprocessableEntityException,
} from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { EcommerceOutboundService } from './ecommerce-outbound.service';
import { EcommerceWebhookDto } from './dto/ecommerce-webhook.dto';

// Distinguishable marker thrown from inside the $transaction callback when
// the atomic updateMany() stock guard loses a race with a concurrent
// in-store sale (see the comment at the throw site below). Never sent to a
// client directly — createOrder() catches it once the transaction has
// unwound, fires the owner notification (outside the now-rolled-back
// transaction), and re-throws as a ConflictException (409) — unlike the
// other two rejection paths, which throw UnprocessableEntityException
// (422), because this condition is transient and safe to retry.
class StockConflictError extends Error {
  constructor(public readonly productId: string) {
    super(`Stock for product ${productId} changed concurrently`);
  }
}

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

    // Single source of truth for each item's mapped productId + product
    // record, reused below instead of re-deriving mappingByExternalId →
    // productById independently at each call site. Deliberately does NOT
    // resolve unitPrice yet, and deliberately does not `!`-assert product
    // is defined — a product can legitimately be missing here (deleted
    // after being externally mapped), and that has to fail gracefully via
    // the stock-sufficiency check right below, not crash here.
    const resolved = items.map((item) => {
      const productId = mappingByExternalId.get(
        item.externalProductId,
      )!.productId;
      const product = productById.get(productId);
      return { item, productId, product };
    });

    for (const { item, productId, product } of resolved) {
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

    // Only reachable once the loop above has confirmed every item's
    // product exists and has sufficient stock — safe to assert non-null
    // here, unlike in `resolved` above. NOTE: no test covers the
    // missing-product path (it requires a product deleted post-mapping AND
    // an item that omits its own price, since item.price short-circuits the
    // sellPrice read), so collapsing these two arrays back into one will
    // NOT fail the suite — it will fail in production.
    const priced = resolved.map(({ item, productId, product }) => ({
      item,
      productId,
      product: product!,
      unitPrice: item.price ?? Number(product!.sellPrice),
    }));

    // Cross-check the external site's claimed totalAmount against what
    // Dukon itself computes from the mapped products' prices and the
    // order's line-item quantities. dto.totalAmount is only ever trusted
    // input from the external site — without this check a compromised or
    // buggy site could report an artificially low total and Dukon would
    // record the sale (and decrement stock) at that wrong value.
    const TOTAL_AMOUNT_TOLERANCE = 0.01;
    const computedTotal = priced.reduce(
      (sum, { item, unitPrice }) => sum + unitPrice * item.quantity,
      0,
    );
    // !Number.isFinite guards the failure mode explicitly rather than
    // relying solely on the DTO's upstream class-validator requirement:
    // Math.abs(computedTotal - undefined) is NaN, and NaN > tolerance is
    // false, so a missing/non-numeric totalAmount would otherwise silently
    // pass this check if that upstream guarantee ever changed.
    if (
      !Number.isFinite(dto.totalAmount) ||
      Math.abs(computedTotal - dto.totalAmount!) > TOTAL_AMOUNT_TOLERANCE
    ) {
      await this.notifications.sendToStoreUsers(
        storeId,
        'Заказ с сайта отклонён',
        `Заказ ${dto.externalOrderId} отклонён — переданная сумма заказа (${dto.totalAmount}) не совпадает с суммой по товарам (${computedTotal.toFixed(2)}).`,
        'ECOMMERCE_ORDER_REJECTED',
      );
      throw new UnprocessableEntityException(
        `totalAmount (${dto.totalAmount}) does not match computed item sum (${computedTotal.toFixed(2)})`,
      );
    }

    const subscription = await this.prisma.subscription.findUnique({
      where: { storeId },
    });
    const planConfig = await this.prisma.subscriptionPlanConfig.findUnique({
      where: { plan: subscription!.plan },
    });

    let sale;
    try {
      sale = await this.prisma.$transaction(async (tx) => {
        const customer = await tx.customer.upsert({
          where: { storeId_phone: { storeId, phone: dto.customer!.phone } },
          create: {
            storeId,
            name: dto.customer!.name,
            phone: dto.customer!.phone,
          },
          update: { name: dto.customer!.name },
        });

        const saleItemsData = priced.map(
          ({ item, productId, product, unitPrice }) => ({
            productId,
            productName: product.name,
            quantity: item.quantity,
            unitPrice,
            costPrice: product.costPrice ?? undefined,
            total: unitPrice * item.quantity,
          }),
        );

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
            // Persist Dukon's own computedTotal, not the site's
            // dto.totalAmount — it's already been proven consistent with
            // it (within TOTAL_AMOUNT_TOLERANCE) above, and using it here
            // keeps Sale.total consistent with the line items it was
            // derived from, rather than the site's independently-rounded
            // figure (which can still diverge slightly on >2dp item
            // prices, since the DTO's item.price has no decimal-places
            // constraint).
            subtotal: computedTotal,
            total: computedTotal,
            paymentType: 'CARD',
            paidAmount: computedTotal,
            status: 'COMPLETED',
            externalOrderId: dto.externalOrderId,
            items: { create: saleItemsData },
          },
          include: { items: true },
        });

        for (const { item, productId } of priced) {
          const result = await tx.product.updateMany({
            where: { id: productId, quantity: { gte: item.quantity } },
            data: { quantity: { decrement: item.quantity } },
          });
          if (result.count === 0) {
            // Stock changed between the pre-transaction check above and
            // this write (race with an in-store sale) — abort the whole
            // transaction; the site should retry the webhook per the
            // design spec's data-integrity contract.
            //
            // Throw a distinguishable marker instead of
            // ConflictException directly: notifications.
            // sendToStoreUsers must NOT be called from inside a transaction
            // that's about to roll back (unlike the two pre-transaction
            // rejection paths above, which notify before the transaction
            // even starts). createOrder() below catches this marker once
            // $transaction has unwound and fires the notification there.
            throw new StockConflictError(productId);
          }
        }

        await tx.stockMovement.createMany({
          data: priced.map(({ item, productId }) => ({
            productId,
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
    } catch (err) {
      if (err instanceof StockConflictError) {
        // Outside the transaction now (it has already rolled back), so
        // this is safe to fire without holding anything open. Matches
        // this codebase's established fire-and-forget notification
        // pattern (see the `void this.outbound.pushStockUpdate(...)`
        // calls below) rather than awaiting — the request is already
        // headed for a 409, so there's nothing further to gate on it.
        void this.notifications.sendToStoreUsers(
          storeId,
          'Заказ с сайта отклонён',
          `Заказ ${dto.externalOrderId} отклонён — остаток товара изменился во время обработки заказа (конкурентная продажа в магазине). Повторите попытку.`,
          'ECOMMERCE_ORDER_REJECTED',
        );
        throw new ConflictException(
          `Stock for product ${err.productId} changed concurrently — retry the webhook`,
        );
      }
      throw err;
    }

    // Fire-and-forget per the design spec's data-integrity section: the
    // merchant's own webhook endpoint being slow or unreachable must
    // never block or delay Dukon's own webhook response. pushStockUpdate
    // never throws (see EcommerceOutboundService) and retries internally
    // with its own backoff, so it's safe to let it run in the background.
    for (const { productId } of priced) {
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
