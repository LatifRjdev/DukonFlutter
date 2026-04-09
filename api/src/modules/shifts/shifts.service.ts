import {
  Injectable,
  NotFoundException,
  ConflictException,
  BadRequestException,
} from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { OpenShiftDto } from './dto/open-shift.dto';
import { CloseShiftDto } from './dto/close-shift.dto';
import { Prisma } from '@prisma/client';

@Injectable()
export class ShiftsService {
  constructor(private prisma: PrismaService) {}

  /**
   * Resolve the Staff record for the current user in the given store.
   * Store owners may not have a Staff record, so we also check ownership.
   */
  private async getStaffId(storeId: string, userId: string): Promise<string> {
    const staff = await this.prisma.staff.findUnique({
      where: { storeId_userId: { storeId, userId } },
      select: { id: true, isActive: true },
    });

    if (!staff || !staff.isActive) {
      throw new BadRequestException(
        'You do not have an active staff record in this store',
      );
    }

    return staff.id;
  }

  async openShift(storeId: string, userId: string, dto: OpenShiftDto) {
    const staffId = await this.getStaffId(storeId, userId);

    // Check no active shift exists for this staff
    const activeShift = await this.prisma.shift.findFirst({
      where: { storeId, staffId, status: 'OPEN' },
    });

    if (activeShift) {
      throw new ConflictException(
        'You already have an active shift. Close it before opening a new one.',
      );
    }

    return this.prisma.shift.create({
      data: {
        storeId,
        staffId,
        openingCash: dto.openingCash,
        status: 'OPEN',
      },
      include: {
        staff: {
          include: { user: { select: { id: true, name: true } } },
        },
      },
    });
  }

  async closeShift(storeId: string, shiftId: string, userId: string, dto: CloseShiftDto) {
    const staffId = await this.getStaffId(storeId, userId);

    const shift = await this.prisma.shift.findFirst({
      where: { id: shiftId, storeId, staffId, status: 'OPEN' },
    });

    if (!shift) {
      throw new NotFoundException(
        'Active shift not found. It may be already closed or does not belong to you.',
      );
    }

    // Aggregate sales within this shift
    const completedSales = await this.prisma.sale.findMany({
      where: { shiftId, status: 'COMPLETED' },
      select: { total: true, paymentType: true },
    });

    const returnedSales = await this.prisma.sale.findMany({
      where: { shiftId, status: { in: ['RETURNED', 'PARTIALLY_RETURNED'] } },
      select: { total: true },
    });

    let salesTotal = new Prisma.Decimal(0);
    let cashSales = new Prisma.Decimal(0);
    let cardSales = new Prisma.Decimal(0);
    let debtSales = new Prisma.Decimal(0);
    const salesCount = completedSales.length;

    for (const sale of completedSales) {
      salesTotal = salesTotal.add(sale.total);
      if (sale.paymentType === 'CASH') {
        cashSales = cashSales.add(sale.total);
      } else if (sale.paymentType === 'CARD') {
        cardSales = cardSales.add(sale.total);
      } else if (sale.paymentType === 'DEBT') {
        debtSales = debtSales.add(sale.total);
      } else if (sale.paymentType === 'MIXED') {
        // For MIXED payments, count toward cash (conservative approach)
        cashSales = cashSales.add(sale.total);
      }
    }

    let returnsTotal = new Prisma.Decimal(0);
    const returnsCount = returnedSales.length;
    for (const ret of returnedSales) {
      returnsTotal = returnsTotal.add(ret.total);
    }

    const openingCash = shift.openingCash;
    const cashWithdrawals = shift.cashWithdrawals;
    const expectedCash = openingCash
      .add(cashSales)
      .sub(returnsTotal)
      .sub(cashWithdrawals);

    const closingCash = new Prisma.Decimal(dto.closingCash);
    const difference = closingCash.sub(expectedCash);

    return this.prisma.shift.update({
      where: { id: shiftId },
      data: {
        closedAt: new Date(),
        closingCash: dto.closingCash,
        salesTotal,
        salesCount,
        cashSales,
        cardSales,
        debtSales,
        returnsTotal,
        returnsCount,
        expectedCash,
        difference,
        status: 'CLOSED',
      },
      include: {
        staff: {
          include: { user: { select: { id: true, name: true } } },
        },
      },
    });
  }

  async findCurrent(storeId: string, userId: string) {
    const staffId = await this.getStaffId(storeId, userId);

    const shift = await this.prisma.shift.findFirst({
      where: { storeId, staffId, status: 'OPEN' },
      include: {
        staff: {
          include: { user: { select: { id: true, name: true } } },
        },
      },
    });

    if (!shift) {
      throw new NotFoundException('No active shift found');
    }

    return shift;
  }

  async findAll(
    storeId: string,
    page = 1,
    limit = 20,
    staffId?: string,
    dateFrom?: string,
    dateTo?: string,
  ) {
    const where: Prisma.ShiftWhereInput = { storeId };

    if (staffId) {
      where.staffId = staffId;
    }

    if (dateFrom || dateTo) {
      where.openedAt = {};
      if (dateFrom) {
        where.openedAt.gte = new Date(dateFrom);
      }
      if (dateTo) {
        where.openedAt.lte = new Date(dateTo);
      }
    }

    const [data, total] = await Promise.all([
      this.prisma.shift.findMany({
        where,
        orderBy: { openedAt: 'desc' },
        skip: (page - 1) * limit,
        take: limit,
        include: {
          staff: {
            include: { user: { select: { id: true, name: true } } },
          },
        },
      }),
      this.prisma.shift.count({ where }),
    ]);

    return { data, total, page, limit, totalPages: Math.ceil(total / limit) };
  }

  async findOne(storeId: string, shiftId: string) {
    const shift = await this.prisma.shift.findFirst({
      where: { id: shiftId, storeId },
      include: {
        staff: {
          include: { user: { select: { id: true, name: true } } },
        },
      },
    });

    if (!shift) {
      throw new NotFoundException('Shift not found');
    }

    return shift;
  }

  async getZReport(storeId: string, shiftId: string) {
    const shift = await this.prisma.shift.findFirst({
      where: { id: shiftId, storeId },
      include: {
        staff: {
          include: { user: { select: { id: true, name: true } } },
        },
      },
    });

    if (!shift) {
      throw new NotFoundException('Shift not found');
    }

    // Sales breakdown
    const completedSales = await this.prisma.sale.findMany({
      where: { shiftId, status: 'COMPLETED' },
      select: { total: true, paymentType: true },
    });

    let cashTotal = new Prisma.Decimal(0);
    let cardTotal = new Prisma.Decimal(0);
    let debtTotal = new Prisma.Decimal(0);
    let salesGrandTotal = new Prisma.Decimal(0);

    for (const sale of completedSales) {
      salesGrandTotal = salesGrandTotal.add(sale.total);
      if (sale.paymentType === 'CASH') {
        cashTotal = cashTotal.add(sale.total);
      } else if (sale.paymentType === 'CARD') {
        cardTotal = cardTotal.add(sale.total);
      } else if (sale.paymentType === 'DEBT') {
        debtTotal = debtTotal.add(sale.total);
      } else if (sale.paymentType === 'MIXED') {
        cashTotal = cashTotal.add(sale.total);
      }
    }

    // Returns breakdown
    const returnedSales = await this.prisma.sale.findMany({
      where: { shiftId, status: { in: ['RETURNED', 'PARTIALLY_RETURNED'] } },
      select: { total: true },
    });

    let returnsGrandTotal = new Prisma.Decimal(0);
    for (const ret of returnedSales) {
      returnsGrandTotal = returnsGrandTotal.add(ret.total);
    }

    // Top 3 products by quantity sold in this shift
    const topProducts = await this.prisma.saleItem.groupBy({
      by: ['productId', 'productName'],
      where: {
        sale: { shiftId, status: 'COMPLETED' },
      },
      _sum: { quantity: true, total: true },
      orderBy: { _sum: { quantity: 'desc' } },
      take: 3,
    });

    const openingCash = shift.openingCash;
    const cashWithdrawals = shift.cashWithdrawals;
    const expectedCash = openingCash
      .add(cashTotal)
      .sub(returnsGrandTotal)
      .sub(cashWithdrawals);

    return {
      shift: {
        id: shift.id,
        storeId: shift.storeId,
        staffId: shift.staffId,
        staffName: shift.staff?.user?.name,
        openedAt: shift.openedAt,
        closedAt: shift.closedAt,
        status: shift.status,
        notes: shift.notes,
      },
      sales: {
        cashTotal,
        cardTotal,
        debtTotal,
        total: salesGrandTotal,
        count: completedSales.length,
      },
      returns: {
        count: returnedSales.length,
        total: returnsGrandTotal,
      },
      cashDrawer: {
        opening: openingCash,
        cashSales: cashTotal,
        cashReturns: new Prisma.Decimal(0),
        withdrawals: cashWithdrawals,
        expected: expectedCash,
        actual: shift.closingCash,
        difference: shift.difference,
      },
      topProducts: topProducts.map((p) => ({
        productId: p.productId,
        productName: p.productName,
        quantitySold: p._sum.quantity,
        totalRevenue: p._sum.total,
      })),
    };
  }
}
