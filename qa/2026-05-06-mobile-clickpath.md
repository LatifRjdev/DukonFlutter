# Mobile click-path audit — 2026-05-06

**Device:** Android emulator-5554 (Pixel-class, 1080×2400, API 36)
**APK:** `app-debug.apk` from current `main` (commit 178cc0a + Sentry/Kotlin fixes)
**Method:** ADB-driven taps + `screencap` + logcat watch for `AndroidRuntime FATAL EXCEPTION`

## Summary

- Screens reached: 14 (login, create store, all 5 bottom-nav tabs, Ещё submenu, sales history attempted)
- Hard crashes (`FATAL EXCEPTION`): **0**
- Suspicious behavior: **2** (one near-certain bug, one UX smell)

## Flow walked

| # | Screen | HTTP/state | Crash? | Notes |
|---|---|---|---|---|
| 00 | Cold launch → splash → login | OK | ❌ | Splash skipped because seed admin already onboarded. Land on login. |
| 01 | Login form, enter credentials `+992 000000000` / `admin123` | OK | ❌ | Phone field accepts numeric, password masked. |
| 02 | Войти button → "Создать магазин" | OK | ❌ | Admin had no store → forced to create-store gate. |
| 03 | Fill `Test Shop` + scroll, "Создать магазин" submit | OK | ❌ | Submit fires POST /api/stores → 201, store id `3561d14d-…`. |
| 04 | Land on dashboard (Касса tab) | OK | ❌ | "Test Shop", "0 TJS", Сегодня/Неделя/Месяц switcher, Прибыль/Себестоимость/Расходы cards, "+ Новая продажа" CTA. |
| 10 | Tap Главная (109, 2271) | OK | ❌ | Same dashboard view; this tab is the home. |
| 11 | Tap Товары (270, 2271) | OK | ❌ | Empty state "Нет товаров", "Добавить товар" CTA, search bar, filters (Все/В наличии/Заканчивается/Нет в наличии), barcode scanner icon. |
| 12 | Tap Касса (540, 2271) | DUPLICATE | ❌ | Screenshot identical to 11. Either Касса button doesn't navigate from Товары, OR it's the same widget tree (POS lives inside products tab). See "Suspicious #2" below. |
| 13 | Tap Финансы (810, 2271) | OK | ❌ | Финансы dashboard with 8 tiles: Баланс / Кредиты / Вложения / Закят / Валюты / Доставка / Отчёт / Расходы. День/Неделя/Месяц/6мес switcher. Общий доход / Общие расходы / Валовая прибыль / Чистая прибыль cards. Динамика chart placeholder. |
| 14 | Tap Ещё (970, 2271) | OK | ❌ | Big drawer with sections: Продажи и Финансы (История продаж, Финансы, Расходы, Долги, Закят), Персонал (Сотрудники, Смены, Зарплата, Роли и права), Контрагенты (Клиенты, …). |
| 15 | Tap "История продаж" item | LOGGED OUT | ❌ | Landed back on login screen. See "Suspicious #1" below. |

## Suspicious #1 — Silent logout on idle, no token refresh attempted

**Timeline:**
- Login at 10:10 (access token issued)
- Tabs walk completed at 10:38 (28 min later)
- Returned to test sub-screen at 11:15 (65 min after login)
- App at 11:15: showing login screen, fields cleared

**API log evidence:** Between login (`POST /api/auth/login` 200) and the next user action, the API received **zero 401s and zero `POST /api/auth/refresh` calls**. So either:
- The mobile app pre-emptively logged the user out by checking the JWT `exp` claim locally and never tried to refresh, OR
- The refresh attempt was made and failed before hitting the network.

**Why this matters:** access tokens are configured for 15 min TTL. Real users will leave the app idle for an hour and come back to find themselves logged out, even though the refresh token (likely 7d TTL) is still valid. This breaks the offline-first promise — a working POS shouldn't kick you out during a slow shift.

**Recommended next step:** read `app/lib/data/datasources/local/auth_local_datasource.dart` and `app/lib/core/network/api_interceptor.dart`. The interceptor should retry once on 401, hitting `/api/auth/refresh` with the stored refresh token, and only force-logout if refresh itself returns 401.

**Severity:** P1. Not a crash, not a security regression, but it actively breaks user experience and there's a real chance the refresh interceptor is never wired in.

## Suspicious #2 — Касса bottom-nav button visually permanent, doesn't act as a tab switch

**Symptom:** the central nav button (giant purple cash register icon) renders the same on every screen, regardless of which tab is selected. The actual selected indicator is the small icon + label on the other 4 tabs (e.g. on Финансы, "Финансы" text turns purple). Касса's own visual state never reflects whether it's the active tab.

After tapping Товары then Касса, screenshot is identical to the Товары screenshot. Two interpretations, both possible:

1. **Intentional FAB design** — Касса is permanently a "primary action" floating-style button that triggers a modal/sheet, not a tab. The tap on Касса (540, 2271) might be opening the new-sale flow on top of whatever screen you're on, but if there are no products to sell, it falls through and nothing visible changes.
2. **Genuine routing bug** — the Касса route handler stays on whatever tab you came from when there are no products; the button is just a no-op in that empty state.

**Recommended next step:** read `app/lib/presentation/widgets/common/app_bottom_nav_bar.dart` and the home shell to see if Касса tab maps to a route or fires an action. Add at least an "empty cart" state so users get visual feedback.

**Severity:** P2. Not blocking; works fine once products exist.

## What the audit did NOT cover (out of scope today)

- Add product flow end-to-end (camera/gallery upload, saving)
- POS new-sale flow with multiple items
- Customer add + debt management
- Shifts open/close
- Reports export (PDF/Excel)
- Telegram bot send-receipt
- Bluetooth printer
- Offline mode + sync queue

The app is open, logged in (after re-login) and ready for these to be tested manually if needed.

## Artifacts

- Screenshots: `/Users/latifrjdev/Downloads/01_Проекты/Dukon/app/qa/screenshots/20260506-2202/*.png`
- Sibling reports: `qa/2026-05-06-api-audit.md`, `qa/2026-05-06-admin-audit.md`
