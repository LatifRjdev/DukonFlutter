import {
  Injectable,
  NotFoundException,
  ConflictException,
} from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { CreateProductDto } from './dto/create-product.dto';
import { UpdateProductDto } from './dto/update-product.dto';
import { ProductQueryDto } from './dto/product-query.dto';
import { Prisma } from '@prisma/client';
import { assertWithinPlanLimit } from '../../common/guards/plan-limit.helper';

@Injectable()
export class ProductsService {
  constructor(private prisma: PrismaService) {}

  async create(storeId: string, dto: CreateProductDto) {
    // F2.1: enforce plan-limit before any write. Counts only active rows
    // so soft-deleted products don't burn quota (paired with F3.1 fix).
    const activeCount = await this.prisma.product.count({
      where: { storeId, isActive: true },
    });
    await assertWithinPlanLimit(
      this.prisma,
      storeId,
      'maxProducts',
      activeCount,
    );

    if (dto.sku) {
      const existing = await this.prisma.product.findUnique({
        where: { storeId_sku: { storeId, sku: dto.sku } },
      });
      if (existing)
        throw new ConflictException('Product with this SKU already exists');
    }

    if (dto.barcode) {
      const existing = await this.prisma.product.findUnique({
        where: { storeId_barcode: { storeId, barcode: dto.barcode } },
      });
      if (existing)
        throw new ConflictException('Product with this barcode already exists');
    }

    return this.prisma.product.create({
      data: {
        storeId,
        name: dto.name,
        sku: dto.sku,
        barcode: dto.barcode,
        description: dto.description,
        categoryId: dto.categoryId,
        supplierId: dto.supplierId,
        costPrice: dto.costPrice,
        sellPrice: dto.sellPrice,
        wholesalePrice: dto.wholesalePrice,
        quantity: dto.quantity || 0,
        minQuantity: dto.minQuantity || 0,
        unit: dto.unit || 'PCS',
        imageUrl: dto.imageUrl,
      },
      include: { category: true, supplier: true },
    });
  }

  async findAll(storeId: string, query: ProductQueryDto) {
    // F3.1: soft-deleted (isActive=false) products previously remained
    // visible in list + total count. Default to active-only here; pass
    // `?includeArchived=true` to see archived rows.
    const where: Prisma.ProductWhereInput = { storeId };
    if (!query.includeArchived) {
      where.isActive = true;
    }

    if (query.search) {
      where.OR = [
        { name: { contains: query.search, mode: 'insensitive' } },
        { sku: { contains: query.search, mode: 'insensitive' } },
        { barcode: { contains: query.search, mode: 'insensitive' } },
      ];
    }

    if (query.categoryId) where.categoryId = query.categoryId;
    if (query.inStock === true) where.quantity = { gt: 0 };
    if (query.inStock === false) where.quantity = { lte: 0 };

    const orderBy: Prisma.ProductOrderByWithRelationInput = {};
    if (query.sortBy) {
      (orderBy as any)[query.sortBy] = query.sortOrder || 'desc';
    }
    const effectiveOrderBy = Object.keys(orderBy).length
      ? orderBy
      : { createdAt: 'desc' as const };
    const limit = query.limit || 20;

    // "Low stock" means quantity <= minQuantity (and quantity > 0, since an
    // out-of-stock product is a distinct concept handled by inStock=false).
    // That's a column-vs-column comparison on the same row, which Prisma's
    // query builder cannot express in `where`. There's no existing
    // $queryRaw precedent in this module/module set, so rather than bolt on
    // raw SQL for this one filter, fetch rows matching every other filter
    // normally, apply the low-stock predicate in application code, and
    // paginate the filtered result ourselves. Store catalogs are bounded in
    // size, so loading the filtered set before paginating is fine here.
    if (query.lowStock) {
      const candidates = await this.prisma.product.findMany({
        where,
        include: { category: { select: { id: true, name: true } } },
        orderBy: effectiveOrderBy,
      });
      const filtered = candidates.filter(
        (p: any) => p.quantity > 0 && p.quantity <= p.minQuantity,
      );
      const total = filtered.length;
      const data = filtered.slice(query.skip, query.skip + limit);

      return {
        data,
        total,
        page: query.page || 1,
        limit,
        totalPages: Math.ceil(total / limit),
      };
    }

    const [data, total] = await Promise.all([
      this.prisma.product.findMany({
        where,
        include: { category: { select: { id: true, name: true } } },
        orderBy: effectiveOrderBy,
        skip: query.skip,
        take: limit,
      }),
      this.prisma.product.count({ where }),
    ]);

    return {
      data,
      total,
      page: query.page || 1,
      limit,
      totalPages: Math.ceil(total / limit),
    };
  }

  async findOne(storeId: string, id: string) {
    // F3.1: only return active products. Soft-deleted rows surface as 404.
    const product = await this.prisma.product.findFirst({
      where: { id, storeId, isActive: true },
      include: { category: true, supplier: true },
    });
    if (!product) throw new NotFoundException('Product not found');
    return product;
  }

  async findByBarcode(storeId: string, barcode: string) {
    const product = await this.prisma.product.findUnique({
      where: { storeId_barcode: { storeId, barcode } },
      include: { category: true },
    });
    if (!product) throw new NotFoundException('Product not found');
    return product;
  }

  async update(storeId: string, id: string, dto: UpdateProductDto) {
    await this.findOne(storeId, id);
    return this.prisma.product.update({
      where: { id },
      data: dto as any,
      include: { category: true, supplier: true },
    });
  }

  async remove(storeId: string, id: string) {
    await this.findOne(storeId, id);
    return this.prisma.product.update({
      where: { id },
      data: { isActive: false },
    });
  }

  // Finds the product's most recent PURCHASE stock movement ("the anchor" /
  // "the batch") and computes how much of it has sold, for how much
  // revenue and profit, and how far the batch is from cash-payback.
  async getBatchProfitability(storeId: string, id: string) {
    const product = await this.prisma.product.findFirst({
      where: { id, storeId, isActive: true },
    });
    if (!product) throw new NotFoundException('Product not found');

    const anchor = await this.prisma.stockMovement.findFirst({
      where: { productId: id, type: 'PURCHASE' },
      orderBy: { createdAt: 'desc' },
    });

    const remainingQuantity = product.quantity;
    const remainingStockValue = product.costPrice
      ? Number(product.costPrice) * remainingQuantity
      : null;

    if (!anchor || anchor.totalCost == null) {
      return {
        hasBatch: false,
        batchQuantity: null,
        batchCost: null,
        soldQuantity: null,
        revenue: null,
        profitEarned: null,
        remainingQuantity,
        remainingStockValue,
        paybackPercent: null,
        paybackShortfall: null,
      };
    }

    const soldItems = await this.prisma.saleItem.findMany({
      where: {
        productId: id,
        sale: { storeId, createdAt: { gte: anchor.createdAt } },
      },
      select: {
        quantity: true,
        refundedQuantity: true,
        costPrice: true,
        total: true,
      },
    });

    let soldQuantity = 0;
    let revenue = new Prisma.Decimal(0);
    let profitEarned = new Prisma.Decimal(0);
    for (const item of soldItems) {
      const netQty = item.quantity - item.refundedQuantity;
      soldQuantity += netQty;
      // F-RACE-2 pattern (see sales.service.ts refund()): `total` already
      // nets out any discount for the FULL line, so pro-rate it to the
      // non-refunded quantity rather than recomputing from unitPrice.
      const perUnitNet = new Prisma.Decimal(item.total).div(item.quantity);
      const lineRevenue = perUnitNet.mul(netQty);
      revenue = revenue.add(lineRevenue);
      const costSnapshot =
        item.costPrice != null
          ? new Prisma.Decimal(item.costPrice)
          : new Prisma.Decimal(0);
      profitEarned = profitEarned.add(
        lineRevenue.sub(costSnapshot.mul(netQty)),
      );
    }

    const batchCost = new Prisma.Decimal(anchor.totalCost);
    const paybackPercent = batchCost.gt(0)
      ? revenue.div(batchCost).mul(100).toNumber()
      : null;
    const paybackShortfall = revenue.sub(batchCost).toNumber();

    return {
      hasBatch: true,
      batchQuantity: anchor.quantity,
      batchCost: batchCost.toNumber(),
      soldQuantity,
      revenue: revenue.toNumber(),
      profitEarned: profitEarned.toNumber(),
      remainingQuantity,
      remainingStockValue,
      paybackPercent,
      paybackShortfall,
    };
  }
}
