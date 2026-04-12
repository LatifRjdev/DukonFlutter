import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { CreateDeliveryDto } from './dto/create-delivery.dto';
import { UpdateDeliveryStatusDto } from './dto/update-delivery-status.dto';
import { DeliveryQueryDto } from './dto/delivery-query.dto';
import { DeliveryStatus, Prisma } from '@prisma/client';

const STATUS_TRANSITIONS: Record<DeliveryStatus, DeliveryStatus[]> = {
  NEW: [DeliveryStatus.IN_TRANSIT, DeliveryStatus.CANCELLED],
  IN_TRANSIT: [DeliveryStatus.DELIVERED, DeliveryStatus.CANCELLED],
  DELIVERED: [],
  CANCELLED: [],
};

@Injectable()
export class DeliveriesService {
  constructor(private prisma: PrismaService) {}

  async create(storeId: string, dto: CreateDeliveryDto) {
    // Verify sale belongs to this store
    const sale = await this.prisma.sale.findFirst({
      where: { id: dto.saleId, storeId },
    });
    if (!sale) {
      throw new NotFoundException('Sale not found in this store');
    }

    // Check for existing delivery on this sale
    const existing = await this.prisma.delivery.findUnique({
      where: { saleId: dto.saleId },
    });
    if (existing) {
      throw new BadRequestException('This sale already has a delivery');
    }

    if (dto.courierId) {
      const courier = await this.prisma.staff.findFirst({
        where: { id: dto.courierId, storeId },
      });
      if (!courier) {
        throw new NotFoundException('Courier not found in this store');
      }
    }

    return this.prisma.delivery.create({
      data: {
        storeId,
        saleId: dto.saleId,
        address: dto.address,
        courierId: dto.courierId,
        notes: dto.notes,
      },
      include: {
        sale: {
          select: {
            id: true,
            receiptNo: true,
            total: true,
            customer: { select: { id: true, name: true, phone: true } },
          },
        },
        courier: {
          select: { id: true, user: { select: { name: true } }, role: true },
        },
      },
    });
  }

  async findAll(storeId: string, query: DeliveryQueryDto) {
    const where: Prisma.DeliveryWhereInput = { storeId };

    if (query.status) {
      where.status = query.status;
    }

    if (query.from || query.to) {
      where.createdAt = {};
      if (query.from) where.createdAt.gte = new Date(query.from);
      if (query.to) {
        const to = new Date(query.to);
        to.setHours(23, 59, 59, 999);
        where.createdAt.lte = to;
      }
    }

    const limit = query.limit ?? 20;
    const page = query.page ?? 1;
    const skip = (page - 1) * limit;

    const [data, total] = await Promise.all([
      this.prisma.delivery.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip,
        take: limit,
        include: {
          sale: {
            select: {
              id: true,
              receiptNo: true,
              total: true,
              customer: { select: { id: true, name: true, phone: true } },
            },
          },
          courier: {
            select: { id: true, user: { select: { name: true } }, role: true },
          },
        },
      }),
      this.prisma.delivery.count({ where }),
    ]);

    return {
      data,
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
    };
  }

  async findOne(storeId: string, id: string) {
    const delivery = await this.prisma.delivery.findFirst({
      where: { id, storeId },
      include: {
        sale: {
          include: {
            items: {
              include: {
                product: {
                  select: { id: true, name: true, barcode: true, unit: true },
                },
              },
            },
            customer: { select: { id: true, name: true, phone: true } },
          },
        },
        courier: {
          select: { id: true, role: true, user: { select: { name: true, phone: true } } },
        },
      },
    });

    if (!delivery) {
      throw new NotFoundException('Delivery not found');
    }

    return delivery;
  }

  async updateStatus(storeId: string, id: string, dto: UpdateDeliveryStatusDto) {
    const delivery = await this.findOne(storeId, id);

    const allowedTransitions = STATUS_TRANSITIONS[delivery.status];
    if (!allowedTransitions.includes(dto.status)) {
      throw new BadRequestException(
        `Cannot transition from ${delivery.status} to ${dto.status}`,
      );
    }

    return this.prisma.delivery.update({
      where: { id },
      data: { status: dto.status },
      include: {
        sale: {
          select: {
            id: true,
            receiptNo: true,
            total: true,
            customer: { select: { id: true, name: true } },
          },
        },
        courier: {
          select: { id: true, user: { select: { name: true } }, role: true },
        },
      },
    });
  }
}
