# MacOS Esperanto 0.3 source record

## Authoritative mapping

The normalized mapping is transcribed from Michael Everson's public
`MacOS_Esperanto` to-Unicode table:

- URL: https://www.evertype.com/standards/eo/eo-table.html
- page title: `Macintosh Esperanto Code Table`
- table version: `Table version: 0.3`, based on MacOS Turkish 0.2
- table date: 15 August 1997
- author: Michael Everson
- fetched: 2026-07-17
- fetched HTML size: 13,591 bytes
- fetched HTML SHA-256:
  `d7ca70a8da95d5ec5338705d3cd0907232eed98416fe062bb731d86090a52084`

The source header identifies Apple Computer, Inc. as the 1996 copyright
holder and describes the mapping table as preliminary. The upstream HTML is
not redistributed here. The CSV contains normalized mapping facts only.

## Normalization and transport policy

The source explicitly enumerates all 95 ASCII graphic positions `20..7E` and
all 128 high-half positions `80..FF`. Those 223 rows are reproduced without
semantic substitutions as `source_identity` or `source_mapping`.

Like the historical Apple mapping-table convention, the source omits C0 and DEL
(`00..1F`, `7F`) rather than assigning graphic characters there. Iconvex
uses the explicit Unicode-identity text transport for those 33 positions. This
policy preserves control bytes and does not claim that controls are part of the
MacOS Esperanto graphic repertoire.

The resulting 256 octet mappings are unique. Encoding is therefore the exact
inverse of decoding; there are no duplicate-preference rules and no undefined
octets. The encoding is one octet per unit, so a packed-bit transport is not
applicable.

Normalized CSV SHA-256:
`4ad11598020843b2728f438dc8e8e3149ee822ae03a688330ad0b80dc013aa05`.

## Names and scope

The canonical name preserves the source-table identifier `MACOS_ESPERANTO`.
The aliases `MACESPERANTO`, `MAC-ESPERANTO`, and `MACOS-ESPERANTO` are only
punctuation-normalized spellings of the same named mapping; they do not select
other Macintosh Roman variants.

GNU libiconv 1.19 does not expose MacOS Esperanto, MacEsperanto, or a matching
codec in its default or `--enable-extra-encodings` inventories. It is therefore
not used as a byte oracle for this codec.

The negative support audit is pinned to these GNU libiconv 1.19 fixtures:

- `encodings.def` SHA-256
  `156cc484a53109241e3c4d23e0ac1d75c0e199eac48f3de8e9d9e87ecc1ce5f1`
- `encodings_extra.def` SHA-256
  `0747ecd7a6311ea3fab734d666e49b17e39750a4ba5d498fee267132461e3303`
- default `iconv -l` output SHA-256
  `f747cadfad9e17ecfa455937b2f95e8bef5c747dcd989d66e52e4681e49b3da1`

## Licensing

The implementation and normalized table are distributed under
LGPL-2.1-or-later, matching GNU libiconv. The cited upstream page remains under
its stated Apple rights and is used as a reference source only.
