import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { FinanceQueryDto } from './dto/finance-query.dto';
import { BalanceQueryDto, BalancePeriod } from './dto/balance-query.dto';

@Injectable()
export class FinancesService {
  constructor(private prisma: PrismaService) {}

  async getOverview(storeId: string) {
    const startOfToday = new Date();
    startOfToday.setHours(0, 0, 0, 0);

    const [salesAggregate, expensesAggregate, totalProducts, lowStockProducts, recentSales] = await Promise.all([
      this.prisma.sale.aggregate({
        where: {
          storeId,
          status: 'COMPLETED',
          createdAt: { gte: startOfToday },
        },
        _sum: { total: true },
        _count: true,
      }),
      this.prisma.expense.aggregate({
        where: {
          storeId,
          date: { gte: startOfToday },
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
    ]);

    const todayRevenue = Number(salesAggregate._sum.total || 0);
    const todayExpenses = Number(expensesAggregate._sum.amount || 0);

    return {
      todayRevenue,
      todaySalesCount: salesAggregate._count,
      todayProfit: todayRevenue - todayExpenses,
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

    const [salesAggregate, expensesAggregate, salesCount, topProducts, recentSales] = await Promise.all([
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
      // Top products by quantity sold
      this.prisma.saleItem.groupBy({
        by: ['productId', 'productName'],
        where: {
          sale: {
            storeId,
            status: 'COMPLETED',
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
    ]);

    const totalRevenue = Number(salesAggregate._sum.total || 0);
    const totalExpenses = Number(expensesAggregate._sum.amount || 0);
    const averageCheck = Number(salesAggregate._avg.total || 0);
    const profit = totalRevenue - totalExpenses;

    return {
      totalRevenue,
      totalExpenses,
      profit,
      salesCount,
      averageCheck,
      topProducts: topProducts.map(p => ({
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

    return {
      salesByDay,
      expensesByDay,
      expensesByCategory: expensesByCategory.map(e => ({
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
    const endDate = new Date();
    const startDate = new Date();

    switch (query.period) {
      case BalancePeriod.WEEK:
        startDate.setDate(startDate.getDate() - 7);
        break;
      case BalancePeriod.YEAR:
        startDate.setFullYear(startDate.getFullYear() - 1);
        break;
      case BalancePeriod.MONTH:
      default:
        startDate.setMonth(startDate.getMonth() - 1);
        break;
    }
    startDate.setHours(0, 0, 0, 0);

    const [salesAgg, expensesAgg, recentSales, recentExpenses, chartData] = await Promise.all([
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
    ]);

    const income = Number(salesAgg._sum.total ?? 0);
    const expenses = Number(expensesAgg._sum.amount ?? 0);
    const profit = income - expenses;

    // Build recent transactions merged and sorted
    const recentTransactions = [
      ...recentSales.map((s) => ({
        type: 'SALE' as const,
        id: s.id,
        amount: Number(s.total),
        label: `Sale #${s.receiptNo}`,
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
      currentBalance: profit,
      income,
      expenses,
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
    const [customersWithDebt, suppliersWithDebt, totals] = await Promise.all([
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
    ]);

    const [customerTotals, supplierTotals] = totals;

    return {
      receivables: {
        totalAmount: Number(customerTotals._sum.debt ?? 0),
        count: customerTotals._count,
        customers: customersWithDebt.map((c) => ({
          ...c,
          debt: Number(c.debt),
          totalSpent: Number(c.totalSpent),
        })),
      },
      payables: {
        totalAmount: Number(supplierTotals._sum.debt ?? 0),
        count: supplierTotals._count,
        suppliers: suppliersWithDebt.map((s) => ({
          ...s,
          debt: Number(s.debt),
        })),
      },
      netPosition:
        Number(customerTotals._sum.debt ?? 0) -
        Number(supplierTotals._sum.debt ?? 0),
    };
  }

  private getDateRange(query: FinanceQueryDto): { startDate: Date; endDate: Date } {
    if (query.startDate && query.endDate) {
      return {
        startDate: new Date(query.startDate),
        endDate: new Date(query.endDate),
      };
    }

    const endDate = new Date();
    const startDate = new Date();

    switch (query.period) {
      case 'day':
        startDate.setHours(0, 0, 0, 0);
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

    return { startDate, endDate };
  }
}
