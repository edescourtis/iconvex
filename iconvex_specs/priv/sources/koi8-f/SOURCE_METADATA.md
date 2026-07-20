# KOI8-F / KOI8 Unified source provenance

Iconvex's `KOI8-F` codec is the source-qualified New Mexico State University
2008 Unicode mapping of Fingertip Software's KOI8 Unified character set.

## Creator specification

- Creator: Peter Cassetta, Fingertip Software.
- Archived specification:
  <https://web.archive.org/web/19980109123404id_/http://fingertipsoft.com/ref/cyrillic/koi8-uni.html>
- Retrieved: 2026-07-17.
- Retrieved HTML SHA-256:
  `d9e5d2825477b1e3c28ea917d615b0d938d8d97417b13875f20e0c5a6d10c59f`.
- The creator page defines the name and repertoire and explicitly records that
  positions 154 (`0x9A`) and 160 (`0xA0`) both contain NO-BREAK SPACE.
- The creator HTML remains at the cited archive and is not redistributed in
  this package.

## Exact Unicode mapping

- Publisher: Department of Mathematical Sciences, New Mexico State University.
- Mapping title: *KOI8 Unified Cyrillic to Unicode 2.1 mapping table*.
- Archived source:
  <https://web.archive.org/web/20200712005106id_/http://sofia.nmsu.edu/~mleisher/Software/csets/KOI8UNI.TXT>
- Retrieved: 2026-07-17.
- Vendored file: `KOI8UNI.TXT`, 10,503 bytes and 288 lines.
- SHA-256:
  `9b24e0aa3d0eaf1ebacfb7cbb1ef435793c7542a3cf99fc20f90923fccba15cd`.
- Coverage: every octet `0x00..0xFF`, with no undefined positions.
- The published mapping deliberately maps `0x95` to U+2219 BULLET OPERATOR to
  match RFC 1489 and preserves both NO-BREAK SPACE positions.

`KOI8-F-NMSU-2008` and the other source-qualified aliases make that mapping
choice explicit. Plain `KOI8-F` selects the same complete published mapping.
The source file grants permission under the MIT license; its notice is retained
verbatim and is also reproduced in `LICENSE.MIT-NMSU`, SHA-256
`453f7f1cbd5504398ebee03e90d7ebf1ccc80ef9661cabb779ce749099666ef4`.
Hex releases include this metadata file, the exact `KOI8UNI.TXT` mapping, and
`LICENSE.MIT-NMSU`; the original LGPL-2.1-or-later Elixir implementation is
licensed separately under the package's main `LICENSE`.
