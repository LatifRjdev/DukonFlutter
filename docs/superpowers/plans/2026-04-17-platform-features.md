# Sub-project 3: Platform Features Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete the remaining platform features — notifications datasource + FCM registration, stock movements history in product detail.

**Architecture:** 3 of 5 features (Subscriptions, Telegram, Finance) are already fully working. Only Notifications needs a datasource layer and FCM wiring. Stock Movements needs a history view in product detail.

**Tech Stack:** Flutter (DioClient, firebase_messaging), NestJS

---

## Audit Summary

| Feature | Status | Action Needed |
|---------|--------|---------------|
| Subscriptions | Complete | None |
| Telegram Receipts | Complete | None |
| Finance Balance/Credits | Complete | None |
| Notifications | Pages exist, no datasource | Create datasource, wire pages, add FCM registration |
| Stock Movements | Intake page exists, no history view | Add movements list to product detail |

---

### Task 1: Create Notification Datasource and Wire Pages

**Files:**
- Create: `app/lib/data/datasources/remote/notification_remote_datasource.dart`
- Modify: `app/lib/injection.dart` (register datasource)
- Modify: `app/lib/presentation/pages/notifications/notifications_page.dart` (wire to datasource)

Steps:
1. Read the notifications page to understand current data structure
2. Read the backend notifications controller to know exact endpoints and response shapes
3. Create NotificationRemoteDatasource with: getNotifications(storeId), markAsRead(storeId, id), saveFcmToken(token), saveSettings(storeId, settings)
4. Register in injection.dart
5. Wire notifications page to use datasource instead of direct DioClient (if it uses DioClient) or add API calls (if page is a stub)
6. Commit

### Task 2: Add FCM Token Registration on App Startup

**Files:**
- Modify: `app/lib/main.dart` or `app/lib/app.dart`

Steps:
1. Check if firebase_messaging is already initialized anywhere
2. If not, add FCM token retrieval and registration call on app startup
3. Use the notification datasource's saveFcmToken method
4. Commit

### Task 3: Add Stock Movements History to Product Detail

**Files:**
- Modify: `app/lib/presentation/pages/product/product_detail_page.dart`

Steps:
1. Read product detail page to understand structure
2. Add a section/tab that loads and displays stock movements for the product
3. Call GET /stores/:storeId/products/:productId/stock-movements
4. Commit
