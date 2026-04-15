# Firebase Setup for DukonPro

## Step 1: Create Firebase Project

1. Go to https://console.firebase.google.com/
2. Click "Add project"
3. Name: `DukonPro`
4. Disable Google Analytics (not needed for now)
5. Click "Create project"

## Step 2: Add Android App

1. In Firebase console, click "Add app" → Android
2. Package name: `com.itlsolutions.dokonpro`
3. App nickname: `DukonPro`
4. SHA-1 (get it by running): 
   ```bash
   cd /Users/latifrjdev/Downloads/Dukon/app/android
   keytool -list -v -keystore upload-keystore.jks -alias upload
   ```
   Copy the SHA1 fingerprint and paste it
5. Click "Register app"
6. Download `google-services.json`
7. Place it at: `app/android/app/google-services.json`

## Step 3: Enable Cloud Messaging

1. In Firebase console → Project settings → Cloud Messaging
2. Cloud Messaging API (V1) should be enabled by default
3. Go to Project settings → Service accounts
4. Click "Generate new private key"
5. Download the JSON file
6. Convert to single-line: `cat firebase-key.json | jq -c .`
7. Add to backend `.env`:
   ```
   FIREBASE_SERVICE_ACCOUNT={"type":"service_account","project_id":"dokonpro",...}
   ```

## Step 4: Verify Flutter Config

```bash
cd /Users/latifrjdev/Downloads/Dukon/app
dart pub global activate flutterfire_cli
flutterfire configure --project=dokonpro
```

This generates `firebase_options.dart` — commit it.

## Files to NOT commit (add to .gitignore)
- `google-services.json` (contains API keys)
- Firebase service account JSON
