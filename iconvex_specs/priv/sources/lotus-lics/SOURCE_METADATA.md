# Lotus International Character Set (LICS) source record

## Implemented profile

`lotus_lics_hp_1991.csv` is the complete 256-position Lotus International
Character Set profile printed in the second edition of the *HP 95LX User's
Guide*, June 1991, Appendix F.  This is an octet single-byte character set.
The normalized table is SHA-256
`2eedf12805e1aee25e37044ddf58c8fcdcb9e754f3c3776aeb8a0447674a5239`.

The implementation deliberately distinguishes this complete profile from the
earlier table for Lotus 1-2-3 Release 2 and 2.01 in Xerox's May 1988 manual.
The Xerox table jumps from decimal 150 to 160.  The later HP table assigns
0x97, 0x98, 0x9A, and 0x9B to up triangle, down triangle, hard space, and left
arrow respectively.  Those four rows therefore carry `hp_1991_extension`
provenance; no other undocumented profile is merged into the codec.

## Authoritative manuals and original vendor artifact

1. Hewlett-Packard Company, *HP 95LX User's Guide*, second edition, June 1991,
   publication F1000-90001, Appendix F “Lotus International Character Set
   (LICS)”, physical PDF pages 792–798 / printed pages F-1 through F-7.
   The scan was visually audited at original resolution.

   - URL: https://www.retroisle.com/others/hp95lx/OriginalDocs/95LX_UsersGuide_F1000-90001_826pages_Jun91.pdf
   - Size: 7,575,631 bytes
   - SHA-256: `358d8b5b06cc196034fcb54af77388cc0d75f58513f7ea4dd4cc6488e04ef621`

2. Xerox Corporation, *Xerox ViewPoint File Conversions Reference, Volume 10*,
   May 1988, publication 610E12320, Table 6-19 “LICS, XCCS, ASCII Character Set
   conversions”, physical PDF pages 166–179 / printed pages 6-19 through 6-32.
   This independent vendor interoperability table was visually audited at
   original resolution and agrees with every shared assignment.

   - URL: https://bitsavers.org/pdf/xerox/viewpoint/VP_2.0/610E12320_File_Conversion_Reference_Volume_10_May88.pdf
   - Size: 11,527,427 bytes
   - SHA-256: `dd588f6a90c38ce9ae612a25439310f7a374581facbdf2325f2b05dd8863e72c`

3. The Internet Archive item “Lotus 1-2-3 Release 2” supplies the original
   Lotus Development Corporation release files.  It proves the vendor,
   product, and release context; it is not used as a Unicode mapping oracle
   because this extracted archive has no separate `LICS.EAT` table.

   - URL: https://archive.org/download/Lotus1-2-3Release2/files_extracted.zip
   - Size: 728,366 bytes
   - SHA-256: `3fd743be6e67450d889a1bc4164e12f7edb6dbe106b6915768eabff545e35beb`

The copyrighted manuals and Lotus archive are reference-only and are not
redistributed in this package.  Only this provenance record and the normalized
factual mapping oracle are packaged.

## Unicode normalization and transport policy

- HP explicitly classifies codes 0 through 31 as controls.  They use Unicode
  control identity U+0000 through U+001F.
- HP explicitly calls codes 32 through 127 the standard ASCII characters.  In
  particular, byte 0x7F is U+007F DELETE, not a display-only shade glyph.
- HP's black “unknown character” positions, corroborated by omissions in the
  Xerox conversion table, are explicit invalid bytes: 0x85–0x8F, 0x99,
  0x9C–0x9F, and 0xFF.
- The upper- and lowercase compose accents at 0x80–0x84 and 0x90–0x94 use the
  corresponding Unicode combining marks.  Each pair therefore decodes to one
  scalar.  The lowest-byte canonical encoder selects 0x80–0x84; the alternate
  bytes remain valid decoder inputs and are tested explicitly.
- Byte 0x96, shown as an underlining ordinal/compose mark, is normalized to
  U+0331 COMBINING MACRON BELOW.  Byte 0xB5 is U+00B5 MICRO SIGN, matching the
  source's “micro” semantics rather than Greek letter mu.
- All remaining graphic rows follow the character identity printed in the two
  vendor tables.  The CSV records 239 assigned bytes, 17 invalid bytes, 234
  distinct Unicode scalars, and five duplicate scalar pairs.
- Units are exactly 8 bits.  Packed-bit transport is inapplicable to this
  octet codec.

## GNU libiconv comparison

GNU libiconv 1.19 does not expose LICS in either its default inventory or its
`--enable-extra-encodings` inventory, so GNU byte-for-byte comparison is
unavailable.  The negative inventory fixtures are pinned as follows:

- `encodings.def`: `156cc484a53109241e3c4d23e0ac1d75c0e199eac48f3de8e9d9e87ecc1ce5f1`
- `encodings_extra.def`: `0747ecd7a6311ea3fab734d666e49b17e39750a4ba5d498fee267132461e3303`
- default `iconv -l`: `f747cadfad9e17ecfa455937b2f95e8bef5c747dcd989d66e52e4681e49b3da1`

## License

The Iconvex implementation, tests, normalized mapping oracle, and this source
record are distributed under LGPL-2.1-or-later, the same license family as GNU
libiconv.  No claim is made over the underlying character-set facts or the
copyrighted reference publications.
