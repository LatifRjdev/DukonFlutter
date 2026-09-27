# i18n Allow-list Resync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make CI's `i18n lint (check_i18n.dart)` step pass again by regenerating `app/tool/i18n-allowlist.txt` to match the codebase's actual current state.

**Architecture:** One command regenerates the allow-list data file from a fresh scan of `app/lib/presentation/`; no application code changes. This is a resync, not a migration — see `docs/superpowers/specs/2026-09-27-i18n-allowlist-resync-design.md` for why the file drifted and why migrating the ~25 genuinely-new strings is explicitly out of scope here.

**Tech Stack:** Dart (`app/tool/check_i18n.dart`, already exists, no changes needed), Flutter.

**Working directory:** create a new worktree per `superpowers:using-git-worktrees` (branch e.g. `fix/i18n-allowlist-resync`) before starting Task 1 — do not implement on `main`. All commands below assume you've `cd`'d into that worktree's `app/` directory.

---

### Task 1: Regenerate and commit the allow-list

**Files:**
- Modify: `app/tool/i18n-allowlist.txt` (regenerated data file — not hand-edited, produced entirely by the command in Step 1)

- [ ] **Step 1: Regenerate the allow-list from the current codebase**

Run from `app/`:

```bash
dart run tool/check_i18n.dart --dump-allowlist
```

Expected output: `check_i18n: wrote 1022 locations to tool/i18n-allowlist.txt` (the exact count may differ by a handful if other commits landed on `main` between when this plan was written and when you run it — that's fine, the point is a fresh, accurate count, not this specific number).

- [ ] **Step 2: Verify the lint now passes clean**

Run:

```bash
dart run tool/check_i18n.dart
```

Expected output: `check_i18n: scanned <N> files, no new hardcoded Cyrillic strings.` and the command exits 0 (check with `echo $?` immediately after if the output alone doesn't make this obvious).

- [ ] **Step 3: Confirm `flutter analyze` is still clean**

This step doesn't touch any `.dart` source, so this should be unaffected, but confirm nothing else regressed since the last check:

```bash
flutter analyze
```

Expected output: `No issues found!`

- [ ] **Step 4: Run the Flutter test suite**

```bash
flutter test --reporter expanded
```

Expected: all tests pass (this change touches no application code, so this is a sanity check, not expected to catch anything — if it fails, the failure is unrelated to this change and should be investigated separately, not papered over).

- [ ] **Step 5: Commit**

```bash
git add tool/i18n-allowlist.txt
git commit -m "$(cat <<'EOF'
fix(app): resync i18n allow-list to current codebase state

check_i18n.dart's allow-list keys violations by file:line, not content —
any edit above an already-allow-listed line in the same file shifts its
line number and the entry silently stops matching, making the same
long-known violation reappear as "new" (this exact drift already
documented once before in docs/adr/0002-i18n-rollout-plan.md's
Reconciliation section). Regenerated via
`dart run tool/check_i18n.dart --dump-allowlist` from a fresh scan of
lib/presentation/ — no application code changed, no strings migrated.

Per docs/superpowers/specs/2026-09-27-i18n-allowlist-resync-design.md,
deliberately NOT included here: migrating the ~25 genuinely-new
violations into app_ru.arb, fixing check_i18n.dart's line-based tracking
(so this exact drift doesn't recur), and ADR-0002 Track 2 (the full
~1022-violation backlog migration) — all explicitly out of scope.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Final verification

**Files:** none (verification only)

- [ ] **Step 1: Re-run the exact CI step locally, one more time, post-commit**

```bash
dart run tool/check_i18n.dart
```

Expected: same clean pass as Task 1 Step 2 — this just confirms the committed file (not an uncommitted working-tree version) is what actually gets checked out and scanned.

No further commit for this task — it's a checkpoint before the final review, live re-verification (there's no "live" environment for this change beyond CI itself, so "live re-verification" here means: push and watch the actual CI run go green), and `superpowers:finishing-a-development-branch`.
