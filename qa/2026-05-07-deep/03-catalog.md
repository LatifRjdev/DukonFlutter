# Phase 3 — Catalog (categories + products)

**Date:** 2026-05-07
**Coverage:** Categories CRUD, Products CRUD + validation + search + filters + cross-store leak.

## Coverage matrix

| Flow | Result | Severity | Notes |
|---|---|---|---|
| Categories: create with russian + color | 🟢 PASS | — | 201, full row returned. |
| Categories: update name | 🟢 PASS | — | 200, updatedAt advanced. |
| Categories: read single | 🟢 PASS | — | 200, no leak. |
| Categories: hard delete (returns 200 with deleted row) | 🟢 PASS | — | DELETE returns the row body so caller can confirm. |
| Products: validation — empty body | 🟢 PASS | — | 400 with name + sellPrice errors. |
| Products: validation — negative price | 🟢 PASS | — | 400 "sellPrice must not be less than 0". |
| Products: emoji name (🍎 Яблоко 🟢) | 🟢 PASS | — | 201, stored as UTF-8. |
| Products: SQL-injection-shaped name | 🟢 PASS | — | 201, stored literally; products table intact (101 rows). Prisma parameterizes. |
| Products: duplicate barcode within store | 🟢 PASS | — | 409 "Product with this barcode already exists". |
| Products: update via PUT | 🟢 PASS | — | 200, name + sellPrice updated. |
| Products: soft delete | 🟡 PARTIAL | **P1** | DELETE flips `isActive=false` but the **single-product GET still returns 200** with the archived row. Plus the list endpoint still counts it in `total`. See F3.1. |
| Products: list pagination | 🟢 PASS | — | `data,total,page,limit,totalPages` envelope; `?limit=3` truncates correctly. |
| Products: low-stock filter | 🟢 PASS | — | `?lowStock=true` returns empty array (no stocked items). |
| Products: search by russian name | 🟡 NIT | P3 | Untested — shell didn't URL-encode the cyrillic query. Need to confirm with proper URL encoding. |
| Products: cross-store leak (U2 reads U1) | 🟢 PASS | — | 403 "You do not have access to this store". |

## Findings

### F3.1 — P1: Soft-deleted products still readable + counted

**Repro:**
```bash
# Create a product
PID=$(curl -sX POST .../products -d '{"name":"x","sellPrice":1,"unit":"PCS"}' | jq -r .id)
# Soft delete
curl -sX DELETE .../products/$PID
# Try to read it
curl -s .../products/$PID -w "%{http_code}"
# Expected: 404. Observed: 200 with isActive=false.
```

**Effect:**
- Lists include archived items in `total` count (display count is wrong).
- Detail page reachable for an item the user thinks they deleted —
  could lead to confusion or accidental edits.
- Plan-limit checks (once F2.1 is fixed) will need to specifically
  filter on `isActive=true` to avoid counting trash against the limit.

**Fix path:**
- Make `findOne` reject when `isActive=false` (return `NotFoundException`).
- Make `findAll` default to `where: { isActive: true }`; expose
  `?includeArchived=true` for admin/restore flows.
- Audit `_count.products` on category — if it includes archived, fix it
  the same way.

### F3.2 — P3: Hard delete vs soft delete inconsistency between modules

Categories DELETE appears to **hard-delete** the row (no `deletedAt`
column in schema for categories). Products DELETE **soft-deletes**.
Either pattern is fine, but the inconsistency is surprising. Pick one
and document; reflect it in the API summary spec.

### F3.3 — P3: Russian search urlencoding

Test was inconclusive because the shell command didn't URL-encode the
cyrillic search term. Need to revisit with proper encoding to confirm
the search endpoint handles non-ASCII queries. Likely fine but worth
verifying.

## What's pending

- **Photo upload via gallery** — UI flow only, requires app-side
  exercise. Will fold into Phase 4 POS or Phase 9 Settings.
- **Barcode scanner** — needs camera. Will fold into Phase 4.
- **Excel import** — needs xlsx fixture file. Will fold into Phase 8.
- **Variants** — schema has none yet (no `ProductVariant` table). Mark
  as out-of-scope for current schema.

## Phase 3 summary

13 PASS / 1 P1 (soft-delete leak) / 0 P2 / 2 P3 nits.

The validation layer is solid. The one real issue is soft-delete
visibility — items keep appearing as if alive after a delete.
