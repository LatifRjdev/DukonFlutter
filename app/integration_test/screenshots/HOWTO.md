# Capturing Store Screenshots — Manual Workflow

## Status

5 ru-RU screenshots already captured (onboarding 1-4 + login). Sufficient
for Play Store minimum (≥2 required). Apple App Store also accepts these
but requires resize to specific iPhone dimensions — see "Resize for App
Store" below.

```
android/fastlane/metadata/android/ru-RU/images/phoneScreenshots/
├── 01-onboarding-1.png   "Быстрые продажи"  (1080×2400)
├── 02-onboarding-2.png   "Учёт товаров"     (1080×2400)
├── 03-onboarding-3.png   "Аналитика"        (1080×2400)
├── 04-onboarding-4.png   "Работает офлайн"  (1080×2400)
└── 05-login.png          DukonPro login     (1080×2400)
```

## Why we couldn't auto-capture inner screens

`flutter drive` integration_test setup hangs after APK install on this
machine — known issue with Flutter/test_driver/IntegrationTestBinding
compat under newer Flutter SDK. Documented but not blocking.

For inner (authenticated) screens — POS, dashboard, products, customers,
shifts, reports — the simplest workflow is manual:

## How to capture more screenshots manually

### 1. Start API + Postgres

```bash
# Terminal A: Postgres + Redis (if not already running)
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
docker compose up -d postgres redis

# Terminal B: API
cd api
npm run start:dev
# wait until you see "Application is running on: http://[::1]:4455"
```

### 2. Boot Android emulator + launch app

The DukonPro APK is already installed on emulator-5554 from this session.
Just relaunch:

```bash
adb -s emulator-5554 shell monkey -p com.itlsolutions.dukonpro \
    -c android.intent.category.LAUNCHER 1
```

If you destroyed the emulator since: rebuild + install:

```bash
cd app
flutter build apk --debug
adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-debug.apk
adb -s emulator-5554 shell monkey -p com.itlsolutions.dukonpro \
    -c android.intent.category.LAUNCHER 1
```

### 3. Login as admin

On the login screen:
- Phone: `+992000000000`
- Password: `admin123`

(Created via `api/scripts/create-admin.ts`. Re-create with
`cd api && npx ts-node scripts/create-admin.ts` if needed.)

### 4. Navigate + capture each screen

For each screen of interest, tap your way to it, then:

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/app/android/fastlane/metadata/android/ru-RU/images/phoneScreenshots/
adb -s emulator-5554 exec-out screencap -p > 06-dashboard.png
adb -s emulator-5554 exec-out screencap -p > 07-pos.png
adb -s emulator-5554 exec-out screencap -p > 08-products.png
adb -s emulator-5554 exec-out screencap -p > 09-customers.png
adb -s emulator-5554 exec-out screencap -p > 10-reports.png
```

The exec-out trick streams the PNG directly without temp files. Output
is exactly the device's display resolution (1080×2400 here).

### Suggested screen order (for store conversion)

After login, navigate via bottom-nav and capture:

1. **Dashboard / home** — daily totals, top metrics
2. **POS / cashier** — products in cart with totals
3. **Product catalog** — list view with sample products
4. **Customer list** — sample customers with debt balances
5. **Reports** — daily/weekly chart
6. **Shifts** — active shift card or shift history

Take 3-5 inner screenshots in addition to the 5 already captured.
Both stores show 5-8 well, so total of 8-10 is the sweet spot.

## Resize for App Store (iOS submission)

Apple requires specific iPhone dimensions. Once you have screenshots from
Android (1080×2400), resize them to iOS sizes via `sips` (macOS native):

```bash
SRC=android/fastlane/metadata/android/ru-RU/images/phoneScreenshots
DST_67=ios/fastlane/screenshots/ru-RU/iphone67
DST_65=ios/fastlane/screenshots/ru-RU/iphone55

mkdir -p $DST_67 $DST_65

for f in $SRC/*.png; do
  name=$(basename $f)
  sips -Z 2796 -c 2796 1290 $f --out $DST_67/$name
  sips -Z 2688 -c 2688 1242 $f --out $DST_65/$name
done
```

⚠️ Resized screenshots from Android won't be pixel-perfect iOS UI
(they'll have Android system bars + slightly different proportions).
**Apple will reject these in review.** For real App Store submission you
need actual iOS Simulator screenshots, which requires the full Xcode app.

For Play Store the Android screenshots work as-is.

## After install of full Xcode

Once you install Xcode from App Store + iOS Simulator runtime:

```bash
xcode-select --switch /Applications/Xcode.app/Contents/Developer

# Boot iPhone 15 Pro Max sim (6.7")
xcrun simctl boot "iPhone 15 Pro Max"
open -a Simulator

cd app
flutter build ios --no-codesign
flutter install -d "iPhone 15 Pro Max"
# Or run interactively:
flutter run -d "iPhone 15 Pro Max"
```

Then take screenshots via:
- **Cmd+S** in Simulator (saves to ~/Desktop)
- Or `xcrun simctl io booted screenshot screenshot.png`
- Repeat for `iPhone 11 Pro Max` (6.5")
