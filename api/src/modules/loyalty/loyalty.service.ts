import { Injectable } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { TelegramService } from '../telegram/telegram.service';
import { NotificationsService } from '../notifications/notifications.service';
import { UpdateLoyaltySettingsDto } from './dto/update-loyalty-settings.dto';

export function isBirthday(birthday: Date): boolean {
  const today = new Date();
  return (
    birthday.getUTCMonth() === today.getUTCMonth() &&
    birthday.getUTCDate() === today.getUTCDate()
  );
}

export function addDays(date: Date, days: number): Date {
  const d = new Date(date);
  d.setUTCDate(d.getUTCDate() + days);
  return d;
}

type PrismaTx = Omit<
  PrismaService,
  '$connect' | '$disconnect' | '$on' | '$transaction' | '$use' | '$extends'
>;

@Injectable()
export class LoyaltyService {
  constructor(
    private prisma: PrismaService,
    private telegram: TelegramService,
    private notifications: NotificationsService,
  ) {}

  async getSettings(storeId: string) {
    return this.prisma.loyaltySettings.upsert({
      where: { storeId },
      update: {},
      create: {
        storeId,
        isEnabled: false,
        pointsPerAmount: 1,
        amountForPoints: new Prisma.Decimal(100),
        pointValue: new Prisma.Decimal('0.01'),
        welcomePoints: 0,
      },
    });
  }

  async updateSettings(storeId: string, dto: UpdateLoyaltySettingsDto) {
    await this.getSettings(storeId);
    return this.prisma.loyaltySettings.update({
      where: { storeId },
      data: {
        ...(dto.isEnabled !== undefined && { isEnabled: dto.isEnabled }),
        ...(dto.pointsPerAmount !== undefined && {
          pointsPerAmount: dto.pointsPerAmount,
        }),
        ...(dto.amountForPoints !== undefined && {
          amountForPoints: new Prisma.Decimal(dto.amountForPoints),
        }),
        ...(dto.pointValue !== undefined && {
          pointValue: new Prisma.Decimal(dto.pointValue),
        }),
        ...(dto.welcomePoints !== undefined && {
          welcomePoints: dto.welcomePoints,
        }),
        ...('birthdayDiscount' in dto && {
          birthdayDiscount:
            dto.birthdayDiscount != null
              ? new Prisma.Decimal(dto.birthdayDiscount)
              : null,
        }),
        ...('pointsExpireDays' in dto && {
          pointsExpireDays: dto.pointsExpireDays ?? null,
        }),
      },
    });
  }

  async getCustomerBalance(storeId: string, customerId: string) {
    const [customer, transactions] = await Promise.all([
      this.prisma.customer.findFirst({
        where: { id: customerId, storeId },
        select: { loyaltyPoints: true },
      }),
      this.prisma.loyaltyTransaction.findMany({
        where: { customerId, storeId },
        orderBy: { createdAt: 'desc' },
        take: 20,
      }),
    ]);
    return {
      points: customer?.loyaltyPoints ?? 0,
      transactions,
    };
  }

  async earnPoints(
    tx: PrismaTx,
    opts: {
      customerId: string;
      storeId: string;
      saleId: string;
      points: number;
      expiresAt: Date | null;
    },
  ): Promise<void> {
    if (opts.points <= 0) return;
    await tx.loyaltyTransaction.create({
      data: {
        customerId: opts.customerId,
        storeId: opts.storeId,
        type: 'EARN',
        points: opts.points,
        saleId: opts.saleId,
        expiresAt: opts.expiresAt,
      },
    });
    await tx.customer.update({
      where: { id: opts.customerId },
      data: { loyaltyPoints: { increment: opts.points } },
    });

    // Fire-and-forget Telegram notifications — never throw
    const customer = await this.prisma.customer.findUnique({
      where: { id: opts.customerId },
      select: { telegramChatId: true, name: true, loyaltyPoints: true },
    });
    if (customer?.telegramChatId) {
      this.telegram
        .sendMessage(
          customer.telegramChatId,
          `+${opts.points} баллов начислено за покупку. Баланс: ${customer.loyaltyPoints} баллов 🎉`,
        )
        .catch(() => {});
    }
    this.telegram
      .getStoreChatId(opts.storeId)
      .then((storeChatId) => {
        if (storeChatId && customer) {
          this.telegram
            .sendMessage(
              storeChatId,
              `Клиент ${customer.name} получил +${opts.points} баллов`,
            )
            .catch(() => {});
        }
      })
      .catch(() => {});
  }

  async redeemPoints(
    tx: PrismaTx,
    opts: {
      customerId: string;
      storeId: string;
      saleId: string;
      points: number;
    },
  ): Promise<void> {
    if (opts.points <= 0) return;
    await tx.loyaltyTransaction.create({
      data: {
        customerId: opts.customerId,
        storeId: opts.storeId,
        type: 'REDEEM',
        points: -opts.points,
        saleId: opts.saleId,
      },
    });
    await tx.customer.update({
      where: { id: opts.customerId },
      data: { loyaltyPoints: { decrement: opts.points } },
    });
  }

  async getAnalytics(storeId: string, from: Date, to: Date) {
    const dateFilter = { gte: from, lte: to };

    const [earned, redeemed, expired, participants, topCustomers, settings] =
      await Promise.all([
        this.prisma.loyaltyTransaction.aggregate({
          where: { storeId, type: 'EARN', createdAt: dateFilter },
          _sum: { points: true },
        }),
        this.prisma.loyaltyTransaction.aggregate({
          where: { storeId, type: 'REDEEM', createdAt: dateFilter },
          _sum: { points: true },
        }),
        this.prisma.loyaltyTransaction.aggregate({
          where: { storeId, type: 'EXPIRE', createdAt: dateFilter },
          _sum: { points: true },
        }),
        this.prisma.customer.count({
          where: { storeId, loyaltyPoints: { gt: 0 } },
        }),
        this.prisma.customer.findMany({
          where: { storeId, loyaltyPoints: { gt: 0 } },
          orderBy: { loyaltyPoints: 'desc' },
          take: 10,
          select: { id: true, name: true, loyaltyPoints: true },
        }),
        this.prisma.loyaltySettings.findUnique({ where: { storeId } }),
      ]);

    const totalEarned = earned._sum.points ?? 0;
    const totalRedeemed = Math.abs(redeemed._sum.points ?? 0);
    const totalExpired = Math.abs(expired._sum.points ?? 0);
    const pointValue = Number(settings?.pointValue ?? 0);

    const earnedPerCustomer =
      topCustomers.length > 0
        ? await this.prisma.loyaltyTransaction.groupBy({
            by: ['customerId'],
            where: {
              storeId,
              customerId: { in: topCustomers.map((c) => c.id) },
              type: 'EARN',
            },
            _sum: { points: true },
          })
        : [];

    const earnMap = new Map(
      (earnedPerCustomer as any[]).map((r) => [r.customerId, r._sum.points ?? 0]),
    );

    return {
      period: { from: from.toISOString(), to: to.toISOString() },
      totalEarned,
      totalRedeemed,
      totalExpired,
      discountValue: totalRedeemed * pointValue,
      activeParticipants: participants,
      topCustomers: topCustomers.map((c) => ({
        customerId: c.id,
        name: c.name,
        balance: c.loyaltyPoints,
        totalEarned: earnMap.get(c.id) ?? 0,
      })),
    };
  }

  @Cron('0 9 * * *')
  async sendBirthdayPushes(): Promise<void> {
    const enabledStores = await this.prisma.loyaltySettings.findMany({
      where: { isEnabled: true, birthdayDiscount: { not: null } },
      select: { storeId: true, birthdayDiscount: true },
    });

    for (const setting of enabledStores) {
      const allCustomers = await this.prisma.customer.findMany({
        where: { storeId: setting.storeId, birthday: { not: null } },
        select: { id: true, name: true, birthday: true },
      });
      const birthdayCustomers = allCustomers.filter((c) =>
        isBirthday(c.birthday!),
      );
      for (const c of birthdayCustomers) {
        void this.notifications.sendToStoreUsers(
          setting.storeId,
          '🎂 День рождения',
          `${c.name} — скидка ${setting.birthdayDiscount}%`,
          'LOYALTY_BIRTHDAY',
        );
      }
    }
  }

  @Cron('0 2 * * *')
  async expireOverduePoints(): Promise<{
    expired: number;
    customersAffected: number;
  }> {
    const now = new Date();

    const alreadyExpired = await this.prisma.loyaltyTransaction.findMany({
      where: { type: 'EXPIRE', sourceEarnId: { not: null } },
      select: { sourceEarnId: true },
    });
    const expiredEarnIds = new Set(alreadyExpired.map((r) => r.sourceEarnId!));

    const overdueEarns = await this.prisma.loyaltyTransaction.findMany({
      where: {
        type: 'EARN',
        expiresAt: { lt: now },
        ...(expiredEarnIds.size > 0 && {
          NOT: { id: { in: [...expiredEarnIds] } },
        }),
      },
      take: 100,
    });

    if (overdueEarns.length === 0) return { expired: 0, customersAffected: 0 };

    const affectedCustomers = new Set(overdueEarns.map((e) => e.customerId));

    await this.prisma.$transaction(async (tx) => {
      for (const earn of overdueEarns) {
        await tx.loyaltyTransaction.create({
          data: {
            customerId: earn.customerId,
            storeId: earn.storeId,
            type: 'EXPIRE',
            points: -earn.points,
            sourceEarnId: earn.id,
            note: `Points from ${earn.createdAt.toISOString()} expired`,
          },
        });
      }

      for (const customerId of affectedCustomers) {
        const expiredTotal = overdueEarns
          .filter((e) => e.customerId === customerId)
          .reduce((sum, e) => sum + e.points, 0);
        await tx.customer.update({
          where: { id: customerId },
          data: { loyaltyPoints: { decrement: expiredTotal } },
        });
      }
    });

    return {
      expired: overdueEarns.length,
      customersAffected: affectedCustomers.size,
    };
  }
}
