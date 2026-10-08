# Release Readiness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Make the Play Internal build a working application instead of one that cannot reach a server.

**Architecture:** Two blockers, in dependency order. The API has no deployment anywhere, and the release build does not inject an API URL even if there were one — so it ships pointing at `10.0.2.2`, the Android emulator's alias for the developer's own machine. Everything else on this list is secondary.

**Not a code-quality exercise.** The app itself passes 1959 tests on a CI-matched Linux container. What is missing is deployment and build configuration.

---

## The two blockers, stated precisely

**1. The release AAB ships with the emulator loopback.**
`app/fastlane/Fastfile:20-23` runs `flutter build appbundle --release --build-name=… --build-number=…` and passes **no** `--dart-define`. `app/lib/core/constants/api_endpoints.dart:10-13` therefore falls back to `http://10.0.2.2:4455/api`. On a physical device that address resolves to nothing: no login, no screen loads.

The project already has the right mechanism and the Play lane does not use it — `app/scripts/build-release.sh:60-62` builds the same AAB *with* `--dart-define=API_BASE_URL="$API_URL"`. Two build paths disagree and the one wired to CI is the wrong one.

**2. There is nothing to point it at.**
`api/Dockerfile` and `api/docker-compose.yml` exist; nothing deploys them. `.github/workflows/` contains no SSH, registry push, or hosting step. No production hostname appears anywhere in the repository.

---

## Task 1: Decide and provision hosting — THE USER'S DECISION

Nothing below can be verified until an HTTPS endpoint exists. This task is listed first because it blocks everything, and it is **not** a decision an implementer should make alone.

What the API needs, taken from the code rather than assumed:
- Node, serving compiled `dist/` (`npm run start:prod`), port configurable
- PostgreSQL — currently `dukonpro-db`, schema managed by Prisma migrations
- Persistent disk for `uploads/receipts/` — receipts are written to local disk (`subscriptions.controller.ts`'s `diskStorage`), so an ephemeral filesystem loses them on every deploy
- Environment: `DATABASE_URL`, `JWT_ACCESS_EXPIRATION`, `THROTTLE_TTL`, `THROTTLE_LIMIT`, plus whatever `api/.env` holds today
- HTTPS, because the project's own security rules require it in production

**The uploads directory is the sharpest constraint** and rules out the simplest platforms: a container that restarts with a clean filesystem silently loses every merchant's payment receipt. Either the host provides a persistent volume, or receipts move to object storage first — which is its own piece of work and should be decided here, not discovered later.

- [ ] **Step 1: Choose a target.** Options to weigh, with the uploads problem against each: a VPS with Docker Compose and a mounted volume (simplest, manual ops); a managed container platform with an attached persistent disk; or a managed platform plus S3-compatible storage for receipts (most work, cleanest).
- [ ] **Step 2: Provision it and record the hostname.** The remaining tasks need one concrete value: the public HTTPS base URL, including the `/api` prefix the app expects.
- [ ] **Step 3: Run the migrations against the production database.** `npx prisma migrate deploy` — **not** `migrate dev`, which is for development and will prompt. The migration journal was repaired on 2026-10-08, so the history is clean and `deploy` will apply all of it to an empty database.
- [ ] **Step 4: Confirm the API answers over HTTPS** before touching the app: `curl -s -o /dev/null -w "%{http_code}" https://<host>/api/health` must return 200.

---

## Task 2: Inject the API URL into the Play build

**Files:** `app/fastlane/Fastfile:20-23`, `.github/workflows/deploy.yml`

- [ ] **Step 1: Prove the defect before fixing it**

```bash
cd app && flutter build appbundle --release
unzip -p build/app/outputs/bundle/release/app-release.aab \
  base/dex/classes.dex 2>/dev/null | strings | grep -c "10.0.2.2" || true
```
Expected: a non-zero count — the emulator address is compiled into the shipped bundle. If the grep finds nothing, inspect how `String.fromEnvironment` landed before concluding the defect is absent; do not skip ahead.

- [ ] **Step 2: Add the define to the Fastfile**

Replace lines 20-23 of `app/fastlane/Fastfile`:

```ruby
    api_url = ENV.fetch("API_BASE_URL") do
      UI.user_error!(
        "API_BASE_URL is not set. Without it the bundle falls back to " \
        "http://10.0.2.2:4455/api — the Android emulator's alias for the " \
        "developer's own machine — and the app cannot reach anything on a " \
        "real device."
      )
    end

    sh("flutter build appbundle --release " \
       "--build-name=#{version_name} " \
       "--build-number=#{build_number} " \
       "--dart-define=API_BASE_URL=#{api_url}",
       chdir: "..")
```

`ENV.fetch` with a raising block, not a default: a default would let the lane quietly ship the broken bundle again, which is exactly how this happened. A release that cannot be built without the URL cannot be released without it.

- [ ] **Step 3: Supply it in CI**

In `.github/workflows/deploy.yml`, on the `Deploy to Play Internal` step, add:

```yaml
        env:
          API_BASE_URL: ${{ secrets.API_BASE_URL }}
```

Add the same to the iOS lane if `ios beta` builds the Flutter app — read the Fastfile's `platform :ios` block and check; if it calls `flutter build ipa`, it has the identical defect and must get the identical fix. Report what you find.

- [ ] **Step 4: Verify the fix the same way you proved the defect**

```bash
cd app && API_BASE_URL=https://example.test/api bundle exec fastlane android beta --dry-run 2>/dev/null || \
  flutter build appbundle --release --dart-define=API_BASE_URL=https://example.test/api
unzip -p build/app/outputs/bundle/release/app-release.aab base/dex/classes.dex | strings | grep -c "example.test"
unzip -p build/app/outputs/bundle/release/app-release.aab base/dex/classes.dex | strings | grep -c "10.0.2.2"
```
Expected: the first count non-zero, the second zero. **Both assertions matter** — the new URL being present does not prove the old default is gone.

- [ ] **Step 5: Commit.** The message must state that the release lane shipped the emulator loopback, and that `scripts/build-release.sh` already did this correctly — two build paths disagreed and CI used the wrong one.

---

## Task 3: Prove it on a physical device

The emulator cannot catch this defect: `10.0.2.2` works there. That is precisely why it survived.

- [ ] **Step 1: Build an APK against the real host** — `flutter build apk --release --dart-define=API_BASE_URL=https://<host>/api`
- [ ] **Step 2: Install on a real phone**, over USB or by sideloading. Not an emulator.
- [ ] **Step 3: Exercise the paths that need the network**, and name what you saw rather than "it worked": sign in with a QA account; open Товары and confirm the list is populated; make one sale; open Настройки → Подписка and confirm the plan cards show prices from the server.
- [ ] **Step 4: Confirm a receipt upload survives a redeploy.** Submit a card payment with a receipt, redeploy the API, then reopen the payment history and open the receipt image. If it 404s, the host's filesystem is ephemeral and Task 1's uploads question was answered wrongly — stop and report rather than working around it.

---

## Task 4: The signing fallback that fails silently

`app/android/app/build.gradle.kts:37-51` falls back to the **debug** signing config when `key.properties` is absent. CI writes that file, so CI is fine; a local release build produces a debug-signed AAB with no warning, which Play rejects for a reason the error message does not make obvious.

- [ ] **Step 1: Make the fallback loud.** Keep it — it is useful for local development — but have the release build print a clear warning naming the consequence, so a developer who builds locally and uploads knows why Play refused it. A hard failure is the alternative and is defensible; choose one and say why in the commit.
- [ ] **Step 2: Verify both branches** — with and without `key.properties` present — and confirm the warning appears only in the fallback case.

---

## Task 5: Play Console obligations

Not code. Listed so it is not discovered during review.

- [ ] **Step 1: Justify two permissions.** `ACCESS_FINE_LOCATION` (`AndroidManifest.xml:13`) is required for Bluetooth scanning of receipt printers, and `SCHEDULE_EXACT_ALARM` (`:17`) is restricted from Android 13 and granted only to some app categories. Both need a declaration in the console. Check whether `ACCESS_FINE_LOCATION` can be dropped in favour of `BLUETOOTH_SCAN` with `neverForLocation`, which would remove the obligation entirely — the manifest already requests `BLUETOOTH_SCAN` at `:10`.
- [ ] **Step 2: Data Safety form and privacy policy.** The app handles phone numbers, customer records and payment receipts. Neither artefact exists in the repository; confirm whether they exist outside it before writing new ones.
- [ ] **Step 3: Store listing.** The Fastfile skips metadata, screenshots and images (`:34-37`), so nothing in CI maintains them. Confirm who does.

---

## What this plan does not cover

Stated so silence is not read as approval: iOS beyond the shared `--dart-define` defect, ProGuard rule correctness under the already-enabled `isMinifyEnabled`, the actual resolved value of `targetSdk` (inherited from the Flutter toolchain rather than pinned), load or security testing of the deployed API, and backup/restore for the production database.
