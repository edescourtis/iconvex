# DEC terminal character-set source metadata

## Normative DEC table

- Artifact: `EK-VT3XX-TP-002_VT330_VT340_Text_Programming_198805.pdf`
- Title: *VT330/VT340 Text Programming Reference Manual*, second edition,
  May 1988
- Publisher: Digital Equipment Corporation
- URL: <https://bitsavers.org/pdf/dec/terminal/vt340/EK-VT3XX-TP-002_VT330_VT340_Text_Programming_198805.pdf>
- SHA-256: `518676ad1188d4f75d0780e25f0a8fda2bb4a1a591902c6d62e1b9fde8042978`
- National Replacement Character Sets: Table 2-1, printed page 25 / PDF page 38
- DEC Special Graphic: Figure 2-7, printed page 26, PDF page 39
- DEC Technical: Figure 2-8, printed page 27, PDF page 40

The manual defines both sets as 7-bit, 94-position graphic sets. It explicitly
permits each set to replace ASCII in GL or DEC Supplemental Graphic in GR.
Iconvex therefore exposes GL and GR as separate byte profiles rather than
discarding bit 8 during conversion.

Table 2-1 exhaustively gives the twelve seven-bit NRC profiles by listing every
position that replaces ASCII: United Kingdom, Dutch, Finnish, French, French
Canadian, German, Italian, Norwegian/Danish, Portuguese, Spanish, Swedish, and
Swiss. All other positions retain ASCII, while high octets are outside these
seven-bit sets. Six mappings are byte-exact with existing RFC 1345 codecs, but
all twelve DEC profile names use dedicated native fast paths. Every profile
also has explicit packed MSB- and LSB-first septet transports.

## Unicode mapping evidence

- Artifact: `Unicode_L2_1998_354_Terminal_Character_Sets_Proposal.pdf`
- Title: *Proposed New Characters for Terminal Emulation*, Unicode L2/98-354
- URL: <https://www.unicode.org/L2/L1998/98354.pdf>
- SHA-256: `c50253ab97f2e155f55c920f9e11e449c3a11f955ee585327ef033c647fa1c78`
- Relevant material: section 6 and Table 6.1 on PDF pages 10-11; section 7
  and Table 7.1 on PDF pages 12-13

The 1998 proposal identifies the DEC table positions behind the extensible
math and terminal-graphics characters later standardized in Unicode. The
codec uses their assigned Unicode 17 values, including U+23B2/U+23B3 for the
summation top/bottom, U+23B4/U+23B5 for its joining corners, U+23B7 for the
small radical, and U+23BA..U+23BD for scan lines.

The modern U+1FB95 CHECKER BOARD FILL assignment is independently backed by
the pinned Unicode WG2 N5028 mapping source at
`../iso-ir-mosaic-technical/unicode-mappings/n5028.pdf`, URL
<https://www.unicode.org/L2/L2022/22020r2-n5028.pdf>, SHA-256
`e64a54b4b223b5e6a9d686a7a7ddd1fc98d0bc88585059be02078b082a760e61`.
No private-use code point is needed in the published mapping.

## Independent historical implementation cross-check

- Artifact: `kermit/ckcuni.c`
- Project: C-Kermit/Kermit 95
- Repository: <https://github.com/davidrg/ckwin>
- Revision: `8e977425d2f7f618d14aa466d516e9b79787ffc6`
- SHA-256: `af93d5a1c779aa73fa3221ab5ec0125de20267110cf23395971ce35cc88527ca`
- Relevant tables: `u_dectech`, `u_decspec`, and the twelve NRC `u_*` tables
- License artifact: `kermit/COPYING`
- License SHA-256: `067b8c8fc98d9359dfbd211820e1d57bed1e173144a184a21e8ead802b6502be`

Kermit's custom-font branch preserves historical private-use assignments for
several joining pieces that were not encoded when that table was written.
Those entries are audit evidence only: their later standardized Unicode
characters are used here. Kermit's BSD-style license applies to the pinned
cross-check artifact; Iconvex Specs remains LGPL-2.1-or-later.

The NRC audit found two additional source defects and follows the DEC manual:
Kermit's Dutch table uses U+00A4/U+0027 where Table 2-1 specifies U+0192/U+00B4,
and its Portuguese table is a six-position copy of Norwegian/Danish rather
than the manual's Ã/Ç/Õ and ã/ç/õ replacements. Permanent tests assert both
difference counts so neither implementation can silently regress to those
historical mistakes.
