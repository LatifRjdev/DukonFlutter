import { Injectable, NotFoundException, ConflictException } from '@nestjs/common';
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
    await assertWithinPlanLimit(this.prisma, storeId, 'maxProducts', activeCount);

    if (dto.sku) {
      const existing = await this.prisma.product.findUnique({
        where: { storeId_sku: { storeId, sku: dto.sku } },
      });
      if (existing) throw new ConflictException('Product with this SKU already exists');
    }

    if (dto.barcode) {
      const existing = await this.prisma.product.findUnique({
        where: { storeId_barcode: { storeId, barcode: dto.barcode } },
      });
      if (existing) throw new ConflictException('Product with this barcode already exists');
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
    if (query.lowStock) {
      where.AND = [
        { quantity: { gt: 0 } },
        { quantity: { lte: this.prisma.$queryRaw`"minQuantity"` as any } },
      ];
      // Simplified: use raw where for lowStock
      where.AND = undefined;
      where.quantity = { gt: 0 };
    }

    const orderBy: Prisma.ProductOrderByWithRelationInput = {};
    if (query.sortBy) {
      (orderBy as any)[query.sortBy] = query.sortOrder || 'desc';
    }

    const [data, total] = await Promise.all([
      this.prisma.product.findMany({
        where,
        include: { category: { select: { id: true, name: true } } },
        orderBy: Object.keys(orderBy).length ? orderBy : { createdAt: 'desc' },
        skip: query.skip,
        take: query.limit || 20,
      }),
      this.prisma.product.count({ where }),
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
}
