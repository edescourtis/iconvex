# VSCII-2 / TCVN 5712:1993 VN2 source metadata

The project-authored `vscii2.csv` is licensed under **LGPL-2.1-or-later**, the
same license as GNU libiconv and Iconvex Specs. External standards and mapping
artifacts listed below are reference-only verification inputs and are not
redistributed here.

## Exact profile and byte semantics

This codec is the VN2 profile of TCVN 5712:1993: the right-hand 96-character
graphic set registered as ISO-IR-180 and commonly called `VSCII-2` or `VSCII`.
It is not RFC 1456 `VISCII`, and it is not the VN1 encoding that GNU libiconv
calls `TCVN` / `TCVN5712-1`.

- Bytes `00..7F` are exact ASCII/C0/DEL identity.
- Bytes `80..9F` are undefined. ISO-IR-180 designates a 96-character graphic
  set for columns 10 through 15; it does not designate the C1 area.
- Bytes `A0..FF` are the 96 ISO-IR-180 graphic positions in order.
- The complete domain therefore has 224 assigned bytes and 32 undefined bytes.
- All 224 assigned Unicode scalars are unique, so encoding is the exact
  bijective inverse of decoding.
- Positions `B0..B4` include raw Unicode combining marks U+0300, U+0309,
  U+0303, U+0301, and U+0323. Conversion performs no normalization and does
  not infer composed or decomposed equivalents. A Unicode scalar is encodable
  only when it is explicitly assigned by the table.
- Packed-bit transport is not applicable: VSCII-2 is an octet codec.

## Primary registration

Official ISO/IEC 2375 registration maintained by ITSCJ:

- URL: <https://itscj.ipsj.or.jp/ir/180.pdf>
- Artifact SHA-256:
  `a02cf84237d0344f2ef1d09f125a4fa5ea5464bdf1d90bd8e537bac04c9090a0`
- Artifact size: 998,754 bytes; six PDF pages.
- Registration number 180; registration date 1993-11-01.
- Page 1 names the set “Right-hand Part of the VSCII-2 Code Table”, says it is
  a 96-character graphic set intended for columns 10 through 15 of an 8-bit
  VSCII code, and identifies the origin as TCVN 5712-1993 (VSCII), 12 May 1993.
- Page 2 provides the full coded layout. Pages 3 through 5 enumerate all 96
  graphic positions and character names. Page 6 repeats the right-hand chart.
- All six pages were rendered and visually inspected during the audit.
- License/status: copyrighted standard registration, reference only; not
  copied into this package.

The primary registration supplies character names rather than modern Unicode
numbers. Those names were resolved against UnicodeData 17.0. The resulting 96
high-byte mappings had zero name mismatches against the independent VN2
charmap below.

## Official Vietnamese standard catalog

Vietnamese Standards Quality Institute catalog record:

- URL:
  <https://tieuchuan.vsqi.gov.vn/tieuchuan/view?sohieu=TCVN+5712%3A1993>
- Retrieved HTML SHA-256:
  `5b5a8909bb9b7ca9e6dbe6f390466657f341d182e7c11afcf94242df4fa980b1`
- Retrieved size: 32,280 bytes.
- It identifies TCVN 5712:1993 and the official English title “Information
  technology - Vietnamese 8 bit standard coded character set for information
  interchange”, lists 18 pages, and records that the 1993 edition was
  withdrawn and replaced by the 1999 edition.
- License/status: VSQI copyrighted catalog/standard material, reference only.

## Independent exact implementation

Python issue attachment by Jean Christophe André:

- URL: <https://bugs.python.org/file37055/TCVN5712-2.TXT>
- SHA-256:
  `4b2385eed17f8aa30b3299ddc924b83bff6479f43befbb7619d81a97b04b920b`
- It explicitly identifies TCVN 5712:1993 VN2 and the aliases `tcvn-vn2` and
  `vscii-2`, and contains 256 ordered byte rows.
- Exact comparison: `00..7F` identity, `80..9F` undefined, and all 96 mappings
  at `A0..FF` agree with the ISO-IR-180-name-to-Unicode transcription.
- License/status: Python issue contribution with a recorded PSF contributor
  agreement; reference only. No attachment text is distributed here.

Unicode character-name source:

- URL: <https://www.unicode.org/Public/17.0.0/ucd/UnicodeData.txt>
- SHA-256:
  `2e1efc1dcb59c575eedf5ccae60f95229f706ee6d031835247d843c11d96470c`
- Artifact size: 2,198,209 bytes.
- License/status: Unicode Data Files and Software License, reference only.

## GNU libiconv 1.19 audit

GNU libiconv 1.19 does not expose VSCII-2, VN2, or ISO-IR-180 in either its
default catalog or its `--enable-extra-encodings` catalog. It exposes RFC 1456
`VISCII` and the distinct VN1 profile as `TCVN`, `TCVN-5712`, `TCVN5712-1`,
and `TCVN5712-1:1993`.

The audited GNU catalog fixtures are:

- `encodings.def` SHA-256
  `156cc484a53109241e3c4d23e0ac1d75c0e199eac48f3de8e9d9e87ecc1ce5f1`
- `encodings_extra.def` SHA-256
  `0747ecd7a6311ea3fab734d666e49b17e39750a4ba5d498fee267132461e3303`
- default `iconv -l` output SHA-256
  `f747cadfad9e17ecfa455937b2f95e8bef5c747dcd989d66e52e4681e49b3da1`

Because GNU libiconv has no VSCII-2 converter, the production benchmark uses
an independent generic Elixir table reference; a GNU timing comparator is
reported as unavailable rather than comparing the wrong Vietnamese codec.

## Names and deliberate exclusions

Canonical name: `VSCII-2`.

Exact aliases: `VSCII`, `TCVN-5712-2`, `TCVN5712-2`,
`TCVN5712-2:1993`, `TCVN-VN2`, `VN2`, and `ISO-IR-180`.

Deliberately excluded related or ambiguous names: `VISCII`, `VSCII-1`,
`VSCII-3`, `TCVN`, `TCVN-5712`, `TCVN5712-1`, `TCVN5712-1:1993`, `TCVN3`,
`VN1`, `VN3`, and `x-viet-tcvn5712`.

## Core registry finding and integration state

At audit start, the core registry routed `ISO-IR-180` to `:viscii`, the
unrelated RFC 1456 VISCII codec. Shared integration work removed that misalias
during this audit, so the current built-in target is intentionally unregistered
and the core misalias has been removed. Remaining integration must add this
module to Iconvex Specs' external codec list and thereby route `ISO-IR-180` to
the external `:vscii_2` codec; it must also package this source directory and
regenerate shared counts, inventories, catalog status, and documentation. The
isolated implementation itself did not edit those shared files.

## Local mapping integrity

- `vscii2.csv` SHA-256:
  `719bd06c76a258e414f422093b49a7687da111e9cbf2fab14194ff57e2d6f127`
- Format: exactly 256 ordered rows after
  `byte_hex,unicode_hex,status`, uppercase hexadecimal, LF endings, and exactly
  one final LF.
- Undefined rows are explicit rather than inferred.
