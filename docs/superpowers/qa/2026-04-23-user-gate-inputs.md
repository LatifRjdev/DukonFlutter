# User-provided inputs for Sprint 1 (prod blockers)

Заполни эту форму, как только соберёшь данные. Я жду GATE 0a/0b для blocker-тасков. Остальные gate-ы (0c/0d) имеют дефолты, так что могу двигаться без них.

## GATE 0a — Firebase key rotation ⚠️ security incident

Старый ключ (`AIzaSyA8uwf4buni-9P4NcV7sBXgMyEB58hnX54`) закоммичен в репо и должен считаться скомпрометированным.

1. Зайти на https://console.firebase.google.com → DukonPro → Project Settings
2. В разделе "Your apps" найти Android app (`com.itlsolutions.dokonpro`)
3. Получить SHA-1 release keystore: `keytool -list -v -keystore path/to/release.jks -alias <alias>`
4. В Google Cloud Console → APIs & Services → Credentials: удалить старый API key ИЛИ привязать SHA-1 restriction к нему
5. Если удалил: скачать новый `google-services.json` + перегенерить `GoogleService-Info.plist` для iOS
6. Положить файлы на локальной машине:
   - `/Users/latifrjdev/Downloads/Dukon/app/android/app/google-services.json`
   - `/Users/latifrjdev/Downloads/Dukon/app/ios/Runner/GoogleService-Info.plist`

- [ ] Rotation done — date: `YYYY-MM-DD`
- [ ] New google-services.json placed
- [ ] New GoogleService-Info.plist placed (iOS)
- [ ] Old key revoked in Google Cloud Console

## GATE 0b — Sentry DSNs

1. https://sentry.io — Sign Up / Log In (free tier даёт 5K events/month, хватит на старт)
2. Create organization (если нет) → Projects → Create Project 3 раза:
   - Platform: **Node.js → NestJS** → project name: `dukonpro-api`
   - Platform: **JavaScript → Next.js** → project name: `dukonpro-admin`
   - Platform: **Dart → Flutter** → project name: `dukonpro-mobile`
3. В каждом проекте: Settings → Client Keys (DSN) → скопировать DSN

```
DSN_API:     
DSN_ADMIN:   
DSN_MOBILE:  
```

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
Privacy policy URL:       (обязательно — без этого Apple/Google откажут)
Support email:            (e.g. support@dukonpro.tj)
App name (Play + Apple): ≤30 символов
Short description:        ≤80 символов (только Play)
Full description:         ≤4000 символов, Russian
Keywords (Apple):         ≤100 chars, comma-separated
Screenshots folder:       (путь к 5-8 PNG на девайс-класс)
App icon 1024×1024:       (путь к файлу)
Signing keystore alias:   (для Android SHA-1)
```
