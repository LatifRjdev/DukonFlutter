---
description: Rules for Ktor API client and backend integration
globs: "shared/**/remote/**/*.kt,api/**/*.ts"
---

# API Integration Rules

- Base URL configurable per environment (dev/staging/prod)
- All endpoints scoped by storeId: /stores/:storeId/resource
- Ktor HttpClient with JSON content negotiation (kotlinx.serialization)
- Auth interceptor auto-attaches Bearer token, refreshes on 401
- Request/response DTOs separate from domain entities — map in repository
- Error responses mapped to sealed class hierarchy (NetworkError, AuthError, ServerError)
- Offline detection: queue failed requests in SyncQueue
- Pagination via cursor or offset params where needed
- File uploads (product images, excel) via multipart
- Backend NestJS modules in api/src/modules/ — one module per feature
- Prisma schema is source of truth for backend data model
