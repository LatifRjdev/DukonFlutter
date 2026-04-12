import {
  Injectable,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { UpdateCountItemsDto } from './dto/update-count-items.dto';

@Injectable()
export class InventoryCountsService {
  constructor(private prisma: PrismaService) {}

  async create(storeId: string) {
    // Load all active products with their current quantities as expectedQty
    const products = await this.prisma.product.findMany({
      where: { storeId, isActive: true },
      select: { id: true, quantity: true },
    });

    if (products.length === 0) {
      throw new BadRequestException('No active products found in this store');
    }

    const inventoryCount = await this.prisma.inventoryCount.create({
      data: {
        storeId,
        items: {
          create: products.map((p) => ({
            productId: p.id,
            expectedQty: p.quantity,
            actualQty: null,
          })),
        },
      },
      include: {
        items: {
          include: {
            product: {
              select: {
                id: true,
                name: true,
                sku: true,
                barcode: true,
                unit: true,
                quantity: true,
              },
            },
          },
        },
      },
    });

    return inventoryCount;
  }

  async findOne(storeId: string, id: string) {
    const inventoryCount = await this.prisma.inventoryCount.findFirst({
      where: { id, storeId },
      include: {
        items: {
          include: {
            product: {
              select: {
                id: true,
                name: true,
                sku: true,
                barcode: true,
                unit: true,
                quantity: true,
                sellPrice: true,
                costPrice: true,
              },
            },
          },
          orderBy: { product: { name: 'asc' } },
        },
      },
    });

    if (!inventoryCount) {
      throw new NotFoundException('Inventory count session not found');
    }

    return inventoryCount;
  }

  async updateItems(storeId: string, id: string, dto: UpdateCountItemsDto) {
    const inventoryCount = await this.prisma.inventoryCount.findFirst({
      where: { id, storeId },
    });

    if (!inventoryCount) {
      throw new NotFoundException('Inventory count session not found');
    }

    if (inventoryCount.status !== 'IN_PROGRESS') {
      throw new BadRequestException(
        'Cannot update items on a count session that is not IN_PROGRESS',
      );
    }

    // Upsert each item's actualQty
    await this.prisma.$transaction(
      dto.items.map((item) =>
        this.prisma.inventoryCountItem.updateMany({
          where: {
            inventoryCountId: id,
            productId: item.productId,
          },
          data: { actualQty: item.actualQty },
        }),
      ),
    );

    return this.findOne(storeId, id);
  }

  async apply(storeId: string, id: string) {
    const inventoryCount = await this.prisma.inventoryCount.findFirst({
      where: { id, storeId },
      include: {
        items: true,
      },
    });

    if (!inventoryCount) {
      throw new NotFoundException('Inventory count session not found');
    }

    if (inventoryCount.status !== 'IN_PROGRESS') {
      throw new BadRequestException(
        'This inventory count session is already finalized',
      );
    }

    // Only apply items that have actualQty set
    const itemsWithActual = inventoryCount.items.filter(
      (item) => item.actualQty !== null,
    );

    if (itemsWithActual.length === 0) {
      throw new BadRequestException('No items with actual quantities to apply');
    }

    await this.prisma.$transaction([
      // Update product quantities for all counted items
      ...itemsWithActual.map((item) =>
        this.prisma.product.update({
          where: { id: item.productId },
          data: { quantity: Math.round(item.actualQty!) },
        }),
      ),
      // Mark the count session as COMPLETED
      this.prisma.inventoryCount.update({
        where: { id },
        data: {
          status: 'COMPLETED',
          completedAt: new Date(),
        },
      }),
    ]);

    return this.findOne(storeId, id);
  }
}
