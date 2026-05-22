# Contributing

## Local setup

### Backend (api/)

```bash
cd api
npm ci
npx prisma generate
npm test
```

Requires a running Postgres (the dev compose container is `dukonpro-db`
at `localhost:5435`, user/password/db all `dukonpro`).

### Flutter app (app/)

```bash
cd app
flutter pub get
flutter test
```

## Pre-commit hooks

We use [lefthook](https://github.com/evilmartians/lefthook) to gate
prettier / lint / typecheck on staged files before commit, and the full
test suite before push. The config lives in `lefthook.yml` at the repo
root.

### Install

```bash
brew install lefthook                              # macOS
# or:
go install github.com/evilmartians/lefthook@latest # any platform
# then:
cd /path/to/Dukon
lefthook install
```

After `lefthook install`, every `git commit` runs the pre-commit
checks on the staged files and every `git push` runs the test suites.

### Bypass (emergencies only)

```bash
git commit --no-verify   # skip pre-commit
git push --no-verify     # skip pre-push tests
```

Bypass should be rare. If something fails the hooks, prefer fixing the
underlying issue (e.g. `cd api && npx prettier --write .`).

## CI

GitHub Actions runs on every PR + push to `main`:

| Job                              | What it runs                                         |
|----------------------------------|------------------------------------------------------|
| **Backend (Nest / Jest)**        | `npm ci` → prisma generate → `tsc --noEmit` → `npm test` → `npm run build` + `npm audit` advisory |
| **Backend e2e (Jest + Postgres)** | postgres:16 service container → `prisma migrate deploy` → `npm run test:e2e` |
| **Flutter app (analyze + test)** | `pub get` → `flutter analyze` (strict) → i18n lint → `flutter test` + `pub outdated` advisory |

Advisory steps (`npm audit`, `pub outdated`) use `continue-on-error:
true` — they surface yellow but don't block merge. Promote to required
once outstanding findings drop under ~5.

## Branch protection (repo settings)

A repo admin must set the 3 CI jobs as **Required status checks**
in Settings → Branches → Branch protection rule for `main`:

- `Backend (Nest / Jest)`
- `Backend e2e (Jest + Postgres)`
- `Flutter app (analyze + test)`

Also recommended:

- ☑ Require pull request before merging
- ☑ Require linear history
- ☑ Do not allow bypassing the above settings

## Commit messages

Conventional-commit-ish style, no strict tooling:

```
type(scope): subject

Body with the why if non-obvious. Multi-line OK.

Co-Authored-By: ... (when pairing)
```

Common types: `feat`, `fix`, `chore`, `docs`, `refactor`, `test`,
`schema`, `ci`, `style`.

## Throttle limits

| Endpoint | Limit | TTL | Reason |
|----------|------:|-----|--------|
| Global default | 300 | 60s | Normal POS traffic |
| Auth /register | 3 | 60s | Account creation abuse |
| Auth /login | 5 | 60s | Password brute-force |
| Auth /refresh | 10 | 60s | Token cycling |
| Auth /send-otp | 3 | 60s | SMS spam |
| Auth /verify-otp | 5 | 60s | OTP brute-force |
| Auth /forgot-password | 3 | 60s | SMS spam |
| Auth /reset-password | 3 | 60s | Password reset abuse |
| Admin mutations | 60 | 60s | Compromised admin account |

Admin mutations covered: `POST /admin/announcements`, `POST /admin/announcements/preview`,
`PUT /admin/plans/:plan`, `PUT /admin/stores/:id/suspend`, `PUT /admin/stores/:id/unsuspend`,
`PUT /admin/stores/:id/transfer`, `PUT /admin/users/:id/toggle-admin`,
`PUT /admin/users/:id/block`, `PUT /admin/users/:id/unblock`, `DELETE /admin/users/:id`.
Admin read endpoints (`GET`) remain at the global 300/min.

## Where things live

- `api/` — NestJS + Prisma backend
- `app/` — Flutter mobile app
- `docs/superpowers/specs/` — design docs
- `docs/superpowers/plans/` — implementation plans
- `qa/<date>-<topic>/` — verification artefacts (REPORT.md, scripts, screenshots)
