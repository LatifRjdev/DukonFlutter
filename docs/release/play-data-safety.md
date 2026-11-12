# Play Console — форма Data Safety

Ответы выведены из кода, а не из политики конфиденциальности. Политика
один раз уже расходилась с реальностью (утверждала, что в Sentry не уходят
персональные данные, хотя уходит идентификатор аккаунта), поэтому здесь у
каждого ответа указано, чем он подтверждён.

Форма заполняется один раз и проверяется Google при каждом обновлении.
Расхождение между формой и поведением приложения — основание для снятия
с публикации, поэтому ответы «на всякий случай пошире» так же вредны,
как и заниженные.

---

## Раздел 1. Data collection and security

| Вопрос | Ответ | Чем подтверждается |
|---|---|---|
| Does your app collect or share any of the required user data types? | **Yes** | Регистрация требует имя и телефон (`api/prisma/schema.prisma`, модель `User`) |
| Is all of the user data collected by your app encrypted in transit? | **Yes** | `ApiEndpoints.baseUrl` задаётся через `--dart-define=API_BASE_URL`; релизные полосы Fastlane отказываются собирать без него. **Убедитесь, что в продакшене туда подставлен `https://`** — на этом ответ и держится |
| Do you provide a way for users to request that their data is deleted? | **Yes** | `DELETE /api/users/me` + экран «Настройки → Удалить аккаунт» + страница https://latifrjdev.github.io/dukonpro-privacy/delete-account.html |

URL для поля **Account deletion**:
`https://latifrjdev.github.io/dukonpro-privacy/delete-account.html`

---

## Раздел 2. Типы данных

Везде ниже: **Collected = Yes** означает «уходит с устройства на наш
сервер». **Shared = Yes** — «передаётся третьей стороне».

### Personal info

| Тип | Collected | Shared | Назначение | Обязательно |
|---|---|---|---|---|
| Name | Yes | No | App functionality, Account management | Да |
| Phone number | Yes | No | App functionality, Account management | Да |
| Email address | Yes | No | Account management | Нет (поле необязательное) |
| User IDs | Yes | **Yes — Sentry** | App functionality, Crash reporting | Да |

`User IDs` помечается как shared из-за `_bindSentryUser` в
`app/lib/presentation/blocs/auth/auth_bloc.dart`: при каждом отчёте о сбое
в Sentry уходит `SentryUser(id: user.id)`. Скрубер в
`app/lib/core/sentry.dart` чистит тело запроса, заголовки и `extra`, но
`event.user` не трогает.

**Имя и телефон клиентов магазина** (модель `Customer`, поля `name`,
`phone`, `email`) тоже собираются. Это данные третьих лиц, которые вводит
владелец магазина. Google трактует их как Personal info — они уже покрыты
строками Name / Phone / Email выше, отдельных строк в форме для них нет.

### Financial info

| Тип | Collected | Shared | Назначение |
|---|---|---|---|
| Purchase history | Yes | No | App functionality |
| Other financial info | Yes | No | App functionality |

Приложение ведёт учёт продаж, расходов, долгов и зарплат магазина
(`Sale`, `Expense`, `SupplierPayment`, `Payroll`). Платёжные реквизиты
покупателей **не собираются** — оплата подписки подтверждается
фотографией квитанции, которую проверяет администратор вручную.

### Photos and videos

| Тип | Collected | Shared | Назначение |
|---|---|---|---|
| Photos | Yes | No | App functionality |

Только квитанции об оплате подписки: загружаются через
`POST /subscriptions/.../receipt`, лежат на сервере в `uploads/receipts/`.
Камера используется ещё для сканирования штрихкодов, но кадр нигде не
сохраняется и никуда не отправляется — это **не** сбор данных.

### App activity

| Тип | Collected | Shared | Назначение |
|---|---|---|---|
| Other actions | No | No | — |

Аналитики поведения в приложении нет. В `pubspec.yaml` только
`firebase_core`, `firebase_messaging` и `sentry_flutter` — ни Firebase
Analytics, ни рекламных SDK.

### App info and performance

| Тип | Collected | Shared | Назначение |
|---|---|---|---|
| Crash logs | Yes | **Yes — Sentry** | Crash reporting, App functionality |
| Diagnostics | Yes | **Yes — Sentry** | Crash reporting |

Передаются тип ошибки, stack trace, версия приложения, модель устройства,
версия ОС и идентификатор аккаунта.

### Device or other IDs

| Тип | Collected | Shared | Назначение |
|---|---|---|---|
| Device or other IDs | Yes | **Yes — Firebase (Google)** | App functionality (push-уведомления) |

Токен FCM, модель `FcmToken`.

### Location — **не собирается**

Отвечайте **No** на все вопросы о местоположении.

Приложение не читает местоположение: ни пакета геолокации, ни вызова в
коде. `ACCESS_FINE_LOCATION` объявлено только ради обнаружения
Bluetooth-принтера на Android 11 и ниже и ограничено
`android:maxSdkVersion="30"`.

> **Проверьте это перед отправкой.** Манифест `bluetooth_print_plus`
> объявляет `ACCESS_FINE_LOCATION` и `ACCESS_COARSE_LOCATION` без
> ограничений, и до исправления они попадали в собранный APK — в слитом
> манифесте от прежней сборки `ACCESS_COARSE_LOCATION` присутствовал,
> хотя манифест приложения его вообще не упоминает. Сейчас обе строки
> перекрыты через `tools:node="replace"`. Если кто-то уберёт эти атрибуты,
> форма станет ложной, а Play потребует Location Permissions Declaration,
> которую честно заполнить нельзя.
>
> Команда для проверки собранного артефакта:
> ```
> "$(ls ~/Library/Android/sdk/build-tools/*/aapt2 | tail -1)" dump permissions \
>   app/build/app/outputs/flutter-apk/app-release.apk | grep -iE 'location|bluetooth'
> ```
> Ожидается ровно это (проверено на debug-сборке 12.11.2026):
> ```
> uses-permission: name='android.permission.BLUETOOTH_SCAN' usesPermissionFlags='neverForLocation'
> uses-permission: name='android.permission.ACCESS_FINE_LOCATION' maxSdkVersion='30'
> uses-permission: name='android.permission.ACCESS_COARSE_LOCATION' maxSdkVersion='30'
> ```
> Любая строка с LOCATION **без** `maxSdkVersion` означает, что перекрытие
> слетело и форму заполнять нельзя.

### Не собирается ничего из

Contacts, Calendar, SMS, Files and docs, Music, Health and fitness,
Web browsing history, Installed apps, Search history, Ads.

---

## Раздел 3. Третьи стороны

| Кому | Что | Зачем |
|---|---|---|
| **Firebase Cloud Messaging** (Google) | токен устройства | доставка push |
| **Sentry** (sentry.io) | тип ошибки, stack trace, версия приложения и ОС, модель устройства, идентификатор аккаунта | диагностика сбоев |
| **Telegram Bot API** | содержимое чека и chat ID | отправка чека клиенту, по действию продавца |
| **Национальный банк Таджикистана** (nbt.tj) | ничего | читаются публичные курсы валют |

NBT в форме указывать не нужно: данные только принимаются, ничего не
отправляется.

---

## Что держать синхронным

Форма, `docs/privacy-policy-ru.md` и опубликованная
https://latifrjdev.github.io/dukonpro-privacy/ должны говорить одно и то
же. Опубликованная версия — источник истины; копия в репозитории уже
однажды отстала на несколько разделов.
