# PDP-1 alphanumeric character-code source metadata

The reviewed source tables are factual transcriptions of primary Digital
Equipment Corporation manuals. The scans and rendered pages are not included
in this package.

## April 1960 Friden FPC-8 revision

- Source: *Programmed Data Processor-1 Handbook*, F15, April 1960.
- URL: <https://bitsavers.org/pdf/dec/pdp1/F15_PDP1_Handbook_Apr60.pdf>
- SHA-256: `7495a32bca4897aa54fb0b073149303b66a17bf2f96371e930aa300594c38ab6`
- PDF page 12 / printed pages 20-21 specifies the eight-hole reader,
  odd-parity fifth bit, discarded eighth bit, six-bit conversion, and special
  carriage-return conversion.
- PDF page 17 / printed pages 30-31 contains Tables I-III, the complete
  Friden-to-Concise mapping and both case columns.

## October 1963 FIO-DEC revision

- Source: *Programmed Data Processor-1 Handbook*, F15D, October 1963.
- URL: <https://bitsavers.org/pdf/dec/pdp1/F15D_PDP1_Handbook_Oct63.pdf>
- SHA-256: `8490b72962584f30c9dc7f3a9684ba3eeb79c7d5530b78ee371a6efe098a8f21`
- PDF page 24 / printed page 23 specifies the eight-channel reader, channel
  order, FIO-DEC odd parity, and the Concise six-bit conversion.
- PDF pages 69-70 / printed pages 68-69 contain the complete character,
  FIO-DEC, Concise, case, ribbon, shift, tape-feed, stop, delete, and device
  control tables.

The transition is independently corroborated by *PDP-1 Handbook* F15B (1961),
SHA-256 `492aa312130ee1c8fb6c504e780ca1ce8487fde7921197d79c4dabf3984224d4`,
PDF page 13 / printed pages 22-23 and PDF pages 20-21 / printed pages 36-39.

## Unicode and licensing policy

The tables preserve the manuals' literal glyph identities. The 1963
non-spacing overstrike is represented as U+0305 COMBINING OVERLINE; its
middle-dot partner is U+00B7. Logical horseshoe, OR, AND, arrows, and multiply
use their matching Unicode scalars. Device actions change state or produce no
Unicode scalar; TAB, BACKSPACE, and CARRIAGE RETURN retain their control-code
semantics.

These reviewed numeric mappings and the original project expression are
distributed under `LGPL-2.1-or-later`, the package license. No DEC scan,
facsimile, page image, or substantial manual prose is redistributed.
