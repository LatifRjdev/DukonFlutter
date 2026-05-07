# Phase 5 — Customers & Suppliers

**Date:** 2026-05-07

## Coverage matrix

| Flow | Result | Severity | Notes |
|---|---|---|---|
| Customer create with russian + email + emoji notes | 🟢 PASS | — | UTF-8 preserved end-to-end. |
| Customer create with no phone (optional) | 🟢 PASS | — | 201, phone=null. |
| Customer phone validation (`phone="123"`) | 🔴 FAIL | **P2** | See F5.1. |
| Customer update | 🟢 PASS | — | 200, name + email updated. |
| Customer search by phone fragment | 🟢 PASS | — | `?search=992907` returns matching customer. |
| Customer cross-store leak (U2 → U1 customers) | 🟢 PASS | — | 403 "You do not have access to this store". |
| Customer soft delete + read | 🔴 FAIL | **P1** | Same pattern as F3.1 — soft-deleted customer remains readable via GET. Trends with the F3.1 finding; one fix should cover both. |
| Supplier list / create | 🟢 PASS | — | 201, all expected fields. |
| Supplier cross-store leak | 🟢 PASS | — | 403. |
| Customer debt + loyalty (covered in Phase 4 sales) | 🟢 PASS | — | Debt tracked correctly (debt+13 after debt+mixed sales); loyalty stays at 0 because no rules created. |

## Findings

### F5.1 — P2: Customer phone validation absent

**Repro:**
```bash
curl -X POST .../customers -d '{"name":"BadPhone","phone":"123"}'
```

**Expected:** 400 (Tajik POS expects +992XXXXXXXXX format, same as User
registration).

**Observed:** 201, customer stored with phone="123".

**Why this matters:** when a cashier later wants to send a Telegram
receipt or look up a customer by phone, the bad numbers won't match
anything. Bookkeeping reports filtering "by phone = +992X" will
silently drop these.

**Fix path:** add `@Matches(/^\+992\d{9}$/)` (or use the existing
phone-validator pipe used on register) to `CreateCustomerDto.phone`
when phone is non-null.

### F5.2 — P1 (linked to F3.1): Soft-deleted customer remains readable

Same shape as products soft-delete. Customer GET returns 200 with
`isActive=false` instead of 404. List endpoint likely also includes
inactive (didn't re-test — same pattern).

**Fix path:** apply the same `where: { isActive: true }` default to
findAll/findOne for every soft-deletable entity. Worth introducing a
shared `softDelete` mixin / Prisma extension.

## Phase 5 summary

8 PASS / 1 P1 (linked to F3.1) / 1 P2 / 0 P3.

Most of the surface is fine. The two findings are structural — the
soft-delete leak repeats for every soft-deletable entity, and phone
validation needs to be DRY-reused from User onto Customer.
