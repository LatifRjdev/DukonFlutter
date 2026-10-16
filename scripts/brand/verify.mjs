// Asserts the generated asset set. Exits non-zero on the first failure.
// Run after render.mjs and after flutter_launcher_icons.
import sharp from 'sharp';
import { existsSync } from 'node:fs';
import { resolve } from 'node:path';
import { SAFE_RADIUS, CANVAS } from './geometry.mjs';

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

if (failures.length) {
  console.error(`\n${failures.length} check(s) failed:\n`);
  for (const f of failures) console.error(`  ✗ ${f}`);
  process.exit(1);
}
console.log('✓ every brand asset check passed');
