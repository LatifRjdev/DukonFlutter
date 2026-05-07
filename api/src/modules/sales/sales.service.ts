import {
  Injectable,
  NotFoundException,
  BadRequestException,
  Logger,
} from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { RedisService } from '../../redis/redis.service';
import { CreateSaleDto } from './dto/create-sale.dto';
import { SaleQueryDto } from './dto/sale-query.dto';
import { RefundSaleDto } from './dto/refund-sale.dto';
import { Prisma } from '@prisma/client';

@Injectable()
export class SalesService {
  private readonly logger = new Logger(SalesService.name);

  constructor(
    private prisma: PrismaService,
    private redis: RedisService,
  ) {}

  async create(storeId: string, dto: CreateSaleDto) {
    if (!dto.items || dto.items.length === 0) {
      throw new BadRequestException('Sale must have at least one item');
    }

    return this.prisma.$transaction(async (tx) => {
      // Generate receipt number
      const receiptNo = await this.generateReceiptNo(storeId);

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
        const itemTotal = unitPrice.mul(item.quantity).sub(itemDiscount);

        subtotal = subtotal.add(itemTotal);

        saleItems.push({
          productId: product.id,
          productName: product.name,
          quantity: item.quantity,
          unitPrice,
          costPrice: product.costPrice,
          discount: itemDiscount,
          total: itemTotal,
        });
      }

      // Apply sale-level discount
      let saleDiscount = new Prisma.Decimal(dto.discount || 0);
      if (dto.discountType === 'PERCENTAGE') {
        saleDiscount = subtotal.mul(dto.discount || 0).div(100);
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
          items: { create: saleItems },
        },
        include: { items: true, customer: true },
      });

      // Decrement product quantities and create stock movements
      for (const item of dto.items) {
        await tx.product.update({
          where: { id: item.productId },
          data: { quantity: { decrement: item.quantity } },
        });

        await tx.stockMovement.create({
          data: {
            productId: item.productId,
            type: 'SALE',
            quantity: item.quantity,
            reference: receiptNo,
          },
        });
      }

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

      return sale;
    });
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

  async refund(storeId: string, saleId: string, dto: RefundSaleDto) {
    const sale = await this.findOne(storeId, saleId);
    if (sale.status === 'RETURNED' || sale.status === 'CANCELLED') {
      throw new BadRequestException('Sale is already returned or cancelled');
    }

    return this.prisma.$transaction(async (tx) => {
      let isFullRefund = true;
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
        if (refundItem.quantity > saleItem.quantity) {
          throw new BadRequestException(
            `Refund quantity exceeds sale quantity for ${saleItem.productName}`,
          );
        }
        if (refundItem.quantity < saleItem.quantity) isFullRefund = false;

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

        // Per-line refund value = unitPrice × refundedQty (proportional
        // discount handling: line discount stays attached to original
        // remaining qty, so refund returns the gross unitPrice).
        const lineRefund = new Prisma.Decimal(saleItem.unitPrice).mul(
          refundItem.quantity,
        );
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

      // Check if all items are fully refunded
      const allItemsRefunded = sale.items.every((saleItem) => {
        const refundItem = dto.items.find((r) => r.saleItemId === saleItem.id);
        return refundItem && refundItem.quantity === saleItem.quantity;
      });

      const newStatus =
        allItemsRefunded && isFullRefund ? 'RETURNED' : 'PARTIALLY_RETURNED';

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

      return updated;
    });
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
