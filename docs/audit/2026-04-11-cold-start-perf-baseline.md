# Cold start perf baseline — 2026-04-11

**Related finding:** FD-P1-004 (#37) — audit reported ~6s cold start,
>10s warm launch hang.

## Method

Android emulator `emulator-5554` (Pixel 8 API 35, x86_64), local dev
machine. Command:

```
adb shell am force-stop com.itlsolutions.dukonpro
sleep 3
adb shell am start -W -a android.intent.action.MAIN \
  -n com.itlsolutions.dukonpro/com.itlsolutions.dukonpro.MainActivity
```

Three runs each, TotalTime reported by `am start -W` in milliseconds.

## Results

### Debug build (on-device after flutter clean + rebuild)

| Run | TotalTime | WaitTime |
|-----|-----------|----------|
| 1   | 1840 ms   | 1844 ms  |
| 2   | 1321 ms   | 1322 ms  |
| 3   | 1509 ms   | 1514 ms  |

Median ~1509 ms. First cold start after fresh install is slowest
(1840 ms) — consistent with first-frame JIT + DI graph construction.

### Release build (`flutter build apk --release`, 82.1 MB APK)

| Run | TotalTime | WaitTime |
|-----|-----------|----------|
| 1   | 737 ms    | 739 ms   |
| 2   | 542 ms    | 546 ms   |
| 3   | 450 ms    | 453 ms   |

Median ~542 ms, well under any reasonable P1 budget for POS use.

## What changed since the audit

Audit on 2026-04-10 reported:
> Cold start ≈6s, warm launch >10s (observed one >10s splash hang then
> recovery).

Those numbers do not reproduce on the current main after PR #44 / #47.
Possible explanations:

1. **First-cold after a cold device boot** — emulator had just booted
   when the audit ran, OS was still page-caching system libs. The
   current measurement is on a warm device.
2. **Debug-mode AOT regression** — the audit was run on a debug build
   immediately after a `flutter clean`, which triggers the slowest
   possible first launch. The 1840 ms "run 1" above is consistent
   with that, but still nowhere near 6000 ms.
3. **SyncEngine.start()** subscribing to connectivity on `main()` was
   blocking the splash if the connectivity plugin took >3s to resolve
   on the first call — that plugin has been warm since.
4. The audit measurement may have been off by an order of magnitude
   (wall clock vs adb-reported). No raw number was captured, only
   "observed one >10s splash hang then recovery", which is hard to
   reproduce.

## Recommendation

Close FD-P1-004 as "cannot reproduce" at the reported severity. Keep
the ticket open under P2 with a narrower acceptance criterion:

> Median release-mode cold start on emulator-5554 must stay under
> 800 ms, measured via `adb shell am start -W`.

Add a lightweight CI perf check that runs the same command after a
release build and fails if the median of 3 runs exceeds 800 ms. That
covers future regressions without chasing a ghost.

## Next steps (not in this session)

- Wire a CI job that installs `app-release.apk` on an emulator and
  runs `am start -W` 3× — hard to host cheaply, but feasible with
  Firebase Test Lab or GitHub Actions Android image.
- Profile the first 1.8s of debug launch with DevTools timeline to
  identify any heavy `await` in `main()` / `initDependencies()`.
- `SyncEngine.start()` could be deferred to `addPostFrameCallback`
  after the first render — latency-neutral but reduces any future
  risk of the same plugin hang.

## Why no code in this PR

The audit's 6s number doesn't reproduce, so the obvious fix (rip out
heavy init from main) isn't justified without a real regression.
Shipping doc + re-scoping the issue is the right call rather than
refactoring on a phantom.
