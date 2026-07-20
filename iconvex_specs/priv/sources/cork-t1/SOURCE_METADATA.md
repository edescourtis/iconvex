# Cork / TeX T1 normalized source metadata

This directory contains an independently normalized factual 256-slot mapping.
It contains no upstream font program, PostScript vector, LaTeX source, CMap, or
PDF. The normalized CSV and Iconvex implementation are distributed under
`LGPL-2.1-or-later`.

Retrieved and reviewed: 2026-07-17.

## Primary sources

- Michael J. Ferguson, “Report on Multilingual Activities,” TUGboat 11(4),
  1990, PDF page 3, “Extended TeX Font Encoding Scheme — Latin” (Cork,
  1990-09-12):
  https://www.tug.org/TUGboat/tb11-4/tb30ferguson.pdf
  SHA-256: ce79e1e82074f4d48abd15c9bc4f38619d1469bf96c532941e3bbd1df409a74c.
  The downloaded article contains no explicit license and is not vendored.
- TUG Fontname `ec.enc`, internal date `24feb10`:
  https://tug.ctan.org/info/fontname/ec.enc
  SHA-256: bd865bb53fe3c2f479efa8e3d92e1027db5e64a1d7c0ced7884d6c9ee65c0b48.
  CTAN package metadata identifies Fontname as GPL; `ec.enc` has no per-file
  license notice and is not vendored.
- LaTeX2e `base/ltoutenc.dtx`, commit
  `5954204ffe58a81db0e0de1335c62cd45c8caf9b` (2026-06-18), file version
  `2025/07/18 v2.1d`:
  https://github.com/latex3/latex2e/blob/5954204ffe58a81db0e0de1335c62cd45c8caf9b/base/ltoutenc.dtx
  SHA-256: 61cc867257831d2611e2d96ead2a1882f03e4da27c095b642cc866984aac0bc2.
  License: LPPL-1.3c-or-later. The source is not vendored.
- CTAN `cmap` 1.0j (2021-02-06):
  https://tug.ctan.org/macros/latex/contrib/cmap.zip
  Archive SHA-256: b5fffa016ac4571f0405592ac40bf231f9ddb6b1ce3100d17a33833284bbeb84.
  `t1.cmap` SHA-256: e43d20b203a25786d101e757d312b3660bc2505d57251db7701cd3f69e6d1f42.
  License: LPPL. Neither archive nor CMap is vendored.
- EC fonts 1.0 source archive:
  https://tug.ctan.org/fonts/ec.zip
  SHA-256: 364ea6dc4c05ca49833c31f8bb510bd7cd94142e8e934c59df48a950695c9ed4.
  Its custom distribution and renaming terms are why no EC font source is
  vendored.
- Adobe Glyph List repository, commit
  `4036a9ca80a62f64f9de4f7321a9a045ad0ecfd6`:
  https://github.com/adobe-type-tools/agl-aglfn
  License: BSD-3-Clause. Used only to corroborate glyph-name semantics.

## Normalization policy

Cork/T1 is a font-glyph encoding, so one lossless Unicode interpretation does
not exist. `cork_t1_slots.csv` records two named mappings:

- `TEX-T1-EC-GLYPH` follows EC glyph identities. Slot DF is the exact semantic
  sequence U+0053 U+0053 because classic EC draws two capital S glyphs.
- `TEX-T1-CMAP-1.0J` follows CTAN `TeX-T1-0` Unicode extraction. Its inverse
  encoder is an Iconvex-defined deterministic longest-match policy.

Slot 18 (`perthousandzero`) has no Unicode mapping and is undefined in both
profiles. U+2080 is not used as a visual substitute. Slot D0 is overloaded by
LaTeX as both `\DH` and `\DJ`; the recorded base profiles use the `/Eth` glyph
identity U+00D0 and document the unresolved U+0110 semantic alternative.

Both profiles define 255 bytes. The EC profile has 254 scalar mappings and one
sequence; U+002D canonically encodes as byte 2D because byte 7F duplicates it.
The CMap profile has 249 scalar mappings and six sequences, with 255 unique
outputs. They differ at exactly nine slots: 17, 1B, 1C, 1D, 1E, 1F, 7F, 95,
and B5. Both profiles deliberately map classic slot DF to the exact `SS`
sequence; treating it as U+1E9E would create a tenth but inexact difference.

GNU libiconv does not expose Cork/T1, so it is not a differential oracle for
these profiles. Conformance is anchored to the pinned source hashes above.
