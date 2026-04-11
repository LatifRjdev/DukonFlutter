#!/usr/bin/env bash
# Generate a fresh api/.env with random JWT secrets from .env.example.
# Safe to re-run; refuses to overwrite an existing .env so no one accidentally
# nukes a working local config.
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ -f .env ]]; then
  echo "api/.env already exists — refusing to overwrite."
  echo "Delete it manually first if you want to regenerate."
  exit 1
fi

if [[ ! -f .env.example ]]; then
  echo "api/.env.example is missing — cannot bootstrap." >&2
  exit 1
fi

gen_secret() {
  node -e "console.log(require('crypto').randomBytes(64).toString('hex'))"
}

access_secret="$(gen_secret)"
refresh_secret="$(gen_secret)"

# Replace the two JWT secret placeholders line-by-line so the access and
# refresh secrets differ (BSD sed has no /N flag for 'replace Nth match').
awk -v a="${access_secret}" -v r="${refresh_secret}" '
  /^JWT_ACCESS_SECRET=/  { print "JWT_ACCESS_SECRET="  a; next }
  /^JWT_REFRESH_SECRET=/ { print "JWT_REFRESH_SECRET=" r; next }
  { print }
' .env.example > .env

chmod 600 .env

echo "Generated api/.env with fresh JWT secrets."
echo "Remember: .env is gitignored and must stay out of CI artifacts."
