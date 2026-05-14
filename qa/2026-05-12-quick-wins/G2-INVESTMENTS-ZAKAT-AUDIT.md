# G.2 — Investments / Zakat Deep Audit — 2026-05-14

## Scope

8-check backend matrix per module (`investments` + `zakat`) plus a
Flutter sweep covering `zakat_calculator_page.dart` formula,
`zakat_history_page.dart` + `zakat_settings_page.dart` UX, and
`investment_bloc/` state machine + ROI math.

Inline fixes (this spec): all P1 findings get fixed in commits
listed in the "P1 fix-list" section. P0 findings get same
treatment but none surfaced. P2 + P3 findings are documented
only — proposed fixes for follow-up sprints.

## Severity totals

| Severity | Count | Disposition |
|----------|------:|-------------|
| P0 | 0 | — |
| P1 | 9 | inline fix in this spec |
| P2 | 16 | documented, deferred |
| P3 | 13 | documented, deferred |

## Backend matrix

### Investments (`api/src/modules/investments/`)

| # | Check | Status | Severity | Note |
|---|-------|--------|----------|------|
| 1 | Routes + REST | PASS | — | POST/GET/GET summary/GET :id/PUT/DELETE; verbs + nesting under `/stores/:storeId/investments` correct. |
| 2 | JwtAuthGuard + CurrentUser | PASS | — | Class-level `JwtAuthGuard + StoreAccessGuard + PermissionsGuard`. |
| 3 | RBAC | PASS | — | Writes gated by `@Permissions('investments.write')` (OWNER/ADMIN). |
| 4 | @RequiresFeature | FAIL | P2 | No tier gate; `hasInvestments` flag absent. |
| 5 | DTO validation | FAIL | **P1** | `amount` and `returnAmount` lack `@IsPositive`/`@Min(0)`/`@Max`; pagination unbounded; `investorPhone` skips `+992` regex. |
| 6 | Service logic | FAIL | P2 | No `$transaction` on update/delete (TOCTOU); no `localId` idempotency; no audit log on money writes. |
| 7 | Schema constraints | FAIL | P2 | Missing `@@index([storeId, createdAt(sort: Desc)])`; no DB-level CHECK on Decimal columns. |
| 8 | Test coverage | FAIL | P2 | `create` and `update` (the only money-mutating paths) untested. |

### Zakat (`api/src/modules/zakat/`)

| # | Check | Status | Severity | Note |
|---|-------|--------|----------|------|
| 1 | Routes + REST | PASS | — | `GET/POST /stores/:storeId/zakat/{calculate,settings,payments}`. |
| 2 | JwtAuthGuard + CurrentUser | PARTIAL | P2 | Guards present but `@CurrentUser()` never injected → no actor identity for audit. |
| 3 | RBAC | PASS | — | Writes gated by `@Permissions('zakat.manage')` (OWNER+ADMIN). |
| 4 | @RequiresFeature | FAIL | **P1** | No `@RequiresFeature`; no `hasZakat` plan flag. Every paid tier (incl. START) gets full zakat. |
| 5 | DTO validation | FAIL | **P1** | `zakatRate` no `@Max(100)`; `nisabGold/Silver/Amount/totalAssets/zakatDue` lack `@Min(0)`; `nisabCurrency` missing from DTO entirely. |
| 6 | Service logic | FAIL | **P1** | (a) `createPayment` trusts client-supplied `zakatDue/totalAssets`; no idempotency; (b) no `AuditLogService.record()` on `upsertSettings` or `createPayment`; (c) `calculate` not in `$transaction` (5 sequential reads); (d) JS `Number` math on Prisma `Decimal` (rounding drift on large balances). |
| 7 | Schema constraints | FAIL | **P1** | `ZakatSettings.store` and `ZakatPayment.store` FKs use default `NoAction` (orphans on store delete); no CHECK on Decimal columns. |
| 8 | Test coverage | FAIL | P2 | `getSettings`, `upsertSettings`, `createPayment` have zero tests. |

## Flutter findings

### `zakat_calculator_page.dart` (formula audit)

| # | Check | Status | Severity | Note |
|---|-------|--------|----------|------|
| 1 | 2.5% rate applied | PASS | — | `zakatRate` defaults to 2.5; configurable via settings. |
| 2 | Excludes declared debts | PASS | — | `netAssets = totalAssets - payables` (server-side). |
| 3 | Currency conversion | PASS-by-design | — | Single-currency TJS by design; multi-currency would need conversion at repo. |
| 4 | Holding period (haul) ≥ 354 days | FAIL | **P1** | `haulStartDate` captured but NEVER enforced. Religious correctness regression. |
| 5 | Nisab threshold check | PASS | — | Hides "Mark as paid" CTA when below nisab. |
| 6 | Save path idempotency | FAIL | P2 | No `localId` on payment POST; double-tap creates duplicates. |
| 7 | DateTime.now() injected | FAIL | P2 | Raw `DateTime.now()` in `paidAt`. |

### `zakat_history_page.dart` + `zakat_settings_page.dart` (UX audit)

| # | Check | Status | Severity | Note |
|---|-------|--------|----------|------|
| H.1 | Pagination | FAIL | P3 | Loads all without limit. |
| H.2 | Sort newest-first | FAIL | P2 | No client-side sort enforcement. |
| H.3 | Refresh | FAIL | P3 | No `RefreshIndicator`. |
| H.4 | Empty state | PASS | — | Uses `AppEmptyState`. |
| S.1 | Nisab threshold validator | FAIL | P2 | No `validator:` on field; relies on `tryParse`. |
| S.2 | Currency from store | FAIL | P2 | Hardcoded TJS — breaks USD/RUB. |
| S.3 | DateTime.now() in `_pickDate` | FAIL | P2 | Raw `DateTime.now()`. |
| S.4 | Save feedback | PASS | — | `AppSnackbar.success`/`error`. |

### `investment_bloc/` (state machine + ROI audit)

| # | Check | Status | Severity | Note |
|---|-------|--------|----------|------|
| 1 | All 4 states present | PASS | — | Initial / Loading / Loaded / Error + Summary/Success. |
| 2 | Clean transitions | PASS | — | Discriminated union, no copyWith abuse. |
| 3 | ROI divide-by-zero | N/A — no ROI math exists | — | Future ROI dashboards must guard `amount == 0`. |
| 4 | Edge cases handled | PARTIAL | P2 | No client-side `amount > 0` validation. |
| 5 | API error → Failure | PASS | — | All handlers `try/catch` + `mapErrorToUserMessage`. |
| 6 | bloc_test.dart exists | FAIL | P3 | No tests. |

### Cross-module finding from zakat_calculator audit

| # | Check | Status | Severity | Note |
|---|-------|--------|----------|------|
| X.1 | HTTP verb mismatch on settings save | FAIL | **P1** | Flutter `zakat_remote_datasource.dart` does `PUT /settings`, controller has `@Post('settings')`. Settings save 404s. |

(Originally rated P3 in source audit; reclassified to P1 here because it breaks settings persistence.)

## P1 fix-list (inline in this spec)

- [x] **I-P1-1** (commit 9e41d68): investments DTO accepts negative/unbounded `amount`/`returnAmount`/pagination. Add `@Min(0.01)` + `@Max(9_999_999_999.99)` + `+992` phone regex.
- [ ] **Z-P1-1**: zakat `createPayment` trusts client-supplied amounts. Re-derive `zakatDue` server-side from `calculate()`; reject if client-supplied diverges by > 0.5%. Add `localId` idempotency.
- [ ] **Z-P1-2**: zakat write paths bypass `AuditLogService`. Inject + record on `upsertSettings` + `createPayment`. Inject `@CurrentUser()` so actor id is captured.
- [x] **Z-P1-3** (commit 9e41d68): zakat DTOs too permissive. Add `@Max(100)` on `zakatRate`, `@Min(0)` on every Decimal, expose `nisabCurrency` in `UpsertZakatSettingsDto`.
- [ ] **Z-P1-4**: no `hasZakat` tier flag + no `@RequiresFeature`. **Decision-deferred** — needs product call: should zakat be tier-gated or baseline? Documented as deferred; no inline fix.
- [x] **Z-P1-5**: zakat FKs `NoAction`. Migration to `onDelete: Cascade`. *(Fixed 2026-05-14: migration `20260514070427_g2_zakat_cascade` — both `zakat_settings_storeId_fkey` + `zakat_payments_storeId_fkey` now CASCADE; plus 7 CHECK constraints on Decimal money columns.)*
- [ ] **Z-P1-6**: zakat `calculate` uses JS `Number` on `Decimal`. Wrap in `$transaction`; convert to `Prisma.Decimal` arithmetic.
- [ ] **ZC-P1-1**: haul (354-day) not enforced. Backend: gate `zakatDue` on `now - haulStartDate >= 354 days`. Flutter: surface "haul completes on YYYY-MM-DD" hint when below threshold.
- [x] **X-P1-1** (commit 58672dd): settings save HTTP verb mismatch — Flutter datasource changed from PUT to POST to match backend controller.

## P2 / P3 findings (documented, NOT fixed)

### Investments backend
- **P2** No `@RequiresFeature` — needs product decision on `hasInvestments` flag.
- **P2** No `localId` idempotency on create.
- **P2** No `$transaction` on update/delete.
- **P2** No audit logging on money writes.
- **P2** Missing `@@index([storeId, createdAt(sort:Desc)])`.
- **P2** No DB CHECK on `amount >= 0` / `returnAmount >= 0`.
- **P2** `create` and `update` have zero unit tests.
- **P3** `investorPhone` skips `+992` validation (covered by I-P1-1 fix).
- **P3** `summary` returns inconsistent `Decimal | 0` shape.

### Zakat backend
- **P2** `@CurrentUser()` never injected (closes once Z-P1-2 fix lands).
- **P2** `getSettings`, `upsertSettings`, `createPayment` zero test coverage.
- **P3** Decimal serialization implicit (no DTO mapping).

### Zakat calculator (Flutter)
- **P2** Payment POST has no `localId` (covered by Z-P1-1 fix).
- **P2** Raw `DateTime.now()` in `paidAt`.
- **P3** "2.5%" hardcoded in 2 UI strings even though `zakatRate` is configurable.
- **P3** No cash-on-hand input field — `cashOnHand` always 0 (silent under-reporting).
- **P3** No `WidgetsBinding.addPostFrameCallback` around `initState` event dispatch.
- **P3** `_formatPrice` hardcodes `'TJS'`.

### Zakat history + settings (Flutter)
- **P2** Sort order not enforced client-side.
- **P2** Nisab threshold field has no `validator`.
- **P2** Currency hardcoded TJS — breaks USD/RUB stores.
- **P2** `_pickDate` uses raw `DateTime.now()`.
- **P3** No pagination on history.
- **P3** No `RefreshIndicator` on history.

### Investment bloc (Flutter)
- **P2** No client-side `amount > 0` validation.
- **P2** `InvestmentLoading` clobbers previous list (UI flicker on filter).
- **P2** `InvestmentActionSuccess` immediately overwritten by chained `InvestmentListRequested`.
- **P3** No `investment_bloc_test.dart`.
- **P3** Hardcoded Russian success messages in bloc (l10n violation).

## Recommendations

1. **For the next sprint**, bundle the P2 cluster on **money discipline** (idempotency, audit, `$transaction`, DB CHECK) into a single "data integrity hardening" spec covering investments + zakat together.
2. The **single biggest follow-up** is the **zakat tier-gating decision** (Z-P1-4). Without a product call we can't fix this in this spec — leaving it open is intentional.
3. The **`investment_bloc` ROI gap** (no math today) becomes critical the moment a future PR adds a "Profit %" widget. Mention in the bloc's docstring + add a TODO referencing this audit.
4. Multi-currency support is broken in 2 places (`zakat_settings_page.dart` hardcoded TJS, `_formatPrice` hardcoded TJS). When the multi-currency feature ships properly, both fixes belong in that spec.
