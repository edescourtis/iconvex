# Source-qualified glyph-vector to Unicode metadata

Iconvex implementation code and the normalized hexadecimal mapping CSV files
are distributed under `LGPL-2.1-or-later`. The profiles deliberately combine a
pinned encoding vector with a pinned Adobe Glyph List (AGL) revision: an
encoding vector selects glyph names, while AGL supplies the Unicode scalar for
each selected name. This source qualification does not imply Adobe authorship, affiliation, approval, or endorsement of Iconvex.

## Adobe Glyph List pin

- Repository: <https://github.com/adobe-type-tools/agl-aglfn>
- Commit: `4036a9ca80a62f64f9de4f7321a9a045ad0ecfd6`
- `glyphlist.txt` size: 78,060 bytes
- `glyphlist.txt` SHA-256:
  `a3b2f61ced9f3644cc0d4ecde5c59df34ca286c689d9484a43a710a81c466789`
- Upstream license: `BSD-3-Clause`; its verbatim terms are retained in
  `AGL_LICENSE.md`.

## CTAN LY1 / TeX'n'ANSI profile

- Canonical profile: `CTAN-LY1-TEXNANSI-1.1-AGL-4036A9CA`
- CTAN archive: <https://mirrors.ctan.org/fonts/psfonts/ly1.zip>
- Retrieved archive SHA-256:
  `e6a43938a3b8e375fe52763a1cab1de849879d4bb4b0998414c190ad20f07e0a`
- Verbatim `texnansi.enc` version/date: 1.1, 1996-12-01
- Verbatim vector size: 6,938 bytes
- Verbatim vector SHA-256:
  `cd006b13b530d7bfd386396c7f1138488d2b336f40508552b41952a83cdb0601`
- Normalized mapping SHA-256:
  `df9bb4301cb8280827f55c99224c03f8775e5767d6ded5741d4da68cdaa01d21`
- Upstream CTAN bundle license: `LPPL-1.0-or-later`. The bundle's
  `ly1/README.md` applies LPPL version 1 or, at the recipient's option, any
  later version to every file in that directory; its SHA-256 is
  `60ceab0c10da129230b18dbd73ef8994dad546e21197298e6d7930d9f8dc20e0`.
- Complete LPPL 1.0 terms: `licenses/upstream/LPPL-1.0.txt`, copied verbatim
  from <https://www.latex-project.org/lppl/lppl-1-0.txt>, SHA-256
  `89358c7072db622ba6d8ac9b4a322984853dd6d870f93c39efdb3f6a22719cd2`.

The vector has five `.notdef` entries. Its sixth non-text position is byte
`0A`, glyph name `cwm`: the source marks it as an internal boundary character,
and pinned AGL has no `cwm` mapping. Those six bytes are invalid. The remaining
250 positions decode through AGL. Duplicate Unicode scalars encode to the
lowest source byte.

## PostScript LanguageLevel 3 ISOLatin1Encoding profile

- Canonical profile: `ADOBE-POSTSCRIPT-3-ISOLATIN1-AGL-4036A9CA`
- Primary source: Adobe, *PostScript Language Reference*, third edition,
  Appendix E, Table E.7 (printed page 785; PDF page 799):
  <https://www.adobe.com/jp/print/postscript/pdfs/PLRM.pdf>
- Retrieved PDF size: 7,771,729 bytes
- Retrieved PDF SHA-256:
  `6b29e79e4ab64aaa61a3fb27a0f36838c01f2530362873ac316bdb493a1bab6b`
- Normalized vector SHA-256:
  `2d48471248773a8faa94fb773707b05ac8b757cca1b53f3a267792e0f3697315`
- Normalized mapping SHA-256:
  `926b7598f3738ab3db3e2315daeace041aec7570270702fb1b19eccb7418e624`

The copyrighted PLRM is referenced and digest-pinned but is not redistributed.
`postscript3_isolatin1_vector.csv` is an Iconvex-authored factual transcription
of the 256 positions. Table E.7 assigns 205 glyphs; the other 51 positions are
invalid. AGL is applied literally: for example, octet `A0` selects `/space`
(U+0020), octet `AD` selects `/hyphen` (U+002D), and octet `60` selects
`/quoteleft` (U+2018). This is therefore not an alias for ISO-8859-1.

GNU libiconv 1.19 does not expose either source-qualified composite profile, so
no exact GNU differential or throughput comparator is claimed.
