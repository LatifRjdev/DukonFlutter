import {
  Injectable,
  NotFoundException,
  BadRequestException,
  OnModuleInit,
  Logger,
} from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { PrismaService } from '../../prisma/prisma.service';
import { AuditLogService } from '../../common/audit/audit-log.service';
import { NotificationsService } from '../notifications/notifications.service';
import { RequestChangeDto } from './dto/request-change.dto';
import { AdminSubscriptionQueryDto } from './dto/admin-subscription-query.dto';
import { RejectPaymentDto } from './dto/reject-payment.dto';
import { ChangePlanDto } from './dto/change-plan.dto';
import { ExtendSubscriptionDto } from './dto/extend-subscription.dto';
import { SetDiscountDto } from './dto/set-discount.dto';

const PLAN_HIERARCHY: Record<string, number> = {
  START: 1,
  BUSINESS: 2,
  PREMIUM: 3,
};

@Injectable()
export class SubscriptionsService implements OnModuleInit {
  private readonly logger = new Logger(SubscriptionsService.name);

  constructor(
    private prisma: PrismaService,
    private notificationsService: NotificationsService,
    private audit: AuditLogService,
  ) {}

  // ─── Seed plan configs on startup ───────────────────────────────────────────

  async onModuleInit() {
    await this.seedPlanConfigs();
  }

  private async seedPlanConfigs() {
    const plans = [
      {
        plan: 'START' as const,
        price: 200,
        maxProducts: 500,
        maxStaff: 2,
        maxDiscounts: 0,
        hasReportsAll: false,
        hasExport: false,
        hasTelegram: false,
        hasAllPush: false,
        hasDelivery: false,
        hasInventory: false,
        hasZakat: false,
        hasInvestments: false,
      },
      {
        plan: 'BUSINESS' as const,
        price: 400,
        maxProducts: 2000,
        maxStaff: 10,
        maxDiscounts: 5,
        hasReportsAll: true,
        hasExport: false,
        hasTelegram: true,
        hasAllPush: true,
        hasDelivery: true,
        hasInventory: true,
        hasZakat: true,
        hasInvestments: true,
      },
      {
        plan: 'PREMIUM' as const,
        price: 600,
        maxProducts: -1,
        maxStaff: -1,
        maxDiscounts: -1,
        hasReportsAll: true,
        hasExport: true,
        hasTelegram: true,
        hasAllPush: true,
        hasDelivery: true,
        hasInventory: true,
        hasZakat: true,
        hasInvestments: true,
      },
    ];

    for (const config of plans) {
      await this.prisma.subscriptionPlanConfig.upsert({
        where: { plan: config.plan },
        create: config,
        update: {},
      });
    }

    this.logger.log('Subscription plan configs seeded');
  }

  // ─── Public (user) endpoints ─────────────────────────────────────────────────

  async getPlans() {
    return this.prisma.subscriptionPlanConfig.findMany({
      orderBy: { price: 'asc' },
    });
  }

  async getSubscription(storeId: string) {
    const subscription = await this.prisma.subscription.findUnique({
      where: { storeId },
      include: { store: { select: { name: true } } },
    });

    if (!subscription) {
      throw new NotFoundException('Subscription not found for this store');
    }

    const planConfig = await this.prisma.subscriptionPlanConfig.findUnique({
      where: { plan: subscription.plan },
    });

    const discount = subscription.adminDiscount
      ? Number(subscription.adminDiscount)
      : 0;
    const basePrice = planConfig ? Number(planConfig.price) : 0;
    const calculatedPrice = basePrice * (1 - discount / 100);

    return {
      ...subscription,
      planConfig,
      calculatedPrice: Math.round(calculatedPrice * 100) / 100,
    };
  }

  async requestChange(storeId: string, dto: RequestChangeDto) {
    const subscription = await this.prisma.subscription.findUnique({
      where: { storeId },
    });

    if (!subscription) {
      throw new NotFoundException('Subscription not found');
    }

    const planConfig = await this.prisma.subscriptionPlanConfig.findUnique({
      where: { plan: dto.plan as any },
    });

    if (!planConfig) {
      throw new BadRequestException('Invalid plan');
    }

    const discount = subscription.adminDiscount
      ? Number(subscription.adminDiscount)
      : 0;
    const basePrice = Number(planConfig.price);
    const amount = basePrice * (1 - discount / 100);

    const payment = await this.prisma.payment.create({
      data: {
        subscriptionId: subscription.id,
        amount,
        currency: 'TJS',
        method: dto.paymentMethod as any,
        status: 'PENDING',
        note: `Plan change request to ${dto.plan}`,
      },
    });

    return payment;
  }

  async uploadReceipt(storeId: string, paymentId: string, filePath: string) {
    const subscription = await this.prisma.subscription.findUnique({
      where: { storeId },
    });

    if (!subscription) {
      throw new NotFoundException('Subscription not found');
    }

    const payment = await this.prisma.payment.findFirst({
      where: { id: paymentId, subscriptionId: subscription.id },
    });

    if (!payment) {
      throw new NotFoundException('Payment not found');
    }

    return this.prisma.payment.update({
      where: { id: paymentId },
      data: { receiptImage: filePath },
    });
  }

  async getPaymentHistory(storeId: string) {
    const subscription = await this.prisma.subscription.findUnique({
      where: { storeId },
    });

    if (!subscription) {
      throw new NotFoundException('Subscription not found');
    }

    return this.prisma.payment.findMany({
      where: { subscriptionId: subscription.id },
      orderBy: { createdAt: 'desc' },
    });
  }

  // ─── Admin endpoints ──────────────────────────────────────────────────────────

  async adminGetAll(query: AdminSubscriptionQueryDto) {
    const where: any = {};

    if (query.status) {
      where.status = query.status;
    }

    if (query.plan) {
      where.plan = query.plan;
    }

    if (query.search) {
      where.store = {
        name: { contains: query.search, mode: 'insensitive' },
      };
    }

    return this.prisma.subscription.findMany({
      where,
      include: {
        store: { select: { id: true, name: true } },
        payments: { orderBy: { createdAt: 'desc' }, take: 1 },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  async adminGetPendingPayments() {
    return this.prisma.payment.findMany({
      where: { status: 'PENDING' },
      include: {
        subscription: {
          include: { store: { select: { id: true, name: true } } },
        },
      },
      orderBy: { createdAt: 'asc' },
    });
  }

  async adminApprovePayment(
    subscriptionId: string,
    paymentId: string,
    reviewedBy: string,
  ) {
    const subscription = await this.prisma.subscription.findUnique({
      where: { id: subscriptionId },
      include: { payments: { where: { id: paymentId } } },
    });

    if (!subscription) {
      throw new NotFoundException('Subscription not found');
    }

    const payment = subscription.payments[0];
    if (!payment) {
      throw new NotFoundException('Payment not found');
    }

    if (payment.status === 'APPROVED') {
      return { payment, subscription };
    }

    if (payment.status === 'REJECTED') {
      throw new BadRequestException(
        'Cannot approve a payment that was previously rejected',
      );
    }

    let newPlan = subscription.plan;
    if (payment.note) {
      const match = payment.note.match(/Plan change request to (\w+)/);
      if (match) {
        newPlan = match[1] as any;
      }
    }

    const now = new Date();

    // Extend from currentPeriodEnd if still in future, else from now
    const base =
      subscription.currentPeriodEnd > now ? subscription.currentPeriodEnd : now;
    const newPeriodEnd = new Date(base);
    newPeriodEnd.setDate(newPeriodEnd.getDate() + 30);

    const [updatedPayment, updatedSubscription] =
      await this.prisma.$transaction([
        this.prisma.payment.update({
          where: { id: paymentId },
          data: {
            status: 'APPROVED',
            reviewedAt: now,
            reviewedBy,
          },
        }),
        this.prisma.subscription.update({
          where: { id: subscriptionId },
          data: {
            status: 'ACTIVE',
            plan: newPlan,
            currentPeriodEnd: newPeriodEnd,
            currentPeriodStart: now,
          },
        }),
      ]);

    // Notify store owner
    const store = await this.prisma.store.findUnique({
      where: { id: updatedSubscription.storeId },
      select: { ownerId: true, name: true },
    });

    if (store) {
      await this.notificationsService.sendPush(
        store.ownerId,
        'Подписка активирована',
        `Ваш платёж подтверждён. Подписка ${newPlan} активна до ${newPeriodEnd.toLocaleDateString('ru-RU')}.`,
        'SUBSCRIPTION_APPROVED',
        updatedSubscription.storeId,
      );
    }

    // Deferred #2: audit subscription approval.
    void this.audit.record(
      reviewedBy,
      'subscription.approve',
      'subscription',
      updatedSubscription.id,
      {
        paymentId: updatedPayment.id,
        plan: updatedSubscription.plan,
        newPeriodEnd: updatedSubscription.currentPeriodEnd,
      },
    );

    return { payment: updatedPayment, subscription: updatedSubscription };
  }

  async adminRejectPayment(
    subscriptionId: string,
    paymentId: string,
    dto: RejectPaymentDto,
    reviewedBy: string,
  ) {
    const subscription = await this.prisma.subscription.findUnique({
      where: { id: subscriptionId },
      include: { payments: { where: { id: paymentId } } },
    });

    if (!subscription) {
      throw new NotFoundException('Subscription not found');
    }

    if (!subscription.payments[0]) {
      throw new NotFoundException('Payment not found');
    }

    const now = new Date();

    const updatedPayment = await this.prisma.payment.update({
      where: { id: paymentId },
      data: {
        status: 'REJECTED',
        // F2.5: write the rejection reason to its own column so the
        // original `note` (e.g. "Plan change request to BUSINESS")
        // survives in the audit trail.
        rejectionReason: dto.reason,
        reviewedAt: now,
        reviewedBy,
      },
    });

    // Notify store owner
    const store = await this.prisma.store.findUnique({
      where: { id: subscription.storeId },
      select: { ownerId: true },
    });

    if (store) {
      await this.notificationsService.sendPush(
        store.ownerId,
        'Платёж отклонён',
        `Ваш платёж был отклонён. Причина: ${dto.reason}`,
        'SUBSCRIPTION_REJECTED',
        subscription.storeId,
      );
    }

    // Deferred #2: audit subscription rejection.
    void this.audit.record(
      reviewedBy,
      'subscription.reject',
      'subscription_payment',
      paymentId,
      { subscriptionId, reason: dto.reason },
    );

    return updatedPayment;
  }

  async adminExtend(
    subscriptionId: string,
    dto: ExtendSubscriptionDto,
    adminUserId: string,
  ) {
    const subscription = await this.prisma.subscription.findUnique({
      where: { id: subscriptionId },
    });

    if (!subscription) {
      throw new NotFoundException('Subscription not found');
    }

    const newEnd = new Date(subscription.currentPeriodEnd);
    newEnd.setDate(newEnd.getDate() + dto.days);

    const updated = await this.prisma.subscription.update({
      where: { id: subscriptionId },
      data: { currentPeriodEnd: newEnd },
    });

    void this.audit.record(
      adminUserId,
      'subscription.extend',
      'subscription',
      subscriptionId,
      { days: dto.days, newPeriodEnd: newEnd },
    );

    return updated;
  }

  async adminChangePlan(
    subscriptionId: string,
    dto: ChangePlanDto,
    adminUserId: string,
  ) {
    const subscription = await this.prisma.subscription.findUnique({
      where: { id: subscriptionId },
    });

    if (!subscription) {
      throw new NotFoundException('Subscription not found');
    }

    const updated = await this.prisma.subscription.update({
      where: { id: subscriptionId },
      data: { plan: dto.plan as any },
    });

    // Deferred #2: audit plan changes — both upgrades (revenue
    // implication) and downgrades (which silently lose access to
    // premium features under the F.2 fixed guard).
    void this.audit.record(
      adminUserId,
      'subscription.plan_change',
      'subscription',
      subscriptionId,
      { from: subscription.plan, to: dto.plan },
    );

    return updated;
  }

  async adminSetDiscount(subscriptionId: string, dto: SetDiscountDto) {
    const subscription = await this.prisma.subscription.findUnique({
      where: { id: subscriptionId },
    });

    if (!subscription) {
      throw new NotFoundException('Subscription not found');
    }

    return this.prisma.subscription.update({
      where: { id: subscriptionId },
      data: {
        adminDiscount: dto.percent === 0 ? null : dto.percent,
      },
    });
  }

  async adminCancel(subscriptionId: string) {
    const subscription = await this.prisma.subscription.findUnique({
      where: { id: subscriptionId },
    });

    if (!subscription) {
      throw new NotFoundException('Subscription not found');
    }

    return this.prisma.subscription.update({
      where: { id: subscriptionId },
      data: { status: 'CANCELLED' },
    });
  }

  // ─── Cron jobs ────────────────────────────────────────────────────────────────

  @Cron('0 0 * * *')
  async checkExpiredSubscriptions() {
    const now = new Date();
    this.logger.log('Running checkExpiredSubscriptions cron');

    const expired = await this.prisma.subscription.findMany({
      where: {
        status: { in: ['ACTIVE', 'TRIAL'] },
        currentPeriodEnd: { lt: now },
      },
      include: {
        store: { select: { ownerId: true, id: true, name: true } },
      },
    });

    if (expired.length > 0) {
      // D.4: was N+1 (one update per expired sub). Single updateMany
      // batches the status flip. The push notifications still fire
      // per-subscription because each owner gets their own message.
      await this.prisma.subscription.updateMany({
        where: { id: { in: expired.map((s) => s.id) } },
        data: { status: 'EXPIRED' },
      });

      for (const sub of expired) {
        await this.notificationsService.sendPush(
          sub.store.ownerId,
          'Подписка истекла',
          `Ваша подписка для магазина "${sub.store.name}" истекла. Обновите подписку для продолжения работы.`,
          'SUBSCRIPTION_EXPIRED',
          sub.store.id,
        );
        this.logger.log(`Subscription ${sub.id} marked as EXPIRED`);
      }
    }
  }

  @Cron('0 9 * * *')
  async sendExpiryReminders() {
    const now = new Date();
    const in3Days = new Date(now);
    in3Days.setDate(in3Days.getDate() + 3);

    this.logger.log('Running sendExpiryReminders cron');

    const expiringSoon = await this.prisma.subscription.findMany({
      where: {
        status: 'ACTIVE',
        currentPeriodEnd: {
          gte: now,
          lte: in3Days,
        },
      },
      include: {
        store: { select: { ownerId: true, id: true, name: true } },
      },
    });

    for (const sub of expiringSoon) {
      const msLeft = sub.currentPeriodEnd.getTime() - now.getTime();
      const daysLeft = Math.ceil(msLeft / (1000 * 60 * 60 * 24));

      await this.notificationsService.sendPush(
        sub.store.ownerId,
        'Подписка заканчивается',
        `Подписка заканчивается через ${daysLeft} дн. Продлите её, чтобы не потерять доступ.`,
        'SUBSCRIPTION_EXPIRY_REMINDER',
        sub.store.id,
      );

      this.logger.log(
        `Expiry reminder sent for subscription ${sub.id} (${daysLeft} days left)`,
      );
    }
  }
}
