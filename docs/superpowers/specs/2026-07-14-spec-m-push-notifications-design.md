# Spec M: Push Notifications (FCM/APNs)

## Goal

Wire up Firebase Cloud Messaging so the Dukon app delivers server-triggered push
notifications to store owners for three loyalty events: customer birthday today,
points expiry, and low points balance after redemption. Telegram remains the
primary customer-facing channel; push notifications are the operator-facing channel
(store owner / staff devices running the Dukon app).

## What Already Exists

The infrastructure is largely in place — Spec M wires the pieces together:

| Component | Status |
|-----------|--------|
| `firebase_core` + `firebase_messaging` in `pubspec.yaml` | ✅ declared |
| `Firebase.initializeApp()` in `main.dart` | ✅ called |
| FCM token registration `POST /users/me/fcm-token` in `main.dart` | ✅ exists, but missing `platform` field |
| `FcmToken` Prisma model (multi-device, one per token) | ✅ exists |
| `NotificationsService.sendPush(userId, title, body, type, storeId)` | ✅ fully implemented |
| Stale FCM token cleanup on send errors | ✅ implemented |
| `LoyaltyService.isBirthday()` helper | ✅ exists |
| `LoyaltyService.expireOverduePoints()` daily cron at 02:00 | ✅ runs, but sends no push |
| `ScheduleModule` in `app.module.ts` | ✅ imported |
| `flutter_local_notifications` for foreground display | ✅ initialised |

Missing:
- FCM background message handler (required top-level function)
- Foreground message display (app open → FCM arrives silently, must display manually)
- Token refresh listener
- Notification tap → navigation
- Backend: birthday push cron
- Backend: push calls after `expireOverduePoints()` and in `debitPoints()`
- Backend: `sendToStoreUsers()` helper

---

## Architecture

```
Flutter app                        NestJS backend
───────────────────────────        ────────────────────────────────────
main.dart
  @pragma background handler ◄──── FCM push delivery (Google/Apple)
  FirebaseMessaging.onMessage
    └─ NotificationService
         showLocalNotification()     LoyaltyService
  onTokenRefresh                       @Cron 09:00 sendBirthdayPushes()
    └─ POST /users/me/fcm-token        expireOverduePoints() + push
  onMessageOpenedApp                   debitPoints()  → low-balance push
    └─ go('/notifications')
                                     NotificationsService
                                       sendToStoreUsers(storeId, …)
                                         └─ sendPush(userId, …) × N
```

The rule: push is always **store-owner/staff → device**. Customers receive
Telegram (Spec K). Push targets the Dukon app users that belong to the store
associated with the loyalty event.

---

## Backend

### 1. `NotificationsService.sendToStoreUsers()`

New helper. Queries all user IDs that belong to a given store (via
`prisma.storeUser` or equivalent join), then calls `sendPush()` for each.
Used by all three loyalty triggers. Never throws — degrades silently like
`sendPush()`.

```typescript
async sendToStoreUsers(
  storeId: string,
  title: string,
  body: string,
  type: string,
): Promise<void>
```

Implementation:
```typescript
const store = await this.prisma.store.findUnique({ where: { id: storeId }, select: { ownerId: true } });
const staff = await this.prisma.staff.findMany({ where: { storeId }, select: { userId: true } });
const userIds = [...new Set([store?.ownerId, ...staff.map(s => s.userId)].filter(Boolean))];
await Promise.all(userIds.map(uid => this.sendPush(uid, title, body, type, storeId)));
```

### 2. `LoyaltyService` changes

**Inject `NotificationsService`** alongside existing `TelegramService`.

**New cron — `sendBirthdayPushes()` at `0 9 * * *`:**
- Find all `loyaltySettings` where `isEnabled = true AND birthdayDiscount IS NOT NULL`
- For each setting's `storeId`, query customers where `birthday` matches today (month + day)
- If any found: call `sendToStoreUsers()` with message
  `"🎂 День рождения: {name} — скидка {discount}%"` per customer
- One push per customer (not batched into one message) so store owner sees each name

**Modify `expireOverduePoints()`:**
- After the existing transaction completes, if `customersAffected > 0`:
  - Collect the distinct `storeId` values from `overdueEarns`
  - For each storeId: `sendToStoreUsers(storeId, "⏳ Баллы истекли", "У {N} клиентов истекли баллы лояльности", "LOYALTY_EXPIRY")`
  - Sends one push per store (aggregate), not one per customer

**Modify `debitPoints()`:**
- After the `customer.update({ loyaltyPoints: { decrement } })`, query the
  updated balance
- If `loyaltyPoints < LOW_BALANCE_THRESHOLD` (constant: `50`):
  - `sendToStoreUsers(storeId, "📉 Низкий баланс", "{name}: {balance} баллов", "LOYALTY_LOW_BALANCE")`

### 3. `LoyaltyModule`

Import `NotificationsModule` (forwardRef if circular).

### 4. Tests

- `sendBirthdayPushes()`: mock `prisma.loyaltySettings.findMany`, `prisma.customer.findMany`, assert `sendToStoreUsers` called for birthday customers only
- `expireOverduePoints()` push path: existing test extended — after expiry, assert `sendToStoreUsers` called per affected store
- `debitPoints()` low-balance: assert `sendToStoreUsers` called when resulting balance < 50, not called when balance ≥ 50
- `sendToStoreUsers()`: assert finds store users and calls `sendPush()` for each

---

## Flutter

### 1. Background handler (`main.dart`)

Top-level function required by FCM (must be outside any class, annotated with
`@pragma('vm:entry-point')`):

```dart
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // FCM shows system notification automatically in background/terminated state.
  // No explicit display needed here.
}
```

Register before `runApp`:
```dart
FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
```

### 2. Fix FCM token registration

Current code in `main.dart` posts token without platform. Fix:

```dart
final platform = defaultTargetPlatform == TargetPlatform.iOS ? 'IOS' : 'ANDROID';
await sl<DioClient>().post('/users/me/fcm-token', data: {
  'token': fcmToken,
  'platform': platform,
});
```

### 3. `NotificationService.initFcm()`

New method called from `main.dart` after `init()` and `requestPermission()`.

```dart
Future<void> initFcm(DioClient dio, GoRouter router) async {
  // Foreground: FCM arrives but system does NOT auto-show — display manually
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    final n = message.notification;
    if (n != null) showNotification(title: n.title ?? '', body: n.body ?? '');
  });

  // Token refresh: re-register with backend
  FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
    final platform = defaultTargetPlatform == TargetPlatform.iOS ? 'IOS' : 'ANDROID';
    try {
      await dio.post('/users/me/fcm-token', data: {'token': token, 'platform': platform});
    } catch (_) {}
  });

  // Tap from terminated state
  final initial = await FirebaseMessaging.instance.getInitialMessage();
  if (initial != null) router.go('/notifications');

  // Tap from background state
  FirebaseMessaging.onMessageOpenedApp.listen((_) => router.go('/notifications'));
}
```

`initFcm()` is called in `main.dart` after `FirebaseApp` and DI are ready.
`AppRouter.router` is a static field — pass it directly: `sl<NotificationService>().initFcm(sl<DioClient>(), AppRouter.router)`.

### 4. Call site in `main.dart`

```dart
await sl<NotificationService>().init();
await sl<NotificationService>().requestPermission();
FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
await sl<NotificationService>().initFcm(sl<DioClient>(), AppRouter.router);
```

---

## Notification types

| `type` field | Trigger | Title (ru) | Body |
|---|---|---|---|
| `LOYALTY_BIRTHDAY` | Daily 09:00 | 🎂 День рождения | `{name} — скидка {discount}%` |
| `LOYALTY_EXPIRY` | Daily 02:00 (post-expire) | ⏳ Баллы истекли | `{N} клиентов: баллы истекли` |
| `LOYALTY_LOW_BALANCE` | After redeem | 📉 Низкий баланс | `{name}: {balance} баллов` |

---

## Notification settings

No new Prisma migration required. Notification settings (per-store, stored in
`store.settings` JSON) can include `loyalty.birthdayPush` / `loyalty.expiryPush`
/ `loyalty.lowBalancePush` booleans — but for MVP, all three are **always on**.
The store's existing notification settings page can add toggles in a future spec.

---

## Constants

```typescript
// loyalty.service.ts
const LOW_BALANCE_THRESHOLD = 50; // points
```

---

## Manual prerequisites (not code tasks)

These are one-time setup steps, not part of the implementation task list:

1. **`google-services.json`** → `app/android/app/` (download from Firebase console)
2. **`GoogleService-Info.plist`** → `app/ios/Runner/` (download from Firebase console)
3. **`FIREBASE_SERVICE_ACCOUNT`** env var on the production NestJS server (JSON key for Firebase Admin SDK)
4. Enable FCM API in the Firebase project console

Without steps 1–3, FCM will not deliver messages. The Flutter build will succeed
(Firebase gracefully skips initialization if config files are absent in debug
builds), but push delivery is dead.

---

## Files

### Modified

| File | Change |
|------|--------|
| `app/lib/main.dart` | Background handler, `onBackgroundMessage` registration, fix platform field, call `initFcm()` |
| `app/lib/core/services/notification_service.dart` | Add `initFcm()` method |
| `api/src/modules/notifications/notifications.service.ts` | Add `sendToStoreUsers()` helper |
| `api/src/modules/notifications/notifications.service.spec.ts` | Test for `sendToStoreUsers()` |
| `api/src/modules/loyalty/loyalty.service.ts` | Inject `NotificationsService`, add birthday cron, push in expiry cron, push in debitPoints |
| `api/src/modules/loyalty/loyalty.module.ts` | Import `NotificationsModule` |
| `api/src/modules/loyalty/loyalty.service.spec.ts` | Tests for all 3 push paths |

### New files

None.

---

## Out of scope

- Per-store notification toggles (UI for enabling/disabling each push type)
- Customer-facing push (customers do not have the app; Telegram is their channel)
- Rich notifications (images, action buttons)
- Silent/data-only push for background sync
- Android notification channels beyond the existing default channel
- iOS provisional push authorisation
