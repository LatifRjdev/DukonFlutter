import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ConflictException,
} from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import * as crypto from 'crypto';
import { PrismaService } from '../../prisma/prisma.service';
import { AdminUsersQueryDto } from './dto/admin-users-query.dto';
import { AdminStoresQueryDto } from './dto/admin-stores-query.dto';
import { TransferStoreDto } from './dto/transfer-store.dto';
import { CreateAnnouncementDto } from './dto/create-announcement.dto';
import { UpdatePlanDto } from './dto/update-plan.dto';
import { AdminAuditLogQueryDto } from './dto/admin-audit-log-query.dto';
import { RevenueQueryDto, ReportPeriod } from './dto/revenue-query.dto';
import { AnnouncementsQueryDto } from './dto/announcements-query.dto';
import { CreateUserByAdminDto } from './dto/create-user-by-admin.dto';
import { SendDirectNotificationDto } from './dto/send-direct-notification.dto';
import { NotificationsService } from '../notifications/notifications.service';
import { StoresService } from '../stores/stores.service';
import { Prisma, SubscriptionPlan, SubscriptionStatus } from '@prisma/client';
import { renderTemplate, AnnouncementVars } from './announcements-template';

@Injectable()
export class AdminService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
    private readonly storesService: StoresService,
  ) {}

  // ============ USERS ============

  async listUsers(query: AdminUsersQueryDto) {
    const page = query.page ?? 1;
    const limit = query.limit ?? 20;
    const skip = (page - 1) * limit;

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

    const [data, total] = await Promise.all([
      this.prisma.user.findMany({
        where,
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
        select: {
          id: true,
          phone: true,
          name: true,
          email: true,
          isAdmin: true,
          isActive: true,
          createdAt: true,
          _count: { select: { ownedStores: true } },
        },
      }),
      this.prisma.user.count({ where }),
    ]);

    return { data, total, page, limit };
  }

  async createUserManually(dto: CreateUserByAdminDto) {
    const existing = await this.prisma.user.findUnique({
      where: { phone: dto.phone },
    });
    if (existing) {
      throw new ConflictException('User with this phone already exists');
    }

    const passwordWasGenerated = !dto.password;
    const rawPassword = dto.password ?? this.generateRandomPassword();
    const hashedPassword = await bcrypt.hash(rawPassword, 12);

    const { user, store } = await this.prisma.$transaction(async (tx) => {
      const createdUser = await tx.user.create({
        data: {
          phone: dto.phone,
          password: hashedPassword,
          name: dto.name,
          email: dto.email,
        },
      });

      let createdStore: { id: string; name: string } | null = null;
      if (dto.createStore) {
        const storeResult = await this.storesService.create(
          createdUser.id,
          {
            name: dto.storeName!,
            category: dto.storeCategory!,
            currency: dto.storeCurrency,
            address: dto.storeAddress,
            phone: dto.storePhone,
          },
          tx,
        );
        createdStore = { id: storeResult.id, name: storeResult.name };
      }

      return { user: createdUser, store: createdStore };
    });

    return {
      user: {
        id: user.id,
        phone: user.phone,
        name: user.name,
        email: user.email,
        isAdmin: user.isAdmin,
      },
      store,
      generatedPassword: passwordWasGenerated ? rawPassword : null,
    };
  }

  // Used only when the admin leaves the password field blank — generates
  // a password that trivially satisfies IsStrongPassword (length >= 8,
  // not a common password, doesn't match phone/email) without needing
  // any coordination with that validator. 16 chars from a mixed
  // alphanumeric+symbol set is far above the minimum bar on purpose:
  // this password is shown to the admin once and handed to the end user,
  // it's never chosen or memorized by a human, so there's no usability
  // cost to making it long.
  private generateRandomPassword(): string {
    const chars =
      'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#$%';
    const bytes = crypto.randomBytes(16);
    let password = '';
    for (let i = 0; i < 16; i++) {
      password += chars[bytes[i] % chars.length];
    }
    return password;
  }

  async getUserDetail(id: string) {
    const user = await this.prisma.user.findUnique({
      where: { id },
      select: {
        id: true,
        phone: true,
        name: true,
        email: true,
        avatar: true,
        isAdmin: true,
        isActive: true,
        createdAt: true,
        updatedAt: true,
        ownedStores: {
          select: {
            id: true,
            name: true,
            category: true,
            isActive: true,
            subscription: { select: { plan: true, status: true } },
          },
        },
        _count: { select: { ownedStores: true } },
      },
    });
    if (!user) throw new NotFoundException('User not found');

    const salesCount = await this.prisma.sale.count({
      where: { store: { ownerId: id } },
    });

    return { ...user, totalSalesCount: salesCount };
  }

  async listUserStores(userId: string) {
    return this.prisma.store.findMany({
      where: { ownerId: userId },
      select: {
        id: true,
        name: true,
        currency: true,
        category: true,
        isActive: true,
        createdAt: true,
        subscription: {
          select: {
            plan: true,
            status: true,
            currentPeriodEnd: true,
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  async toggleAdmin(id: string) {
    const user = await this.prisma.user.findUnique({ where: { id } });
    if (!user) throw new NotFoundException('User not found');
    return this.prisma.user.update({
      where: { id },
      data: { isAdmin: !user.isAdmin },
      select: { id: true, isAdmin: true },
    });
  }

  async blockUser(id: string) {
    const user = await this.prisma.user.findUnique({ where: { id } });
    if (!user) throw new NotFoundException('User not found');

    await this.prisma.$transaction([
      this.prisma.user.update({ where: { id }, data: { isActive: false } }),
      this.prisma.refreshToken.deleteMany({ where: { userId: id } }),
    ]);
    return { id, isActive: false };
  }

  async unblockUser(id: string) {
    const user = await this.prisma.user.findUnique({ where: { id } });
    if (!user) throw new NotFoundException('User not found');
    return this.prisma.user.update({
      where: { id },
      data: { isActive: true },
      select: { id: true, isActive: true },
    });
  }

  async deleteUser(id: string) {
    const user = await this.prisma.user.findUnique({ where: { id } });
    if (!user) throw new NotFoundException('User not found');
    return this.prisma.user.update({
      where: { id },
      data: {
        isActive: false,
        phone: `deleted_${id}`,
        email: null,
      },
      select: { id: true, isActive: true },
    });
  }

  // ============ STORES ============

  async listStores(query: AdminStoresQueryDto) {
    const page = query.page ?? 1;
    const limit = query.limit ?? 20;
    const skip = (page - 1) * limit;

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

    const [data, total] = await Promise.all([
      this.prisma.store.findMany({
        where,
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
        select: {
          id: true,
          name: true,
          category: true,
          isActive: true,
          createdAt: true,
          owner: { select: { id: true, name: true, phone: true } },
          subscription: { select: { plan: true, status: true } },
          _count: { select: { products: true, staff: true } },
        },
      }),
      this.prisma.store.count({ where }),
    ]);

    return { data, total, page, limit };
  }

  async getStoreDetail(id: string) {
    const store = await this.prisma.store.findUnique({
      where: { id },
      include: {
        owner: { select: { id: true, name: true, phone: true } },
        subscription: true,
        _count: { select: { products: true, staff: true } },
      },
    });
    if (!store) throw new NotFoundException('Store not found');

    const now = new Date();
    const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);

    const [monthlySales, lastSale] = await Promise.all([
      this.prisma.sale.aggregate({
        where: { storeId: id, createdAt: { gte: startOfMonth } },
        _sum: { total: true },
        _count: true,
      }),
      this.prisma.sale.findFirst({
        where: { storeId: id },
        orderBy: { createdAt: 'desc' },
        select: { createdAt: true },
      }),
    ]);

    return {
      ...store,
      monthlySalesTotal: monthlySales._sum.total ?? 0,
      monthlySalesCount: monthlySales._count,
      lastSaleDate: lastSale?.createdAt ?? null,
    };
  }

  async getStoreSubscription(storeId: string) {
    const sub = await this.prisma.subscription.findUnique({
      where: { storeId },
      include: {
        payments: {
          orderBy: { createdAt: 'desc' },
          take: 10,
        },
      },
    });
    if (!sub) throw new NotFoundException('Subscription not found for store');
    return sub;
  }

  async suspendStore(id: string) {
    const store = await this.prisma.store.findUnique({ where: { id } });
    if (!store) throw new NotFoundException('Store not found');
    return this.prisma.store.update({
      where: { id },
      data: { isActive: false },
      select: { id: true, isActive: true },
    });
  }

  async unsuspendStore(id: string) {
    const store = await this.prisma.store.findUnique({ where: { id } });
    if (!store) throw new NotFoundException('Store not found');
    return this.prisma.store.update({
      where: { id },
      data: { isActive: true },
      select: { id: true, isActive: true },
    });
  }

  async transferStore(id: string, dto: TransferStoreDto) {
    const [store, newOwner] = await Promise.all([
      this.prisma.store.findUnique({ where: { id } }),
      this.prisma.user.findUnique({ where: { id: dto.newOwnerId } }),
    ]);
    if (!store) throw new NotFoundException('Store not found');
    if (!newOwner) throw new NotFoundException('New owner user not found');

    return this.prisma.store.update({
      where: { id },
      data: { ownerId: dto.newOwnerId },
      select: { id: true, ownerId: true, name: true },
    });
  }

  // ============ DASHBOARD ============

  async getDashboard() {
    const now = new Date();
    const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);

    const [
      totalUsers,
      totalStores,
      subscriptionsByStatus,
      approvedPaymentsThisMonth,
      newUsersThisMonth,
      newStoresThisMonth,
    ] = await Promise.all([
      this.prisma.user.count(),
      this.prisma.store.count(),
      this.prisma.subscription.groupBy({
        by: ['status'],
        _count: true,
      }),
      this.prisma.payment.aggregate({
        where: {
          status: 'APPROVED',
          createdAt: { gte: startOfMonth },
        },
        _sum: { amount: true },
        _count: true,
      }),
      this.prisma.user.count({ where: { createdAt: { gte: startOfMonth } } }),
      this.prisma.store.count({ where: { createdAt: { gte: startOfMonth } } }),
    ]);

    return {
      totalUsers,
      totalStores,
      subscriptionsByStatus: subscriptionsByStatus.reduce(
        (acc, item) => {
          acc[item.status] = item._count;
          return acc;
        },
        {} as Record<string, number>,
      ),
      approvedPaymentsThisMonth: {
        total: approvedPaymentsThisMonth._sum.amount ?? 0,
        count: approvedPaymentsThisMonth._count,
      },
      newUsersThisMonth,
      newStoresThisMonth,
    };
  }

  async getRevenue(query: RevenueQueryDto) {
    const period = query.period ?? ReportPeriod.MONTH;
    const { startDate, groupFormat } = this.getPeriodRange(period);

    const payments = await this.prisma.payment.findMany({
      where: {
        status: 'APPROVED',
        createdAt: { gte: startDate },
      },
      select: { amount: true, createdAt: true },
      orderBy: { createdAt: 'asc' },
    });

    const grouped = this.groupByDate(payments, groupFormat);
    return grouped.map(([date, items]) => ({
      date,
      revenue: items.reduce((sum, p) => sum + Number(p.amount), 0),
      paymentsCount: items.length,
    }));
  }

  async getRegistrations(query: RevenueQueryDto) {
    const period = query.period ?? ReportPeriod.MONTH;
    const { startDate, groupFormat } = this.getPeriodRange(period);

    const [users, stores] = await Promise.all([
      this.prisma.user.findMany({
        where: { createdAt: { gte: startDate } },
        select: { createdAt: true },
      }),
      this.prisma.store.findMany({
        where: { createdAt: { gte: startDate } },
        select: { createdAt: true },
      }),
    ]);

    const allDates = new Set([
      ...users.map((u) => this.formatDate(u.createdAt, groupFormat)),
      ...stores.map((s) => this.formatDate(s.createdAt, groupFormat)),
    ]);

    return Array.from(allDates)
      .sort()
      .map((date) => ({
        date,
        users: users.filter(
          (u) => this.formatDate(u.createdAt, groupFormat) === date,
        ).length,
        stores: stores.filter(
          (s) => this.formatDate(s.createdAt, groupFormat) === date,
        ).length,
      }));
  }

  // ============ PLANS ============

  async listPlans() {
    return this.prisma.subscriptionPlanConfig.findMany();
  }

  async updatePlan(plan: SubscriptionPlan, dto: UpdatePlanDto) {
    const existing = await this.prisma.subscriptionPlanConfig.findUnique({
      where: { plan },
    });
    if (!existing) throw new NotFoundException('Plan config not found');

    const updateData: Prisma.SubscriptionPlanConfigUpdateInput = {};
    if (dto.price !== undefined) updateData.price = dto.price;
    if (dto.maxProducts !== undefined) updateData.maxProducts = dto.maxProducts;
    if (dto.maxStaff !== undefined) updateData.maxStaff = dto.maxStaff;
    if (dto.maxDiscounts !== undefined)
      updateData.maxDiscounts = dto.maxDiscounts;
    if (dto.hasReportsAll !== undefined)
      updateData.hasReportsAll = dto.hasReportsAll;
    if (dto.hasExport !== undefined) updateData.hasExport = dto.hasExport;
    if (dto.hasTelegram !== undefined) updateData.hasTelegram = dto.hasTelegram;
    if (dto.hasAllPush !== undefined) updateData.hasAllPush = dto.hasAllPush;
    if (dto.hasDelivery !== undefined) updateData.hasDelivery = dto.hasDelivery;
    if (dto.hasInventory !== undefined)
      updateData.hasInventory = dto.hasInventory;

    return this.prisma.subscriptionPlanConfig.update({
      where: { plan },
      data: updateData,
    });
  }

  // ============ ANNOUNCEMENTS ============

  // Spec C: shared audience resolver — used by both preview and
  // create. Returns one record per recipient with userId, primary
  // storeId (for sendPush), and pre-built vars (for renderTemplate).
  // Dedupes by userId in case a user owns multiple stores matching
  // the filter.
  private async _resolveAnnouncementAudience(
    dto: CreateAnnouncementDto,
  ): Promise<
    Array<{
      userId: string;
      storeId: string;
      vars: AnnouncementVars;
    }>
  > {
    const stores = await this.prisma.store.findMany({
      where: {
        isActive: true,
        owner: { isActive: true, isAdmin: false },
        ...(dto.targetPlan || dto.targetStatus
          ? {
              subscription: {
                ...(dto.targetPlan && { plan: dto.targetPlan }),
                ...(dto.targetStatus && { status: dto.targetStatus }),
              },
            }
          : {}),
      },
      include: {
        owner: { select: { id: true, name: true, phone: true } },
        subscription: { select: { plan: true, currentPeriodEnd: true } },
      },
    });

    // Dedupe by ownerId — pick FIRST store per user as the primary
    // (sendPush requires a storeId; if user has multiple, we just
    // need one).
    const seen = new Set<string>();
    const audience: Array<{
      userId: string;
      storeId: string;
      vars: AnnouncementVars;
    }> = [];

    for (const store of stores) {
      if (seen.has(store.ownerId)) continue;
      seen.add(store.ownerId);

      audience.push({
        userId: store.ownerId,
        storeId: store.id,
        vars: {
          user: {
            name: store.owner.name,
            phone: store.owner.phone ?? '',
          },
          store: {
            name: store.name,
            currency: store.currency,
            subscription: {
              plan: store.subscription?.plan ?? 'START',
              currentPeriodEnd: store.subscription?.currentPeriodEnd
                ? store.subscription.currentPeriodEnd.toISOString().slice(0, 10)
                : '—',
            },
          },
        },
      });
    }

    return audience;
  }

  private _fakeVarsForEmptyAudience(): AnnouncementVars {
    return {
      user: { name: 'Имя', phone: '+992XXXXXXXXX' },
      store: {
        name: 'Магазин',
        currency: 'TJS',
        subscription: { plan: 'START', currentPeriodEnd: '—' },
      },
    };
  }

  async createAnnouncement(dto: CreateAnnouncementDto, adminId: string) {
    // Spec C: shared audience resolver + per-user template render.
    // Each recipient gets THEIR rendered title/body via FCM. The
    // raw template is stored on Announcement so the row mirrors
    // what the admin typed (not the personalized expansion).
    const audience = await this._resolveAnnouncementAudience(dto);

    await Promise.allSettled(
      audience.map(({ userId, storeId, vars }) => {
        const renderedTitle = renderTemplate(dto.title, vars);
        const renderedBody = renderTemplate(dto.body, vars);
        return this.notifications.sendPush(
          userId,
          renderedTitle,
          renderedBody,
          'ANNOUNCEMENT',
          storeId,
        );
      }),
    );

    return this.prisma.announcement.create({
      data: {
        title: dto.title, // raw template — admin sees what was authored
        body: dto.body,
        targetPlan: dto.targetPlan,
        targetStatus: dto.targetStatus,
        sentBy: adminId,
        recipientCount: audience.length,
      },
    });
  }

  async previewAnnouncement(dto: CreateAnnouncementDto) {
    // Spec C: real audience resolver + template expansion.
    const audience = await this._resolveAnnouncementAudience(dto);
    const sample = audience[0]?.vars ?? this._fakeVarsForEmptyAudience();

    const renderedTitle = renderTemplate(dto.title, sample);
    const renderedBody = renderTemplate(dto.body, sample);

    // FCM Admin SDK throughput on a single Node process: ~100 users/sec
    // (10 parallel batches at ~50ms each). 6000 users/min, rounded up.
    // Min 1 minute so the UI never shows 0.
    const estimatedDeliveryMinutes = Math.max(
      1,
      Math.ceil(audience.length / 6000),
    );

    return {
      renderedTitle,
      renderedBody,
      audienceCount: audience.length,
      estimatedDeliveryMinutes,
    };
  }

  async listAnnouncements(query: AnnouncementsQueryDto) {
    const page = query.page ?? 1;
    const limit = query.limit ?? 20;
    const skip = (page - 1) * limit;

    const [data, total] = await Promise.all([
      this.prisma.announcement.findMany({
        orderBy: { createdAt: 'desc' },
        skip,
        take: limit,
      }),
      this.prisma.announcement.count(),
    ]);

    return { data, total, page, limit };
  }

  // ============ DIRECT NOTIFICATIONS ============

  async sendDirectNotification(dto: SendDirectNotificationDto): Promise<void> {
    if (dto.storeId) {
      await this.notifications.sendToStoreUsers(
        dto.storeId,
        dto.title,
        dto.body,
        'ADMIN_DIRECT',
      );
      return;
    }

    const store = await this.prisma.store.findFirst({
      where: { ownerId: dto.userId },
      select: { id: true },
      orderBy: { createdAt: 'asc' },
    });
    if (!store) {
      throw new NotFoundException(
        'User has no store to associate the notification with',
      );
    }

    await this.notifications.sendPush(
      dto.userId!,
      dto.title,
      dto.body,
      'ADMIN_DIRECT',
      store.id,
    );
  }

  // ============ AUDIT LOGS ============

  async listAuditLogs(query: AdminAuditLogQueryDto) {
    const page = query.page ?? 1;
    const limit = query.limit ?? 20;
    const skip = (page - 1) * limit;

    const where: Prisma.AuditLogWhereInput = {};
    if (query.userId) where.userId = query.userId;
    if (query.action)
      where.action = { contains: query.action, mode: 'insensitive' };
    if (query.entityType) where.entityType = query.entityType;
    if (query.from || query.to) {
      where.createdAt = {};
      if (query.from) where.createdAt.gte = new Date(query.from);
      if (query.to) where.createdAt.lte = new Date(query.to);
    }

    const [logs, total] = await Promise.all([
      this.prisma.auditLog.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip,
        take: limit,
      }),
      this.prisma.auditLog.count({ where }),
    ]);

    // Attach user names
    const userIds = [...new Set(logs.map((l) => l.userId))];
    const users = await this.prisma.user.findMany({
      where: { id: { in: userIds } },
      select: { id: true, name: true, phone: true },
    });
    const userMap = new Map(users.map((u) => [u.id, u]));

    const data = logs.map((log) => ({
      ...log,
      user: userMap.get(log.userId) ?? null,
    }));

    return { data, total, page, limit };
  }

  // ============ HELPERS ============

  private getPeriodRange(period: ReportPeriod): {
    startDate: Date;
    groupFormat: 'day' | 'week' | 'month';
  } {
    const now = new Date();
    switch (period) {
      case ReportPeriod.WEEK:
        return {
          startDate: new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000),
          groupFormat: 'day',
        };
      case ReportPeriod.YEAR:
        return {
          startDate: new Date(now.getFullYear(), 0, 1),
          groupFormat: 'month',
        };
      case ReportPeriod.MONTH:
      default:
        return {
          startDate: new Date(now.getFullYear(), now.getMonth(), 1),
          groupFormat: 'day',
        };
    }
  }

  private formatDate(date: Date, format: 'day' | 'week' | 'month'): string {
    if (format === 'month') {
      return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}`;
    }
    return date.toISOString().slice(0, 10);
  }

  private groupByDate<T extends { createdAt: Date; amount?: any }>(
    items: T[],
    format: 'day' | 'week' | 'month',
  ): [string, T[]][] {
    const map = new Map<string, T[]>();
    for (const item of items) {
      const key = this.formatDate(item.createdAt, format);
      if (!map.has(key)) map.set(key, []);
      map.get(key)!.push(item);
    }
    return Array.from(map.entries()).sort(([a], [b]) => a.localeCompare(b));
  }
}
