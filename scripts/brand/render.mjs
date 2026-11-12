// Writes every brand asset from the canonical geometry. Run after any change
// to geometry.mjs. Never hand-edit the files this produces.
import sharp from 'sharp';
import { mkdirSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
import {
  CANVAS, CENTRE, PLATE_RADIUS, MARK_SCALE, MARK_PATH, GRADIENT, GRADIENT_ID,
  gradientDef, markSvg, plateSvg, iconSvg,
} from './geometry.mjs';
import { outline, CAP_RATIO } from './wordmark.mjs';

const ROOT = resolve(import.meta.dirname, '../..');
const BRAND = resolve(ROOT, 'app/assets/brand');
const ICON = resolve(ROOT, 'app/assets/icon');
const ANDROID_FASTLANE = resolve(ROOT, 'app/android/fastlane/metadata/android/ru-RU/images');
const IOS_FASTLANE = resolve(ROOT, 'app/ios/fastlane/metadata/ru-RU');
const ADMIN_APP = resolve(ROOT, 'admin/app');
const ADMIN_PUBLIC = resolve(ROOT, 'admin/public');
mkdirSync(BRAND, { recursive: true });
mkdirSync(ICON, { recursive: true });
mkdirSync(ANDROID_FASTLANE, { recursive: true });
mkdirSync(IOS_FASTLANE, { recursive: true });
mkdirSync(ADMIN_APP, { recursive: true });
mkdirSync(ADMIN_PUBLIC, { recursive: true });

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
    `<rect width="${CANVAS}" height="${CANVAS}" rx="${PLATE_RADIUS}" fill="url(#${GRADIENT_ID})"/>` +
    `<g transform="translate(${CENTRE},${CENTRE}) scale(${MARK_SCALE}) translate(-${CENTRE},-${CENTRE})">` +
    `<path fill="#FFFFFF" fill-rule="evenodd" d="${MARK_PATH}"/></g>`;
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">` +
    `<defs>${gradientDef(GRADIENT_ID)}</defs>` +
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

// ---- admin panel copies ---------------------------------------------------
// admin/app/icon.svg is Next.js's App Router favicon convention; admin/public/
// brand-icon.svg is what Sidebar renders via <Image src="/brand-icon.svg">.
// Both are just the app icon — written here, not hand-copied, so they can
// never drift from app/assets/brand/icon.svg.
writeFileSync(resolve(ADMIN_APP, 'icon.svg'), sources['icon.svg']);
writeFileSync(resolve(ADMIN_PUBLIC, 'brand-icon.svg'), sources['icon.svg']);
console.log('svg   admin/app/icon.svg, admin/public/brand-icon.svg');

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

// ---- Play Store feature graphic -----------------------------------------
// Exactly 1024x500 and opaque — Google Play rejects any other size and does
// not accept an alpha channel.
//
// Composition is centred with wide margins on purpose. Play crops this to
// different aspect ratios across its surfaces and, where the listing has a
// promo video, overlays a play button over the middle. Anything near an edge
// is liable to be cut; anything small in the dead centre is liable to be
// covered. So: one centred lockup, large, with nothing in the corners.
//
// The tagline is lifted verbatim from the first clause of the store listing's
// own short_description.txt rather than written fresh, so the graphic cannot
// drift from the approved copy. It is set in the TEXT face — the wordmark
// face has no Cyrillic and would render it blank.
const FEATURE = { w: 1024, h: 500 };

function featureGraphicSvg() {
  const iconSize = 132;
  const typeSize = 86;
  const tagSize = 30;
  const gap = 28;
  const tagGap = 34;

  const duk = outline('Dukon', typeSize, L.track);
  const pro = outline('Pro', typeSize, L.track);
  const tag = outline('Касса и учёт магазина', tagSize, 0, 'text');

  const lockupW = iconSize + gap + duk.width + pro.width;
  const lockupX = (FEATURE.w - lockupW) / 2;
  // The whole block (lockup + tagline) is centred vertically as one unit,
  // rather than centring the lockup and letting the tagline push it off.
  const blockH = iconSize + tagGap + tagSize;
  const top = (FEATURE.h - blockH) / 2;
  const capH = CAP_RATIO * typeSize;
  const typeBaseline = top + iconSize / 2 + capH / 2;
  const tagBaseline = top + iconSize + tagGap + tagSize * 0.72;

  const plate =
    `<rect width="${CANVAS}" height="${CANVAS}" rx="${PLATE_RADIUS}" fill="#FFFFFF" fill-opacity="0.14"/>` +
    `<g transform="translate(${CENTRE},${CENTRE}) scale(${MARK_SCALE}) translate(-${CENTRE},-${CENTRE})">` +
    `<path fill="#FFFFFF" fill-rule="evenodd" d="${MARK_PATH}"/></g>`;

  return (
    `<svg xmlns="http://www.w3.org/2000/svg" width="${FEATURE.w}" height="${FEATURE.h}" ` +
    `viewBox="0 0 ${FEATURE.w} ${FEATURE.h}">` +
    `<defs><linearGradient id="fg" x1="0" y1="0" x2="1" y2="1">` +
    GRADIENT.map(
      (g) => `<stop offset="${g.offset}" stop-color="${g.color}"/>`,
    ).join('') +
    `</linearGradient></defs>` +
    `<rect width="${FEATURE.w}" height="${FEATURE.h}" fill="url(#fg)"/>` +
    `<g transform="translate(${lockupX},${top}) scale(${iconSize / CANVAS})">${plate}</g>` +
    `<g transform="translate(${lockupX + iconSize + gap},${typeBaseline})">` +
    `<path fill="#FFFFFF" d="${duk.d}"/>` +
    `<g transform="translate(${duk.width},0)">` +
    `<path fill="#FFFFFF" fill-opacity="0.82" d="${pro.d}"/></g>` +
    `</g>` +
    `<g transform="translate(${(FEATURE.w - tag.width) / 2},${tagBaseline})">` +
    `<path fill="#FFFFFF" fill-opacity="0.88" d="${tag.d}"/></g>` +
    `</svg>`
  );
}

const featureSvg = featureGraphicSvg();
if (featureSvg.includes('NaN')) {
  throw new Error('featureGraphic contains NaN — refusing to write');
}
writeFileSync(resolve(BRAND, 'feature-graphic.svg'), featureSvg);
await sharp(Buffer.from(featureSvg), { density: 144 })
  .resize(FEATURE.w, FEATURE.h)
  .flatten({ background: '#6366F1' })
  .png()
  .toFile(resolve(ANDROID_FASTLANE, 'featureGraphic.png'));
console.log('png   fastlane featureGraphic (1024x500)');
