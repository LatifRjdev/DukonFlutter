# L10n Extraction and Retry-After Header Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close out the two remaining items explicitly deferred from the prior `chore/tech-debt-cleanup` branch: (1) a precise `Retry-After` header + Swagger status documentation on the e-commerce webhook's retryable 409 path, and (2) extraction of all hardcoded Russian UI strings into the app's existing `AppLocalizations` system, file by file, worst-offender first.

**Architecture:** Task 1 is a small, fully self-contained backend fix. Everything after that is one task per mobile page file, each following an identical, precisely-specified extraction procedure — read the file, find hardcoded Cyrillic string literals, reuse an existing `.arb` key if one already matches, otherwise add a new Russian-only key, replace the literal with `AppLocalizations.of(context)!.keyName`, regenerate, test, commit.

**Tech Stack:** NestJS backend (`api/`) for Task 1; Flutter mobile app (`app/`) with the built-in `flutter gen-l10n` toolchain (`lib/l10n/app_ru.arb` / `app_tg.arb` / `app_uz.arb`, config in `l10n.yaml`) for all l10n tasks.

---

## Decisions already made (do not re-litigate)

- **Translations**: Russian-only for all newly-extracted strings. `tg.arb`/`uz.arb` are deliberately left without the new keys. Confirmed via a live experiment during planning: `flutter gen-l10n` does NOT fail or crash when a key is missing from a non-template locale — it prints a build-time warning (`"tg": N untranslated message(s)`) and the generated `AppLocalizationsTg`/`AppLocalizationsUz` getter for that key silently falls back to the Russian (template) value. This is a real, visible-but-safe trade-off: Tajik/Uzbek users will see Russian text on these specific newly-extracted strings until someone provides real translations. No task in this plan should attempt to author tg/uz translations.
- **Batching**: one file per task, worst-offender first, using the exact ordered list in the "File order" section below (real data, captured during planning — re-verify string counts per file as you go, since counts may drift slightly as earlier files in the list are completed, though files are independent of each other so this should be minimal).
- **Scope boundary**: this plan only covers `app/lib/presentation/pages/**/*.dart` files currently missing `AppLocalizations.of(context)` usage (36 files, confirmed via `comm` diff between all page files and files using `AppLocalizations.of(context)` during planning). It does NOT cover: widgets under `app/lib/presentation/widgets/`, blocs, non-UI strings (enum values, API payload keys, format codes), or debug/log-only text. If an implementer finds hardcoded strings in files outside this list while working, leave them — out of scope for this plan.

---

### Task 1: Add a precise `Retry-After` header and Swagger status docs to the e-commerce webhook's 409 path

**Files:**
- Create: `api/src/common/exceptions/retryable-conflict.exception.ts`
- Modify: `api/src/common/filters/http-exception.filter.ts`
- Modify: `api/src/modules/ecommerce/ecommerce-orders.service.ts`
- Modify: `api/src/modules/ecommerce/ecommerce-orders.controller.ts`
- Test: `api/src/common/filters/http-exception.filter.spec.ts`, `api/src/modules/ecommerce/ecommerce-orders.service.spec.ts`

**Context:** A prior task on this codebase changed the e-commerce webhook's stock-race-conflict rejection from `UnprocessableEntityException` (422) to `ConflictException` (409), since that specific failure is transient and safe to retry (unlike the webhook's other two rejection paths, which are genuinely permanent). Code-quality review at the time flagged two follow-ups, explicitly scoped as separate work: (a) the merchant site's only signal that a retry will help is the English-less Russian message text — no `Retry-After` header exists to tell it *when* to retry; (b) the endpoint's Swagger docs document zero status codes at all, so an integrator reading the generated API spec learns nothing about either the 409 or the pre-existing 422 paths.

**Design (established during planning, not to be re-derived):** The codebase already has ONE global exception filter (`AllExceptionsFilter`, `@Catch()`) that every thrown exception passes through — this is the natural place to attach the header, rather than a route-specific interceptor. But a blanket "add `Retry-After` to every `ConflictException`" would be semantically wrong: this same `ConflictException` class is already thrown elsewhere in the app for genuinely PERMANENT conflicts (e.g. `staff.controller.ts`'s "Staff member already exists in this store" — retrying that will never succeed, so telling the client to retry-after-N-seconds would be actively misleading). The fix is a small, purpose-built exception subclass carrying its own retry hint, so the filter can precisely target only the genuinely-transient case:

```typescript
// api/src/common/exceptions/retryable-conflict.exception.ts
import { ConflictException } from '@nestjs/common';

export class RetryableConflictException extends ConflictException {
  constructor(
    message: string,
    public readonly retryAfterSeconds: number = 5,
  ) {
    super(message);
  }
}
```

- [ ] **Step 1: Write the failing filter test**

Read `api/src/common/filters/http-exception.filter.spec.ts` in full first — note its `makeHost()` helper builds a mock `response` object with `status()` and `json()` methods but no `setHeader()`. Add `setHeader` to that mock (capturing calls so tests can assert on them), matching the existing mock's style:

```typescript
function makeHost(): {
  host: ArgumentsHost;
  response: { statusCode: number; body: unknown; headers: Record<string, string> };
  request: { method: string; url: string };
} {
  const response = {
    statusCode: 0,
    body: undefined as unknown,
    headers: {} as Record<string, string>,
  };
  const request = { method: 'GET', url: '/api/test' };
  const mockResponse = {
    status(code: number) {
      response.statusCode = code;
      return this;
    },
    setHeader(name: string, value: string) {
      response.headers[name] = value;
      return this;
    },
    json(body: unknown) {
      response.body = body;
      return this;
    },
  };
  const host = {
    switchToHttp: () => ({
      getResponse: () => mockResponse,
      getRequest: () => request,
    }),
  } as unknown as ArgumentsHost;
  return { host, response, request };
}
```

Add these two tests to the `describe('AllExceptionsFilter', ...)` block:

```typescript
  it('should set a Retry-After header when a RetryableConflictException is thrown', () => {
    const { host, response } = makeHost();
    filter.catch(new RetryableConflictException('Stock changed concurrently', 7), host);
    expect(response.headers['Retry-After']).toBe('7');
    expect(response.statusCode).toBe(409);
  });

  it('should NOT set a Retry-After header for a plain ConflictException', () => {
    const { host, response } = makeHost();
    filter.catch(new ConflictException('Staff member already exists'), host);
    expect(response.headers['Retry-After']).toBeUndefined();
    expect(response.statusCode).toBe(409);
  });
```

(Add `import { ConflictException } from '@nestjs/common';` and `import { RetryableConflictException } from '../exceptions/retryable-conflict.exception';` to the top of the spec file, adjusting the relative path if the actual directory structure differs from what's assumed here — verify `api/src/common/` has a `filters/` and will need a new `exceptions/` sibling directory; create it if it doesn't exist.)

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd api && npx jest http-exception.filter.spec.ts`
Expected: FAIL — `RetryableConflictException` doesn't exist yet, `setHeader` is never called by the filter.

- [ ] **Step 3: Create the exception class**

Create `api/src/common/exceptions/retryable-conflict.exception.ts` with exactly the code shown in the Design section above.

- [ ] **Step 4: Update the global exception filter**

In `api/src/common/filters/http-exception.filter.ts`, add the import (`import { RetryableConflictException } from '../exceptions/retryable-conflict.exception';`) and insert a check before the final `response.status(status).json(...)` call:

```typescript
    if (exception instanceof RetryableConflictException) {
      response.setHeader('Retry-After', String(exception.retryAfterSeconds));
    }

    response.status(status).json({
```

(This must come before `status`/`message` are already computed via the existing `exception instanceof HttpException` branch above it — `RetryableConflictException extends ConflictException extends HttpException`, so `status` will already correctly be `409` and `message` will already be the constructor's message by the time this new check runs. Just insert the new block; don't restructure the existing logic above it.)

- [ ] **Step 5: Run the filter tests to verify they pass**

Run: `cd api && npx jest http-exception.filter.spec.ts`
Expected: PASS, all tests including the two new ones.

- [ ] **Step 6: Switch the e-commerce service to throw the new exception type**

In `api/src/modules/ecommerce/ecommerce-orders.service.ts`, the `catch (err)` block inside `createOrder()` currently does:
```typescript
        throw new ConflictException(
          `Stock for product ${err.productId} changed concurrently — retry the webhook`,
        );
```
Change the import at the top of the file from `ConflictException` (in the `@nestjs/common` import list) to ALSO import `RetryableConflictException` from the new file (`import { RetryableConflictException } from '../../common/exceptions/retryable-conflict.exception';` — adjust the relative path to match this file's actual location, `api/src/modules/ecommerce/`), and change the throw to:
```typescript
        throw new RetryableConflictException(
          `Stock for product ${err.productId} changed concurrently — retry the webhook`,
        );
```
(Using the default `retryAfterSeconds = 5` — don't pass a second argument unless you have a specific reason to pick a different value.) You can remove `ConflictException` from the `@nestjs/common` import list if nothing else in this file uses it directly anymore — check first with `grep -n "ConflictException" api/src/modules/ecommerce/ecommerce-orders.service.ts` before removing.

- [ ] **Step 7: Add/update a test in the e-commerce service spec asserting the retry header behavior end-to-end**

Read the existing stock-race-conflict test in `api/src/modules/ecommerce/ecommerce-orders.service.spec.ts` (titled something like `'rejects the whole order (409, retryable) and notifies the owner when the atomic stock guard detects a concurrent race'`). Its current assertion checks `.rejects.toMatchObject({ status: 409 })`. Strengthen it (or add a new test right after it, your call on which reads better) to also assert the thrown error is specifically a `RetryableConflictException` with the expected `retryAfterSeconds`:
```typescript
    await expect(
      service.handleWebhook('store-1', 'valid-key', makeOrderCreatedDto()),
    ).rejects.toMatchObject({ status: 409, retryAfterSeconds: 5 });
```
(This works because `toMatchObject` checks own+inherited enumerable properties, and `retryAfterSeconds` is a public constructor-parameter property on the new class — verify this actually passes; if `retryAfterSeconds` doesn't show up on the thrown object for some TypeScript/class-property reason, fall back to `expect(err).toBeInstanceOf(RetryableConflictException)` via a manual try/catch instead of `.rejects.toMatchObject`, and note why in your report.)

- [ ] **Step 8: Add Swagger `@ApiResponse` decorators to the controller**

Read `api/src/modules/ecommerce/ecommerce-orders.controller.ts` in full — it currently has only `@ApiTags`/`@ApiOperation` with no `@ApiResponse` decorators at all. Add `@ApiResponse` (imported from `@nestjs/swagger`, alongside the existing `ApiTags, ApiOperation` import) documenting all four possible outcomes of `POST /stores/:storeId/ecommerce/orders`, matching the exact pattern already established in `api/src/modules/staff/staff.controller.ts` (stack multiple `@ApiResponse` decorators, one per status):

```typescript
  @ApiResponse({ status: 200, description: 'Order processed successfully (created or cancelled)' })
  @ApiResponse({
    status: 409,
    description:
      'Transient stock conflict — a concurrent in-store sale claimed the stock first. Safe to retry; see the Retry-After header for the suggested delay in seconds.',
  })
  @ApiResponse({
    status: 422,
    description:
      'Permanent rejection — no product mapping, insufficient stock, or totalAmount mismatch. Fix the underlying issue before retrying; retrying an unchanged payload will fail again.',
  })
  @ApiResponse({ status: 401, description: 'Invalid or disabled X-API-Key' })
```
Place these directly above the existing `@Post('orders')` / `@HttpCode(HttpStatus.OK)` / `@Throttle(...)` / `@ApiOperation(...)` decorator stack on `handleWebhook()` (exact ordering among decorators doesn't matter functionally, but group the new `@ApiResponse` ones together, adjacent to `@ApiOperation` for readability).

- [ ] **Step 9: Run the full backend suite and typecheck**

Run: `cd api && npx jest`
Expected: all suites pass (should be 590/590 — 588 existing + the 2 new filter tests; the strengthened e-commerce test doesn't add to the count if you strengthened rather than added).

Run: `cd api && npx tsc --noEmit`
Expected: no errors.

- [ ] **Step 10: Commit**

```bash
git add api/src/common/exceptions/retryable-conflict.exception.ts api/src/common/filters/http-exception.filter.ts api/src/common/filters/http-exception.filter.spec.ts api/src/modules/ecommerce/ecommerce-orders.service.ts api/src/modules/ecommerce/ecommerce-orders.service.spec.ts api/src/modules/ecommerce/ecommerce-orders.controller.ts
git commit -m "feat(ecommerce): add a precise Retry-After header and Swagger status docs to the webhook's 409 path"
```

---

## L10n extraction — process specification (applies to every task from Task 2 onward)

**Why this section is written once, not per-file:** the 36 remaining tasks are mechanically identical in procedure — only the specific file, its specific strings, and the specific new `.arb` keys differ. Writing out full step-by-step checkboxes with complete before/after code for all ~450 individual string extractions across 36 files would make this document enormous without adding real guidance beyond what's specified once, here, plus the one fully-worked example in Task 2. Every task from Task 2 onward follows this exact procedure — read it in full before starting your assigned file.

### The procedure

1. **Read the target `.dart` file in full.**

2. **Identify every user-facing hardcoded Russian (Cyrillic) string literal.** This means: `Text('...')` widget content, `hintText:`/`labelText:`/`errorText:` on form fields, `SnackBar`/dialog content, button labels, validator error-message strings, `AppBar` titles — anything a user actually reads. Do NOT extract: debug/log strings, non-UI enum-like string values (e.g. `'ACTIVE'`, `'CARD'`), format strings/regex patterns, or comments.

3. **For each identified string, check whether an existing key in `app/lib/l10n/app_ru.arb` already has the exact same value (or a clearly-equivalent one you'd naturally reuse — e.g. a screen-specific "Сохранить" button should reuse the existing `save` key, not create `screenNameSaveButton`).** Read `app/lib/l10n/app_ru.arb` (it's ~365 real keys, browse or `grep` for candidate matches by searching for a few words from the string) before creating anything new. This matters — during planning, checking `login_page.dart`'s 8 hardcoded strings against the existing `.arb` found that 5 of 8 already had exact matching keys (`password`, `login`, `forgotPassword`, `noAccount`, `register`), leaving only 3 genuinely new. Expect similar overlap in most files. Reusing existing keys is strictly better than duplicating — fewer keys to maintain, and any future retranslation only needs to happen once.

4. **For strings with no existing match, add a new key to `app/lib/l10n/app_ru.arb` only** (never to `app_tg.arb`/`app_uz.arb` — see "Decisions already made" above). Naming convention, matching the file's existing style: `camelCase`, prefixed with a short screen/feature identifier when the string is specific to one screen and collision-prone (e.g. `loginSubtitle`, `zReportPrintButton`), left unprefixed only for truly generic strings that would obviously belong at the top level near `save`/`cancel`/`delete` if reused elsewhere (rare — when in doubt, prefix). Insert new keys near the end of the file, or grouped near thematically-related existing keys if there's an obvious cluster (e.g. new `login_page.dart` keys near the existing `login`/`password`/`forgotPassword` cluster) — use judgment, this file doesn't enforce strict alphabetical or strict grouping today.

5. **Regenerate the localization classes: run `cd app && flutter gen-l10n`** (or `flutter pub get`, which triggers the same generation as a side effect — either works, verified during planning; `flutter gen-l10n` is more direct). Expect a `"tg": N untranslated message(s)` / `"uz": N untranslated message(s)` warning printed to the console for however many new keys you added — this is expected and correct per the "Decisions already made" section, not an error to fix.

6. **Replace every extracted string literal in the `.dart` file with `AppLocalizations.of(context)!.keyName`.** If the file doesn't already import `AppLocalizations`, add `import '../../../l10n/app_localizations.dart';` (adjust the relative path's `../` count to match the actual file's depth under `lib/presentation/pages/` — count directory levels from the target file back to `lib/`, then down into `l10n/`; check a sibling file that already does this import, e.g. any file already using `AppLocalizations`, for the exact relative path convention at a similar directory depth, rather than guessing). If a widget using the string is `const` (e.g. `const Text('Пароль')`), removing `const` is required once the value is no longer a compile-time constant (`AppLocalizations.of(context)!.password` is not const) — check each call site.

7. **Verify no hardcoded Cyrillic string literals remain that should have been extracted.** Run `grep -oE "'[^']*[а-яА-ЯёЁ][^']*'|\"[^\"]*[а-яА-ЯёЁ][^\"]*\"" <file>` and manually confirm every remaining hit is a legitimate non-UI exception (per step 2's exclusion list) — if you're unsure whether something should have been extracted, err toward extracting it.

8. **Run `flutter analyze` on the touched file.** Expected: no issues (in particular, no `use_of_void_result`, no unused imports if `AppLocalizations` wasn't already imported and now is needed, no leftover unused `const` issues).

9. **Run the file's existing test(s), if any exist** (`find app/test -iname "*<page_name>*"` to check). Widget/golden tests that assert on the OLD Russian string text via `find.text('старый текст')` will need updating to either `find.text('новый текст из arb')` (should be byte-identical to before, since you're not changing the actual displayed Russian text, only its source) — if a test breaks, it's almost certainly because the test asserted on exact string content and something about the extraction changed the actual rendered value (e.g. a typo during extraction) — fix the extraction, not the test, unless you can clearly justify otherwise. Golden (screenshot) tests should not need pixel changes since the rendered text is unchanged, but regenerate goldens if the test runner reports a mismatch and you've confirmed the rendered text is genuinely identical to before.

10. **Commit** with message: `git commit -m "feat(mobile): extract hardcoded strings in <short file description> to AppLocalizations"`.

### Worked example: `app/lib/presentation/pages/auth/login_page.dart`

This file (8 hardcoded Cyrillic strings) is small enough to fully specify here as the concrete template for every other file. Read it in full first (`app/lib/presentation/pages/auth/login_page.dart`) to confirm it still matches what's described — if it's drifted significantly, treat this worked example as illustrative of the PROCESS rather than an exact diff to apply blindly.

**Strings found and their disposition** (determined during planning by cross-referencing `app/lib/l10n/app_ru.arb`'s existing 365 keys):

| String in file | Existing key? | Action |
|---|---|---|
| `'DukonPro'` | `appTitle` (exact match) | Reuse `appTitle` |
| `'Управление магазином'` | none | New key: `loginSubtitle` |
| `'Введите номер телефона'` | none (checked: no existing validator-message key matches) | New key: `loginPhoneRequired` |
| `'Пароль'` | `password` (exact match) | Reuse `password` |
| `'Минимум 6 символов'` | none | New key: `passwordMinLength` (unprefixed — this exact validation message is likely to recur on other password fields elsewhere in the app; a future file's implementer should check for this key before adding a duplicate) |
| `'Забыли пароль?'` | `forgotPassword` (exact match) | Reuse `forgotPassword` |
| `'Войти'` | `login` (exact match) | Reuse `login` |
| `'Нет аккаунта?'` | `noAccount` (exact match) | Reuse `noAccount` |
| `'Зарегистрироваться'` | `register` (exact match) | Reuse `register` |

Only 3 new keys needed. Add to `app/lib/l10n/app_ru.arb` (near the existing `login`/`password`/`forgotPassword` cluster):
```json
"loginSubtitle": "Управление магазином",
"loginPhoneRequired": "Введите номер телефона",
"passwordMinLength": "Минимум 6 символов",
```

In `app/lib/presentation/pages/auth/login_page.dart`:
- Add the `AppLocalizations` import (check the exact relative path convention from a sibling already-migrated file under `pages/auth/`, if one exists, or another file at the same `pages/<feature>/` depth).
- At the top of `build()`, add `final l10n = AppLocalizations.of(context)!;` (matching whatever local-variable naming convention already-migrated files in this codebase use — check 2-3 examples first).
- `Text('DukonPro', ...)` → `Text(l10n.appTitle, ...)` (drop `const` from the parent `Column`/`Text` if it was const, since `l10n.appTitle` isn't a compile-time constant).
- `Text('Управление магазином', ...)` → `Text(l10n.loginSubtitle, ...)`.
- The `PhoneInputField`'s `validator`: `if (v == null || v.length < 9) return 'Введите номер телефона';` → `return l10n.loginPhoneRequired;`.
- `AppTextField(..., label: 'Пароль', ...)` → `label: l10n.password`.
- The password validator: `if (v == null || v.length < 6) return 'Минимум 6 символов';` → `return l10n.passwordMinLength;`.
- `TextButton(child: const Text('Забыли пароль?'))` → `Text(l10n.forgotPassword)` (drop `const`).
- `AppButton(text: 'Войти', ...)` → `text: l10n.login`.
- `const Text('Нет аккаунта?')` → `Text(l10n.noAccount)`.
- `TextButton(child: const Text('Зарегистрироваться'))` → `Text(l10n.register)`.

Run `flutter gen-l10n`, then `flutter analyze lib/presentation/pages/auth/login_page.dart`, then whatever test(s) cover this page (check `find app/test -iname "*login_page*"`), then commit.

---

## File order (worst-offender first, real counts captured during planning)

Process these 36 files as Tasks 2 through 37, in this exact order. Each task = one file, following the procedure above. Re-confirm the string count when you actually open the file (counts may have shifted slightly since planning).

| Task | File | Approx. strings |
|---|---|---|
| 2 | `app/lib/presentation/pages/dashboard/dashboard_page.dart` | 38 |
| 3 | `app/lib/presentation/pages/shifts/z_report_page.dart` | 31 |
| 4 | `app/lib/presentation/pages/inventory/inventory_count_page.dart` | 23 |
| 5 | `app/lib/presentation/pages/product/import_products_page.dart` | 22 |
| 6 | `app/lib/presentation/pages/finance/credits_page.dart` | 21 |
| 7 | `app/lib/presentation/pages/product/add_product_step2_page.dart` | 20 |
| 8 | `app/lib/presentation/pages/pos/credit_sale_page.dart` | 19 |
| 9 | `app/lib/presentation/pages/dashboard/more_page.dart` | 19 |
| 10 | `app/lib/presentation/pages/staff/add_staff_page.dart` | 18 |
| 11 | `app/lib/presentation/pages/finance/expense_list_page.dart` | 16 |
| 12 | `app/lib/presentation/pages/finance/balance_page.dart` | 16 |
| 13 | `app/lib/presentation/pages/settings/loyalty_settings_page.dart` | 15 |
| 14 | `app/lib/presentation/pages/settings/loyalty_analytics_page.dart` | 15 |
| 15 | `app/lib/presentation/pages/delivery/delivery_detail_page.dart` | 14 |
| 16 | `app/lib/presentation/pages/settings/printer_settings_page.dart` | 13 |
| 17 | `app/lib/presentation/pages/settings/ecommerce_settings_page.dart` | 13 |
| 18 | `app/lib/presentation/pages/auth/register_page.dart` | 12 |
| 19 | `app/lib/presentation/pages/onboarding/onboarding_page.dart` | 11 |
| 20 | `app/lib/presentation/pages/supplier/supplier_detail_page.dart` | 10 |
| 21 | `app/lib/presentation/pages/settings/change_password_page.dart` | 10 |
| 22 | `app/lib/presentation/pages/delivery/delivery_list_page.dart` | 10 |
| 23 | `app/lib/presentation/pages/customer/customer_form_page.dart` | 10 |
| 24 | `app/lib/presentation/pages/debt/debts_overview_page.dart` | 9 |
| 25 | `app/lib/presentation/pages/dashboard/cart_restore_prompt.dart` | 9 |
| 26 | `app/lib/presentation/pages/store/create_store_page.dart` | 8 |
| 27 | `app/lib/presentation/pages/auth/login_page.dart` | 8 (see worked example above — this one is effectively done once Task 27's implementer confirms it matches) |
| 28 | `app/lib/presentation/pages/debt/supplier_debts_page.dart` | 7 |
| 29 | `app/lib/presentation/pages/auth/create_password_page.dart` | 7 |
| 30 | `app/lib/presentation/pages/settings/ecommerce_product_mapping_page.dart` | 6 |
| 31 | `app/lib/presentation/pages/roles/roles_page.dart` | 5 |
| 32 | `app/lib/presentation/pages/product/empty_products_page.dart` | 5 |
| 33 | `app/lib/presentation/pages/auth/otp_page.dart` | 5 |
| 34 | `app/lib/presentation/pages/auth/forgot_password_page.dart` | 5 |
| 35 | `app/lib/presentation/pages/sales/empty_sales_page.dart` | 4 |
| 36 | `app/lib/presentation/pages/dashboard/home_page.dart` | 2 |
| 37 | `app/lib/presentation/pages/onboarding/splash_page.dart` | 1 |

**Note on Task 27** (`login_page.dart`): since this exact file was used as the fully-worked example above, its implementer's job is mostly to verify the file still matches what planning found and apply the already-fully-specified change — this task should be fast. If the file has drifted meaningfully from the worked example, fall back to the general procedure.

---

## Final check (after Task 1 and all 36 l10n tasks land)

- [ ] `cd api && npx jest` — full backend suite passes
- [ ] `cd api && npx tsc --noEmit` — no errors
- [ ] `cd app && flutter gen-l10n` — runs clean (warnings about untranslated tg/uz messages are expected and fine; no errors)
- [ ] `cd app && flutter analyze` — no new issues beyond the pre-existing 6 unrelated info-level hints in `test/data/datasources/remote/product_remote_datasource_test.dart`
- [ ] `cd app && flutter test` — passes (expect the same pre-existing, environment-specific golden-test flakiness already documented across prior branches — 19 failures in files unrelated to this plan's scope; investigate if the count or file list changes)
- [ ] Spot-check: `grep -rl "AppLocalizations.of(context)" app/lib/presentation/pages/ | wc -l` should now read `82` (up from `46`) — every page file uses it
- [ ] `git log --oneline` — confirm Task 1's commit plus all 36 l10n commits are present (37 total)
