---
description: SQLDelight database conventions for local storage
globs: "**/*.sq,**/*.sqm"
---

# SQLDelight Database Rules

- All table definitions in shared/src/commonMain/sqldelight/
- One .sq file per entity (product.sq, sale.sq, customer.sq, etc.)
- Use migrations (.sqm files) for schema changes, never modify existing .sq after release
- All queries must be named and typed
- Index frequently filtered columns: store_id, barcode, created_at
- Foreign key constraints enforced
- JSON columns for flexible settings fields
- Batch operations for sync — use transaction blocks
- Column naming: snake_case
- Table naming: snake_case plural (products, sales, customers)
