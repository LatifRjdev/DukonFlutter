# User-provided inputs for Sprint 1 (prod blockers)

Заполни эту форму, как только соберёшь данные. Я жду GATE 0a/0b для blocker-тасков. Остальные gate-ы (0c/0d) имеют дефолты, так что могу двигаться без них.

## GATE 0a — Firebase key rotation ⚠️ security incident

Старый ключ (`AIzaSyA8uwf4buni-9P4NcV7sBXgMyEB58hnX54`) закоммичен в репо и должен считаться скомпрометированным.

1. Зайти на https://console.firebase.google.com → DukonPro → Project Settings
2. В разделе "Your apps" найти Android app (`com.itlsolutions.dukonpro`)
3. Получить SHA-1 release keystore: `keytool -list -v -keystore path/to/release.jks -alias <alias>`
4. В Google Cloud Console → APIs & Services → Credentials: удалить старый API key ИЛИ привязать SHA-1 restriction к нему
5. Если удалил: скачать новый `google-services.json` + перегенерить `GoogleService-Info.plist` для iOS
6. Положить файлы на локальной машине:
   - `/Users/latifrjdev/Downloads/Dukon/app/android/app/google-services.json`
   - `/Users/latifrjdev/Downloads/Dukon/app/ios/Runner/GoogleService-Info.plist`

- [x] Rotation done — date: `2026-04-28` (via Cloud Console restrictions, not regeneration)
- [x] New google-services.json placed at `app/android/app/google-services.json` (with `com.itlsolutions.dukonpro` package)
- [ ] New GoogleService-Info.plist placed (iOS) — pending iOS build setup
- [x] Old key constrained in Google Cloud Console
  - Project: `dukonpro-ca00c`
  - Key: `AIzaSyA8uwf4buni-9P4NcV7sBXgMyEB58hnX54` (Android key, auto-created by Firebase)
  - Application restrictions: Android apps
    - Package: `com.itlsolutions.dukonpro`
    - SHA-1 (release): `A9:C6:B9:D5:4D:54:D6:83:F6:E2:F8:75:47:85:E8:98:DB:26:A7:F5`
    - SHA-1 (debug):   `9F:69:71:CF:AF:FC:38:35:E0:0B:DE:81:FF:90:01:01:84:FF:1A:BC`
  - API restrictions: 25 APIs (Firebase default set)
  - Verified: Restrictions column shows "Android apps, 25 APIs"
- Release keystore: `~/dukonpro-release.jks`, alias `dukonpro` — **stored in 1Password / secure backup**, never committed

## GATE 0b — Sentry DSNs

1. https://sentry.io — Sign Up / Log In (free tier даёт 5K events/month, хватит на старт)
2. Create organization (если нет) → Projects → Create Project 3 раза:
   - Platform: **Node.js → NestJS** → project name: `dukonpro-api`
   - Platform: **JavaScript → Next.js** → project name: `dukonpro-admin`
   - Platform: **Dart → Flutter** → project name: `dukonpro-mobile`
3. В каждом проекте: Settings → Client Keys (DSN) → скопировать DSN

```
DSN_API:     https://1cb6c561eae05fa51a22505da527045d@o4511295919095808.ingest.de.sentry.io/4511296168722512
DSN_ADMIN:   https://badaaed08382cdd7fde67eb93f5bb394@o4511295919095808.ingest.de.sentry.io/4511295927877712
DSN_MOBILE:  https://823a8cf336ed5df76bef64da62624afb@o4511295919095808.ingest.de.sentry.io/4511296176652368
```

✅ Wired into all 3 layers in commit `c401e95`:
- API:    `api/.env` SENTRY_DSN, init in `api/src/sentry.ts`, registered in `app.module.ts`
- Admin:  `admin/.env.local` NEXT_PUBLIC_SENTRY_DSN, instrumentation.ts + 3 sentry.*.config.ts files
- Mobile: passed via `--dart-define=SENTRY_DSN_MOBILE=...` at build time, init in `app/lib/core/sentry.dart`

## GATE 0c — iOS usage descriptions (дефолты есть, поменяй если хочешь)

Дефолт (я поставлю это если не укажешь иначе):
- `NSCameraUsageDescription`: *"Приложение использует камеру для сканирования штрихкодов товаров и съёмки фото товаров."*
- `NSPhotoLibraryUsageDescription`: *"Приложение обращается к галерее для выбора фотографий товаров и квитанций об оплате."*
- `NSPhotoLibraryAddUsageDescription`: *"Приложение сохраняет сгенерированные чеки в галерею."*
- `NSBluetoothAlwaysUsageDescription`: *"Приложение использует Bluetooth для подключения к принтеру чеков."*
- `NSBluetoothPeripheralUsageDescription`: *"Приложение использует Bluetooth для подключения к принтеру чеков."*

- [ ] Use defaults (можно просто отметить)
- [ ] Use custom → напиши ниже:

## GATE 0d — Store submission metadata

Нужно для финального Task 7 (Fastlane scaffolding). Не блокирует другие таски.

```
Privacy policy URL:       https://latifrjdev.github.io/dukonpro-privacy/
                          ⚠️ Needs 2 amendments before store submission:
                            1. Add Sentry to section 4 (third-party data sharing)
                            2. Add "uploaded images" section (payment receipt photos)
                          See main commit message in 8239412 follow-up for the
                          exact text additions.
Support email:            (e.g. support@dukonpro.tj)
App name (Play + Apple): ≤30 символов
Short description:        ≤80 символов (только Play)
Full description:         ≤4000 символов, Russian
Keywords (Apple):         ≤100 chars, comma-separated
Screenshots folder:       (путь к 5-8 PNG на девайс-класс)
App icon 1024×1024:       (путь к файлу)
Signing keystore alias:   (для Android SHA-1)
```
