// Converts the DukonPro wordmark to outline paths.
//
// fontkit, NOT opentype.js. opentype.js emits NaN x-coordinates when glyph
// paths from this font are accumulated, and librsvg then stops drawing
// mid-word with no error. It also throws outright on this font's GSUB table.
import * as fontkit from 'fontkit';
import { resolve } from 'node:path';

const fontPath = (file) =>
  resolve(import.meta.dirname, '../../app/assets/fonts/', file);

/**
 * Two faces, because one does not cover the alphabet we need.
 *
 * `display` is the wordmark face — "DukonPro" is set in it and nothing else
 * should be. It has **no Cyrillic glyphs at all**: ask it for "Касса" and
 * fontkit returns .notdef for every letter, which renders as blank or as
 * tofu boxes with no error anywhere. That is why `text` exists.
 *
 * `text` is the UI face the app already ships, and it does cover Cyrillic.
 * Any Russian, Tajik or Uzbek string in a rendered asset must use it.
 */
const FACES = {
  display: fontkit.openSync(fontPath('PlusJakartaSans-ExtraBold.ttf')),
  text: fontkit.openSync(fontPath('Inter-SemiBold.ttf')),
};

const font = FACES.display;
const UPM = font.unitsPerEm;

export const CAP_RATIO = font.capHeight / UPM;

/**
 * Throws if [face] cannot draw every character of [text].
 *
 * Without this a missing glyph is silent: fontkit substitutes .notdef and the
 * render completes, so the first sign of trouble is a blank word in a shipped
 * store asset. Same failure mode as the opentype.js NaN bug this module was
 * written to escape — wrong output, no error — so it gets the same treatment.
 */
function assertCovered(text, faceName) {
  const face = FACES[faceName];
  const missing = [...new Set(text)].filter(
    (ch) => ch !== ' ' && !face.hasGlyphForCodePoint(ch.codePointAt(0)),
  );
  if (missing.length) {
    throw new Error(
      `face "${faceName}" has no glyph for: ${missing.join(' ')} — ` +
        `"${text}" would render blank. Cyrillic needs face "text".`,
    );
  }
}

/**
 * @param {string} text
 * @param {number} size      em size in SVG user units
 * @param {number} tracking  letter-spacing as a fraction of the em
 * @param {'display'|'text'} faceName  'display' is the wordmark face and has
 *                                     no Cyrillic; use 'text' for anything else
 * @returns {{ d: string, width: number }}
 */
export function outline(text, size, tracking = 0, faceName = 'display') {
  assertCovered(text, faceName);
  const face = FACES[faceName];
  const UPM = face.unitsPerEm;
  const run = face.layout(text);
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
