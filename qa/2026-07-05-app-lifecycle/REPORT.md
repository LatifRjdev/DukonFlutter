# App Lifecycle QA — Cart Persistence Under System Pressure

**Date:** 2026-07-05  
**Spec:** Spec I — App Lifecycle Stress  
**Build:** `flutter build apk --debug` then `adb install build/app/outputs/flutter-apk/app-debug.apk`  
**Device:** Android emulator (API 34) or physical Android device  
**Prereq:** Enable developer options. For scenario 4: enable "Don't keep activities" in Developer Options.

---

## Scenarios

| # | Scenario | Steps | Expected | Result |
|---|---|---|---|---|
| 1 | OS process kill mid-sale | 1. Open POS → add 3 items to cart<br>2. Force-stop: `adb shell am force-stop com.dukonpro.app`<br>3. Reopen app<br>4. Observe cart restore prompt | Cart restore prompt appears with 3 items. Accepting restores cart exactly. Declining clears cart cleanly. No crash. | — |
| 2 | Doze mode (10-min background) | 1. Open POS → add 2 items to cart<br>2. Lock screen, wait 10 minutes<br>3. Unlock → foreground app | Session still valid (no auth prompt). Cart intact. No crash. | — |
| 3 | Device sleep during active sale | 1. Open POS cart with items<br>2. Lock screen immediately<br>3. Unlock immediately (< 30 s) | App resumes without restart. Cart state unchanged. | — |
| 4 | Low-memory process kill | 1. Enable "Don't keep activities" in Developer Options<br>2. Open POS → add items to cart<br>3. Press Home (background)<br>4. Reopen app | App restores to POS. Cart restore prompt shown with saved items. No corrupt state. | — |

---

## Pass criteria

All 4 scenarios must show no crash and correct cart state. Scenarios 1 and 4 must show the restore prompt.

---

## Notes

_Fill in after manual run. Include device model, Android API level, and any deviations from expected._
