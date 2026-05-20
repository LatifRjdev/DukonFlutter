# Dependency audit — 2026-05-16 (Spec F C)

## Backend (api/)

### npm audit before / after `npm audit fix`

Before: 21 high / 18 moderate / 8 low (plus 4 critical) — **51 total**
After:  3 high / 5 moderate / 8 low (plus 2 critical) — **18 total**

Net: closed **33 advisories** (18 high, 13 moderate, 2 critical) without breaking changes.

Tests after fix: 226 unit pass, 11 e2e pass. `package.json` unchanged — only
`package-lock.json` moved transitive deps within their declared semver ranges
(@nestjs/* 11.0.x → 11.1.x, @prisma/* 6.19.2 → 6.19.3, @sentry/* 10.50 → 10.53,
@nuxt/opencollective, brace-expansion, protobufjs, etc.).

### Outstanding npm advisories (no fix without breaking change)

The 18 remaining advisories cluster into 4 transitive trees. Each tree can
only be cleared by a major-version bump of the direct dependency (forbidden by
this task) or by replacing the dependency entirely. They are tracked as
follow-up specs.

| # | Direct dep | Vuln chain | Top severity | Net advisories | Why deferred |
|---|------------|-----------|--------------|----------------|--------------|
| 1 | `firebase-admin@11.x` | `@google-cloud/{firestore,storage}` → `google-gax` → `teeny-request` → `http-proxy-agent` → `@tootallnate/once` (GHSA-vpq2-c234-7xj6); plus `retry-request` | low × 8 | 8 | `npm audit fix --force` proposes `firebase-admin@10.3.0` — a **downgrade** across a major boundary (we are on 11.x). Real fix is firebase-admin major upgrade (12+) which changes the Admin SDK init API. |
| 2 | `node-telegram-bot-api@0.67.0` | `@cypress/request-promise` → `request-promise-core` → `request` (GHSA-p8p7-x288-28g6 SSRF, **critical**) → `form-data` (GHSA-fjxv-7rqg-78g4 unsafe random boundary, **critical**), `qs` (GHSA-6rw7-vpxm-498p ReDoS), `tough-cookie` (GHSA-72xf-g2v4-qvf3 proto-pollution) | **critical** × 2 | 7 | `npm audit fix --force` proposes `node-telegram-bot-api@0.63.0` — downgrade across major. The 0.6x line still depends on legacy `request` (deprecated since 2020). Proper fix = swap the lib (e.g. grammy/Telegraf) or wait for upstream to drop `request`. |
| 3 | `bcrypt@5.1.1` | `@mapbox/node-pre-gyp@1.0.11` → `tar@6.2.1` (six tar advisories: GHSA-34x7-hfp2-rc4v, GHSA-8qq5-rm4j-mr97, GHSA-83g3-92jg-28cx, GHSA-qffp-2rhf-9h96, GHSA-9ppj-qmqm-q256, GHSA-r6q2-hw4h-h46w) | high | 2 | `npm audit fix` claims a fix is available but resolution is blocked behind `bcrypt@6.0.0` (the only published version that ships a tar-7-aware `node-pre-gyp`). Risk: Linux glibc compat + rebuilt password hashes — needs its own validation pass. |
| 4 | `xlsx@0.18.5` (SheetJS Community) | direct: GHSA-4r6h-8v6p-xvw6 (proto-pollution), GHSA-5pgg-2g8v-p4x9 (ReDoS) | high | 1 | **No fix available on npm** — SheetJS moved to a self-hosted CDN. Workaround tracked elsewhere is to migrate to `exceljs` or pull SheetJS from the cdn registry. |

**Mitigation already in place:**
- `request`/`form-data`/`tough-cookie`/`qs` advisories are reachable only via
  `node-telegram-bot-api` outbound calls to api.telegram.org — no untrusted
  attacker input flows through these dependencies in our usage.
- `tar` advisories are reachable only at install time (bcrypt prebuild
  download). Production runtime is unaffected; CI installs run against the
  pinned lockfile.
- `xlsx` is used only to ingest admin-uploaded product catalogs — we already
  size-cap and run uploads through `class-validator`. ReDoS surface is bounded
  by the upload-size middleware.

### Major-version outdated (deferred — each is its own follow-up spec)

Source: `npm outdated --long` (output in `/tmp/outdated.txt` at audit time).

| Package | Current | Latest | Risk |
|---------|---------|--------|------|
| `@prisma/client` / `prisma` | 6.19.3 | 7.8.0 | Prisma 7 drops Node 18 support, reworks `$transaction` interactive API, and changes raw-query type inference. Needs schema-level QA pass. |
| `bcrypt` | 5.1.1 | 6.0.0 | New native binding (node-pre-gyp 2.x). Requires CI prebuild verification across Linux glibc / Alpine / macOS arm64. Would clear the `tar` advisories above. |
| `@types/bcrypt` | 5.0.2 | 6.0.0 | Pinned to bcrypt major. Bump together. |
| `node-telegram-bot-api` *(library swap)* | 0.67.0 | 0.67.0 | Latest is already in use; no upgrade clears the `request` tree. Migration is to a different library (grammy/Telegraf). Tracked separately. |
| `eslint` | 9.39.2 | 10.4.0 | ESLint 10 drops `.eslintrc` in favor of flat config — we are already on flat config (`eslint.config.mjs`), so risk is moderate but the `@eslint/js` and `typescript-eslint` matrices need joint upgrade. |
| `@eslint/js` | 9.39.2 | 10.0.1 | Bump with `eslint` above. |
| `typescript` | 5.9.3 | 6.0.3 | TS 6 tightens `strict` checks and reworks moduleResolution defaults. Likely to surface new errors in tests that already have 15 known `strictNullChecks` warnings in spec files. |
| `@types/node` | 22.19.7 | 25.8.0 | Node 25 type defs; we deploy on Node 22 LTS — pin to 22.x. |
| `@types/multer` | 1.4.13 | 2.1.0 | Matches `multer@2` rewrite (`multer` itself is still on 1.x in our tree). Bump together with `multer`. |
| `@types/supertest` | 6.0.3 | 7.2.0 | Aligns with supertest 7.x (we are already on 7.2.2 — `@types` mismatch is harmless but should be aligned). |
| `class-validator` | 0.14.3 | 0.15.1 | 0.x library — treated as major. Decorator metadata API change affecting nested validation. Full DTO pass required. |
| `globals` | 16.5.0 | 17.6.0 | ESLint flat-config globals — low risk, tag along with eslint 10 bump. |
| `uuid` | 10.0.0 | 14.0.0 | Switched to native-randomUUID-first impl + ESM-only entry. Used in many places (idempotency keys, sync queue) — needs import audit. |

(Patch / minor bumps such as `@eslint/eslintrc`, `@nestjs/schedule`,
`@nestjs/testing`, `@sentry/*`, `ioredis`, `jest`, `prettier`, `ts-jest`,
`ts-loader`, `typescript-eslint`, `@nestjs/*` 11.0 → 11.1 were absorbed by
`npm install` reconciling the lockfile against the existing `^` ranges. No
package.json edits needed.)

### Verification

- `npx tsc --noEmit`: 15 pre-existing errors in `*.spec.ts` files
  (`health.controller.spec.ts`, `notifications.service.spec.ts`,
  `payroll.service.spec.ts`) — same count as before this task; tracked as
  pre-existing tech debt unrelated to the audit fix.
- `npm test`: 30 suites, **226 / 226 pass**.
- `npm run test:e2e`: 4 suites, **11 / 11 pass**.

## Flutter (app/)

### `pub upgrade` before / after

Source: `flutter pub outdated --no-dependency-overrides` snapshots
(`/tmp/pub-outdated-pre.txt`, `/tmp/pub-outdated-post.txt`).

Before: **73 packages outdated** — 34 within-constraint (Upgradable > Current),
39 constrained (Resolvable behind Latest). Split across direct / dev /
transitive: 25 direct deps, 4 dev deps, 44 transitives carried `*` in
`Current`.

After:  **39 packages outdated** — 0 within-constraint remain (every
Upgradable now matches Current), 39 still constrained to older than
Resolvable. Direct deps still behind: 16. Dev deps still behind: 4.

Net: bumped **37 packages within constraint** (per `pub upgrade` output:
"Changed 37 dependencies!"). `pubspec.yaml` untouched — only `pubspec.lock`
moved transitive + direct versions inside the existing `^` ranges. Three
brand-new transitives pulled in by upgraded plugins: `jni`, `jni_flutter`,
`record_use` (all carried by `mobile_scanner` / `pdf` indirect deps as build
metadata).

Representative bumps (direct deps): `cupertino_icons` 1.0.8 → 1.0.9,
`dio` 5.9.1 → 5.9.2, `flutter_svg` 2.2.3 → 2.3.0, `image_picker` 1.2.1 →
1.2.2, `pdf` 3.11.3 → 3.12.0, `printing` 5.14.2 → 5.14.3,
`shared_preferences` 2.5.4 → 2.5.5, `sqflite` 2.4.2 → 2.4.2+1,
`uuid` 4.5.2 → 4.5.3. Plus 28 transitive bumps (notably `bloc` 9.2.0 →
9.2.1, `built_value` 8.12.3 → 8.12.6, `objective_c` 9.2.5 → 9.3.0,
`url_launcher_ios` 6.3.6 → 6.4.1, `vector_graphics` 1.1.19 → 1.2.2,
`vm_service` 15.0.2 → 15.2.0, several Android `_android` plugin patches).

### Golden re-baselines

**0 goldens re-baselined.** All 441 tests (including the goldens added in
Spec E: `MonthSelector`, `OnboardingSlide`, `ShiftCard`, `CurrentShiftCard`
in both light and dark themes) passed unchanged. No pixel drift from any of
the bumped transitives — `flutter`, `vector_graphics`, `google_fonts`, and
the `material_color_utilities` stack were all already at the resolved
(unchanged) versions, so theme tokens and font rendering did not move.

### Major-version outdated (deferred — each its own follow-up spec)

Source: `flutter pub outdated --no-dependency-overrides` (post-upgrade
snapshot in `/tmp/pub-outdated-post.txt`). Listed where `Current →
Resolvable` crosses a major boundary (or a 0.x minor boundary, treated as
major per semver).

| Package | Current | Latest | Risk |
|---------|---------|--------|------|
| `connectivity_plus` | 6.1.5 | 7.1.1 | v7 drops Android <21 (we already require 21+), but changes the `ConnectivityResult` enum to a `List<ConnectivityResult>` everywhere — touches the sync engine's connectivity gating. |
| `firebase_core` | 3.15.2 | 4.9.0 | v4 requires Firebase iOS SDK 11.x and bumps Android Gradle plugin minimum. Coordinated bump with `firebase_messaging` below. |
| `firebase_messaging` | 15.2.10 | 16.2.2 | v16 pins to `firebase_core` 4.x. APNs token API changed; FCM background handler signature tightened. Needs paired QA on push notifications. |
| `fl_chart` | 0.69.2 | 1.2.0 | 1.0 release rewrites `LineChartBarData` / `BarChartGroupData` constructors and removes deprecated `extra` params. Visual regression risk on the analytics dashboards — goldens may need re-baselining. |
| `flutter_local_notifications` | 18.0.1 | 21.0.0 | v19/20/21 staged breaking changes: notification channel APIs split per platform, `NotificationDetails` no longer accepts null `iOS`/`android` together. Re-test scheduled-reminder feature end-to-end. |
| `flutter_secure_storage` | 9.2.4 | 10.2.0 | v10 splits Darwin platform into its own package and requires new iOS Keychain accessibility config. Auth token storage is critical — needs migration test plan (existing tokens must continue to decrypt). |
| `freezed_annotation` + `freezed` | 2.4.4 / 2.5.8 | 3.1.0 / 3.2.5 | v3 changes generated code shape (no more implicit `copyWith` for sealed members, mandatory pattern-matching). Re-run `build_runner` across every freezed model; expect generated-file churn in DTOs. |
| `get_it` | 8.3.0 | 9.2.1 | v9 removes `signalsReady` API and tightens scope lifecycle. DI registration in `injection.dart` needs audit. |
| `go_router` | 14.8.1 | 17.2.3 | v15→16→17 each shipped routing breakage: `GoRoute.redirect` signature change, `StatefulShellRoute` rebuild semantics, removal of `routerNeglect`. Touches every route in `app_router.dart`. |
| `google_fonts` | 6.3.3 | 8.1.0 | v7 + v8 change font caching to use platform paths (new permissions on Android 13+). Possible first-launch UX regression if fonts re-download. |
| `injectable` + `injectable_generator` | 2.7.1+4 / 2.7.0 | 3.0.0 / 3.0.2 | v3 changes `@injectable` annotation defaults and the env-based registration API. Paired with `freezed` 3 — both gen libs should bump in one spec. |
| `json_annotation` + `json_serializable` | 4.9.0 / 6.9.5 | 4.12.0 / 6.14.0 | Marked discontinued direction — needs joint bump with `freezed` 3 to avoid generator mismatch. Patch-looking but generated code shape may change. |
| `mobile_scanner` | 6.0.11 | 7.2.0 | v7 reworks `MobileScannerController` lifecycle and removes the deprecated `formats` param. POS barcode flow needs full regression test (Android + iOS camera). |
| `permission_handler` | 11.4.0 | 12.0.1 | v12 drops iOS 11 and reworks `Permission.bluetooth*` granularity for Android 12+. Bluetooth-printer integration needs re-test. |
| `sentry_flutter` + `sentry` | 8.14.2 | 9.20.0 | v9 changes the `Sentry.init` options API (renamed `dsn` builder, new tracing config). Crash-reporting must be validated after bump. |
| `share_plus` (+ platform interface) | 10.1.4 | 13.1.0 | v11→12→13 each bumped Android `manifest` requirements (`FileProvider` config) and changed `Share.shareXFiles` signatures. PDF receipt sharing flow needs test. |
| `build_runner` | 2.5.4 | 2.15.0 | Still 2.x but jumps multiple minor versions that gated behind `analyzer 8.x`. Pulls in `_fe_analyzer_shared 91.x` and `analyzer 8.4.1`. Tag along with the `freezed` 3 / `injectable` 3 spec. |

(Transitive-only majors — `archive` 3 → 4, `firebase_core_platform_interface`
6 → 7, `firebase_messaging_platform_interface` 4.6 → 4.7,
`flutter_local_notifications_*` cluster, `flutter_secure_storage_*` cluster,
`xml` 6 → 7, `analyzer` 7 → 13, `build` 2 → 4, `source_gen` 2 → 4 — will
move automatically once their direct-dep majors above are bumped.)

Three transitive packages are marked **discontinued** by their authors and
will be removed once their direct parents drop them: `js` (replaced by
`dart:js_interop`, blocked on Firebase web SDK), `build_resolvers` and
`build_runner_core` (replaced by `build` 4.x, blocked on `build_runner` 2.15
spec above).

### Verification

- `dart analyze lib/`: **No issues found.** (0 issues — same as baseline.)
- `flutter test --reporter=compact`: **441 / 441 pass** (matches Spec E
  baseline; includes all golden tests with no re-baselining required).
- `pubspec.yaml` unchanged. `pubspec.lock` is the only source-controlled
  delta (160 lines: +92 / -68).
