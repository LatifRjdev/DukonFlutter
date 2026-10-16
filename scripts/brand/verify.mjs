// Asserts the generated asset set. Exits non-zero on the first failure.
// Run after render.mjs and after flutter_launcher_icons.
import sharp from 'sharp';
import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { SAFE_RADIUS, CANVAS, iconSvg } from './geometry.mjs';

const ROOT = resolve(import.meta.dirname, '../..');
const p = (rel) => resolve(ROOT, rel);

const failures = [];
const fail = (msg) => failures.push(msg);

/** Mean hue/saturation of the opaque pixels, via sharp's channel stats. */
async function meanHsl(file) {
  const { channels } = await sharp(file).flatten({ background: '#808080' }).stats();
  const [r, g, b] = channels.slice(0, 3).map((c) => c.mean / 255);
  const max = Math.max(r, g, b);
  const min = Math.min(r, g, b);
  const l = (max + min) / 2;
  const d = max - min;
  if (d === 0) return { hue: 0, sat: 0, light: l };
  const sat = d / (1 - Math.abs(2 * l - 1));
  let hue;
  if (max === r) hue = ((g - b) / d) % 6;
  else if (max === g) hue = (b - r) / d + 2;
  else hue = (r - g) / d + 4;
  hue = (hue * 60 + 360) % 360;
  return { hue, sat, light: l };
}

async function expectBrandColoured(rel) {
  const file = p(rel);
  if (!existsSync(file)) return fail(`missing: ${rel}`);
  const { hue, sat } = await meanHsl(file);
  // Measured, not guessed: our plate reads hue 249 / sat 0.75, and the Flutter
  // logo this replaces reads hue 200 / sat 0.78. Hue is what separates them —
  // 200 sits 25 degrees below the lower bound. Saturation does NOT discriminate
  // between the two; it is here only to catch a blank or greyscale render.
  if (hue < 225 || hue > 275) {
    fail(`${rel}: mean hue ${hue.toFixed(0)}° is outside the brand range 225-275°. ` +
         `Hue 200 means this is still Flutter's default logo — the asset was not regenerated.`);
  }
  if (sat < 0.15) {
    fail(`${rel}: mean saturation ${sat.toFixed(2)} is too low; expected a coloured plate`);
  }
}

/** Byte-identical to iconSvg() — catches a hand-copied file going stale after
 * geometry.mjs changes, not just a missing one. */
function expectMatchesIcon(rel) {
  const file = p(rel);
  if (!existsSync(file)) return fail(`missing: ${rel}`);
  const actual = readFileSync(file, 'utf8');
  const expected = iconSvg();
  if (actual !== expected) {
    fail(`${rel}: stale — does not match geometry.mjs's iconSvg(). Re-run \`npm run render\`.`);
  }
}

async function expectSize(rel, w, h) {
  const file = p(rel);
  if (!existsSync(file)) return fail(`missing: ${rel}`);
  const m = await sharp(file).metadata();
  if (m.width !== w || m.height !== h) {
    fail(`${rel}: expected ${w}x${h}, got ${m.width}x${m.height}`);
  }
}

async function expectAlpha(rel, wanted) {
  const file = p(rel);
  if (!existsSync(file)) return fail(`missing: ${rel}`);
  const m = await sharp(file).metadata();
  if (!!m.hasAlpha !== wanted) {
    fail(`${rel}: expected hasAlpha=${wanted}, got ${!!m.hasAlpha}`);
  }
}

/** Every opaque pixel of the foreground must sit inside the safe circle. */
async function expectWithinSafeZone(rel) {
  const file = p(rel);
  if (!existsSync(file)) return fail(`missing: ${rel}`);
  const { data, info } = await sharp(file)
    .ensureAlpha()
    .raw()
    .toBuffer({ resolveWithObject: true });
  const cx = info.width / 2;
  const cy = info.height / 2;
  const limit = (SAFE_RADIUS / (CANVAS / 2)) * (info.width / 2);
  let worst = 0;
  for (let y = 0; y < info.height; y++) {
    for (let x = 0; x < info.width; x++) {
      const a = data[(y * info.width + x) * info.channels + info.channels - 1];
      if (a < 8) continue;
      const r = Math.hypot(x + 0.5 - cx, y + 0.5 - cy);
      if (r > worst) worst = r;
    }
  }
  if (worst > limit) {
    fail(`${rel}: mark reaches ${worst.toFixed(0)}px, outside the safe radius ${limit.toFixed(0)}px. ` +
         `Note this check is only meaningful with adaptive_icon_foreground_inset: 0.`);
  }
}

await expectSize('app/assets/icon/icon.png', 1024, 1024);
await expectBrandColoured('app/assets/icon/icon.png');

await expectSize('app/assets/icon/adaptive_bg.png', 1024, 1024);
await expectBrandColoured('app/assets/icon/adaptive_bg.png');

await expectSize('app/assets/icon/adaptive_fg.png', 1024, 1024);
await expectAlpha('app/assets/icon/adaptive_fg.png', true);
await expectWithinSafeZone('app/assets/icon/adaptive_fg.png');

await expectSize('app/assets/icon/monochrome.png', 1024, 1024);
await expectAlpha('app/assets/icon/monochrome.png', true);

await expectSize('app/assets/icon/ios_dark.png', 1024, 1024);
await expectAlpha('app/assets/icon/ios_dark.png', true);

await expectSize('app/assets/icon/ios_tinted.png', 1024, 1024);

for (const rel of [
  'app/assets/brand/icon.svg',
  'app/assets/brand/mark.svg',
  'app/assets/brand/mark-mono.svg',
  'app/assets/brand/lockup-light.svg',
  'app/assets/brand/lockup-dark.svg',
]) {
  if (!existsSync(p(rel))) fail(`missing: ${rel}`);
}

// admin/app/icon.svg (Next.js App Router favicon convention) and
// admin/public/brand-icon.svg (what Sidebar renders) are both the app icon,
// written by render.mjs — not hand-copied. Checked byte-for-byte against
// iconSvg() so a `npm run render` that nobody re-ran after a geometry change
// is caught as stale, not just as missing.
expectMatchesIcon('admin/app/icon.svg');
expectMatchesIcon('admin/public/brand-icon.svg');

// --- shipped platform outputs ------------------------------------------------
// Everything above only checks the pipeline's *inputs* (app/assets/icon,
// app/assets/brand). Those feed flutter_launcher_icons / flutter_native_splash,
// which copy derived art into the platform trees below — and it is only the
// platform trees that actually ship in the built app and the store listings.
// A whole-branch review found Flutter's default logo still live in exactly the
// files this section checks, missed by every per-task review because nothing
// asserted over outputs. Keep this section in sync with whatever
// flutter_launcher_icons / flutter_native_splash / fastlane actually produce.

await expectSize('app/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png', 192, 192);
await expectBrandColoured('app/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png');

await expectSize('app/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png', 1024, 1024);
await expectBrandColoured('app/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png');

await expectSize('app/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png', 1024, 1024);
await expectBrandColoured('app/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png');

await expectSize('app/web/icons/Icon-512.png', 512, 512);
await expectBrandColoured('app/web/icons/Icon-512.png');

// Splash screens: flutter_native_splash layers a solid-colour `background.png`
// under the (deliberately transparent-ground) mark image `splash.png` /
// `android12splash.png` — see drawable*/launch_background.xml. So the colour
// check belongs on background.png, not on the mark layer: expectBrandColoured
// against a mostly-transparent mark-on-transparency image would read near-zero
// saturation and fail even when everything is correct. The mark layer is
// checked instead for the two ways it actually regressed: (1) a stray
// flutter_native_splash `image:` pointing back at the opaque plated icon,
// which would make the "mark" layer fully opaque again (expectAlpha), and
// (2) the mark drifting outside the safe zone Android crops to
// (expectWithinSafeZone, reusing the same check adaptive_fg.png gets).
// xxhdpi stands in for the whole density set, which render.mjs/
// flutter_native_splash regenerate together.
await expectBrandColoured('app/android/app/src/main/res/drawable/background.png');
await expectBrandColoured('app/android/app/src/main/res/drawable-night/background.png');

await expectAlpha('app/android/app/src/main/res/drawable-xxhdpi/splash.png', true);
await expectWithinSafeZone('app/android/app/src/main/res/drawable-xxhdpi/splash.png');
await expectAlpha('app/android/app/src/main/res/drawable-xxhdpi/android12splash.png', true);
await expectWithinSafeZone('app/android/app/src/main/res/drawable-xxhdpi/android12splash.png');

// iOS launch screen: same layered split as Android (LaunchBackground carries
// colour, LaunchImage is the transparent mark) — this was one of the two
// files the whole-branch review actually caught showing Flutter's logo, so
// it gets the same three-part check as its Android counterpart.
await expectBrandColoured('app/ios/Runner/Assets.xcassets/LaunchBackground.imageset/background.png');
await expectBrandColoured('app/ios/Runner/Assets.xcassets/LaunchBackground.imageset/darkbackground.png');
await expectAlpha('app/ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@3x.png', true);
await expectWithinSafeZone('app/ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@3x.png');

// Store listing icons — Google Play requires an opaque PNG at 512x512, the App
// Store rejects alpha in its 1024x1024. Both are generated by render.mjs, not
// hand-copied.
await expectSize('app/android/fastlane/metadata/android/ru-RU/images/icon.png', 512, 512);
await expectAlpha('app/android/fastlane/metadata/android/ru-RU/images/icon.png', false);
await expectBrandColoured('app/android/fastlane/metadata/android/ru-RU/images/icon.png');

await expectSize('app/ios/fastlane/metadata/ru-RU/icon.png', 1024, 1024);
await expectAlpha('app/ios/fastlane/metadata/ru-RU/icon.png', false);
await expectBrandColoured('app/ios/fastlane/metadata/ru-RU/icon.png');

if (failures.length) {
  console.error(`\n${failures.length} check(s) failed:\n`);
  for (const f of failures) console.error(`  ✗ ${f}`);
  process.exit(1);
}
console.log('✓ every brand asset check passed');
