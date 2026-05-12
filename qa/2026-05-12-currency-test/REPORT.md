# Multi-currency live test — 2026-05-12

## Context

qa-business OWNER (`+992910001002` / `qatest1234`) with 3 stores after this run:

| store name | id | currency | sales |
|------------|----|----------|-------|
| qa-business-store | `d169d2e8-0a24-4a23-844a-5d5e7b690d8c` | TJS | 24 (pre-existing) |
| qa-usd-store | `3ec979cd-bb56-498e-8409-97a878dbf1b6` | USD | 1 (created in step 6) |
| qa-rub-store | `8950f793-6d62-4ed7-b901-4aadcc765449` | RUB | 0 |

Verification done via API (curl) + SQL — emulator UI tested only at the dashboard (splash) level. Pure UI-driving was skipped because the app's UI coordinates drift session-to-session and the MECHANISMS we want to verify are all backend-side.

API base: `http://localhost:4455`. DB: `dukonpro` in container `dukonpro-db`.

## Scenario results

| # | Scenario | How tested | Expected | Actual | Status |
|---|----------|------------|----------|--------|--------|
| 1 | TJS store has existing sales | SQL `SELECT COUNT(*) FROM sales WHERE storeId=...` | ≥1 row | 24 rows | PASS |
| 2 | USD store created with currency='USD' | SQL `INSERT INTO stores ... RETURNING` | row visible | id `3ec979cd-...` currency=USD | PASS |
| 3 | RUB store created with currency='RUB' | SQL `INSERT INTO stores ... RETURNING` | row visible | id `8950f793-...` currency=RUB | PASS |
| 4 | TJS store currency change blocked (BUG #15 fix) | `PUT /api/stores/{TJS_ID}` body `{"currency":"USD"}` | HTTP 400 with "Currency cannot be changed once sales exist..." | HTTP 400, msg `"Currency cannot be changed once sales exist for this store. Contact support if you need a migration."` | PASS |
| 5a | Fresh USD store currency CAN be changed to TJS | `PUT /api/stores/{USD_ID}` body `{"currency":"TJS"}` | HTTP 200 | HTTP 200, body shows currency=TJS | PASS |
| 5b | EUR rejected by enum | `PUT /api/stores/{USD_ID}` body `{"currency":"EUR"}` | HTTP 400 | HTTP 400, msg `"currency must be one of the following values: "` (list empty — see findings) | PASS (with finding) |
| 6 | USD store sale via API | `POST /api/stores/{USD_ID}/sales` paymentType=CASH paidAmount=5 | HTTP 201, sale created | sale id `2a18da24-636a-464b-84b0-943b166fbce4`, total=5, paymentType=CASH, status=COMPLETED | PASS |
| 7a | `/reports/sales` for USD store | `GET /api/stores/{USD_ID}/reports/sales` | HTTP 200 with sale data | HTTP 200, `{"byDate":[{"date":"2026-05-12...","count":1,"revenue":5,"avgCheck":5}],"topProducts":[{"productName":"USD test bread","totalQty":1,"totalRevenue":5}],"totalRevenue":5,"totalCount":1,"avgCheck":5,...}` | PASS |
| 7b | `/reports/profit` for USD store | `GET /api/stores/{USD_ID}/reports/profit` | HTTP 200 with profit data | HTTP 200, `{"income":5,"expenses":0,"profit":5,"marginPercent":100,...}` | PASS |
| 8 | USD store currency NOW locked (after sale) | `PUT /api/stores/{USD_ID}` body `{"currency":"TJS"}` | HTTP 400 | HTTP 400, same lock message as scenario 4 | PASS |
| 9 | currencies/rates endpoint | `GET /api/currencies/rates` | HTTP 200 | HTTP 200, body `[]` (no rates seeded) | PASS |

Tally: 11/11 PASS (1 with a minor finding).

## Findings

1. **EUR rejection error message lists an empty enum** — `PUT /api/stores/{id}` with `{"currency":"EUR"}` returns `"currency must be one of the following values: "` with a trailing colon and no values. The mechanism (rejection) is correct, but the message is unhelpful — it should enumerate `TJS, USD, RUB`. Likely the `@IsEnum` decorator is being passed something other than the enum object, or `class-validator`'s default formatter is broken for this case. **Severity: P3 cosmetic.**

2. **`/api/stores/{id}/settings` returns 404** — neither route is exposed at this path. If a store-settings UI screen is on the roadmap, the endpoint will need to be added. Not currency-related per se. **Severity: not a bug, just absent.**

3. **`/api/stores/{id}/reports/*` returns 403 "No subscription found for this store"** if no subscription row exists. This is intentional (SubscriptionGuard), but worth flagging — when seeding test stores via SQL, you must also seed a subscription row, otherwise reports look broken. Not currency-related, but tripped during this test. To make scenario 7 work I seeded a `BUSINESS / TRIAL` subscription for the USD store via raw SQL. **Severity: not a bug, ergonomic note for QA.**

4. **`/api/stores/{id}/currencies/rates` does NOT exist** (HTTP 404). The currencies module is mounted globally at `/api/currencies/*` (per `currencies.controller.ts` line 7: `@Controller('currencies')`). Routes available: `GET /rates`, `POST /rates/fetch`, `GET /rates/history`. **Severity: not a bug** — this matches the architectural intent (rates are global, not per-store).

5. **POST /sales DTO mismatch with the task description** — the task suggested `paymentMethod`, `cashReceived`, and an item-level `price` field, but the actual DTO uses `paymentType`, `paidAmount`, and items only carry `productId + quantity + optional discount` (server uses `product.sellPrice` for `unitPrice`). This was a doc gap in the task plan, not a real bug — the API itself worked fine once the correct payload was sent. **Severity: doc-only.**

## Architectural note

Currency is a per-store enum (TJS / USD / RUB), enforced at write boundary by the BUG #15 fix once any sale exists. Sale amounts are stored as bare `Decimal` columns — currency is contextual via `sale.store.currency`. There is no per-sale currency tag and no rate conversion at write time. The `currencies` module manages exchange rates globally (`/api/currencies/rates`) for display purposes only.

This design was confirmed end-to-end:

- Stores can be created in any of the three enum currencies (`USD/TJS/RUB`) — verified by direct INSERT and by `PUT` on a fresh store.
- `EUR` is rejected at the validation layer (enum gate), so unsupported currencies cannot leak in.
- Once a single sale is recorded, the currency becomes immutable on that store (BUG #15 fix). Verified twice: on the pre-seeded TJS store (24 sales) and on the freshly-seeded USD store (after creating 1 sale).
- Reports return bare numeric amounts — they do NOT carry a currency suffix. The client is expected to render the amount with the store's `currency` field as the unit.
- The currency-rates endpoint is global (`/api/currencies/rates`), not store-scoped.

No changes to production code were required; all five "must work" mechanisms work as designed.

## Artifacts

- `screenshots/01-dashboard.png` — full-resolution screencap
- `screenshots/01-dashboard-sm.png` — 1200px-wide preview

The screenshot is just a sanity check that the Android app launches; the substantive verification is the API/SQL evidence above.
