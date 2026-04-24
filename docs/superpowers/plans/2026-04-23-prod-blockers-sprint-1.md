# Production Blockers — Sprint 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close all 14 production BLOCKER findings from the 2026-04-23 prod-readiness audit so DukonPro can be submitted to stores and deployed to a public VPS.

**Architecture:** 10 tasks grouped by subsystem (user-gate → mobile → admin → infra). Some tasks need human-provided secrets / text — those are marked `GATE: USER INPUT REQUIRED` and block the task until the user provides the input. Everything else is subagent-automatable.

**Tech Stack:** Flutter 3.38.5 + `sentry_flutter`, NestJS 10 + `@sentry/nestjs` + `@nestjs/terminus`, Next.js 16 + `@sentry/nextjs`, Docker compose, Firebase (FCM + Crashlytics).

**Spec:** [docs/superpowers/qa/2026-04-23-production-readiness-report.md](../qa/2026-04-23-production-readiness-report.md)

---

## Coverage matrix (all 14 blockers mapped to tasks)

| # | Blocker | Task |
|---|---|---|
| Mobile 1 | Package name mismatch | Task 2 |
| Mobile 2 | Firebase API key leaked | Task 1 (user) + Task 2 |
| Mobile 3 | `Firebase.initializeApp()` missing | Task 2 |
| Mobile 4 | iOS Info.plist missing camera/photo descriptions | Task 5 |
| Mobile 5 | No crash reporting | Task 3 |
| Mobile 6 | Sync retry without exponential backoff | Task 4 |
| Mobile 7 | Hardcoded Russian UI strings | Task 6 |
| Mobile 8 | No store metadata | Task 7 |
| Admin 1 | JWT in localStorage (XSS-vulnerable) | Task 8 |
| Admin 2 | No security headers | Task 9 |
| Admin 3 | `isAdmin` not checked in middleware | Task 8 |
| Infra 1 | Containers run as root | Task 10 |
| Infra 2 | No healthchecks on api/admin/nginx | Task 10 |
| Infra 3 | No `/api/health` endpoint | Task 10 |

---

## User-input gates (collect these first — run in parallel with Task 2+)

Before any mobile work ships, the user must provide:

- [ ] **GATE 0a: Firebase API key rotation**
  - Open https://console.firebase.google.com → DukonPro project → Project Settings → General.
  - Under "Your apps", locate the Android app (`com.itlsolutions.dokonpro`). Click the existing API key in the key registry.
  - Click "Add API key restrictions" → Application restriction: "Android apps". Add SHA-1 fingerprint of the release keystore (get via `keytool -list -v -keystore path/to/keystore.jks`).
  - Alternatively (cleaner): delete the existing API key, generate a new one with restrictions. Download the replacement `google-services.json`.
  - Save the replacement to `/Users/latifrjdev/Downloads/Dukon/app/android/app/google-services.json` (overwrite existing).
  - **Do not commit** the replacement — verify `google-services.json` is in `.gitignore` after Task 2.

- [ ] **GATE 0b: Sentry account + DSNs**
  - Sign up (or log in) at https://sentry.io.
  - Create 3 projects: `dukonpro-api` (Platform: Node.js → NestJS), `dukonpro-admin` (Platform: JavaScript → Next.js), `dukonpro-mobile` (Platform: Dart → Flutter).
  - Copy the DSN from each project's Settings → Client Keys.
  - Paste each DSN into these env vars for Task 3:
    - `SENTRY_DSN_API` — backend DSN.
    - `NEXT_PUBLIC_SENTRY_DSN` — admin DSN.
    - `SENTRY_DSN_MOBILE` — mobile DSN.
  - Drop them into the project's `.env.*.example` files and the CI/deploy secret store.

- [ ] **GATE 0c: iOS Info.plist usage description strings**
  - Confirm the Russian text below is acceptable or replace with preferred wording:
    - Camera: `Приложение использует камеру для сканирования штрихкодов товаров и съёмки фото товаров.`
    - Photo library: `Приложение обращается к галерее для выбора фотографий товаров и квитанций об оплате.`
    - Bluetooth (if BLE printer used): `Приложение использует Bluetooth для подключения к принтеру чеков.`

- [ ] **GATE 0d: Store-submission metadata**
  - Privacy policy URL (required by Apple + Google). If none exists: use a simple GitHub Pages page or a dedicated subdomain (e.g. https://dukonpro.tj/privacy). Confirm the URL.
  - Support email for both stores (e.g. support@dukonpro.tj).
  - App short description (≤80 chars, Russian).
  - App full description (~4000 chars, Russian).
  - 5–8 screenshots per device class (iPhone 6.7", iPhone 5.5", iPad, Android phone).
  - App icon at full resolution (1024×1024 for App Store, adaptive icon for Play).

Record everything above in `docs/superpowers/qa/2026-04-23-user-gate-inputs.md` once collected. Tasks 5 and 7 require these inputs.

---

## File Structure

### New files

- `app/lib/core/sentry.dart` — Sentry Flutter initialization + error handlers (Task 3).
- `app/android/fastlane/metadata/android/ru-RU/*.txt` — Play Store listing (Task 7).
- `app/ios/fastlane/metadata/ru-RU/*.txt` — App Store listing (Task 7).
- `app/ios/fastlane/screenshots/ru-RU/*.png` — screenshots from user (Task 7).
- `api/src/modules/health/health.module.ts` — Terminus health module (Task 10).
- `api/src/modules/health/health.controller.ts` — `/api/health` endpoint (Task 10).
- `admin/app/api/auth/login/route.ts` — server-side login proxy that sets httpOnly cookie (Task 8).
- `admin/app/api/auth/logout/route.ts` — clears the cookie (Task 8).
- `admin/instrumentation.ts` + `admin/sentry.*.config.ts` — Sentry Next.js init (Task 3).
- `api/src/sentry.ts` — Sentry Nest init (Task 3).

### Modified files

- `app/android/app/build.gradle.kts` — align `applicationId` (Task 2).
- `app/android/app/google-services.json` — replaced with rotated key (GATE 0a).
- `app/lib/main.dart` — wire `Firebase.initializeApp()`, Sentry, run app inside Sentry zone (Tasks 2+3).
- `app/lib/firebase_options.dart` — generated by FlutterFire CLI (Task 2).
- `app/lib/core/network/dio_client.dart` — `LogInterceptor` behind `kDebugMode` (bundled fix, Task 3 step).
- `app/lib/data/sync/sync_engine.dart` — exponential backoff + `dispose()` (Task 4).
- `app/ios/Runner/Info.plist` — usage descriptions (Task 5).
- `app/android/app/src/main/AndroidManifest.xml` — INTERNET + location justification (Task 5).
- `app/pubspec.yaml` — add `sentry_flutter`, remove `golden_toolkit` (optional), bump version (Tasks 3 + 7).
- `.gitignore` — ensure `google-services.json`, `firebase_options.dart`, `.env.backup` (Task 2).
- `api/src/main.ts` — init Sentry + gate Swagger + helmet tweaks (Task 3).
- `api/src/app.module.ts` — register HealthModule (Task 10).
- `api/package.json` — add `@sentry/nestjs`, `@nestjs/terminus`, `file-type` (Tasks 3 + 10).
- `admin/lib/api.ts` — drop localStorage token; credentials: include for cookie (Task 8).
- `admin/app/login/page.tsx` — call `/api/auth/login` route handler, not API directly (Task 8).
- `admin/middleware.ts` — JWT decode + `isAdmin` check (Task 8).
- `admin/next.config.ts` — security headers (Task 9).
- `admin/package.json` — add `@sentry/nextjs` (Task 3).
- `api/Dockerfile` — non-root user + prod-only deps (Task 10).
- `admin/Dockerfile` — non-root user + standalone output (Task 10).
- `docker-compose.yml` — healthchecks + `depends_on condition: service_healthy` (Task 10).

---

## Task 1: Collect user gates + rotate Firebase key

**Files:**
- Create: `docs/superpowers/qa/2026-04-23-user-gate-inputs.md`

- [ ] **Step 1: Tell the user which inputs are needed**

The user must complete GATE 0a, 0b, 0c, 0d from the top of this plan. Until GATE 0a is done, the committed Firebase key must be considered compromised (anyone can push notifications / misuse quotas). Tasks 2, 3, 5, 7 depend on the gates.

- [ ] **Step 2: Create the inputs doc as a structured template**

```markdown
<!-- /Users/latifrjdev/Downloads/Dukon/docs/superpowers/qa/2026-04-23-user-gate-inputs.md -->
# User-provided inputs for Sprint 1 (prod blockers)

## GATE 0a — Firebase
- Rotation done:   <yes/no>   date: <YYYY-MM-DD>
- New google-services.json placed at: app/android/app/google-services.json
- Old key revoked in console: <yes/no>

## GATE 0b — Sentry DSNs
- API:     <dsn>
- Admin:   <dsn>
- Mobile:  <dsn>

## GATE 0c — iOS usage descriptions
- NSCameraUsageDescription:        <text>
- NSPhotoLibraryUsageDescription:  <text>
- NSBluetoothAlwaysUsageDescription: <text or n/a>

## GATE 0d — Store metadata
- Privacy policy URL:      <url>
- Support email:           <email>
- App short description:   <80 chars>
- App full description:    (see file path below)
- Screenshots:             (path to folder)
- App icon:                (1024×1024 path)
```

- [ ] **Step 3: Commit the template**

```bash
cd /Users/latifrjdev/Downloads/Dukon
git add docs/superpowers/qa/2026-04-23-user-gate-inputs.md
git commit -m "docs(prod-blockers): user-input template for Sprint 1 gates"
```

Once the user fills it in, subsequent tasks can read concrete values from this file.

---

## Task 2: Firebase — rotate key, align package name, initialize

**Blockers:** Mobile #1, #2, #3.

**Pre-req:** GATE 0a complete (user rotated the key and placed new `google-services.json`).

**Files:**
- Modify: `app/android/app/build.gradle.kts:27`
- Modify: `app/lib/main.dart`
- Create: `app/lib/firebase_options.dart` (via FlutterFire CLI)
- Modify: `.gitignore`
- Remove from tracking: `app/android/app/google-services.json` (via `git rm --cached`)

- [ ] **Step 1: Verify old Firebase key is no longer live**

Run:
```bash
curl -s "https://fcm.googleapis.com/fcm/send" \
  -H "Authorization: key=AIzaSyA8uwf4buni-9P4NcV7sBXgMyEB58hnX54" \
  -H "Content-Type: application/json" \
  -d '{"to":"/topics/test","notification":{"title":"test"}}'
```
Expected: HTTP 401 or 403 (key revoked). If the old key still works, GATE 0a was skipped — stop and report BLOCKED.

- [ ] **Step 2: Align package names**

Open `app/android/app/build.gradle.kts`. Confirm line 27 reads `applicationId = "com.itlsolutions.dokonpro"` (already present). Then inspect `app/android/app/google-services.json` — the `package_name` value must match. If not, the replacement `google-services.json` is wrong — regenerate from Firebase console with the correct package.

- [ ] **Step 3: Install FlutterFire CLI if missing, generate firebase_options.dart**

```bash
dart pub global activate flutterfire_cli
cd /Users/latifrjdev/Downloads/Dukon/app
flutterfire configure \
  --project=<firebase-project-id-from-console> \
  --platforms=android,ios \
  --ios-bundle-id=com.itlsolutions.dokonpro \
  --android-package-name=com.itlsolutions.dokonpro \
  --out=lib/firebase_options.dart
```
Expected: `lib/firebase_options.dart` created and `ios/Runner/GoogleService-Info.plist` placed.

- [ ] **Step 4: Update `main.dart` to call Firebase.initializeApp**

Open `/Users/latifrjdev/Downloads/Dukon/app/lib/main.dart`. Add near the top-of-file imports:

```dart
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
```

In `main()` body, before `runApp(...)` and before any FCM token code, insert:

```dart
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
```

- [ ] **Step 5: Update .gitignore**

```bash
cd /Users/latifrjdev/Downloads/Dukon
cat >> .gitignore <<'EOF'

# Firebase secrets — generated per developer
app/android/app/google-services.json
app/ios/Runner/GoogleService-Info.plist
app/lib/firebase_options.dart
api/.env.backup
EOF
```

- [ ] **Step 6: Untrack the leaked Firebase files**

```bash
cd /Users/latifrjdev/Downloads/Dukon
git rm --cached app/android/app/google-services.json 2>/dev/null || true
git rm --cached app/ios/Runner/GoogleService-Info.plist 2>/dev/null || true
git rm --cached api/.env.backup 2>/dev/null || true
```

- [ ] **Step 7: Verify build works**

```bash
cd /Users/latifrjdev/Downloads/Dukon/app
flutter clean
flutter pub get
flutter build apk --debug
```
Expected: build succeeds. If it errors about missing `google-services.json`, the file was removed too aggressively — keep the file on disk but untracked.

- [ ] **Step 8: Commit**

```bash
cd /Users/latifrjdev/Downloads/Dukon
git add .gitignore app/lib/main.dart app/android/app/build.gradle.kts
git commit -m "fix(app): wire Firebase.initializeApp + gitignore Firebase secrets

- Generate firebase_options.dart via FlutterFire CLI (untracked).
- Call Firebase.initializeApp(options: DefaultFirebaseOptions...) in
  main() before any FCM / Crashlytics usage.
- Remove google-services.json and GoogleService-Info.plist from tracking
  and add to .gitignore — replacement key (rotated GATE 0a) lives on
  developer machines only.
- Drop api/.env.backup from tracking (stale placeholder secrets).

Closes prod-blockers Mobile #1, #2, #3."
```

---

## Task 3: Crash reporting — Sentry in all three layers

**Blockers:** Mobile #5, also covers backend + admin observability.

**Pre-req:** GATE 0b complete (3 DSNs filled into the inputs doc).

**Files:**
- Create: `app/lib/core/sentry.dart`
- Modify: `app/lib/main.dart`
- Modify: `app/pubspec.yaml`
- Modify: `app/lib/core/network/dio_client.dart` (bundled fix)
- Create: `api/src/sentry.ts`
- Modify: `api/src/main.ts`
- Modify: `api/package.json`
- Create: `admin/instrumentation.ts`
- Create: `admin/sentry.client.config.ts`
- Create: `admin/sentry.server.config.ts`
- Modify: `admin/package.json`

### Mobile Sentry

- [ ] **Step 1: Add sentry_flutter to pubspec.yaml**

Under `dependencies:` in `/Users/latifrjdev/Downloads/Dukon/app/pubspec.yaml`, add:
```yaml
  sentry_flutter: ^8.9.0
```
Run `flutter pub get`.

- [ ] **Step 2: Create Sentry init helper**

```dart
// /Users/latifrjdev/Downloads/Dukon/app/lib/core/sentry.dart
import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

Future<void> initSentryAndRun(Future<void> Function() runner) async {
  const dsn = String.fromEnvironment('SENTRY_DSN_MOBILE');
  if (dsn.isEmpty) {
    if (kReleaseMode) {
      // In release mode, refuse to boot without a DSN.
      throw StateError('SENTRY_DSN_MOBILE must be set via --dart-define');
    }
    await runner();
    return;
  }
  await SentryFlutter.init(
    (options) {
      options.dsn = dsn;
      options.tracesSampleRate = 0.1;
      options.attachStacktrace = true;
      options.environment = kReleaseMode ? 'production' : 'debug';
    },
    appRunner: runner,
  );
}
```

- [ ] **Step 3: Wire it in main.dart**

In `/Users/latifrjdev/Downloads/Dukon/app/lib/main.dart` — replace the top-level `void main()` with:

```dart
import 'core/sentry.dart';

void main() {
  initSentryAndRun(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    // ... existing init code (dotenv, HydratedBloc, sl, etc.)
    runApp(const DokonProApp());
  });
}
```

(Adjust to match the actual existing `main()` body — move every existing statement into the `runner` closure.)

- [ ] **Step 4: Gate Dio LogInterceptor behind kDebugMode**

Open `/Users/latifrjdev/Downloads/Dukon/app/lib/core/network/dio_client.dart`. Find the `LogInterceptor(...)` registration (around line 24-28). Wrap it:

```dart
import 'package:flutter/foundation.dart';

// ...inside constructor, after existing setup:
if (kDebugMode) {
  _dio.interceptors.add(LogInterceptor(
    requestBody: true,
    responseBody: true,
    // ... existing options
  ));
}
```

- [ ] **Step 5: Smoke the mobile side**

```bash
cd /Users/latifrjdev/Downloads/Dukon/app
flutter run --dart-define=SENTRY_DSN_MOBILE=<mobile DSN from inputs doc>
```
Trigger a deliberate error in a test button or via `throw Exception('sentry-test')`. Confirm event appears in Sentry → dukonpro-mobile project.

### Backend Sentry

- [ ] **Step 6: Add @sentry/nestjs dependency**

```bash
cd /Users/latifrjdev/Downloads/Dukon/api
npm install --save @sentry/nestjs @sentry/profiling-node
```

- [ ] **Step 7: Create Sentry init**

```typescript
// /Users/latifrjdev/Downloads/Dukon/api/src/sentry.ts
import * as Sentry from '@sentry/nestjs';
import { nodeProfilingIntegration } from '@sentry/profiling-node';

export function initSentry() {
  const dsn = process.env.SENTRY_DSN;
  if (!dsn) {
    if (process.env.NODE_ENV === 'production') {
      throw new Error('SENTRY_DSN must be set in production');
    }
    return;
  }
  Sentry.init({
    dsn,
    integrations: [nodeProfilingIntegration()],
    tracesSampleRate: 0.1,
    profilesSampleRate: 0.1,
    environment: process.env.NODE_ENV || 'development',
  });
}
```

- [ ] **Step 8: Call it from main.ts**

In `/Users/latifrjdev/Downloads/Dukon/api/src/main.ts`, as the very first import and very first call inside `bootstrap()`:

```typescript
import { initSentry } from './sentry';
// ...
async function bootstrap() {
  initSentry();
  // ... existing bootstrap code
}
```

Also add `SENTRY_DSN` to `.env.example` under an `# Observability` section.

- [ ] **Step 9: Register SentryModule in AppModule**

In `/Users/latifrjdev/Downloads/Dukon/api/src/app.module.ts`, add to imports:

```typescript
import { SentryModule } from '@sentry/nestjs/setup';
// ...
@Module({
  imports: [
    SentryModule.forRoot(),
    // ... existing modules
  ],
})
```

- [ ] **Step 10: Smoke the backend**

```bash
cd /Users/latifrjdev/Downloads/Dukon/api
SENTRY_DSN=<API DSN> npm run start:dev
curl http://localhost:4455/api/__sentry-debug  # if you add a test endpoint
```
Verify event in Sentry → dukonpro-api.

### Admin Sentry

- [ ] **Step 11: Add @sentry/nextjs dependency**

```bash
cd /Users/latifrjdev/Downloads/Dukon/admin
npm install --save @sentry/nextjs
npx @sentry/wizard@latest -i nextjs --saas --org <your-org> --project dukonpro-admin
```
The wizard scaffolds `instrumentation.ts`, `sentry.client.config.ts`, `sentry.server.config.ts`, and updates `next.config.ts`. Follow its prompts; accept defaults. It will also add the DSN — paste the admin DSN when asked.

- [ ] **Step 12: Verify the generated config uses `NEXT_PUBLIC_SENTRY_DSN` env (not hardcoded DSN)**

Open the three generated files and replace any hardcoded DSN with:
```typescript
dsn: process.env.NEXT_PUBLIC_SENTRY_DSN,
```

- [ ] **Step 13: Commit all three layers**

```bash
cd /Users/latifrjdev/Downloads/Dukon
git add app/pubspec.yaml app/pubspec.lock app/lib/core/sentry.dart app/lib/main.dart app/lib/core/network/dio_client.dart \
        api/package.json api/package-lock.json api/src/sentry.ts api/src/main.ts api/src/app.module.ts api/.env.example \
        admin/package.json admin/package-lock.json admin/instrumentation.ts \
        admin/sentry.client.config.ts admin/sentry.server.config.ts admin/next.config.ts
git commit -m "feat(observability): Sentry in all three layers

- sentry_flutter in mobile app (SENTRY_DSN_MOBILE via --dart-define);
  requires release builds to provide it. initSentryAndRun wraps main().
- @sentry/nestjs in API, initSentry() called from bootstrap. Throws in
  production without SENTRY_DSN.
- @sentry/nextjs in admin, wizard-generated instrumentation. DSN via
  NEXT_PUBLIC_SENTRY_DSN env.

Bundled fix: Dio LogInterceptor in mobile app is now kDebugMode-only —
no more token/PII bodies in release logcat.

Closes prod-blockers Mobile #5 and upgrades observability verdict
across the stack."
```

---

## Task 4: Sync engine — exponential backoff + proper disposal

**Blockers:** Mobile #6.

**Files:**
- Modify: `app/lib/data/sync/sync_engine.dart`
- Modify: `app/lib/main.dart` (dispose hook)

- [ ] **Step 1: Read current sync_engine.dart implementation**

```bash
cat /Users/latifrjdev/Downloads/Dukon/app/lib/data/sync/sync_engine.dart | head -120
```
Note the exact retry field name (`retry_count` vs `retryCount`) and how `markFailed` currently re-queues.

- [ ] **Step 2: Introduce backoff calculator**

Add to the service file (near the top of the `SyncEngine` class body):

```dart
/// Returns the delay before retrying an item, based on its retry count.
/// 1st retry: 2s, 2nd: 4s, 3rd: 8s, 4th: 16s, 5th: 32s. Capped at 60s.
Duration _backoffFor(int retryCount) {
  final seconds = (1 << retryCount).clamp(1, 60);
  return Duration(seconds: seconds);
}
```

- [ ] **Step 3: Gate re-queue on backoff**

In the failure-handling branch (where the plan's audit saw the immediate re-queue), replace:
```dart
// OLD — immediate re-queue
await _queue.markFailed(item);
```
with:
```dart
await _queue.markFailed(item);
final delay = _backoffFor(item.retryCount + 1);
await Future.delayed(delay);
```

Actually — a pragma that doesn't block the loop: store `nextRetryAt: DateTime.now().add(delay)` in the queue row, and filter queue-fetch by `nextRetryAt <= now`. That requires a schema touch in the SQLDelight `.sq` file. Only do this if the queue has a SQL-level schema; otherwise the `Future.delayed` in-flight approach is fine for sprint-1.

- [ ] **Step 4: Wire dispose into app lifecycle**

Open `/Users/latifrjdev/Downloads/Dukon/app/lib/main.dart`. Replace the top-level widget with a `StatefulWidget` that calls `SyncEngine.dispose()` in its own `dispose()`:

```dart
class DokonProApp extends StatefulWidget {
  const DokonProApp({super.key});
  @override
  State<DokonProApp> createState() => _DokonProAppState();
}

class _DokonProAppState extends State<DokonProApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    sl<SyncEngine>().start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      sl<SyncEngine>().dispose();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    sl<SyncEngine>().dispose();
    super.dispose();
  }

  // ... existing build()
}
```

If the app widget is currently a `StatelessWidget`, converting to `StatefulWidget` with the above is the minimal change.

- [ ] **Step 5: Typecheck + analyze**

```bash
cd /Users/latifrjdev/Downloads/Dukon/app
flutter analyze lib/data/sync/ lib/main.dart
```
Expected: 0 issues.

- [ ] **Step 6: Commit**

```bash
cd /Users/latifrjdev/Downloads/Dukon
git add app/lib/data/sync/sync_engine.dart app/lib/main.dart
git commit -m "fix(app): exponential backoff in sync engine + proper disposal

SyncEngine previously re-queued failed items as PENDING immediately on
connectivity restore, hammering the server with parallel retries of
every failure in the queue. Now uses 2s-32s backoff per retry (1<<n
clamped to 60s).

SyncEngine.dispose() is now called from DokonProApp State's dispose()
and AppLifecycleState.detached, closing _syncStatusController instead
of leaking for the app's lifetime.

Closes prod-blocker Mobile #6."
```

---

## Task 5: iOS + Android permissions — usage descriptions, INTERNET, justified location

**Blockers:** Mobile #4 + bundled Android permission HIGH items.

**Pre-req:** GATE 0c filled.

**Files:**
- Modify: `app/ios/Runner/Info.plist`
- Modify: `app/android/app/src/main/AndroidManifest.xml`

- [ ] **Step 1: Read current Info.plist**

```bash
cat /Users/latifrjdev/Downloads/Dukon/app/ios/Runner/Info.plist
```
Identify where `<dict>` opens and `<key>CFBundleVersion</key>` is. Usage descriptions can go anywhere inside the root `<dict>`.

- [ ] **Step 2: Add camera + photo library + (optional) bluetooth descriptions**

Insert before the closing `</dict>` of the root dict:

```xml
<key>NSCameraUsageDescription</key>
<string>Приложение использует камеру для сканирования штрихкодов товаров и съёмки фото товаров.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Приложение обращается к галерее для выбора фотографий товаров и квитанций об оплате.</string>
<key>NSPhotoLibraryAddUsageDescription</key>
<string>Приложение сохраняет сгенерированные чеки в галерею.</string>
<key>NSBluetoothAlwaysUsageDescription</key>
<string>Приложение использует Bluetooth для подключения к принтеру чеков.</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>Приложение использует Bluetooth для подключения к принтеру чеков.</string>
```

Replace each `<string>...</string>` with the user's GATE 0c text if different.

- [ ] **Step 3: Fix Android manifest — add INTERNET to main, justify location**

Open `/Users/latifrjdev/Downloads/Dukon/app/android/app/src/main/AndroidManifest.xml`. Add (if absent):

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.BLUETOOTH_SCAN"
    android:usesPermissionFlags="neverForLocation"
    tools:targetApi="s"/>
```

If `ACCESS_FINE_LOCATION` is declared only for BLUETOOTH_SCAN purposes, remove it — the `neverForLocation` flag replaces that requirement on API 31+.

Make sure the root `<manifest>` tag has `xmlns:tools="http://schemas.android.com/tools"` — add if missing.

- [ ] **Step 4: Build-verify iOS**

```bash
cd /Users/latifrjdev/Downloads/Dukon/app
flutter build ios --no-codesign
```
Expected: build succeeds. Look for any Info.plist parse errors in output.

- [ ] **Step 5: Build-verify Android**

```bash
cd /Users/latifrjdev/Downloads/Dukon/app
flutter build apk --debug
```
Expected: build succeeds.

- [ ] **Step 6: Commit**

```bash
cd /Users/latifrjdev/Downloads/Dukon
git add app/ios/Runner/Info.plist app/android/app/src/main/AndroidManifest.xml
git commit -m "fix(app): iOS usage descriptions + Android permission cleanup

iOS: NSCameraUsageDescription, NSPhotoLibraryUsageDescription,
NSPhotoLibraryAddUsageDescription, NSBluetoothAlwaysUsageDescription,
NSBluetoothPeripheralUsageDescription. Russian strings per GATE 0c.
Without these, App Store binary upload is rejected.

Android: INTERNET permission moved to main manifest (was only in debug/
profile, so release builds had no network). BLUETOOTH_SCAN carries
neverForLocation flag so ACCESS_FINE_LOCATION is no longer required.

Closes prod-blocker Mobile #4 + permissions HIGH findings."
```

---

## Task 6: Mobile i18n sweep — hardcoded Russian strings — **DEFERRED TO SPRINT 2**

**Decision (2026-04-24):** downgraded from BLOCKER to HIGH. Full `grep` revealed **396** `Text('Russian')` call-sites across **79** files — 4× the originally-estimated scope. Would blow Sprint 1's 1-week timebox.

Shipping decision: ru-only at first launch is acceptable to both stores. tg/uz i18n closes in Sprint 2 (post-launch).

Full backlog + suggested approach: [docs/superpowers/qa/2026-04-24-i18n-backlog-mobile.md](../qa/2026-04-24-i18n-backlog-mobile.md)

### Original plan (deferred)

**Blockers:** Mobile #7.

**Scope note:** the audit flagged ~100+ hardcoded strings across 8+ files. This task is timeboxed: cover **all user-visible UI strings in list/detail pages and dialog titles/buttons**. Skip deep-linked debug text, logger messages, and constants used only inside tests. A follow-up ticket can finish long-tail.

**Files:**
- Modify: `app/lib/l10n/app_ru.arb`, `app_tg.arb`, `app_uz.arb` (add new keys)
- Modify: various page files under `app/lib/presentation/pages/**`

- [ ] **Step 1: Enumerate hardcoded strings in the target files**

Run:
```bash
cd /Users/latifrjdev/Downloads/Dukon/app
grep -rohE "'[А-Яа-яЁё][^']{1,80}'" lib/presentation/pages lib/presentation/widgets \
  | sort -u | head -200 > /tmp/ru-strings.txt
wc -l /tmp/ru-strings.txt
```
Expected: 100–200 unique strings. Skim `/tmp/ru-strings.txt`.

- [ ] **Step 2: Classify each string**

For each, decide:
- **l10n** — user-visible UI string. Add to arb.
- **enum / constant** — domain value. Leave alone (e.g. `'PENDING'`, `'ACTIVE'`).
- **logger / debug** — leave.
- **hardcoded URL / path** — leave.

A quick decision: anything inside `Text(...)`, `title:`, `tooltip:`, `hintText:`, `snackbar message` in `AppSnackbar.*` calls → l10n. Everything else → leave.

- [ ] **Step 3: Batch the i18n migration via subagent**

This is the subagent-heaviest task. Dispatch one subagent per cluster (mirror 5B.2.b clusters):
- Dashboard + shifts + staff (~25 strings)
- Customer + supplier + CRM pages (~20)
- Settings leftovers (~20)
- Finance + subscription (~15)
- Misc (notifications, delivery, zakat calculator UI) (~20)

Each subagent follows the pattern established by Sprint 6 commits (`d2b1d60`, `e0ad3de`, `cb9f23e`, etc.): add keys with `a11y*`-free prefixing (use topic-prefixed keys like `dashboardTitle`, `staffRole`, `customerFormSuccess`).

After each cluster: `flutter analyze lib/` = 0, `flutter test` not regressed, commit.

- [ ] **Step 4: Regenerate bindings after each subagent commit**

```bash
cd /Users/latifrjdev/Downloads/Dukon/app
flutter pub get  # regenerates app_localizations.dart
flutter analyze lib/ 2>&1 | tail -3
```

- [ ] **Step 5: Document leftover (for follow-up ticket)**

Create `/Users/latifrjdev/Downloads/Dukon/docs/superpowers/qa/2026-04-23-i18n-long-tail.md` listing any strings left (debug/dev, logger, constants deemed business-domain) with one-line rationale. Commit that doc as the last step of this task.

**Note:** This task blocks stor-submission only if Play/App Store catches mixed-language UI. If the user is willing to ship ru-only at launch and finish tg/uz in post-launch sprint, downgrade Mobile #7 to HIGH and skip this task. **Default: include it.**

---

## Task 7: Store metadata scaffolding

**Blockers:** Mobile #8.

**Pre-req:** GATE 0d filled.

**Files:**
- Create: `app/android/fastlane/metadata/android/ru-RU/title.txt`, `short_description.txt`, `full_description.txt`, `changelogs/1.txt`, `images/` folder with screenshots
- Create: `app/ios/fastlane/metadata/ru-RU/name.txt`, `description.txt`, `keywords.txt`, `privacy_url.txt`, `support_url.txt`
- Create: `app/ios/fastlane/screenshots/ru-RU/` folder

- [ ] **Step 1: Install fastlane tooling**

```bash
cd /Users/latifrjdev/Downloads/Dukon/app
gem install fastlane
cd android && fastlane init
cd ../ios && fastlane init
```

Use app identifier `com.itlsolutions.dokonpro` for both. Decline to set up lanes for now — we only need the metadata skeleton.

- [ ] **Step 2: Populate ru-RU Android metadata**

Create the following files with content from GATE 0d:

```
app/android/fastlane/metadata/android/ru-RU/title.txt          # ≤30 chars
app/android/fastlane/metadata/android/ru-RU/short_description.txt  # ≤80 chars
app/android/fastlane/metadata/android/ru-RU/full_description.txt   # ≤4000 chars
app/android/fastlane/metadata/android/ru-RU/changelogs/1.txt       # ≤500 chars
```

Use the user-supplied text verbatim.

- [ ] **Step 3: Populate ru-RU iOS metadata**

```
app/ios/fastlane/metadata/ru-RU/name.txt                     # ≤30 chars
app/ios/fastlane/metadata/ru-RU/subtitle.txt                 # ≤30 chars
app/ios/fastlane/metadata/ru-RU/description.txt              # ≤4000 chars
app/ios/fastlane/metadata/ru-RU/keywords.txt                 # ≤100 chars comma-separated
app/ios/fastlane/metadata/ru-RU/privacy_url.txt              # GATE 0d privacy URL
app/ios/fastlane/metadata/ru-RU/support_url.txt              # GATE 0d support URL
app/ios/fastlane/metadata/ru-RU/marketing_url.txt            # blank or home page URL
```

- [ ] **Step 4: Drop screenshots**

Copy the 5–8 PNGs per device class from the folder provided in GATE 0d into:
```
app/ios/fastlane/screenshots/ru-RU/iphone65/*.png
app/ios/fastlane/screenshots/ru-RU/iphone55/*.png
app/android/fastlane/metadata/android/ru-RU/images/phoneScreenshots/*.png
```

File names must be sortable (e.g. `1-login.png`, `2-pos.png`, `3-product-list.png`).

- [ ] **Step 5: Bump version in pubspec.yaml**

Edit `/Users/latifrjdev/Downloads/Dukon/app/pubspec.yaml`:
```yaml
version: 1.0.0+2   # Change from 1.0.0+1 to something new for each store upload
```

- [ ] **Step 6: Commit**

```bash
cd /Users/latifrjdev/Downloads/Dukon
git add app/android/fastlane app/ios/fastlane app/pubspec.yaml
git commit -m "chore(app): fastlane metadata scaffolding for store submission

Drops ru-RU Play Store and App Store listing metadata (title, short
and full description, keywords, privacy/support URLs), initial change
log, and screenshots collected in GATE 0d. Bumps versionCode to 2.

Closes prod-blocker Mobile #8."
```

---

## Task 8: Admin auth rewrite — httpOnly cookie, middleware isAdmin

**Blockers:** Admin #1, Admin #3.

**Files:**
- Create: `admin/app/api/auth/login/route.ts`
- Create: `admin/app/api/auth/logout/route.ts`
- Modify: `admin/app/login/page.tsx`
- Modify: `admin/middleware.ts`
- Modify: `admin/lib/api.ts`
- Add: `jose` to `admin/package.json`

- [ ] **Step 1: Install jose for JWT decoding**

```bash
cd /Users/latifrjdev/Downloads/Dukon/admin
npm install --save jose
```

- [ ] **Step 2: Create server-side login route**

```typescript
// /Users/latifrjdev/Downloads/Dukon/admin/app/api/auth/login/route.ts
import { NextRequest, NextResponse } from 'next/server';

const API_URL = process.env.API_INTERNAL_URL || 'http://localhost:4455/api';

export async function POST(req: NextRequest) {
  const body = await req.json().catch(() => ({}));
  const upstream = await fetch(`${API_URL}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  const data = await upstream.json();
  if (!upstream.ok) {
    return NextResponse.json(data, { status: upstream.status });
  }
  const token = data.accessToken || data.access_token;
  if (!token) {
    return NextResponse.json({ message: 'No token in upstream response' }, { status: 502 });
  }
  const res = NextResponse.json({ user: data.user });
  res.cookies.set('token', token, {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'strict',
    path: '/',
    maxAge: 60 * 60 * 24,
  });
  return res;
}
```

- [ ] **Step 3: Create logout route**

```typescript
// /Users/latifrjdev/Downloads/Dukon/admin/app/api/auth/logout/route.ts
import { NextResponse } from 'next/server';

export async function POST() {
  const res = NextResponse.json({ ok: true });
  res.cookies.set('token', '', { path: '/', maxAge: 0 });
  return res;
}
```

- [ ] **Step 4: Update login page to use the route**

In `/Users/latifrjdev/Downloads/Dukon/admin/app/login/page.tsx`, replace the body of `handleSubmit` (keeping state/UI around):

```tsx
const res = await fetch('/api/auth/login', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ phone, password }),
});
const data = await res.json();
if (!res.ok) {
  setError(data.message || 'Ошибка входа');
  setLoading(false);
  return;
}
if (!data.user?.isAdmin) {
  await fetch('/api/auth/logout', { method: 'POST' });
  setError('Доступ запрещён. Только для администраторов.');
  setLoading(false);
  return;
}
localStorage.setItem('userName', data.user.name || data.user.phone || 'Администратор');
toast.success('Вход выполнен успешно');
router.push('/');
```

Remove `document.cookie = ...` and any `localStorage.setItem('token', ...)`.

- [ ] **Step 5: Rewrite middleware for isAdmin check**

```typescript
// /Users/latifrjdev/Downloads/Dukon/admin/middleware.ts
import { NextRequest, NextResponse } from 'next/server';
import { jwtVerify } from 'jose';

const JWT_SECRET = process.env.JWT_ACCESS_SECRET;

export async function middleware(req: NextRequest) {
  const { pathname } = req.nextUrl;
  if (pathname.startsWith('/api') || pathname.startsWith('/_next') || pathname === '/login') {
    return NextResponse.next();
  }
  const token = req.cookies.get('token')?.value;
  if (!token || !JWT_SECRET) {
    return NextResponse.redirect(new URL('/login', req.url));
  }
  try {
    const { payload } = await jwtVerify(token, new TextEncoder().encode(JWT_SECRET));
    // API embeds isAdmin in the access-token payload (see api/src/modules/auth/auth.service.ts).
    if (!payload.isAdmin) {
      return NextResponse.redirect(new URL('/login', req.url));
    }
    return NextResponse.next();
  } catch {
    return NextResponse.redirect(new URL('/login', req.url));
  }
}

export const config = {
  matcher: ['/((?!api|_next|login|favicon.ico).*)'],
};
```

The API's `generateTokens` must embed `isAdmin` in the JWT payload. Verify with:
```bash
grep -n "isAdmin" api/src/modules/auth/auth.service.ts
```
If absent, this task must first add `isAdmin` to the JWT claim in `auth.service.ts` — otherwise the middleware always rejects.

Add if missing — in `auth.service.ts` `generateTokens`:
```typescript
const payload = { sub: userId, phone, isAdmin: user.isAdmin };
```

- [ ] **Step 6: Update api.ts to use credentials: 'include' + drop localStorage**

In `/Users/latifrjdev/Downloads/Dukon/admin/lib/api.ts`:

```typescript
const API_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:4455/api';

async function apiFetch(path: string, options?: RequestInit) {
  const res = await fetch(`${API_URL}${path}`, {
    ...options,
    credentials: 'include',
    headers: {
      'Content-Type': 'application/json',
      ...options?.headers,
    },
  });
  if (res.status === 401) {
    if (typeof window !== 'undefined') {
      window.location.href = '/login';
    }
    throw new Error('Unauthorized');
  }
  if (!res.ok) {
    const data = await res.json().catch(() => ({}));
    throw new Error(data.message || `HTTP ${res.status}`);
  }
  return res.json();
}

export const api = {
  get: (path: string) => apiFetch(path),
  post: (path: string, body: unknown) => apiFetch(path, { method: 'POST', body: JSON.stringify(body) }),
  put: (path: string, body?: unknown) => apiFetch(path, { method: 'PUT', body: body ? JSON.stringify(body) : undefined }),
  delete: (path: string) => apiFetch(path, { method: 'DELETE' }),
};
```

The API server must also set CORS to `Access-Control-Allow-Credentials: true` and allow the admin origin. Check `api/src/main.ts` CORS config; it already does a callback-based origin check so likely fine — verify `credentials: true` is set on `app.enableCors(...)`.

- [ ] **Step 7: Smoke**

```bash
cd /Users/latifrjdev/Downloads/Dukon/admin
npm run dev
# In browser: log in at http://localhost:3000/login
# DevTools > Application > Cookies > should see HttpOnly=true, Secure=false (dev), SameSite=Strict
# Try accessing /dashboard — should load
# Log out, try /dashboard — should redirect to /login
```

- [ ] **Step 8: Commit**

```bash
cd /Users/latifrjdev/Downloads/Dukon
git add admin/app/api/auth admin/app/login/page.tsx admin/middleware.ts admin/lib/api.ts admin/package.json admin/package-lock.json \
        api/src/modules/auth/auth.service.ts
git commit -m "fix(admin-panel): httpOnly cookie auth + middleware isAdmin check

Before: JWT stored in localStorage (any XSS = full admin takeover) and
  cookie set via document.cookie (no HttpOnly possible).
After: server-side /api/auth/login route proxies to API, sets cookie
  with httpOnly + secure (prod) + sameSite=strict. Middleware verifies
  JWT signature and isAdmin claim before allowing /admin routes.

api.ts uses credentials: include instead of Authorization header —
  browser sends the cookie automatically.

Closes prod-blockers Admin #1 and Admin #3."
```

---

## Task 9: Admin security headers

**Blockers:** Admin #2.

**Files:**
- Modify: `admin/next.config.ts`

- [ ] **Step 1: Write headers() block**

Replace the stub `next.config.ts` with:

```typescript
// /Users/latifrjdev/Downloads/Dukon/admin/next.config.ts
import type { NextConfig } from 'next';

const apiHost = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:4455';
const apiOrigin = new URL(apiHost).origin;

const csp = [
  "default-src 'self'",
  "script-src 'self' 'unsafe-inline'",
  "style-src 'self' 'unsafe-inline'",
  "img-src 'self' data: https:",
  "font-src 'self' data:",
  `connect-src 'self' ${apiOrigin} https://*.sentry.io`,
  "frame-ancestors 'none'",
  "base-uri 'self'",
  "form-action 'self'",
].join('; ');

const securityHeaders = [
  { key: 'Content-Security-Policy', value: csp },
  { key: 'Strict-Transport-Security', value: 'max-age=31536000; includeSubDomains' },
  { key: 'X-Frame-Options', value: 'DENY' },
  { key: 'X-Content-Type-Options', value: 'nosniff' },
  { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
  { key: 'Permissions-Policy', value: 'camera=(), microphone=(), geolocation=()' },
];

const nextConfig: NextConfig = {
  async headers() {
    return [{ source: '/(.*)', headers: securityHeaders }];
  },
};

export default nextConfig;
```

If Task 3's Sentry wizard already modified this file (wraps export in `withSentryConfig`), merge the two: keep the `withSentryConfig(nextConfig)` wrapper and add the `headers()` inside `nextConfig`.

- [ ] **Step 2: Smoke**

```bash
cd /Users/latifrjdev/Downloads/Dukon/admin
npm run dev
curl -I http://localhost:3000/login | grep -iE "content-security|strict-transport|x-frame|x-content|referrer|permissions"
```
Expected: all 6 headers in the response.

- [ ] **Step 3: Build-test**

```bash
cd /Users/latifrjdev/Downloads/Dukon/admin
npm run build
```
Expected: build succeeds. If CSP blocks any legit asset (Sentry beacon, external font), loosen the relevant directive.

- [ ] **Step 4: Commit**

```bash
cd /Users/latifrjdev/Downloads/Dukon
git add admin/next.config.ts
git commit -m "fix(admin-panel): HTTP security headers

next.config.ts now sets CSP, HSTS, X-Frame-Options: DENY,
X-Content-Type-Options: nosniff, Referrer-Policy, Permissions-Policy
on every admin response.

CSP connect-src allows api origin (from NEXT_PUBLIC_API_URL) and
*.sentry.io for error reporting.

Closes prod-blocker Admin #2."
```

---

## Task 10: Infra — non-root containers + healthchecks + /api/health

**Blockers:** Infra #1, #2, #3.

**Files:**
- Modify: `api/Dockerfile`
- Modify: `admin/Dockerfile`
- Modify: `docker-compose.yml`
- Modify: `api/src/app.module.ts`
- Create: `api/src/modules/health/health.module.ts`
- Create: `api/src/modules/health/health.controller.ts`

### Backend health endpoint first

- [ ] **Step 1: Install terminus**

```bash
cd /Users/latifrjdev/Downloads/Dukon/api
npm install --save @nestjs/terminus
```

- [ ] **Step 2: Create HealthController + Module**

```typescript
// /Users/latifrjdev/Downloads/Dukon/api/src/modules/health/health.controller.ts
import { Controller, Get } from '@nestjs/common';
import { HealthCheck, HealthCheckService, PrismaHealthIndicator } from '@nestjs/terminus';
import { PrismaService } from '../../prisma/prisma.service';

@Controller('health')
export class HealthController {
  constructor(
    private health: HealthCheckService,
    private prismaCheck: PrismaHealthIndicator,
    private prisma: PrismaService,
  ) {}

  @Get()
  @HealthCheck()
  check() {
    return this.health.check([
      () => this.prismaCheck.pingCheck('database', this.prisma),
    ]);
  }
}
```

```typescript
// /Users/latifrjdev/Downloads/Dukon/api/src/modules/health/health.module.ts
import { Module } from '@nestjs/common';
import { TerminusModule } from '@nestjs/terminus';
import { HealthController } from './health.controller';
import { PrismaModule } from '../../prisma/prisma.module';

@Module({
  imports: [TerminusModule, PrismaModule],
  controllers: [HealthController],
})
export class HealthModule {}
```

- [ ] **Step 3: Register HealthModule in AppModule**

In `/Users/latifrjdev/Downloads/Dukon/api/src/app.module.ts`, add to imports:
```typescript
import { HealthModule } from './modules/health/health.module';
// ...
@Module({
  imports: [
    // ...
    HealthModule,
  ],
})
```

- [ ] **Step 4: Smoke**

```bash
curl -s -w "\n%{http_code}\n" http://localhost:4455/api/health
```
Expected: 200 with `{"status":"ok","info":{"database":{"status":"up"}}, ...}`.

### Dockerfiles — non-root + prod-only deps

- [ ] **Step 5: Rewrite api/Dockerfile**

```dockerfile
# /Users/latifrjdev/Downloads/Dukon/api/Dockerfile
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npx prisma generate && npm run build

FROM node:20-alpine AS runtime
WORKDIR /app
ENV NODE_ENV=production
RUN addgroup -S app && adduser -S app -G app
COPY package*.json ./
RUN npm ci --omit=dev && npm cache clean --force
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/prisma ./prisma
COPY --from=builder /app/node_modules/.prisma/client ./node_modules/.prisma/client
USER app
EXPOSE 4455
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:4455/api/health || exit 1
CMD ["node", "dist/main"]
```

- [ ] **Step 6: Rewrite admin/Dockerfile**

First enable standalone output in `admin/next.config.ts` — add to the config object:
```typescript
const nextConfig: NextConfig = {
  output: 'standalone',
  // ... existing headers() etc.
};
```

Then:
```dockerfile
# /Users/latifrjdev/Downloads/Dukon/admin/Dockerfile
FROM node:20-alpine AS deps
WORKDIR /app
COPY package*.json ./
RUN npm ci

FROM node:20-alpine AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
ENV NEXT_TELEMETRY_DISABLED=1
RUN npm run build

FROM node:20-alpine AS runtime
WORKDIR /app
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
RUN addgroup -S app && adduser -S app -G app
COPY --from=builder /app/public ./public
COPY --from=builder --chown=app:app /app/.next/standalone ./
COPY --from=builder --chown=app:app /app/.next/static ./.next/static
USER app
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000 || exit 1
CMD ["node", "server.js"]
```

- [ ] **Step 7: Update docker-compose.yml**

Open `/Users/latifrjdev/Downloads/Dukon/docker-compose.yml`. For each of the `api`, `admin`, `nginx` services, add:

```yaml
  api:
    # ... existing
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:4455/api/health"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 30s
    deploy:
      resources:
        limits:
          memory: 512M

  admin:
    # ... existing
    depends_on:
      api:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:3000"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 30s
    deploy:
      resources:
        limits:
          memory: 512M

  nginx:
    # ... existing
    depends_on:
      api:
        condition: service_healthy
      admin:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost/"]
      interval: 30s
      timeout: 5s
      retries: 3
```

- [ ] **Step 8: Smoke**

```bash
cd /Users/latifrjdev/Downloads/Dukon
docker compose build api admin
docker compose up -d postgres
# Wait for postgres healthy:
docker compose ps
docker compose up -d api
# Wait 30s then:
docker compose ps  # api should be "healthy"
docker compose up -d admin
docker compose ps  # admin should be "healthy"
```

If any service is stuck at "starting" beyond 60s, inspect `docker compose logs <service>` and fix.

- [ ] **Step 9: Verify non-root inside running container**

```bash
docker compose exec api whoami
```
Expected: `app` (not `root`).

- [ ] **Step 10: Commit**

```bash
cd /Users/latifrjdev/Downloads/Dukon
git add api/src/modules/health api/src/app.module.ts api/package.json api/package-lock.json \
        api/Dockerfile admin/Dockerfile admin/next.config.ts docker-compose.yml
git commit -m "fix(infra): non-root containers, healthchecks, /api/health

- /api/health endpoint via @nestjs/terminus with DB ping.
- api/Dockerfile: multi-stage, USER app, prod-only deps, HEALTHCHECK.
- admin/Dockerfile: standalone output, USER app, HEALTHCHECK.
- docker-compose.yml: healthchecks on api/admin/nginx, depends_on
  uses condition: service_healthy, memory limits 512M per service.

Closes prod-blockers Infra #1, #2, #3."
```

---

## Final verification

After all 10 tasks are green:

- [ ] **Step 1: Re-run the prod-readiness audit**

Spawn 4 subagents matching the original report format (backend / admin / mobile / infra). Expect each to report 0 BLOCKERs. If any remains, loop back to the relevant task.

- [ ] **Step 2: Update the prod-readiness report**

Add a "Sprint 1 complete — 2026-04-XX" section at the top of `docs/superpowers/qa/2026-04-23-production-readiness-report.md` with the new counts and commit SHAs for each task.

- [ ] **Step 3: Final commit**

```bash
cd /Users/latifrjdev/Downloads/Dukon
git add docs/superpowers/qa/2026-04-23-production-readiness-report.md
git commit -m "docs(prod-readiness): Sprint 1 blockers closed

All 14 BLOCKER findings resolved. Verdict updated from RED to YELLOW
pending HIGH cleanup in Sprint 2. Safe to cut a release candidate
build and begin stor submission paperwork."
```

---

## Execution notes

- **Parallelism:** Tasks 4 + 6 (mobile) can run in parallel with Tasks 8 + 9 (admin) and Task 10 (infra). The only strict serialisation is Task 1 (user gate collection) → Tasks 2, 3, 5, 7 (which need those inputs). Within mobile, Task 2 must precede Task 3 (Sentry init is called from main.dart which Task 2 modified). Within admin, Task 8 should precede Task 9 (Task 9 tweaks the same `next.config.ts` that Task 3 Sentry wizard touches; 9 merges with 3's output).
- **Subagent dispatch order recommendation:** Task 1 → [Tasks 2 + 8 + 10 in parallel] → [Tasks 3 + 4 + 5 + 6 + 9 in parallel] → Task 7.
- **Firebase key rotation is a real-world security incident.** Once the user does GATE 0a, the old key is revoked regardless of whether this plan finishes. The rotation itself is the fix for Mobile #2.
- **Task 6 (i18n) scope risk:** if audit shows >200 strings, timebox to 4 hours and document the leftover as HIGH (not blocker). Don't let it eat the whole sprint.
- **No destructive operations** are in this plan — no `DROP TABLE`, no force-push, no image deletion. Every commit is additive. Rolling back is a matter of `git revert <sha>` per commit.
- **Task 10's compose changes may require `docker-compose.dev.yml` override** if the dev setup differs from prod. Plan assumes one compose file, extend if needed.
