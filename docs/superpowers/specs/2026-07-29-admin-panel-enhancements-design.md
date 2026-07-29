# Доработка админ-панели — Design Spec

**Date:** 2026-07-29
**Status:** Approved, ready for implementation planning

## Problem

Текущая админ-панель (`admin/`, бэкенд `api/src/modules/admin/`) покрывает базовое управление пользователями, магазинами, тарифами и подписками, но не хватает нескольких возможностей, которыми регулярно пользуется саппорт и биллинг:

- Нет способа написать конкретному пользователю/магазину — только broadcast-рассылка по фильтру («Объявления»).
- Платежи можно только approve/reject уже поданных — нет ручного внесения оплаты, полученной вне системы (наличные, банковский перевод).
- Нет экспорта списков (пользователи/магазины/подписки) для бухгалтерии.
- Аудит-лог показывает только новые значения запроса, без состояния «до» — сложно расследовать споры («кто и когда сменил тариф с X на Y»).
- Нет способа показать пользователям приложения промо/важное сообщение баннером внутри приложения (не только push).
- Саппорт не может воспроизвести баг клиента без прямого доступа к его аккаунту.

Это первая из двух независимых задач (вторая — интеграция с внешними интернет-магазинами для тарифа PREMIUM — пойдёт отдельным спеком).

## Goals

Добавить в админ-панель 6 независимых возможностей:
1. Точечные уведомления конкретному пользователю/магазину
2. Ручное создание платежа с автопродлением подписки
3. Экспорт списков (пользователи/магазины/подписки) в Excel с учётом текущих фильтров
4. Diff «было → стало» в аудит-логе
5. In-app баннеры в мобильном приложении с таргетингом по тарифу/статусу
6. Impersonate — вход в приложение клиента от его имени с его согласия

## Non-goals (явно вне рамок v1)

- Роли внутри самой админки (саппорт vs супер-админ) — плоский `isAdmin` остаётся как есть.
- Веб-версия клиентского приложения для impersonation — у продукта нет веб-клиента, только Flutter mobile.
- Универсальный diff-движок для всех сущностей БД — только для сущностей, которыми управляет админка (users, stores, subscriptions, planConfigs).
- Серверное хранение факта «баннер закрыт» — хранится локально на устройстве клиента.

## Design

### 1. Точечные уведомления

**Бэкенд**: `POST /admin/notifications/direct`, DTO `{ userId?: string; storeId?: string; title: string; body: string }` — ровно одно из `userId`/`storeId` (валидация на уровне DTO). Контроллер — новый метод в `admin-users.controller.ts` (переиспользует `AdminGuard`/`AuditInterceptor`). Вызывает существующие `NotificationsService.sendPush()` (для userId) или `sendToStoreUsers()` (для storeId) — новой инфраструктуры уведомлений не создаём.

**Фронтенд**: на `admin/app/(admin)/users/[id]/page.tsx` и `admin/app/(admin)/stores/[id]/page.tsx` — кнопка «Отправить сообщение» → shadcn `Dialog` с полями «Заголовок», «Текст». После отправки — success-toast. История доставки видна получателю в его собственной истории уведомлений (уже существует), факт отправки — в аудит-логе (автоматически).

### 2. Ручное создание платежа

**Бэкенд**: `POST /admin/subscriptions/:id/manual-payment`, DTO `{ amount: number; method: PaymentMethod; periodDays: number; notes?: string }`. В `SubscriptionsService`/`AdminService` — выносим общую логику продления подписки (сейчас внутри `approve-payment`) в приватный метод `applyApprovedPayment(subscriptionId, amount, periodDays)`, чтобы `approve-payment` и `manual-payment` использовали один и тот же код продления `currentPeriodEnd`. Создаёт `Payment` со статусом `APPROVED`, `method` из тела запроса (`CASH`/`MOBILE_TRANSFER`/`CARD` — существующий enum, новых значений не требуется), `reviewedBy: adminId`, `note` — из `notes` тела запроса. Новых полей в модели `Payment` не требуется — все нужные (`method`, `note`, `reviewedBy`) уже есть.

**Фронтенд**: на странице подписки (`/subscriptions`, раскрытая строка или отдельный `/subscriptions/[id]`, если появится) — кнопка «Внести платёж вручную» → форма (сумма, период в днях, примечание).

### 3. Экспорт в Excel

**Бэкенд**: три новых эндпоинта:
- `GET /admin/users/export`
- `GET /admin/stores/export`
- `GET /admin/subscriptions/export`

Каждый принимает те же query-параметры фильтрации, что и обычный `GET` списка (переиспользуют существующие `where`-билдеры `AdminService`), отдают `.xlsx` через `Content-Disposition: attachment`. Реализация — по образцу уже существующего `reports/export.service.ts` (библиотека `excel` уже есть в зависимостях бэкенда, `api/src/modules/reports/export.service.ts`).

**Фронтенд**: кнопка «Экспорт» на `/users`, `/stores`, `/subscriptions` — собирает текущие активные фильтры/поиск страницы в query-string и инициирует скачивание файла.

### 4. Diff в аудит-логе

`AuditInterceptor` (`api/src/common/interceptors/audit.interceptor.ts`) переписывается:

1. **До** вызова `next.handle()`: по `entityType` (уже парсится из URL через `deriveEntityType`) и `entityId` из `request.params`, через маппинг `Record<string, PrismaModelDelegate>` (только для сущностей, которыми управляет админка: users, stores, subscriptions, subscriptionPlanConfigs) — читает текущее состояние объекта (`before`).
2. **После** выполнения — читает объект заново (`after`).
3. Сохраняет в `audit_log.details` структуру `{ before: {...}, after: {...} }` вместо текущего плоского payload запроса.
4. Редактирование чувствительных полей (`SENSITIVE_FIELDS`) применяется к обоим снэпшотам.

Для действий без осмысленного «до/после» (например, `CREATE`) `before` будет `null`.

**Обратная совместимость**: старые записи в БД хранят плоский формат (текущий `details`). Фронтенд `/audit-log` при рендере проверяет форму объекта: если есть ключи `before`/`after` — показывает diff (построчно «поле: было → стало» для несовпадающих ключей); если нет — показывает как раньше (сырой JSON), без миграции старых данных.

### 5. In-app баннеры

**Модель** (новая таблица `banners` в `prisma/schema.prisma`):
```prisma
model Banner {
  id          String    @id @default(uuid())
  title       String
  body        String
  targetPlan  SubscriptionPlan?
  targetStatus SubscriptionStatus?
  startDate   DateTime
  endDate     DateTime
  active      Boolean  @default(true)
  createdAt   DateTime @default(now())

  @@map("banners")
}
```

Аудитория определяется той же логикой, что у `Announcement` — существующий приватный метод `AdminService._resolveAnnouncementAudience()` обобщается в `_resolveAudience()` и используется и announcements, и banners.

**Бэкенд**:
- `admin-banners.controller.ts` — CRUD (`POST/GET/PUT/DELETE /admin/banners`), обычные admin-гварды.
- Публичный `GET /stores/:storeId/banners/active` (только `JwtAuthGuard`+`StoreAccessGuard`, без `AdminGuard`) — вызывается из мобильного приложения; возвращает активный баннер, если текущая дата между `startDate`/`endDate`, `active: true`, и аудитория (по тарифу/статусу подписки магазина) подходит. Если баннеров несколько подходящих — возвращает самый свежий по `createdAt`.

**Мобильное приложение**: баннер над `HomePage`, запрашивается при каждом заходе на главный экран. Крестик закрытия сохраняет `bannerId` в локальный `SharedPreferences`-список закрытых баннеров — повторно этот же баннер не показывается на этом устройстве. Серверная сторона не хранит факт закрытия (не нужен per non-goals).

**Фронтенд админки**: новая страница `/banners` — список (с индикатором активен/истёк), создание/редактирование через диалог, ручное вкл/выкл.

### 6. Impersonate

Самая чувствительная часть — требует явного согласия клиента и полной прослеживаемости.

**Модель** (новая таблица `impersonation_requests`):
```prisma
model ImpersonationRequest {
  id            String   @id @default(uuid())
  adminId       String
  targetUserId  String
  status        String   // PENDING | APPROVED | REJECTED | EXPIRED | ENDED
  requestedAt   DateTime @default(now())
  respondedAt   DateTime?
  expiresAt     DateTime?
  endedAt       DateTime?
}
```

**Поток**:
1. `POST /admin/users/:id/impersonate` — создаёт `ImpersonationRequest(status: PENDING)`, отправляет push целевому пользователю через существующий `sendPush()`: «Поддержка Dukon запросила доступ к вашему аккаунту для диагностики. Разрешить?» с deep-link на экран подтверждения в приложении.
2. Мобильное приложение показывает экран с кнопками «Разрешить (30 минут)» / «Отклонить». Действие — новый эндпоинт `PUT /impersonation-requests/:id/respond` (пользовательский, не admin), доступный самому пользователю.
3. При `APPROVED` — бэкенд генерирует access+refresh токены для `targetUserId` с дополнительным JWT claim `impersonatedBy: adminId`, `impersonationRequestId`, TTL 30 минут (короче обычных 15 минут access + refresh — то есть весь impersonation-сеанс укладывается в 30 минут, после чего требуется повторный запрос).
4. Админ-панель получает токены через `GET /admin/impersonation/:id/token` (только если `status: APPROVED` и не истёк) — показывает QR-код с токеном (для сканирования тестовым устройством саппорта) и текстовую deep-link ссылку `dukonpro://impersonate?token=...`, открывающую приложение на тестовом/девайсе саппорта с уже подставленной сессией.
5. Любой запрос с impersonation-токеном помечается в `AuditInterceptor` флагом `viaImpersonation: true` (читается из JWT claim в `request.user`).
6. Мобильное приложение при активной impersonation-сессии показывает несъедаемый баннер поверх интерфейса «Вы вошли как поддержка Dukon» с кнопкой «Завершить сессию» → `POST /admin/impersonation/:id/end`, немедленно инвалидирует токены (добавление в существующий механизм revoked refresh tokens, используемый при block/unblock пользователя).
7. Токен истекает автоматически через 30 минут в любом случае.

**Фронтенд админки**: на `/users/[id]` — кнопка «Войти как пользователь» → показывает статус запроса в реальном времени (ожидание / одобрено / отклонено, с поллингом или редиректом на экран с QR-кодом после одобрения).

## Data integrity

- Ручное создание платежа и продление подписки — в одной транзакции (`prisma.$transaction`), как и существующий `approve-payment`.
- Impersonation-токен должен быть невозможно получить без прохождения полного цикла PENDING→APPROVED — эндпоинт выдачи токена проверяет статус запроса на каждый вызов, не кэширует.

## Access control

Как и весь `/admin/*` — доступ только `isAdmin: true`. Публичные эндпоинты для мобильного приложения (`GET .../banners/active`, `PUT /impersonation-requests/:id/respond`) — обычная пользовательская авторизация (`JwtAuthGuard`), не admin.

## Testing

- Юнит-тесты на `AdminService` для каждого нового метода (direct-notification, manual-payment, export query-building, audience resolution для banners, impersonation state machine) — по паттерну существующих `admin.service.spec.ts`.
- Юнит-тест на `AuditInterceptor` для before/after снэпшотов и для обратной совместимости старого формата в UI-рендере.
- Интеграционный тест на полный цикл impersonation: request → push → respond → token issuance → audit flag → auto-expiry.

## Open questions

Нет — все решения приняты в ходе обсуждения.
