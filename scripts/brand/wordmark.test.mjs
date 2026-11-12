import test from 'node:test';
import assert from 'node:assert/strict';
import { outline, CAP_RATIO } from './wordmark.mjs';

// --- Everything below this line was NOT in the spec. Added to close three
// gaps flagged during self-review: width is never checked against anything
// independent, the y-flip is unverified, and kerning-vs-advanceWidth is
// unverified. Each opens the font directly via fontkit, bypassing
// wordmark.mjs's own arithmetic, so a bug in that arithmetic can't hide
// behind a matching bug in the test.
import * as fontkitModule from 'fontkit';
const fontkit = fontkitModule.default ?? fontkitModule;
import { resolve } from 'node:path';

const FONT = resolve(
  import.meta.dirname,
  '../../app/assets/fonts/PlusJakartaSans-ExtraBold.ttf',
);
const font = fontkit.openSync(FONT);

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

// Added: ties `width` to a figure computed independently of outline()'s own
// arithmetic — the sum of each glyph's kerned xAdvance, read straight off a
// freshly-opened font instance. A constant-factor bug in outline()'s
// `(x - tracking * UPM) * k` would show up here even though every width-only
// relative test above would still pass.
test('width matches an independently computed sum of kerned advances', () => {
  const size = 40;
  const run = font.layout('DukonPro');
  const expected = run.positions.reduce((sum, p) => sum + p.xAdvance, 0) * (size / font.unitsPerEm);
  const { width } = outline('DukonPro', size, 0);
  assert.ok(Math.abs(width - expected) < 1e-6, `expected ${expected}, got ${width}`);
});

// Added: none of "DukonPro"'s letters have a true descender, but round
// letters ('u', 'o') do have a small optical overshoot below the baseline
// (-12 font units, per their glyph bbox — normal type-design practice, not
// a bug). So the correct bound isn't "y <= 0", it's "y <= the font's own
// worst-case overshoot, scaled". That bound is computed independently from
// glyph.bbox here, not asserted from guesswork. After the required
// .scale(k, -k), every y in the emitted path must stay inside it. If the
// scale were accidentally (k, k) — the exact regression this guards
// against — the cap-height letters (745-757 font units tall) would flip to
// roughly +30 user units, ~60x past this bound, and this is the only test
// in the file that would notice.
test('every y coordinate stays within the font\'s own baseline overshoot (catches an un-negated y-scale)', () => {
  const size = 40;
  const k = size / font.unitsPerEm;
  const worstOvershoot = Math.min(
    0,
    ...[...'DukonPro'].map((ch) => font.glyphForCodePoint(ch.codePointAt(0)).bbox.minY),
  );
  // Scaled bound, plus slack for Bezier control points (which can sit
  // outside the rendered curve's own tight bbox).
  const bound = -worstOvershoot * k + 1.0;

  const { d } = outline('DukonPro', size, 0);
  const nums = d.match(/-?\d+\.?\d*/g).map(Number);
  assert.ok(nums.length % 2 === 0, 'expected an even count of x,y coordinate values');
  const ys = nums.filter((_, i) => i % 2 === 1);
  const worst = Math.max(...ys);
  assert.ok(worst <= bound, `y coordinate ${worst} exceeds overshoot bound ${bound} — looks flipped`);
});

// Added: glyph index 2 in "DukonPro" (the 'k') kerns tighter against 'u'
// than its bare advanceWidth would suggest — advanceWidth is 586 font units,
// xAdvance is 576. That 10-unit gap makes it possible to tell outline()'s
// real output apart from what it would produce if `pos.xAdvance` were
// swapped for `glyph.advanceWidth`, which is exactly the regression called
// out in the task brief.
test('width reflects GPOS kerning, not bare glyph.advanceWidth', () => {
  const size = 40;
  const run = font.layout('DukonPro');
  const kernedSum = run.positions.reduce((sum, p) => sum + p.xAdvance, 0);
  const unkernedSum = run.glyphs.reduce((sum, g) => sum + g.advanceWidth, 0);
  assert.notEqual(kernedSum, unkernedSum, 'fixture assumption broke: this font no longer kerns "DukonPro"');

  const { width } = outline('DukonPro', size, 0);
  const k = size / font.unitsPerEm;
  assert.ok(
    Math.abs(width - kernedSum * k) < 1e-6,
    `width should match the kerned sum (${kernedSum * k}), got ${width}`,
  );
  assert.ok(
    Math.abs(width - unkernedSum * k) > 0.01,
    'width matches the UNkerned sum — looks like xAdvance was swapped for advanceWidth',
  );
});

// --- Second face -----------------------------------------------------------
// The feature graphic needs a Russian tagline, and the wordmark face cannot
// set one: Plus Jakarta Sans ships no Cyrillic. fontkit does not complain
// about that — it substitutes .notdef and returns a path — so the only sign
// would be a blank word in a published store asset. These pin the guard.

test('the display face refuses Cyrillic instead of rendering it blank', () => {
  assert.throws(
    () => outline('Касса', 40, 0, 'display'),
    /no glyph for/,
    'Plus Jakarta Sans has no Cyrillic; this must fail loudly, not silently',
  );
});

test('the text face sets Cyrillic', () => {
  const { d, width } = outline('Касса и учёт магазина', 40, 0, 'text');
  assert.ok(!d.includes('NaN'), 'path data contains NaN');
  assert.ok(d.startsWith('M'), 'path data should start with a moveto');
  assert.ok(width > 0, `expected a positive width, got ${width}`);
});

test('the text face still measures against its own unitsPerEm', () => {
  // Inter and Plus Jakarta Sans have different UPMs, so a hardcoded module
  // constant would silently mis-scale every string set in the second face.
  const inter = fontkit.openSync(
    resolve(import.meta.dirname, '../../app/assets/fonts/Inter-SemiBold.ttf'),
  );
  const size = 40;
  const run = inter.layout('Касса');
  const expected =
    run.positions.reduce((sum, p) => sum + p.xAdvance, 0) *
    (size / inter.unitsPerEm);
  const { width } = outline('Касса', size, 0, 'text');
  assert.ok(
    Math.abs(width - expected) < 1e-6,
    `expected ${expected}, got ${width}`,
  );
});

test('the default face is still the wordmark face', () => {
  const explicit = outline('DukonPro', 40, 0, 'display').width;
  const implied = outline('DukonPro', 40, 0).width;
  assert.equal(implied, explicit);
});
