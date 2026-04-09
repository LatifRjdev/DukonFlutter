---
description: Add a new API endpoint to NestJS backend and wire to KMP client
---

Add API endpoint: $ARGUMENTS

Steps:
1. **Backend** (`api/src/modules/`):
   - Add/update Prisma model if needed → run `npx prisma migrate dev`
   - Create/update DTO with validation decorators
   - Add controller method with proper decorators (@Get, @Post, etc.)
   - Add service method with business logic
   - Scope under `/stores/:storeId/` if store-specific
   - Add Swagger documentation
   - Add guard: `@UseGuards(JwtAuthGuard)`

2. **Shared KMP** (`shared/`):
   - Add response/request DTOs in `data/remote/dto/`
   - Add Ktor client method in corresponding API service
   - Update repository if needed
   - Update or create use case

3. **Test**: 
   - `cd api && npm run test` for backend
   - `./gradlew :shared:allTests` for KMP client
