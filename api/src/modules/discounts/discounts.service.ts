import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { CreateDiscountDto } from './dto/create-discount.dto';
import { UpdateDiscountDto } from './dto/update-discount.dto';
import { ApplicableDiscountQueryDto } from './dto/applicable-discount-query.dto';

@Injectable()
export class DiscountsService {
  constructor(private prisma: PrismaService) {}

  async create(storeId: string, dto: CreateDiscountDto) {
    return this.prisma.discount.create({
      data: {
        storeId,
        name: dto.name,
        type: dto.type,
        value: dto.value,
        condition: dto.condition,
        categoryId: dto.categoryId,
        productId: dto.productId,
        minTotal: dto.minTotal,
        startDate: new Date(dto.startDate),
        endDate: dto.endDate ? new Date(dto.endDate) : null,
        active: dto.active ?? true,
      },
    });
  }

  async findAll(storeId: string) {
    return this.prisma.discount.findMany({
      where: { storeId },
      orderBy: { createdAt: 'desc' },
    });
  }

  async findApplicable(storeId: string, query: ApplicableDiscountQueryDto) {
    const now = new Date();

    const categoryIds = query.categoryIds
      ? query.categoryIds.split(',').map((id) => id.trim()).filter(Boolean)
      : [];

    const productIds = query.productIds
      ? query.productIds.split(',').map((id) => id.trim()).filter(Boolean)
      : [];

    const discounts = await this.prisma.discount.findMany({
      where: {
        storeId,
        active: true,
        startDate: { lte: now },
        OR: [{ endDate: null }, { endDate: { gte: now } }],
      },
    });

    return discounts.filter((discount) => {
      // Check minTotal if set
      if (discount.minTotal !== null && discount.minTotal !== undefined) {
        if ((query.total ?? 0) < discount.minTotal) return false;
      }

      // Filter by condition
      switch (discount.condition) {
        case 'CART':
          return true;
        case 'CATEGORY':
          return (
            discount.categoryId != null &&
            categoryIds.includes(discount.categoryId)
          );
        case 'PRODUCT':
          return (
            discount.productId != null &&
            productIds.includes(discount.productId)
          );
        default:
          return false;
      }
    });
  }

  async findOne(storeId: string, id: string) {
    const discount = await this.prisma.discount.findFirst({
      where: { id, storeId },
    });
    if (!discount) throw new NotFoundException('Discount not found');
    return discount;
  }

  async update(storeId: string, id: string, dto: UpdateDiscountDto) {
    await this.findOne(storeId, id);
    return this.prisma.discount.update({
      where: { id },
      data: {
        ...(dto.name !== undefined && { name: dto.name }),
        ...(dto.type !== undefined && { type: dto.type }),
        ...(dto.value !== undefined && { value: dto.value }),
        ...(dto.condition !== undefined && { condition: dto.condition }),
        ...(dto.categoryId !== undefined && { categoryId: dto.categoryId }),
        ...(dto.productId !== undefined && { productId: dto.productId }),
        ...(dto.minTotal !== undefined && { minTotal: dto.minTotal }),
        ...(dto.startDate !== undefined && {
          startDate: new Date(dto.startDate),
        }),
        ...(dto.endDate !== undefined && {
          endDate: dto.endDate ? new Date(dto.endDate) : null,
        }),
        ...(dto.active !== undefined && { active: dto.active }),
      },
    });
  }

  async remove(storeId: string, id: string) {
    await this.findOne(storeId, id);
    return this.prisma.discount.update({
      where: { id },
      data: { active: false },
    });
  }
}
