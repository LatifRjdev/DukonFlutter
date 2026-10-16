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
