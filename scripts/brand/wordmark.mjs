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
