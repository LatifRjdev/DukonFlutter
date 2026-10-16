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
const ANDROID_FASTLANE = resolve(ROOT, 'app/android/fastlane/metadata/android/ru-RU/images');
const IOS_FASTLANE = resolve(ROOT, 'app/ios/fastlane/metadata/ru-RU');
mkdirSync(BRAND, { recursive: true });
mkdirSync(ICON, { recursive: true });
mkdirSync(ANDROID_FASTLANE, { recursive: true });
mkdirSync(IOS_FASTLANE, { recursive: true });

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
// Bare mark on transparency for flutter_native_splash — distinct from
// adaptive_fg.png because the splash ground is already a solid colour, so a
// plated icon here would double up on background. Own file, own name: the
// two consumers may diverge later.
await png(markSvg('#FFFFFF')).toFile(resolve(ICON, 'splash.png'));
console.log('png   icon, adaptive_bg, adaptive_fg, monochrome, ios_dark, ios_tinted, splash');

// ---- store listing icons (fastlane) -------------------------------------
// Both stores require an opaque icon (Google Play rejects alpha implicitly by
// flattening it itself with unpredictable results; the App Store rejects it
// outright), but iconSvg()'s plate has rounded corners, so the corners render
// transparent, not pre-painted. Flattened against white, matching what
// flutter_launcher_icons' own `remove_alpha_ios: true` already does for the
// shipped iOS app icon (verified empirically: the straight-alpha edge pixels
// sharp/librsvg produce already carry the correct gradient-edge RGB, not a
// black-premultiplied one, so compositing over white blends cleanly with no
// dark fringe at the rounded-corner boundary).
await png(iconSvg(), 512).flatten({ background: '#FFFFFF' }).toFile(resolve(ANDROID_FASTLANE, 'icon.png'));
await png(iconSvg(), 1024).flatten({ background: '#FFFFFF' }).toFile(resolve(IOS_FASTLANE, 'icon.png'));
console.log('png   fastlane icon (android 512, ios 1024)');
