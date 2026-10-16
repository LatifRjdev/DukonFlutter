import test from 'node:test';
import assert from 'node:assert/strict';
import sharp from 'sharp';
import {
  CANVAS, CENTRE, SAFE_RADIUS, PLATE_RADIUS, GRADIENT_ID,
  ARCH, ARCH_BOUNDS, BARS_META, MARK_PATH, MARK_SCALE,
  scaledCornerRadius, barGroupBounds,
  archLeftWallXAtY, archRightWallXAtY,
  markSvg, plateSvg, iconSvg,
} from './geometry.mjs';

test('scaled arch corners sit inside the Android safe circle', () => {
  assert.ok(
    scaledCornerRadius() <= SAFE_RADIUS,
    `corner at ${scaledCornerRadius().toFixed(1)} exceeds safe radius ${SAFE_RADIUS}`,
  );
});

test('the mark is not wastefully smaller than the safe circle allows', () => {
  // Guards the opposite failure: someone "fixes" clipping by over-shrinking.
  // Tight enough that MARK_SCALE = 0.82 (a plausible over-correction) goes red.
  assert.ok(
    scaledCornerRadius() > SAFE_RADIUS * 0.96,
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

test('bars have one uniform width and even gaps', () => {
  // barGroupBounds() only exposes the outer edges — this is what actually pins down
  // the middle bar's left/width, which would otherwise be free to drift.
  const widths = new Set(BARS_META.map((b) => b.width));
  assert.equal(widths.size, 1, 'bars do not share one width');
  const gaps = BARS_META.slice(1).map((b, i) => b.left - (BARS_META[i].left + BARS_META[i].width));
  assert.deepEqual(gaps, [16, 16]);
});

test("bars stay clear of the arch's bounding box (coarse sanity check only — the real, tighter figure at the tallest bar is checked below against the actual curved wall)", () => {
  const { left, right } = barGroupBounds();
  const WALL = 40; // slack against the bounding box, not the true per-height wall
  assert.ok(left - ARCH_BOUNDS.x1 >= WALL, 'left bar group too close to the arch bounding box');
  assert.ok(ARCH_BOUNDS.x2 - right >= WALL, 'right bar group too close to the arch bounding box');
});

test('each bar stays inside the arch wall at its own height', () => {
  // Rigorous version of the bounding-box check above: samples the arch's actual
  // flank curve at each bar's top y (via archLeftWallXAtY/archRightWallXAtY) rather
  // than comparing to the widest point of the arch. The tallest bar's top is above
  // the knee, inside the curved flank, so this is the test that actually bites there.
  for (const bar of BARS_META) {
    assert.ok(bar.baseline < ARCH_BOUNDS.y2, `bar at x=${bar.left} baseline reaches the arch floor`);
    assert.ok(bar.top > ARCH_BOUNDS.y1, `bar at x=${bar.left} top reaches above the arch apex`);
    assert.ok(bar.baseline > bar.top, `bar at x=${bar.left} has non-positive height`);

    const leftWall = archLeftWallXAtY(bar.top);
    const rightWall = archRightWallXAtY(bar.top);
    assert.ok(
      bar.left >= leftWall,
      `bar at x=${bar.left} crosses the left wall (${leftWall.toFixed(1)}) at y=${bar.top}`,
    );
    assert.ok(
      bar.left + bar.width <= rightWall,
      `bar at x=${bar.left} crosses the right wall (${rightWall.toFixed(1)}) at y=${bar.top}`,
    );
  }
});

test('ARCH_BOUNDS matches the coordinates actually written in ARCH', () => {
  // A plain "split all numbers into alternating x,y" scrape does NOT work here: V/H
  // commands contribute a single axis value each, which desyncs the parity of every
  // number after them. ARCH has two V commands, so naively doing
  //   nums.filter((_, i) => i % 2 === 0)   // "xs"
  //   nums.filter((_, i) => i % 2 === 1)   // "ys"
  // on the raw flattened number list produces {x1:112, y1:132, x2:254, y2:396} —
  // wrong, and silently so (112/254 are apex/knee y-values miscounted as x). This
  // walks the actual path commands instead, so each number is attributed to the
  // right axis regardless of which command produced it.
  //
  // The walk itself is only sound because every extreme of this particular arch
  // falls on an anchor or control point of M/V/H/C — none of it lies strictly inside
  // a curve interior past its listed points. If the arch were reshaped so an extreme
  // fell strictly inside a curve instead of at a listed point, this would need to
  // sample the curve (see archLeftWallXAtY) rather than just listing coordinates.
  //
  // This duplicates roughly the same walk as geometry.mjs's own parseArchCubics,
  // deliberately: ARCH_BOUNDS is a hand-copied constant being checked against ARCH,
  // and this test's job is to catch the two drifting apart. Importing and reusing
  // parseArchCubics here would make the test verify the module's parser against
  // itself — passing even if that parser were the thing that broke. Keep the
  // duplication; don't "DRY" this one.
  const tokens = ARCH.match(/[A-Za-z][^A-Za-z]*/g);
  let x = 0;
  let y = 0;
  const xs = [];
  const ys = [];
  for (const tok of tokens) {
    const cmd = tok[0];
    const nums = tok.slice(1).trim().split(/[\s,]+/).filter(Boolean).map(Number);
    if (cmd === 'M') {
      [x, y] = nums;
      xs.push(x);
      ys.push(y);
    } else if (cmd === 'V') {
      [y] = nums;
      xs.push(x);
      ys.push(y);
    } else if (cmd === 'H') {
      [x] = nums;
      xs.push(x);
      ys.push(y);
    } else if (cmd === 'C') {
      const [x1, y1, x2, y2, x3, y3] = nums;
      xs.push(x1, x2, x3);
      ys.push(y1, y2, y3);
      x = x3;
      y = y3;
    }
  }
  assert.deepEqual(
    { x1: Math.min(...xs), y1: Math.min(...ys), x2: Math.max(...xs), y2: Math.max(...ys) },
    ARCH_BOUNDS,
  );
});

test('the Android safe radius is the documented 66% of the canvas', () => {
  assert.equal(SAFE_RADIUS, Math.round((CANVAS * 0.66) / 2));
});

test('the plate radius is the Apple HIG squircle proportion', () => {
  assert.ok(
    Math.abs(PLATE_RADIUS / CANVAS - 0.223) < 0.002,
    `plate radius is ${(PLATE_RADIUS / CANVAS * 100).toFixed(2)}% of the canvas, expected 22.3%`,
  );
});

test('the plate, icon and mark SVGs declare a viewBox matching CANVAS', () => {
  for (const svg of [markSvg(), plateSvg(), iconSvg()]) {
    assert.match(svg, new RegExp(`viewBox="0 0 ${CANVAS} ${CANVAS}"`));
  }
});

test("the plate's corner radius equals PLATE_RADIUS", () => {
  assert.match(plateSvg(), new RegExp(`rx="${PLATE_RADIUS}"`));
  assert.match(iconSvg(), new RegExp(`rx="${PLATE_RADIUS}"`));
});

test('every url(#id) reference resolves to a matching id= in the same document', () => {
  for (const svg of [plateSvg(), iconSvg()]) {
    const refs = [...svg.matchAll(/url\(#([-\w.]+)\)/g)].map((m) => m[1]);
    assert.ok(refs.length > 0, 'expected at least one gradient reference');
    for (const id of refs) {
      assert.match(svg, new RegExp(`id="${id}"`), `no id="${id}" definition for url(#${id})`);
    }
    // The canonical id both sides are expected to agree on.
    assert.ok(refs.includes(GRADIENT_ID));
  }
});

test('markSvg and iconSvg draw the exact MARK_PATH, scaled by MARK_SCALE', () => {
  for (const svg of [markSvg(), iconSvg()]) {
    assert.ok(svg.includes(MARK_PATH), 'MARK_PATH is not present verbatim');
    assert.ok(svg.includes(`scale(${MARK_SCALE})`), 'mark is not scaled by MARK_SCALE');
  }
});

test('the mark path uses evenodd fill so the bars cut out of the arch', () => {
  for (const svg of [markSvg(), iconSvg()]) {
    assert.match(svg, /fill-rule="evenodd"/);
  }
});

test('markSvg has no background rect — it is the cutout mark alone', () => {
  assert.doesNotMatch(markSvg(), /<rect/);
});

test('every builder output is well-formed SVG that sharp can rasterise at CANVAS size', async () => {
  for (const svg of [markSvg(), plateSvg(), iconSvg()]) {
    const meta = await sharp(Buffer.from(svg)).metadata();
    assert.equal(meta.width, CANVAS);
    assert.equal(meta.height, CANVAS);
  }
});
