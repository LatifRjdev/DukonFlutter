import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { CreateStockMovementDto } from './dto/create-stock-movement.dto';

@Injectable()
export class StockMovementsService {
  constructor(private prisma: PrismaService) {}

  async create(
    storeId: string,
    dto: CreateStockMovementDto,
    createdBy?: string,
  ) {
    // Spec B E.2: idempotent replay. If localId already used,
    // return the existing row instead of creating a duplicate
    // (and skip re-applying the stock-quantity change).
    if (dto.localId) {
      const existing = await this.prisma.stockMovement.findUnique({
        where: { localId: dto.localId },
      });
      if (existing) return existing;
    }

    // Verify product belongs to store
    const product = await this.prisma.product.findFirst({
      where: { id: dto.productId, storeId },
    });
    if (!product)
      throw new NotFoundException('Product not found in this store');

    const totalCost = dto.unitCost ? dto.unitCost * dto.quantity : undefined;

    return this.prisma.$transaction(async (tx) => {
      const movement = await tx.stockMovement.create({
        data: {
          productId: dto.productId,
          type: dto.type,
          quantity: dto.quantity,
          unitCost: dto.unitCost,
          totalCost,
          supplierId: dto.supplierId,
          reference: dto.reference,
          notes: dto.notes,
          createdBy,
          localId: dto.localId ?? null,
        },
      });

      // Update product quantity
      let quantityChange = 0;
      if (dto.type === 'PURCHASE' || dto.type === 'RETURN') {
        quantityChange = dto.quantity;
      } else if (dto.type === 'SALE' || dto.type === 'WRITE_OFF') {
        quantityChange = -dto.quantity;
      }
      // ADJUSTMENT and TRANSFER handled by explicit quantity

      if (quantityChange !== 0) {
        await tx.product.update({
          where: { id: dto.productId },
          data: { quantity: { increment: quantityChange } },
        });
      }

      // Update cost price if PURCHASE
      if (dto.type === 'PURCHASE' && dto.unitCost) {
        await tx.product.update({
          where: { id: dto.productId },
          data: { costPrice: dto.unitCost },
        });
      }

      return movement;
    });
  }

  async findAll(storeId: string, productId?: string, page = 1, limit = 20) {
    const where: any = {};
    if (productId) {
      const product = await this.prisma.product.findFirst({
        where: { id: productId, storeId },
      });
      if (!product) throw new NotFoundException('Product not found');
      where.productId = productId;
    } else {
      where.product = { storeId };
    }

    const [data, total] = await Promise.all([
      this.prisma.stockMovement.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * limit,
        take: limit,
      }),
      this.prisma.stockMovement.count({ where }),
    ]);

    return { data, total, page, limit, totalPages: Math.ceil(total / limit) };
  }
}
