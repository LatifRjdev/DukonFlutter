# Spec L: Mobile Release — Android + iOS

## Goal

Prepare the Dukon app for production publishing to Google Play and App Store. Pushing a `v*.*.*` git tag triggers automated builds and uploads to both platforms without manual intervention.

## Architecture

- **Icons + splash:** `flutter_launcher_icons` and `flutter_native_splash` generate all platform assets from a single master PNG at build time. Generated files are committed to the repo.
- **Android signing:** keystore stored locally + in GitHub Secrets (base64). `build.gradle.kts` reads `key.properties` at build time.
- **iOS signing:** Fastlane Match syncs encrypted certificates and provisioning profiles from a private `dukon-certificates` repo. CI always runs `match --readonly`.
- **Release automation:** Fastlane `Fastfile` defines four lanes (`android_beta`, `android_release`, `ios_beta`, `ios_release`). Lanes patch `pubspec.yaml` version from the git tag, build, and upload.
- **CI:** Existing `ci.yml` runs tests on every push/PR (unchanged). New `deploy.yml` triggers on `v*.*.*` tags with two parallel jobs — ubuntu for Android, self-hosted Mac for iOS.

## Tech Stack

- Flutter 3.x, `flutter_launcher_icons ^0.14`, `flutter_native_splash ^2.4`
- Fastlane (Ruby gem), `supply` (Play), `pilot` (TestFlight)
- GitHub Actions (ubuntu-latest + self-hosted macOS runner)
- Fastlane Match (git storage, AES-256 encrypted)
- App Store Connect API Key (not Apple ID password)
- Google Play service account JSON

---

## Files

### New files
- `app/assets/icon/icon.png` — master icon 1024×1024 PNG (prepared manually, not generated)
- `app/flutter_launcher_icons.yaml` — icon generation config
- `app/flutter_native_splash.yaml` — splash screen config
- `app/fastlane/Gemfile` — pins fastlane + plugins
- `app/fastlane/Appfile` — app identifiers
- `app/fastlane/Fastfile` — lanes for build + deploy
- `app/fastlane/Matchfile` — Match git repo + type
- `app/android/key.properties.example` — template (no secrets, committed)
- `.github/workflows/deploy.yml` — release workflow

### Modified files
- `app/pubspec.yaml` — add `flutter_launcher_icons`, `flutter_native_splash` to dev_dependencies
- `app/android/app/build.gradle.kts` — add signing config reading `key.properties`
- `app/android/.gitignore` — add `key.properties`
- `.gitignore` (root) — add `app/android/key.properties`

---

## Detailed Design

### A. App Icons

`app/flutter_launcher_icons.yaml`:
```yaml
flutter_launcher_icons:
  android: "ic_launcher"
  ios: true
  image_path: "assets/icon/icon.png"
  min_sdk_android: 21
  adaptive_icon_background: "#FFFFFF"
  adaptive_icon_foreground: "assets/icon/icon.png"
  web:
    generate: false
```

Run: `dart run flutter_launcher_icons`

Generated files committed. CI does NOT re-run generation — generated files are source of truth.

### B. Splash Screen

`app/flutter_native_splash.yaml`:
```yaml
flutter_native_splash:
  color: "#1565C0"          # AppColors.primary
  image: assets/icon/icon.png
  color_dark: "#0D47A1"
  image_dark: assets/icon/icon.png
  android_12:
    color: "#1565C0"
    image: assets/icon/icon.png
  fullscreen: false
```

Run: `dart run flutter_native_splash:create`

Generated files committed.

### C. Android Signing

`app/android/key.properties.example`:
```
storePassword=<ANDROID_STORE_PASSWORD>
keyPassword=<ANDROID_KEY_PASSWORD>
keyAlias=<ANDROID_KEY_ALIAS>
storeFile=../dukon.jks
```

`app/android/.gitignore` additions:
```
key.properties
*.jks
```

`app/android/app/build.gradle.kts` signing config:
```kotlin
import java.util.Properties

val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties().apply {
    if (keyPropertiesFile.exists()) load(keyPropertiesFile.inputStream())
}

android {
    signingConfigs {
        create("release") {
            keyAlias = keyProperties["keyAlias"] as String? ?: System.getenv("ANDROID_KEY_ALIAS")
            keyPassword = keyProperties["keyPassword"] as String? ?: System.getenv("ANDROID_KEY_PASSWORD")
            storeFile = keyProperties["storeFile"]?.let { file(it as String) }
                ?: System.getenv("ANDROID_KEYSTORE_PATH")?.let { file(it) }
            storePassword = keyProperties["storePassword"] as String? ?: System.getenv("ANDROID_STORE_PASSWORD")
        }
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}
```

Keystore generation (one-time, developer's machine):
```bash
keytool -genkey -v -keystore dukon.jks -keyalg RSA -keysize 2048 \
  -validity 10000 -alias dukon
# Store dukon.jks in a secure location OUTSIDE the repo
```

### D. Fastlane Setup

`app/fastlane/Gemfile`:
```ruby
source "https://rubygems.org"
gem "fastlane"
gem "fastlane-plugin-flutter_version"
```

`app/fastlane/Appfile`:
```ruby
app_identifier(["com.itlsolutions.dukonpro"])
apple_id(ENV["APPLE_ID"])
itc_team_id(ENV["ITC_TEAM_ID"])
team_id(ENV["TEAM_ID"])
```

`app/fastlane/Matchfile`:
```ruby
git_url(ENV["MATCH_GIT_URL"])
storage_mode("git")
type("appstore")
app_identifier(["com.itlsolutions.dukonpro"])
```

`app/fastlane/Fastfile`:
```ruby
default_platform(:ios)

def version_from_tag
  tag = ENV["GITHUB_REF_NAME"] || sh("git describe --tags --abbrev=0").strip
  tag.delete_prefix("v")
end

def build_number_from_tag
  tag = ENV["GITHUB_REF_NAME"] || sh("git describe --tags --abbrev=0").strip
  tag.delete_prefix("v").gsub(".", "").to_i
end

platform :android do
  lane :beta do
    version = version_from_tag
    build = build_number_from_tag
    sh("flutter build appbundle --release " \
       "--build-name=#{version} --build-number=#{build}")
    supply(
      track: "internal",
      aab: "../build/app/outputs/bundle/release/app-release.aab",
      json_key_data: ENV["PLAY_SERVICE_ACCOUNT_JSON"],
      package_name: "com.itlsolutions.dukonpro",
      skip_upload_apk: true,
      skip_upload_metadata: true,
      skip_upload_changelogs: true,
      skip_upload_images: true,
      skip_upload_screenshots: true,
    )
  end
end

platform :ios do
  lane :beta do
    version = version_from_tag
    build = build_number_from_tag
    api_key = app_store_connect_api_key(
      key_id: ENV["APP_STORE_CONNECT_API_KEY_ID"],
      issuer_id: ENV["APP_STORE_CONNECT_ISSUER_ID"],
      key_content: ENV["APP_STORE_CONNECT_API_KEY_BASE64"],
      is_key_content_base64: true,
    )
    match(type: "appstore", readonly: true, api_key: api_key)
    sh("flutter build ipa --release " \
       "--build-name=#{version} --build-number=#{build} " \
       "--export-options-plist=../ios/ExportOptions.plist")
    pilot(
      api_key: api_key,
      ipa: "../build/ios/ipa/dukonpro.ipa",
      skip_waiting_for_build_processing: true,
    )
  end
end
```

`app/ios/ExportOptions.plist` (new):
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
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
</dict>
</plist>
```

### E. GitHub Actions Deploy Workflow

`.github/workflows/deploy.yml`:
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
          echo "$ANDROID_KEYSTORE_BASE64" | base64 --decode > android/dukon.jks
        env:
          ANDROID_KEYSTORE_BASE64: ${{ secrets.ANDROID_KEYSTORE_BASE64 }}

      - name: Write key.properties
        run: |
          cat > android/key.properties <<EOF
          storePassword=${{ secrets.ANDROID_STORE_PASSWORD }}
          keyPassword=${{ secrets.ANDROID_KEY_PASSWORD }}
          keyAlias=${{ secrets.ANDROID_KEY_ALIAS }}
          storeFile=../dukon.jks
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
          APP_STORE_CONNECT_API_KEY_ID: ${{ secrets.APP_STORE_CONNECT_API_KEY_ID }}
          APP_STORE_CONNECT_ISSUER_ID: ${{ secrets.APP_STORE_CONNECT_ISSUER_ID }}
          APP_STORE_CONNECT_API_KEY_BASE64: ${{ secrets.APP_STORE_CONNECT_API_KEY_BASE64 }}
          GITHUB_REF_NAME: ${{ github.ref_name }}
```

---

## GitHub Secrets Reference

Document in `docs/release/secrets.md` (not committed — reference only):

| Secret | Used by | Description |
|--------|---------|-------------|
| `ANDROID_KEYSTORE_BASE64` | Android CI | `base64 dukon.jks` |
| `ANDROID_KEY_ALIAS` | Android CI | Alias used in keytool |
| `ANDROID_KEY_PASSWORD` | Android CI | Key password |
| `ANDROID_STORE_PASSWORD` | Android CI | Keystore password |
| `PLAY_SERVICE_ACCOUNT_JSON` | Fastlane supply | Google Play service account JSON content |
| `MATCH_GIT_URL` | iOS CI | SSH or HTTPS URL of `dukon-certificates` repo |
| `MATCH_PASSWORD` | iOS CI | AES passphrase for Match encryption |
| `APP_STORE_CONNECT_API_KEY_ID` | iOS CI | Key ID from App Store Connect |
| `APP_STORE_CONNECT_ISSUER_ID` | iOS CI | Issuer UUID from App Store Connect |
| `APP_STORE_CONNECT_API_KEY_BASE64` | iOS CI | base64 of the `.p8` private key file |

---

## Out of Scope

- Creating Google Play Console and Apple Developer accounts
- App Store / Play Store listing metadata, screenshots, descriptions
- App review submission (manual step after TestFlight/Internal Testing)
- ProGuard / R8 obfuscation rules (separate ADR if needed)
- Crashlytics / Firebase integration (Spec M covers push notifications)

---

## Testing

- After icons/splash: run `flutter run` on physical Android + iOS device, verify splash and icon
- After Android signing: `flutter build appbundle --release` locally with `key.properties`, verify `jarsigner -verify`
- After deploy.yml: push tag `v0.0.1-test` to a feature branch (modify trigger temporarily), verify both jobs succeed in Actions
- Self-hosted runner: verify `runs-on: [self-hosted, macOS]` picks up the Mac, Xcode version matches project requirements
