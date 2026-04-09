import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { FinanceQueryDto } from './dto/finance-query.dto';

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
