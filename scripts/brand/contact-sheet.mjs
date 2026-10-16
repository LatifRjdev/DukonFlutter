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
