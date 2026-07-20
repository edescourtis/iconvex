# BraSCII / Brazil-ABNT source metadata

This directory contains Iconvex's normalized Unicode mapping for the Brazilian
Code for Information Interchange, standardized as **ABNT NBR 9611:1991**
("Information technology - Brazilian code for information interchange -
Standardization", 14 pages). The earlier edition was NBR 9614:1986.

## Exact graphical mapping evidence

Two independent manufacturer manuals publish the same complete high-half table:

1. **Epson Stylus COLOR 200 User's Guide**, Appendix B, PDF page 119,
   printed page B-5, table labelled `BRASCII`.
   - Pinned URL:
     https://files.support.epson.com/pdf/sc200_/sc200_u1.pdf
   - Retrieved: 2026-07-17
   - SHA-256:
     `9c957a73217d9e39cfa9ba5c3f4b40cdcfe205e8b988ee2bf69268d12d8c697d`
   - The preceding page states that all non-italic tables use the PC437
     assignments for `00..7F`, and that the remaining tables show
     `80..FF`. The BraSCII table visibly assigns the Latin repertoire and
     the two distinctive OE positions.

2. **Star Micronics LC-8021 User's Manual**, PDF page 64, printed page 58,
   table `Code Page #3847 Brazil-ABNT`.
   - Original manufacturer URL (no longer live):
     https://www.star-m.jp/eng/service/usermanual/lc8021um.pdf
   - Primary audited Archive.org derivative:
     https://archive.org/download/manuallib-id-2525457/2525457.pdf
   - Retrieved: 2026-07-17
   - SHA-256:
     `c723b37df1b936606d960754713c23ed9ac11be1f0cb3365300fad1c9521724b`
   - Byte length / container: 3,261,185 bytes, PDF 1.2.
   - Independently hosted derivative:
     https://minuszerodegrees.net/manuals/Star%20Micronics/dot_matrix/Star%20Micronics%20-%20LC-8021%20-%20Users%20Manual.pdf
   - Independent derivative SHA-256:
     `b47aa8daac993cdfa128f5036aa3cef8b5a05315b15c865cea509e3c88b80157`
   - Byte length / container: 3,260,460 bytes, PDF 1.3.
   - These are distinct PDF containers of the same 86-page scan, not a digest
     conflict. Rendering physical page 64 from each at the same 2x scale
     produced byte-identical 840x1190 RGB pixels with SHA-256
     `8f9a7a87454e8a58df381137714774844bd14a35ae5127a875a4eba0c9ebaca5`.
   - Pages 26 and 69 also identify the selectable code page number as 3847.

The ABNT catalog record is:
https://www.dinmedia.de/en/standard/abnt-nbr-9611/180541278

The base repertoire was checked against **ECMA-94, first edition, March 1985**:
https://ecma-international.org/wp-content/uploads/ECMA-94_1st_edition_march_1985.pdf
SHA-256
`dd7541b58618e2995f77e28b07434626e03b299df60039d2861e10d414600ba1`.
That standard corroborates the Latin positions but marks 13/07 and 15/07
(`D7` and `F7`) unused; the two manufacturer BraSCII tables are therefore
the exact evidence for BraSCII's U+0152/U+0153 overrides.

The normalized table is byte-for-byte identity for every position except:

- `D7 -> U+0152 LATIN CAPITAL LIGATURE OE`
- `F7 -> U+0153 LATIN SMALL LIGATURE OE`

Consequently U+00D7 MULTIPLICATION SIGN and U+00F7 DIVISION SIGN are not
representable.

## Control-byte transport policy

NBR 9611 and the cited printer charts define a graphical repertoire, while
printer firmware also gives some high-bit byte values device-control effects.
Those device actions are not Unicode characters. For a deterministic text
codec, Iconvex classifies all 256 values and maps the C0 and C1 control ranges
to the same-number Unicode control code points. ASCII, DEL, and the C0 and C1
ranges therefore use the conventional ISO-8859-style identity transport.
This policy is explicit in the CSV and in `BraSCII.transport_policy/0`; it
does not reinterpret printer commands as text.

## Distribution and licensing

The upstream PDFs are not redistributed because their publication licenses do
not grant relicensing. Only their URLs, page locations, and cryptographic
digests are pinned here. `brascii_nbr_9611.csv` is a normalized factual table
authored for Iconvex and is distributed under **LGPL-2.1-or-later**, matching
the project.

GNU libiconv 1.19 does not expose BraSCII, Brazil-ABNT, or code page 3847, so
there is no GNU throughput comparator for this codec.
