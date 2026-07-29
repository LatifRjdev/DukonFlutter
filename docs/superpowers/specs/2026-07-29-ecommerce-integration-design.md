# Интеграция интернет-магазина (PREMIUM) — Design Spec

**Date:** 2026-07-29
**Status:** Approved, ready for implementation planning

## Problem

У части клиентов Dukon (тариф PREMIUM) есть отдельный интернет-магазин (например, сайт-магазин одежды), не связанный с Dukon. Заказы, сделанные на сайте, никак не отражаются в Dukon: остатки товара не списываются, продажа не попадает в отчётность, а физический магазин может продать тот же товар, который уже ушёл со склада онлайн (и наоборот) — overselling в обе стороны.

Это вторая из двух независимых задач этой сессии (первая — доработка админ-панели, отдельный спек `2026-07-29-admin-panel-enhancements-design.md`). В кодовой базе на момент написания нет вообще никакой e-commerce/webhook-инфраструктуры — единственный прецедент входящего вебхука во всём проекте — Telegram-бот (`api/src/modules/telegram/telegram.controller.ts`), который и служит образцом для аутентификации по общему секрету.

## Goals

- Клиент PREMIUM подключает свой сайт к Dukon: настраивает исходящий вебхук на сайт и API-ключ для входящих запросов.
- Клиент сопоставляет товары своего сайта с товарами в каталоге Dukon вручную (таблица соответствий).
- При заказе на сайте — Dukon списывает остаток, создаёт продажу с каналом «Online», при необходимости создаёт заказчика и черновик доставки.
- При отмене заказа на сайте — Dukon возвращает остаток и помечает продажу отменённой.
- При любом изменении остатка в Dukon (продажа в магазине, приход, корректировка, включая сам факт онлайн-заказа) — Dukon в реальном времени уведомляет сайт об актуальном остатке, чтобы сайт не продавал то, чего физически нет.
- Продажи с сайта видны в отчётности Dukon отдельным каналом, с возможностью фильтрации.

## Non-goals (явно вне рамок v1)

- Готовые коннекторы для конкретных платформ (Shopify, WooCommerce, Tilda) — интеграция полностью общая (generic REST/webhook), клиент/разработчик сайта сам вызывает контракт Dukon. Платформо-специфичные коннекторы могут появиться позже как надстройка над этим же контрактом.
- Автоматическое сопоставление товаров по SKU/штрихкоду — только ручная таблица соответствий в v1.
- Очередь задач (message queue) для исходящих вебхуков — простой retry с экспоненциальной задержкой внутри сервиса, без внешней инфраструктуры (Bull/Redis и т.п. в проекте сейчас нет).
- Синхронизация цен «Dukon → сайт» или «сайт → Dukon» — только остатки. Цены каждая система ведёт сама.
- Массовый импорт/экспорт таблицы сопоставления (например, через Excel) — только ручное редактирование по одному товару. Может стать отдельным улучшением позже.

## Design

### Модель данных

```prisma
model EcommerceIntegration {
  id                  String   @id @default(uuid())
  storeId             String   @unique
  store               Store    @relation(fields: [storeId], references: [id])
  apiKey              String   @unique
  outboundWebhookUrl  String?
  enabled             Boolean  @default(true)
  createdAt           DateTime @default(now())
  updatedAt           DateTime @updatedAt

  @@map("ecommerce_integrations")
}

model ExternalProductMapping {
  id                String   @id @default(uuid())
  storeId           String
  store             Store    @relation(fields: [storeId], references: [id])
  productId         String
  product           Product  @relation(fields: [productId], references: [id])
  externalProductId String
  createdAt         DateTime @default(now())

  @@unique([storeId, externalProductId])
  @@map("external_product_mappings")
}

enum SalesChannel {
  IN_STORE
  ONLINE
}
```

`Sale` (`api/prisma/schema.prisma:298`) получает два новых поля:
- `channel SalesChannel @default(IN_STORE)`
- `externalOrderId String?` — для сопоставления с заказом сайта при отмене (`@@index` для быстрого поиска при `order.cancelled`)

`SaleStatus.CANCELLED` уже существует (`schema.prisma:349-354`) — переиспользуется как есть, новый статус не нужен.

`SubscriptionPlanConfig` получает `hasEcommerceIntegration Boolean @default(false)` — `true` только у PREMIUM (устанавливается через существующий `PUT /admin/plans/:plan`, отдельный UI в админке не нужен, поле появится в существующей форме `/subscriptions/plans` автоматически, как и остальные фичи).

### Входящий поток: сайт → Dukon

**`POST /stores/:storeId/ecommerce/orders`**

Аутентификация: заголовок `X-API-Key`, сверяется с `EcommerceIntegration.apiKey` данного магазина (тот же принцип общего секрета, что и `TELEGRAM_WEBHOOK_SECRET`, но ключ per-store, а не глобальный — хранится в БД, не в env).

Тело запроса:
```json
{
  "event": "order.created",
  "externalOrderId": "site-order-123",
  "items": [{ "externalProductId": "sku-1", "quantity": 2, "price": 150 }],
  "customer": { "name": "Иван Иванов", "phone": "+992900000000", "address": "ул. Рудаки 1" },
  "totalAmount": 300
}
```

Обработка (`EcommerceOrdersService`, одна Prisma-транзакция):
1. Найти `EcommerceIntegration` по `storeId`+`apiKey`; если не найдена/`enabled: false`/тариф магазина не PREMIUM (проверка `hasEcommerceIntegration` через существующий `SubscriptionGuard`-паттерн) — 401/403.
2. Для каждого `items[].externalProductId` найти `ExternalProductMapping`; если хотя бы для одной позиции нет соответствия, или недостаточно остатка (`product.quantity < requested`) — **отклонить весь заказ целиком** (422, с точным указанием, какая позиция проблемная), отправить push владельцу магазина через существующий `NotificationsService.sendToStoreUsers()`: «Заказ с сайта отклонён — не хватает товара [название]».
3. Найти или создать `Customer` по `[storeId, phone]` (существующий уникальный индекс, `upsert`).
4. Создать `Sale`: `channel: ONLINE`, `paymentType: CARD`, `paidAmount: totalAmount`, `status: COMPLETED`, `externalOrderId`, `customerId`. Списать остаток по каждой позиции обычным путём — через существующий `StockMovementsService` с `type: SALE` (переиспользуется без изменений).
5. Если `hasDelivery` тарифа включён — создать `Delivery(address: customer.address, status: NEW)`, привязанную к продаже через существующее 1:1-отношение `Sale.delivery`.

**`event: "order.cancelled"`** (то же тело, но `event` и только `externalOrderId` обязательны): находит `Sale` по `[storeId, externalOrderId]`, возвращает остаток каждой позиции через `StockMovementsService` (`type: RETURN`), переводит `Sale.status → CANCELLED`. Если продажа не найдена — 404 (сайт мог продублировать вебхук о заказе, которого Dukon не видел из-за более ранней ошибки — по контракту сайт должен считать такой ответ идемпотентным «уже отменено/не существовало»).

### Исходящий поток: Dukon → сайт

Точка входа — там же, где сейчас пишутся stock-movements (`StockMovementsService.create()` и любой другой код, который меняет `Product.quantity`: продажа в кассе, приход, инвентаризация, ручная корректировка, а также сам входящий заказ с сайта из шага выше — самоэхо безвредно, просто одна лишняя исходящая проверка).

После успешной записи движения — если у товара есть `ExternalProductMapping`, асинхронно (не блокируя ответ клиенту) вызывается `EcommerceOutboundService.pushStockUpdate(productId, newQuantity)`:
- `POST {outboundWebhookUrl}` с телом `{ externalProductId, quantity }`.
- При сетевой ошибке/не-2xx — до 3 повторов с экспоненциальной задержкой (1s/4s/16s).
- Если все попытки неудачны — лог ошибки + один push владельцу «Не удалось обновить остатки на сайте — проверьте настройки интеграции» (не более одного уведомления на 15 минут на магазин, чтобы не спамить при затяжном простое сайта клиента).

### UI в мобильном приложении (только PREMIUM, `hasEcommerceIntegration`)

Новый раздел «Интернет-магазин» в Настройках, по образцу существующих «Telegram-бот»/«ККМ»:
- Показывает URL входящего вебхука Dukon (`{API_BASE}/stores/{storeId}/ecommerce/orders`) и текущий `apiKey` (копирование в буфер, кнопка «Перегенерировать» — инвалидирует старый ключ).
- Поле «URL вебхука вашего сайта» (`outboundWebhookUrl`) — куда Dukon будет слать обновления остатков.
- Переключатель «Интеграция активна» (`enabled`).
- Экран «Сопоставление товаров»: список товаров магазина, у каждого — редактируемое текстовое поле «Внешний ID» (создаёт/обновляет/удаляет `ExternalProductMapping` при сохранении).

### Отчётность

`Sale.channel` — новый фильтр-чип на странице «Отчёты» (вкладки Продажи/Прибыль/Товары), рядом с существующим выбором периода. На главном дашборде — дополнительная строка «В магазине / Онлайн» с разбивкой выручки за период (переиспользует существующий агрегирующий запрос, добавляя `GROUP BY channel`).

## Data integrity

- Обработка входящего заказа — одна Prisma-транзакция (customer upsert + sale + stock-movements + delivery); при ошибке любого шага — весь заказ откатывается, вебхуку возвращается ошибка (сайт должен повторить).
- Отмена заказа — тоже одна транзакция (stock-movements возврата + смена статуса продажи).
- Исходящий push остатков — вне транзакции записи движения (fire-and-forget), поскольку временная недоступность сайта клиента не должна блокировать или откатывать операции внутри Dukon.

## Access control

- Входящий эндпоинт `POST /stores/:storeId/ecommerce/orders` — не использует `JwtAuthGuard` (сайт не имеет пользовательской сессии Dukon), аутентификация только через `X-API-Key`. Ограничен по `Throttle` (защита от перебора/спама), как и вебхук Telegram.
- Управление интеграцией (настройки, сопоставление товаров) — обычная пользовательская авторизация магазина (`JwtAuthGuard` + `StoreAccessGuard`), доступно владельцу/сотрудникам с соответствующей ролью, гейтится `RequiresFeature('hasEcommerceIntegration')`.

## Testing

- Юнит-тесты `EcommerceOrdersService`: успешный заказ (списание, создание customer/delivery), отклонение при нехватке остатка, отклонение при отсутствии сопоставления, отмена существующего заказа, отмена несуществующего заказа (идемпотентный 404).
- Юнит-тест `EcommerceOutboundService`: успешный push, retry при ошибке, финальный провал после 3 попыток + анти-спам уведомления (не чаще раза в 15 минут).
- Интеграционный тест на сквозной сценарий: входящий заказ → списание остатка → срабатывание исходящего push (мокнутый HTTP-клиент) → отмена → возврат остатка → повторный push.

## Open questions

Нет — все решения приняты в ходе обсуждения.
