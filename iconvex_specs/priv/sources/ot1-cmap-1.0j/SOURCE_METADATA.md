# CTAN cmap 1.0j OT1 source metadata

Iconvex's implementation code is distributed under `LGPL-2.1-or-later`.
The verbatim upstream `ot1.cmap` and `ot1tt.cmap` reference artifacts are
from Vladimir Volovich's CTAN `cmap` package 1.0j and retain the upstream
`LPPL-1.3c-or-later` terms. They were extracted without modification from:

- <https://tug.ctan.org/macros/latex/contrib/cmap.zip>
- archive SHA-256: `b5fffa016ac4571f0405592ac40bf231f9ddb6b1ce3100d17a33833284bbeb84`
- `ot1.cmap` SHA-256: `2c7325ed9ad97da701f43737f0762c181878b8d770b5abf37df8728216f9e646`
- `ot1tt.cmap` SHA-256: `58b4f178ac815587ccf5165cd3cc13816000f1338b05706717bdbc8345d75af3`
- The same archive's `cmap.sty`, SHA-256
  `67123f5846b014963904c7395605d3521e98e11493be933aacf45e2bb3c12327`,
  applies the LPPL to a program it expressly defines as including both
  `ot1.cmap` and `ot1tt.cmap`. The source uses the generic LPPL name; the
  release records its current versioned grant as `LPPL-1.3c-or-later`.
- Complete LPPL 1.3c terms: `licenses/upstream/LPPL-1.3c.txt`, copied verbatim
  from <https://www.latex-project.org/lppl/lppl-1-3c.txt>, SHA-256
  `3d262cdf34dafa6955f703c634a8c238ec44109bc8dd6ef34fb7aa54809f7e66`.

The package README identifies the release as 1.0j (2021-02-06), explains
that `ot1tt.cmap` is selected for monospaced fonts, and therefore establishes
that OT1 normal and typewriter mappings are distinct profiles.

LaTeX's current source definition was independently pinned as a repertoire
cross-check, not substituted for the CMap Unicode extraction semantics:

- <https://github.com/latex3/latex2e/blob/5954204ffe58a81db0e0de1335c62cd45c8caf9b/base/ltoutenc.dtx>
- SHA-256: `61cc867257831d2611e2d96ead2a1882f03e4da27c095b642cc866984aac0bc2`

The normal profile maps 127 of the 128 seven-bit positions; byte `0x20` is
absent from the upstream CMap and is deliberately invalid here. The typewriter
profile maps all 128 positions and maps `0x20` to U+2423 OPEN BOX. Bytes
`0x80..0xFF` are outside both CMap code spaces. The normal profile's inverse
uses deterministic longest matching for `ffi`, `ffl`, `ff`, `fi`, and `fl`.

These are source-qualified Unicode-extraction profiles, not generic claims
about every historical OT1 font. GNU libiconv does not expose these source-qualified profiles,
so no exact GNU throughput or differential
comparator is available.
