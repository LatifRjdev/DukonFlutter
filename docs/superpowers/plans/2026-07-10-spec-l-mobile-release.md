# Spec L: Mobile Release Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire up app icons, splash screen, Fastlane automation, and GitHub Actions deploy pipeline so that pushing a `v*.*.*` tag builds and uploads to both Google Play Internal Testing and TestFlight automatically.

**Architecture:** `flutter_launcher_icons` regenerates all icon densities from a master PNG; `flutter_native_splash` produces the Android 12-compatible splash. A single `app/fastlane/Fastfile` holds `platform :android` and `platform :ios` lanes. GitHub Actions `deploy.yml` runs both lanes in parallel on tag push — ubuntu for Android, self-hosted Mac for iOS.

**Tech Stack:** Flutter 3.38.5, flutter_launcher_icons ^0.14.0, flutter_native_splash ^2.4.0, Fastlane (Ruby), fastlane-plugin-supply, fastlane-plugin-pilot, GitHub Actions, Fastlane Match

---

## What already exists (do NOT re-create)

- `app/android/key.properties` — local keystore config (in .gitignore) ✓
- `app/android/upload-keystore.jks` — local signing keystore ✓
- `app/android/app/build.gradle.kts` — signing config already reads `key.properties` ✓
- `app/android/fastlane/metadata/android/ru-RU/` — Play Store listing copy ✓
- `app/ios/fastlane/metadata/ru-RU/` — App Store listing copy ✓
- `app/ios/Runner/Assets.xcassets/AppIcon.appiconset/` — iOS icons (all sizes) ✓
- `app/ios/Runner/Assets.xcassets/LaunchImage.imageset/` — iOS launch image ✓

## File Map

| File | Action | Purpose |
|------|--------|---------|
| `app/assets/icon/icon.png` | Create (copy) | Master 1024×1024 icon for generation |
| `app/flutter_launcher_icons.yaml` | Create | Config for icon generation |
| `app/flutter_native_splash.yaml` | Create | Config for splash generation |
| `app/pubspec.yaml` | Modify | Add dev_dependencies + assets/icon/ |
| `app/fastlane/Gemfile` | Create | Pin fastlane + plugins |
| `app/fastlane/Appfile` | Create | App identifiers |
| `app/fastlane/Fastfile` | Create | Android + iOS lanes |
| `app/fastlane/Matchfile` | Create | iOS cert sync config |
| `app/ios/ExportOptions.plist` | Create | IPA export settings for CI |
| `app/android/key.properties.example` | Create | Template for onboarding |
| `.github/workflows/deploy.yml` | Create | Release pipeline |
| `docs/release/SECRETS.md` | Create | GitHub Secrets reference |

---

## Task 1: App icon — flutter_launcher_icons

**Files:**
- Modify: `app/pubspec.yaml`
- Create: `app/flutter_launcher_icons.yaml`
- Create: `app/assets/icon/icon.png` (manual copy)

The Android icons in `mipmap-*/` are still the default Flutter icon (544 bytes). Replace them.
The iOS 1024×1024 icon at `app/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png` is the branded master — use it as the source.

- [ ] **Step 1: Copy the branded master icon**

```bash
mkdir -p app/assets/icon
cp app/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png \
   app/assets/icon/icon.png
```

- [ ] **Step 2: Add flutter_launcher_icons to pubspec dev_dependencies**

In `app/pubspec.yaml`, add under `dev_dependencies:`:
```yaml
  flutter_launcher_icons: ^0.14.0
```

Also add the icon asset folder under `flutter: assets:`:
```yaml
  assets:
    - assets/images/
    - assets/icons/
    - assets/fonts/
    - assets/icon/
```

- [ ] **Step 3: Create flutter_launcher_icons.yaml**

Create `app/flutter_launcher_icons.yaml`:
```yaml
flutter_launcher_icons:
  android: "ic_launcher"
  ios: true
  image_path: "assets/icon/icon.png"
  min_sdk_android: 21
  adaptive_icon_background: "#FFFFFF"
  adaptive_icon_foreground: "assets/icon/icon.png"
  remove_alpha_ios: true
```

- [ ] **Step 4: Get packages and run the generator**

```bash
cd app
flutter pub get
dart run flutter_launcher_icons
```

Expected output: lines like `✓ Successfully generated launcher icons` for each platform.

- [ ] **Step 5: Verify tests still pass**

```bash
flutter test --no-pub
```

Expected: `All tests passed!` (456 tests).

- [ ] **Step 6: Commit**

```bash
git add app/pubspec.yaml app/pubspec.lock app/flutter_launcher_icons.yaml \
  app/assets/icon/ \
  app/android/app/src/main/res/ \
  app/ios/Runner/Assets.xcassets/AppIcon.appiconset/
git commit -m "feat(release): branded app icons via flutter_launcher_icons (Spec L T1)"
```

---

## Task 2: Splash screen — flutter_native_splash

**Files:**
- Modify: `app/pubspec.yaml`
- Create: `app/flutter_native_splash.yaml`

The current Android splash is the default white screen. This task adds a branded splash with the app's primary colour (`#1565C0`) on both platforms, including the Android 12 splash API.

- [ ] **Step 1: Add flutter_native_splash to pubspec dev_dependencies**

In `app/pubspec.yaml`, under `dev_dependencies:`:
```yaml
  flutter_native_splash: ^2.4.0
```

- [ ] **Step 2: Create flutter_native_splash.yaml**

Create `app/flutter_native_splash.yaml`:
```yaml
flutter_native_splash:
  color: "#1565C0"
  image: assets/icon/icon.png
  color_dark: "#0D47A1"
  image_dark: assets/icon/icon.png
  android_12:
    color: "#1565C0"
    image: assets/icon/icon.png
    icon_background_color: "#1565C0"
    color_dark: "#0D47A1"
    image_dark: assets/icon/icon.png
    icon_background_color_dark: "#0D47A1"
  fullscreen: false
  android: true
  ios: true
```

- [ ] **Step 3: Run the splash generator**

```bash
cd app
flutter pub get
dart run flutter_native_splash:create
```

Expected: `✓ Native splash configured successfully` (or similar).

- [ ] **Step 4: Verify tests still pass**

```bash
flutter test --no-pub
```

Expected: `All tests passed!` (456 tests).

- [ ] **Step 5: Commit**

```bash
git add app/pubspec.yaml app/pubspec.lock app/flutter_native_splash.yaml \
  app/android/app/src/main/res/ \
  app/ios/Runner/
git commit -m "feat(release): branded splash screen via flutter_native_splash (Spec L T2)"
```

---

## Task 3: Fastlane Gemfile + Appfile

**Files:**
- Create: `app/fastlane/Gemfile`
- Create: `app/fastlane/Appfile`

- [ ] **Step 1: Create the Gemfile**

Create `app/fastlane/Gemfile`:
```ruby
source "https://rubygems.org"

gem "fastlane", "~> 2.225"
```

- [ ] **Step 2: Create Appfile**

Create `app/fastlane/Appfile`:
```ruby
# Android
json_key_file("")           # not used — key passed via env var in lanes
package_name("com.itlsolutions.dukonpro")

# iOS
apple_id(ENV["APPLE_ID"] || "")
itc_team_id(ENV["ITC_TEAM_ID"] || "")
team_id(ENV["TEAM_ID"] || "")
app_identifier("com.itlsolutions.dukonpro")
```

- [ ] **Step 3: Install gems**

```bash
cd app
bundle install
```

Expected: Gemfile.lock created, fastlane installed (version ~2.225.x).

- [ ] **Step 4: Verify fastlane is runnable**

```bash
cd app
bundle exec fastlane --version
```

Expected: `fastlane installation at path:` + version line.

- [ ] **Step 5: Commit**

```bash
git add app/fastlane/Gemfile app/fastlane/Gemfile.lock app/fastlane/Appfile
git commit -m "feat(release): Fastlane Gemfile + Appfile (Spec L T3)"
```

---

## Task 4: Fastfile — Android lane

**Files:**
- Create: `app/fastlane/Fastfile`
- Create: `app/android/key.properties.example`

- [ ] **Step 1: Create key.properties.example**

Create `app/android/key.properties.example`:
```
# Copy this file to key.properties (gitignored) and fill in your values.
# For CI, these values come from GitHub Secrets — see docs/release/SECRETS.md.
storePassword=REPLACE
keyPassword=REPLACE
keyAlias=upload
storeFile=upload-keystore.jks
```

- [ ] **Step 2: Create the Fastfile with the Android beta lane**

Create `app/fastlane/Fastfile`:
```ruby
# Fastfile for Dukon — manages Android (Play) and iOS (TestFlight) releases.
# Run from the `app/` directory: bundle exec fastlane android beta
# Version is read from the GITHUB_REF_NAME env var (e.g. "v1.2.3").

def parse_version
  ref = ENV.fetch("GITHUB_REF_NAME", "v0.0.0")
  ref.delete_prefix("v")             # "1.2.3"
end

def parse_build_number
  parse_version.delete(".").to_i     # 123
end

platform :android do
  desc "Build release AAB and upload to Play Internal Testing"
  lane :beta do
    version_name = parse_version
    build_number = parse_build_number

    sh("flutter build appbundle --release " \
       "--build-name=#{version_name} " \
       "--build-number=#{build_number}",
       chdir: "..")

    upload_to_play_store(
      track: "internal",
      aab: "../build/app/outputs/bundle/release/app-release.aab",
      json_key_data: ENV.fetch("PLAY_SERVICE_ACCOUNT_JSON"),
      package_name: "com.itlsolutions.dukonpro",
      skip_upload_apk: true,
      skip_upload_metadata: true,
      skip_upload_changelogs: true,
      skip_upload_images: true,
      skip_upload_screenshots: true,
      release_status: "draft",
    )
  end
end
```

- [ ] **Step 3: Verify Fastfile syntax**

```bash
cd app
bundle exec fastlane lanes
```

Expected: prints `android beta` lane without errors.

- [ ] **Step 4: Commit**

```bash
git add app/fastlane/Fastfile app/android/key.properties.example
git commit -m "feat(release): Fastfile Android beta lane (Spec L T4)"
```

---

## Task 5: iOS lane — Matchfile + ExportOptions + iOS Fastfile lane

**Files:**
- Create: `app/fastlane/Matchfile`
- Create: `app/ios/ExportOptions.plist`
- Modify: `app/fastlane/Fastfile` (add `platform :ios` block)

Prerequisites: Apple Developer account with App ID `com.itlsolutions.dukonpro` created. Private `dukon-certificates` repo created. Match initialized once via `bundle exec fastlane match init` (interactive — not scripted here).

- [ ] **Step 1: Create Matchfile**

Create `app/fastlane/Matchfile`:
```ruby
git_url(ENV.fetch("MATCH_GIT_URL", ""))
storage_mode("git")
type("appstore")
app_identifier(["com.itlsolutions.dukonpro"])
username(ENV.fetch("APPLE_ID", ""))
```

- [ ] **Step 2: Create ExportOptions.plist**

Create `app/ios/ExportOptions.plist`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>app-store</string>
  <key>teamID</key>
  <string>REPLACE_WITH_TEAM_ID</string>
  <key>uploadSymbols</key>
  <true/>
  <key>compileBitcode</key>
  <false/>
  <key>signingStyle</key>
  <string>manual</string>
  <key>provisioningProfiles</key>
  <dict>
    <key>com.itlsolutions.dukonpro</key>
    <string>match AppStore com.itlsolutions.dukonpro</string>
  </dict>
</dict>
</plist>
```

Replace `REPLACE_WITH_TEAM_ID` with your 10-character Apple Developer Team ID (visible at developer.apple.com → Membership).

- [ ] **Step 3: Add iOS platform block to Fastfile**

Append to `app/fastlane/Fastfile` (after the closing `end` of `platform :android`):
```ruby

platform :ios do
  desc "Build release IPA and upload to TestFlight"
  lane :beta do
    version_name = parse_version
    build_number = parse_build_number

    api_key = app_store_connect_api_key(
      key_id:       ENV.fetch("APP_STORE_CONNECT_API_KEY_ID"),
      issuer_id:    ENV.fetch("APP_STORE_CONNECT_ISSUER_ID"),
      key_content:  ENV.fetch("APP_STORE_CONNECT_API_KEY_BASE64"),
      is_key_content_base64: true,
      duration:     1200,
    )

    match(
      type:     "appstore",
      readonly: true,
      api_key:  api_key,
    )

    sh("flutter build ipa --release " \
       "--build-name=#{version_name} " \
       "--build-number=#{build_number} " \
       "--export-options-plist=ios/ExportOptions.plist",
       chdir: "..")

    upload_to_testflight(
      api_key:                          api_key,
      ipa:                              "../build/ios/ipa/dukonpro.ipa",
      skip_waiting_for_build_processing: true,
      notify_external_testers:          false,
    )
  end
end
```

- [ ] **Step 4: Verify Fastfile syntax**

```bash
cd app
bundle exec fastlane lanes
```

Expected: both `android beta` and `ios beta` lanes listed.

- [ ] **Step 5: Commit**

```bash
git add app/fastlane/Matchfile app/fastlane/Fastfile app/ios/ExportOptions.plist
git commit -m "feat(release): Fastfile iOS beta lane + Match + ExportOptions (Spec L T5)"
```

---

## Task 6: GitHub Actions deploy.yml

**Files:**
- Create: `.github/workflows/deploy.yml`

- [ ] **Step 1: Create deploy.yml**

Create `.github/workflows/deploy.yml`:
```yaml
name: Release

on:
  push:
    tags:
      - 'v*.*.*'

jobs:
  android-release:
    name: Android → Play Internal
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: app
    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          flutter-version: "3.38.5"
          channel: stable
          cache: true

      - name: Setup Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: '3.2'
          bundler-cache: true
          working-directory: app

      - name: Decode keystore
        run: |
          echo "${{ secrets.ANDROID_KEYSTORE_BASE64 }}" | base64 --decode \
            > android/upload-keystore.jks

      - name: Write key.properties
        run: |
          cat > android/key.properties <<EOF
          storePassword=${{ secrets.ANDROID_STORE_PASSWORD }}
          keyPassword=${{ secrets.ANDROID_KEY_PASSWORD }}
          keyAlias=${{ secrets.ANDROID_KEY_ALIAS }}
          storeFile=upload-keystore.jks
          EOF

      - name: Flutter pub get
        run: flutter pub get

      - name: Deploy to Play Internal
        run: bundle exec fastlane android beta
        env:
          PLAY_SERVICE_ACCOUNT_JSON: ${{ secrets.PLAY_SERVICE_ACCOUNT_JSON }}
          GITHUB_REF_NAME: ${{ github.ref_name }}

  ios-release:
    name: iOS → TestFlight
    runs-on: [self-hosted, macOS]
    defaults:
      run:
        working-directory: app
    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          flutter-version: "3.38.5"
          channel: stable
          cache: true

      - name: Setup Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: '3.2'
          bundler-cache: true
          working-directory: app

      - name: Flutter pub get
        run: flutter pub get

      - name: Deploy to TestFlight
        run: bundle exec fastlane ios beta
        env:
          MATCH_PASSWORD: ${{ secrets.MATCH_PASSWORD }}
          MATCH_GIT_URL: ${{ secrets.MATCH_GIT_URL }}
          APPLE_ID: ${{ secrets.APPLE_ID }}
          APP_STORE_CONNECT_API_KEY_ID: ${{ secrets.APP_STORE_CONNECT_API_KEY_ID }}
          APP_STORE_CONNECT_ISSUER_ID: ${{ secrets.APP_STORE_CONNECT_ISSUER_ID }}
          APP_STORE_CONNECT_API_KEY_BASE64: ${{ secrets.APP_STORE_CONNECT_API_KEY_BASE64 }}
          GITHUB_REF_NAME: ${{ github.ref_name }}
```

- [ ] **Step 2: Verify YAML syntax**

```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/deploy.yml'))"
```

Expected: no output (valid YAML).

- [ ] **Step 3: Verify existing ci.yml still valid**

```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml'))"
```

Expected: no output.

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/deploy.yml
git commit -m "feat(release): GitHub Actions deploy.yml for Play + TestFlight (Spec L T6)"
```

---

## Task 7: Secrets documentation

**Files:**
- Create: `docs/release/SECRETS.md`

- [ ] **Step 1: Create the secrets reference doc**

Create `docs/release/SECRETS.md`:
```markdown
# GitHub Secrets for Release Pipeline

Set these in: GitHub → Settings → Secrets and variables → Actions → Repository secrets

## Android

| Secret | How to get |
|--------|-----------|
| `ANDROID_KEYSTORE_BASE64` | `base64 -i android/upload-keystore.jks` (run locally) |
| `ANDROID_KEY_ALIAS` | Value of `keyAlias` in `android/key.properties` (currently `upload`) |
| `ANDROID_KEY_PASSWORD` | Value of `keyPassword` in `android/key.properties` |
| `ANDROID_STORE_PASSWORD` | Value of `storePassword` in `android/key.properties` |
| `PLAY_SERVICE_ACCOUNT_JSON` | Full JSON content of Google Play service account key (Play Console → Setup → API access → Create service account → download JSON) |

## iOS

| Secret | How to get |
|--------|-----------|
| `MATCH_GIT_URL` | SSH URL of the private `dukon-certificates` repo (e.g. `git@github.com:org/dukon-certificates.git`) |
| `MATCH_PASSWORD` | Passphrase used when running `fastlane match init` (AES-256 encryption password) |
| `APPLE_ID` | Your Apple ID email (used for Match) |
| `APP_STORE_CONNECT_API_KEY_ID` | App Store Connect → Users → Keys → Key ID |
| `APP_STORE_CONNECT_ISSUER_ID` | App Store Connect → Users → Keys → Issuer ID |
| `APP_STORE_CONNECT_API_KEY_BASE64` | `base64 -i AuthKey_KEYID.p8` (the downloaded .p8 file) |

## Self-hosted Mac runner setup (one-time)

1. GitHub → Settings → Actions → Runners → New self-hosted runner → macOS
2. Follow the installation script shown in GitHub UI
3. Run as a service: `cd ~/actions-runner && ./svc.sh install && ./svc.sh start`
4. Ensure Xcode, Ruby 3.2, Flutter 3.38.5 are installed on the Mac
5. Runner appears in Actions with label `self-hosted, macOS`

## One-time iOS setup (before first release)

```bash
cd app
# Initialise Match (interactive — run locally, not in CI)
bundle exec fastlane match init
# Choose git storage, enter dukon-certificates repo URL, set MATCH_PASSWORD

# Create and push certificates + profiles for App Store
bundle exec fastlane match appstore
```
```

- [ ] **Step 2: Commit**

```bash
git add docs/release/SECRETS.md
git commit -m "docs(release): GitHub Secrets reference for Spec L pipeline (Spec L T7)"
```

---

## Self-Review

**Spec coverage check:**

| Spec requirement | Task |
|-----------------|------|
| flutter_launcher_icons + splash | T1, T2 |
| Android signing config | already done; key.properties.example in T4 |
| Fastlane Gemfile + Appfile | T3 |
| Fastfile android lane | T4 |
| Fastfile iOS lane + Match + ExportOptions | T5 |
| deploy.yml with ubuntu + self-hosted mac | T6 |
| Secrets documentation | T7 |

**Placeholder scan:** `REPLACE_WITH_TEAM_ID` in ExportOptions.plist — intentional, documented in T5 step 2. `REPLACE` in key.properties.example — intentional template. No other placeholders.

**Type consistency:** `parse_version` and `parse_build_number` defined at top of Fastfile and used in both platforms — consistent. `upload-keystore.jks` used in both CI yaml and key.properties — consistent.
