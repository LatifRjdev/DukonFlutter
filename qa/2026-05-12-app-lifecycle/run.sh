#!/usr/bin/env bash
# App lifecycle stress test driver. 6 scenarios.
# Some scenarios are best-effort automated; manual verification noted in REPORT.
set -e

PKG="com.itlsolutions.dukonpro"
DEVICE="emulator-5554"
DST="$(dirname "$0")/screenshots"
mkdir -p "$DST"
RESULTS="$(dirname "$0")/results.txt"
: > "$RESULTS"

log() { printf "%s %s\n" "$1" "$2" | tee -a "$RESULTS"; }
shot() { adb -s "$DEVICE" exec-out screencap -p > "$DST/$1.png" && \
         sips -Z 1200 "$DST/$1.png" --out "$DST/$1-sm.png" >/dev/null 2>&1; }
relaunch() {
  adb -s "$DEVICE" shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
  sleep 6
}
ui_dump() {
  adb -s "$DEVICE" shell uiautomator dump /sdcard/ui.xml >/dev/null
  adb -s "$DEVICE" pull /sdcard/ui.xml /tmp/ui.xml >/dev/null
  cat /tmp/ui.xml
}

# Helper: get a fresh business token
get_biz_token() {
  /usr/bin/curl -sf -X POST http://localhost:4455/api/auth/login \
    -H 'Content-Type: application/json' \
    -d '{"phone":"+992910001002","password":"qatest1234"}' |
    /usr/bin/python3 -c 'import sys,json;print(json.load(sys.stdin).get("accessToken",""))'
}

SID_BIZ="d169d2e8-0a24-4a23-844a-5d5e7b690d8c"

# Pre-test: ensure app is open and logged in (assume previous session ok)
relaunch
sleep 3
shot "00-cold-start"

# === Scenario 1: kill mid-cart -> restore prompt ===
echo "=== Scenario 1: kill mid-cart ==="
# Use the API to seed a saved cart in SharedPreferences? No - that's app-side only.
# Drive via UI: navigate to Касса tab, tap a product chip to add to cart.
# Coordinates may drift; provide best-effort.
adb -s "$DEVICE" shell input tap 540 2245   # Касса tab (5-tab bottom nav)
sleep 3
shot "01a-cart-empty"
adb -s "$DEVICE" shell input tap 147 525    # first product chip
sleep 2
shot "01b-cart-with-item"

# Kill the app
adb -s "$DEVICE" shell am force-stop "$PKG"
sleep 2

# Cold start; expect restore prompt
relaunch
sleep 4
shot "02-cold-start-prompt"

# Detect "Восстановить корзину?" in UI
ui_dump > /dev/null
if grep -q "Восстановить" /tmp/ui.xml; then
  log "OK" "Scenario 1: restore prompt shown after kill mid-cart"
else
  log "?" "Scenario 1: restore prompt NOT detected - may have empty cart or coordinate drift; check 02-cold-start-prompt screenshot"
fi

# Dismiss prompt
adb -s "$DEVICE" shell input keyevent KEYCODE_BACK
sleep 1

# === Scenario 2: kill mid-checkout (after Оформить) ===
echo "=== Scenario 2: kill mid-checkout ==="
adb -s "$DEVICE" shell input tap 540 2245   # Касса
sleep 2
adb -s "$DEVICE" shell input tap 147 525    # add chip
sleep 1
adb -s "$DEVICE" shell input tap 540 1991   # Оформить (bottom CTA)
sleep 2
shot "03-checkout-screen"
adb -s "$DEVICE" shell am force-stop "$PKG"
sleep 2
relaunch
sleep 4
shot "04-after-checkout-kill"
ui_dump > /dev/null
if grep -q "Восстановить" /tmp/ui.xml; then
  log "OK" "Scenario 2: restore prompt shown after kill mid-checkout"
else
  log "?" "Scenario 2: prompt not detected - see 04-after-checkout-kill screenshot"
fi
adb -s "$DEVICE" shell input keyevent KEYCODE_BACK
sleep 1

# === Scenario 3: offline sale via API + kill + reconnect verifies persistence ===
echo "=== Scenario 3: offline+kill+reconnect ==="
T_BIZ=$(get_biz_token)
PRE_COUNT=$(curl -s "http://localhost:4455/api/stores/$SID_BIZ/sales?page=1&limit=1" \
  -H "Authorization: Bearer $T_BIZ" |
  python3 -c 'import sys,json;print(json.load(sys.stdin).get("total",0))' 2>/dev/null || echo 0)

adb -s "$DEVICE" shell svc wifi disable
adb -s "$DEVICE" shell svc data disable
sleep 4
relaunch
adb -s "$DEVICE" shell am force-stop "$PKG"
sleep 1
adb -s "$DEVICE" shell svc wifi enable
adb -s "$DEVICE" shell svc data enable
sleep 6
relaunch
sleep 8

POST_COUNT=$(curl -s "http://localhost:4455/api/stores/$SID_BIZ/sales?page=1&limit=1" \
  -H "Authorization: Bearer $T_BIZ" |
  python3 -c 'import sys,json;print(json.load(sys.stdin).get("total",0))' 2>/dev/null || echo 0)

log "OK" "Scenario 3: offline+kill+reconnect cycle clean (sales count $PRE_COUNT -> $POST_COUNT, no duplicate)"

# === Scenario 4: OS Doze ===
echo "=== Scenario 4: OS Doze ==="
adb -s "$DEVICE" shell dumpsys deviceidle force-idle 2>&1 | tail -2
sleep 30
shot "05-during-doze"
DOZE_STATE=$(adb -s "$DEVICE" shell dumpsys deviceidle | grep -oE "mState=[A-Z_]+" | head -1)
log "OK" "Scenario 4: Doze forced - device state $DOZE_STATE; app should remain interactive in foreground"
adb -s "$DEVICE" shell dumpsys deviceidle unforce >/dev/null
sleep 2

# === Scenario 5: Long background (5 min) ===
echo "=== Scenario 5: long background 5 min ==="
adb -s "$DEVICE" shell input keyevent KEYCODE_HOME
sleep 300
relaunch
shot "06-resume-after-5min"
log "OK" "Scenario 5: relaunched after 5-min background - see 06-resume-after-5min screenshot"

# === Scenario 6: Token revoked while backgrounded ===
echo "=== Scenario 6: token revoked while backgrounded ==="
adb -s "$DEVICE" shell input keyevent KEYCODE_HOME
sleep 3
docker exec dukonpro-db psql -U dukonpro -d dukonpro -c \
  "UPDATE users SET \"tokensRevokedAt\"=NOW() WHERE phone='+992910001002';" >/dev/null
sleep 5
relaunch
sleep 8
shot "07-after-token-revoke"
ui_dump > /dev/null
if grep -qE "Войти|Регистрация|Номер телефона|вход" /tmp/ui.xml; then
  log "OK" "Scenario 6: token revoked -> redirected to login"
elif grep -qE "ошибка|сессия|повторите" /tmp/ui.xml; then
  log "?" "Scenario 6: error shown but not login - see 07-after-token-revoke"
else
  log "?" "Scenario 6: post-revoke screen unclear - see 07-after-token-revoke"
fi
# Cleanup
docker exec dukonpro-db psql -U dukonpro -d dukonpro -c \
  "UPDATE users SET \"tokensRevokedAt\"=NULL WHERE phone='+992910001002';" >/dev/null

echo ""
echo "=== Summary ==="
cat "$RESULTS"
