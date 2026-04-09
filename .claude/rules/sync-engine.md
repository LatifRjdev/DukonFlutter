---
description: Offline-first sync engine rules
globs: "shared/**/sync/**/*.kt"
---

# Sync Engine Rules

- All writes go to local DB first, then queued for remote sync
- Sync queue stored in SQLDelight table with: entity_type, entity_id, operation, payload, retry_count, status
- Operations: CREATE, UPDATE, DELETE — processed FIFO
- Conflict resolution: last-write-wins with server timestamp comparison
- Auto-sync triggers on connectivity change (via platform expect/actual)
- Retry with exponential backoff, max 5 retries
- Composite entity IDs for scoped resources: "storeId:entityId"
- Batch sync support for initial data load
- Sync status observable via Flow for UI indicators
- Never block UI on sync — local DB is always source of truth for reads
