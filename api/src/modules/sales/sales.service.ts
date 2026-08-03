import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ConflictException,
  Logger,
} from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { RedisService } from '../../redis/redis.service';
import { AuditLogService } from '../../common/audit/audit-log.service';
import { NotificationsService } from '../notifications/notifications.service';
import { CreateSaleDto } from './dto/create-sale.dto';
import { SaleQueryDto } from './dto/sale-query.dto';
import { RefundSaleDto } from './dto/refund-sale.dto';
import { Prisma } from '@prisma/client';
import * as Sentry from '@sentry/nestjs';
import {
  LoyaltyService,
  isBirthday,
  addDays,
} from '../loyalty/loyalty.service';
import { EcommerceOutboundService } from '../ecommerce/ecommerce-outbound.service';

@Injectable()
export class SalesService {
  private readonly logger = new Logger(SalesService.name);

  constructor(
    private prisma: PrismaService,
    private redis: RedisService,
    private audit: AuditLogService,
    private notifications: NotificationsService,
    private loyaltyService: LoyaltyService,
    private ecommerceOutbound: EcommerceOutboundService,
  ) {}

  // F.3 + Deferred #1 (2026-05-11): per-store threshold (in store
  // currency) above which a sale triggers a "big sale" push to the
  // store owner. Read from `store.settings.bigSaleThreshold` if set;
  // otherwise falls back to this default. Setting it to 0 disables
  // the alert (useful for low-volume merchants who'd be spammed).
  private readonly DEFAULT_BIG_SALE_THRESHOLD = 1000;

  async create(storeId: string, dto: CreateSaleDto) {
    Sentry.addBreadcrumb({
      category: 'sales',
      message: 'sale.create',
      data: {
        storeId,
        itemCount: dto.items?.length ?? 0,
        paidAmount: dto.paidAmount,
        paymentType: dto.paymentType,
        localId: dto.localId,
      },
    });

    if (!dto.items || dto.items.length === 0) {
      throw new BadRequestException('Sale must have at least one item');
    }

    // F-IDEMPOTENT-1: if the client supplied a localId and a sale with
    // that localId already exists in this store, return it instead of
    // creating a duplicate. This makes the offline-replay path safe
    // under network-timeout retries — without dedupe, a sync that
    // succeeded server-side but timed out client-side would create
    // a second sale on the next retry.
    if (dto.localId) {
      const existing = await this.prisma.sale.findFirst({
        where: { storeId, localId: dto.localId },
        include: { items: true, customer: true },
      });
      if (existing) return existing;
    }

    // F-FK-1: validate referenced foreign keys belong to this store
    // BEFORE the transaction. Without these checks, a bogus shiftId or
    // staffId or customerId surfaces as a Prisma FK constraint error
    // and Nest maps it to a 500. Validating here means a 400 with a
    // friendly message instead.
    if (dto.shiftId) {
      const shift = await this.prisma.shift.findFirst({
        where: { id: dto.shiftId, storeId },
        select: { id: true, status: true },
      });
      if (!shift) {
        throw new BadRequestException('shiftId not found in this store');
      }
      if (shift.status !== 'OPEN') {
        throw new BadRequestException(
          'shiftId references a closed shift. Open a new shift first.',
        );
      }
    }
    if (dto.staffId) {
      const staff = await this.prisma.staff.findFirst({
        where: { id: dto.staffId, storeId, isActive: true },
        select: { id: true },
      });
      if (!staff) {
        throw new BadRequestException(
          'staffId not found in this store or is inactive',
        );
      }
    }
    if (dto.customerId) {
      const customer = await this.prisma.customer.findFirst({
        where: { id: dto.customerId, storeId },
        select: { id: true },
      });
      if (!customer) {
        throw new BadRequestException('customerId not found in this store');
      }
    }

    const result = await this.prisma.$transaction(async (tx) => {
      // F4.3: receipt number generation moved AFTER all validations.
      // Previously, INCR ran first and a subsequent BadRequestException
      // (insufficient stock, missing product, F4.1 cash-shortfall, …)
      // would consume a receipt number that never reached the DB,
      // leaving gaps in the sequence the auditor expects to be
      // continuous.

      // Fetch products and validate
      const productIds = dto.items.map((i) => i.productId);
      const products = await tx.product.findMany({
        where: { id: { in: productIds }, storeId },
      });

      if (products.length !== productIds.length) {
        throw new BadRequestException('Some products not found in this store');
      }

      const productMap = new Map(products.map((p) => [p.id, p]));

      // Calculate totals
      let subtotal = new Prisma.Decimal(0);
      const saleItems: any[] = [];

      for (const item of dto.items) {
        const product = productMap.get(item.productId);
        if (!product)
          throw new BadRequestException(`Product ${item.productId} not found`);

        if (product.quantity < item.quantity) {
          throw new BadRequestException(
            `Insufficient stock for ${product.name}. Available: ${product.quantity}`,
          );
        }

        const unitPrice = product.sellPrice;
        const itemDiscount = new Prisma.Decimal(item.discount || 0);
        // F-MONEY-1: clamp line discount so item.total can never go
        // negative. Previously a `1×@5 -100` line wrote items[0].total
        // = -95 which then propagated to sale.total. The cashier could
        // hand free goods AND owe the customer money via change=...
        const lineGross = unitPrice.mul(item.quantity);
        const clampedItemDiscount = itemDiscount.gt(lineGross)
          ? lineGross
          : itemDiscount;
        const itemTotal = lineGross.sub(clampedItemDiscount);

        subtotal = subtotal.add(itemTotal);

        saleItems.push({
          productId: product.id,
          productName: product.name,
          quantity: item.quantity,
          unitPrice,
          costPrice: product.costPrice,
          discount: clampedItemDiscount,
          total: itemTotal,
        });
      }

      // Apply sale-level discount.
      // F-MONEY-1: clamp PERCENTAGE to 0..100 and FIXED to 0..subtotal.
      // Without these clamps, discount=100 on a 5-TJS sale wrote
      // total=-95 and change=95 — i.e. the sale "owed" the customer 95
      // and stamped that as paid by the cashier.
      let saleDiscount = new Prisma.Decimal(dto.discount || 0);
      if (dto.discountType === 'PERCENTAGE') {
        const pct = Math.min(Math.max(dto.discount || 0, 0), 100);
        saleDiscount = subtotal.mul(pct).div(100);
      } else if (saleDiscount.gt(subtotal)) {
        saleDiscount = subtotal;
      }

      const total = subtotal.sub(saleDiscount);
      const paidAmount = new Prisma.Decimal(dto.paidAmount);
      const change = paidAmount.gt(total)
        ? paidAmount.sub(total)
        : new Prisma.Decimal(0);
      const debtAmount = total.gt(paidAmount)
        ? total.sub(paidAmount)
        : new Prisma.Decimal(0);

      // F4.1: a CASH or CARD sale that doesn't fully cover the total used
      // to silently spawn an orphan-debt row with customerId=null. That
      // money was effectively lost — the merchant delivered goods, no
      // customer was on the hook. Block the path: shortfalls must use
      // DEBT (full credit) or MIXED (cash + credit) with a customerId.
      if (
        debtAmount.gt(0) &&
        (dto.paymentType === 'CASH' || dto.paymentType === 'CARD')
      ) {
        throw new BadRequestException(
          `${dto.paymentType} payment must cover the full total. ` +
            `For partial payment + credit, use paymentType=MIXED or DEBT and supply customerId.`,
        );
      }
      // F4.1: any debt-bearing sale must be linked to a customer so the
      // debt has an owner.
      if (
        debtAmount.gt(0) &&
        (dto.paymentType === 'DEBT' || dto.paymentType === 'MIXED') &&
        !dto.customerId
      ) {
        throw new BadRequestException(
          'A sale with debtAmount > 0 must be linked to a customerId.',
        );
      }

      // F4.3: now safe to allocate a receipt number — every validation
      // above has passed, so this number will land in the DB.
      const receiptNo = await this.generateReceiptNo(storeId);

      // Create sale
      const sale = await tx.sale.create({
        data: {
          storeId,
          customerId: dto.customerId,
          staffId: dto.staffId,
          shiftId: dto.shiftId,
          receiptNo,
          subtotal,
          discount: saleDiscount,
          discountType: dto.discountType,
          total,
          paymentType: dto.paymentType,
          paidAmount,
          change,
          debtAmount,
          dueDate: dto.dueDate ? new Date(dto.dueDate) : undefined,
          notes: dto.notes,
          localId: dto.localId,
          // F-OFFLINE-1: client may pass occurredAt for offline-replayed
          // sales so the row lands in the right business day. We don't
          // override updatedAt — that one stays as server "last touched".
          ...(dto.occurredAt ? { createdAt: new Date(dto.occurredAt) } : {}),
          items: { create: saleItems },
        },
        include: { items: true, customer: true },
      });

      // Decrement product quantities and create stock movements.
      //
      // F-RACE-1: the earlier `findMany` + `update` pair was a TOCTOU.
      // At default Postgres READ COMMITTED isolation, two concurrent
      // sales for the last unit both read quantity=1, both pass the
      // validation block above, and both decrement — final qty goes
      // negative. Replaced with `updateMany WHERE quantity >= requested`
      // so the database does the atomic check + decrement; if zero
      // rows are affected, another transaction got there first.
      //
      // D.4: stock-movement creation moved out of the loop to a single
      // createMany after all decrements succeed (was 1 query per item).
      for (const item of dto.items) {
        const product = productMap.get(item.productId)!;
        const result = await tx.product.updateMany({
          where: {
            id: item.productId,
            quantity: { gte: item.quantity },
          },
          data: { quantity: { decrement: item.quantity } },
        });
        if (result.count === 0) {
          throw new ConflictException(
            `Insufficient stock for ${product.name} (another sale just claimed the last units).`,
          );
        }
      }

      await tx.stockMovement.createMany({
        data: dto.items.map((item) => ({
          productId: item.productId,
          type: 'SALE' as const,
          quantity: item.quantity,
          reference: receiptNo,
        })),
      });

      // Update customer debt and totalSpent
      if (dto.customerId) {
        const updateData: any = {
          totalSpent: { increment: total },
        };
        if (debtAmount.gt(0)) {
          updateData.debt = { increment: debtAmount };
        }
        await tx.customer.update({
          where: { id: dto.customerId },
          data: updateData,
        });
      }

      // ── LOYALTY INTEGRATION ────────────────────────────────────────
      if (dto.customerId) {
        const [sub, loyaltySettings] = await Promise.all([
          tx.subscription.findUnique({
            where: { storeId },
            select: { plan: true },
          }),
          tx.loyaltySettings.findUnique({
            where: { storeId },
          }),
        ]);

        if (loyaltySettings?.isEnabled) {
          const planConfig = sub?.plan
            ? await tx.subscriptionPlanConfig.findUnique({
                where: { plan: sub.plan },
                select: { hasLoyalty: true },
              })
            : null;

          if (planConfig?.hasLoyalty) {
            const customerRow = await tx.customer.findUnique({
              where: { id: dto.customerId },
              select: {
                loyaltyPoints: true,
                totalSpent: true,
                birthday: true,
              },
            });

            // totalSpent was already incremented by `total` above in this tx,
            // so subtract to get the pre-sale value for isFirstSale check.
            const preSaleTotalSpent = new Prisma.Decimal(
              customerRow?.totalSpent ?? 0,
            ).sub(total);
            const isFirstSale = preSaleTotalSpent.lte(0);

            let effectiveTotal = total; // Prisma.Decimal — sale total

            // Birthday discount (auto-applied when today matches birthday)
            if (
              loyaltySettings.birthdayDiscount &&
              customerRow?.birthday &&
              isBirthday(customerRow.birthday)
            ) {
              const factor = new Prisma.Decimal(1).sub(
                new Prisma.Decimal(loyaltySettings.birthdayDiscount).div(100),
              );
              effectiveTotal = effectiveTotal.mul(factor).toDecimalPlaces(2);
            }

            // Redemption
            if (dto.redemptionPoints && dto.redemptionPoints > 0) {
              const currentPoints = customerRow?.loyaltyPoints ?? 0;
              if (dto.redemptionPoints > currentPoints) {
                throw new BadRequestException(
                  `Cannot redeem ${dto.redemptionPoints} points — customer only has ${currentPoints}`,
                );
              }
              const redemptionValue = new Prisma.Decimal(
                loyaltySettings.pointValue,
              ).mul(dto.redemptionPoints);
              effectiveTotal = Prisma.Decimal.max(
                effectiveTotal.sub(redemptionValue),
                new Prisma.Decimal(0),
              );
              await this.loyaltyService.redeemPoints(tx as any, {
                customerId: dto.customerId,
                storeId,
                saleId: sale.id,
                points: dto.redemptionPoints,
              });
            }

            // Earn points on effectiveTotal
            const basePoints =
              Math.floor(
                effectiveTotal
                  .div(new Prisma.Decimal(loyaltySettings.amountForPoints))
                  .toNumber(),
              ) * loyaltySettings.pointsPerAmount;
            const bonusPoints = isFirstSale ? loyaltySettings.welcomePoints : 0;
            const totalEarned = basePoints + bonusPoints;

            if (totalEarned > 0) {
              const expiresAt = loyaltySettings.pointsExpireDays
                ? addDays(new Date(), loyaltySettings.pointsExpireDays)
                : null;
              await this.loyaltyService.earnPoints(tx as any, {
                customerId: dto.customerId,
                storeId,
                saleId: sale.id,
                points: totalEarned,
                expiresAt,
              });
            }
          }
        }
      }
      // ── END LOYALTY ─────────────────────────────────────────────────

      return sale;
    });

    // F.3: fire a "big sale" push to the store owner for amounts
    // ≥ threshold. Outside the transaction so a notification failure
    // can't roll back a real sale. Push is also gated by hasAllPush
    // because notifications.service silently no-ops if the feature
    // flag is off and FCM is unavailable.
    void this.maybeNotifyBigSale(storeId, result);

    // Notify the merchant's e-commerce site of the new stock levels for
    // every product this sale touched. Fire-and-forget — an outbound push
    // failure or slowness must never block or delay the sale itself.
    for (const item of dto.items) {
      void this.ecommerceOutbound.pushStockUpdate(item.productId, storeId);
    }

    if (dto.customerId && dto.redemptionPoints && dto.redemptionPoints > 0) {
      void this.loyaltyService.notifyLowBalanceIfNeeded(
        dto.customerId,
        storeId,
      );
    }

    return result;
  }

  private async maybeNotifyBigSale(
    storeId: string,
    sale: { id: string; total: any; receiptNo: string },
  ) {
    try {
      const store = await this.prisma.store.findUnique({
        where: { id: storeId },
        select: { ownerId: true, name: true, currency: true, settings: true },
      });
      if (!store) return;
      // Deferred #1: threshold can be overridden per-store via
      // store.settings.bigSaleThreshold. 0 disables the alert.
      const settings = (store.settings as Record<string, any>) ?? {};
      const overrideRaw = settings['bigSaleThreshold'];
      const threshold =
        typeof overrideRaw === 'number'
          ? overrideRaw
          : this.DEFAULT_BIG_SALE_THRESHOLD;
      if (threshold <= 0) return;
      if (Number(sale.total) < threshold) return;
      await this.notifications.sendPush(
        store.ownerId,
        `Крупная продажа в "${store.name}"`,
        `Чек ${sale.receiptNo}: ${Number(sale.total)} ${store.currency}`,
        'BIG_SALE',
        storeId,
      );
    } catch (err) {
      this.logger.warn(
        `big-sale notification failed for ${sale.id}: ${(err as Error).message}`,
      );
    }
  }

  async findAll(storeId: string, query: SaleQueryDto) {
    const where: Prisma.SaleWhereInput = { storeId };

    if (query.customerId) where.customerId = query.customerId;
    if (query.staffId) where.staffId = query.staffId;
    if (query.status) where.status = query.status as any;
    if (query.paymentType) where.paymentType = query.paymentType as any;

    if (query.dateFrom || query.dateTo) {
      where.createdAt = {};
      if (query.dateFrom) where.createdAt.gte = new Date(query.dateFrom);
      if (query.dateTo) where.createdAt.lte = new Date(query.dateTo);
    }

    const [data, total] = await Promise.all([
      this.prisma.sale.findMany({
        where,
        include: {
          customer: { select: { id: true, name: true } },
          items: {
            select: {
              id: true,
              productName: true,
              quantity: true,
              total: true,
            },
          },
        },
        orderBy: { createdAt: 'desc' },
        skip: query.skip,
        take: query.limit || 20,
      }),
      this.prisma.sale.count({ where }),
    ]);

    return {
      data,
      total,
      page: query.page || 1,
      limit: query.limit || 20,
      totalPages: Math.ceil(total / (query.limit || 20)),
    };
  }

  async findOne(storeId: string, id: string) {
    const sale = await this.prisma.sale.findFirst({
      where: { id, storeId },
      include: {
        items: {
          include: {
            product: { select: { id: true, name: true, imageUrl: true } },
          },
        },
        customer: true,
        debtPayments: true,
      },
    });
    if (!sale) throw new NotFoundException('Sale not found');
    return sale;
  }

  async refund(
    storeId: string,
    saleId: string,
    dto: RefundSaleDto,
    actorId: string = 'system',
  ) {
    Sentry.addBreadcrumb({
      category: 'sales',
      message: 'sale.refund',
      data: {
        storeId,
        saleId,
        itemCount: dto.items?.length ?? 0,
        reason: dto.reason,
      },
    });

    const sale = await this.findOne(storeId, saleId);
    if (sale.status === 'RETURNED' || sale.status === 'CANCELLED') {
      throw new BadRequestException('Sale is already returned or cancelled');
    }

    const result = await this.prisma.$transaction(async (tx) => {
      // F4.2: track total refunded value so we can decrement customer
      // debt + sale.debtAmount + customer.totalSpent in a consistent
      // single transaction with the stock restore.
      let refundedValue = new Prisma.Decimal(0);

      for (const refundItem of dto.items) {
        const saleItem = sale.items.find((i) => i.id === refundItem.saleItemId);
        if (!saleItem)
          throw new BadRequestException(
            `Sale item ${refundItem.saleItemId} not found`,
          );

        // BUG-REFUND-1: re-read the current refundedQuantity from inside
        // the transaction rather than trusting the pre-transaction `sale`
        // snapshot. Validating only against the item's original quantity
        // (with no memory of prior refund calls) allowed the same
        // saleItemId to be refunded an unbounded number of times as long
        // as the sale hadn't reached the fully-RETURNED terminal state —
        // each call re-incremented stock and re-credited customer
        // debt/totalSpent with no upper bound.
        const currentItem = await tx.saleItem.findUniqueOrThrow({
          where: { id: saleItem.id },
        });
        const remaining = currentItem.quantity - currentItem.refundedQuantity;
        if (refundItem.quantity > remaining) {
          throw new BadRequestException(
            `Refund quantity exceeds remaining refundable quantity for ${saleItem.productName} ` +
              `(requested ${refundItem.quantity}, remaining ${remaining})`,
          );
        }

        await tx.saleItem.update({
          where: { id: saleItem.id },
          data: { refundedQuantity: { increment: refundItem.quantity } },
        });

        // Restore stock
        await tx.product.update({
          where: { id: saleItem.productId },
          data: { quantity: { increment: refundItem.quantity } },
        });

        await tx.stockMovement.create({
          data: {
            productId: saleItem.productId,
            type: 'RETURN',
            quantity: refundItem.quantity,
            reference: sale.receiptNo,
            notes: dto.reason,
          },
        });

        // F-RACE-2: refund value must match what the customer actually
        // paid for those units, NOT the gross unitPrice. The previous
        // formula `unitPrice × refundedQty` over-credited whenever a
        // line discount or sale-level discount applied — refunding 1
        // unit out of a `1×@5 -1` sale was crediting 5 even though
        // the customer paid 4. customer.totalSpent went negative.
        //
        // Sale.discount (sale-level) is split proportionally across
        // line totals; line.discount is already deducted from line.total.
        // So the fair per-unit refund is `line.total / line.quantity`,
        // pro-rated by saleDiscount/sale.subtotal.
        const lineNet = new Prisma.Decimal(saleItem.total);
        const perUnitNet = lineNet.div(saleItem.quantity);
        let lineRefund = perUnitNet.mul(refundItem.quantity);
        if (
          (sale.discount as unknown as number) > 0 &&
          (sale.subtotal as unknown as number) > 0
        ) {
          const ratio = new Prisma.Decimal(1).sub(
            new Prisma.Decimal(sale.discount).div(sale.subtotal),
          );
          lineRefund = lineRefund.mul(ratio);
        }
        refundedValue = refundedValue.add(lineRefund);
      }

      // F4.2: if the original sale carried debt and a customer, drop the
      // debt by min(refundedValue, sale.debtAmount). totalSpent goes
      // down by the gross refunded value because the customer no longer
      // "spent" that money on us.
      const saleDebt = new Prisma.Decimal(sale.debtAmount);
      let saleDebtDecrement = new Prisma.Decimal(0);
      if (saleDebt.gt(0) && sale.customerId) {
        saleDebtDecrement = refundedValue.gt(saleDebt)
          ? saleDebt
          : refundedValue;
        await tx.customer.update({
          where: { id: sale.customerId },
          data: {
            debt: { decrement: saleDebtDecrement },
            totalSpent: { decrement: refundedValue },
          },
        });
      } else if (sale.customerId && refundedValue.gt(0)) {
        // Cash or card sale on a known customer: only adjust totalSpent.
        await tx.customer.update({
          where: { id: sale.customerId },
          data: { totalSpent: { decrement: refundedValue } },
        });
      }

      // BUG-REFUND-2: the old check only looked at whether THIS call's
      // dto.items fully covered every line item, so a legitimately
      // full refund spread across multiple calls (e.g. item A refunded
      // in one call, item B in another) never reached the RETURNED
      // terminal state. Read the cumulative refundedQuantity for every
      // line item instead, which is correct regardless of how many
      // calls it took.
      const allSaleItems = await tx.saleItem.findMany({
        where: { saleId },
      });
      const allItemsFullyRefunded = allSaleItems.every(
        (item) => item.refundedQuantity >= item.quantity,
      );

      const newStatus = allItemsFullyRefunded
        ? 'RETURNED'
        : 'PARTIALLY_RETURNED';

      const updated = await tx.sale.update({
        where: { id: saleId },
        data: {
          status: newStatus,
          // F4.2: drop the sale's outstanding debt by the same amount we
          // credited back to the customer.
          ...(saleDebtDecrement.gt(0) && {
            debtAmount: { decrement: saleDebtDecrement },
          }),
        },
        include: { items: true },
      });

      // D.3: emit audit log outside the inner write but still inside
      // the transaction promise. Failures in the logger are swallowed
      // so they can't roll back the refund.
      void this.audit.record(actorId, 'sale.refund', 'sale', saleId, {
        receiptNo: sale.receiptNo,
        refundedValue: refundedValue.toString(),
        saleDebtDecrement: saleDebtDecrement.toString(),
        newStatus,
        reason: dto.reason,
        items: dto.items,
      });

      return updated;
    });

    // Notify the merchant's e-commerce site of the restored stock levels
    // for every refunded product. Fire-and-forget, same as create() above.
    for (const refundItem of dto.items) {
      const saleItem = sale.items.find((i) => i.id === refundItem.saleItemId)!;
      void this.ecommerceOutbound.pushStockUpdate(saleItem.productId, storeId);
    }

    return result;
  }

  private async generateReceiptNo(storeId: string): Promise<string> {
    const key = `receipt:${storeId}`;
    try {
      const num = await this.redis.incr(key);
      return `R-${num.toString().padStart(6, '0')}`;
    } catch {
      // Fallback: count sales in DB
      const count = await this.prisma.sale.count({ where: { storeId } });
      return `R-${(count + 1).toString().padStart(6, '0')}`;
    }
  }
}
