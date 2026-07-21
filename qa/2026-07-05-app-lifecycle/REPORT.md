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
| 1 | OS process kill mid-sale | 1. Open POS → add 3 items to cart<br>2. Force-stop: `adb shell am force-stop com.itlsolutions.dukonpro`<br>3. Reopen app<br>4. Observe cart restore prompt | Cart restore prompt appears with 3 items. Accepting restores cart exactly. Declining clears cart cleanly. No crash. | **Pass.** Restore dialog "Восстановить корзину?" appeared on reopen with the exact copy "Найдена сохранённая корзина (только что, 3 товаров)." Tapping "Восстановить" restored the cart exactly: qty 3 of qa‑p‑start‑20979, subtotal/итого 3 TJS. No FATAL EXCEPTION / AndroidRuntime crash in logcat around the transition. ("Очистить" decline path was not separately exercised — only one restore cycle was run per scenario — see Notes.) |
| 2 | Doze mode (10-min background) | 1. Open POS → add 2 items to cart<br>2. Lock screen, wait 10 minutes<br>3. Unlock → foreground app | Session still valid (no auth prompt). Cart intact. No crash. | **Pass (simulated Doze, not a real 10‑min wait — see Notes).** Locked screen, then forced deep idle via `adb shell dumpsys deviceidle force-idle` (confirmed `IDLE` state), then `unforce` + unlock. Process pid was unchanged before/after (4723 → 4723), i.e. the OS never killed the process under simulated Doze, so this is really testing "process survives backgrounding," not an actual eviction. App resumed straight to the POS screen with cart intact (3 items, 3 TJS), no login/auth prompt, no crash in logcat. |
| 3 | Device sleep during active sale | 1. Open POS cart with items<br>2. Lock screen immediately<br>3. Unlock immediately (< 30 s) | App resumes without restart. Cart state unchanged. | **Pass.** `KEYCODE_POWER` to lock, ~3 s later `KEYCODE_POWER` + swipe to unlock. Process pid unchanged (4723), app resumed instantly to the same POS screen with cart unchanged (3 items, 3 TJS). No crash in logcat. |
| 4 | Low-memory process kill | 1. Enable "Don't keep activities" in Developer Options<br>2. Open POS → add items to cart<br>3. Press Home (background)<br>4. Reopen app | App restores to POS. Cart restore prompt shown with saved items. No corrupt state. | **Pass, with one deviation from the expected description.** `always_finish_activities=1` was set, but on this Android 16 emulator that setting alone did **not** finish/kill the activity on Home press (`dumpsys activity activities` still showed the task alive after several seconds). Used `adb shell am kill com.itlsolutions.dukonpro` after backgrounding to force an actual low-memory-style process kill (pid confirmed gone). On reopen, Android recreated the task and the app **landed on the Home tab ("Главная"), not directly on the POS tab** — this contradicts the "App restores to POS" wording in Expected, since bottom-nav tab selection is not part of what gets restored (only the cart itself persists). The cart-restore dialog then appeared correctly ("Найдена сохранённая корзина (6 мин назад, 3 товаров)"); accepting it restored the cart exactly once navigated back to Касса (3 items, 3 TJS). No corrupt state, no crash in logcat. |

---

## Pass criteria

All 4 scenarios must show no crash and correct cart state. Scenarios 1 and 4 must show the restore prompt.

---

## Notes

**Run date:** 2026-07-21 (actually executed — this report was previously a template with all four Results still "—").

**Device:** Android emulator `duckon` (AVD `sdk_gphone64_arm64`), Android 16, API level 36, "user" build (`google/sdk_gphone64_arm64/emu64a:16/BP41.250822.007/14042983:user/release-keys`). App under test: `com.itlsolutions.dukonpro`, versionName `1.0.0`, debug build.

**Result summary:** All 4 scenarios pass their stated criteria (no crash, correct/intact cart state). Scenario 4 has a documented deviation from the literal "Expected" wording (does not restore to the POS tab specifically). Scenario 2 was necessarily simulated, not a real 10‑minute wait.

**Environment/tooling gotcha (not a `lib/` bug, but nearly derailed this entire run — flagging for whoever runs this next):**
`build/app/outputs/flutter-apk/app-debug.apk` was, at the start of this session, an **integration-test harness build** (entrypoint `flutter_test_listener.dart`, confirmed via the Dart VM service `getIsolate` → `rootLib.uri`), not the normal `lib/main.dart` app. Installing and launching that APK produces a native splash screen that **never advances — indefinitely, with no crash, no ANR, and no error in logcat** — because the test-listener entrypoint sits waiting for an external test driver that's never attached when you just `adb shell am start` it normally. This is extremely easy to misdiagnose as an app-level hang (I initially spent a long time chasing it as a suspected `FirebaseMessaging.instance.getToken()` deadlock in `lib/main.dart`, including trying GMS force-stop, network/airplane-mode toggles, and a full emulator reboot — none of which "fixed" it, because the real cause was the wrong artifact, not app logic). The fix was `flutter build apk --debug -t lib/main.dart` to force the correct entrypoint (resulting APK ~197 MB vs. the ~161 MB test-harness build), then a clean reinstall. **If `build/app/outputs/flutter-apk/app-debug.apk` was produced by an `integration_test`/`flutter test integration_test/...`/`flutter drive` invocation anywhere earlier in the day (matches this task's own suggested fallback of running `functional_smoke_test.dart`), it will silently overwrite the normal debug APK at that same path** and any subsequent plain `adb install` + `am start` will hit this same false hang. Recommend: always verify the entrypoint (`getIsolate.rootLib.uri` via the VM service, or just check APK size) before spending time debugging an unresponsive splash screen, and/or build to a separate output path for integration tests.

**Other environment instability observed:** during the same session, another process on this machine independently rebuilt/reinstalled/uninstalled `com.itlsolutions.dukonpro` on this same emulator at least twice (APK mtime and app data changed without my involvement) — this emulator is evidently not exclusively owned by this QA run. Scenario execution below happened only after that interference had stopped; no interference was observed during the actual 4 scenario runs.

**Restore-prompt mechanics worth knowing for future runs:** `CartRestorePrompt` (`lib/presentation/pages/dashboard/cart_restore_prompt.dart`) is guarded by a static `_shown` bool that only resets on a fresh Dart isolate (i.e., a real process restart), and it's triggered from `home_page.dart`, not the POS page — so after any lifecycle event that kills the process, the dialog surfaces on whichever screen mounts `HomePage` first, and the app does not remember which bottom-nav tab (Главная/Товары/**Касса**/Финансы/Ещё) was active before the kill; it always comes back to Главная. That's the source of the scenario-4 deviation noted above — it is very likely also implicitly true of scenario 1, it just wasn't called out as a deviation there because scenario 1's Expected column doesn't mention which tab.

**Scenario 2 caveat:** true 10-minute Doze cannot be waited out in this environment. Used `adb shell dumpsys deviceidle force-idle` / `unforce` as instructed. This confirms the app doesn't crash or lose session/cart under simulated Doze, but does **not** prove behavior under a real Doze-triggered process eviction (which scenario 1/4's process-kill tests cover instead via a different mechanism). No separate low-memory-during-Doze combination was tested.

**No crashes or data-loss bugs found.** Across all 4 scenarios the cart survived exactly (correct item, correct quantity, correct total) with no corruption and no `FATAL EXCEPTION`/`AndroidRuntime` entries in logcat around any of the transitions. A real cashier's in-progress sale would not be lost by any of the four tested interruptions.
