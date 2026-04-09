import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { CreateSupplierDto } from './dto/create-supplier.dto';
import { UpdateSupplierDto } from './dto/update-supplier.dto';
import { CreateSupplierPaymentDto } from './dto/create-payment.dto';
import { Prisma } from '@prisma/client';

@Injectable()
export class SuppliersService {
  constructor(private prisma: PrismaService) {}

  async create(storeId: string, dto: CreateSupplierDto) {
    return this.prisma.supplier.create({
      data: { storeId, ...dto },
    });
  }

  async findAll(storeId: string, page = 1, limit = 20, search?: string) {
    const where: Prisma.SupplierWhereInput = { storeId };

    if (search) {
      where.OR = [
        { name: { contains: search, mode: 'insensitive' } },
        { phone: { contains: search, mode: 'insensitive' } },
      ];
    }

    const [data, total] = await Promise.all([
      this.prisma.supplier.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * limit,
        take: limit,
      }),
      this.prisma.supplier.count({ where }),
    ]);

    return { data, total, page, limit, totalPages: Math.ceil(total / limit) };
  }

  async findOne(storeId: string, id: string) {
    const supplier = await this.prisma.supplier.findFirst({
      where: { id, storeId },
      include: {
        products: {
          where: { isActive: true },
          select: { id: true, name: true, sellPrice: true, quantity: true },
          take: 50,
        },
      },
    });
    if (!supplier) throw new NotFoundException('Supplier not found');
    return supplier;
  }

  async update(storeId: string, id: string, dto: UpdateSupplierDto) {
    await this.findOne(storeId, id);
    return this.prisma.supplier.update({
      where: { id },
      data: dto,
    });
  }

  async remove(storeId: string, id: string) {
    await this.findOne(storeId, id);
    return this.prisma.supplier.delete({ where: { id } });
  }

  async getDebts(storeId: string, supplierId: string) {
    const supplier = await this.findOne(storeId, supplierId);

    const recentPayments = await this.prisma.supplierPayment.findMany({
      where: { supplierId, storeId },
      orderBy: { createdAt: 'desc' },
      take: 20,
    });

    return {
      supplierId,
      debt: supplier.debt,
      recentPayments,
    };
  }

  async addPayment(storeId: string, supplierId: string, dto: CreateSupplierPaymentDto) {
    const supplier = await this.findOne(storeId, supplierId);

    if (Number(supplier.debt) <= 0) {
      throw new BadRequestException('This supplier has no outstanding debt');
    }

    if (dto.amount > Number(supplier.debt)) {
      throw new BadRequestException('Payment amount exceeds the outstanding debt');
    }

    return this.prisma.$transaction(async (tx) => {
      const payment = await tx.supplierPayment.create({
        data: {
          storeId,
          supplierId,
          amount: dto.amount,
          method: dto.method,
          notes: dto.notes,
        },
      });

      await tx.supplier.update({
        where: { id: supplierId },
        data: {
          debt: {
            decrement: dto.amount,
          },
        },
      });

      // Ensure debt doesn't go below 0
      await tx.supplier.updateMany({
        where: { id: supplierId, debt: { lt: 0 } },
        data: { debt: 0 },
      });

      return payment;
    });
  }

  async getPayments(storeId: string, supplierId: string) {
    await this.findOne(storeId, supplierId);

    return this.prisma.supplierPayment.findMany({
      where: { supplierId, storeId },
      orderBy: { createdAt: 'desc' },
    });
  }
}
