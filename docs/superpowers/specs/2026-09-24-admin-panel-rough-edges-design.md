# Admin Panel — Rough Edges — Design

**Context.** After fixing the six confirmed action-layer bugs
(`feature/admin-panel-bugfixes`, merged), a live click-through of the admin
panel also surfaced three UX/completeness gaps that aren't outright bugs
(nothing crashes or silently fails) but make the panel harder or riskier to
operate day-to-day. This spec covers those three, deferred from the bugfix
cycle by explicit agreement.

**Goal.** (1) Let an admin delete a user from the UI — the backend endpoint
already exists and is fully implemented, just unreachable from the panel.
(2) Replace the raw-UUID "new owner" input on store transfer with a
search-by-name/phone picker. (3) Add a confirmation step to the panel's
irreversible or high-consequence one-click actions, closing out the
`// TODO: when confirmation dialog is added` markers already sitting in the
test suite.

## Findings and fixes

### 1. Missing UI: delete user

`DELETE /admin/users/:id` (`admin/users.controller.ts` — soft-delete:
anonymizes phone, nulls email, per `admin.service.ts` `deleteUser()`) has no
caller anywhere in `admin/`. There's no button, no menu item, nothing —
confirmed by grepping the whole `admin/app` tree for `api.delete` and
`toggle-admin`-adjacent action buttons on `users/[id]/page.tsx`.

**Fix:** add a "Удалить пользователя" action to the user detail page
(`admin/app/(admin)/users/[id]/page.tsx`), next to the existing "Сделать
admin" / "Заблокировать" / "Отправить сообщение" / "Войти как пользователь"
row. Since this is destructive and irreversible from the admin's
perspective (the account is anonymized, not just deactivated), it goes
through the new `ConfirmDialog` from Finding 3 rather than firing on a bare
click. On success, navigate back to `/users` (the just-deleted user's own
detail page would immediately 404/blank on refetch otherwise) and show a
success toast.

Out of scope: no "delete" entry point from the users *list* page — the
detail page is the only place other destructive user actions
(block/toggle-admin) live today, so this follows that existing pattern
rather than inventing a second entry point.

### 2. Store transfer: raw UUID input → search-by-name/phone picker

"Передать владение" (both `admin/app/(admin)/stores/page.tsx` and
`admin/app/(admin)/stores/[id]/page.tsx`) currently requires typing the new
owner's raw user ID into a bare text input — and no page in the admin panel
displays a user's ID anywhere, so today the only way to actually use this
feature is to open browser devtools and read it off a network response.

**Fix:** replace the bare `Input` with a small new `UserPicker` component
(`admin/components/user-picker.tsx`) — a text input that filters the
already-fetched `/admin/users` list client-side by name or phone (same
`.toLowerCase().includes(...)` pattern `admin/app/(admin)/users/page.tsx`
already uses for its own search box, not a new backend query), showing up
to 8 matches in a simple dropdown below the input. Selecting a match sets
the transfer dialog's `newOwnerId` state to that user's `id` and displays
their name in the input in place of typed text. No new dependency — reuses
the existing `Input` primitive and plain conditional rendering, not a
`Command`/`Popover` combobox (this codebase has neither installed, and
YAGNI doesn't justify introducing `cmdk` for one text-filtered list of at
most a few hundred rows).

`UserPicker` is a single reusable component so it's built and tested once,
then dropped into both the list-page and detail-page transfer dialogs
identically — the two dialogs currently duplicate the same bare-`Input`
markup, so this is a net reduction in duplicated JSX, not an increase.

### 3. No confirmation on destructive one-click actions

Seven spots across three list pages already carry
`// TODO: when confirmation dialog is added, this test should assert
dialog appears first.` comments in their tests — this is tracked,
acknowledged debt, not a new observation:

- `admin/app/(admin)/stores/page.tsx` — "Приостановить" (suspend a store)
- `admin/app/(admin)/subscriptions/page.tsx` — "Отменить" (cancel a
  subscription), "Подтвердить" (approve a pending payment)
- `admin/app/(admin)/users/page.tsx` — "Заблокировать" (block a user),
  "Снять права admin" / "Сделать admin" (toggle admin rights)

The equivalent actions on the two detail pages
(`admin/app/(admin)/stores/[id]/page.tsx`,
`admin/app/(admin)/users/[id]/page.tsx`) fire just as instantly and aren't
separately marked, but are the same action against the same backend
endpoint reached from a different page — leaving them unconfirmed while the
list-page version is confirmed would be an inconsistent, confusing product,
so they're in scope too.

**Deliberately NOT included:** "Восстановить"/"Разблокировать" (unsuspend,
unblock) and the reject-payment flow. The first two *undo* a restriction —
there's no destructive consequence to confirm, and requiring a confirm
click to un-block someone you just blocked by mistake is friction with no
safety benefit. Reject-payment already requires typing a reason into its
own dialog before it fires, which is itself a confirmation gate; adding a
second dialog on top would be redundant.

**Fix:** one new reusable component,
`admin/components/confirm-dialog.tsx`, built on the existing `Dialog`
primitive (this codebase has no `alert-dialog` installed — reusing `Dialog`
avoids adding a new Radix dependency for what's structurally the same
"are you sure" prompt already hand-built for reject-payment). Props:
`open`, `onOpenChange`, `title`, `description`, `confirmLabel`,
`onConfirm`, `variant?: 'destructive' | 'default'` (destructive renders the
confirm button in the existing red/destructive button style already used
elsewhere for "Ошибка"-flavored UI). Each of the 9 call sites (7 listed
above + delete-user + store-detail-page's suspend/transfer mirrors) wraps
its existing `onClick={() => xMutation.mutate(...)}` handler: the button's
`onClick` now opens the confirm dialog instead of calling the mutation
directly, and the mutation call moves into the dialog's `onConfirm`.

## Testing approach

- **`ConfirmDialog`**: one new component test
  (`admin/components/confirm-dialog.test.tsx`) — renders closed by default,
  opens on `open=true`, calls `onConfirm` and not the mutation on
  "Отмена", calls `onConfirm` and closes on the confirm button.
- **`UserPicker`**: one new component test
  (`admin/components/user-picker.test.tsx`) — typing a partial name/phone
  filters the MSW-mocked `/admin/users` list to matching rows only;
  selecting a row calls `onSelect` with that user's `id` and updates the
  visible input value to their name.
- **Per-page regression tests**: for each of the 9 destructive-action call
  sites, update the existing test (the ones carrying the `// TODO:
  when confirmation dialog is added` comment, plus the equivalent
  not-yet-tested detail-page ones) to: click the action button, assert the
  underlying PUT/DELETE has NOT fired yet and the confirm dialog is visible,
  click confirm, THEN assert the PUT/DELETE fired. This directly closes out
  the existing TODO comments (delete them once satisfied) rather than
  leaving them as stale markers next to now-passing tests.
- **Store transfer**: extend the existing transfer tests (already covering
  the `newOwnerId` field-name fix from the previous cycle) to drive the
  flow through `UserPicker` — type a partial name, click the matching
  result, click "Передать" — instead of filling a raw ID into a bare input.

## Live re-verification

After implementation: delete a disposable test user from the UI and
confirm they disappear from the users list; transfer a disposable test
store by typing a partial owner name and picking them from the dropdown,
confirm ownership actually changes; click each of the 7 previously-bare
destructive buttons and confirm a dialog now appears and nothing fires
until it's confirmed.

## Out of scope

- No change to reject-payment's existing reason-dialog flow beyond
  whatever styling `ConfirmDialog`'s existence might make it tempting to
  unify with — not requested, and it already has its own working gate.
- No backend changes — `DELETE /admin/users/:id` and `GET /admin/users`
  already exist and already do everything this spec needs.
- No new list-page entry point for deleting a user (see Finding 1).
- No debounced/server-side search for `UserPicker` — client-side filtering
  of the already-fetched list, matching the existing users-page search
  box's own approach at today's data scale.
