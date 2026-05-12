#!/usr/bin/env bash
# Subscription lifecycle test driver. 6 transitions against live API.
#
# Pre-reqs (verified at start):
#   - API at http://localhost:4455 healthy
#   - dukonpro-db container reachable via `docker exec`
#   - admin: +992000000000 / admin123
#   - qa-business owner: +992910001002 / qatest1234 → store qa-business-store
#   - qa-premium owner:  +992910001003 / qatest1234 → store qa-premium-store
#
# Each scenario: seed prereq via SQL → call endpoint → SELECT to verify →
# log ✓ / ✗ / ?.

set -u  # treat unset vars as errors; do NOT set -e because we want to keep going on per-scenario fail

API="http://localhost:4455/api"
RESULTS="$(dirname "$0")/results.txt"
: > "$RESULTS"

DB() { docker exec dukonpro-db psql -U dukonpro -d dukonpro -tA -c "$1" 2>&1; }

login() {
  /usr/bin/curl -sf -X POST "$API/auth/login" \
    -H 'Content-Type: application/json' \
    -d "{\"phone\":\"$1\",\"password\":\"$2\"}" |
    /usr/bin/python3 -c 'import sys,json;print(json.load(sys.stdin).get("accessToken",""))' 2>/dev/null
}

log() { printf "%s %s\n" "$1" "$2" | tee -a "$RESULTS"; }

# ─── Setup ────────────────────────────────────────────────────────────────────

T_ADMIN=$(login "+992000000000" "admin123")
T_BIZ=$(login "+992910001002" "qatest1234")
T_PREM=$(login "+992910001003" "qatest1234")

[ -z "$T_ADMIN" ] && { echo "FATAL: admin login failed"; exit 1; }
[ -z "$T_BIZ"   ] && { echo "FATAL: qa-biz login failed"; exit 1; }
[ -z "$T_PREM"  ] && { echo "FATAL: qa-prem login failed"; exit 1; }

SID_BIZ="d169d2e8-0a24-4a23-844a-5d5e7b690d8c"   # qa-business-store
SID_PREM="c64ec2dc-0bc4-4387-9278-66f552cbed34"  # qa-premium-store

SUB_BIZ=$(DB "SELECT id FROM subscriptions WHERE \"storeId\"='$SID_BIZ';")
SUB_PREM=$(DB "SELECT id FROM subscriptions WHERE \"storeId\"='$SID_PREM';")

[ -z "$SUB_BIZ"  ] && { echo "FATAL: no subscription for qa-biz";  exit 1; }
[ -z "$SUB_PREM" ] && { echo "FATAL: no subscription for qa-prem"; exit 1; }

echo "Setup: SUB_BIZ=$SUB_BIZ SUB_PREM=$SUB_PREM" | tee -a "$RESULTS"
echo "" | tee -a "$RESULTS"

# ─── Scenario 1: TRIAL → ACTIVE via admin approve-payment ─────────────────────
# 1) Reset BIZ sub to TRIAL/BUSINESS so the test is repeatable.
# 2) Owner POSTs request-change → creates a PENDING payment.
# 3) Admin PUT /admin/subscriptions/:id/approve-payment/:pid → status=ACTIVE.

DB "UPDATE subscriptions SET status='TRIAL', plan='BUSINESS', \"currentPeriodEnd\"=NOW()+INTERVAL '5 days' WHERE id='$SUB_BIZ';" >/dev/null

PAY_RESP=$(curl -s -X POST "$API/stores/$SID_BIZ/subscription/request-change" \
  -H "Authorization: Bearer $T_BIZ" -H 'Content-Type: application/json' \
  -d '{"plan":"BUSINESS","paymentMethod":"CARD"}')
PAY_ID=$(echo "$PAY_RESP" | /usr/bin/python3 -c 'import sys,json;print(json.load(sys.stdin).get("id",""))' 2>/dev/null)

if [ -z "$PAY_ID" ]; then
  log "✗" "Scenario 1: request-change did not return a payment id; resp=$PAY_RESP"
else
  APP_RESP=$(curl -s -o /dev/null -w "%{http_code}" -X PUT \
    "$API/admin/subscriptions/$SUB_BIZ/approve-payment/$PAY_ID" \
    -H "Authorization: Bearer $T_ADMIN")
  STATUS_NOW=$(DB "SELECT status FROM subscriptions WHERE id='$SUB_BIZ';")
  PAY_STATUS=$(DB "SELECT status FROM payments WHERE id='$PAY_ID';")
  if [ "$APP_RESP" = "200" ] || [ "$APP_RESP" = "201" ]; then
    if [ "$STATUS_NOW" = "ACTIVE" ] && [ "$PAY_STATUS" = "APPROVED" ]; then
      log "✓" "Scenario 1: TRIAL→ACTIVE; sub.status=$STATUS_NOW, payment.status=$PAY_STATUS"
    else
      log "✗" "Scenario 1: HTTP $APP_RESP but sub.status=$STATUS_NOW payment.status=$PAY_STATUS"
    fi
  else
    log "✗" "Scenario 1: approve HTTP=$APP_RESP"
  fi
fi
echo "" | tee -a "$RESULTS"

# ─── Scenario 2: ACTIVE renewal extends currentPeriodEnd ──────────────────────
# Set sub to ACTIVE with currentPeriodEnd = NOW+10d.
# Run another request-change → approve. Expect new periodEnd = old+30 (extended
# from currentPeriodEnd because it's still in the future).

DB "UPDATE subscriptions SET status='ACTIVE', plan='BUSINESS', \"currentPeriodEnd\"=NOW()+INTERVAL '10 days' WHERE id='$SUB_BIZ';" >/dev/null
END_BEFORE=$(DB "SELECT \"currentPeriodEnd\" FROM subscriptions WHERE id='$SUB_BIZ';")

PAY_RESP=$(curl -s -X POST "$API/stores/$SID_BIZ/subscription/request-change" \
  -H "Authorization: Bearer $T_BIZ" -H 'Content-Type: application/json' \
  -d '{"plan":"BUSINESS","paymentMethod":"CARD"}')
PAY_ID=$(echo "$PAY_RESP" | /usr/bin/python3 -c 'import sys,json;print(json.load(sys.stdin).get("id",""))' 2>/dev/null)

if [ -z "$PAY_ID" ]; then
  log "✗" "Scenario 2: request-change failed; resp=$PAY_RESP"
else
  curl -s -o /dev/null -X PUT \
    "$API/admin/subscriptions/$SUB_BIZ/approve-payment/$PAY_ID" \
    -H "Authorization: Bearer $T_ADMIN"
  END_AFTER=$(DB "SELECT \"currentPeriodEnd\" FROM subscriptions WHERE id='$SUB_BIZ';")
  # +30d > +10d → AFTER must be strictly later.
  IS_LATER=$(DB "SELECT CASE WHEN '$END_AFTER'::timestamp > '$END_BEFORE'::timestamp THEN 'yes' ELSE 'no' END;")
  if [ "$IS_LATER" = "yes" ]; then
    log "✓" "Scenario 2: renewal extended periodEnd ($END_BEFORE → $END_AFTER)"
  else
    log "✗" "Scenario 2: periodEnd did not advance ($END_BEFORE → $END_AFTER)"
  fi
fi
echo "" | tee -a "$RESULTS"

# ─── Scenario 3: Admin extend by N days ───────────────────────────────────────

END_BEFORE=$(DB "SELECT \"currentPeriodEnd\" FROM subscriptions WHERE id='$SUB_BIZ';")
EXT_HTTP=$(curl -s -o /tmp/ext.json -w "%{http_code}" -X PUT \
  "$API/admin/subscriptions/$SUB_BIZ/extend" \
  -H "Authorization: Bearer $T_ADMIN" -H 'Content-Type: application/json' \
  -d '{"days":7}')
END_AFTER=$(DB "SELECT \"currentPeriodEnd\" FROM subscriptions WHERE id='$SUB_BIZ';")
DELTA_DAYS=$(DB "SELECT EXTRACT(EPOCH FROM ('$END_AFTER'::timestamp - '$END_BEFORE'::timestamp))/86400;")
# Should be ≈ 7.0 (allow tiny float wobble).
if [ "$EXT_HTTP" = "200" ] && [ "$(printf '%.0f' "$DELTA_DAYS")" = "7" ]; then
  log "✓" "Scenario 3: extend +7d; delta=${DELTA_DAYS}d"
else
  log "✗" "Scenario 3: HTTP=$EXT_HTTP delta=${DELTA_DAYS}d (expected 7)"
fi
echo "" | tee -a "$RESULTS"

# ─── Scenario 4: PREMIUM → START downgrade — /reports/sales 200 → 403 ─────────
# Reset PREMIUM sub to ACTIVE/PREMIUM. Confirm /reports/sales = 200. Downgrade
# via admin change-plan. Confirm /reports/sales = 403 immediately.

DB "UPDATE subscriptions SET status='ACTIVE', plan='PREMIUM', \"currentPeriodEnd\"=NOW()+INTERVAL '30 days' WHERE id='$SUB_PREM';" >/dev/null

BEFORE=$(curl -s -o /dev/null -w "%{http_code}" \
  "$API/stores/$SID_PREM/reports/sales?from=2026-01-01&to=2026-12-31" \
  -H "Authorization: Bearer $T_PREM")

curl -s -o /dev/null -X PUT "$API/admin/subscriptions/$SUB_PREM/change-plan" \
  -H "Authorization: Bearer $T_ADMIN" -H 'Content-Type: application/json' \
  -d '{"plan":"START"}'

AFTER=$(curl -s -o /dev/null -w "%{http_code}" \
  "$API/stores/$SID_PREM/reports/sales?from=2026-01-01&to=2026-12-31" \
  -H "Authorization: Bearer $T_PREM")

PLAN_NOW=$(DB "SELECT plan FROM subscriptions WHERE id='$SUB_PREM';")
if [ "$BEFORE" = "200" ] && [ "$AFTER" = "403" ] && [ "$PLAN_NOW" = "START" ]; then
  log "✓" "Scenario 4: downgrade access loss immediate (200→403, plan=$PLAN_NOW)"
else
  log "✗" "Scenario 4: BEFORE=$BEFORE AFTER=$AFTER plan=$PLAN_NOW (expected 200→403, START)"
fi
echo "" | tee -a "$RESULTS"

# ─── Scenario 5: ACTIVE → EXPIRED via cron-equivalent ─────────────────────────
# Cron is @Cron('0 0 * * *'); no manual trigger endpoint. We can either
# (a) wait until midnight (not viable) or
# (b) invoke the same SQL the cron does — that exercises the *state machine*
#     transition but NOT the cron handler itself. Mark "?" with a clear note.
#
# Restore PREMIUM sub to ACTIVE first, then push currentPeriodEnd into the past
# and apply the equivalent updateMany the cron does.

DB "UPDATE subscriptions SET status='ACTIVE', plan='PREMIUM', \"currentPeriodEnd\"=NOW()+INTERVAL '30 days' WHERE id='$SUB_PREM';" >/dev/null
DB "UPDATE subscriptions SET \"currentPeriodEnd\"=NOW()-INTERVAL '1 hour' WHERE id='$SUB_PREM';" >/dev/null
# Equivalent of the cron's updateMany:
DB "UPDATE subscriptions SET status='EXPIRED' WHERE status IN ('ACTIVE','TRIAL') AND \"currentPeriodEnd\" < NOW() AND id='$SUB_PREM';" >/dev/null
STATUS_NOW=$(DB "SELECT status FROM subscriptions WHERE id='$SUB_PREM';")

# Verify gating: EXPIRED → /reports/sales must 403 (SubscriptionGuard rejects).
EXP_HTTP=$(curl -s -o /dev/null -w "%{http_code}" \
  "$API/stores/$SID_PREM/reports/sales?from=2026-01-01&to=2026-12-31" \
  -H "Authorization: Bearer $T_PREM")

if [ "$STATUS_NOW" = "EXPIRED" ] && [ "$EXP_HTTP" = "403" ]; then
  log "?" "Scenario 5: EXPIRED transition simulated via SQL (cron has no manual trigger). Guard rejects EXPIRED with 403 as expected."
else
  log "✗" "Scenario 5: status=$STATUS_NOW guard=$EXP_HTTP (expected EXPIRED + 403)"
fi
echo "" | tee -a "$RESULTS"

# ─── Scenario 6: EXPIRED → ACTIVE via approved payment (reactivation) ─────────
# Sub is EXPIRED from Scenario 5. Owner submits a new payment. Admin approves.
# Expect status flips back to ACTIVE.

PAY_RESP=$(curl -s -X POST "$API/stores/$SID_PREM/subscription/request-change" \
  -H "Authorization: Bearer $T_PREM" -H 'Content-Type: application/json' \
  -d '{"plan":"PREMIUM","paymentMethod":"CARD"}')
PAY_ID=$(echo "$PAY_RESP" | /usr/bin/python3 -c 'import sys,json;print(json.load(sys.stdin).get("id",""))' 2>/dev/null)

if [ -z "$PAY_ID" ]; then
  log "✗" "Scenario 6: request-change while EXPIRED failed; resp=$PAY_RESP"
else
  curl -s -o /dev/null -X PUT \
    "$API/admin/subscriptions/$SUB_PREM/approve-payment/$PAY_ID" \
    -H "Authorization: Bearer $T_ADMIN"
  STATUS_NOW=$(DB "SELECT status FROM subscriptions WHERE id='$SUB_PREM';")
  PLAN_NOW=$(DB "SELECT plan FROM subscriptions WHERE id='$SUB_PREM';")
  END_NOW=$(DB "SELECT \"currentPeriodEnd\" > NOW() FROM subscriptions WHERE id='$SUB_PREM';")
  if [ "$STATUS_NOW" = "ACTIVE" ] && [ "$PLAN_NOW" = "PREMIUM" ] && [ "$END_NOW" = "t" ]; then
    log "✓" "Scenario 6: EXPIRED→ACTIVE; status=$STATUS_NOW plan=$PLAN_NOW periodEnd>now=$END_NOW"
  else
    log "✗" "Scenario 6: status=$STATUS_NOW plan=$PLAN_NOW endInFuture=$END_NOW (expected ACTIVE/PREMIUM/t)"
  fi
fi
echo "" | tee -a "$RESULTS"

# ─── Cleanup: leave both subs in a sane state for follow-on tests ─────────────
DB "UPDATE subscriptions SET status='TRIAL', plan='BUSINESS', \"currentPeriodEnd\"=NOW()+INTERVAL '5 days' WHERE id='$SUB_BIZ';" >/dev/null
DB "UPDATE subscriptions SET status='TRIAL', plan='PREMIUM',  \"currentPeriodEnd\"=NOW()+INTERVAL '5 days' WHERE id='$SUB_PREM';" >/dev/null

echo "=== Summary ===" | tee -a "$RESULTS"
cat "$RESULTS"
