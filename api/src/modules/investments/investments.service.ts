import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { CreateInvestmentDto } from './dto/create-investment.dto';
import { UpdateInvestmentDto } from './dto/update-investment.dto';
import { InvestmentQueryDto } from './dto/investment-query.dto';
import { Prisma } from '@prisma/client';

@Injectable()
export class InvestmentsService {
  constructor(private prisma: PrismaService) {}

  async create(storeId: string, dto: CreateInvestmentDto) {
    return this.prisma.investment.create({
      data: {
        storeId,
        name: dto.name,
        description: dto.description,
        amount: dto.amount,
        returnAmount: dto.returnAmount,
        investorName: dto.investorName,
        investorPhone: dto.investorPhone,
        status: dto.status,
        startDate: new Date(dto.startDate),
        endDate: dto.endDate ? new Date(dto.endDate) : undefined,
      },
    });
  }

  async findAll(storeId: string, query: InvestmentQueryDto) {
    const where: Prisma.InvestmentWhereInput = { storeId };

    if (query.status) {
      where.status = query.status;
    }

    if (query.startDate || query.endDate) {
      where.startDate = {};
      if (query.startDate) where.startDate.gte = new Date(query.startDate);
      if (query.endDate) where.startDate.lte = new Date(query.endDate);
    }

    const limit = query.limit || 20;
    const page = query.page || 1;

    const [data, total] = await Promise.all([
      this.prisma.investment.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: query.skip,
        take: limit,
      }),
      this.prisma.investment.count({ where }),
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
    const investment = await this.prisma.investment.findFirst({
      where: { id, storeId },
    });
    if (!investment) throw new NotFoundException('Investment not found');
    return investment;
  }

  async update(storeId: string, id: string, dto: UpdateInvestmentDto) {
    await this.findOne(storeId, id);
    return this.prisma.investment.update({
      where: { id },
      data: {
        ...dto,
        startDate: dto.startDate ? new Date(dto.startDate) : undefined,
        endDate: dto.endDate ? new Date(dto.endDate) : undefined,
      },
    });
  }

  async remove(storeId: string, id: string) {
    await this.findOne(storeId, id);
    return this.prisma.investment.delete({ where: { id } });
  }

  async summary(storeId: string) {
    const [totals, active, completed] = await Promise.all([
      this.prisma.investment.aggregate({
        where: { storeId },
        _sum: { amount: true },
        _count: true,
      }),
      this.prisma.investment.aggregate({
        where: { storeId, status: 'ACTIVE' },
        _sum: { amount: true },
        _count: true,
      }),
      this.prisma.investment.aggregate({
        where: { storeId, status: 'COMPLETED' },
        _sum: { amount: true, returnAmount: true },
        _count: true,
      }),
    ]);

    return {
      total: {
        amount: totals._sum.amount || 0,
        count: totals._count,
      },
      active: {
        amount: active._sum.amount || 0,
        count: active._count,
      },
      completed: {
        amount: completed._sum.amount || 0,
        returnAmount: completed._sum.returnAmount || 0,
        count: completed._count,
      },
    };
  }
}
