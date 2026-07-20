# U.S. Army GTA 31-70-001 Tap Code pair-value profile

The project-authored `pairs.csv`, this metadata, and the codec implementation
are licensed under **LGPL-2.1-or-later**, matching GNU libiconv and Iconvex
Specs. The external publications below are reference-only evidence and are not
redistributed in this package.

## Exact source-qualified profile

This profile implements only the fixed “Prisoner of War Tap Code” word matrix
printed inside U.S. Army GTA 31-70-001, January 2015. It deliberately does not
claim the generic names `TAP-CODE`, `KNOCK-CODE`, or `POLYBIUS-SQUARE` because
other tap-code matrices and physical conventions exist.

The Army card specifies:

- a five-by-five matrix whose rows are `ABCDE`, `FGHIJ`, `LMNOP`, `QRSTU`,
  and `VWXYZ`;
- first, tap down the `A-F-L-Q-V` column to the desired row;
- second, tap across that row to the desired letter;
- use `C` in place of `K`;
- the system may be conveyed orally, visually, or by touch, with examples
  including sweeping, chopping, whistling, and musical instruments.

The decoded Unicode repertoire is therefore the 25 uppercase Basic Latin
letters U+0041..U+005A excluding U+004B. Encoding additionally accepts U+004B
and emits the same pair as U+0043. Decoding that pair canonically returns `C`,
so K input is deliberately lossy. Lowercase, case folding, normalization,
spaces, punctuation, and all other Unicode scalars are outside this profile.

The card labels this part “Communicating Words” but defines no in-band word
separator. No Unicode space is encoded. It defines communicating numbers as a
separate timing and gesture mode: slow taps, longer pauses between numbers,
and the letter O for zero. That number mode and the separate hand-language
panel are not represented by this word-pair codec.

## Pair-value transport boundary

The Army source specifies ordered tap-count pairs, not computer bytes. To make
that abstract alphabet usable through Iconvex's binary codec API, this
source-qualified profile defines a project transport:

- each first (row) count is stored as one numeric octet `0x01..0x05`;
- each second (column) count follows as one numeric octet `0x01..0x05`;
- these are numeric count values, not ASCII digits;
- pairs are adjacent with no in-band separator;
- an odd final octet is an incomplete pair;
- any complete pair containing a value outside `0x01..0x05` is invalid.

Thus exactly 25 of the 65,536 possible octet pairs are valid and 65,511 are
invalid. The binary serialization is explicitly Iconvex-defined; it is not
presented as a U.S. Army wire-byte format. Packed-bit transport is not
applicable because tap counts are signal run lengths, not fixed-width bit code
units.

## Primary U.S. Army source

Publication: **GTA 31-70-001, Special Forces Survival, Evasion, Resistance,
and Escape Communications Techniques**, Headquarters, Department of the Army,
January 2015.

- Official Army Training Network repository URL:
  <https://rdl.train.army.mil/catalog-ws/view/100.ATSC/B18B36F6-2596-43BA-B50A-EFC562032BA9-1300757028781/gta31_70_001.pdf>
- Exact January 2015 production-sheet artifact used for visual verification:
  <https://asktop.net/wp/download/GTA/GTAx31-70-001xv2015x.pdf>
- Artifact SHA-256:
  `b1ba006ff9150582a6a40dc759ce3d4b21a8aa72f71b678ca80baff13bd75e3d`
- Artifact size: 5,069,379 bytes; one 576-by-864-point PDF page.
- PDF title: `GTA 31-70-001 ID v07`; creation 2014-12-22 and modification
  2015-01-15 according to embedded metadata.
- Relevant location: the interior panel on physical PDF page 1.
- The artifact was rendered at 180 DPI and the exterior and complete interior
  were visually inspected. The matrix, first/second arrows, C/K diagonal,
  wording, number-mode distinction, publication identity, date, and release
  statement are legible and internally consistent.
- The sheet states “Approved for public release; distribution is unlimited.”
  It is treated as a U.S. government public-release reference artifact and is
  not copied into this package.

The mirror URL is pinned only to identify the exact audited bytes; the official
Army repository URL is the authoritative publication location.

## Independent U.S. Naval History source

Publication: Stuart I. Rochester, **The Battle Behind Bars: Navy and Marine
POWs in the Vietnam War**, Naval History & Heritage Command.

- Official Naval History URL:
  <https://www.history.navy.mil/content/dam/nhhc/research/publications/Publication-PDF/BattleBehindBars.pdf>
- Exact independently hosted artifact used for visual verification:
  <https://md.teyit.org/file/battlebehindbars2.pdf>
- Artifact SHA-256:
  `bfae22e1f86c310ce67eb12006b70eafea0fa89514c0c88f1212c739e5572735`
- Artifact size: 1,986,013 bytes; 76 PDF pages.
- Relevant location: physical PDF page 33, printed page 27, “The Tap Code.”
- That page was rendered at 180 DPI and visually inspected. It independently
  prints the same 25-letter matrix, says K is not used, defines the first
  number as the horizontal row and the second as the vertical column, gives
  `2-2` = G, `1-2` = B, and `4-5` = U, and explains that C denoted both C and K.
- It also records that POWs occasionally used scrambled matrices. That is why
  this implementation is fixed to the January 2015 Army card and does not
  claim a generic Tap Code identity.
- License/status: U.S. government historical publication, reference only; the
  local mirror artifact is not redistributed.

## GNU libiconv and variant audit

GNU libiconv 1.19 does not expose Tap Code in either the default catalog or the
`--enable-extra-encodings` catalog. This is expected: the source system is a
human signaling alphabet, and the numeric-octet pair serialization is an
explicit Iconvex project transport.

Audited GNU catalog fixtures:

- `encodings.def` SHA-256
  `156cc484a53109241e3c4d23e0ac1d75c0e199eac48f3de8e9d9e87ecc1ce5f1`
- `encodings_extra.def` SHA-256
  `0747ecd7a6311ea3fab734d666e49b17e39750a4ba5d498fee267132461e3303`
- default `iconv -l` output SHA-256
  `f747cadfad9e17ecfa455937b2f95e8bef5c747dcd989d66e52e4681e49b3da1`

Deliberately excluded names and domains: `TAP-CODE`, `KNOCK-CODE`,
`POLYBIUS-SQUARE`, `TAP-CODE-NUMBERS`, `TAP-CODE-HAND-LANGUAGE`, and
`TAP-CODE-SCRAMBLED-MATRIX`.

## Local mapping integrity

- `pairs.csv` SHA-256:
  `b9289530db75d795b65768b8be1add61a9d6ee20e6fb780a7b5bda853637e4cb`
- Schema: `row,column,unicode_hex,letter` followed by exactly 25 ordered rows,
  row-major from pair `1,1` through `5,5`, uppercase Unicode hexadecimal, LF
  endings, and exactly one final LF.
- K is intentionally absent; pair `1,3` decodes to U+0043 `C`.
