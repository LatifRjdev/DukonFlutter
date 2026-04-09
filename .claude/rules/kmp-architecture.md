---
description: Architecture rules for Kotlin Multiplatform shared module
globs: "shared/**/*.kt"
---

# KMP Shared Module Architecture

- Follow Clean Architecture: domain → data → presentation boundary
- Domain layer has ZERO dependencies on data layer or frameworks
- Entities are plain Kotlin data classes, no annotations
- Use cases have single `invoke` operator function
- Repository interfaces live in domain, implementations in data
- All repository methods return `Result<T>` or `Flow<T>`
- Never import Android or iOS specific code in commonMain
- Platform-specific code goes in androidMain/iosMain with `expect/actual`
- Use kotlinx.serialization for all API models
- Use kotlinx.coroutines Flow for reactive data streams
- Koin modules defined per feature in shared/di/
