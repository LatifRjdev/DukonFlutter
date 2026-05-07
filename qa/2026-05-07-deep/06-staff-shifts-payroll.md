# Phase 6 — Staff, shifts, payroll

**Date:** 2026-05-07

## Coverage matrix

| Flow | Result | Severity | Notes |
|---|---|---|---|
| Roles list | 🟢 PASS | — | Returns OWNER + ADMIN with full permission matrix. |
| Staff create CASHIER role + salary + commission | 🟢 PASS | — | 201 with linked user (auto-created stub). |
| Staff list | 🟢 PASS | — | Owner + new cashier. Note: top-level `name` is null in list shape (lives under `user.name`) — minor UX nit if a frontend reads `.name`. |
| Shift open with correct field name | 🟢 PASS | — | DTO field is `openingCash`, not `openingBalance`. |
| Shift open with wrong field | 🟢 PASS | — | 400 lists actual fields. |
| Concurrent shift open blocked | 🟢 PASS | — | 409 "You already have an active shift". |
| Sale linked to shift via shiftId | 🟢 PASS | — | Sale row carries shiftId. |
| Shift close — expected math | 🟢 PASS | — | expectedCash = openingCash + cashSales (1000 + 5 = 1005). |
| Shift close — discrepancy reported | 🟢 PASS | — | difference = closingCash - expectedCash (1500 - 1005 = +495 surplus). |
| Payroll calculate | 🟢 PASS | — | Creates period with one payroll per active staff member. |
| Payroll list | 🟢 PASS | — | Returns paginated list. |
| Cross-store leak (U2 → U1 staff) | 🟢 PASS | — | 403. |

## Findings

### F6.1 — P3: Staff list shape inconsistency

**Repro:**
```bash
curl .../staff
# Returns array where each row has top-level `name=null` and `user.name="QA Cashier"`.
```

The `name` field on the top-level Staff object is null even though the
Staff row has an associated User with a name. A naive frontend that
reads `staff[i].name` will show "null" or empty.

**Fix path:** either drop the top-level `name` from the response shape
or backfill it from `user.name`. Already lives under `.user.name`
so the data isn't missing, just inconsistent.

## Phase 6 summary

12 PASS / 0 P0 / 0 P1 / 0 P2 / 1 P3 nit.

This phase is the cleanest so far — the shift accounting in particular
is correct (expected vs declared math + cross-shift block + sale
linkage). Payroll calculation generates the right number of rows.
