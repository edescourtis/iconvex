# IBM 24/26 special-character arrangement source record

## Primary source and exact scope

The implementation follows International Business Machines Corporation,
*Reference Manual: IBM 24 Card Punch; IBM 26 Printing Card Punch*, publication
**A24-0520-3**, Minor Revision, October 1965. The exact visually audited scan is
vendored in this source tree as
`A24-0520-3_24_26_Card_Punch_Reference_Manual_Oct1965.pdf`.

- Authoritative mirror URL:
  <https://bitsavers.org/pdf/ibm/punchedCard/Keypunch/024-026/A24-0520-3_24_26_Card_Punch_Reference_Manual_Oct1965.pdf>
- SHA-256: `8d1f8e0b937989fa720d434b636bc829899414b7f11396b436ccd68b2265c91b`
- Size: 6,161,673 bytes; 41 physical PDF pages.
- Identity/revision evidence: physical PDF pages 1-3.
- Exact ten-arrangement special table: physical PDF page 28 / printed page 27 / Figure 23.
- Shared space, digits, letters, and punch-row semantics: physical PDF page 37 / printed page 36 / Figure 28.

The 110 rows in `figure_23_arrangements.csv` are a literal, row-major
transcription of Figure 23: arrangements A, B, C, D, E, F, G, H, J, and K,
then the eleven printed columns from `12` through `4-8`. Each cell retains its
logical twelve-row card mask. Every row is accepted by the decoder.

The shared repertoire is no-punch SPACE, digits 0-9, and uppercase A-Z. The
manual's combination-keyboard summary and diagram explicitly show their
ordinary IBM card punches. It is generated as 37 common rows rather than
repeated ten times in the compact Figure 23 extraction.

## Unicode semantics and duplicate punches

- The box-like graphic printed at `12-4-8` in arrangements A-D, G, and J is
  **U+2311 SQUARE LOZENGE**, matching the established Unicode semantic for the
  IBM card-code graphic rather than an ASCII approximation.
- Arrangement H explicitly labels its `4-8` graphic “Prime Sign”; it is
  **U+2032 PRIME**, not U+0027 APOSTROPHE.
- All other cells use the Unicode identity of the printed graphic.

The encoder's deterministic reverse policy is **base-before-Figure-23, then left-to-right**.
Shared SPACE/alphanumeric punches win first; otherwise the
first Figure 23 column containing a graphic is canonical. Later duplicates
remain accepted decode aliases. This gives the following six alternates:

- arrangement C: `0-1` decodes as `0`; encoding `0` uses the ordinary `0` row;
- arrangement D: `11` decodes as `-`; encoding `-` uses `12`;
- arrangement E: `11-3-8` decodes as `.`; encoding `.` uses `12-3-8`;
- arrangement F: `4-8` decodes as `-`; encoding `-` uses `11`;
- arrangement G: `3-8` decodes as `+` and `4-8` decodes as `-`; encoding uses
  `12` for `+` and `11` for `-`.

Each arrangement therefore accepts 48 masks. Arrangements A, B, H, J, and K
have 48 canonical Unicode scalars; C, D, E, and F have 47 plus one alias; G
has 46 plus two aliases.

## Names and transport boundary

The source specifies logical punched-card columns, not a byte serialization.
Each arrangement is therefore exposed as a logical 12-bit MSB-packed profile,
with an explicitly named nonstandard LSB-packed API. Registered binary codecs
use project-defined, zero-padded 16-bit words in explicit big- or little-endian
order. Values above `0x0FFF` are invalid words.

The catalogue names “IBM 026 Commercial card code” / `BCD-A` and “IBM 026
FORTRAN card code” / `BCD-H` are retained as aliases of arrangements A and H,
respectively, using the independently pinned University of Iowa historical
inventory only for those names. The primary IBM manual remains the mapping
authority for all ten arrangements. Generic names `IBM-24`, `IBM-26`, and
`IBM-026` are deliberately unclaimed because they do not select an arrangement
or transport. The exact spaced catalogue names remain logical-profile aliases;
registered byte transports use only their printable hyphenated and `BCD-*`
aliases with explicit `-16BE` or `-16LE` suffixes.

## GNU libiconv and license

GNU libiconv 1.19, including `--enable-extra-encodings`, does not expose these
logical IBM 24/26 punched-card arrangements. Conformance is therefore measured
against the exact primary-source extraction and exhaustive native-reference
tests, not a GNU byte codec.

The Iconvex implementation, tests, normalized factual extraction, and this
metadata are distributed under **LGPL-2.1-or-later**, matching GNU libiconv and
Iconvex Specs. The IBM manual remains copyrighted reference material; it is
not relicensed under LGPL and is excluded from the Hex package artifact.
