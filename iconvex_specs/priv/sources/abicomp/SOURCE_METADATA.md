# ABICOMP / Brazil CP3848 source metadata

This directory contains only an Iconvex-authored factual transcription and this
provenance record. Both files are licensed under LGPL-2.1-or-later, matching
Iconvex and GNU libiconv. The referenced manuals and FreeDOS binary are not
redistributed here.

## Exact profile implemented

The canonical codec is the octet-oriented Brazilian ABICOMP text profile also
identified by printer vendors and FreeDOS as Brazil-ABICOMP / code page 3848.
Bytes `00..7F` map identically to Unicode `U+0000..U+007F`, including C0
controls and DEL. Bytes `80..9F` and `E0..FF` are undefined. Byte `A0` is
NO-BREAK SPACE, and every byte `A1..DF` has the mapping transcribed in
`abicomp.csv`. The resulting table has 192 defined bytes and 64 undefined
bytes. Every defined Unicode scalar is unique, so encoding uses the exact
bijective inverse and has no duplicate-resolution policy.

This is an 8-bit single-byte character set. Packed-bit transport is not
applicable.

## Independent exact mapping authorities

1. Star Micronics, *LC-8021 User's Manual* (1997), printed page 58, physical PDF
   page 64, table “Code Page #3848 Brazil-ABICOMP”. The table supplies the
   complete high half and states that the other characters are the same as code
   page 437.
   This entry pins the 3,261,185-byte Internet Archive artifact (PDF 1.2,
   modification date 1999-03-31). A distinct 3,260,460-byte PDF 1.3 artifact at
   minuszerodegrees.net has SHA-256
   `b47aa8daac993cdfa128f5036aa3cef8b5a05315b15c865cea509e3c88b80157`;
   both have 86 pages and render physical page 64 identically. Their differing
   whole-file digests therefore identify different containers, not conflicting
   editions or mapping tables.
   - Retrieval URL:
     https://archive.org/download/manuallib-id-2525457/2525457.pdf
   - PDF SHA-256:
     `c723b37df1b936606d960754713c23ed9ac11be1f0cb3365300fad1c9521724b`
   - License/status: copyrighted Star Micronics manual; reference only, not
     redistributed.

2. Epson, *Stylus Color 200 User's Guide* (1996), printed page B-5, physical PDF
   page 119, exact ABICOMP character table.
   - Retrieval URL:
     https://archive.org/download/manualzz-id-749516/749516.pdf
   - PDF SHA-256:
     `9c957a73217d9e39cfa9ba5c3f4b40cdcfe205e8b988ee2bf69268d12d8c697d`
   - License/status: copyrighted Epson manual; reference only, not
     redistributed.

3. FreeDOS CPIDOS 3.0, `BIN/ega18.cpx`, code page 3848. Its 8-, 14-, and
   16-pixel fonts independently confirm the assigned/blank ranges. In
   conjunction with both vendor tables, the blank slots establish the 64
   undefined bytes; `A0` is the intentional blank NO-BREAK SPACE.
   - Package URL:
     https://www.ibiblio.org/pub/micro/pc-stuff/freedos/files/dos/cpi/3.0/cpidos30.zip
   - Package SHA-256:
     `5af7b1064c946810453034aa689870ecf6b2d8640f5daec9c45496808afd50bc`
   - `BIN/ega18.cpx` SHA-256:
     `11944b119a838656de3fc795521e90bbc610b000fe603f95f8c685ee21216b1f`
   - Package license: GPL-2.0-or-later. The binary is used only as an external
     verification source and is not redistributed.

Wikipedia's ABICOMP table agrees with the transcription but is deliberately not
used as the mapping oracle.

## Names and variants

The exact aliases supported by this profile are `BRAZIL-ABICOMP`, `CP3848`,
`CODE-PAGE-3848`, and `FREEDOS-CP3848`.

HP PCL documentation names two symbol sets, `13P ABICOMP Brazil/Portugal` and
`14P ABICOMP International`, but the located primary PCL comparison material
does not give exact symbol maps. Therefore `PCL-13P`, `PCL-14P`, and
`ABICOMP-INTERNATIONAL` are not aliases and are not implemented by this
profile. Treating either PCL name as byte-identical would be an unsupported
claim.

## GNU libiconv comparison

GNU libiconv 1.19 does not expose ABICOMP or CP3848 in its default or
`--enable-extra-encodings` catalog. This was checked against the pinned
catalog fixtures:

- `encodings.def` SHA-256
  `156cc484a53109241e3c4d23e0ac1d75c0e199eac48f3de8e9d9e87ecc1ce5f1`
- `encodings_extra.def` SHA-256
  `0747ecd7a6311ea3fab734d666e49b17e39750a4ba5d498fee267132461e3303`
- default `iconv -l` output SHA-256
  `f747cadfad9e17ecfa455937b2f95e8bef5c747dcd989d66e52e4681e49b3da1`

No GNU differential benchmark is possible for a codec GNU libiconv does not
support.
