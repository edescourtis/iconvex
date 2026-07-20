# TeX OML/OMS semantic mapping provenance

These two CSV files are independently authored compact factual numeric
transcriptions of the lower 128 entries in the `cmmi10` and `cmsy10`
ToUnicode CMaps emitted by the pinned LaTeX test artifact below. They are
maintained as Iconvex source data under `LGPL-2.1-or-later`.
No upstream source blob is redistributed here.

## Reviewed LaTeX source

- LaTeX stable tag: `release-2026-06-01`
- Commit: `7c8574ae28a5b257f7b92cc1e5e317255644e40d`
- Tree: <https://github.com/latex3/latex2e/tree/7c8574ae28a5b257f7b92cc1e5e317255644e40d>
- Golden artifact containing the CMaps: `required/latex-lab/testfiles-math/mathcapture-tag-001.tpf`
- Artifact URL: <https://raw.githubusercontent.com/latex3/latex2e/7c8574ae28a5b257f7b92cc1e5e317255644e40d/required/latex-lab/testfiles-math/mathcapture-tag-001.tpf>
- Artifact SHA-256: `e49bef156ccaf6f6e3616103a5ff6b0363aedb33ad06623fe63f6ccc41e2b72e`
- LaTeX Project Public License version 1.3c applies to the reviewed LaTeX
  sources; see the upstream repository for its complete notices.

The encoding guide defines OML and OMS over code positions `0x00..0x7F` and
uses `cmmi10` and `cmsy10` as the respective exemplars:

- `base/doc/encguide.tex`, SHA-256
  `514ebf9ce8d63fbac91fb19342d95eda05b9e4b77aaebbad50a830a099bfb5b8`
- <https://raw.githubusercontent.com/latex3/latex2e/7c8574ae28a5b257f7b92cc1e5e317255644e40d/base/doc/encguide.tex>
- `base/fontdef.dtx`, SHA-256
  `a3376423114232dc36439df7388b588d5b3bc42655d31f87800bb55fb0109dc4`
- `base/ltoutenc.dtx`, SHA-256
  `61cc867257831d2611e2d96ead2a1882f03e4da27c095b642cc866984aac0bc2`
- `base/cmfonts.fdd`, SHA-256
  `c255713697ef748c541dc7bceaf1ce5e78f5aad30c9de1d22b2c9413200cfb01`

The CMaps contain high-byte aliases used by Type 1 font mechanics. Those are
not positions in the official seven-bit OML/OMS encodings and are deliberately
excluded. Iconvex accepts exactly `0x00..0x7F` for these profiles.

## Computer Modern font-source cross-check

The CTAN `cm-mf` package (version date `2021-02-05`) is distributed under the
Knuth License, not the LGPL or LPPL. It was consulted only as a cross-check;
none of its Metafont sources are shipped.

- Package: <https://ctan.org/pkg/cm-mf>
- Archive: <https://mirrors.ctan.org/fonts/cm/mf.zip>
- Archive SHA-256: `b22c69034d9f3f7a9bf22673544bdeaace5656973cf7fb1a395a857148943076`
- `cmmi10.mf`: `5280e50e3f2f6b5a3cd3474de2259fc4f738043119985da9b57b37057eeb826f`
- `cmsy10.mf`: `02decdd50872beec303a73c295d43d62483eb6c2cad4d8ac3cf73982559101a2`
- `mathit.mf`: `ec1875f36663830fe52614ea378e4fdd907a8a425efa32fcb94ea55e394b34b6`
- `mathsy.mf`: `19dc81ad93629dd18678e0599335b4a874ef82ff2995ae751f98d4a1384aa44f`

TeX Live's `glyphtounicode.tex` was also reviewed at Subversion revision
29720 (SHA-256
`395e568c1f4db5e89013e6aa4aac22a668b543256a20b4349436070356870851`).
That generated file combines Adobe Glyph List and LCDF `texglyphlist`
material with mixed upstream licensing, so it is referenced but not vendored.

## Semantic and normalization limits

The tables are semantic ToUnicode mappings. They preserve every byte exactly
on decode followed by encode because all 128 Unicode targets in each table are
unique. Unicode cannot preserve every font-specific visual distinction:
OML italic and old-style-number styling, OMS calligraphic styling, and some
component-glyph intent remain typography rather than character identity.

No Unicode normalization is performed. In particular, OML byte `0x0A` is
U+2126 OHM SIGN even though NFC changes it to U+03A9, while compatibility
normalization can collapse OML U+2113 with ASCII `l` and OMS U+211C/U+2111
with ASCII `R`/`I`. The reverse maps therefore contain exact table targets
only and no normalization aliases.

Retrieval and transcription review date: `2026-07-17`.

Not shipped: any upstream `.dtx`, `.mf`, `.tpf`, PDF, or
`glyphtounicode.tex` source blob.
