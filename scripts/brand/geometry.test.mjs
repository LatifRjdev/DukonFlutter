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
