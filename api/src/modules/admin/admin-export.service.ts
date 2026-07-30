import { Injectable } from '@nestjs/common';
import * as ExcelJS from 'exceljs';
import { Prisma, SubscriptionPlan, SubscriptionStatus } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { AdminUsersQueryDto } from './dto/admin-users-query.dto';
import { AdminStoresQueryDto } from './dto/admin-stores-query.dto';

const EXPORT_ROW_CAP = 10000;

/**
 * Admin-scoped xlsx export — a distinct data shape from
 * `reports/export.service.ts` (which exports one store's own
 * sales/products/customers). This service queries system-wide tables,
 * filtered by the same query params the admin list endpoints already
 * accept. Not paginated — capped at EXPORT_ROW_CAP rows, matching the
 * existing ExportService convention.
 */
@Injectable()
export class AdminExportService {
  constructor(private prisma: PrismaService) {}

  async exportUsers(query: AdminUsersQueryDto): Promise<Buffer> {
    const where: Prisma.UserWhereInput = {};
    if (query.search) {
      where.OR = [
        { name: { contains: query.search, mode: 'insensitive' } },
        { phone: { contains: query.search, mode: 'insensitive' } },
        { email: { contains: query.search, mode: 'insensitive' } },
      ];
    }
    if (query.isAdmin !== undefined) where.isAdmin = query.isAdmin;
    if (query.isActive !== undefined) where.isActive = query.isActive;

    const users = await this.prisma.user.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      take: EXPORT_ROW_CAP,
      select: {
        name: true,
        phone: true,
        email: true,
        isAdmin: true,
        isActive: true,
        createdAt: true,
      },
    });

    const wb = new ExcelJS.Workbook();
    const ws = wb.addWorksheet('Users');
    ws.columns = [
      { header: 'Name', key: 'name', width: 24 },
      { header: 'Phone', key: 'phone', width: 18 },
      { header: 'Email', key: 'email', width: 24 },
      { header: 'Admin', key: 'isAdmin', width: 10 },
      { header: 'Active', key: 'isActive', width: 10 },
      { header: 'Created', key: 'createdAt', width: 20 },
    ];
    for (const u of users) {
      ws.addRow({
        name: u.name ?? '',
        phone: u.phone,
        email: u.email ?? '',
        isAdmin: u.isAdmin,
        isActive: u.isActive,
        createdAt: u.createdAt.toISOString(),
      });
    }

    return Buffer.from(await wb.xlsx.writeBuffer());
  }

  async exportStores(query: AdminStoresQueryDto): Promise<Buffer> {
    const where: Prisma.StoreWhereInput = {};
    if (query.search) {
      where.OR = [
        { name: { contains: query.search, mode: 'insensitive' } },
        { owner: { name: { contains: query.search, mode: 'insensitive' } } },
      ];
    }
    if (query.category) where.category = query.category;
    if (query.isActive !== undefined) where.isActive = query.isActive;
    if (query.plan) where.subscription = { plan: query.plan };

    const stores = await this.prisma.store.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      take: EXPORT_ROW_CAP,
      select: {
        name: true,
        category: true,
        isActive: true,
        createdAt: true,
        owner: { select: { name: true, phone: true } },
        subscription: { select: { plan: true, status: true } },
      },
    });

    const wb = new ExcelJS.Workbook();
    const ws = wb.addWorksheet('Stores');
    ws.columns = [
      { header: 'Name', key: 'name', width: 28 },
      { header: 'Category', key: 'category', width: 16 },
      { header: 'Owner', key: 'ownerName', width: 24 },
      { header: 'Owner phone', key: 'ownerPhone', width: 18 },
      { header: 'Plan', key: 'plan', width: 12 },
      { header: 'Status', key: 'status', width: 12 },
      { header: 'Active', key: 'isActive', width: 10 },
      { header: 'Created', key: 'createdAt', width: 20 },
    ];
    for (const s of stores) {
      ws.addRow({
        name: s.name,
        category: s.category ?? '',
        ownerName: s.owner?.name ?? '',
        ownerPhone: s.owner?.phone ?? '',
        plan: s.subscription?.plan ?? '',
        status: s.subscription?.status ?? '',
        isActive: s.isActive,
        createdAt: s.createdAt.toISOString(),
      });
    }

    return Buffer.from(await wb.xlsx.writeBuffer());
  }

  async exportSubscriptions(filters: {
    plan?: SubscriptionPlan;
    status?: SubscriptionStatus;
  }): Promise<Buffer> {
    const where: Prisma.SubscriptionWhereInput = {};
    if (filters.plan) where.plan = filters.plan;
    if (filters.status) where.status = filters.status;

    const subs = await this.prisma.subscription.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      take: EXPORT_ROW_CAP,
      select: {
        plan: true,
        status: true,
        currentPeriodStart: true,
        currentPeriodEnd: true,
        createdAt: true,
        store: {
          select: {
            name: true,
            owner: { select: { name: true, phone: true } },
          },
        },
      },
    });

    const wb = new ExcelJS.Workbook();
    const ws = wb.addWorksheet('Subscriptions');
    ws.columns = [
      { header: 'Store', key: 'storeName', width: 28 },
      { header: 'Owner', key: 'ownerName', width: 24 },
      { header: 'Owner phone', key: 'ownerPhone', width: 18 },
      { header: 'Plan', key: 'plan', width: 12 },
      { header: 'Status', key: 'status', width: 12 },
      { header: 'Period start', key: 'periodStart', width: 20 },
      { header: 'Period end', key: 'periodEnd', width: 20 },
    ];
    for (const s of subs) {
      ws.addRow({
        storeName: s.store?.name ?? '',
        ownerName: s.store?.owner?.name ?? '',
        ownerPhone: s.store?.owner?.phone ?? '',
        plan: s.plan,
        status: s.status,
        periodStart: s.currentPeriodStart.toISOString(),
        periodEnd: s.currentPeriodEnd.toISOString(),
      });
    }

    return Buffer.from(await wb.xlsx.writeBuffer());
  }
}
