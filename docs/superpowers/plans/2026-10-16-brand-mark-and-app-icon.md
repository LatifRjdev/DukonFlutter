# Brand Mark and App Icon Set — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Flutter's default logo — currently shipping as DukonPro's app icon on every platform — with the agreed brand mark, generated reproducibly from one canonical SVG.

**Architecture:** One geometry module holds the canonical paths and numbers. Every asset — SVG sources, PNG inputs, lockups — is derived from it by scripts; no PNG is ever hand-edited. A verifier script asserts the result, and is written *before* the generator so it starts red against the current Flutter-logo state. `flutter_launcher_icons` then fans the PNG inputs out to each platform.

**Tech Stack:** Node 25 ESM, `sharp` (SVG→PNG), `fontkit` (wordmark→outlines), `node:test`, `flutter_launcher_icons` 0.14.4.

**Spec:** [`docs/superpowers/specs/2026-10-16-brand-mark-and-app-icon-design.md`](../specs/2026-10-16-brand-mark-and-app-icon-design.md)

---

## Tooling facts — verified, do not re-litigate

These were each established by running them against the real font and the real renderer. Re-deriving them costs an hour.

| Fact | Consequence |
|---|---|
| `sharp` renders SVG with gradients, `fill-rule="evenodd"` and nested transforms correctly | It is the rasteriser. No ImageMagick / librsvg / Inkscape / cairosvg exists on this machine. |
| **`opentype.js` emits `NaN` coordinates for this font** | Do **not** use it. Individual glyphs are clean, but accumulating them yields `NaN` in `x`; librsvg then silently stops drawing mid-word. It also crashes outright on this font's GSUB table (`lookupType 6, substFormat 2`) if you call `getPath` on a string. |
| `fontkit` outlines the same font cleanly | It is the outliner. Use `font.layout()` and take advances from `run.positions[i].xAdvance` so kerning is applied. |
| fontkit paths are y-up; SVG is y-down | Every glyph path needs `.scale(k, -k)`. |
| `adaptive_icon_foreground_inset` defaults to **16** | Must be set to `0`. See spec — otherwise it multiplies with our `scale(0.89)` and the icon ships visibly small. |
| `adaptive_icon_round` is not a key in 0.14.4 | Delete the line; it has never done anything. |
| `Plus Jakarta Sans` has `unitsPerEm: 1000`, `capHeight: 745` | Used for lockup baseline maths. |

---

## File Structure

| File | Responsibility |
|---|---|
| `scripts/brand/package.json` | pins `sharp` + `fontkit`; isolates this toolchain from `admin/` |
| `scripts/brand/geometry.mjs` | **single source of truth** — canonical paths, numbers, SVG builders |
| `scripts/brand/geometry.test.mjs` | asserts the geometric invariants (safe zone, centring, bar step) |
| `scripts/brand/wordmark.mjs` | turns `DukonPro` into outline path data via fontkit |
| `scripts/brand/render.mjs` | writes every SVG source and PNG input |
| `scripts/brand/verify.mjs` | asserts the generated asset set; the regression guard |
| `scripts/brand/contact-sheet.mjs` | one PNG for eyeballing; not committed |
| `app/assets/brand/*.svg` | generated SVG sources, committed |
| `app/assets/icon/*.png` | generated PNG inputs for `flutter_launcher_icons`, committed |
| `app/flutter_launcher_icons.yaml` | modified |
| `admin/app/icon.svg`, `admin/public/lockup.svg` | admin panel assets |

`node_modules/` is already covered by `.gitignore` (lines 2–3). Generated PNGs **are** tracked — they are build inputs, not byproducts.

---

### Task 1: Scaffold the toolchain and the geometry module

**Files:**
- Create: `scripts/brand/package.json`
- Create: `scripts/brand/geometry.mjs`
- Test: `scripts/brand/geometry.test.mjs`

- [ ] **Step 1: Create the package manifest**

`scripts/brand/package.json`:

```json
{
  "name": "dukonpro-brand",
  "private": true,
  "type": "module",
  "description": "Generates the DukonPro brand mark and every icon asset from one canonical geometry.",
  "scripts": {
    "test": "node --test",
    "render": "node render.mjs",
    "verify": "node verify.mjs",
    "sheet": "node contact-sheet.mjs"
  },
  "dependencies": {
    "sharp": "^0.34.5",
    "fontkit": "^2.0.4"
  }
}
```

- [ ] **Step 2: Install dependencies**

Run: `cd scripts/brand && npm install`
Expected: `added N packages`, and `scripts/brand/node_modules/` now exists. No `package-lock.json` conflict — this directory has no prior lockfile.

- [ ] **Step 3: Write the failing test**

`scripts/brand/geometry.test.mjs`:

```js
import test from 'node:test';
import assert from 'node:assert/strict';
import {
  CANVAS, CENTRE, SAFE_RADIUS,
  ARCH_BOUNDS, BARS_META, scaledCornerRadius, barGroupBounds,
} from './geometry.mjs';

test('scaled arch corners sit inside the Android safe circle', () => {
  assert.ok(
    scaledCornerRadius() <= SAFE_RADIUS,
    `corner at ${scaledCornerRadius().toFixed(1)} exceeds safe radius ${SAFE_RADIUS}`,
  );
});

test('the mark is not wastefully smaller than the safe circle allows', () => {
  // Guards the opposite failure: someone "fixes" clipping by over-shrinking.
  assert.ok(
    scaledCornerRadius() > SAFE_RADIUS * 0.9,
    `mark only reaches ${scaledCornerRadius().toFixed(1)} of ${SAFE_RADIUS}; it is too small`,
  );
});

test('the bar group is centred on the canvas centre', () => {
  const { left, right } = barGroupBounds();
  assert.equal((left + right) / 2, CENTRE);
});

test('bars ascend by a constant step', () => {
  const heights = BARS_META.map((b) => b.baseline - b.top);
  const steps = heights.slice(1).map((h, i) => h - heights[i]);
  assert.deepEqual(steps, [42, 42]);
});

test('bars share one baseline', () => {
  const baselines = new Set(BARS_META.map((b) => b.baseline));
  assert.equal(baselines.size, 1);
});

test('bars stay clear of the arch walls', () => {
  const { left, right } = barGroupBounds();
  const WALL = 40; // minimum white between a bar and the arch edge
  assert.ok(left - ARCH_BOUNDS.x1 >= WALL, 'left bar too close to the arch wall');
  assert.ok(ARCH_BOUNDS.x2 - right >= WALL, 'right bar too close to the arch wall');
});

test('the canvas is square and the centre is its midpoint', () => {
  assert.equal(CENTRE, CANVAS / 2);
});
```

- [ ] **Step 4: Run the test to verify it fails**

Run: `cd scripts/brand && npm test`
Expected: FAIL — `Cannot find module './geometry.mjs'`

- [ ] **Step 5: Write the geometry module**

`scripts/brand/geometry.mjs`:

```js
// Canonical geometry for the DukonPro mark. Everything else derives from this.
// Three ascending bars cut out of a solid pointed arch.
// Spec: docs/superpowers/specs/2026-10-16-brand-mark-and-app-icon-design.md

export const CANVAS = 512;
export const CENTRE = CANVAS / 2;
export const PLATE_RADIUS = 114;          // 22.3% squircle, per Apple HIG

// Android guarantees only the central 66% of an adaptive icon survives masking.
export const SAFE_RADIUS = 169;
// Unscaled, the arch corners sit 187 units out. 187 * 0.89 = 166.4, inside 169.
export const MARK_SCALE = 0.89;

export const GRADIENT = [
  { offset: '0%', color: '#6366F1' },
  { offset: '55%', color: '#7C6AF0' },
  { offset: '100%', color: '#8B5CF6' },
];

export const ARCH = 'M132 396V254C132 176 184 132 256 112C328 132 380 176 380 254V396Z';
export const ARCH_BOUNDS = { x1: 132, y1: 112, x2: 380, y2: 396 };

// width 34, gap 16, one baseline at 360, tops stepping by 42
export const BARS_META = [
  { left: 189, width: 34, top: 300, baseline: 360 },
  { left: 239, width: 34, top: 258, baseline: 360 },
  { left: 289, width: 34, top: 216, baseline: 360 },
];

export const BARS = BARS_META.map(
  (b) => `M${b.left} ${b.baseline}V${b.top}H${b.left + b.width}V${b.baseline}Z`,
);

export const MARK_PATH = [ARCH, ...BARS].join(' ');

/** Distance from canvas centre to the arch's bottom corner, after MARK_SCALE. */
export function scaledCornerRadius() {
  const dx = CENTRE - ARCH_BOUNDS.x1;
  const dy = ARCH_BOUNDS.y2 - CENTRE;
  return Math.hypot(dx, dy) * MARK_SCALE;
}

export function barGroupBounds() {
  const first = BARS_META[0];
  const last = BARS_META[BARS_META.length - 1];
  return { left: first.left, right: last.left + last.width };
}

const stops = () =>
  GRADIENT.map((s) => `<stop offset="${s.offset}" stop-color="${s.color}"/>`).join('');

export const gradientDef = (id) =>
  `<linearGradient id="${id}" x1="0" y1="0" x2="1" y2="1">${stops()}</linearGradient>`;

const scaled = (inner) =>
  `<g transform="translate(${CENTRE},${CENTRE}) scale(${MARK_SCALE}) translate(-${CENTRE},-${CENTRE})">${inner}</g>`;

const open = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${CANVAS} ${CANVAS}" width="${CANVAS}" height="${CANVAS}">`;

/** The mark alone on a transparent ground. */
export function markSvg(fill = '#FFFFFF') {
  return `${open}${scaled(`<path fill="${fill}" fill-rule="evenodd" d="${MARK_PATH}"/>`)}</svg>`;
}

/** The gradient plate with no mark. */
export function plateSvg() {
  return `${open}<defs>${gradientDef('b')}</defs>` +
    `<rect width="${CANVAS}" height="${CANVAS}" rx="${PLATE_RADIUS}" fill="url(#b)"/></svg>`;
}

/** Plate plus mark — the app icon. */
export function iconSvg() {
  return `${open}<defs>${gradientDef('b')}</defs>` +
    `<rect width="${CANVAS}" height="${CANVAS}" rx="${PLATE_RADIUS}" fill="url(#b)"/>` +
    `${scaled(`<path fill="#FFFFFF" fill-rule="evenodd" d="${MARK_PATH}"/>`)}</svg>`;
}
```

- [ ] **Step 6: Run the test to verify it passes**

Run: `cd scripts/brand && npm test`
Expected: PASS — `# pass 7`, `# fail 0`

- [ ] **Step 7: Commit**

```bash
git add scripts/brand/package.json scripts/brand/geometry.mjs scripts/brand/geometry.test.mjs
git commit -m "feat(brand): canonical mark geometry with invariant tests"
```

---

### Task 2: Write the verifier, and watch it fail on the current state

The verifier exists before the generator on purpose. Right now the repo ships Flutter's logo, so a correct verifier must reject it. That red run is the proof the guard works.

**Files:**
- Create: `scripts/brand/verify.mjs`

- [ ] **Step 1: Write the verifier**

`scripts/brand/verify.mjs`:

```js
// Asserts the generated asset set. Exits non-zero on the first failure.
// Run after render.mjs and after flutter_launcher_icons.
import sharp from 'sharp';
import { existsSync } from 'node:fs';
import { resolve, relative } from 'node:path';
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
  // Our plate lives at hue 235-260 (indigo to violet).
  // Flutter's own logo is a light blue around hue 200 with near-zero mean saturation.
  if (hue < 225 || hue > 275) {
    fail(`${rel}: mean hue ${hue.toFixed(0)}° is outside the brand range 225-275°. ` +
         `This is what Flutter's default logo looks like — the asset was not regenerated.`);
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
```

- [ ] **Step 2: Run the verifier and confirm it rejects the current state**

Run: `cd scripts/brand && npm run verify`
Expected: FAIL, exit code 1. The current `app/assets/icon/icon.png` is Flutter's logo at 1024×1024, so expect at minimum:
- `app/assets/icon/icon.png: mean hue ...° is outside the brand range 225-275°`
- `missing: app/assets/icon/adaptive_bg.png` and the other not-yet-generated files

If the hue check does *not* fire on the Flutter logo, the guard is useless — stop and fix the thresholds before continuing.

- [ ] **Step 3: Commit**

```bash
git add scripts/brand/verify.mjs
git commit -m "test(brand): verifier that rejects the shipped Flutter logo"
```

---

### Task 3: Outline the wordmark with fontkit

**Files:**
- Create: `scripts/brand/wordmark.mjs`
- Test: `scripts/brand/wordmark.test.mjs`

- [ ] **Step 1: Write the failing test**

`scripts/brand/wordmark.test.mjs`:

```js
import test from 'node:test';
import assert from 'node:assert/strict';
import { outline, CAP_RATIO } from './wordmark.mjs';

test('outlines contain no NaN', () => {
  // opentype.js fails exactly here on this font; fontkit does not.
  const { d } = outline('DukonPro', 40, -0.03);
  assert.ok(!d.includes('NaN'), 'path data contains NaN');
});

test('produces real path data', () => {
  const { d } = outline('DukonPro', 40, -0.03);
  assert.ok(d.startsWith('M'), 'path data should start with a moveto');
  assert.ok(d.length > 1000, `path data suspiciously short: ${d.length} chars`);
});

test('width scales linearly with size', () => {
  const a = outline('DukonPro', 40, 0).width;
  const b = outline('DukonPro', 80, 0).width;
  assert.ok(Math.abs(b - a * 2) < 0.01, `expected ${a * 2}, got ${b}`);
});

test('negative tracking narrows the wordmark', () => {
  const loose = outline('DukonPro', 40, 0).width;
  const tight = outline('DukonPro', 40, -0.03).width;
  assert.ok(tight < loose, 'tracking had no effect');
});

test('cap ratio matches the font metrics', () => {
  assert.ok(Math.abs(CAP_RATIO - 0.745) < 0.001, `got ${CAP_RATIO}`);
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd scripts/brand && npm test`
Expected: FAIL — `Cannot find module './wordmark.mjs'`

- [ ] **Step 3: Write the wordmark module**

`scripts/brand/wordmark.mjs`:

```js
// Converts the DukonPro wordmark to outline paths.
//
// fontkit, NOT opentype.js. opentype.js emits NaN x-coordinates when glyph
// paths from this font are accumulated, and librsvg then stops drawing
// mid-word with no error. It also throws outright on this font's GSUB table.
import * as fontkit from 'fontkit';
import { resolve } from 'node:path';

const FONT = resolve(
  import.meta.dirname,
  '../../app/assets/fonts/PlusJakartaSans-ExtraBold.ttf',
);

const font = fontkit.openSync(FONT);
const UPM = font.unitsPerEm;

export const CAP_RATIO = font.capHeight / UPM;

/**
 * @param {string} text
 * @param {number} size      em size in SVG user units
 * @param {number} tracking  letter-spacing as a fraction of the em
 * @returns {{ d: string, width: number }}
 */
export function outline(text, size, tracking = 0) {
  const run = font.layout(text);
  const k = size / UPM;
  let x = 0;
  let d = '';
  run.glyphs.forEach((glyph, i) => {
    const pos = run.positions[i];
    // fontkit is y-up, SVG is y-down — hence scale(k, -k).
    d += glyph.path.translate(x + (pos.xOffset || 0), 0).scale(k, -k).toSVG() + ' ';
    x += pos.xAdvance + tracking * UPM;
  });
  return { d: d.trim(), width: (x - tracking * UPM) * k };
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd scripts/brand && npm test`
Expected: PASS — all geometry tests plus `# pass 12`, `# fail 0`

- [ ] **Step 5: Commit**

```bash
git add scripts/brand/wordmark.mjs scripts/brand/wordmark.test.mjs
git commit -m "feat(brand): outline the wordmark with fontkit"
```

---

### Task 4: Generate every SVG source and PNG input

**Files:**
- Create: `scripts/brand/render.mjs`
- Creates at runtime: `app/assets/brand/*.svg`, `app/assets/icon/*.png`

- [ ] **Step 1: Write the renderer**

`scripts/brand/render.mjs`:

```js
// Writes every brand asset from the canonical geometry. Run after any change
// to geometry.mjs. Never hand-edit the files this produces.
import sharp from 'sharp';
import { mkdirSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
import {
  CANVAS, CENTRE, PLATE_RADIUS, MARK_SCALE, MARK_PATH,
  gradientDef, markSvg, plateSvg, iconSvg,
} from './geometry.mjs';
import { outline, CAP_RATIO } from './wordmark.mjs';

const ROOT = resolve(import.meta.dirname, '../..');
const BRAND = resolve(ROOT, 'app/assets/brand');
const ICON = resolve(ROOT, 'app/assets/icon');
mkdirSync(BRAND, { recursive: true });
mkdirSync(ICON, { recursive: true });

// density 144 renders the 512-unit viewBox at 1024px before any resize
const png = (svg, size = 1024) =>
  sharp(Buffer.from(svg), { density: 144 }).resize(size, size).png();

// ---- lockup -------------------------------------------------------------
// Verified metrics: icon 56, type 40, tracking -0.03, gap 16, padding 4.
const L = { icon: 56, size: 40, track: -0.03, gap: 16, pad: 4 };

function lockupSvg(bg, duk, pro) {
  const a = outline('Dukon', L.size, L.track);
  const b = outline('Pro', L.size, L.track);
  const capH = CAP_RATIO * L.size;
  const baseY = L.pad + L.icon / 2 + capH / 2;
  const w = Math.ceil(L.pad * 2 + L.icon + L.gap + a.width + b.width);
  const h = L.icon + L.pad * 2;
  const plate =
    `<rect width="${CANVAS}" height="${CANVAS}" rx="${PLATE_RADIUS}" fill="url(#b)"/>` +
    `<g transform="translate(${CENTRE},${CENTRE}) scale(${MARK_SCALE}) translate(-${CENTRE},-${CENTRE})">` +
    `<path fill="#FFFFFF" fill-rule="evenodd" d="${MARK_PATH}"/></g>`;
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">` +
    `<defs>${gradientDef('b')}</defs>` +
    (bg ? `<rect width="${w}" height="${h}" fill="${bg}"/>` : '') +
    `<g transform="translate(${L.pad},${L.pad}) scale(${L.icon / CANVAS})">${plate}</g>` +
    `<g transform="translate(${L.pad + L.icon + L.gap},${baseY})">` +
    `<path fill="${duk}" d="${a.d}"/>` +
    `<g transform="translate(${a.width},0)"><path fill="${pro}" d="${b.d}"/></g>` +
    `</g></svg>`;
}

// ---- SVG sources --------------------------------------------------------
const sources = {
  'icon.svg': iconSvg(),
  'mark.svg': markSvg('#FFFFFF'),
  'mark-mono.svg': markSvg('#000000'),
  'lockup-light.svg': lockupSvg('#FFFFFF', '#1E1B4B', '#7C6AF0'),
  'lockup-dark.svg': lockupSvg('#0F0A1A', '#F0ECF8', '#A78BFA'),
};
for (const [name, svg] of Object.entries(sources)) {
  if (svg.includes('NaN')) throw new Error(`${name} contains NaN — refusing to write`);
  writeFileSync(resolve(BRAND, name), svg);
  console.log(`svg   ${name}`);
}

// ---- PNG inputs for flutter_launcher_icons ------------------------------
await png(iconSvg()).toFile(resolve(ICON, 'icon.png'));
await png(plateSvg()).toFile(resolve(ICON, 'adaptive_bg.png'));
await png(markSvg('#FFFFFF')).toFile(resolve(ICON, 'adaptive_fg.png'));
await png(markSvg('#FFFFFF')).toFile(resolve(ICON, 'monochrome.png'));
await png(markSvg('#FFFFFF')).toFile(resolve(ICON, 'ios_dark.png'));
await png(iconSvg()).greyscale().toFile(resolve(ICON, 'ios_tinted.png'));
console.log('png   icon, adaptive_bg, adaptive_fg, monochrome, ios_dark, ios_tinted');
```

- [ ] **Step 2: Run the renderer**

Run: `cd scripts/brand && npm run render`
Expected: five `svg` lines then one `png` line, no errors.

- [ ] **Step 3: Run the verifier — the SVG and PNG checks should now pass**

Run: `cd scripts/brand && npm run verify`
Expected: PASS — `✓ every brand asset check passed`

If `expectWithinSafeZone` fails, the mark is wider than `MARK_SCALE` allows; fix `MARK_SCALE` in `geometry.mjs` and re-run Task 1's tests before continuing.

- [ ] **Step 4: Look at the result before committing**

Run: `cd scripts/brand && node -e "import('sharp').then(async({default:s})=>{const m=await s('../../app/assets/icon/icon.png').metadata();console.log(m.width+'x'+m.height,m.format)})"`
Expected: `1024x1024 png`

Then open `app/assets/brand/lockup-light.svg` and `app/assets/icon/icon.png` and confirm by eye: a pointed arch with three ascending bars, wordmark reading `DukonPro` in full with `Pro` in violet. **If the wordmark is cut short, the outliner regressed to opentype.js — check Task 3.**

- [ ] **Step 5: Commit**

```bash
git add scripts/brand/render.mjs app/assets/brand app/assets/icon
git commit -m "feat(brand): generate mark, lockups and launcher icon inputs"
```

---

### Task 5: Fix the launcher config and fan the icons out

**Files:**
- Modify: `app/flutter_launcher_icons.yaml` (whole file replaced)

- [ ] **Step 1: Replace the config**

`app/flutter_launcher_icons.yaml`:

```yaml
flutter_launcher_icons:
  image_path: "assets/icon/icon.png"
  min_sdk_android: 21

  android: "ic_launcher"
  adaptive_icon_background: "assets/icon/adaptive_bg.png"
  adaptive_icon_foreground: "assets/icon/adaptive_fg.png"
  adaptive_icon_monochrome: "assets/icon/monochrome.png"
  # Must stay 0. The package default is 16 and lands in the adaptive XML as
  # android:inset="16%" on both foreground and monochrome. Our mark already
  # carries scale(0.89) for the safe zone; the two would multiply to 0.605 and
  # the icon would ship visibly smaller than its neighbours.
  adaptive_icon_foreground_inset: 0

  ios: true
  remove_alpha_ios: true
  image_path_ios_dark_transparent: "assets/icon/ios_dark.png"
  image_path_ios_tinted_grayscale: "assets/icon/ios_tinted.png"

  web:
    generate: true
    image_path: "assets/icon/icon.png"
    background_color: "#6366F1"
    theme_color: "#6366F1"

  macos:
    generate: true
    image_path: "assets/icon/icon.png"
```

Note what left: `adaptive_icon_round: true`. It is not a key in 0.14.4 — the parser has no such `@JsonKey`, so it never did anything.

- [ ] **Step 2: Generate the platform icons**

Run: `cd app && dart run flutter_launcher_icons`
Expected: output ending in `✓ Successfully generated launcher icons`, with lines for Android, iOS, web and macOS.

- [ ] **Step 3: Confirm the adaptive XML carries a zero inset**

Run: `grep -r "inset" app/android/app/src/main/res/mipmap-anydpi-v26/`
Expected: `android:inset="0%"` on both the `<foreground>` and `<monochrome>` drawables. If it reads `16%`, step 1 did not take.

- [ ] **Step 4: Confirm Flutter's logo is gone from every platform**

Run: `cd scripts/brand && npm run verify`
Expected: PASS.

Then spot-check a generated platform file by hue:

Run: `cd scripts/brand && node -e "import('./verify.mjs')" 2>&1 | tail -1`
Expected: `✓ every brand asset check passed`

- [ ] **Step 5: Commit**

```bash
git add app/flutter_launcher_icons.yaml app/android app/ios app/web app/macos
git commit -m "feat(app): ship the brand icon on every platform

Replaces Flutter's own logo, which was the app icon on Android, iOS, web
and macOS. Fixes the adaptive icon: background is now the gradient plate
and foreground the bare mark, where before the background was flat white
and the foreground was the full plated image.

Pins adaptive_icon_foreground_inset to 0. The package default of 16
becomes android:inset=\"16%\" on the foreground and monochrome layers and
would multiply with the mark's own scale(0.89), shipping the icon at
0.605 of its intended size.

Drops adaptive_icon_round, which is not a key in 0.14.4 and never had
any effect."
```

---

### Task 6: Contact sheet for the eyeball check

**Files:**
- Create: `scripts/brand/contact-sheet.mjs`

- [ ] **Step 1: Write the sheet generator**

`scripts/brand/contact-sheet.mjs`:

```js
// Renders one PNG showing the mark across every size and ground that matters.
// Output is a scratch artefact — not committed.
import sharp from 'sharp';
import { resolve } from 'node:path';
import { markSvg, iconSvg, CENTRE, SAFE_RADIUS } from './geometry.mjs';

const OUT = process.argv[2] ?? resolve(import.meta.dirname, 'contact-sheet.png');
const SIZES = [16, 24, 32, 48, 64, 128];
const render = (svg, px) => sharp(Buffer.from(svg), { density: 300 }).resize(px, px).png().toBuffer();

const layers = [];
let x = 20;
for (const s of SIZES) {
  layers.push({ input: await render(iconSvg(), s), left: x, top: 20 + (128 - s) });
  x += s + 20;
}

// safe-zone overlay: the icon with the guaranteed circle drawn over it.
// iconSvg() contains exactly one `</svg>`, so this replace is unambiguous.
const overlay = iconSvg().replace(
  '</svg>',
  `<circle cx="${CENTRE}" cy="${CENTRE}" r="${SAFE_RADIUS}" fill="none" ` +
    `stroke="#fff" stroke-opacity=".6" stroke-width="4" stroke-dasharray="12 10"/></svg>`,
);
layers.push({ input: await render(overlay, 128), left: x, top: 20 });

// monochrome on white, and the mark on the dark app surface
layers.push({ input: await render(markSvg('#000000'), 96), left: 20, top: 180 });
const onDark = await sharp({ create: { width: 136, height: 136, channels: 3, background: '#0F0A1A' } })
  .composite([{ input: await render(markSvg('#FFFFFF'), 96), left: 20, top: 20 }])
  .png().toBuffer();
layers.push({ input: onDark, left: 140, top: 160 });

await sharp({ create: { width: 900, height: 330, channels: 3, background: '#F0EEF7' } })
  .composite(layers).png().toFile(OUT);
console.log(`contact sheet → ${OUT}`);
```

- [ ] **Step 2: Generate and inspect**

Run: `cd scripts/brand && npm run sheet`
Expected: `contact sheet → .../contact-sheet.png`

Open it. Check: at 16px the mark is still an arch silhouette rather than a blob; the bars are distinguishable from 24px up; the monochrome version reads on white; nothing crosses the dashed safe circle.

- [ ] **Step 3: Keep the output out of git**

Run: `echo "scripts/brand/contact-sheet.png" >> .gitignore`

- [ ] **Step 4: Commit**

```bash
git add scripts/brand/contact-sheet.mjs .gitignore
git commit -m "chore(brand): contact sheet for visual review"
```

---

### Task 7: Give the admin panel the mark

The admin panel has no brand asset at all — `admin/public` holds only Next.js's stock `next.svg`, `vercel.svg`, `file.svg`, `globe.svg`, `window.svg`, and the sidebar uses a generic `Store` glyph from lucide.

**Read before writing any code here.** `admin/AGENTS.md` warns that this is Next.js 16.2.3 and its conventions may differ from what you remember. Two points already checked against `admin/node_modules/next/dist/docs/`:

- `app/icon.svg` is a valid convention — `01-app/03-api-reference/03-file-conventions/01-metadata/app-icons.md` lists `.svg` as supported for `icon` anywhere under `app/**/*`.
- `next/image` serves SVG without `dangerouslyAllowSVG`: `01-app/03-api-reference/02-components/image.md` states `unoptimized` is applied automatically when `src` ends in `.svg`.

**Pre-existing failure, not yours.** `npx eslint components/sidebar.tsx` already reports one error before you touch anything:

```
components/sidebar.tsx:37:5  Avoid calling setState() directly within an effect  react-hooks/set-state-in-effect
```

It comes from the `userName` effect and is unrelated to this work. Leave it. If lint reports exactly this one error after your change, nothing regressed.

**Files:**
- Create: `admin/app/icon.svg`
- Create: `admin/public/brand-icon.svg`
- Modify: `admin/components/sidebar.tsx`

- [ ] **Step 1: Copy the generated icon into the admin panel**

Run:
```bash
cp app/assets/brand/icon.svg admin/app/icon.svg
cp app/assets/brand/icon.svg admin/public/brand-icon.svg
```

The plated icon is used rather than a lockup, for two reasons: the sidebar already renders the words "DukonPro Admin" next to the glyph, and that sidebar is dark (`bg-slate-900`) so a light lockup would sit in a white box on it.

- [ ] **Step 2: Swap the lucide glyph for the brand mark**

`admin/components/sidebar.tsx` currently opens its logo block with a generic store glyph:

```tsx
      {/* Logo */}
      <div className="flex items-center gap-2 px-6 py-5 border-b border-slate-700">
        <Store className="h-6 w-6 text-blue-400" />
        <span className="font-bold text-lg tracking-tight">DukonPro Admin</span>
      </div>
```

Replace that `<Store .../>` line with:

```tsx
        <Image
          src="/brand-icon.svg"
          alt=""
          width={512}
          height={512}
          className="h-6 w-6 rounded-[6px]"
        />
```

Keep the `<span>` exactly as it is — "Admin" distinguishes this panel from the mobile app, and the lockup does not carry that word.

`alt=""` is deliberate: the adjacent span already names the brand, so an alt text here would make a screen reader announce it twice. `width`/`height` are the SVG's intrinsic 512×512; Tailwind's `h-6 w-6` is what actually sizes it. `rounded-[6px]` keeps the plate's corners proportional at 24px, since the 114/512 radius scales to about 5.3px.

- [ ] **Step 3: Add the import**

At the top of `admin/components/sidebar.tsx`, below the `next/navigation` import:

```tsx
import Image from 'next/image';
```

- [ ] **Step 4: Remove `Store` from the lucide import if it is now unused**

Run: `grep -n "Store" admin/components/sidebar.tsx`
Expected: `Store` still appears in `navItems` as the icon for `/stores`. **It is still used — leave the import alone.** Only drop it from the import list if this grep shows no remaining usage.

- [ ] **Step 5: Lint, build and test**

Run: `cd admin && npx eslint components/sidebar.tsx`
Expected: exactly one error, the pre-existing `react-hooks/set-state-in-effect` at line 37. Any second error is yours.

Run: `cd admin && npm run build`
Expected: build completes with no type errors.

Run: `cd admin && npm test`
Expected: all suites pass. `components/sidebar.test.tsx` asserts on `userName` and the nav, not on the glyph, so it should be unaffected. If a snapshot does fail, inspect the diff and update it only if the sole change is the glyph swap.

- [ ] **Step 6: Commit**

```bash
git add admin/app/icon.svg admin/public/brand-icon.svg admin/components/sidebar.tsx
git commit -m "feat(admin): brand favicon and sidebar mark

The panel had no brand asset: the favicon was Next.js's default and the
sidebar used a generic lucide store glyph. Both now use the generated
icon.svg, so they stay in step with the mobile app automatically."
```

---

### Task 8: Final sweep

- [ ] **Step 1: Run every check once more from a clean state**

```bash
cd scripts/brand && npm test && npm run render && npm run verify
cd ../../app && dart run flutter_launcher_icons
cd ../scripts/brand && npm run verify
```

Expected: tests pass, render writes, generator succeeds, verifier passes.

- [ ] **Step 2: Confirm the working tree holds no stray changes**

Run: `git status --short`
Expected: clean, or only `scripts/brand/contact-sheet.png` which is ignored.

- [ ] **Step 3: Confirm the app builds with the new icons**

Run: `cd app && flutter build apk --debug`
Expected: `✓ Built build/app/outputs/flutter-apk/app-debug.apk`

- [ ] **Step 4: Check the icon on a device or emulator**

Install the debug APK and look at the launcher. Confirm: the icon is the arch with bars, not Flutter's logo; it is the same visual size as neighbouring icons (this is the `adaptive_icon_foreground_inset` check, and only a real launcher shows it); long-pressing and switching the launcher to themed icons shows the monochrome version.

---

## Out of scope

Named in the spec, deliberately not in this plan:

- **Splash screen.** `flutter_native_splash: 2.4.4` is installed but unconfigured; the splash is still default white.
- **Printing the mark on receipts.** `mark-mono.svg` and `monochrome.png` are produced here, but wiring them into the ESC/POS path touches the printing code.
- **Store marketing assets.** Feature graphic 1024×500, screenshots.

## Follow-ups worth filing

1. Configure `flutter_native_splash` with the mark on the gradient ground, so launch stops flashing white.
2. Add `scripts/brand/npm test && npm run verify` to CI so a regenerated-wrong icon cannot merge.
3. Revisit the bar group's optical centring during final balancing — the spec records this as the one open question.
