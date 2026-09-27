# i18n Allow-list Resync — Design

**Context.** CI's `Flutter app (analyze + test)` job fails at the
`i18n lint (check_i18n.dart)` step, reporting 517 "new" hardcoded
Cyrillic strings outside `tool/i18n-allowlist.txt`. Investigated before
writing this spec (see `docs/adr/0002-i18n-rollout-plan.md`'s existing
"Reconciliation update" section, which already documents this exact
failure mode occurring once before): `check_i18n.dart`'s allow-list keys
each violation by `path:line`, not by string content. Any edit above an
already-allow-listed line in the same file shifts that line number, so
the entry silently stops matching and the same, already-known violation
reappears as "new."

Confirmed by regenerating the allow-list from scratch
(`dart run tool/check_i18n.dart --dump-allowlist`) and diffing against
the committed file, then restoring the committed file (no repo changes
made during investigation):

| | Committed allow-list | Actual current state |
|---|---|---|
| Total violations | 1017 | 1022 |

Per-file comparison shows the real net-new debt is small — about 25
violations across 9 files (`customer_list_page.dart`,
`expense_list_page.dart`, `payroll_page.dart`, `discounts_page.dart`,
`my_stores_page.dart`, `settings_page.dart`, `shifts_page.dart`,
`supplier_detail_page.dart`, `payroll_staff_card.dart`) — the other
~490 of the "517 new" locations are line-number drift on strings that
were already grandfathered before.

**Goal.** Make the `i18n lint` CI step pass again by resyncing the
allow-list to the codebase's actual current state — the same fix this
exact drift problem already received once, per the ADR's own
reconciliation note ("regenerated via `--dump-allowlist`... now reflects
actual current violations").

## Fix

Run `dart run tool/check_i18n.dart --dump-allowlist` from `app/` and
commit the resulting `tool/i18n-allowlist.txt`. This is the same
mechanism the tool already documents in its own header comment
("False positives are added to tool/i18n-allowlist.txt... during the
incremental migration") and the same one used for the prior
reconciliation.

The regenerated file will contain 1022 entries (up from 1017) — the ~25
newly-introduced strings identified above are swept in as grandfathered
debt, undifferentiated from the pre-existing ~1017, exactly like the
tool's own error message describes as an acceptable interim step
("temporarily add them to tool/i18n-allowlist.txt with a TODO" — no
manual per-line TODO annotation is added, matching how the existing
1017-line file already has none).

## Explicitly out of scope

- **Migrating the ~25 newly-introduced strings into `app_ru.arb`.**
  They remain hardcoded, same as the rest of the allow-listed debt.
- **Fixing `check_i18n.dart`'s line-number-based tracking** (e.g.
  switching to a content hash so future edits don't cause this same
  drift again). The tool will very likely need this same resync again
  after further unrelated edits to any of the ~1017 already-affected
  files — that recurrence is accepted, not solved, by this fix.
- **ADR-0002 Track 2** (migrating the full ~1022-violation backlog into
  `app_ru.arb`/`app_tg.arb`/`app_uz.arb`) — a separate, already-scoped,
  much larger initiative in the ADR, untouched here.

## Testing / verification

`cd app && dart run tool/check_i18n.dart` must report
`"no new hardcoded Cyrillic strings"` and exit 0 after the resync.
`flutter analyze` (already fixed in an earlier, separate commit) must
remain clean. No other test suite is affected — this touches one data
file, not application code.
