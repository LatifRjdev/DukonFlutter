---
description: Scaffold a new feature module across KMP shared + Android + iOS
---

Create a new feature module for: $ARGUMENTS

Follow this checklist:

1. **Shared KMP module** (`shared/src/commonMain/`):
   - Create entity in `domain/entity/`
   - Create repository interface in `domain/repository/`
   - Create use cases in `domain/usecase/` (one per operation: Get, Create, Update, Delete, List)
   - Create API DTOs in `data/remote/dto/`
   - Create Ktor API client in `data/remote/`
   - Create SQLDelight schema in `sqldelight/` (.sq file)
   - Create local datasource in `data/local/`
   - Create repository implementation in `data/repository/`
   - Register in Koin module in `di/`

2. **Android** (`androidApp/`):
   - Create ViewModel in `viewmodel/`
   - Create Compose screens in `ui/{feature}/`
   - Add navigation routes
   - Add string resources (ru, tg, uz)

3. **iOS** (`iosApp/`):
   - Create ViewModel (ObservableObject) in `ViewModel/`
   - Create SwiftUI views in `UI/{Feature}/`
   - Add navigation
   - Add localized strings (ru, tg, uz)

4. **Tests**:
   - Unit tests for use cases and repository in `shared/src/commonTest/`
   - Basic UI test for main screen on Android

Reference the existing design files in `/design/` for UI layout.
