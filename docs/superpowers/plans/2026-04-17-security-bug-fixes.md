# Sub-project 1: Security & Bug Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix all security vulnerabilities and critical bugs blocking production deployment.

**Architecture:** Direct fixes to existing files — no new modules or features. Security fixes (git secrets, CORS), bug fixes (error exposure, navigation), and infrastructure (auth failure handling, deployment docs).

**Tech Stack:** NestJS (main.ts, interceptors), Flutter (BLoC, GoRouter, FlutterSecureStorage), Git

---

## File Structure

| Action | File | Responsibility |
|--------|------|----------------|
| Create | `api/.gitignore` | Exclude secrets, build artifacts, dependencies |
| Create | `api/.env.example` | Document required environment variables |
| Modify | `app/lib/presentation/blocs/import/import_bloc.dart` | Fix error exposure |
| Modify | `app/lib/presentation/pages/finance/finance_dashboard_page.dart` | Fix missing storeId |
| Modify | `api/src/main.ts` | Enforce CORS in production |
| Modify | `app/lib/core/network/api_interceptor.dart` | Handle refresh token failure |
| Create | `docs/deployment.md` | Production deployment guide |

---

### Task 1: Create api/.gitignore and Remove .env from Tracking

**Files:**
- Create: `api/.gitignore`
- Modify: git tracking (remove .env)

- [ ] **Step 1: Create api/.gitignore**

Create `api/.gitignore`:

```
# Dependencies
node_modules/

# Build
dist/

# Environment
.env
.env.local
.env.production

# Logs
*.log
npm-debug.log*

# Coverage
coverage/

# IDE
.idea/
.vscode/

# OS
.DS_Store
Thumbs.db
```

- [ ] **Step 2: Remove .env from git tracking**

```bash
cd /Users/latifrjdev/Downloads/Dukon
git rm --cached api/.env
```

Expected: `rm 'api/.env'`

Note: This removes the file from git tracking but keeps it on disk. The file will still exist in git history — secrets must be rotated before production deploy.

- [ ] **Step 3: Create api/.env.example**

Create `api/.env.example`:

```
NODE_ENV=development
PORT=4455

# Database
DATABASE_URL=postgresql://user:password@localhost:5435/dukonpro

# Redis
REDIS_URL=redis://localhost:6379

# JWT — MUST be rotated for production
JWT_ACCESS_SECRET=change-me-64-byte-hex-string
JWT_REFRESH_SECRET=change-me-64-byte-hex-string
JWT_ACCESS_EXPIRATION=15m
JWT_REFRESH_EXPIRATION=7d

# Rate Limiting
THROTTLE_TTL=60000
THROTTLE_LIMIT=100

# Telegram Bot
TELEGRAM_BOT_TOKEN=your-bot-token-here

# CORS — set to your frontend domain in production
# Leave empty for development (allows localhost)
CORS_ORIGIN=
```

- [ ] **Step 4: Commit**

```bash
git add api/.gitignore api/.env.example
git commit -m "security: add .gitignore, remove .env from tracking, add .env.example

IMPORTANT: Rotate JWT_ACCESS_SECRET, JWT_REFRESH_SECRET, and
TELEGRAM_BOT_TOKEN before production deployment — old values
are in git history."
```

---

### Task 2: Fix Error Exposure in ImportBloc

**Files:**
- Modify: `app/lib/presentation/blocs/import/import_bloc.dart:42,66,81`

- [ ] **Step 1: Add missing import**

In `app/lib/presentation/blocs/import/import_bloc.dart`, check if this import exists at the top. If not, add it:

```dart
import '../../../core/errors/error_messages.dart';
```

- [ ] **Step 2: Replace e.toString() on line 42**

```dart
// OLD (line 42):
emit(ImportError(message: e.toString()));

// NEW:
emit(ImportError(message: mapErrorToUserMessage(e)));
```

- [ ] **Step 3: Replace e.toString() on line 66**

```dart
// OLD (line 66):
emit(ImportError(message: e.toString()));

// NEW:
emit(ImportError(message: mapErrorToUserMessage(e)));
```

- [ ] **Step 4: Replace e.toString() on line 81**

```dart
// OLD (line 81):
emit(ImportError(message: e.toString()));

// NEW:
emit(ImportError(message: mapErrorToUserMessage(e)));
```

- [ ] **Step 5: Verify**

```bash
cd /Users/latifrjdev/Downloads/Dukon/app
flutter analyze lib/presentation/blocs/import/import_bloc.dart
```

Expected: No errors.

- [ ] **Step 6: Commit**

```bash
git add app/lib/presentation/blocs/import/import_bloc.dart
git commit -m "security: replace e.toString() with mapErrorToUserMessage in ImportBloc"
```

---

### Task 3: Fix Missing storeId in Finance Dashboard Navigation

**Files:**
- Modify: `app/lib/presentation/pages/finance/finance_dashboard_page.dart:355`

- [ ] **Step 1: Fix currencies navigation**

In `app/lib/presentation/pages/finance/finance_dashboard_page.dart`, find line 355:

```dart
// OLD:
() => context.push('/finance/currencies')

// NEW:
() => context.push('/finance/currencies', extra: storeId)
```

- [ ] **Step 2: Verify deliveries already has storeId**

Check line 357 — it should already have `extra: storeId`. If it does, no change needed. If not:

```dart
// Should be:
() => context.push('/deliveries', extra: storeId)
```

- [ ] **Step 3: Commit**

```bash
git add app/lib/presentation/pages/finance/finance_dashboard_page.dart
git commit -m "fix: pass storeId to currencies navigation in finance dashboard"
```

---

### Task 4: Enforce CORS in Production

**Files:**
- Modify: `api/src/main.ts`

- [ ] **Step 1: Read current CORS setup**

Read `api/src/main.ts` and find the CORS enablement section (around lines 79-94).

- [ ] **Step 2: Add production CORS enforcement**

The current CORS setup already has dynamic origin validation. Add a startup check that warns if `CORS_ORIGIN` is empty in production:

Find the section before `app.enableCors()` and add:

```typescript
// Add before CORS setup:
const corsOrigin = configService.get<string>('CORS_ORIGIN');
if (process.env.NODE_ENV === 'production' && !corsOrigin) {
  logger.warn(
    'WARNING: CORS_ORIGIN is not set in production. ' +
    'Set CORS_ORIGIN to your frontend domain (e.g., https://app.dukonpro.com)',
  );
}
```

- [ ] **Step 3: Verify backend builds**

```bash
cd /Users/latifrjdev/Downloads/Dukon/api
npm run build
```

Expected: No errors.

- [ ] **Step 4: Commit**

```bash
git add api/src/main.ts
git commit -m "security: warn when CORS_ORIGIN not set in production"
```

---

### Task 5: Handle Auth Token Refresh Failure

**Files:**
- Modify: `app/lib/core/network/api_interceptor.dart`

- [ ] **Step 1: Read current interceptor**

Read `app/lib/core/network/api_interceptor.dart` fully. The current flow:
1. On 401, call `_refreshToken()`
2. If refresh succeeds, retry request
3. If refresh fails, `_refreshToken()` returns false, clears tokens from storage
4. Error is passed through — **but user stays on current screen with no session**

- [ ] **Step 2: Add navigation callback for session expiry**

Update the constructor to accept a callback, and call it on refresh failure:

```dart
// Add to class fields:
final VoidCallback? onSessionExpired;

// Update constructor:
ApiInterceptor({
  required FlutterSecureStorage storage,
  this.onSessionExpired,
}) : _storage = storage;
```

- [ ] **Step 3: Call the callback on refresh failure**

In the `onError` handler, after the `if (refreshed)` block, add the session expiry call:

```dart
@override
void onError(DioException err, ErrorInterceptorHandler handler) async {
  if (err.response?.statusCode == 401) {
    final refreshed = await _refreshToken();
    if (refreshed) {
      final token = await _storage.read(key: 'access_token');
      err.requestOptions.headers['Authorization'] = 'Bearer $token';
      try {
        final response = await Dio().fetch(err.requestOptions);
        return handler.resolve(response);
      } catch (e) {
        return handler.next(err);
      }
    }
    // Session expired — notify app to redirect to login
    onSessionExpired?.call();
  }
  handler.next(err);
}
```

- [ ] **Step 4: Wire the callback in injection.dart**

In `app/lib/injection.dart`, find where `ApiInterceptor` is created and add the callback:

```dart
// Find the ApiInterceptor registration and update:
sl.registerLazySingleton<ApiInterceptor>(
  () => ApiInterceptor(
    storage: sl<FlutterSecureStorage>(),
    onSessionExpired: () {
      // Clear auth state and navigate to login
      sl<FlutterSecureStorage>().deleteAll();
      AppRouter.router.go('/login');
    },
  ),
);
```

Make sure `AppRouter` is imported in injection.dart:
```dart
import 'core/router/app_router.dart';
```

- [ ] **Step 5: Verify**

```bash
cd /Users/latifrjdev/Downloads/Dukon/app
flutter analyze lib/core/network/api_interceptor.dart
flutter analyze lib/injection.dart
```

Expected: No errors.

- [ ] **Step 6: Commit**

```bash
git add app/lib/core/network/api_interceptor.dart app/lib/injection.dart
git commit -m "security: redirect to login on auth token refresh failure"
```

---

### Task 6: Create Production Deployment Guide

**Files:**
- Create: `docs/deployment.md`

- [ ] **Step 1: Create deployment guide**

Create `docs/deployment.md`:

```markdown
# DukonPro — Production Deployment Guide

## Prerequisites

- Node.js 20+
- PostgreSQL 15+
- Redis 7+
- Flutter 3.24+
- Android SDK (for APK builds)

## Backend (NestJS API)

### 1. Environment Variables

Copy `api/.env.example` to `api/.env` and configure:

| Variable | Description | Example |
|----------|-------------|---------|
| NODE_ENV | Environment | `production` |
| PORT | Server port | `4455` |
| DATABASE_URL | PostgreSQL connection | `postgresql://user:pass@host:5432/dukonpro` |
| REDIS_URL | Redis connection | `redis://host:6379` |
| JWT_ACCESS_SECRET | Access token signing key (64+ chars) | Generate with `openssl rand -hex 32` |
| JWT_REFRESH_SECRET | Refresh token signing key (64+ chars) | Generate with `openssl rand -hex 32` |
| TELEGRAM_BOT_TOKEN | Telegram bot API token | Get from @BotFather |
| CORS_ORIGIN | Allowed origins (comma-separated) | `https://admin.dukonpro.com` |

**IMPORTANT:** Generate new JWT secrets for production. Do NOT reuse development values.

### 2. Database Setup

```bash
cd api
npm install --production
npx prisma migrate deploy
```

### 3. Start Server

```bash
npm run build
node dist/main.js
```

Or with PM2:
```bash
pm2 start dist/main.js --name dukonpro-api
```

## Mobile App (Flutter)

### 1. Build APK

```bash
cd app
flutter build apk --release \
  --dart-define=API_BASE_URL=https://api.dukonpro.com/api
```

### 2. HTTPS Enforcement

The app enforces HTTPS in release mode (`main.dart` assertion). The `API_BASE_URL` MUST start with `https://` for release builds.

### 3. Android Signing

1. Create keystore: `keytool -genkey -v -keystore dukonpro.jks -keyalg RSA -keysize 2048 -validity 10000`
2. Create `app/android/key.properties`:
   ```
   storePassword=<password>
   keyPassword=<password>
   keyAlias=dukonpro
   storeFile=<path>/dukonpro.jks
   ```
3. The `build.gradle.kts` already reads from `key.properties`

## Security Checklist

- [ ] Generated new JWT_ACCESS_SECRET and JWT_REFRESH_SECRET
- [ ] Generated new TELEGRAM_BOT_TOKEN (old one is in git history)
- [ ] Set CORS_ORIGIN to exact frontend domain
- [ ] DATABASE_URL uses SSL connection
- [ ] REDIS_URL uses authentication
- [ ] API served behind HTTPS (nginx/CloudFlare)
- [ ] Android APK signed with release keystore
```

- [ ] **Step 2: Commit**

```bash
git add docs/deployment.md
git commit -m "docs: add production deployment guide with security checklist"
```
