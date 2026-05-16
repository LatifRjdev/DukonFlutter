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

(Populated in Task C.2)
