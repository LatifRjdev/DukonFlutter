# DokonPro — Native Rebuild

## Overview
Retail management SaaS (POS, inventory, CRM, finance, zakat) for small/medium stores in Tajikistan/CIS. Offline-first mobile app with cloud sync. Rebuilt natively using Kotlin Multiplatform + SwiftUI + Jetpack Compose.

## Tech Stack
- **Shared Logic**: Kotlin Multiplatform (KMP)
- **iOS UI**: SwiftUI + Combine
- **Android UI**: Jetpack Compose + ViewModel
- **Local DB**: SQLDelight (shared, generates type-safe Kotlin/Swift)
- **Network**: Ktor Client (shared)
- **DI**: Koin Multiplatform
- **Auth**: JWT (access + refresh tokens), Keychain (iOS) / EncryptedSharedPreferences (Android)
- **Backend**: NestJS + Prisma + PostgreSQL + Redis (existing `/api` directory)
- **Sync**: Custom offline-first queue with conflict resolution (shared KMP module)

## Project Structure
```
/
├── shared/                    # KMP shared module
│   ├── src/commonMain/        # Shared Kotlin code
│   │   ├── domain/            # Entities, repository interfaces, use cases
│   │   ├── data/              # Repository impls, datasources, sync engine
│   │   │   ├── remote/        # Ktor API clients
│   │   │   ├── local/         # SQLDelight datasources
│   │   │   └── sync/          # Offline queue, conflict resolver
│   │   └── di/                # Koin modules
│   ├── src/androidMain/       # Android-specific implementations
│   ├── src/iosMain/           # iOS-specific implementations
│   └── build.gradle.kts
├── androidApp/                # Android application
│   ├── src/main/java/.../
│   │   ├── ui/                # Compose screens & components
│   │   │   ├── auth/
│   │   │   ├── pos/
│   │   │   ├── products/
│   │   │   ├── sales/
│   │   │   ├── customers/
│   │   │   ├── finance/
│   │   │   ├── staff/
│   │   │   ├── zakat/
│   │   │   ├── settings/
│   │   │   └── components/    # Shared UI components
│   │   ├── viewmodel/         # Android ViewModels wrapping shared UseCases
│   │   ├── navigation/        # Compose Navigation
│   │   └── service/           # Bluetooth printer, barcode scanner
│   └── build.gradle.kts
├── iosApp/                    # iOS application
│   ├── Sources/
│   │   ├── UI/                # SwiftUI Views
│   │   │   ├── Auth/
│   │   │   ├── POS/
│   │   │   ├── Products/
│   │   │   ├── Sales/
│   │   │   ├── Customers/
│   │   │   ├── Finance/
│   │   │   ├── Staff/
│   │   │   ├── Zakat/
│   │   │   ├── Settings/
│   │   │   └── Components/
│   │   ├── ViewModel/         # ObservableObjects wrapping shared UseCases
│   │   ├── Navigation/
│   │   └── Service/           # CoreBluetooth printer, AVFoundation scanner
│   └── iosApp.xcodeproj
├── api/                       # NestJS backend (existing)
├── design/                    # Figma exports (existing)
├── gradle/
├── build.gradle.kts           # Root Gradle config
├── settings.gradle.kts
└── CLAUDE.md
```

## Key Commands
```bash
# Shared module
./gradlew :shared:build                    # Build shared KMP module
./gradlew :shared:allTests                 # Run shared tests (JVM + iOS simulator)

# Android
./gradlew :androidApp:assembleDebug        # Build Android debug
./gradlew :androidApp:installDebug         # Install on device/emulator
./gradlew :androidApp:testDebugUnitTest    # Android unit tests

# iOS
cd iosApp && xcodebuild -scheme iosApp -destination 'platform=iOS Simulator,name=iPhone 16' build
# Or open iosApp/iosApp.xcworkspace in Xcode

# Backend (existing)
cd api && npm run start:dev                # Start dev server
cd api && npx prisma migrate dev           # Run migrations
cd api && npx prisma studio                # DB GUI

# Full project
./gradlew build                            # Build everything
./gradlew check                            # All checks & tests
```

## Architecture
### Shared KMP Layer (Clean Architecture)
- **Entities** (`shared/.../domain/entity/`): Pure Kotlin data classes — Product, Sale, Customer, etc.
- **Use Cases** (`shared/.../domain/usecase/`): Single-responsibility business operations
- **Repository Interfaces** (`shared/.../domain/repository/`): Abstractions for data access
- **Repository Implementations** (`shared/.../data/repository/`): Offline-first with local + remote
- **Sync Engine** (`shared/.../data/sync/`): Queue-based sync with retry, conflict resolution (last-write-wins)

### Platform UI Layer
- Android: Compose screens observe shared UseCases via ViewModel + StateFlow
- iOS: SwiftUI views observe shared UseCases via ObservableObject wrapping KMP flows

### Data Flow
```
UI Event → ViewModel → UseCase → Repository
                                    ├── LocalDataSource (SQLDelight) → immediate response
                                    └── SyncQueue → RemoteDataSource (Ktor) → when online
```

### Auth Flow
1. Phone + OTP → Register/Login → JWT tokens
2. Tokens stored: Keychain (iOS) / EncryptedSharedPreferences (Android)
3. Ktor interceptor auto-attaches & refreshes tokens
4. All API endpoints scoped by storeId: `/stores/:storeId/resource`

## Conventions
- **Kotlin**: Follow official Kotlin coding conventions, `camelCase` for functions/properties, `PascalCase` for classes
- **Swift**: Follow Swift API Design Guidelines, same naming as Kotlin where possible
- **Compose**: Stateless composables preferred, state hoisted to ViewModel
- **SwiftUI**: Same — views are thin, logic in ViewModels
- **API models**: Use `@Serializable` (kotlinx.serialization) in shared module
- **DB**: SQLDelight `.sq` files in `shared/src/commonMain/sqldelight/`
- **Tests**: Each use case and repository must have unit tests in shared module
- **Localization**: String resources in each platform's native system (strings.xml / Localizable.strings) for ru, tg, uz
- **Error handling**: Result type pattern in shared code, platform-specific error UI
- **Git**: Conventional commits (`feat:`, `fix:`, `refactor:`, etc.)
