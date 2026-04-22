# TalkBack / VoiceOver QA Checklist — a11y Sprints 5B.2.a/b/c + Sprint 6

**Purpose:** Manually verify that screen-reader users (Android TalkBack, iOS VoiceOver) hear the right announcements on the 5 highest-value user flows after the accessibility work in:

- Sprint 5B.2.a — critical-path semantic labels (auth, bottom nav, POS checkout, product CRUD)
- Sprint 5B.2.b — secondary-path semantic labels (settings, finance, CRM, shifts, etc.)
- Sprint 5B.2.c — live regions via `SemanticsService.sendAnnouncement` (91 snackbars)
- Sprint 6 — l10n of the hardcoded Russian strings into ru/tg/uz

**Tester prerequisites:**
- Android emulator OR physical Android device with USB debugging enabled (physical device recommended — emulator TalkBack is known-flaky on Apple Silicon).
- TalkBack enabled: `Settings → Accessibility → TalkBack → On`. Alternative if TalkBack crashes: `Settings → Accessibility → Select to Speak`.
- Or iOS: `Settings → Accessibility → VoiceOver → On`.
- Active store selected in the app.
- Test locale set to ru (other locales covered in separate follow-up pass).

---

## Flow 1 — Login / auth error path

**Pre-condition:** logged out.

**Steps and expected announcements:**

| # | Action | Expected announcement |
|---|---|---|
| 1 | Focus phone field | "Номер телефона, текстовое поле" (or similar) |
| 2 | Focus password field | "Пароль, текстовое поле" |
| 3 | Focus password visibility toggle | "Показать пароль, переключатель" |
| 4 | Tap toggle | "Скрыть пароль" announced after state change |
| 5 | Tap "Войти" with wrong password | **Live region:** "<error message>" read automatically without focus move |
| 6 | Focus "Забыли пароль?" | "Забыли пароль?, ссылка" or "кнопка" |
| 7 | Navigate to OTP screen | Back button auto-labeled "Назад" |

**Pass criteria:** all expected strings are heard; the error toast (step 5) is announced automatically (not silent).

---

## Flow 2 — Bottom navigation

**Pre-condition:** on home screen after login.

| # | Action | Expected announcement |
|---|---|---|
| 1 | Swipe to Главная tab | "Главная, кнопка, выбрано" |
| 2 | Swipe to Товары tab | "Товары, кнопка, не выбрано" |
| 3 | Tap Товары | "Товары, выбрано" on re-focus |
| 4 | Swipe to Касса tab | "Касса, кнопка" |
| 5 | Swipe to Финансы tab | "Финансы, кнопка" |
| 6 | Swipe to Ещё tab | "Ещё, кнопка" |

**Pass criteria:** each tab name read in Russian; selected/unselected state is announced.

---

## Flow 3 — POS checkout (add item, change qty, pay cash)

**Pre-condition:** POS tab, shift open, at least 1 product in catalog.

| # | Action | Expected announcement |
|---|---|---|
| 1 | Focus "Добавить товар" FAB | "Добавить товар, кнопка" |
| 2 | Focus "Сканировать штрихкод" | "Сканировать штрихкод, кнопка" |
| 3 | Add a product; focus cart qty − | "Уменьшить количество, кнопка" |
| 4 | Focus cart qty + | "Увеличить количество, кнопка" |
| 5 | Focus "Удалить товар" | "Удалить товар, кнопка" |
| 6 | Tap "Оплатить наличными" | Payment screen loads |
| 7 | Focus quick-amount chip "100" | "Быстрая сумма 100, кнопка" |
| 8 | Focus "Без сдачи" | "Без сдачи, кнопка" |
| 9 | Confirm payment | **Live region:** "Продажа завершена" (or similar success) announced |

**Pass criteria:** quantity controls have distinct labels (not just "+" / "−"); quick-amount chips read the amount value via placeholder.

---

## Flow 4 — Product add wizard (photo upload)

**Pre-condition:** Товары tab, tap "Добавить товар" FAB.

| # | Action | Expected announcement |
|---|---|---|
| 1 | Focus photo upload zone | "Загрузить фото, кнопка" |
| 2 | Fill name + tap "Далее" | Navigate to step 2 |
| 3 | On step 3, focus second photo zone | "Загрузить фото, кнопка" |
| 4 | Complete wizard | **Live region:** "Товар сохранён" announced |

**Pass criteria:** the GestureDetector photo upload (not an IconButton) is announced as a button, not a generic tap target.

---

## Flow 5 — Notifications + language change (dynamic content)

**Pre-condition:** at least 1 unread notification.

| # | Action | Expected announcement |
|---|---|---|
| 1 | Open notifications | Each card is a button |
| 2 | Focus a notification card | "Отметить как прочитанное, кнопка" |
| 3 | Tap the card | **Live region:** notification disappears / read-state change announced |
| 4 | Go to Настройки → Язык | |
| 5 | Focus language rows | "Выбрать язык Русский, кнопка" / "Выбрать язык Тоҷикӣ, кнопка" / "Выбрать язык O'zbek, кнопка" |
| 6 | Tap Тоҷикӣ | App restarts in tg locale |
| 7 | Focus bottom nav | Should now read in Tajik: "Асосӣ, кнопка" |
| 8 | Go to Товары → "Добавить товар" FAB | Should read tg translation "Илова кардани мол, кнопка" |

**Pass criteria:** language switch changes the announced labels; placeholder-based label (`Выбрать язык {language}`) interpolates correctly.

---

## Automated proxy — adb dump of semantic tree

TalkBack reads from the semantic tree. If audio isn't available, dump the semantic tree via adb and grep for label presence:

```bash
# Take a UIAutomator snapshot of the currently displayed screen
adb -s emulator-5554 shell uiautomator dump /sdcard/ui.xml
adb -s emulator-5554 pull /sdcard/ui.xml /tmp/ui.xml

# Check specific labels are present
grep -oE 'content-desc="[^"]*"' /tmp/ui.xml | sort -u
grep -c 'Добавить товар' /tmp/ui.xml
grep -c 'Сканировать штрихкод' /tmp/ui.xml
```

This confirms the widget tree exposes the right labels. Does NOT verify TalkBack actually speaks them — for that, enable TalkBack and perform the flows manually.

---

## Reporting

For each flow above, mark:
- ✅ PASS — all expected announcements heard
- ⚠️ PARTIAL — some announced, some silent / wrong phrasing
- ❌ FAIL — critical label missing

Record any discrepancies in `docs/superpowers/qa/2026-04-22-talkback-qa-results.md` and file follow-up issues for:
- Labels that don't match the convention table
- Missing live-region announcements on snackbars (Sprint 5B.2.c guarantees this — any failure = regression)
- Wrong translations in tg/uz (Sprint 6 marked these best-effort)
