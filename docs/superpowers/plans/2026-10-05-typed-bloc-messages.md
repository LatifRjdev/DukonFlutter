# Typed Bloc Messages — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Blocs stop putting Russian text into state objects. State carries an `AppMessage` enum; the widget resolves it through `AppLocalizations`, so tg/uz can finally reach every error and confirmation.

**Architecture:** One app-wide enum, one `resolve(l10n)` extension. `mapErrorToUserMessage` becomes `mapErrorToAppMessage` with identical branches. `InvestmentL10nKey` folds in and is deleted.

**Tech Stack:** Flutter, flutter_bloc, `flutter gen-l10n` over `app/lib/l10n/app_ru.arb`.

**Spec:** `docs/superpowers/specs/2026-10-05-typed-bloc-messages-design.md`

---

## Measured inventory — do not re-derive

| Thing | Count | Where |
|---|---|---|
| Error literals returned by the mapper | 11 strings → **10 members** (generic fallback is shared by 2 branches) | `lib/core/errors/error_messages.dart` |
| `mapErrorToUserMessage` references | **125** across **51** files | `lib/` |
| Success literals | **10** across **5** classes | blocs |
| Message-carrying state classes | **33** (28 error, 5 success) | `lib/presentation/blocs` |
| Read sites | **~110**, of which **36** are `AppSnackbar.*(context, x.message)` | `lib/presentation/pages` |
| Bloc tests asserting `s.message` | **16 files** — these change | `test/presentation/blocs` |
| Datasource tests asserting `e.message` | **19 files** — diagnostic, **unchanged** | `test/data/datasources` |

Success literals, verbatim, each becoming one member:

| Literal | Member | Class |
|---|---|---|
| Профиль обновлён | `profileUpdated` | `SettingsActionSuccess` |
| Пароль изменён | `passwordChanged` | `SettingsActionSuccess` |
| Расход добавлен | `expenseAdded` | `ExpenseActionSuccess` |
| Расход обновлён | `expenseUpdated` | `ExpenseActionSuccess` |
| Расход удалён | `expenseDeleted` | `ExpenseActionSuccess` |
| Оплата записана | `paymentRecorded` | `DebtPaymentSuccess` |
| Оплата принята | `paymentAccepted` | `DebtPaymentSuccess` |
| Выплата закята записана | `zakatPaymentRecorded` | `ZakatActionSuccess` |
| Настройки закята сохранены | `zakatSettingsSaved` | `ZakatActionSuccess` |
| Заявка отправлена, ожидайте подтверждения | `subscriptionRequestSent` | `SubscriptionActionSuccess` |

---

### Task 1: The enum and its resolver

**Files:**
- Create: `app/lib/core/errors/app_message.dart`
- Create: `app/lib/presentation/l10n/app_message_l10n.dart`
- Test: `app/test/core/errors/app_message_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:dukonpro/core/errors/app_message.dart';
import 'package:dukonpro/l10n/app_localizations.dart';
import 'package:dukonpro/presentation/l10n/app_message_l10n.dart';

void main() {
  // Iterating values is the point: a member added without an ARB key fails
  // here even if someone later adds a `default` to the switch.
  test('should resolve every AppMessage member to a non-empty string', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('ru'));
    for (final m in AppMessage.values) {
      expect(m.resolve(l10n), isNotEmpty, reason: 'no string for $m');
    }
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/core/errors/app_message_test.dart`
Expected: FAIL — `app_message.dart` does not exist.

- [ ] **Step 3: Create the enum**

`app/lib/core/errors/app_message.dart` — members exactly as the spec lists them, in two commented groups (errors, successes). No logic in this file; it must stay importable from anywhere, including blocs.

- [ ] **Step 4: Add the ARB keys**

Ten new error keys. Reuse `offlineBannerNoConnection` for `offline` — do **not** mint a second key for that string. Group the new keys in one contiguous `error*` block per `.claude/rules/mobile-l10n.md`, each with an `@` description. The ten success strings reuse their existing keys where one exists; grep first.

Run `flutter gen-l10n`.

- [ ] **Step 5: Write the resolver**

`app/lib/presentation/l10n/app_message_l10n.dart` — one extension, one exhaustive `switch` expression, **no `default`**. It lives under `presentation/` because it depends on `AppLocalizations`; the enum itself must not.

- [ ] **Step 6: Run the test**

Run: `flutter test test/core/errors/app_message_test.dart`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add app/lib/core/errors/app_message.dart app/lib/presentation/l10n/app_message_l10n.dart app/lib/l10n/ app/test/core/errors/app_message_test.dart
git commit -m "feat(app): an AppMessage enum and its localized resolver"
```

---

### Task 2: Retarget the mapper

**Files:**
- Modify: `app/lib/core/errors/error_messages.dart`
- Test: `app/test/core/errors/error_messages_test.dart`

- [ ] **Step 1: Retarget the existing test**

The file already tests the full table of (exception, statusCode) → string. Change each expectation from a Russian literal to the matching `AppMessage` member. Keep every case; this table is the contract.

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/core/errors/error_messages_test.dart`
Expected: FAIL — the function still returns `String`.

- [ ] **Step 3: Change the return type**

Rename `mapErrorToUserMessage` → `mapErrorToAppMessage`, returning `AppMessage`. Branches are unchanged — the function already dispatches only on runtime type and `statusCode`. Delete the "Russian-only for now" note; it is no longer true.

Do **not** leave a deprecated `String`-returning shim. A shim would let a call site stay unconverted silently, which is the one thing the compile error is buying.

- [ ] **Step 4: Run it**

Run: `flutter test test/core/errors/error_messages_test.dart`
Expected: PASS. `flutter analyze` now reports ~125 errors — that is the worklist for Task 3, not a problem.

- [ ] **Step 5: Commit** (analyze is red here by design; say so in the message)

---

### Task 3: State classes and blocs

**Files:** 33 state files under `app/lib/presentation/blocs/*/`, plus the blocs that construct them.

- [ ] **Step 1:** Change `final String message` → `final AppMessage message` on all 28 error carriers; `props` needs no change.
- [ ] **Step 2:** Change the 5 success carriers the same way and replace each literal with its member from the table above.
- [ ] **Step 3:** Replace every `mapErrorToUserMessage(e)` with `mapErrorToAppMessage(e)` — 125 sites. Mechanical; the import changes too.
- [ ] **Step 4:** Delete `investment_l10n_key.dart`; `InvestmentActionSuccess` takes `AppMessage`.
- [ ] **Step 5:** `flutter analyze` — every remaining error is a read site, which is Task 4.
- [ ] **Step 6: Commit**

---

### Task 4: Read sites

**Files:** ~110 sites under `app/lib/presentation/pages/`, 36 of them snackbars.

- [ ] **Step 1:** For each site, `x.message` → `x.message.resolve(l10n)`.
- [ ] **Step 2:** Where no `l10n` is in scope, add `final l10n = AppLocalizations.of(context)!;` following the file's existing idiom. **List every file where this was needed** in the commit message — these are the only non-mechanical edits.
- [ ] **Step 3:** Replace both duplicated `InvestmentL10nKey` switches with `resolve`.
- [ ] **Step 4:** `flutter analyze` → `No issues found!`
- [ ] **Step 5: Commit**

---

### Task 5: Tests and gates

- [ ] **Step 1:** Retarget the 16 bloc test files from `s.message == 'Russian'` to `s.message == AppMessage.x`.
      The leak assertions (`!s.message.contains('DioException')`) become structurally impossible — replace them with an assertion on the expected member, and note in the test that the property is now enforced by the type.
- [ ] **Step 2:** Leave the 19 datasource test files alone. They assert the exception's diagnostic `message`, which is unchanged and deliberately English.
- [ ] **Step 3:** Add the widget test from the spec: one snackbar path and one inline-error path render resolved Russian.
- [ ] **Step 4:** Gates:
  - `flutter analyze` → `No issues found!`
  - `flutter test` → failing set identical to the documented 18 macOS goldens (compare the SET, pipe through `tr '\r' '\n'`)
  - `dart run tool/check_i18n.dart` → exit 0; the scanned-literal count should **drop**
  - `grep -rn mapErrorToUserMessage app/lib` → no hits
  - `flutter gen-l10n` → new keys present in `l10n_untranslated.json` for tg and uz
- [ ] **Step 5: Commit**

---

## Hard constraints

- NEVER run `dart format` — Dart 3.10 tall style rewrites hundreds of unrelated lines.
- Do NOT regenerate goldens. Do NOT hand-edit `app/lib/l10n/app_localizations*.dart`.
- Do NOT touch `app/lib/core/errors/exceptions.dart`. Its `message` is diagnostic and English on purpose, and its doc comment explains why.
- Do NOT add a deprecated shim for `mapErrorToUserMessage`.
- The Read tool is flaky on files with prior observations; if a Read returns only line 1, use `awk '{print NR": "$0}' <file>`.
