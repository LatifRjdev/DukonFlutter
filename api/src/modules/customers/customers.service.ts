import {
  Injectable,
  NotFoundException,
  ConflictException,
  BadRequestException,
} from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { CreateCustomerDto } from './dto/create-customer.dto';
import { UpdateCustomerDto } from './dto/update-customer.dto';
import { CreateCustomerPaymentDto } from './dto/create-payment.dto';
import { Prisma } from '@prisma/client';

@Injectable()
export class CustomersService {
  constructor(private prisma: PrismaService) {}

  async create(storeId: string, dto: CreateCustomerDto) {
    if (dto.phone) {
      const existing = await this.prisma.customer.findUnique({
        where: { storeId_phone: { storeId, phone: dto.phone } },
      });
      if (existing)
        throw new ConflictException('Customer with this phone already exists');
    }

    return this.prisma.customer.create({
      data: {
        storeId,
        name: dto.name,
        phone: dto.phone,
        email: dto.email,
        birthday: dto.birthday ? new Date(dto.birthday) : undefined,
        notes: dto.notes,
      },
    });
  }

  async findAll(storeId: string, page = 1, limit = 20, search?: string) {
    const where: Prisma.CustomerWhereInput = { storeId, isActive: true };

    if (search) {
      where.OR = [
        { name: { contains: search, mode: 'insensitive' } },
        { phone: { contains: search, mode: 'insensitive' } },
      ];
    }

    const [data, total] = await Promise.all([
      this.prisma.customer.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * limit,
        take: limit,
      }),
      this.prisma.customer.count({ where }),
    ]);

    return { data, total, page, limit, totalPages: Math.ceil(total / limit) };
  }

  async findOne(storeId: string, id: string) {
    // F5.2: only return active customers. Soft-deleted rows surface as 404.
    const customer = await this.prisma.customer.findFirst({
      where: { id, storeId, isActive: true },
      include: {
        sales: {
          orderBy: { createdAt: 'desc' },
          take: 10,
          select: {
            id: true,
            receiptNo: true,
            total: true,
            createdAt: true,
            status: true,
          },
        },
      },
    });
    if (!customer) throw new NotFoundException('Customer not found');
    return customer;
  }

  async update(storeId: string, id: string, dto: UpdateCustomerDto) {
    await this.findOne(storeId, id);
    return this.prisma.customer.update({
      where: { id },
      data: {
        ...dto,
        birthday: dto.birthday ? new Date(dto.birthday) : undefined,
      },
    });
  }

  async remove(storeId: string, id: string) {
    await this.findOne(storeId, id);
    return this.prisma.customer.update({
      where: { id },
      data: { isActive: false },
    });
  }

  async getDebts(storeId: string, customerId: string) {
    await this.findOne(storeId, customerId);

    const sales = await this.prisma.sale.findMany({
      where: {
        customerId,
        storeId,
        debtAmount: { gt: 0 },
        status: 'COMPLETED',
      },
      orderBy: { createdAt: 'desc' },
      select: {
        id: true,
        receiptNo: true,
        total: true,
        debtAmount: true,
        createdAt: true,
        status: true,
      },
    });

    const customer = await this.prisma.customer.findUnique({
      where: { id: customerId },
      select: { debt: true },
    });

    return {
      customerId,
      totalDebt: customer?.debt ?? 0,
      sales,
    };
  }

  async addPayment(
    storeId: string,
    customerId: string,
    dto: CreateCustomerPaymentDto,
  ) {
    await this.findOne(storeId, customerId);

    const sale = await this.prisma.sale.findFirst({
      where: { id: dto.saleId, customerId, storeId },
    });

    if (!sale) {
      throw new NotFoundException('Sale not found for this customer and store');
    }

    if (Number(sale.debtAmount) <= 0) {
      throw new BadRequestException('This sale has no outstanding debt');
    }

    if (dto.amount > Number(sale.debtAmount)) {
      throw new BadRequestException(
        'Payment amount exceeds the outstanding debt for this sale',
      );
    }

    return this.prisma.$transaction(async (tx) => {
      const payment = await tx.debtPayment.create({
        data: {
          saleId: dto.saleId,
          amount: dto.amount,
          method: dto.method,
          notes: dto.notes,
        },
      });

      await tx.sale.update({
        where: { id: dto.saleId },
        data: {
          debtAmount: {
            decrement: dto.amount,
          },
        },
      });

      await tx.customer.update({
        where: { id: customerId },
        data: {
          debt: {
            decrement: dto.amount,
          },
        },
      });

      // Ensure debt values don't go below 0
      await tx.sale.updateMany({
        where: { id: dto.saleId, debtAmount: { lt: 0 } },
        data: { debtAmount: 0 },
      });

      await tx.customer.updateMany({
        where: { id: customerId, debt: { lt: 0 } },
        data: { debt: 0 },
      });

      return payment;
    });
  }

  async getPayments(storeId: string, customerId: string) {
    await this.findOne(storeId, customerId);

    return this.prisma.debtPayment.findMany({
      where: {
        sale: {
          customerId,
          storeId,
        },
      },
      orderBy: { createdAt: 'desc' },
      include: {
        sale: {
          select: {
            id: true,
            receiptNo: true,
            total: true,
            debtAmount: true,
          },
        },
      },
    });
  }
}
