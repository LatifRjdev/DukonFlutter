import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { CreateExpenseDto } from './dto/create-expense.dto';
import { UpdateExpenseDto } from './dto/update-expense.dto';
import { ExpenseQueryDto } from './dto/expense-query.dto';
import { Prisma } from '@prisma/client';

@Injectable()
export class ExpensesService {
  constructor(private prisma: PrismaService) {}

  async create(storeId: string, dto: CreateExpenseDto) {
    return this.prisma.expense.create({
      data: {
        storeId,
        category: dto.category,
        amount: dto.amount,
        description: dto.description,
        notes: dto.notes,
        receiptUrl: dto.receiptUrl,
        isRecurring: dto.isRecurring,
        recurringDay: dto.recurringDay,
        date: dto.date ? new Date(dto.date) : undefined,
      },
    });
  }

  async findAll(storeId: string, query: ExpenseQueryDto) {
    const where: Prisma.ExpenseWhereInput = { storeId };

    if (query.category) {
      where.category = query.category;
    }

    if (query.startDate || query.endDate) {
      where.date = {};
      if (query.startDate) where.date.gte = new Date(query.startDate);
      if (query.endDate) where.date.lte = new Date(query.endDate);
    }

    if (query.search) {
      where.description = { contains: query.search, mode: 'insensitive' };
    }

    const limit = query.limit || 20;
    const page = query.page || 1;

    const [data, total] = await Promise.all([
      this.prisma.expense.findMany({
        where,
        orderBy: { date: 'desc' },
        skip: query.skip,
        take: limit,
      }),
      this.prisma.expense.count({ where }),
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
    const expense = await this.prisma.expense.findFirst({
      where: { id, storeId },
    });
    if (!expense) throw new NotFoundException('Expense not found');
    return expense;
  }

  async update(storeId: string, id: string, dto: UpdateExpenseDto) {
    await this.findOne(storeId, id);
    return this.prisma.expense.update({
      where: { id },
      data: {
        ...dto,
        date: dto.date ? new Date(dto.date) : undefined,
      },
    });
  }

  async remove(storeId: string, id: string) {
    await this.findOne(storeId, id);
    return this.prisma.expense.delete({ where: { id } });
  }
}
