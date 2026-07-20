# Luxor ABC 800 BASIC II character-mode source metadata

This directory contains an Iconvex-authored factual transcription of the
seven-bit character-mode table in Luxor's *ABC 800 BASIC II* manual. The
transcription and the Elixir implementation are licensed under
LGPL-2.1-or-later. The copyrighted manual is referenced but is not
redistributed.

## Exact profile implemented

The implementation is the manual's 1981 ABC 800 **character mode**. It has 128
positions: controls and DEL retain their code-point values; printable slots
use the Swedish ABC 800 repertoire recorded in `character_mode.csv`. Octets
`80..FF` are outside this seven-bit code and are invalid.

The same manual prints a distinct graphics-mode table. That distinct ABC 800
graphics mode is not implemented by this profile. For that reason the canonical name is
`LUXOR-ABC800-BASIC-II-1981-CHARACTER-MODE`, the only short alias is
`ABC800-CHARACTER-MODE`, and the ambiguous names `ABC800` and `ABC-800` are
deliberately not claimed.

Every defined character-mode code point is unique. Encoding is therefore the
exact inverse with no duplicate-selection policy. This is a seven-bit code
stored one code per octet; it is not an odd-width packed transport.

## Primary source

- Publisher: Luxor Industri AB.
- Title: *ABC 800 BASIC II*, part number 1510070-11, 1981.
- Relevant material: Appendix 4, the control-code table and the adjacent
  character-mode / graphics-mode code tables (physical PDF pages 113-114).
- Retrieval URL:
  https://www.abc80.net/archive/luxor/ABC80x/ABC800-manual-BASIC-II.pdf
- Retrieved artifact size: 19,396,994 bytes.
- PDF SHA-256:
  `c5bc63ce12c37d47e2fbfbb9118e581b4738c9f8b9de8d4b0f421328c2f2e3b5`.
- Retrieved for verification: 2026-07-18.

## Normalized mapping

`character_mode.csv` has one row for each code `0..127`, in numeric order.
Unicode character names document the transcription but are not runtime input.
Its exact SHA-256 is
`3afa26503fb3812e0e61c80ab4fbabe6bc4843cd0b9b2db67ba7da6395f85846`.

The manual's printed glyph at decimal 39 is the spacing acute accent and is
normalized to U+00B4. Decimal 95 is LOW LINE U+005F. The national replacement
positions are transcribed literally: É, Ä, Ö, Å, Ü, é, ä, ö, å, and ü. No OCR
output is used by the codec at build time or runtime.

GNU libiconv 1.19 does not expose this source-qualified ABC 800 profile in its
default or `--enable-extra-encodings` catalog, so no GNU differential result is
claimed for it.
