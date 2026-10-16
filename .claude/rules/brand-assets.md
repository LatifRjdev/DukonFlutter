---
description: How to change the DukonPro brand mark and app icon
globs: "scripts/brand/**/*.mjs,app/assets/icon/**,app/assets/brand/**,app/flutter_launcher_icons.yaml,app/flutter_native_splash.yaml"
---

# Brand Assets

- Single source of truth is `scripts/brand/geometry.mjs` — canvas size,
  plate radius, safe-zone radius, mark scale, gradient stops, the arch path,
  the three bars. Change the mark by editing values there, never anywhere
  downstream.
- `scripts/brand/render.mjs` derives every asset from `geometry.mjs`:
  the SVGs in `app/assets/brand/`, the PNG inputs in `app/assets/icon/`,
  the admin panel's `admin/app/icon.svg` / `admin/public/brand-icon.svg`,
  and the fastlane store-listing icons. It is the only thing that writes
  any of them.
- After any change, run this exact sequence:
  ```
  cd scripts/brand && npm test && npm run render && npm run verify
  cd ../../app && dart run flutter_launcher_icons && dart run flutter_native_splash:create
  cd ../scripts/brand && npm run verify
  ```
  `flutter_launcher_icons` and `flutter_native_splash` fan the rendered PNGs
  out into the platform trees (Android mipmaps, iOS `Assets.xcassets`,
  macOS, web); the second `npm run verify` is what actually guards those
  shipped outputs, not just the pipeline's inputs.
- **Every PNG under `app/assets/icon/`, every generated file under the
  Android/iOS/macOS/web platform trees, and the fastlane store-listing
  icons are generated artefacts.** Never hand-edit or hand-copy one —
  including "just this once" fixes to a single icon size. If an asset
  looks wrong, fix `geometry.mjs` and re-render.
- `scripts/brand/npm run verify` checks the pipeline end to end: PNG sizes
  and alpha channels are correct, the mark's opaque pixels stay inside
  Android's safe-crop radius, colours read as the brand's hue (not
  Flutter's default blue), and the shipped platform outputs — not just the
  pipeline's inputs — actually carry the regenerated art. Run it after the
  `flutter_launcher_icons`/`flutter_native_splash` step above, since that is
  what populates the platform trees it checks.
- **Trap:** `adaptive_icon_foreground_inset` in `app/flutter_launcher_icons.yaml`
  must stay `0`. The package default is 16 (`android:inset="16%"` on both
  foreground and monochrome), and the mark already carries `scale(0.89)` for
  its own safe-zone margin. The two compound multiplicatively (a 16% inset on
  each side shrinks the drawable to 0.68× before the mark's own 0.89× is even
  applied: 0.68 × 0.89 ≈ 0.605), so leaving the default in place ships the
  icon at roughly 60% size next to every other app on the launcher.
