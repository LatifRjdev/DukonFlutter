import {
  Injectable,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { CalculatePayrollDto } from './dto/calculate-payroll.dto';
import { CreateAdjustmentDto } from './dto/create-adjustment.dto';

@Injectable()
export class PayrollService {
  constructor(private prisma: PrismaService) {}

  async calculate(storeId: string, dto: CalculatePayrollDto) {
    const { month, year } = dto;

    // 1. FindOrCreate PayrollPeriod
    let period = await this.prisma.payrollPeriod.findFirst({
      where: { storeId, month, year },
    });

    if (!period) {
      period = await this.prisma.payrollPeriod.create({
        data: {
          storeId,
          month,
          year,
          status: 'DRAFT',
          totalAmount: 0,
          paidAmount: 0,
        },
      });
    }

    // 2. Get all active staff in store
    const staffList = await this.prisma.staff.findMany({
      where: { storeId, isActive: true },
      include: { user: { select: { name: true, phone: true, avatar: true } } },
    });

    // Date range for the month
    const startDate = new Date(year, month - 1, 1);
    const endDate = new Date(year, month, 1);

    for (const staff of staffList) {
      const baseSalary = Number(staff.salary) || 0;
      const commissionRate = Number(staff.commission) || 0;

      // Count closed shifts in the month
      const shiftsWorked = await this.prisma.shift.count({
        where: {
          staffId: staff.id,
          status: 'CLOSED',
          openedAt: { gte: startDate, lt: endDate },
        },
      });

      // Sum sales total by staffId in the month
      const salesAgg = await this.prisma.sale.aggregate({
        where: {
          staffId: staff.id,
          storeId,
          createdAt: { gte: startDate, lt: endDate },
        },
        _sum: { total: true },
      });

      const salesTotal = Number(salesAgg._sum.total) || 0;
      const commission = (salesTotal * commissionRate) / 100;

      // Get existing adjustments for this payroll (if any)
      const existingPayroll = await this.prisma.payroll.findFirst({
        where: { payrollPeriodId: period.id, staffId: staff.id },
        include: { adjustments: true },
      });

      let bonuses = 0;
      let deductions = 0;

      if (existingPayroll) {
        for (const adj of existingPayroll.adjustments) {
          if (adj.type === 'BONUS') bonuses += Number(adj.amount);
          else deductions += Number(adj.amount);
        }
      }

      const totalAmount = baseSalary + commission + bonuses - deductions;

      // 3. Upsert Payroll record
      await this.prisma.payroll.upsert({
        where: {
          payrollPeriodId_staffId: {
            payrollPeriodId: period.id,
            staffId: staff.id,
          },
        },
        create: {
          payrollPeriodId: period.id,
          staffId: staff.id,
          baseSalary,
          commission,
          commissionRate,
          salesTotal,
          shiftsWorked,
          shiftsExpected: 26,
          totalAmount,
          isPaid: false,
        },
        update: {
          baseSalary,
          commission,
          commissionRate,
          salesTotal,
          shiftsWorked,
          totalAmount,
        },
      });
    }

    // 4. Update PayrollPeriod totalAmount and status
    const payrolls = await this.prisma.payroll.findMany({
      where: { payrollPeriodId: period.id },
    });

    const totalAmount = payrolls.reduce(
      (sum, p) => sum + Number(p.totalAmount),
      0,
    );
    const paidAmount = payrolls
      .filter((p) => p.isPaid)
      .reduce((sum, p) => sum + Number(p.totalAmount), 0);

    period = await this.prisma.payrollPeriod.update({
      where: { id: period.id },
      data: { totalAmount, paidAmount, status: 'CALCULATED' },
    });

    // 5. Return full period with payrolls
    return this.findOne(storeId, period.id);
  }

  async findAll(storeId: string) {
    return this.prisma.payrollPeriod.findMany({
      where: { storeId },
      orderBy: [{ year: 'desc' }, { month: 'desc' }],
      include: {
        _count: { select: { payrolls: true } },
      },
    });
  }

  async findOne(storeId: string, periodId: string) {
    return this.findOneWithClient(this.prisma, storeId, periodId);
  }

  // Shared query shape for findOne, usable with either the outer `this.prisma`
  // client or a `tx` transaction client. Using `tx` here (from inside an
  // active $transaction) ensures the read sees the transaction's own
  // uncommitted writes instead of a stale pre-mutation snapshot from a
  // separate connection/context.
  private async findOneWithClient(
    client: any,
    storeId: string,
    periodId: string,
  ) {
    const period = await client.payrollPeriod.findFirst({
      where: { id: periodId, storeId },
      include: {
        payrolls: {
          include: {
            staff: {
              include: {
                user: { select: { name: true, phone: true, avatar: true } },
              },
            },
            adjustments: {
              orderBy: { date: 'desc' },
            },
          },
          orderBy: { totalAmount: 'desc' },
        },
      },
    });

    if (!period) throw new NotFoundException('Payroll period not found');
    return period;
  }

  async addAdjustment(
    storeId: string,
    periodId: string,
    dto: CreateAdjustmentDto,
  ) {
    const period = await this.prisma.payrollPeriod.findFirst({
      where: { id: periodId, storeId },
    });
    if (!period) throw new NotFoundException('Payroll period not found');

    const payroll = await this.prisma.payroll.findFirst({
      where: { payrollPeriodId: periodId, staffId: dto.staffId },
    });
    if (!payroll)
      throw new NotFoundException('Payroll record not found for this staff');

    return this.prisma.$transaction(async (tx) => {
      const adjustment = await tx.payrollAdjustment.create({
        data: {
          payrollId: payroll.id,
          type: dto.type,
          amount: dto.amount,
          description: dto.description,
          date: dto.date ? new Date(dto.date) : new Date(),
        },
      });

      // Recalculate payroll totalAmount
      await this.recalculatePayroll(tx, payroll.id);
      await this.recalculatePeriod(tx, periodId);

      return adjustment;
    });
  }

  async removeAdjustment(
    storeId: string,
    periodId: string,
    adjustmentId: string,
  ) {
    const period = await this.prisma.payrollPeriod.findFirst({
      where: { id: periodId, storeId },
    });
    if (!period) throw new NotFoundException('Payroll period not found');

    const adjustment = await this.prisma.payrollAdjustment.findFirst({
      where: { id: adjustmentId, payroll: { payrollPeriodId: periodId } },
    });
    if (!adjustment) throw new NotFoundException('Adjustment not found');

    return this.prisma.$transaction(async (tx) => {
      await tx.payrollAdjustment.delete({ where: { id: adjustmentId } });

      // Recalculate payroll totalAmount
      await this.recalculatePayroll(tx, adjustment.payrollId);
      await this.recalculatePeriod(tx, periodId);

      return { message: 'Adjustment deleted successfully' };
    });
  }

  async payOne(storeId: string, periodId: string, payrollId: string) {
    const period = await this.prisma.payrollPeriod.findFirst({
      where: { id: periodId, storeId },
    });
    if (!period) throw new NotFoundException('Payroll period not found');

    const payroll = await this.prisma.payroll.findFirst({
      where: { id: payrollId, payrollPeriodId: periodId },
    });
    if (!payroll) throw new NotFoundException('Payroll record not found');

    if (payroll.isPaid) throw new BadRequestException('Payroll already paid');

    return this.prisma.$transaction(async (tx) => {
      await tx.payroll.update({
        where: { id: payrollId },
        data: { isPaid: true, paidAt: new Date() },
      });

      await this.recalculatePeriod(tx, periodId);

      return this.findOneWithClient(tx, storeId, periodId);
    });
  }

  async payAll(storeId: string, periodId: string) {
    const period = await this.prisma.payrollPeriod.findFirst({
      where: { id: periodId, storeId },
    });
    if (!period) throw new NotFoundException('Payroll period not found');

    return this.prisma.$transaction(async (tx) => {
      await tx.payroll.updateMany({
        where: { payrollPeriodId: periodId, isPaid: false },
        data: { isPaid: true, paidAt: new Date() },
      });

      const payrolls = await tx.payroll.findMany({
        where: { payrollPeriodId: periodId },
      });

      const totalAmount = payrolls.reduce(
        (sum, p) => sum + Number(p.totalAmount),
        0,
      );

      await tx.payrollPeriod.update({
        where: { id: periodId },
        data: { paidAmount: totalAmount, status: 'PAID' },
      });

      return this.findOneWithClient(tx, storeId, periodId);
    });
  }

  private async recalculatePayroll(tx: any, payrollId: string) {
    const payroll = await tx.payroll.findUnique({
      where: { id: payrollId },
      include: { adjustments: true },
    });

    let bonuses = 0;
    let deductions = 0;

    for (const adj of payroll.adjustments) {
      if (adj.type === 'BONUS') bonuses += Number(adj.amount);
      else deductions += Number(adj.amount);
    }

    const totalAmount =
      Number(payroll.baseSalary) +
      Number(payroll.commission) +
      bonuses -
      deductions;

    await tx.payroll.update({
      where: { id: payrollId },
      data: { totalAmount },
    });
  }

  private async recalculatePeriod(tx: any, periodId: string) {
    const payrolls = await tx.payroll.findMany({
      where: { payrollPeriodId: periodId },
    });

    const totalAmount = payrolls.reduce(
      (sum: number, p: any) => sum + Number(p.totalAmount),
      0,
    );
    const paidAmount = payrolls
      .filter((p: any) => p.isPaid)
      .reduce((sum: number, p: any) => sum + Number(p.totalAmount), 0);

    const allPaid = payrolls.length > 0 && payrolls.every((p: any) => p.isPaid);
    const somePaid = payrolls.some((p: any) => p.isPaid);

    let status = 'CALCULATED';
    if (allPaid) status = 'PAID';
    else if (somePaid) status = 'PARTIALLY_PAID';

    await tx.payrollPeriod.update({
      where: { id: periodId },
      data: { totalAmount, paidAmount, status },
    });
  }
}
