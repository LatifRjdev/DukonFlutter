# All Sprints Executed — 2026-05-10

Plan from `PLAN-NEXT-SPRINTS.md` ran end-to-end. **10 of 13 items
landed**, 1 deferred (G.1 — needs hardware), 1 partial (E.2 — the
codebase has no separate stock_intake repo so there's nothing to
add offline support to), and 1 closed by the audit (G.2).

## Sprint D — Quick wins ✓

### D.1 — Drop maxStores
Migration `20260510153400_drop_max_stores`. Column gone, types/seed/
admin DTO/PlanLimitField cleaned up. PlanLimitField now `'maxProducts'
| 'maxStaff' | 'maxDiscounts'`.

### D.2 — xlsx export endpoints
New `ExportService` streams sales/products/customers as xlsx via
ExcelJS (already in deps). `GET /api/stores/:id/reports/export?type=sales`
gated by `@RequiresFeature('hasExport')`. The dead `hasExport` flag
finally has an endpoint.

### D.3 — AuditLogService + 4 emit sites
Global `AuditLogModule` exposes fire-and-forget `record()`. Logs
swallow errors so a failed audit can never roll back the real
operation. Wired into:
- `sale.refund` → 'sale.refund' (passes acting userId from controller)
- `customer addPayment` → 'debt.payment'
- `inventory-counts apply` → 'inventory.apply'
- `stores update` → 'store.currency_change' (currency only)

### D.4 — N+1 fixes
Three hot paths cleaned:
- Excel import: per-category findUnique loop → 1 findMany + 1
  createMany. 50→2 round-trips on a 50-category file.
- Subscription expiry cron: per-row update → single updateMany.
- Sales.create: per-item stockMovement.create → single
  stockMovement.createMany after all decrements pass.

## Sprint E — Offline parity ✓ (partial)

### E.1 — Shift offline
Schema: `shifts.localId TEXT` (`20260510160000_add_localid_offline`).
DTO: `OpenShiftDto.localId`. Service: idempotent on localId — repeat
opens with the same localId return the existing shift. Repo:
`ShiftRepositoryImpl` rewritten with NetworkInfo + SyncQueue, falls
back to local + queue when offline. Sync engine resolves
`shift→shiftOpen(storeId)`.

### E.2 — Stock intake (no separate repo, documented)
Audit found no `stock_intake_repository_impl.dart`. Stock movements
happen inline in `sale.create` which already has full offline
support via the Sale flow fixed in Phase 1. Stock intake (incoming
inventory) is handled through Product create/edit which already has
offline support in `product_repository_impl.dart`. No additional
work needed; logged as resolved-by-design.

### E.3 — Debt payment localId
Schema: `debt_payments.localId` (same migration as E.1). DTO:
`CreateCustomerPaymentDto.localId`. Service: idempotent dedupe
returns existing payment row. Inline call in `credits_page.dart`
(the only place the endpoint is hit) now generates and sends a
`Uuid().v4()` so a network retry can't double-charge.

### E.4 — Cart persistence + restore prompt
New `CartLocalDatasource` persists cart to SharedPreferences.
`CartBloc` writes on every state change (debounced 400ms), clears
immediately on `CartCleared`. New `CartRestored` event lets the UI
explicitly opt into restore — never auto-restored silently. Wired
into DI; SharedPreferences now a singleton in injection.

## Sprint F — Security hardening ✓

### F.1 — JWT password-change revocation
Schema: `users.tokensRevokedAt TIMESTAMP NULL`
(`20260510170000_user_tokens_revoked_at`). `UsersService.changePassword`
bumps it to `NOW()`. Both `JwtAccessStrategy` and `JwtRefreshStrategy`
now compare `payload.iat` (seconds) against
`floor(tokensRevokedAt / 1000)` and reject older tokens with
"Token revoked. Please sign in again."

### F.2 — Class-level @RequiresFeature
`SubscriptionGuard` now reads handler-then-class metadata explicitly
with `reflector.get` instead of `getAllAndOverride`. Class-level
decorators now actually apply. `DeliveriesController` migrated to
class-only `@RequiresFeature('hasDelivery')` as the canary — all
4 method-level decorators removed.

### F.3 — Big-sale push notification
`SalesService` now fires `notifications.sendPush` to the store owner
when `sale.total >= 1000`. Threshold hardcoded for now (P3 follow-up:
promote to `store.settings`). Push is gated by `hasAllPush` upstream
so START tier silently skips; failures are caught and logged so they
can never roll back a real sale. Wired via `NotificationsModule`
import in `SalesModule`.

## Sprint G — Hardware + module-deep

### G.1 — Receipt printer integration test (DEFERRED)
Needs physical BLE thermal printer (~$30) or esc-pos emulator. No
hardware available in this session. Logged for next sprint when
hardware is procured.

### G.2 — Zakat audit ✓
Found and fixed: when `nisabAmount=0` (unset), the previous code
defaulted `isAboveNisab=true` which religiously over-triggered zakat
on any positive netAssets. New conservative default: no zakat unless
nisabAmount is explicitly configured. Net-negative also short-circuits
to zero (was missing). Two existing tests updated to set nisabAmount
explicitly; new test added for the conservative default. Investments
module unchanged — endpoints exist and the math is straightforward
sum, no audit-worthy issues found.

## Test results

- API: **184 unit + 6 e2e** ✓ (one new zakat test added)
- App: **396 flutter** ✓, dart analyze 0 issues
- TypeScript: 0 errors

## Migrations applied

- `20260510153400_drop_max_stores` (D.1)
- `20260510160000_add_localid_offline` (E.1, E.3 — Shift + DebtPayment)
- `20260510170000_user_tokens_revoked_at` (F.1)

## Cumulative session totals

26 bugs found across the day, 22 fixed, 4 deferred:

| Phase | Bugs | Status |
|-------|------|--------|
| Sprint C P3 | 7 | committed cabee90 |
| Offline + matrix | 9 | committed 1e41faf |
| Money correctness | 3 | committed 86d1927 |
| 19-area sweep | 6 (5 fixed, 1 deferred) | committed e2ce7e4 |
| Sprint D | 4 wins | this commit |
| Sprint E | 3.5 wins (E.2 doc) | this commit |
| Sprint F | 3 wins | this commit |
| Sprint G | 1 fix, 1 deferred (HW) | this commit |

**Deferrals carried into next session:**
1. G.1 — printer integration test (needs HW)
2. Big-sale threshold should move from hardcoded `1000` to per-store
   settings JSON (P3 sub-target)
3. Audit log can extend to staff role change + subscription transition
   (P3 sub-target)
4. Class-level decorator pattern should be applied to remaining
   gated controllers (`InventoryCountsController`,
   `ReportsController`) — done as canary on Deliveries only.

The 11-task plan as written is now closed except for G.1 (hardware).
