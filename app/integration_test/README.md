# DukonPro Store Screenshot Harness

Captures App Store / Play Store screenshots via `integration_test`
(Path A — see `screenshots_test.dart` docstring for Path B post-processing).

## One-time setup

```bash
cd app
flutter pub get
```

## Run on iOS Simulator (App Store 6.7" — iPhone 15 Pro Max)

```bash
# Boot the simulator if it isn't already running
xcrun simctl boot "iPhone 15 Pro Max" 2>/dev/null || true
open -a Simulator

cd app
flutter drive \
  --driver=test_driver/integration_driver.dart \
  --target=integration_test/screenshots_test.dart \
  --dart-define=DEVICE_SLUG=ios-6.7-iphone-15-pro-max \
  -d "iPhone 15 Pro Max"
```

## Run on iOS Simulator (App Store 6.5" — iPhone 8 Plus class)

```bash
cd app
flutter drive \
  --driver=test_driver/integration_driver.dart \
  --target=integration_test/screenshots_test.dart \
  --dart-define=DEVICE_SLUG=ios-6.5 \
  -d "iPhone 8 Plus"
```

## Run on Android (Play Store)

```bash
# Pick a connected device or emulator id from `flutter devices`
flutter devices

cd app
flutter drive \
  --driver=test_driver/integration_driver.dart \
  --target=integration_test/screenshots_test.dart \
  --dart-define=DEVICE_SLUG=android-phone \
  -d <android-device-id>
```

## Output

PNGs are written to:

```
app/integration_test/screenshots/<DEVICE_SLUG>/
  01-splash-or-login.png
  02-login.png
  03-register.png
  04-forgot-password.png
  05-onboarding.png
  06-home-dashboard.png   (only useful if signed in — see below)
  07-products.png
  08-customers.png
  09-reports.png
  10-shifts.png
```

## Authenticated screens

The router gates `/home`, `/products`, `/customers`, `/finance/reports`,
`/shifts`, etc. behind `AuthLocalDatasource.hasTokens()`. If you run on a
fresh sim/device, the router redirects to `/login` and screenshots 06–10
will all show the login page.

To capture the authenticated screens:

1. Run the app normally on the same simulator/device first, sign in once,
   then quit. `flutter_secure_storage` persists the token in the
   Keychain / EncryptedSharedPreferences.
2. Re-run the screenshot driver — redirects will now resolve to `/home`.

(Alternative: the existing golden tests under
`app/test/presentation/pages/` render individual pages with mocked Blocs.
Promote those PNGs to store assets if you'd rather not touch real auth.)

## Path B — pixel-exact App Store dimensions

The screenshots come out at the device's logical resolution. Apple
accepts these as long as they're sharp, but if you need exact
1290 × 2796 (6.7") or 1242 × 2688 (6.5"):

```bash
brew install imagemagick
cd app/integration_test/screenshots/ios-6.7-iphone-15-pro-max
mkdir -p ../app-store-6.7
for f in *.png; do
  magick "$f" -resize 1290x2796^ -gravity center -extent 1290x2796 \
         "../app-store-6.7/$f"
done
```

## Verify the test compiles

```bash
cd app
flutter analyze integration_test/ test_driver/
```

Should report `No issues found!`.
