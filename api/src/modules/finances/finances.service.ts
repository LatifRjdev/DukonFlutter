import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { computeCostOfGoods } from '../../common/finance/cost-of-goods';
import { FinanceQueryDto } from './dto/finance-query.dto';
import { BalanceQueryDto, BalancePeriod } from './dto/balance-query.dto';

@Injectable()
export class FinancesService {
  constructor(private prisma: PrismaService) {}

  async getOverview(storeId: string, query: FinanceQueryDto = {}) {
    // getDateRange() defaults an omitted period to "month" (tuned for
    // getDashboard/getSummary); the home dashboard's default tab is "today".
    const { startDate, endDate } = this.getDateRange({
      ...query,
      period: query.period ?? 'today',
    });

    const [
      salesAggregate,
      expensesAggregate,
      totalProducts,
      lowStockProducts,
      recentSales,
      todayCost,
    ] = await Promise.all([
      this.prisma.sale.aggregate({
        where: {
          storeId,
          status: 'COMPLETED',
          createdAt: { gte: startDate, lte: endDate },
        },
        _sum: { total: true },
        _count: true,
      }),
      this.prisma.expense.aggregate({
        where: {
          storeId,
          date: { gte: startDate, lte: endDate },
        },
        _sum: { amount: true },
      }),
      this.prisma.product.count({
        where: { storeId, isActive: true },
      }),
      this.prisma.$queryRaw<[{ count: bigint }]>`
        SELECT COUNT(*)::bigint as count
        FROM products
        WHERE "storeId" = ${storeId}
          AND "isActive" = true
          AND quantity > 0
          AND quantity <= "minQuantity"
      `,
      this.prisma.sale.findMany({
        where: { storeId },
        orderBy: { createdAt: 'desc' },
        take: 5,
        select: {
          id: true,
          receiptNo: true,
          total: true,
          paymentType: true,
          status: true,
          createdAt: true,
          customer: { select: { name: true } },
        },
      }),
      computeCostOfGoods(this.prisma, storeId, startDate, endDate),
    ]);

    const todayRevenue = Number(salesAggregate._sum.total || 0);
    const todayExpenses = Number(expensesAggregate._sum.amount || 0);

    return {
      todayRevenue,
      todayCost,
      todayExpenses,
      todaySalesCount: salesAggregate._count,
      // Net of BOTH cost of goods and expenses. This previously ignored COGS,
      // which made the dashboard self-contradictory: it showed a profit with
      // expenses already deducted next to an expenses card reading 0.
      todayProfit: todayRevenue - todayCost - todayExpenses,
      totalProducts,
      lowStockProducts: Number(lowStockProducts[0]?.count ?? 0),
      recentSales: recentSales.map((s: any) => ({
        id: s.id,
        receiptNo: s.receiptNo,
        total: Number(s.total),
        paymentType: s.paymentType,
        status: s.status,
        createdAt: s.createdAt,
        customerName: s.customer?.name ?? null,
      })),
    };
  }

  async getDashboard(storeId: string, query: FinanceQueryDto) {
    const { startDate, endDate } = this.getDateRange(query);

    const [
      salesAggregate,
      expensesAggregate,
      salesCount,
      topProducts,
      recentSales,
      cogs,
    ] = await Promise.all([
      // Total revenue from sales
      this.prisma.sale.aggregate({
        where: {
          storeId,
          status: 'COMPLETED',
          createdAt: { gte: startDate, lte: endDate },
        },
        _sum: { total: true },
        _avg: { total: true },
      }),
      // Total expenses
      this.prisma.expense.aggregate({
        where: {
          storeId,
          date: { gte: startDate, lte: endDate },
        },
        _sum: { amount: true },
      }),
      // Sales count
      this.prisma.sale.count({
        where: {
          storeId,
          status: 'COMPLETED',
          createdAt: { gte: startDate, lte: endDate },
        },
      }),
      // F7.2: top-products previously filtered status='COMPLETED' only,
      // which dropped the entire sale row when even one item had been
      // partially refunded. Include PARTIALLY_RETURNED so the original
      // sold quantity is still counted. (Refund quantities aren't yet
      // subtracted line-by-line — follow-up; this fix at least
      // restores the dashboard's intuitive total.)
      this.prisma.saleItem.groupBy({
        by: ['productId', 'productName'],
        where: {
          sale: {
            storeId,
            status: { in: ['COMPLETED', 'PARTIALLY_RETURNED'] },
            createdAt: { gte: startDate, lte: endDate },
          },
        },
        _sum: { quantity: true, total: true },
        orderBy: { _sum: { total: 'desc' } },
        take: 5,
      }),
      // Recent sales
      this.prisma.sale.findMany({
        where: {
          storeId,
          createdAt: { gte: startDate, lte: endDate },
        },
        orderBy: { createdAt: 'desc' },
        take: 10,
        select: {
          id: true,
          receiptNo: true,
          total: true,
          paymentType: true,
          status: true,
          createdAt: true,
        },
      }),
      computeCostOfGoods(this.prisma, storeId, startDate, endDate),
    ]);

    const totalRevenue = Number(salesAggregate._sum.total || 0);
    const totalExpenses = Number(expensesAggregate._sum.amount || 0);
    const averageCheck = Number(salesAggregate._avg.total || 0);
    const profit = totalRevenue - totalExpenses;

    return {
      totalRevenue,
      totalExpenses,
      // The finance screen loads from here on open and from getSummary on a
      // period tap, so both have to carry cogs — otherwise gross profit is
      // wrong until the first tap.
      cogs,
      profit,
      salesCount,
      averageCheck,
      topProducts: topProducts.map((p) => ({
        productId: p.productId,
        productName: p.productName,
        totalQuantity: p._sum.quantity,
        totalRevenue: Number(p._sum.total),
      })),
      recentSales,
      period: query.period || 'month',
      startDate,
      endDate,
    };
  }

  async getSummary(storeId: string, query: FinanceQueryDto) {
    const { startDate, endDate } = this.getDateRange(query);

    // Group sales by day
    const salesByDay = await this.prisma.$queryRaw`
      SELECT
        DATE("createdAt") as date,
        COUNT(*)::int as count,
        COALESCE(SUM(total), 0)::float as revenue
      FROM sales
      WHERE "storeId" = ${storeId}
        AND status = 'COMPLETED'
        AND "createdAt" >= ${startDate}
        AND "createdAt" <= ${endDate}
      GROUP BY DATE("createdAt")
      ORDER BY date ASC
    `;

    // Group expenses by day
    const expensesByDay = await this.prisma.$queryRaw`
      SELECT
        DATE(date) as date,
        COUNT(*)::int as count,
        COALESCE(SUM(amount), 0)::float as total
      FROM expenses
      WHERE "storeId" = ${storeId}
        AND date >= ${startDate}
        AND date <= ${endDate}
      GROUP BY DATE(date)
      ORDER BY date ASC
    `;

    // Expenses by category
    const expensesByCategory = await this.prisma.expense.groupBy({
      by: ['category'],
      where: {
        storeId,
        date: { gte: startDate, lte: endDate },
      },
      _sum: { amount: true },
      _count: true,
    });

    const cogs = await computeCostOfGoods(
      this.prisma,
      storeId,
      startDate,
      endDate,
    );

    return {
      salesByDay,
      expensesByDay,
      cogs,
      expensesByCategory: expensesByCategory.map((e) => ({
        category: e.category,
        total: Number(e._sum.amount || 0),
        count: e._count,
      })),
      period: query.period || 'month',
      startDate,
      endDate,
    };
  }

  async getBalance(storeId: string, query: BalanceQueryDto) {
    // The shared range, so Баланс cannot drift from the screens it is compared
    // against. BalancePeriod's values are the same strings getDateRange reads.
    const { startDate, endDate } = this.getDateRange({
      period: query.period ?? BalancePeriod.MONTH,
    });

    const [salesAgg, expensesAgg, recentSales, recentExpenses, chartData, cogs] =
      await Promise.all([
        this.prisma.sale.aggregate({
          where: {
            storeId,
            status: 'COMPLETED',
            createdAt: { gte: startDate, lte: endDate },
          },
          _sum: { total: true },
        }),
        this.prisma.expense.aggregate({
          where: {
            storeId,
            date: { gte: startDate, lte: endDate },
          },
          _sum: { amount: true },
        }),
        this.prisma.sale.findMany({
          where: { storeId, createdAt: { gte: startDate, lte: endDate } },
          orderBy: { createdAt: 'desc' },
          take: 10,
          select: {
            id: true,
            receiptNo: true,
            total: true,
            paymentType: true,
            status: true,
            createdAt: true,
            customer: { select: { name: true } },
          },
        }),
        this.prisma.expense.findMany({
          where: { storeId, date: { gte: startDate, lte: endDate } },
          orderBy: { date: 'desc' },
          take: 10,
          select: {
            id: true,
            category: true,
            amount: true,
            description: true,
            date: true,
          },
        }),
        this.prisma.$queryRaw<
          { date: Date; income: number; expenses: number }[]
        >`
        SELECT
          day.date,
          COALESCE(s.income, 0) as income,
          COALESCE(e.expenses, 0) as expenses
        FROM (
          SELECT generate_series(
            ${startDate}::date,
            ${endDate}::date,
            '1 day'::interval
          )::date AS date
        ) day
        LEFT JOIN (
          SELECT DATE("createdAt") as date, SUM(total)::float as income
          FROM sales
          WHERE "storeId" = ${storeId}
            AND status = 'COMPLETED'
            AND "createdAt" >= ${startDate}
            AND "createdAt" <= ${endDate}
          GROUP BY DATE("createdAt")
        ) s ON s.date = day.date
        LEFT JOIN (
          SELECT DATE(date) as date, SUM(amount)::float as expenses
          FROM expenses
          WHERE "storeId" = ${storeId}
            AND date >= ${startDate}
            AND date <= ${endDate}
          GROUP BY DATE(date)
        ) e ON e.date = day.date
        ORDER BY day.date ASC
      `,
      computeCostOfGoods(this.prisma, storeId, startDate, endDate),
      ]);

    const income = Number(salesAgg._sum.total ?? 0);
    const expenses = Number(expensesAgg._sum.amount ?? 0);
    // Net of cost of goods, like the dashboard and the profit report. This
    // used to be income - expenses, so Баланс reported 655 where Главная —
    // one tap away, same store, same period — reported 225.
    const profit = income - cogs - expenses;

    // Build recent transactions merged and sorted
    const recentTransactions = [
      ...recentSales.map((s) => ({
        type: 'SALE' as const,
        id: s.id,
        amount: Number(s.total),
        // The app composes the user-visible title from this; it used to be
        // sent as an English literal that rendered verbatim in a Russian UI.
        receiptNo: s.receiptNo,
        customerName: s.customer?.name ?? null,
        paymentType: s.paymentType,
        status: s.status,
        date: s.createdAt,
      })),
      ...recentExpenses.map((e) => ({
        type: 'EXPENSE' as const,
        id: e.id,
        amount: -Number(e.amount),
        label: e.description ?? e.category,
        category: e.category,
        date: e.date,
      })),
    ]
      .sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime())
      .slice(0, 15);

    return {
      // Period revenue less recorded expenses — NOT a cash position, despite
      // the "Текущий баланс" label: `income` counts credit sales in full, and
      // `expenses` holds only manually entered rows, never supplier payments.
      // Deliberately NOT net of cost of goods: PURCHASE is an expense category,
      // so a merchant who books stock purchases there would be double-charged.
      // Only `profit` carries the margin.
      currentBalance: income - expenses,
      income,
      expenses,
      cogs,
      profit,
      period: query.period ?? BalancePeriod.MONTH,
      startDate,
      endDate,
      chartData: chartData.map((row) => ({
        date: row.date,
        income: Number(row.income),
        expenses: Number(row.expenses),
        profit: Number(row.income) - Number(row.expenses),
      })),
      recentTransactions,
    };
  }

  async getCreditsSummary(storeId: string) {
    const [customersWithDebt, suppliersWithDebt, totals, lastPayments] =
      await Promise.all([
      // Receivables: customers who owe the store
      this.prisma.customer.findMany({
        where: { storeId, debt: { gt: 0 } },
        orderBy: { debt: 'desc' },
        select: {
          id: true,
          name: true,
          phone: true,
          debt: true,
          totalSpent: true,
        },
      }),
      // Payables: suppliers the store owes
      this.prisma.supplier.findMany({
        where: { storeId, debt: { gt: 0 } },
        orderBy: { debt: 'desc' },
        select: {
          id: true,
          name: true,
          phone: true,
          debt: true,
        },
      }),
      // Aggregate totals
      Promise.all([
        this.prisma.customer.aggregate({
          where: { storeId, debt: { gt: 0 } },
          _sum: { debt: true },
          _count: true,
        }),
        this.prisma.supplier.aggregate({
          where: { storeId, debt: { gt: 0 } },
          _sum: { debt: true },
          _count: true,
        }),
      ]),
      // Most recent payment per counterparty. The Кредиты screen has always
      // had a "last payment" line; nothing ever filled it. A DebtPayment hangs
      // off a sale rather than a customer, so receivables need the join.
      Promise.all([
        this.prisma.$queryRaw<{ id: string; last: Date }[]>`
          SELECT s."customerId" AS id, MAX(dp."createdAt") AS last
          FROM debt_payments dp
          JOIN sales s ON s.id = dp."saleId"
          WHERE s."storeId" = ${storeId} AND s."customerId" IS NOT NULL
          GROUP BY s."customerId"
        `,
        this.prisma.supplierPayment.groupBy({
          by: ['supplierId'],
          where: { storeId },
          _max: { createdAt: true },
        }),
      ]),
    ]);

    const [customerTotals, supplierTotals] = totals;
    const [customerLastPayments, supplierLastPayments] = lastPayments;
    const lastPaidByCustomer = new Map(
      customerLastPayments.map((r) => [r.id, r.last]),
    );
    const lastPaidBySupplier = new Map(
      supplierLastPayments.map((r) => [r.supplierId, r._max.createdAt]),
    );

    return {
      receivables: {
        totalAmount: Number(customerTotals._sum.debt ?? 0),
        count: customerTotals._count,
        customers: customersWithDebt.map((c) => ({
          ...c,
          debt: Number(c.debt),
          totalSpent: Number(c.totalSpent),
          lastPayment: lastPaidByCustomer.get(c.id) ?? null,
        })),
      },
      payables: {
        totalAmount: Number(supplierTotals._sum.debt ?? 0),
        count: supplierTotals._count,
        suppliers: suppliersWithDebt.map((s) => ({
          ...s,
          debt: Number(s.debt),
          lastPayment: lastPaidBySupplier.get(s.id) ?? null,
        })),
      },
      netPosition:
        Number(customerTotals._sum.debt ?? 0) -
        Number(supplierTotals._sum.debt ?? 0),
    };
  }

  private getDateRange(query: FinanceQueryDto): {
    startDate: Date;
    endDate: Date;
  } {
    if (query.startDate && query.endDate) {
      return {
        startDate: new Date(query.startDate),
        endDate: new Date(query.endDate),
      };
    }

    const endDate = new Date();
    const startDate = new Date();

    switch (query.period) {
      case 'today':
      case 'day':
        // No adjustment: the window starts today. Deleting this group would
        // drop 'today' into default: (a month) and break the home screen.
        break;
      case 'week':
        startDate.setDate(startDate.getDate() - 7);
        break;
      case 'year':
        startDate.setFullYear(startDate.getFullYear() - 1);
        break;
      case 'month':
      default:
        startDate.setMonth(startDate.getMonth() - 1);
        break;
    }
    // Whole days for every period, not just today. Without this, "Месяц" meant
    // "since this time of day a month ago", so the window slid through the day
    // and a sale from exactly a month ago silently dropped out as the clock
    // advanced. getBalance already zeroed the hours, which is why Баланс and
    // Главная could disagree at the edge of a period.
    startDate.setHours(0, 0, 0, 0);

    return { startDate, endDate };
  }
}
