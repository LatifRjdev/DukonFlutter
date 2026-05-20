import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { AuditLogService } from '../../common/audit/audit-log.service';
import { CreateInvestmentDto } from './dto/create-investment.dto';
import { UpdateInvestmentDto } from './dto/update-investment.dto';
import { InvestmentQueryDto } from './dto/investment-query.dto';
import { Prisma } from '@prisma/client';

@Injectable()
export class InvestmentsService {
  constructor(
    private prisma: PrismaService,
    private audit: AuditLogService,
  ) {}

  // Spec D: replay-safe create. If the client retries with the same
  // localId (e.g. after a flaky network), we return the original row
  // instead of inserting a duplicate. Per-store unique constraint on
  // (storeId, localId) is enforced at the DB level.
  async create(storeId: string, dto: CreateInvestmentDto, userId: string) {
    if (dto.localId) {
      const existing = await this.prisma.investment.findUnique({
        where: { storeId_localId: { storeId, localId: dto.localId } },
      });
      if (existing) return existing;
    }

    const created = await this.prisma.investment.create({
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
        localId: dto.localId ?? null,
      },
    });

    // Spec D: audit mutation. AuditLogService swallows its own
    // errors so a logging failure can't roll back the create.
    await this.audit.record(
      userId,
      'investment.create',
      'investment',
      created.id,
      {
        storeId,
        amount: created.amount.toString(),
        name: created.name,
      },
    );

    return created;
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

  // Spec D: wrap existence-check + update in a single $transaction
  // to close the TOCTOU window where a concurrent delete between
  // findFirst and update could update a row that no longer belongs
  // to this store (or no longer exists at all).
  async update(
    storeId: string,
    id: string,
    dto: UpdateInvestmentDto,
    userId: string,
  ) {
    const updated = await this.prisma.$transaction(async (tx) => {
      const existing = await tx.investment.findFirst({
        where: { id, storeId },
      });
      if (!existing) {
        throw new NotFoundException('Investment not found');
      }

      return tx.investment.update({
        where: { id },
        data: {
          ...dto,
          startDate: dto.startDate ? new Date(dto.startDate) : undefined,
          endDate: dto.endDate ? new Date(dto.endDate) : undefined,
        },
      });
    });

    await this.audit.record(userId, 'investment.update', 'investment', id, {
      storeId,
      after: { amount: updated.amount.toString(), status: updated.status },
    });

    return updated;
  }

  // Spec D: same TOCTOU concern as update — wrap check + delete in
  // a $transaction so two racing deletes can't both succeed against
  // a row from another store.
  async remove(storeId: string, id: string, userId: string) {
    const removed = await this.prisma.$transaction(async (tx) => {
      const existing = await tx.investment.findFirst({
        where: { id, storeId },
      });
      if (!existing) {
        throw new NotFoundException('Investment not found');
      }
      await tx.investment.delete({ where: { id } });
      return existing;
    });

    await this.audit.record(userId, 'investment.delete', 'investment', id, {
      storeId,
      amount: removed.amount.toString(),
      name: removed.name,
    });

    return removed;
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
