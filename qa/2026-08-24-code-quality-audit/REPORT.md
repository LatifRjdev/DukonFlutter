# General Code Quality & Tech-Debt Audit — 2026-08-24

Fresh, from-scratch audit of all three codebases (Flutter mobile app,
NestJS API, Next.js admin panel) — general code quality and tech debt
only, not security or production-readiness (those are separate audit
categories with their own prior reports in this directory, e.g.
`2026-05-22-owasp-sweep`, `2026-07-21-production-readiness`). Three
parallel agents each audited one codebase independently; findings below
are synthesized and cross-checked, with two claims independently
re-verified rather than taken at face value (see notes inline).

## Verdict

**All three codebases are in reasonably good shape — no findings rise to
"this needs an emergency fix."** The strongest codebase is the API:
uniformly thin controllers, every service has a test, and the team
visibly documents *why* behind non-obvious code. The admin panel is small
and internally consistent with genuine test coverage. The Flutter app has
strong baseline discipline (zero analyzer warnings, consistent
`flutter_bloc` usage in the large majority of features) but the most
consequential findings in the whole audit live here: two full feature
areas (delivery, notifications) that bypass the app's own architecture
entirely, and a 282-line dead database class that misrepresents what
offline-caching support actually exists.

The single biggest structural theme across all three codebases is **the
same shape of problem recurring at different layers**: no
repository/mapping layer in the API (raw Prisma entities — including once
a password hash — flow to HTTP responses), several Flutter features
calling the network client directly from presentation code instead of
through a repository, and a duplicated CRUD idiom in the API that already
caused one real cross-store IDOR bug once (documented in-code as
`BUG-CAT-IDOR`) and is now reimplemented independently in ~20 modules,
each carrying the same risk of reintroducing that exact bug.

One flagged item from the admin-panel audit — a claim that
`admin/AGENTS.md` contains a "planted" prompt-injection-style instruction
pointing to a nonexistent path — was independently re-checked and found
to be **inaccurate**: the referenced path (`node_modules/next/dist/docs/`)
genuinely exists and contains real Next.js 16.2.3 documentation. The file
is a legitimate (if unusual) practice — reminding AI coding assistants
that this Next.js version postdates their training data and to consult
the installed docs rather than stale knowledge — not malicious content.
Flagged here so the false-positive doesn't get treated as fact if this
report is read out of context.

---

## Cross-cutting: documentation/reality mismatch (High)

`.claude/rules/kmp-architecture.md`, `android-compose.md`,
`ios-swiftui.md`, and `database.md` (SQLDelight-specific parts) describe a
Kotlin Multiplatform + Jetpack Compose + SwiftUI + SQLDelight stack.
**None of this exists anywhere in the repository.** Confirmed: no
`shared/`, `commonMain/`, `androidMain/`, `iosMain/`, or `commonTest/`
directories exist outside `node_modules`; the only Kotlin/Swift files are
stock Flutter platform-runner boilerplate (`MainActivity.kt`,
`AppDelegate.swift`, both under 10 lines). The actual mobile app is 100%
Dart/Flutter using `flutter_bloc`, `get_it`+`injectable`, `sqflite` (not
SQLDelight), and `dio`.

This isn't just stale documentation — it's actively misleading for any
future agent or developer who treats `.claude/rules/` as ground truth
before touching the mobile codebase. `.claude/rules/sync-engine.md` and
`.claude/rules/security.md` map onto the real Flutter app reasonably well
and should stay; the other four should be deleted or explicitly
re-scoped as "not applicable to this repo."

**Recommendation:** delete or clearly quarantine `kmp-architecture.md`,
`android-compose.md`, `ios-swiftui.md`, and `database.md`'s SQLDelight
sections.

---

## Flutter app (`app/`, 349 lib files / 230 test files)

### High severity

- **Delivery feature bypasses the app's own architecture entirely.**
  `lib/presentation/pages/delivery/delivery_list_page.dart:13-107`,
  `delivery_detail_page.dart:97+`, `create_delivery_page.dart:64+` each
  define a private in-file model (`_Delivery`) and a private in-file
  Cubit that call `sl<DioClient>()` directly against
  `/stores/$storeId/deliveries`. No domain entity, no repository
  interface, no `data/repositories/` impl, no `presentation/blocs/`
  directory — a full 3-page, ~1,200-line feature area built entirely
  outside the pattern every other feature follows.
- **Notifications feature has the same problem.**
  `notifications_page.dart` calls `sl<DioClient>()` directly (line 154),
  does its own JSON parsing into a private `_AppNotification` class (line
  20), and manages loading/pagination/mark-read state via raw
  `setState()` instead of a bloc. `notification_settings_page.dart:19`
  does the same. Notably, `core/services/notification_service.dart` and
  `data/datasources/remote/notification_remote_datasource.dart` already
  exist, suggesting the "correct" plumbing was started elsewhere and
  abandoned for these two pages.
- **Dead `AppDatabase` class actively misrepresents offline support.**
  `lib/data/datasources/local/database.dart` (282 lines) is never
  instantiated anywhere — the real DB is wired independently via
  `_initDatabase()` in `injection.dart:547-561`. `AppDatabase`'s schema
  defines 10 tables including `customers`, `suppliers`, and
  `stock_movements`; the *real* schema only creates 5 tables
  (`products`, `sales`/`sale_items`, `categories`, `sync_queue`). Reading
  the dead file gives a false impression that customers/suppliers/stock
  have local offline caching. They don't — no local datasource exists
  for any of those three entities.
- **Local/offline datasource layer is almost completely untested**,
  despite being central to the app's stated offline-first design. Only
  one file exists under `test/**/local/*` (`auth_local_datasource_test.dart`)
  — `ProductLocalDatasourceImpl`, `SaleLocalDatasourceImpl`,
  `CategoryLocalDatasourceImpl`, `CartLocalDatasourceImpl`, and the
  schema-creation logic in `injection.dart` have zero tests.

### Medium severity

- **The `DioClient`-bypass pattern is systemic, not isolated to 2
  features** — 28 of ~82 presentation-layer files (~34%) import
  `core/network/dio_client` directly, including several *blocs*
  (`settings_bloc.dart`, `subscription_bloc.dart`, `debt_bloc.dart`,
  `customer_detail_bloc.dart`, `supplier_detail_bloc.dart`) calling HTTP
  directly instead of going through a repository interface — a
  repository-abstraction violation even where a bloc *is* used. Core
  high-traffic areas (products, sales, staff, POS checkout, stock)
  correctly use the repository pattern; the violation concentrates in
  delivery, notifications, and large parts of finance/settings.
- **84 files use `StatefulWidget`/`setState`**, and in several cases
  (`notifications_page.dart`, `notification_settings_page.dart`,
  `finance/currencies_page.dart:107,141`, `credits_page.dart:115,496`,
  `reports_page.dart:188`, `balance_page.dart:128`) this drives real
  network/business logic rather than pure UI state — exactly the pattern
  the bloc-centric testing convention is meant to prevent.
- **`finance/reports_page.dart` is a 1,997-line single-file monolith**
  with 6 private data models, 12 private widget classes, and 5+ separate
  direct `DioClient` calls for what should be 5 bloc-driven reports.
  Several other files exceed 500-900 lines (`subscription_page.dart` 938,
  `pos_checkout_page.dart` 897, `dashboard_page.dart` 883,
  `product_detail_page.dart` 823, `inventory_count_page.dart` 793) — not
  alarming individually, but `reports_page.dart` is a clear outlier.
- **Sync engine only covers offline writes, not reads, for most
  entities.** The sync engine itself (`data/sync/sync_engine.dart`,
  273 lines) is genuinely well-built — connectivity-triggered, FIFO,
  exponential backoff (2s→60s cap), composite `storeId:entityId` keys,
  respects `maxRetries=5`. But repositories write to the remote API
  *first* when online (not local-first as documented), and only 3 of 18
  repositories (`product`, `sale`, `category`) have both a sync queue
  *and* a local read cache. 5 more (`shift`, `customer`, `debt`, `stock`,
  `supplier`) can queue offline writes but have no local cache for
  reads. 10 repositories are online-only with no offline story at all.
- **4 declared Flutter dependencies are entirely unused:** `google_fonts`,
  `cached_network_image`, `shimmer`, `flutter_svg` — zero references to
  any of their exported symbols anywhere in `lib/`, and the app doesn't
  use SVG assets at all. Safe to remove pending a final confirm-grep.

### Low severity / positive findings

- No dead widgets, entities, models, or services found in sampling; zero
  commented-out code; zero `TODO`/`FIXME` markers anywhere in `lib/`.
- 18/18 repository interfaces have matching implementations; error
  handling in blocs consistently routes through `mapErrorToUserMessage()`
  (the one exception is `notifications_page.dart:169-172`, correlating
  with that file's other architecture violations above).
- Test coverage is stronger than a casual glance suggests — only 3 of 82
  pages have zero test coverage (`loyalty_analytics_page.dart`,
  `loyalty_settings_page.dart`, `cart_restore_prompt.dart`), and all 18
  repos plus all bloc/cubit files have matching tests.
- `flutter analyze`: 0 errors/warnings (6 minor info-level lints, all in
  one test file).

---

## NestJS API (`api/`, 531 TS files)

### High severity

- **No repository/mapping layer exists at all.** 37 services call
  `PrismaService` directly; there is zero repository abstraction
  anywhere in `src/`, a direct departure from
  `.claude/rules/api-integration.md`'s documented convention.
- **Raw Prisma entities are returned directly as API responses.**
  e.g. `modules/products/products.service.ts:196-204` returns the full
  Prisma `Product` (with relations) straight through the controller. The
  `*-response.dto.ts` files that exist (`stores`, `users`, `categories`)
  are Swagger-only decoration — referenced solely via
  `@ApiResponse({ type: ... })` — nothing in the request path actually
  constructs one or strips fields, so the documented shape can silently
  drift from the real payload.
- **Password hash returned in an admin API response.**
  `modules/admin/admin.service.ts:87-113` — `createUserManually()`
  creates a user with no `select`, so the returned object carries the
  full `User` row including the bcrypt `password` field, and
  `admin-users.controller.ts:60` returns it unmodified to the client.
  `users.service.ts:55` shows the correct pattern exists elsewhere
  (explicit `select`) — it just wasn't applied here.

### Medium severity (elevated to High-adjacent given the documented prior bug)

- **CRUD boilerplate — including the store-scoping check — is
  independently reimplemented in ~15-20 modules with no shared base.**
  `categories.service.ts:29-34` carries an in-code comment documenting
  **BUG-CAT-IDOR**: a real historical bug where `findOne`/`update`/
  `remove` once looked up by `id` alone without a `storeId` filter,
  letting any authenticated user access another store's category by
  guessing a UUID. Because this exact lookup idiom (`findFirst({where:
  {id, storeId}})` + manual `NotFoundException`) is hand-rolled ~20 times
  independently rather than centralized in one repository/base-service
  method, every one of those ~20 call sites carries the same risk of
  reintroducing that exact class of bug. This is the single
  highest-leverage refactor identified across all three codebases.
- **`AdminService` is a God Service** — 833 lines, 29 methods spanning
  7 unrelated sub-domains (users, stores, dashboard analytics, plan
  config, announcements, banners, audit logs), backing 8 separately-split
  controllers. Should mirror the controller split (the way
  `admin-export.service.ts` already is separated out).
- **Inconsistent HTTP status codes for "not found."** 81 call sites
  correctly use `NotFoundException` (404), but several equivalent checks
  use `BadRequestException` (400) instead — `sales.service.ts:86,111,130,142`,
  `auth.service.ts:156,166,174`. A client can't reliably distinguish
  "malformed request" from "resource doesn't exist" across endpoints.
- **Multi-step write without a transaction — orphan risk.**
  `staff.service.ts:23-84`'s `create()` creates a `User` then, as a
  separate unwrapped write, creates the `Staff` row. If the second write
  fails, an orphaned `User` with an unrecoverable random password is left
  behind. Notably the codebase demonstrates real care about this class of
  problem elsewhere (`sales.service.ts:255-280`'s documented `F-RACE-1`
  atomic-update comment, and correct `$transaction` usage in `sales`,
  `subscriptions`, `zakat`, `investments`, `roles`, `import-products`,
  `ecommerce-orders`, `inventory-counts`, `impersonation`, `loyalty`,
  `customers`, `suppliers`, `auth`) — this is an inconsistency in rigor,
  not a systemic gap.
- **`node-telegram-bot-api` pulls in a critically-vulnerable dependency
  chain.** Pinned at `0.67.0` (latest is `2.0.0`); transitively depends
  on the long-deprecated `request`/`form-data` packages. `npm audit`
  reports 48 vulnerabilities total (2 critical, 9 high, 37 moderate),
  the bulk from this chain plus a secondary chain through
  `firebase-admin`'s older `@google-cloud/storage` dependency. Flagged
  here as a dependency-hygiene item; a proper security review should
  size the actual exploitability.
- **Prisma schema: inconsistent typing for money/quantity fields and
  missing indexes on hot paths.** `Discount.value`/`minTotal` and
  `CurrencyRate`'s rate fields use `Float` where the rest of the schema
  consistently uses `Decimal(12,2)`; `InventoryCountItem` uses `Float`
  for qty fields while its sibling `InventoryItem` uses `Int` for the
  same concept. `Shift` has **no `@@index` at all** despite being a hot
  lookup path, and its `localId` idempotency-key comment isn't backed by
  the `@@unique([storeId, localId])` constraint that identical comments
  on `ZakatPayment`/`Investment`/`SupplierPayment`/`StockMovement` do
  have — the offline-replay idempotency the comment promises isn't
  actually enforced at the DB level for shifts. `Inventory` and
  `ExchangeRate` are also missing `storeId`-based indexes present on
  their sibling models.

### Low severity / positive findings

- Controllers are uniformly thin (sampled every controller; none exceed
  2 conditional branches) — a genuinely good, consistent pattern.
- No circular module dependencies; the global exception filter
  (`http-exception.filter.ts`) is solid and consistently used.
- **Every service has a matching spec file** — zero untested services
  across all 30 modules, a real strength. (Zero controller spec files
  exist, but given how thin they are, this is a defensible choice.)
- No dead code, no disabled/commented-out blocks, no orphaned migrations.
- N+1-shaped patterns found were deliberate and explicitly documented in
  comments (e.g. `stock-alerts.service.ts:66-68` — a once-daily batch
  job) rather than accidental — a positive signal.

---

## Next.js admin panel (`admin/`, 64 TS/TSX files)

### High severity

- **Sidebar "Log out" button does not actually log the admin out.**
  `components/sidebar.tsx:34-38` clears `localStorage` (a key that was
  never set there) and tries to clear the session cookie via
  `document.cookie = ...` — but the cookie is `httpOnly: true`
  (`app/api/auth/login/route.ts:27-33`), so client-side JS cannot clear
  it; the assignment silently no-ops. The *correct* logout path already
  exists (`app/login/page.tsx:42` calls `POST /api/auth/logout`, which
  does clear the cookie server-side) — the sidebar button just never
  calls it. Net effect: clicking "Выйти" redirects to `/login`
  visually, but the session remains valid.
- **`subscriptions/page.tsx` is a 673-line God Component** — 2 queries,
  7 mutation handlers (extend, change-plan, discount, manual-payment,
  cancel, approve, reject), ~11 pieces of local dialog/form state, and
  5+ inline dialog forms, all in one function component with no
  extraction. The single largest maintainability risk in this codebase.

### Medium severity

- **API response envelope handled inconsistently, with zero runtime
  type enforcement.** `lib/api.ts`'s `apiFetch` returns untyped JSON;
  some pages unwrap a paginated envelope (`r.data ?? []`:
  `users/page.tsx:57`, `stores/page.tsx:76`, `announcements/page.tsx:50`,
  `audit-log/page.tsx:137`) while others assume the raw response is the
  array itself (`subscriptions/page.tsx:89,94`, `subscriptions/plans/page.tsx:120`,
  `dashboard/page.tsx:61,66,71,76`). `banners/page.tsx:44` defensively
  guesses both shapes at once — itself evidence of the ambiguity. If a
  backend envelope shape ever changes, TypeScript won't catch it.
- **Status label/color maps for the same 5-value subscription-status
  enum are copy-pasted across 3 files** (`stores/page.tsx:42-56`,
  `stores/[id]/page.tsx:27-42`, `subscriptions/page.tsx:40-54`) with
  different variable names — a new status value requires updating all
  three by hand with nothing enforcing consistency.
- **`@tanstack/react-table` is a fully unused dependency** — zero
  imports anywhere despite being declared; the app hand-rolls its own
  `DataTable` instead, which currently lacks sorting/filtering that
  react-table would provide for free.
- **Dashboard and plans pages render fabricated random data during
  load.** `dashboard/page.tsx:29-56,79-80,172-173` generates
  `Math.random()`-based mock revenue/registration numbers and falls back
  to them (`revenueData ?? mockRevenue`) whenever the real query hasn't
  resolved — easy to mistake fake numbers for real ones mid-load. Same
  pattern in `subscriptions/plans/page.tsx:142-165` (fabricated
  49/99/199-somoni placeholder pricing).
- **Real test-coverage gaps** on `dashboard/page.tsx` (the landing
  page), `banners/page.tsx`, `announcements/page.tsx` (both are
  content-broadcast forms with real user-facing side effects), and
  `subscriptions/plans/page.tsx` — all with zero test files, in an app
  that otherwise has genuine MSW-backed behavioral tests (9 test files,
  ~1,508 lines) covering the API client, middleware, and most other
  pages. Looks like an oversight rather than a deliberate scoping choice.

### Low severity / positive findings

- App Router used exclusively and consistently; no leftover Pages
  Router. `tsconfig.json` has `strict: true`, and a grep for `any`
  across all non-test source returned **zero hits** — genuinely clean.
- Auth is centralized in `middleware.ts` (edge-level JWT verification),
  not duplicated per-page — architecturally sound apart from the logout
  bug above.
- `lib/types.ts` provides one shared set of domain types used
  consistently across components, not hand-duplicated per file.
- `qrcode.react` is also an unused dependency (same pattern as
  `@tanstack/react-table`); `shadcn` (the CLI codegen tool) is listed
  under `dependencies` instead of `devDependencies`.
- `banners.tsx`/`announcements.tsx` bypass the shared `DataTable`
  component that 4 other list pages use, hand-rolling raw table markup
  instead — losing pagination/loading-skeleton behavior for free.
- The `admin/AGENTS.md` "planted instruction" claim from the initial
  audit pass was independently re-checked and found to be a false
  positive (see Verdict section above) — no action needed.

---

## Prioritized follow-up (highest leverage first)

1. **API: centralize the store-scoped-lookup CRUD idiom** into a shared
   base service or repository helper. This is the one change that would
   simultaneously fix the DTO/response-shaping gap, reduce ~20 modules'
   worth of duplicated code, and close off the exact bug class that
   already happened once (`BUG-CAT-IDOR`).
2. **API: fix the password-hash leak** in
   `admin.service.ts:createUserManually()` — add an explicit `select`
   or map through a response DTO before returning.
3. **Admin: fix the sidebar logout bug** — swap the broken
   client-side-only clear for the existing working `POST
   /api/auth/logout` call already used on the login page.
4. **Flutter: delete the dead `AppDatabase` class**, or wire it in and
   reconcile it with the real schema — it currently misrepresents what
   offline support exists for customers/suppliers/stock.
5. **Flutter: bring `delivery` and `notifications` into the standard
   architecture** (domain entity + repository + bloc) — the two clearest
   outliers, and both isolated enough to refactor independently without
   touching the rest of the app.
6. **Decide the fate of the KMP/Compose/SwiftUI rule files** — delete or
   explicitly mark not-applicable so future agents don't take them as
   ground truth for this Flutter-only repo.
7. Lower-priority cleanup: 4 unused Flutter packages, 2 unused admin
   packages, `node-telegram-bot-api`'s vulnerable dependency chain,
   Prisma schema type/index inconsistencies, `AdminService`/
   `reports_page.dart`/`subscriptions/page.tsx` God-object splits.

None of the above block a release or require emergency action — this is
a backlog-shaping report, not an incident report.
