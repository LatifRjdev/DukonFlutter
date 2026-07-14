# Spec M: Push Notifications — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire Firebase Cloud Messaging end-to-end so store owners receive push notifications for three loyalty events: customer birthday, points expiry, and low points balance after redemption.

**Architecture:** Flutter `main.dart` registers a background handler and calls `NotificationService.initFcm()` which handles foreground display and token refresh. The NestJS backend gains `NotificationsService.sendToStoreUsers()` (finds owner + staff of a store, calls `sendPush()` for each), then `LoyaltyService` calls it from a new birthday cron, the existing expiry cron, and via a post-transaction call in `SalesService`.

**Tech Stack:** Flutter + `firebase_messaging` + `flutter_local_notifications`; NestJS + `firebase-admin` (already wired); Prisma (`FcmToken` model exists); `@nestjs/schedule` (already imported).

---

## File Map

| File | Change |
|------|--------|
| `app/lib/main.dart` | Add background handler function + `onBackgroundMessage` registration + fix `platform` field + call `initFcm()` |
| `app/lib/core/services/notification_service.dart` | Add `initFcm(DioClient, GoRouter)` method |
| `api/src/modules/notifications/notifications.service.ts` | Add `sendToStoreUsers()` method |
| `api/src/modules/notifications/notifications.service.spec.ts` | Add `sendToStoreUsers` tests (extend Prisma fake with `store` + `staff`) |
| `api/src/modules/loyalty/loyalty.module.ts` | Import `NotificationsModule` |
| `api/src/modules/loyalty/loyalty.service.ts` | Inject `NotificationsService`, add `sendBirthdayPushes()` cron, push in `expireOverduePoints()`, add `notifyLowBalanceIfNeeded()` |
| `api/src/modules/loyalty/loyalty.service.spec.ts` | Add tests for all three push paths + extend Prisma fake with `store`+`staff` |
| `api/src/modules/sales/sales.service.ts` | Fire `notifyLowBalanceIfNeeded()` after transaction when points were redeemed |

---

## Task 1: Flutter FCM Wiring

Wire FCM background handler, foreground display, token refresh, and notification tap navigation.

**Files:**
- Modify: `app/lib/main.dart`
- Modify: `app/lib/core/services/notification_service.dart`

> **Context:** `Firebase.initializeApp()` is already called in `main.dart`. `firebase_messaging` is already in `pubspec.yaml`. The current FCM token registration block (lines 58–70 of `main.dart`) posts the token but is missing the required `platform` field — `SaveFcmTokenDto` requires it. `AppRouter.router` is a static field on `AppRouter`.

- [ ] **Step 1: Add `initFcm()` to `NotificationService`**

Open `app/lib/core/services/notification_service.dart`. Add these imports at the top:

```dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import '../network/dio_client.dart';
```

Add `initFcm()` method at the end of the `NotificationService` class, before the closing `}`:

```dart
Future<void> initFcm(DioClient dio, GoRouter router) async {
  // Foreground: FCM delivers silently when the app is open — show manually.
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    final n = message.notification;
    if (n != null) {
      showNotification(
        id: message.hashCode,
        title: n.title ?? '',
        body: n.body ?? '',
      );
    }
  });

  // Token refresh: FCM rotates tokens periodically — re-register with backend.
  FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
    final platform =
        defaultTargetPlatform == TargetPlatform.iOS ? 'IOS' : 'ANDROID';
    try {
      await dio.post(
        '/users/me/fcm-token',
        data: {'token': token, 'platform': platform},
      );
    } catch (_) {}
  });

  // Tap from terminated state (app was killed, user tapped notification).
  final initial = await FirebaseMessaging.instance.getInitialMessage();
  if (initial != null) router.go('/notifications');

  // Tap from background state (app was open, user tapped notification).
  FirebaseMessaging.onMessageOpenedApp.listen((_) => router.go('/notifications'));
}
```

- [ ] **Step 2: Add background handler to `main.dart`**

Open `app/lib/main.dart`. Add this top-level function **before** the `void main()` line:

```dart
/// FCM requires a top-level function annotated with vm:entry-point.
/// Called when a push arrives while the app is terminated or backgrounded.
/// FCM automatically shows the system notification — no manual display needed.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}
```

- [ ] **Step 3: Wire FCM in `_runApp()`**

In `main.dart`, locate this existing block (around line 55–70):

```dart
  await sl<NotificationService>().init();
  await sl<NotificationService>().requestPermission();

  // Register FCM token with backend (non-blocking)
  try {
    final fcmToken = await FirebaseMessaging.instance.getToken();
    if (fcmToken != null) {
      try {
        await sl<DioClient>().post('/users/me/fcm-token', data: {'token': fcmToken});
      } catch (_) {
        // Non-blocking — token registration can fail silently
      }
    }
  } catch (_) {
    // Firebase may not be initialized — skip FCM token registration
  }
```

Replace it with:

```dart
  await sl<NotificationService>().init();
  await sl<NotificationService>().requestPermission();

  // Register background message handler before any other FCM setup.
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Register FCM token with backend (non-blocking)
  try {
    final fcmToken = await FirebaseMessaging.instance.getToken();
    if (fcmToken != null) {
      final platform =
          defaultTargetPlatform == TargetPlatform.iOS ? 'IOS' : 'ANDROID';
      try {
        await sl<DioClient>().post(
          '/users/me/fcm-token',
          data: {'token': fcmToken, 'platform': platform},
        );
      } catch (_) {
        // Non-blocking — token registration can fail silently
      }
    }
  } catch (_) {
    // Firebase may not be initialized — skip FCM token registration
  }

  // Wire foreground display, token refresh, and tap navigation.
  try {
    await sl<NotificationService>().initFcm(sl<DioClient>(), AppRouter.router);
  } catch (_) {
    // Gracefully skip if Firebase is not initialised (e.g., missing config files).
  }
```

Add the missing import for `AppRouter` at the top of `main.dart` if not already present:
```dart
import 'core/router/app_router.dart';
```

- [ ] **Step 4: Verify Flutter builds without errors**

```bash
cd app && flutter analyze lib/main.dart lib/core/services/notification_service.dart
```

Expected: no errors (warnings about unused imports are acceptable).

- [ ] **Step 5: Commit**

```bash
git add app/lib/main.dart app/lib/core/services/notification_service.dart
git commit -m "feat(fcm): wire FCM background handler, foreground display, token refresh, tap nav"
```

---

## Task 2: `NotificationsService.sendToStoreUsers()`

Add the helper that all loyalty push triggers will use.

**Files:**
- Modify: `api/src/modules/notifications/notifications.service.ts`
- Modify: `api/src/modules/notifications/notifications.service.spec.ts`

> **Context:** `sendPush(userId, title, body, type, storeId)` already exists and is fully tested. `Store` model has `ownerId: String`. `Staff` model has `storeId: String` and `userId: String`. The method must find both the owner and all staff of a store, deduplicate, and call `sendPush()` for each.

- [ ] **Step 1: Write the failing test**

Open `api/src/modules/notifications/notifications.service.spec.ts`. 

First, add `store` and `staff` tables to `makePrismaFake()`. Find the line `const store = {` inside `makePrismaFake()` (the existing store mock for `findUnique` / `update` in `saveNotificationSettings`). Add two new tables **before** the `return` statement:

```typescript
  const storeOwners = new Map<string, { ownerId: string }>();
  const staffRows = new Map<string, { storeId: string; userId: string }>();
  let staffSeq = 0;

  const storeOwnerLookup = {
    findUnique: jest.fn(async ({ where, select }: any) => {
      const row = storeOwners.get(where.id);
      if (!row) return null;
      return select?.ownerId ? { ownerId: row.ownerId } : row;
    }),
    update: jest.fn(async ({ where, data }: any) => {
      const s = stores.get(where.id);
      if (!s) throw new Error('Not found');
      Object.assign(s, data);
      return s;
    }),
  };

  const staffLookup = {
    findMany: jest.fn(async ({ where, select }: any) => {
      const results = Array.from(staffRows.values()).filter(
        (r) => r.storeId === where.storeId,
      );
      if (select?.userId) return results.map((r) => ({ userId: r.userId }));
      return results;
    }),
  };
```

Update the `return` block to replace the existing `store` with `storeOwnerLookup` and add `staff` and `__storeOwners` + `__staff`:

```typescript
  return {
    notification,
    fcmToken,
    store: storeOwnerLookup,
    staff: staffLookup,
    __notifications: notifications,
    __fcmTokens: fcmTokens,
    __stores: stores,
    __storeOwners: storeOwners,
    __staff: staffRows,
    __staffSeq: () => ++staffSeq,
  };
```

Now add the test suite at the end of the file, before the final `});`:

```typescript
  describe('sendToStoreUsers — dispatches push to owner + all staff', () => {
    it('should send push to owner and each staff member of the store', async () => {
      sendEachForMulticast.mockResolvedValue({ successCount: 1, responses: [{ success: true }] });
      const service = await buildService();

      // Register FCM tokens for owner and two staff
      await service.saveFcmToken('owner-1', 'token-owner', 'ANDROID');
      await service.saveFcmToken('staff-1', 'token-staff1', 'ANDROID');
      await service.saveFcmToken('staff-2', 'token-staff2', 'IOS');

      prisma.__storeOwners.set('store-X', { ownerId: 'owner-1' });
      prisma.__staff.set(`s-${prisma.__staffSeq()}`, { storeId: 'store-X', userId: 'staff-1' });
      prisma.__staff.set(`s-${prisma.__staffSeq()}`, { storeId: 'store-X', userId: 'staff-2' });

      await service.sendToStoreUsers('store-X', '🎂 День рождения', 'Иван — скидка 10%', 'LOYALTY_BIRTHDAY');

      // 3 notifications created (owner + 2 staff)
      expect(prisma.__notifications.size).toBe(3);
      const userIds = Array.from(prisma.__notifications.values()).map((n) => n.userId).sort();
      expect(userIds).toEqual(['owner-1', 'staff-1', 'staff-2'].sort());
    });

    it('should deduplicate when owner is also in staff list', async () => {
      sendEachForMulticast.mockResolvedValue({ successCount: 1, responses: [{ success: true }] });
      const service = await buildService();

      await service.saveFcmToken('owner-1', 'token-owner', 'ANDROID');

      prisma.__storeOwners.set('store-Y', { ownerId: 'owner-1' });
      // Owner also appears as staff
      prisma.__staff.set('s-dup', { storeId: 'store-Y', userId: 'owner-1' });

      await service.sendToStoreUsers('store-Y', 'Title', 'Body', 'LOYALTY_EXPIRY');

      // Only one notification (owner deduplicated)
      expect(prisma.__notifications.size).toBe(1);
    });

    it('should not throw when store has no users', async () => {
      const service = await buildService();
      // No storeOwner, no staff for 'store-Z'
      prisma.__storeOwners.set('store-Z', { ownerId: 'nobody' });

      await expect(
        service.sendToStoreUsers('store-Z', 'T', 'B', 'LOYALTY_BIRTHDAY'),
      ).resolves.toBeUndefined();
    });
  });
```

- [ ] **Step 2: Run the failing tests**

```bash
cd api && npx jest notifications.service.spec.ts --testNamePattern="sendToStoreUsers" --no-coverage 2>&1 | tail -20
```

Expected: FAIL — `TypeError: service.sendToStoreUsers is not a function`.

- [ ] **Step 3: Implement `sendToStoreUsers()`**

Open `api/src/modules/notifications/notifications.service.ts`. Add this method at the end of the class, before the closing `}`:

```typescript
  /**
   * Send a push notification to every user (owner + staff) that belongs to
   * the given store. Never throws — logs errors and degrades gracefully.
   */
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
      this.logger.error(
        `sendToStoreUsers failed for store ${storeId}`,
        err,
      );
    }
  }
```

- [ ] **Step 4: Run tests — expect PASS**

```bash
cd api && npx jest notifications.service.spec.ts --no-coverage 2>&1 | tail -15
```

Expected: all tests PASS (including the three existing suites).

- [ ] **Step 5: Commit**

```bash
git add api/src/modules/notifications/notifications.service.ts \
        api/src/modules/notifications/notifications.service.spec.ts
git commit -m "feat(notifications): add sendToStoreUsers() for store-wide push dispatch"
```

---

## Task 3: Module Wiring + Birthday Push Cron

Inject `NotificationsService` into `LoyaltyService` and add the 09:00 daily birthday cron.

**Files:**
- Modify: `api/src/modules/loyalty/loyalty.module.ts`
- Modify: `api/src/modules/loyalty/loyalty.service.ts`
- Modify: `api/src/modules/loyalty/loyalty.service.spec.ts`

> **Context:** `LoyaltyService` already imports `TelegramService`. `isBirthday(birthday: Date): boolean` is an exported helper in `loyalty.service.ts`. `Customer.birthday` is `DateTime?`. `LoyaltySettings.birthdayDiscount` is `Decimal?`. The birthday query must filter month+day because Prisma has no built-in month/day filter — fetch customers with `birthday NOT NULL` for the store and filter in JS using `isBirthday()`.

- [ ] **Step 1: Write the failing tests**

Open `api/src/modules/loyalty/loyalty.service.spec.ts`. 

First, extend `makePrismaFake()` to add `store` and `staff` tables (needed by `sendToStoreUsers()` via `NotificationsService`). Find the `return` block in `makePrismaFake()` and add before it:

```typescript
  const storeOwners = new Map<string, { ownerId: string }>();
  const staffRows = new Map<string, { storeId: string; userId: string }>();
```

Inside `makePrismaFake()`, find the `loyaltySettings` object and add `findMany` to it. The object currently has `upsert`, `update`, `findUnique`. Add `findMany` as a new property:

```typescript
  const loyaltySettings = {
    upsert: jest.fn(async ({ where, create }: any) => { /* existing */ }),
    update: jest.fn(async ({ where, data }: any) => { /* existing */ }),
    findUnique: jest.fn(async ({ where }: any) => settings.get(where.storeId) ?? null),
    findMany: jest.fn(async ({ where }: any) => {
      return Array.from(settings.values()).filter((s: any) => {
        if (where?.isEnabled !== undefined && s.isEnabled !== where.isEnabled) return false;
        if (where?.birthdayDiscount?.not === null && s.birthdayDiscount == null) return false;
        return true;
      });
    }),
  };
```

> Keep all existing methods intact — only add `findMany`.

Update the `return` block in `makePrismaFake()`:
```typescript
  return {
    _customers: customers,
    _txs: txs,
    _settings: settings,
    _storeOwners: storeOwners,
    _staffRows: staffRows,
    ...api,
  };
```

Now extend `beforeEach` in the `describe('LoyaltyService')` block to also inject a mock `NotificationsService`:

```typescript
  let notifService: { sendToStoreUsers: jest.Mock };

  beforeEach(async () => {
    prisma = makePrismaFake();
    notifService = { sendToStoreUsers: jest.fn().mockResolvedValue(undefined) };
    const moduleRef = await Test.createTestingModule({
      providers: [
        LoyaltyService,
        { provide: PrismaService, useValue: prisma },
        {
          provide: TelegramService,
          useValue: {
            sendMessage: jest.fn().mockResolvedValue(undefined),
            getStoreChatId: jest.fn().mockResolvedValue(null),
          },
        },
        {
          provide: NotificationsService,
          useValue: notifService,
        },
      ],
    }).compile();
    service = moduleRef.get(LoyaltyService);
  });
```

Add the import for `NotificationsService` at the top:
```typescript
import { NotificationsService } from '../notifications/notifications.service';
```

Add the birthday cron test suite at the end of the `describe('LoyaltyService')` block:

```typescript
  // -------------------------------------------------------------------------
  // sendBirthdayPushes
  // -------------------------------------------------------------------------
  describe('sendBirthdayPushes', () => {
    it('should call sendToStoreUsers for each customer whose birthday is today', async () => {
      const today = new Date();
      const birthdayToday = new Date(
        Date.UTC(1990, today.getUTCMonth(), today.getUTCDate()),
      );
      const otherMonth = (today.getUTCMonth() + 6) % 12;
      const birthdayOther = new Date(Date.UTC(1990, otherMonth, 15));

      // Store with loyalty + birthday discount
      prisma._settings.set('store-1', {
        storeId: 'store-1',
        isEnabled: true,
        birthdayDiscount: new (require('@prisma/client').Prisma.Decimal)(10),
      });

      // Two customers: one with birthday today, one not
      prisma._customers.set('cust-bday', {
        id: 'cust-bday', storeId: 'store-1', name: 'Иван', birthday: birthdayToday, loyaltyPoints: 0, isActive: true,
      });
      prisma._customers.set('cust-other', {
        id: 'cust-other', storeId: 'store-1', name: 'Сидор', birthday: birthdayOther, loyaltyPoints: 0, isActive: true,
      });

      await service.sendBirthdayPushes();

      expect(notifService.sendToStoreUsers).toHaveBeenCalledTimes(1);
      expect(notifService.sendToStoreUsers).toHaveBeenCalledWith(
        'store-1',
        '🎂 День рождения',
        'Иван — скидка 10%',
        'LOYALTY_BIRTHDAY',
      );
    });

    it('should not call sendToStoreUsers when no loyalty settings are enabled', async () => {
      await service.sendBirthdayPushes();
      expect(notifService.sendToStoreUsers).not.toHaveBeenCalled();
    });

    it('should not call sendToStoreUsers when no customer has birthday today', async () => {
      const today = new Date();
      const otherMonth = (today.getUTCMonth() + 6) % 12;

      prisma._settings.set('store-1', {
        storeId: 'store-1',
        isEnabled: true,
        birthdayDiscount: new (require('@prisma/client').Prisma.Decimal)(15),
      });
      prisma._customers.set('cust-1', {
        id: 'cust-1', storeId: 'store-1', name: 'Алишер',
        birthday: new Date(Date.UTC(1990, otherMonth, 15)),
        loyaltyPoints: 0, isActive: true,
      });

      await service.sendBirthdayPushes();
      expect(notifService.sendToStoreUsers).not.toHaveBeenCalled();
    });
  });
```

- [ ] **Step 2: Run the failing tests**

```bash
cd api && npx jest loyalty.service.spec.ts --testNamePattern="sendBirthdayPushes" --no-coverage 2>&1 | tail -20
```

Expected: FAIL — `service.sendBirthdayPushes is not a function` (or module injection error).

- [ ] **Step 3: Import `NotificationsModule` in `loyalty.module.ts`**

Replace the entire content of `api/src/modules/loyalty/loyalty.module.ts` with:

```typescript
import { Module } from '@nestjs/common';
import { NotificationsModule } from '../notifications/notifications.module';
import { TelegramModule } from '../telegram/telegram.module';
import { LoyaltyController } from './loyalty.controller';
import { LoyaltyService } from './loyalty.service';

@Module({
  imports: [TelegramModule, NotificationsModule],
  controllers: [LoyaltyController],
  providers: [LoyaltyService],
  exports: [LoyaltyService],
})
export class LoyaltyModule {}
```

- [ ] **Step 4: Inject `NotificationsService` + add birthday cron in `loyalty.service.ts`**

Open `api/src/modules/loyalty/loyalty.service.ts`.

Add the import for `NotificationsService` at the top (alongside existing imports):
```typescript
import { NotificationsService } from '../notifications/notifications.service';
```

Update the constructor:
```typescript
  constructor(
    private prisma: PrismaService,
    private telegram: TelegramService,
    private notifications: NotificationsService,
  ) {}
```

Add `sendBirthdayPushes()` after the existing `updateSettings()` method and before `getCustomerBalance()`:

```typescript
  @Cron('0 9 * * *')
  async sendBirthdayPushes(): Promise<void> {
    const enabledSettings = await this.prisma.loyaltySettings.findMany({
      where: { isEnabled: true, birthdayDiscount: { not: null } },
      select: { storeId: true, birthdayDiscount: true },
    });

    if (enabledSettings.length === 0) return;

    for (const setting of enabledSettings) {
      const customers = await this.prisma.customer.findMany({
        where: { storeId: setting.storeId, birthday: { not: null }, isActive: true },
        select: { id: true, name: true, birthday: true },
      });

      const birthdayCustomers = customers.filter((c) => isBirthday(c.birthday!));

      for (const customer of birthdayCustomers) {
        const discount = Number(setting.birthdayDiscount);
        await this.notifications.sendToStoreUsers(
          setting.storeId,
          '🎂 День рождения',
          `${customer.name} — скидка ${discount}%`,
          'LOYALTY_BIRTHDAY',
        );
      }
    }
  }
```

- [ ] **Step 5: Run tests — expect PASS**

```bash
cd api && npx jest loyalty.service.spec.ts --no-coverage 2>&1 | tail -15
```

Expected: all tests PASS.

- [ ] **Step 6: Commit**

```bash
git add api/src/modules/loyalty/loyalty.module.ts \
        api/src/modules/loyalty/loyalty.service.ts \
        api/src/modules/loyalty/loyalty.service.spec.ts
git commit -m "feat(loyalty): inject NotificationsService + birthday push cron (09:00 daily)"
```

---

## Task 4: Expiry Push + Low-Balance Notification

Send a push after points expire (existing cron) and when a customer's balance drops below 50 after a redemption.

**Files:**
- Modify: `api/src/modules/loyalty/loyalty.service.ts`
- Modify: `api/src/modules/loyalty/loyalty.service.spec.ts`
- Modify: `api/src/modules/sales/sales.service.ts`

> **Context:** `expireOverduePoints()` collects `overdueEarns` before the `$transaction` block. Each entry has `.storeId`. After the transaction, loop over distinct storeIds and call `sendToStoreUsers()`. `redeemPoints()` runs inside a Prisma `$transaction` — push must fire after the transaction in `SalesService.create()`. `SalesService` already has `void this.maybeNotifyBigSale(storeId, result)` (fire-and-forget pattern) immediately after the transaction — follow the same pattern. `LoyaltyService` is already injected into `SalesService`.

- [ ] **Step 1: Write failing tests**

Add to `api/src/modules/loyalty/loyalty.service.spec.ts` at the end of the `describe('LoyaltyService')` block:

```typescript
  // -------------------------------------------------------------------------
  // expireOverduePoints — push path
  // -------------------------------------------------------------------------
  describe('expireOverduePoints — push notification', () => {
    it('should call sendToStoreUsers once per affected store after expiry', async () => {
      // Seed an EARN tx that is already overdue
      const expiredDate = new Date(Date.now() - 1000 * 60 * 60 * 24); // yesterday
      const earnId = 'earn-1';
      prisma._txs.set(earnId, {
        id: earnId,
        customerId: 'cust-1',
        storeId: 'store-1',
        type: 'EARN',
        points: 100,
        expiresAt: expiredDate,
        createdAt: expiredDate,
        sourceEarnId: null,
      });

      await service.expireOverduePoints();

      expect(notifService.sendToStoreUsers).toHaveBeenCalledWith(
        'store-1',
        '⏳ Баллы истекли',
        expect.stringContaining('клиент'),
        'LOYALTY_EXPIRY',
      );
    });

    it('should not call sendToStoreUsers when no points expired', async () => {
      await service.expireOverduePoints();
      expect(notifService.sendToStoreUsers).not.toHaveBeenCalled();
    });
  });

  // -------------------------------------------------------------------------
  // notifyLowBalanceIfNeeded
  // -------------------------------------------------------------------------
  describe('notifyLowBalanceIfNeeded', () => {
    it('should call sendToStoreUsers when customer balance is below threshold', async () => {
      prisma._customers.set('cust-1', {
        id: 'cust-1', storeId: 'store-1', name: 'Алишер', loyaltyPoints: 30,
      });

      await service.notifyLowBalanceIfNeeded('cust-1', 'store-1');

      expect(notifService.sendToStoreUsers).toHaveBeenCalledWith(
        'store-1',
        '📉 Низкий баланс',
        'Алишер: 30 баллов',
        'LOYALTY_LOW_BALANCE',
      );
    });

    it('should not call sendToStoreUsers when customer balance is at or above threshold', async () => {
      prisma._customers.set('cust-1', {
        id: 'cust-1', storeId: 'store-1', name: 'Иван', loyaltyPoints: 50,
      });

      await service.notifyLowBalanceIfNeeded('cust-1', 'store-1');
      expect(notifService.sendToStoreUsers).not.toHaveBeenCalled();
    });

    it('should not call sendToStoreUsers when customer does not exist', async () => {
      await service.notifyLowBalanceIfNeeded('ghost', 'store-1');
      expect(notifService.sendToStoreUsers).not.toHaveBeenCalled();
    });
  });
```

The `customer` mock in `makePrismaFake()` already has a `findUnique` that returns the full customer row regardless of `select`. This is sufficient — `notifyLowBalanceIfNeeded` selects `name` and `loyaltyPoints`, both of which exist on every seeded customer row in tests. No change needed to the mock.

- [ ] **Step 2: Run the failing tests**

```bash
cd api && npx jest loyalty.service.spec.ts --testNamePattern="expireOverduePoints|notifyLowBalance" --no-coverage 2>&1 | tail -25
```

Expected: FAIL — methods not implemented yet.

- [ ] **Step 3: Add expiry push to `expireOverduePoints()` in `loyalty.service.ts`**

Find the `expireOverduePoints()` method. It ends with:
```typescript
    return {
      expired: overdueEarns.length,
      customersAffected: affectedCustomers.size,
    };
  }
```

Replace that block with:

```typescript
    const result = {
      expired: overdueEarns.length,
      customersAffected: affectedCustomers.size,
    };

    if (affectedCustomers.size > 0) {
      const storeIds = [...new Set(overdueEarns.map((e) => e.storeId))];
      for (const sid of storeIds) {
        const count = new Set(
          overdueEarns.filter((e) => e.storeId === sid).map((e) => e.customerId),
        ).size;
        const suffix = count === 1 ? 'а' : 'ов';
        await this.notifications.sendToStoreUsers(
          sid,
          '⏳ Баллы истекли',
          `У ${count} клиент${suffix} истекли баллы лояльности`,
          'LOYALTY_EXPIRY',
        );
      }
    }

    return result;
  }
```

- [ ] **Step 4: Add `notifyLowBalanceIfNeeded()` to `loyalty.service.ts`**

Add the constant and method at the end of `LoyaltyService`, before the closing `}`:

```typescript
  private static readonly LOW_BALANCE_THRESHOLD = 50;

  async notifyLowBalanceIfNeeded(
    customerId: string,
    storeId: string,
  ): Promise<void> {
    const customer = await this.prisma.customer.findUnique({
      where: { id: customerId },
      select: { name: true, loyaltyPoints: true },
    });
    if (!customer) return;
    if (customer.loyaltyPoints < LoyaltyService.LOW_BALANCE_THRESHOLD) {
      await this.notifications.sendToStoreUsers(
        storeId,
        '📉 Низкий баланс',
        `${customer.name}: ${customer.loyaltyPoints} баллов`,
        'LOYALTY_LOW_BALANCE',
      );
    }
  }
```

- [ ] **Step 5: Run loyalty tests — expect PASS**

```bash
cd api && npx jest loyalty.service.spec.ts --no-coverage 2>&1 | tail -15
```

Expected: all tests PASS.

- [ ] **Step 6: Call `notifyLowBalanceIfNeeded` from `SalesService`**

Open `api/src/modules/sales/sales.service.ts`. Find line 413 where `maybeNotifyBigSale` is called:

```typescript
    void this.maybeNotifyBigSale(storeId, result);

    return result;
```

Replace with:

```typescript
    void this.maybeNotifyBigSale(storeId, result);

    // Fire low-balance push if customer redeemed points and their new balance
    // dropped below the threshold. Runs outside the transaction so a push
    // failure can never roll back a completed sale.
    if (dto.customerId && dto.redemptionPoints && dto.redemptionPoints > 0) {
      void this.loyaltyService.notifyLowBalanceIfNeeded(dto.customerId, storeId);
    }

    return result;
```

- [ ] **Step 7: Run all backend tests to confirm no regressions**

```bash
cd api && npx jest --no-coverage 2>&1 | tail -20
```

Expected: all existing + new tests PASS.

- [ ] **Step 8: Commit**

```bash
git add api/src/modules/loyalty/loyalty.service.ts \
        api/src/modules/loyalty/loyalty.service.spec.ts \
        api/src/modules/sales/sales.service.ts
git commit -m "feat(loyalty): expiry push + low-balance trigger via notifyLowBalanceIfNeeded()"
```

---

## Manual Verification Steps (not automatable)

After all 4 tasks are committed, the following must be done by a human before push notifications will actually deliver on real devices:

1. **Download Firebase config files** from the Firebase console → Project Settings:
   - `google-services.json` → copy to `app/android/app/`
   - `GoogleService-Info.plist` → copy to `app/ios/Runner/` via Xcode (drag into project navigator)

2. **Set `FIREBASE_SERVICE_ACCOUNT` env var** on the NestJS production server. Value is the full JSON of the Firebase Admin SDK service account key (download from Firebase console → Service Accounts).

3. **Test end-to-end** on a physical device:
   - Log in → check backend logs for `FCM sent to 1/1 devices`
   - Background app → trigger a loyalty event → see system notification appear
   - Terminated app → tap notification → app opens to `/notifications` route
