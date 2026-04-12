#!/bin/bash
set -e

# DokonPro Release Build Script
# Usage: ./scripts/build-release.sh https://api.dokonpro.tj

API_URL="${1:-https://api.dokonpro.tj}"

echo "=== DokonPro Release Build ==="
echo "API URL: $API_URL"
echo ""

# Pre-flight checks
echo "[1/6] Checking prerequisites..."

if [ ! -f "android/key.properties" ]; then
  echo "ERROR: android/key.properties not found!"
  echo "Create it with:"
  echo "  storePassword=YOUR_PASSWORD"
  echo "  keyPassword=YOUR_PASSWORD"
  echo "  keyAlias=upload"
  echo "  storeFile=upload-keystore.jks"
  exit 1
fi

if [ ! -f "android/upload-keystore.jks" ]; then
  echo "ERROR: android/upload-keystore.jks not found!"
  echo "Generate it with: keytool -genkey -v -keystore android/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload"
  exit 1
fi

echo "  keystore: OK"
echo "  key.properties: OK"

# Clean
echo "[2/6] Cleaning build artifacts..."
flutter clean
flutter pub get

# Analyze
echo "[3/6] Running analyzer..."
flutter analyze --no-fatal-infos
if [ $? -ne 0 ]; then
  echo "ERROR: flutter analyze found errors. Fix them first."
  exit 1
fi
echo "  Analyze: OK"

# Test
echo "[4/6] Running tests..."
flutter test
if [ $? -ne 0 ]; then
  echo "ERROR: Tests failed. Fix them first."
  exit 1
fi
echo "  Tests: OK"

# Build AAB
echo "[5/6] Building app bundle..."
flutter build appbundle \
  --release \
  --dart-define=API_BASE_URL="$API_URL"

AAB_PATH="build/app/outputs/bundle/release/app-release.aab"
if [ ! -f "$AAB_PATH" ]; then
  echo "ERROR: AAB not found at $AAB_PATH"
  exit 1
fi

AAB_SIZE=$(du -h "$AAB_PATH" | cut -f1)
echo "  AAB: $AAB_PATH ($AAB_SIZE)"

# Also build APK for testing
echo "[6/6] Building APK for testing..."
flutter build apk \
  --release \
  --dart-define=API_BASE_URL="$API_URL"

APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
APK_SIZE=$(du -h "$APK_PATH" | cut -f1)
echo "  APK: $APK_PATH ($APK_SIZE)"

echo ""
echo "=== Build Complete ==="
echo ""
echo "Upload to Play Console:"
echo "  1. Go to https://play.google.com/console"
echo "  2. Select 'DokonPro' app (or create new)"
echo "  3. Go to: Release > Production > Create new release"
echo "  4. Upload: $AAB_PATH"
echo "  5. Add release notes"
echo "  6. Review and submit"
echo ""
echo "For testing on device:"
echo "  adb install $APK_PATH"
