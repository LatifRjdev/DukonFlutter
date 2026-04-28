# Google Play Store Publication Guide — DukonPro

## Prerequisites
- [x] Google Play Developer account ($25 one-time fee): https://play.google.com/console/signup
- [x] Release keystore generated
- [x] AAB built via `scripts/build-release.sh`
- [x] Privacy policy hosted (URL needed)

## Step 1: Create App in Play Console

1. Go to https://play.google.com/console
2. Click "Create app"
3. Fill in:
   - **App name**: DukonPro
   - **Default language**: Russian (ru-RU)
   - **App or game**: App
   - **Free or paid**: Free
4. Accept policies, click "Create app"

## Step 2: Store Listing

Go to: Grow users > Store listing > Main store listing

### Short description (80 chars max)
```
Учёт товаров и продаж для магазинов Таджикистана
```

### Full description
```
DukonPro — профессиональная система учёта для розничных магазинов.

Возможности:
• POS-касса с быстрым поиском и сканером штрихкодов
• Учёт товаров, остатков и приёмки
• Управление клиентами и поставщиками с долгами
• Полные финансовые отчёты (продажи, расходы, прибыль)
• Печать чеков на Bluetooth-принтере
• Отправка чеков через Telegram и WhatsApp
• Курсы валют от Национального банка Таджикистана
• Инвентаризация товаров
• Доставка заказов
• Управление сотрудниками и ролями
• Push-уведомления о важных событиях
• Офлайн-режим — работает без интернета
• Закят-калькулятор

Языки: Русский, Тоҷикӣ, Ўзбекча

Подходит для: продуктовых магазинов, магазинов одежды, электроники, хозтоваров, аптек.
```

### Screenshots
Take screenshots on a real device or emulator:
1. Dashboard (главный экран)
2. POS — оформление продажи
3. Список товаров
4. Финансовый обзор (баланс)
5. Отчёты (графики)
6. Настройки
7. Чек (receipt preview)
8. Инвентаризация

Minimum: 2 screenshots, recommended: 4-8
Format: JPEG or PNG, 16:9 ratio, min 320px, max 3840px

### Feature graphic
1024x500 PNG — promotional banner. Can be a simple design with logo + tagline.

### App icon
512x512 PNG — must match launcher icon

## Step 3: App Content

### Privacy policy
URL: `https://latifrajabov.github.io/dukonpro-privacy/` (host your privacy-policy-ru.md as a GitHub Pages site)

How to host on GitHub Pages:
1. Create repo: `LatifRjdev/dukonpro-privacy`
2. Push `privacy-policy-ru.md` as `index.md`
3. Enable GitHub Pages in repo settings (Source: main, /root)
4. URL will be: `https://latifrjdev.github.io/dukonpro-privacy/`

### Content rating
1. Go to: Policy and programs > App content > Content rating
2. Click "Start questionnaire"
3. Category: Utility
4. Answer all questions (mostly "No" for a business app)
5. Submit → You'll get an "Everyone" rating

### Target audience
1. Go to: Policy and programs > App content > Target audience
2. Target age group: 18+ (business app)

### Data safety
1. Go to: Policy and programs > App content > Data safety
2. Fill in based on our privacy policy:
   - Collects: Name, phone, email
   - Collects: Business data (products, sales)
   - Does NOT share data with third parties
   - Data encrypted in transit (HTTPS)
   - Users can request data deletion

## Step 4: Release

### Internal Testing (recommended first)
1. Go to: Test > Internal testing
2. Create new release
3. Upload AAB file
4. Add release notes:
```
Первый релиз DukonPro v1.0.0
• POS-касса и сканер штрихкодов
• Управление товарами и складом
• Финансовые отчёты
• Печать и отправка чеков
• Управление доставками
• Push-уведомления
```
5. Save and publish to internal track
6. Add testers (email list)

### Production Release
After testing:
1. Go to: Release > Production
2. Create new release
3. Upload same AAB
4. Add release notes
5. Review → Submit for review

Google review takes 1-7 days for first submission.

## Step 5: After Publication

- Monitor crashes in Firebase Crashlytics
- Check reviews in Play Console
- Update frequently (version bump + new AAB)

## Version Bumps

For each update:
1. In `pubspec.yaml`: change `version: 1.0.1+2` (increment both)
2. Rebuild: `./scripts/build-release.sh`
3. Upload new AAB to Play Console
