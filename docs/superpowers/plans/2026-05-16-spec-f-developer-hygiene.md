# Spec F "Developer Hygiene" Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Install CI gap-fills + pre-commit hooks + one-time deps audit + one-time dead-code sweep so the prettier-thrash and dead-controller patterns we've accumulated this sprint stop recurring.

**Architecture:** Order: D dead-code first (informs C), then C deps audit (clean baseline), then A CI gap-fill (with deps stable), finally B lefthook (benefits future commits). Each sub-section's code/commands are in the spec; this plan is bite-sized task orchestration.

**Tech Stack:** NestJS + Prisma 6.19 + Jest (backend); Flutter 3.x + bloc_test (mobile); GitHub Actions; lefthook (new pre-commit harness).

**Spec:** `docs/superpowers/specs/2026-05-16-spec-f-developer-hygiene-design.md` (commit 8efda48).

---

## File Structure

**Created:**
- `lefthook.yml` (repo root)
- `CONTRIBUTING.md` (repo root)
- `qa/2026-05-16-deps-audit/REPORT.md`
- `qa/2026-05-16-dead-code/REPORT.md`

**Modified:**
- `.github/workflows/ci.yml`
- `api/package.json` + `api/package-lock.json`
- `app/pubspec.yaml` + `app/pubspec.lock`
- Various source files (D dead-code deletions, C deps drift)

---

## Sub-section D — Dead-code sweep (do first)

### Task D.1: ts-prune scan + triage

**Files:**
- Create: `qa/2026-05-16-dead-code/REPORT.md`

- [ ] **Step 1: Verify ts-prune is installed (or installable on-the-fly)**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api
npx ts-prune --version 2>&1 | head -1
```
Expected: version string OR "would install" prompt. If neither, install dev dep:
```bash
npm install --save-dev ts-prune
```

- [ ] **Step 2: Run ts-prune, capture all unused exports**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api
npx ts-prune --project tsconfig.json > /tmp/ts-prune-raw.txt
wc -l /tmp/ts-prune-raw.txt
head -30 /tmp/ts-prune-raw.txt
```

Typical output line: `path/to/file.ts:42 - exportedThing (used in module)`. The `(used in module)` tag means it IS used internally — ignore those. Focus on lines WITHOUT that tag.

- [ ] **Step 3: Filter to actionable candidates**

```bash
grep -v "(used in module)" /tmp/ts-prune-raw.txt > /tmp/ts-prune-candidates.txt
wc -l /tmp/ts-prune-candidates.txt
cat /tmp/ts-prune-candidates.txt
```

- [ ] **Step 4: For each candidate, triage**

For each line in `/tmp/ts-prune-candidates.txt`, verify with grep:
```bash
SYMBOL=<the exported name>
grep -rn "$SYMBOL" /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/src/ /Users/latifrjdev/Downloads/01_Проекты/Dukon/api/test/ | grep -v "export.*$SYMBOL" | head -5
```

Categorize each finding:
- **KEEP:** used by NestJS DI (e.g. controller registered in module), Swagger metadata, tests
- **KEEP:** re-exported in a barrel `index.ts` (ts-prune false-positive)
- **DELETE:** truly unreferenced anywhere

Same bar we used for `stock-movements.controller.ts` in Spec E — triple-grep across `src/` AND `test/` AND check `*.module.ts` arrays.

- [ ] **Step 5: Apply deletions one at a time**

For each DELETE candidate:
```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api
# delete or trim the export
# then verify tests still pass:
npm test 2>&1 | grep "Tests:" | tail -1
```

If tests stay green, keep the change. If they fail, revert.

- [ ] **Step 6: Run Flutter dead-code check**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/app
# Try dart_code_metrics first
dart pub global activate dart_code_metrics 2>&1 | tail -3 || true
dart pub global run dart_code_metrics:metrics check-unused-code lib 2>&1 | tee /tmp/dcm-unused.txt | tail -30
```

If `dart_code_metrics` activation fails or the check finds nothing actionable, fall back to manual grep for obviously-unused public widgets:
```bash
# Find every public Widget class
grep -rn "^class [A-Z]" /Users/latifrjdev/Downloads/01_Проекты/Dukon/app/lib/presentation/widgets/ | head -20
# For each, grep usage:
# grep -rln "WidgetName(" /Users/latifrjdev/Downloads/01_Проекты/Dukon/app/lib/
```

Same triage as steps 4-5.

- [ ] **Step 7: Write REPORT.md**

Create `qa/2026-05-16-dead-code/REPORT.md`:

```markdown
# Dead-code sweep — 2026-05-16

## Method
ts-prune on api/, manual+dart_code_metrics on app/lib/. Same delete bar as `stock-movements.controller.ts` (Spec E): triple-grep across src/ + test/ + module arrays.

## Backend findings

| Symbol | File | Disposition | Reason |
|--------|------|-------------|--------|
| <symbol> | <path> | DELETE / KEEP | <note> |
| ... | | | |

## Flutter findings

| Symbol | File | Disposition | Reason |
|--------|------|-------------|--------|
| <symbol> | <path> | DELETE / KEEP | <note> |

## Commits
- <SHA> — delete <symbol>
- ...

## Summary
N candidates triaged: M deleted, K kept (barrel re-exports), L kept (DI/Swagger), J kept (test-only).
```

Fill in with real findings.

- [ ] **Step 8: Final verification + commit REPORT**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api
npm test 2>&1 | grep "Tests:" | tail -1
npx tsc --noEmit 2>&1 | grep "error TS" | head

cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/app
dart analyze lib/ 2>&1 | tail -3
flutter test --reporter=compact 2>&1 | tail -3
```
Expected: all baselines hold (226 + 11 + 441).

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git add qa/2026-05-16-dead-code/REPORT.md
git commit -m "docs(dead-code): triage report — N candidates, M deleted"
```

(Per-delete commits go individually as you apply them in step 5.)

---

## Sub-section C — Dependency audit

### Task C.1: Backend deps audit

**Files:**
- Modify: `api/package.json`, `api/package-lock.json`
- Create: `qa/2026-05-16-deps-audit/REPORT.md`

- [ ] **Step 1: Capture before-state**

```bash
mkdir -p /Users/latifrjdev/Downloads/01_Проекты/Dukon/qa/2026-05-16-deps-audit
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api
npm audit --json > /tmp/audit-pre.json 2>&1 || true
npm audit | head -30 | tee /tmp/audit-pre-human.txt
```

- [ ] **Step 2: Apply non-breaking fixes**

```bash
npm audit fix 2>&1 | tail -10
# Capture after-state:
npm audit --json > /tmp/audit-post.json 2>&1 || true
npm audit | head -30 | tee /tmp/audit-post-human.txt
```

- [ ] **Step 3: Verify still green**

```bash
npx tsc --noEmit 2>&1 | grep "error TS" | head
npm test 2>&1 | grep "Tests:" | tail
npm run test:e2e 2>&1 | grep "Tests:" | tail
```
Expected: 0 errors; 226 unit + 11 e2e pass.

If any test breaks, identify the bumped package + revert via:
```bash
git diff api/package-lock.json | head -20
# rollback specific package if needed
```

- [ ] **Step 4: List outstanding majors**

```bash
npm outdated --long > /tmp/outdated.txt 2>&1 || true
cat /tmp/outdated.txt
```

- [ ] **Step 5: Write the audit doc**

Create `qa/2026-05-16-deps-audit/REPORT.md`:

```markdown
# Dependency audit — 2026-05-16

## Backend (api/)

### npm audit before / after

Before:
- High: N, Moderate: M, Low: K

After `npm audit fix`:
- High: N', Moderate: M', Low: K' (delta)

### Outstanding npm advisories (no fix without breaking)
| Package | Severity | CVE | Workaround |
|---------|----------|-----|------------|
| <pkg> | <sev> | <cve> | <note> |

### Major-version outdated (deferred — each is its own spec)
| Package | Current | Latest | Risk |
|---------|---------|--------|------|
| <pkg> | <ver> | <ver> | <breaking changes summary> |

## Flutter (app/)

(Same shape — populated in Task C.2.)
```

- [ ] **Step 6: Commit C.1**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git add api/package.json api/package-lock.json qa/2026-05-16-deps-audit/REPORT.md
git commit -m "fix(deps): npm audit fix + outdated triage (Spec F C.1)"
```

### Task C.2: Flutter deps audit

**Files:**
- Modify: `app/pubspec.yaml`, `app/pubspec.lock`
- Modify: `qa/2026-05-16-deps-audit/REPORT.md` (extend)

- [ ] **Step 1: Capture before-state**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/app
flutter pub outdated --no-dependency-overrides > /tmp/pub-outdated-pre.txt 2>&1 || true
head -40 /tmp/pub-outdated-pre.txt
```

- [ ] **Step 2: Apply within-constraint upgrades**

```bash
flutter pub upgrade 2>&1 | tail -5
flutter pub get 2>&1 | tail -3
```

- [ ] **Step 3: Verify still green**

```bash
dart analyze lib/ 2>&1 | tail -3
flutter test --reporter=compact 2>&1 | tail -3
```
Expected: 0 issues; 441 pass.

If golden tests break (font / pixel drift from a packed dep), re-baseline only those:
```bash
flutter test --update-goldens <specific test file>
```

- [ ] **Step 4: List outstanding majors**

```bash
flutter pub outdated --mode=null-safety > /tmp/pub-outdated-post.txt 2>&1 || true
head -40 /tmp/pub-outdated-post.txt
```

- [ ] **Step 5: Extend REPORT.md with Flutter section**

Edit the existing `qa/2026-05-16-deps-audit/REPORT.md` from C.1 — fill in the Flutter section with before/after counts + outstanding majors.

- [ ] **Step 6: Commit C.2**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git add app/pubspec.yaml app/pubspec.lock qa/2026-05-16-deps-audit/REPORT.md
git commit -m "fix(deps): flutter pub upgrade + outdated triage (Spec F C.2)"
```

---

## Sub-section A — CI gap-fill

### Task A.1: Add backend-e2e job + audit advisories

**Files:**
- Modify: `.github/workflows/ci.yml`

- [ ] **Step 1: Read current workflow**

```bash
cat /Users/latifrjdev/Downloads/01_Проекты/Dukon/.github/workflows/ci.yml
```

- [ ] **Step 2: Add new `backend-e2e` job**

Edit the yml. After the `backend` job ends, insert the `backend-e2e` job verbatim from the spec's Sub-section A.1 (postgres service + `npm run test:e2e -- --ci --colors`).

- [ ] **Step 3: Add npm audit advisory step to backend job**

In the existing `backend` job, after `npm ci` add:
```yaml
      - name: npm audit (high+ only — advisory)
        run: npm audit --audit-level=high
        continue-on-error: true
```

- [ ] **Step 4: Add `flutter pub outdated` advisory step**

In the existing `flutter` job, after `flutter pub get` add:
```yaml
      - name: flutter pub outdated (advisory)
        run: flutter pub outdated --no-dependency-overrides --no-dev-dependencies
        continue-on-error: true
```

- [ ] **Step 5: Promote analyze to strict**

In the existing `flutter` job, change:
```yaml
      - name: Dart analyze
        run: flutter analyze --no-fatal-infos
```
to:
```yaml
      - name: Dart analyze (strict)
        run: flutter analyze
```

- [ ] **Step 6: Validate yml syntax**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
# Soft validation:
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml'))" && echo "YAML valid"
```

- [ ] **Step 7: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git add .github/workflows/ci.yml
git commit -m "ci: add e2e job + audit advisories + strict analyze (Spec F A)

- new backend-e2e job with postgres:16 service container
- npm audit --audit-level=high advisory step (continue-on-error)
- flutter pub outdated advisory step (continue-on-error)
- flutter analyze promoted to fatal-infos (was --no-fatal-infos)"
```

### Task A.2: CONTRIBUTING.md with branch-protection docs

**Files:**
- Create: `CONTRIBUTING.md`

- [ ] **Step 1: Check if file exists**

```bash
ls /Users/latifrjdev/Downloads/01_Проекты/Dukon/CONTRIBUTING.md 2>&1
```

- [ ] **Step 2: Create the file**

```markdown
# Contributing

## Local setup

### Backend (api/)
```bash
cd api
npm ci
npx prisma generate
npm test
```

### Flutter (app/)
```bash
cd app
flutter pub get
flutter test
```

## Pre-commit hooks

We use [lefthook](https://github.com/evilmartians/lefthook) to gate prettier / lint / typecheck on staged files before commit, and the full test suite before push.

### Install
```bash
brew install lefthook       # macOS
# OR
go install github.com/evilmartians/lefthook@latest
# THEN:
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
lefthook install
```

### Bypass (emergencies only)
```bash
git commit --no-verify   # skip pre-commit
git push --no-verify     # skip pre-push tests
```

## CI

GitHub Actions runs on every PR + push to main:
- `backend` — tsc + jest unit + nest build + npm audit advisory
- `backend-e2e` — postgres container + jest e2e
- `flutter` — pub get + analyze (strict) + i18n lint + flutter test + pub-outdated advisory

## Branch protection (repo settings)

A repo admin must set these as **Required status checks** in
Settings → Branches → Branch protection rule for `main`:
- `Backend (Nest / Jest)`
- `Backend e2e (Jest + Postgres)`
- `Flutter app (analyze + test)`

Also recommended:
- Require pull request before merging
- Require linear history
- Do not allow bypassing the above settings
```

- [ ] **Step 3: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git add CONTRIBUTING.md
git commit -m "docs: CONTRIBUTING.md with setup + lefthook + branch protection (Spec F A.4)"
```

---

## Sub-section B — Lefthook pre-commit hooks (do last)

### Task B.1: Lefthook config

**Files:**
- Create: `lefthook.yml`

- [ ] **Step 1: Create the config**

Write `lefthook.yml` at repo root with EXACT content from Sub-section B of the spec:

```yaml
pre-commit:
  parallel: true
  commands:
    api-prettier:
      glob: "api/**/*.{ts,tsx,js,json}"
      run: cd api && npx prettier --check {staged_files}
    api-tsc:
      glob: "api/**/*.{ts,tsx}"
      run: cd api && npx tsc --noEmit
    api-eslint:
      glob: "api/**/*.{ts,tsx}"
      run: cd api && npx eslint {staged_files} --max-warnings=0
    flutter-format:
      glob: "app/**/*.dart"
      run: cd app && dart format --set-exit-if-changed {staged_files}
    flutter-analyze:
      glob: "app/**/*.dart"
      run: cd app && dart analyze {staged_files}

pre-push:
  commands:
    api-test:
      run: cd api && npm test -- --ci --silent
    flutter-test:
      run: cd app && flutter test --reporter compact
```

- [ ] **Step 2: Validate yml**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
python3 -c "import yaml; yaml.safe_load(open('lefthook.yml'))" && echo "YAML valid"
```

- [ ] **Step 3: Install + smoke test**

```bash
# If lefthook installed locally:
which lefthook 2>&1 | head -1
# If yes:
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
lefthook install 2>&1 | tail -5
# Force-run pre-commit on staged files (none yet — should pass trivially):
lefthook run pre-commit 2>&1 | tail -10
```

If lefthook isn't installed locally, that's OK — the config is committed; install is documented in CONTRIBUTING.md.

- [ ] **Step 4: Commit**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git add lefthook.yml
git commit -m "feat(hooks): lefthook config for pre-commit + pre-push (Spec F B)

Pre-commit (parallel, staged files only):
- api: prettier --check, tsc --noEmit, eslint --max-warnings=0
- flutter: dart format --set-exit-if-changed, dart analyze

Pre-push (full suites):
- api: npm test
- flutter: flutter test

Install via 'lefthook install'; bypass with --no-verify per
CONTRIBUTING.md docs. Ends the prettier-thrash chore-commit
pattern."
```

---

## Task E.1: Final verification gate

**Files:** None (verification only)

- [ ] **Step 1: Full test gate**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/api
npx tsc --noEmit 2>&1 | grep -v "\.spec\." | grep "error TS" | head
npm test 2>&1 | grep "Tests:" | tail
npm run test:e2e 2>&1 | grep "Tests:" | tail
npm audit --audit-level=high 2>&1 | tail -10

cd /Users/latifrjdev/Downloads/01_Проекты/Dukon/app
dart analyze lib/ 2>&1 | tail -3
flutter test --reporter=compact 2>&1 | tail -3
```
Expected:
- 0 tsc errors
- ≥226 unit, ≥11 e2e
- 0 high/critical npm advisories (or documented in REPORT)
- 0 dart issues
- ≥441 flutter pass

- [ ] **Step 2: Confirm artefacts exist**

```bash
ls /Users/latifrjdev/Downloads/01_Проекты/Dukon/qa/2026-05-16-deps-audit/REPORT.md \
   /Users/latifrjdev/Downloads/01_Проекты/Dukon/qa/2026-05-16-dead-code/REPORT.md \
   /Users/latifrjdev/Downloads/01_Проекты/Dukon/CONTRIBUTING.md \
   /Users/latifrjdev/Downloads/01_Проекты/Dukon/lefthook.yml
```
Expected: all 4 listed.

- [ ] **Step 3: Confirm CI workflow has 3 jobs**

```bash
grep -E "^  [a-z][a-z-]+:$|^  [a-z][a-z-]+:" /Users/latifrjdev/Downloads/01_Проекты/Dukon/.github/workflows/ci.yml | head -10
```
Expected: `backend:`, `backend-e2e:`, `flutter:` jobs visible.

- [ ] **Step 4: Final summary**

```bash
cd /Users/latifrjdev/Downloads/01_Проекты/Dukon
git status --short
git log --oneline 8efda48..HEAD | head -20
```

---

## Self-Review

**Spec coverage:**
- ✅ Sub-section A (CI gap-fill) — Task A.1 + A.2
- ✅ Sub-section B (lefthook) — Task B.1
- ✅ Sub-section C (deps audit) — Task C.1 + C.2
- ✅ Sub-section D (dead-code sweep) — Task D.1
- ✅ Final gate — Task E.1

**Order respects dependencies:** D first (informs C), C next (clean baseline), A after (deps stable for CI), B last (workflow change for future commits). Matches spec ship plan.

**Type / name consistency:** Filenames + YAML keys + commit messages all match spec verbatim.

**Placeholders:** None. Each step has concrete commands.

Plan complete and saved to `docs/superpowers/plans/2026-05-16-spec-f-developer-hygiene.md`.
