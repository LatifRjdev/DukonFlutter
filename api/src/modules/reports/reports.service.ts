import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { ReportQueryDto } from './dto/report-query.dto';

@Injectable()
export class ReportsService {
  constructor(private prisma: PrismaService) {}

  private getDateRange(query: ReportQueryDto): {
    startDate: Date;
    endDate: Date;
  } {
    const startDate = query.from
      ? new Date(query.from)
      : new Date(new Date().setDate(1));
    const endDate = query.to ? new Date(query.to) : new Date();
    startDate.setHours(0, 0, 0, 0);
    endDate.setHours(23, 59, 59, 999);
    return { startDate, endDate };
  }

  async getSalesReport(storeId: string, query: ReportQueryDto) {
    const { startDate, endDate } = this.getDateRange(query);

    const [salesByDate, topProducts, totals] = await Promise.all([
      this.prisma.$queryRaw<
        { date: Date; count: bigint; revenue: number; avg_check: number }[]
      >`
        SELECT
          DATE("createdAt") as date,
          COUNT(*)::bigint as count,
          COALESCE(SUM(total), 0)::float as revenue,
          COALESCE(AVG(total), 0)::float as avg_check
        FROM sales
        WHERE "storeId" = ${storeId}
          AND status = 'COMPLETED'
          AND "createdAt" >= ${startDate}
          AND "createdAt" <= ${endDate}
        GROUP BY DATE("createdAt")
        ORDER BY date ASC
      `,

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

      this.prisma.sale.aggregate({
        where: {
          storeId,
          status: 'COMPLETED',
          createdAt: { gte: startDate, lte: endDate },
        },
        _sum: { total: true },
        _avg: { total: true },
        _count: true,
      }),
    ]);

    return {
      byDate: salesByDate.map((row) => ({
        date: row.date,
        count: Number(row.count),
        revenue: Number(row.revenue),
        avgCheck: Number(row.avg_check),
      })),
      topProducts: topProducts.map((p) => ({
        productId: p.productId,
        productName: p.productName,
        totalQty: p._sum.quantity ?? 0,
        totalRevenue: Number(p._sum.total ?? 0),
      })),
      totalRevenue: Number(totals._sum.total ?? 0),
      totalCount: totals._count,
      avgCheck: Number(totals._avg.total ?? 0),
      from: startDate,
      to: endDate,
    };
  }

  async getProfitReport(storeId: string, query: ReportQueryDto) {
    const { startDate, endDate } = this.getDateRange(query);

    const [salesAgg, expensesAgg, cogsResult] = await Promise.all([
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
      // Cost of goods sold: sum(SaleItem.costPrice * quantity) for
      // completed sales in the period. Same COMPLETED-only scoping as
      // every other report query in this file (see getSalesReport /
      // getProductsReport). costPrice is nullable on SaleItem (older
      // rows / items added before cost tracking); those contribute 0.
      this.prisma.$queryRaw<{ cogs: number }[]>`
        SELECT COALESCE(SUM(si.quantity * si."costPrice"), 0)::float as cogs
        FROM sale_items si
        JOIN sales s ON s.id = si."saleId"
        WHERE s."storeId" = ${storeId}
          AND s.status = 'COMPLETED'
          AND s."createdAt" >= ${startDate}
          AND s."createdAt" <= ${endDate}
      `,
    ]);

    const income = Number(salesAgg._sum.total ?? 0);
    const expenses = Number(expensesAgg._sum.amount ?? 0);
    const cogs = Number(cogsResult[0]?.cogs ?? 0);
    // grossProfit: revenue minus cost of the goods actually sold.
    // profit (net): gross profit minus manually-entered operating
    // expenses. `profit` previously ignored COGS entirely, which made
    // margin read as ~100% for any store that didn't log manual
    // expenses even though it had real cost of goods sold — this is
    // the fix for that. `profit` now means true net profit; `cogs` and
    // `grossProfit` are added so consumers can see the breakdown.
    const grossProfit = income - cogs;
    const profit = grossProfit - expenses;
    const margin = income > 0 ? (profit / income) * 100 : 0;

    return {
      income,
      expenses,
      cogs,
      grossProfit,
      profit,
      marginPercent: parseFloat(margin.toFixed(2)),
      from: startDate,
      to: endDate,
    };
  }

  async getProductsReport(storeId: string, query: ReportQueryDto) {
    const { startDate, endDate } = this.getDateRange(query);
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    const [topByQty, topByRevenue, stockValue] = await Promise.all([
      // Top sellers by quantity
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
        orderBy: { _sum: { quantity: 'desc' } },
        take: 10,
      }),

      // Top sellers by revenue
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
        take: 10,
      }),

      // Total stock value
      this.prisma.$queryRaw<{ total_value: number }[]>`
        SELECT COALESCE(SUM(quantity * "costPrice"), 0)::float as total_value
        FROM products
        WHERE "storeId" = ${storeId}
          AND "isActive" = true
          AND "costPrice" IS NOT NULL
      `,
    ]);

    // Dead stock: active products not sold in 30+ days
    const soldProductIds = await this.prisma.saleItem.findMany({
      where: {
        sale: {
          storeId,
          status: 'COMPLETED',
          createdAt: { gte: thirtyDaysAgo },
        },
      },
      select: { productId: true },
      distinct: ['productId'],
    });
    const soldIds = soldProductIds.map((s) => s.productId);

    const deadStock = await this.prisma.product.findMany({
      where: {
        storeId,
        isActive: true,
        quantity: { gt: 0 },
        id: { notIn: soldIds.length > 0 ? soldIds : ['__none__'] },
      },
      select: {
        id: true,
        name: true,
        sku: true,
        quantity: true,
        sellPrice: true,
        costPrice: true,
      },
      take: 20,
    });

    return {
      topByQuantity: topByQty.map((p) => ({
        productId: p.productId,
        productName: p.productName,
        totalQty: p._sum.quantity ?? 0,
        totalRevenue: Number(p._sum.total ?? 0),
      })),
      topByRevenue: topByRevenue.map((p) => ({
        productId: p.productId,
        productName: p.productName,
        totalQty: p._sum.quantity ?? 0,
        totalRevenue: Number(p._sum.total ?? 0),
      })),
      deadStock: deadStock.map((p) => ({
        ...p,
        sellPrice: Number(p.sellPrice),
        costPrice: p.costPrice ? Number(p.costPrice) : null,
      })),
      totalStockValue: Number(stockValue[0]?.total_value ?? 0),
      from: startDate,
      to: endDate,
    };
  }

  async getStaffReport(storeId: string, query: ReportQueryDto) {
    const { startDate, endDate } = this.getDateRange(query);

    const salesByStaff = await this.prisma.sale.groupBy({
      by: ['staffId'],
      where: {
        storeId,
        status: 'COMPLETED',
        staffId: { not: null },
        createdAt: { gte: startDate, lte: endDate },
      },
      _sum: { total: true },
      _avg: { total: true },
      _count: true,
    });

    const staffIds = salesByStaff
      .map((s) => s.staffId)
      .filter((id): id is string => id !== null);

    const staffDetails = await this.prisma.staff.findMany({
      where: { id: { in: staffIds } },
      select: {
        id: true,
        role: true,
        user: { select: { name: true } },
      },
    });

    const staffMap = new Map(staffDetails.map((s) => [s.id, s]));

    return {
      byStaff: salesByStaff.map((s) => {
        const staff = staffMap.get(s.staffId!);
        return {
          staffId: s.staffId,
          staffName: staff?.user?.name ?? 'Unknown',
          role: staff?.role ?? null,
          salesCount: s._count,
          totalRevenue: Number(s._sum.total ?? 0),
          avgCheck: Number(s._avg.total ?? 0),
        };
      }),
      from: startDate,
      to: endDate,
    };
  }
}
