import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../../prisma/prisma.service';
import { NotificationQueryDto } from './dto/notification-query.dto';
import { NotificationSettingsDto } from './dto/notification-settings.dto';

// Lazy-load firebase-admin so startup never crashes if the package is absent
// or credentials are invalid.
type FirebaseApp = import('firebase-admin/app').App;

@Injectable()
export class NotificationsService {
  private readonly logger = new Logger(NotificationsService.name);
  private firebaseApp: FirebaseApp | null = null;
  private fcmEnabled = false;

  constructor(
    private prisma: PrismaService,
    private config: ConfigService,
  ) {
    this.initFirebase();
  }

  private initFirebase(): void {
    const serviceAccountJson = this.config.get<string>(
      'FIREBASE_SERVICE_ACCOUNT',
    );
    if (!serviceAccountJson) {
      this.logger.warn(
        'FIREBASE_SERVICE_ACCOUNT not set — FCM push notifications disabled',
      );
      return;
    }

    try {
      // Dynamic require so the import doesn't fail if firebase-admin has init issues
      // eslint-disable-next-line @typescript-eslint/no-var-requires
      const admin = require('firebase-admin');
      const serviceAccount = JSON.parse(serviceAccountJson);

      // Avoid double-initialization (NestJS hot reload / test contexts)
      if (admin.apps.length === 0) {
        this.firebaseApp = admin.initializeApp({
          credential: admin.credential.cert(serviceAccount),
        });
      } else {
        this.firebaseApp = admin.apps[0] as FirebaseApp;
      }

      this.fcmEnabled = true;
      this.logger.log('Firebase Admin initialized — FCM push enabled');
    } catch (err) {
      this.logger.error(
        'Failed to initialize Firebase Admin — FCM disabled',
        err,
      );
    }
  }

  /**
   * Save notification record to DB and optionally send FCM push.
   * Never throws — always degrades gracefully if FCM is unavailable.
   */
  async sendPush(
    userId: string,
    title: string,
    body: string,
    type: string,
    storeId: string,
  ): Promise<void> {
    // Always persist to DB so the notification history is available in-app
    const notification = await this.prisma.notification.create({
      data: { userId, title, body, type, storeId },
    });

    if (!this.fcmEnabled || !this.firebaseApp) return;

    try {
      // eslint-disable-next-line @typescript-eslint/no-var-requires
      const admin = require('firebase-admin');

      const tokens = await this.prisma.fcmToken.findMany({
        where: { userId },
        select: { token: true },
      });

      if (tokens.length === 0) return;

      const tokenList = tokens.map((t) => t.token);

      const response = await admin
        .messaging(this.firebaseApp)
        .sendEachForMulticast({
          tokens: tokenList,
          notification: { title, body },
          data: { notificationId: notification.id, type, storeId },
        });

      // Clean up stale tokens that FCM reports as invalid
      const staleTokens: string[] = [];
      response.responses.forEach((res: any, idx: number) => {
        if (
          !res.success &&
          (res.error?.code === 'messaging/registration-token-not-registered' ||
            res.error?.code === 'messaging/invalid-registration-token')
        ) {
          staleTokens.push(tokenList[idx]);
        }
      });

      if (staleTokens.length > 0) {
        await this.prisma.fcmToken.deleteMany({
          where: { token: { in: staleTokens } },
        });
        this.logger.debug(
          `Removed ${staleTokens.length} stale FCM token(s) for user ${userId}`,
        );
      }

      this.logger.log(
        `FCM sent to ${response.successCount}/${tokenList.length} devices for user ${userId}`,
      );
    } catch (err) {
      this.logger.error(
        `FCM send failed for user ${userId} — notification saved to DB only`,
        err,
      );
    }
  }

  /** Send push to every owner and staff member of a store. Never throws. */
  async sendToStoreUsers(
    storeId: string,
    title: string,
    body: string,
    type: string,
  ): Promise<void> {
    try {
      const [store, staff] = await Promise.all([
        this.prisma.store.findUnique({
          where: { id: storeId },
          select: { ownerId: true },
        }),
        this.prisma.staff.findMany({
          where: { storeId },
          select: { userId: true },
        }),
      ]);
      const userIds = [
        ...new Set(
          [store?.ownerId, ...staff.map((s) => s.userId)].filter(
            (id): id is string => !!id,
          ),
        ),
      ];
      await Promise.all(
        userIds.map((uid) => this.sendPush(uid, title, body, type, storeId)),
      );
    } catch (err) {
      this.logger.error(`sendToStoreUsers failed for store ${storeId}`, err);
    }
  }

  /** Save or update an FCM device token for the current user. */
  async saveFcmToken(
    userId: string,
    token: string,
    platform: string,
  ): Promise<void> {
    await this.prisma.fcmToken.upsert({
      where: { token },
      update: { userId, platform },
      create: { userId, token, platform },
    });
  }

  /** Paginated notification history for a store+user combination. */
  async getNotifications(
    storeId: string,
    userId: string,
    query: NotificationQueryDto,
  ) {
    const page = query.page ?? 1;
    const limit = query.limit ?? 20;
    const skip = (page - 1) * limit;

    const [data, total] = await Promise.all([
      this.prisma.notification.findMany({
        where: { storeId, userId },
        orderBy: { createdAt: 'desc' },
        skip,
        take: limit,
      }),
      this.prisma.notification.count({ where: { storeId, userId } }),
    ]);

    return {
      data,
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
    };
  }

  /** Mark a single notification as read. */
  async markAsRead(storeId: string, notificationId: string): Promise<void> {
    const notification = await this.prisma.notification.findFirst({
      where: { id: notificationId, storeId },
    });
    if (!notification) throw new NotFoundException('Notification not found');

    await this.prisma.notification.update({
      where: { id: notificationId },
      data: { read: true },
    });
  }

  /** Retrieve current notification preferences for a store, applying all-true defaults. */
  async getNotificationSettings(storeId: string) {
    const store = await this.prisma.store.findUnique({
      where: { id: storeId },
      select: { settings: true },
    });
    const notif = (store?.settings as any)?.notifications ?? {};
    return {
      lowStockAlerts: notif.lowStockAlerts ?? true,
      newSaleAlerts: notif.newSaleAlerts ?? true,
      shiftClosedAlerts: notif.shiftClosedAlerts ?? true,
      deliveryCompletedAlerts: notif.deliveryCompletedAlerts ?? true,
      debtReminderAlerts: notif.debtReminderAlerts ?? true,
      daysWithoutSaleThreshold: notif.daysWithoutSaleThreshold ?? 30,
      remainingPercentThreshold: notif.remainingPercentThreshold ?? 50,
    };
  }

  /** Persist notification preferences into store.settings JSON. */
  async saveNotificationSettings(
    storeId: string,
    dto: NotificationSettingsDto,
  ): Promise<void> {
    const store = await this.prisma.store.findUnique({
      where: { id: storeId },
    });
    if (!store) throw new NotFoundException('Store not found');

    const currentSettings = (store.settings as Record<string, unknown>) ?? {};
    const updated = {
      ...currentSettings,
      notifications: {
        ...((currentSettings.notifications as Record<string, unknown>) ?? {}),
        ...dto,
      },
    };

    await this.prisma.store.update({
      where: { id: storeId },
      data: { settings: updated },
    });
  }
}
