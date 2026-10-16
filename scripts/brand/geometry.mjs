// Canonical geometry for the DukonPro mark. Everything else derives from this.
// Three ascending bars cut out of a solid pointed arch.
// Spec: docs/superpowers/specs/2026-10-16-brand-mark-and-app-icon-design.md

export const CANVAS = 512;
export const CENTRE = CANVAS / 2;
// 22.3% squircle, per Apple HIG (see the test asserting this ratio below).
export const PLATE_RADIUS = 114;

// Android guarantees only the central 66% of an adaptive icon survives masking.
export const SAFE_RADIUS = 169;
// Unscaled, the arch's bottom corner sits 187 units from centre; 187 * 0.89 = 166.4,
// inside SAFE_RADIUS. 0.90 would also technically clear it (187 * 0.90 = 168.3 < 169)
// but leaves only 0.7 units of headroom against mask rounding and anti-aliasing at
// render time; 0.89's 2.6 units of headroom is the deliberate margin.
export const MARK_SCALE = 0.89;

// Indigo (#6366F1) to violet (#8B5CF6), per the agreed brand mark spec. The 55% stop
// (#7C6AF0) is a deliberate custom colour, not the linear RGB midpoint of the two end
// colours (which would be #7761F3) — it was hand-picked to keep the transition visually
// smooth given sRGB gamma rather than mathematically exact.
export const GRADIENT = [
  { offset: '0%', color: '#6366F1' },
  { offset: '55%', color: '#7C6AF0' },
  { offset: '100%', color: '#8B5CF6' },
];
// The id every gradient-consuming asset (plate, icon, and later the lockup in
// render.mjs) references via url(#...). Pulled out once so a def/url mismatch can't
// happen silently from a typo in one of several literal copies.
export const GRADIENT_ID = 'b';

// Two cubic flanks mirrored about x = CENTRE (256), meeting a straight vertical wall
// below y=254 and an apex anchor point at y=112 above it.
export const ARCH = 'M132 396V254C132 176 184 132 256 112C328 132 380 176 380 254V396Z';
// Hand-copied for readability, but see the test that re-derives this from ARCH's own
// coordinates — that test is what keeps this box honest as the path changes.
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

/**
 * Distance from canvas centre to the arch's bottom corner, after MARK_SCALE.
 * Used as a stand-in for the arch's farthest point from centre overall: the bottom
 * corner (187.0 units unscaled) beats the apex (144.0 units unscaled) because the
 * arch is taller than it is wide, so checking just the corner is sufficient here —
 * it would not be if the arch's proportions changed enough to flip that comparison.
 */
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

// --- Arch wall sampling -----------------------------------------------------
// Parses ARCH's own path commands into the two cubic flank curves, so that "is this
// bar inside the arch at this height" can be answered against the real curve instead
// of the bounding box. This only needs to parse M/V/C/Z because that is the complete
// command set ARCH uses.
function parseArchCubics(d) {
  const tokens = d.match(/[A-Za-z][^A-Za-z]*/g) || [];
  let cx = 0;
  let cy = 0;
  const cubics = [];
  for (const tok of tokens) {
    const cmd = tok[0];
    const nums = tok.slice(1).trim().split(/[\s,]+/).filter(Boolean).map(Number);
    if (cmd === 'M') {
      [cx, cy] = nums;
    } else if (cmd === 'V') {
      [cy] = nums;
    } else if (cmd === 'H') {
      [cx] = nums;
    } else if (cmd === 'C') {
      const [x1, y1, x2, y2, x3, y3] = nums;
      cubics.push({ p0: { x: cx, y: cy }, p1: { x: x1, y: y1 }, p2: { x: x2, y: y2 }, p3: { x: x3, y: y3 } });
      cx = x3;
      cy = y3;
    }
    // 'Z' closes the path; no coordinates to track.
  }
  return cubics;
}

const [LEFT_FLANK] = parseArchCubics(ARCH);
// Where the curved flank meets the straight vertical wall.
const KNEE_Y = LEFT_FLANK.p0.y;

function cubicPoint(c, t) {
  const mt = 1 - t;
  return {
    x: mt ** 3 * c.p0.x + 3 * mt ** 2 * t * c.p1.x + 3 * mt * t ** 2 * c.p2.x + t ** 3 * c.p3.x,
    y: mt ** 3 * c.p0.y + 3 * mt ** 2 * t * c.p1.y + 3 * mt * t ** 2 * c.p2.y + t ** 3 * c.p3.y,
  };
}

// Finds x at a given y along a cubic that is monotonic in y. Bisection, not a
// closed-form solve, because a single monotonic flank is all this needs — valid here
// because this specific flank is a smooth curve from knee to apex with no inflection.
function xAtY(cubic, targetY) {
  const descending = cubic.p0.y > cubic.p3.y;
  let lo = 0;
  let hi = 1;
  for (let i = 0; i < 60; i += 1) {
    const mid = (lo + hi) / 2;
    const y = cubicPoint(cubic, mid).y;
    if (descending ? y > targetY : y < targetY) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return cubicPoint(cubic, (lo + hi) / 2).x;
}

/**
 * X coordinate of the arch's left wall at a given y: the straight vertical wall
 * below the knee, the curved flank above it. Derived from ARCH's own parsed
 * coordinates (not hand-copied), so a reshaped arch can't silently drift out of
 * sync with what callers think the wall is.
 */
export function archLeftWallXAtY(y) {
  return y >= KNEE_Y ? ARCH_BOUNDS.x1 : xAtY(LEFT_FLANK, y);
}

/** Mirror of archLeftWallXAtY about the canvas centre (CANVAS = 2 * CENTRE). */
export function archRightWallXAtY(y) {
  return CANVAS - archLeftWallXAtY(y);
}

// --- SVG assembly ------------------------------------------------------------

const ID_PATTERN = /^[A-Za-z][-\w.]*$/;

const stops = () =>
  GRADIENT.map((s) => `<stop offset="${s.offset}" stop-color="${s.color}"/>`).join('');

// x1/y1/x2/y2 here are objectBoundingBox fractions (SVG's default gradientUnits), not
// user-space pixels — "0 0" to "1 1" is a 45-degree diagonal across whatever element's
// bounding box this gradient is applied to, independent of that element's actual size.
export function gradientDef(id) {
  if (!ID_PATTERN.test(id)) {
    throw new Error(`gradientDef: "${id}" is not a valid SVG id`);
  }
  return `<linearGradient id="${id}" x1="0" y1="0" x2="1" y2="1">${stops()}</linearGradient>`;
}

const scaled = (inner) =>
  `<g transform="translate(${CENTRE},${CENTRE}) scale(${MARK_SCALE}) translate(-${CENTRE},-${CENTRE})">${inner}</g>`;

const open = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${CANVAS} ${CANVAS}" width="${CANVAS}" height="${CANVAS}">`;

/** The mark alone on a transparent ground. */
export function markSvg(fill = '#FFFFFF') {
  return `${open}${scaled(`<path fill="${fill}" fill-rule="evenodd" d="${MARK_PATH}"/>`)}</svg>`;
}

/** The gradient plate with no mark. */
export function plateSvg() {
  return `${open}<defs>${gradientDef(GRADIENT_ID)}</defs>` +
    `<rect width="${CANVAS}" height="${CANVAS}" rx="${PLATE_RADIUS}" fill="url(#${GRADIENT_ID})"/></svg>`;
}

/** Plate plus mark — the app icon. */
export function iconSvg() {
  return `${open}<defs>${gradientDef(GRADIENT_ID)}</defs>` +
    `<rect width="${CANVAS}" height="${CANVAS}" rx="${PLATE_RADIUS}" fill="url(#${GRADIENT_ID})"/>` +
    `${scaled(`<path fill="#FFFFFF" fill-rule="evenodd" d="${MARK_PATH}"/>`)}</svg>`;
}
