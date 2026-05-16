# Design — Spec F "Developer Hygiene"

**Date:** 2026-05-16
**Scope:** 4 sub-sections close gaps in the developer workflow:
CI extensions (e2e + audit advisories + fatal-infos), pre-commit
hooks via lefthook, one-time dependency audit, one-time dead-code
sweep.
**Decisions:** lefthook (not husky); npm audit ≥ high blocks;
flutter pub upgrade `--major-versions` reviewed manually; dead-code
deletions only on triple-confirmed unused (same bar as deleted
`stock-movements.controller.ts` in Spec E).

## Summary

The carry-forward sprints surfaced 2 hygiene gaps repeatedly:
(a) 13+ "prettier auto-format" chore commits because no
pre-commit hook gates style; (b) at least one dead controller
file we found by accident. This spec installs the rails so neither
recurs. CI exists already and is solid; we extend it to cover e2e
+ audit signals + stricter analyze. One-time deps audit and
dead-code sweep close current backlog.

## Reality check (what already exists)

- `.github/workflows/ci.yml` runs on push/PR to main:
  - Backend: `npm ci` → `prisma generate` → `tsc --noEmit` → `npm test` → `npm run build`
  - Flutter: `flutter pub get` → `flutter analyze --no-fatal-infos` → `dart run tool/check_i18n.dart` → `flutter test --reporter expanded`
- Concurrency cancel for old PR runs already configured.
- **No pre-commit hooks** (no `.husky/`, no `lefthook.yml`).
- **No root package.json** — monorepo is loose: `api/` and `app/` are siblings.

## Sub-section A — CI gap-fill

### A.1: Add e2e test job

The current `backend` job runs `npm test` (Jest unit) but NOT
`npm run test:e2e`. The e2e suite needs a real Postgres. Add a
new job:

```yaml
backend-e2e:
  name: Backend e2e (Jest + Postgres)
  runs-on: ubuntu-latest
  services:
    postgres:
      image: postgres:16
      env:
        POSTGRES_USER: dukonpro
        POSTGRES_PASSWORD: dukonpro
        POSTGRES_DB: dukonpro
      ports: ['5435:5432']
      options: >-
        --health-cmd pg_isready
        --health-interval 10s
        --health-timeout 5s
        --health-retries 5
  defaults:
    run:
      working-directory: api
  env:
    DATABASE_URL: postgresql://dukonpro:dukonpro@localhost:5435/dukonpro?schema=public
  steps:
    - uses: actions/checkout@v4
    - uses: actions/setup-node@v4
      with:
        node-version: "20"
        cache: npm
        cache-dependency-path: api/package-lock.json
    - run: npm ci
    - run: npx prisma migrate deploy
    - run: npm run test:e2e -- --ci --colors
```

(Adapt port 5435 to whatever local dev uses — matches existing
`dukonpro-db` container.)

### A.2: Advisory deps signals

In the existing `backend` job, after `npm ci`, add a
non-blocking step:
```yaml
- name: npm audit (high+ only — advisory)
  run: npm audit --audit-level=high
  continue-on-error: true
```

In the existing `flutter` job, after `flutter pub get`, add:
```yaml
- name: flutter pub outdated (advisory)
  run: flutter pub outdated --no-dependency-overrides --no-dev-dependencies
  continue-on-error: true
```

Both are signals only — they show up yellow but don't block merge.
Promotes them to required status later when we have <5 outstanding
findings.

### A.3: Promote `flutter analyze` to `--fatal-infos`

Current: `flutter analyze --no-fatal-infos`. Change to:
```yaml
- name: Dart analyze (strict)
  run: flutter analyze
```

(Default behavior fails on infos too.) If this surfaces a flood
of infos, downgrade to `--no-fatal-infos` and file a follow-up.
Most of our `dart analyze lib/` runs in prior sessions reported
0 issues — risk is low.

### A.4: Document required-status checks

Create `CONTRIBUTING.md` (or extend `README.md` if it exists)
with a "Repo settings" section listing the 4 jobs that should be
required: `backend`, `backend-e2e`, `flutter`, plus the lefthook
note. We can't set GitHub branch protection from repo files; the
doc tells whoever administers the repo what to flip.

## Sub-section B — Pre-commit hooks (lefthook)

### Why lefthook (not husky)

- Single Go binary, no Node dep at install time
- Per-subdirectory glob filters work cleanly with `api/` + `app/` monorepo layout
- Faster than husky on cold start
- No `package.json` at repo root required (we don't have one)

### Layout

`lefthook.yml` at repo root:

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

`pre-commit` runs in parallel for speed. `pre-push` runs the full
test suite — slower (~1 min) but escapeable with `git push --no-verify`
when intentionally pushing WIP.

Install instruction (in CONTRIBUTING.md):
```bash
brew install lefthook    # mac
# or: go install github.com/evilmartians/lefthook@latest
lefthook install
```

### Bypass policy
- `--no-verify` allowed but discouraged. Documented in CONTRIBUTING.
- The prettier "13 chore commits" pattern stops because pre-commit fails the commit instead of letting unformatted code through.

## Sub-section C — One-time dependency audit

### C.1: Backend deps

```bash
cd api
npm audit --json > /tmp/audit-pre.json
npm audit fix
npm audit --json > /tmp/audit-post.json
npm test                  # confirm green
npm run test:e2e          # confirm green
```

Record before/after counts in `qa/2026-05-16-deps-audit/REPORT.md`.

Then triage `npm outdated`:
- Patch + minor: bump automatically
- Major: list in REPORT with risk note (NestJS 11? Prisma 6→7 if available?)
- Don't bump major versions in this spec — separate spec each

### C.2: Flutter deps

```bash
cd app
flutter pub outdated --no-dependency-overrides > /tmp/pub-outdated.txt
flutter pub upgrade           # bump within constraints
flutter pub get
flutter test                  # confirm green
```

Then `flutter pub outdated --mode=null-safety` for any majors.
Same triage as C.1 — log majors, don't bump them here.

### C.3: Prisma generator client

`npm outdated prisma @prisma/client` — if 6.19.2 → 6.x latest patch,
bump. If 6.x → 7.x available, defer (likely breaking).

## Sub-section D — Dead-code sweep

### D.1: Backend (ts-prune)

```bash
cd api
npx ts-prune --project tsconfig.json > /tmp/ts-prune.txt
```

For each entry:
- If it's a re-export in `index.ts`/barrel — keep
- If used by tests only — keep
- If used by Swagger / dependency injection (NestJS) — keep
- If truly unused everywhere (grep'd in api/src/ + api/test/) — delete

Output: `qa/2026-05-16-dead-code/REPORT.md` with each finding +
disposition. Same bar we used for `stock-movements.controller.ts`
in Spec E (triple-grep confirmation before delete).

### D.2: Flutter

```bash
cd app
# Option A: dart_code_metrics (if installed)
dart run dart_code_metrics:metrics check-unused-code lib 2>&1 | tee /tmp/dcm.txt
# Option B: manual grep sweep for declared-but-unused public methods
```

Same triage as D.1. Public widgets used only in golden tests stay.

## Files touched

**Created:**
- `lefthook.yml` (repo root)
- `CONTRIBUTING.md` (repo root) — install + branch protection docs
- `qa/2026-05-16-deps-audit/REPORT.md`
- `qa/2026-05-16-dead-code/REPORT.md`

**Modified:**
- `.github/workflows/ci.yml` — A.1 (new e2e job) + A.2 (audit advisories) + A.3 (fatal-infos)
- `api/package.json` + `api/package-lock.json` — C.1 minor bumps
- `app/pubspec.yaml` + `app/pubspec.lock` — C.2 minor bumps
- Variable files — D dead-code deletions

## Out of scope

- Renovate / Dependabot setup (requires GitHub App install decision)
- Conventional commits enforcement
- Branch protection auto-setup via API (needs admin token in CI)
- Code coverage thresholds + Codecov integration (Spec G observability)
- E2E browser tests via Playwright (Spec G or later)
- Major-version Prisma / NestJS / Flutter SDK bumps (each is its own
  spec — too risky to bundle)
- Storybook-equivalent for Flutter widgets (Spec M dashboard polish
  if at all)

## Acceptance

- `.github/workflows/ci.yml` has 3 jobs (backend, backend-e2e,
  flutter) — all green on the spec branch
- `lefthook install` then committing a deliberately-broken file
  (extra trailing whitespace) fails the commit
- `qa/2026-05-16-deps-audit/REPORT.md` shows 0 high/critical npm
  advisories remaining (or documented exceptions)
- `qa/2026-05-16-dead-code/REPORT.md` lists findings + the deletes
  applied; full suite still green
- `npm test` ≥226 + `npm run test:e2e` ≥11 + `flutter test` ≥441,
  `dart analyze lib/` 0, `npx tsc --noEmit` 0

## Risks

- **`flutter analyze` strict may surface infos.** Mitigation: if
  >15 surfaced, leave `--no-fatal-infos`, file follow-up. Most
  recent runs reported 0 issues so likely fine.
- **`npm audit fix` may break.** Mitigation: incremental bumps,
  run tests after each, revert breaking changes.
- **Lefthook adds friction for first-time contributors.** Mitigation:
  CONTRIBUTING.md has the install command. `--no-verify` works as
  escape hatch.
- **ts-prune may flag re-exports as unused.** Mitigation: each
  finding triaged manually; only triple-confirmed unused gets
  deleted.
- **CI e2e job runtime.** Adding Postgres service + e2e tests
  bumps total CI time by ~2-3 min. Acceptable for PR confidence.

## Ship plan

~2 days. Order:
1. **D dead-code** first — informs what NOT to update in C
2. **C deps audit** — green-field after dead-code cleanup
3. **A CI gap-fill** — needs deps stable
4. **B lefthook** — last; future commits benefit from the hooks

## Test results gate

After implementation:
- API: `npm test` (≥226) + `npm run test:e2e` (≥11) — green
- Flutter: `flutter test` (≥441) + `dart analyze lib/` (0)
- 0 tsc errors
- 0 high/critical npm audit findings
- `lefthook install` works on a fresh checkout
- CI workflow runs all 3 jobs green
