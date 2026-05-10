# Risk Areas — Where bugs likely still hide — 2026-05-10

After 14 fixes across this session (offline flow, subscription matrix,
concurrency, refund math, discount clamps), here is a structured map of
**where bugs are most likely to still hide**, ranked by blast radius.

The 6 areas that were probed in this round are marked ✓ (passed) or 🔴
(found+fixed). The remaining ~20 areas have NOT been audited live and
are the highest-priority follow-ups.

## Probed this round

### 🔴 Area 1 — Concurrent sale race (FIXED, BUG #12)
5 parallel POST /sales for the last unit → all returned 201, stock went
to **-4**. TOCTOU between `findMany` and `update`. Fixed with atomic
`updateMany WHERE quantity >= requested`. Now: 1×201 + 4×409, qty=0.

### 🔴 Area 2 — Refund money math (FIXED, BUG #13)
Refund of a discounted line over-credited customer.totalSpent
(went to **-1** TJS for 1×@5 -1 disc → refund). Was using gross
unitPrice; now uses `line.total / qty` pro-rated by sale-level
discount ratio.

### 🔴 Area 3 — Discount math edges (FIXED, BUG #14, 3 cases)
- FIXED discount > subtotal → `total = -95` (sale "owed" customer 95)
- PERCENTAGE 150% → total = -2.5
- Line discount > unit_price → items[0].total = -95
All three clamped: line discount ≤ line gross; sale discount ≤ subtotal;
PERCENTAGE clamped to [0, 100].

### ✓ Area 4 — Cross-store isolation (PASS)
qa-START gets 403 on every read/write to qa-BUSINESS's store.
`StoreAccessGuard` works.

### ✓ Area 5 — RBAC (PASS, partial)
CASHIER blocked from staff.manage / products.delete / expenses.write.
Allowed sales.manage / products.view. The `permissions-matrix.ts`
defaults align with intent. Note: 1 OWNER-only endpoint returned 404
instead of 403 (path mismatch in test) — re-verify after correcting
URL.

### ✓ Area 6 — Auth brute-force / rate-limit (PASS)
Login throttled at 3 attempts/minute → 429. OTP send/verify at 3-5/min.
Tight enough.

## NOT yet probed — high priority

### 🟠 Area 7 — Sync engine failure paths
We tested only the success path (offline sale → online → API). What
about:
- API rejects queued sale (e.g. plan-limit hit during offline window)
  → does the queue retry forever? Drop with notification?
- Queue persistence across app restart while offline
- Out-of-order sync (CREATE customer queued AFTER sale that references it)
- Conflict resolution when same row edited offline + online concurrently
  (rules say "last-write-wins by server timestamp" — never verified)
- Multi-device same-store: device A offline writes sale 50, device B
  online creates 51-60, A reconnects — what's the receipt-no order?

**Risk:** silent data loss or duplicate writes. Hard to reproduce in
production support, so worth probing now.

### 🟠 Area 8 — Other offline flows beyond CASH
Only CASH POS sale was tested offline. Untested:
- DEBT sale offline (does F4.1 customer-required guard fire on replay?)
- Refund offline
- Product create/update/delete offline
- Customer create/edit offline
- Stock intake offline
- Expense create offline
- Shift open/close offline

**Risk:** any of these can silently fail and surface as data corruption.

### 🟠 Area 9 — Multi-currency sales
The schema has a Currency enum and Subscription/store carry currency.
Untested: a sale rung in TJS while store currency is later switched
to RUB — what does totalSpent / debt show? Are exchange rates applied
anywhere?

**Risk:** money math wrong for any non-default currency.

### 🟠 Area 10 — Shift module
- Sales rung up while shift is closed (allowed? blocked?)
- Multiple shifts open simultaneously for one cashier
- Cash-count mismatch on close
- Shift spans midnight — does the shift "today" boundary work?

### 🟠 Area 11 — Loyalty / debt edge cases
- Customer redeems loyalty points + cash mixed
- Debt payment > debt amount (overpayment)
- Customer deletion when debt > 0
- Concurrent debt payments

### 🟡 Area 12 — Receipt printing / templates
- Thermal printer disconnect mid-print
- Template variables that reference nullable fields
- Receipt rendering with very long product names
- Print queue retry behaviour

### 🟡 Area 13 — Excel import / file uploads
- Malformed XLSX (zip-bomb? formula injection?)
- Image upload size + type validation
- Receipt-image upload for subscription (stored where? size limits?)
- Cleanup of orphaned uploads

### 🟡 Area 14 — JWT / session edge cases
- Token expiring mid-request
- Refresh-token reuse / rotation
- Token issued for a user who is later deactivated (revocation?)
- Concurrent refresh races

### 🟡 Area 15 — N+1 queries / performance
- /sales with 100 items + 10 includes — query count?
- /products with category include on a 2000-item list
- Dashboard aggregates running on every render
- SQLDelight queries on large local DB (100k sales)

### 🟡 Area 16 — Notifications module
- FCM token rotation
- Notification dispatch on offline-replayed sale
- Notification preferences fence (already gated, but never live-tested)

### 🟡 Area 17 — Telegram integration
- Webhook signature verification (we saw `Post('telegram/webhook')`
  with NO auth — just relies on bot-token secrecy?)
- Bot command flooding
- Receipt rendering with PDF/image attachments

### 🟡 Area 18 — Subscription lifecycle
- TRIAL → ACTIVE transition (does the date math work?)
- Renewal extending currentPeriodEnd
- Downgrade from PREMIUM → START (do PREMIUM-tier inventory rows
  become unreadable, or stay accessible?)
- Failed payment → PAST_DUE (we tested EXPIRED, not PAST_DUE)
- Plan-change refund accounting

### 🟡 Area 19 — Audit log coverage
- Which write paths emit audit log entries? (We saw the admin module
  has audit logs.)
- Sale refund — audited?
- Subscription change — audited?
- Inventory count apply — audited?
- Verify any sensitive action without an audit trail

### 🟡 Area 20 — Data export / backup
- "Export my data" flow exists?
- Account deletion — does it cascade or soft-delete?
- Data residency / GDPR-ish concerns

### 🟢 Area 21 — i18n
- 3 langs (ru, tg, uz). Missing translations would surface as English
  fallbacks.
- Date formatting per locale
- Tajik script display (Latin/Cyrillic mix)

### 🟢 Area 22 — Receipt template customisation
- Default template path tested in Sprint C; custom uploads / merge
  logic untested

### 🟢 Area 23 — Investments / Zakat modules
- Barely audited; module-specific rules unknown to me

### 🟢 Area 24 — Admin panel (Next.js)
- Separate app, separate audit needed
- Sentry already wired; real auth flows untested
- Admin-only mutations (refund any sale, change any plan, etc.)
  whose exposure was reduced in 2026-04-23 audit but never re-verified

### 🟢 Area 25 — App lifecycle (Android/iOS)
- App killed mid-sale → data loss?
- OS-initiated kills (Doze, low-memory)
- Process death + restore restoring cart state
- Background → foreground refresh

## Recommended next-pass priorities

| # | Area | Why first |
|---|------|-----------|
| 1 | **Area 7 (sync failure paths)** | Silent data loss is the worst class of bug; we proved the happy path but the failure modes are wide open |
| 2 | **Area 8 (other offline flows)** | We tested 1 of ~7 offline operations; the rest may have the same `_offline*` shape we just fixed |
| 3 | **Area 18 (subscription lifecycle)** | Money in/out at plan boundaries; downgrade is the riskiest |
| 4 | **Area 11 (loyalty/debt edges)** | Easy to drop into negative balances under concurrency or refund |
| 5 | **Area 14 (JWT edge cases)** | Auth correctness once a user account is "in flight" |

These five together would close most of the obvious release-blocker
risk before public launch.
