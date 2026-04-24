# DukonPro Production-Readiness Report — 2026-04-23

## Sprint 1 Progress Update — 2026-04-24

**Статус: 🟡 YELLOW** (10 из 14 blocker-ов закрыто; 3 ждут user-gate; 1 downgrade → HIGH).

| # | Blocker | Слой | Commit | Статус |
|---|---|---|---|---|
| M#4 | iOS Info.plist usage descriptions | mobile | `0c2e3d5` | ✅ closed |
| M#6 | Sync retry without exponential backoff | mobile | `23fbdb6` | ✅ closed |
| M#7 | Hardcoded Russian UI strings | mobile | — | ⚠️ DEFERRED → Sprint 2 (396 strings, ru-only OK to ship) |
| A#1 | JWT in localStorage (XSS) | admin | `7065522` | ✅ closed |
| A#2 | No security headers | admin | `920f3b3` | ✅ closed |
| A#3 | isAdmin not in middleware | admin | `7065522` | ✅ closed |
| I#1 | Containers run as root | infra | `0fc1fe2` | ✅ closed |
| I#2 | No healthchecks | infra | `0fc1fe2` | ✅ closed |
| I#3 | No /api/health endpoint | infra | `0fc1fe2` | ✅ closed |
| M#1 | Package name mismatch | mobile | — | 🔐 GATE 0a (Firebase) |
| M#2 | Firebase API key leaked | mobile | — | 🔐 GATE 0a (Firebase) |
| M#3 | Firebase.initializeApp() missing | mobile | — | 🔐 GATE 0a (Firebase) |
| M#5 | No crash reporting (Sentry) | all | — | 🔐 GATE 0b (Sentry DSNs) |
| M#8 | No store metadata | mobile | — | 🔐 GATE 0d (privacy URL, screenshots) |

**Что unblocks запуск:**
- GATE 0a (Firebase rotation) → закрывает M#1, M#2, M#3
- GATE 0b (3 Sentry DSNs) → закрывает M#5
- GATE 0d (store metadata) → закрывает M#8

После этих gate-ов Sprint 1 официально закрыт и можно подавать в стор на ru-only.

---

## TL;DR (изначальный audit)

**🔴 НЕ ГОТОВ К ПРОДУ.**

| Слой | 🔴 BLOCKER | 🟠 HIGH | 🟡 MEDIUM | 🟢 LOW | Verdict |
|---|---|---|---|---|---|
| Backend (NestJS) | 0 | 5 | 6 | 2 | 🟡 YELLOW — чище всех, фиксится за день |
| Admin panel (Next.js) | 3 | 6 | 5 | 4 | 🔴 BLOCKED — auth уязвим к XSS |
| Mobile (Flutter) | 8 | 6 | 7 | 4 | 🔴 NO-GO — стор отклонит submission |
| Infra + observability | 3 | 8 | 9 | 4 | 🔴 NOT READY — root-контейнеры, нет бэкапов |
| **Итого** | **14** | **25** | **27** | **14** | **🔴 RED** |

Всего 80 findings. Основная работа — 14 blocker-ов (~5-10 рабочих дней) и 25 HIGH (~2-3 недели параллельно).

---

## 🔴 BLOCKER-list (14 пунктов — до запуска)

### Mobile (8 blockers — основная боль)

1. **Mismatch package name** — Gradle `com.itlsolutions.dokonpro` vs `google-services.json` `com.itlsolutions.dukonpro`. FCM не инициализируется в release. [`build.gradle.kts:27`](app/android/app/build.gradle.kts#L27)
2. **Firebase API key закоммичен в репо** — `AIzaSyA8uwf4buni-9P4NcV7sBXgMyEB58hnX54`. Ротировать + проверить git history. [`google-services.json:18`](app/android/app/google-services.json#L18)
3. **`Firebase.initializeApp()` не вызывается**, но `FirebaseMessaging.instance.getToken()` дергается → runtime crash / silent token failure.
4. **iOS: нет `NSCameraUsageDescription` и `NSPhotoLibraryUsageDescription`** в Info.plist → App Store отклонит upload.
5. **Нет crash reporting** — ни Crashlytics, ни Sentry. Любой прод-краш невидим.
6. **Sync retry без exponential backoff** — при reconnect все failed items летят одновременно, DOS на сервер.
7. **Hardcoded Russian labels по всему UI** — dashboard, shifts, customer form, POS receipt. В tg/uz локалях всё рендерится по-русски. Sprint 6-7 закрыл ~70 строк, осталось ещё ~100+.
8. **Нет стор-метаданных** (fastlane/ / privacy policy URL / скриншоты / описание) — обязательно для обоих сторов.

### Admin panel (3 blockers)

9. **JWT в `localStorage`** + cookie без `HttpOnly/Secure`. Один XSS = кража всех админ-сессий. Нужен server-set httpOnly cookie.
10. **Нет security headers** (CSP, X-Frame-Options, HSTS). [`next.config.ts`](admin/next.config.ts) пустой.
11. *(часть #9)* — `isAdmin` проверяется только в браузере; middleware пропускает любой валидный JWT.

### Infra (3 blockers)

12. **Все контейнеры запускаются от root** — api/admin/Dockerfile без `USER app`.
13. **Нет healthcheck-ов** на api/admin/nginx (только postgres); admin депендит на api по startup, не по readiness.
14. **Нет `/api/health` endpoint** — балансировщику/docker healthcheck некуда стучаться.

---

## 🟠 HIGH-list (25 пунктов — первые 2 недели)

### Backend (5)

- `.env.backup` не в `.gitignore` — потенциальный leak креденшелов через git history.
- **Swagger `/api/docs` открыт в проде** — полная схема API + bearer auth flow наружу. Обернуть в `NODE_ENV !== 'production'`.
- Prisma `connection_limit` не задан — под нагрузкой выжрет Postgres `max_connections`.
- Загрузки чеков используют client-trusted MIME тип (`file.mimetype.match(...)`) — обход через подделку header. Нужна magic-byte валидация.
- Excel-импорт продуктов без `limits.fileSize` и `fileFilter` — unbounded upload.

### Admin (6)

- Нет error boundary / `error.tsx` — любая ошибка в любой странице = белый экран.
- API-ошибки silently swallowed — `data = []` default скрывает сетевые фейлы под "пусто".
- Нет fetch timeout — повисший API = залипший UI навсегда.
- Нет confirmation-диалогов на **destructive actions**: block user, revoke admin, suspend store, cancel subscription, approve payment.
- Нет валидации login формы (zod + react-hook-form), телефон без формата `+992`.
- Нет token refresh на 401 — мид-сессия выбросит админа с потерей работы.

### Mobile (6)

- `Dio LogInterceptor` логирует full request/response bodies (включая JWT, PII) **в release** build'е тоже.
- Release signing fallback на debug key если нет `key.properties` — Play Store reject.
- `SyncEngine.dispose()` нигде не вызывается, StreamController течёт весь lifecycle.
- `scheduleNotification` использует `Future.delayed` без lifecycle-guard.
- Android `ACCESS_FINE_LOCATION` без justification → privacy review от Play.
- `flutter_lints` единственный анализатор, `strict-casts/inference/raw-types` не включены.

### Infra (8)

- Образы копируют `node_modules` с devDeps в runtime stage (api + admin).
- Admin Dockerfile не использует Next standalone output — огромный образ.
- Нет `.dockerignore` (`.git`, `tests`, `*.md`, dist — всё попадает в контекст).
- Нет resource limits — одна runaway служба = OOM всего VPS.
- **Backup локальный** на том же VPS (`/data/backups`). Потеря VPS = полная потеря данных. Нужен offsite (S3 / rclone).
- `/uploads` volume не бэкапится вообще (только Postgres).
- Нет cron для backup.sh — запускается руками.
- **`prisma migrate deploy` запускается ПОСЛЕ старта нового контейнера** в `deploy.sh`. Окно старого кода против новой схемы или наоборот.
- Nginx без security headers (HSTS/X-Frame-Options/CSP для admin статики), без edge rate-limit на `/auth/*`, слабая TLS конфигурация.
- Нет Sentry/Bugsnag ни в одном из 3 слоёв.
- Нет metrics pipeline (Prometheus/Grafana).
- Нет npm audit / Trivy / CodeQL в CI.

---

## Что делать (roadmap в 4 недели)

### Неделя 1 — Mobile + Security blockers

- [ ] Ротировать Firebase API key, добавить `google-services.json` в `.gitignore`, переписать git history через BFG если в истории.
- [ ] Выровнять applicationId на `com.itlsolutions.dokonpro` везде.
- [ ] Добавить `Firebase.initializeApp()` + `firebase_options.dart` (generated).
- [ ] Добавить `NSCameraUsageDescription` + `NSPhotoLibraryUsageDescription` в iOS Info.plist.
- [ ] Интегрировать Sentry во все 3 слоя (`@sentry/nestjs`, `@sentry/nextjs`, `sentry_flutter`).
- [ ] Прогнать локализационный sweep mobile app'а — добить оставшиеся ~100 hardcoded строк в ru/tg/uz arb.
- [ ] Переписать admin auth: httpOnly cookie set server-side, JWT decode + isAdmin check в middleware.ts.
- [ ] Добавить security headers в `next.config.ts` + nginx.

### Неделя 2 — Infra blockers + HIGH

- [ ] `USER app` во всех Dockerfile'ах; `.dockerignore` расширить.
- [ ] `/api/health` endpoint (`@nestjs/terminus`) + healthcheck-и в docker-compose для api/admin/nginx.
- [ ] Offsite backups (S3 + cron), бэкап uploads volume.
- [ ] Prisma migrate → one-shot container ПЕРЕД `up -d`.
- [ ] Resource limits в compose.
- [ ] Скрыть Swagger в проде, пофиксить `.env.backup`.
- [ ] Prisma connection_limit.
- [ ] Nginx: TLS hardening, HSTS, edge rate-limit на /auth.

### Неделя 3 — HIGH + UX safety

- [ ] Confirmation dialogs на destructive actions в админке.
- [ ] Error boundaries + proper error states во всех admin pages.
- [ ] fetch timeout + token refresh flow на клиенте админки.
- [ ] Sync engine exponential backoff в mobile app.
- [ ] Dio LogInterceptor за `kDebugMode` guard.
- [ ] Android release signing — throw если нет key.properties.
- [ ] Стор-метаданные (privacy policy, скриншоты, описание).

### Неделя 4 — MEDIUM / стабилизация

- [ ] Accessibility второй проход secondary paths в mobile.
- [ ] Metrics pipeline (Prometheus + Grafana Cloud).
- [ ] Docker log rotation (size/max-file).
- [ ] CI: `npm audit`, Trivy image scan.
- [ ] Rollback script.
- [ ] Restore procedure + репетиция.

---

## Что уже хорошо (не переписывай, не ломай)

- **JWT rotation с replay detection** (backend auth) — редкий уровень качества для такого возраста проекта.
- **bcrypt cost=12, global ValidationPipe + whitelist, parameterized raw SQL** — базовая security гигиена.
- **CORS с явным callback-whitelist + boot-time config validation** — в проде `CORS_ORIGIN` обязателен.
- **Helmet с explicit CSP / HSTS / COOP / CORP** на API.
- **@nestjs/throttler** с per-endpoint overrides на auth routes.
- **Token storage в flutter_secure_storage** (Keychain / EncryptedSharedPreferences).
- **Sync queue, transaction-based audit log** — архитектура в целом здоровая.
- **Admin panel functional**: все 15 endpoint-ов wired, DTO-mismatches после сегодняшнего аудита закрыты.

---

## Ссылки на оригинальные findings-отчёты

Полные скан-отчёты лежат в памяти этой сессии. Ключевые файлы для старта работы:

- Backend: `api/src/main.ts`, `api/src/modules/auth/`, `api/prisma/schema.prisma`
- Admin: `admin/lib/api.ts`, `admin/middleware.ts`, `admin/next.config.ts`
- Mobile: `app/lib/main.dart`, `app/lib/data/sync/sync_engine.dart`, `app/android/app/build.gradle.kts`, `app/ios/Runner/Info.plist`
- Infra: `docker-compose.yml`, `api/Dockerfile`, `admin/Dockerfile`, `scripts/deploy.sh`, `nginx/conf.d/default.conf`
