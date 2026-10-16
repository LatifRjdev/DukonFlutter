# Font licences

This directory ships two font families, both under the SIL Open Font License
1.1. Neither family's `.ttf` files carried this notice as a separate file —
only inside their own `name` table — so it is reproduced here from the fonts
themselves.

The fields below were read programmatically with `fontkit` from each `.ttf`'s
`name` table: nameID 0 (copyright), nameID 13 (licence description) and
nameID 14 (licence URL). Within each family every weight (`Regular`, `Medium`,
`SemiBold`, `Bold`, `ExtraBold`) carries byte-identical copyright, licence and
licence-URL strings — only the version string differs between weights, and
that is omitted below as not legally significant. No field was empty in any
of the nine files checked; nothing here is filled in from a guess.

## Inter

Files: `Inter-Regular.ttf`, `Inter-Medium.ttf`, `Inter-SemiBold.ttf`,
`Inter-Bold.ttf`.

- **Copyright (nameID 0):** Copyright 2016 The Inter Project Authors
- **Licence (nameID 13):** This Font Software is licensed under the SIL Open
  Font License, Version 1.1. This license is available with a FAQ at:
  http://scripts.sil.org/OFL
- **Licence URL (nameID 14):** http://scripts.sil.org/OFL

## Plus Jakarta Sans

Files: `PlusJakartaSans-Regular.ttf`, `PlusJakartaSans-Medium.ttf`,
`PlusJakartaSans-SemiBold.ttf`, `PlusJakartaSans-Bold.ttf`,
`PlusJakartaSans-ExtraBold.ttf`.

- **Copyright (nameID 0):** Copyright 2020 The Plus Jakarta Sans Project
  Authors (https://github.com/tokotype/PlusJakartaSans)
- **Licence (nameID 13):** This Font Software is licensed under the SIL Open
  Font License, Version 1.1. This license is available with a FAQ at:
  https://scripts.sil.org/OFL
- **Licence URL (nameID 14):** https://scripts.sil.org/OFL

## Scope of this notice

The OFL permits embedding and outlining glyphs into other artwork; it does
not require redistributing the OFL's full legal text alongside every
derivative, only that the font's own licence notice travel with the font
files. This branch is the first to bake these fonts' glyph outlines into
committed, redistributed artwork — `app/assets/brand/lockup-light.svg` and
`app/assets/brand/lockup-dark.svg`, both produced by
`scripts/brand/wordmark.mjs` — which is squarely permitted; this file exists
only to carry the notice that was missing.
