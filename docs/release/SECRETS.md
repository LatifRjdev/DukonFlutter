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
