# TI-89 / TI-92 Plus AMS 2.0 character-set evidence

The adjacent `mapping.csv` is an independently authored byte-to-Unicode
correspondence. It was transcribed and visually checked from Texas
Instruments' official guidebooks. No libticonv table was copied or transformed.

## Normative source

- Title: *TI-89 / TI-92 Plus Guidebook*, AMS 2.0
- URL: <https://education.ti.com/download/en/ed-tech/2110B5BC591D44E1AF4C28F00A6614B6/0470DB419F2144349E4032AFE3C0DD7E/8992bookeng.pdf>
- SHA-256: `6e7266917fd2de05f7374ebe0de3ef898a06533e17fd9a5c6e4a3d3f237140a9`
- Appendix B: PDF physical page 572, printed page 555, exact cells 1–255
- `char(integer)`: PDF physical page 436, printed page 419; valid range 0–255

The PDF is not redistributed. Byte 0 is absent from the printed table; the
`char(integer)` contract establishes only that byte 0 is in the defined 0–255
domain, not its glyph or Unicode semantics. The canonical `00` -> U+0000 choice
is an explicitly libticonv-corroborated inference. `LOSSLESS_VPUA` and
`RAW_VPUA` retain source identity without relying on that inference.

## Independent corroboration

- Title: *TI-89 Titanium / Voyage 200 Guidebook*
- URL: <https://education.ti.com/download/en/ed-tech/FA1DC891957E4700B46A67255850C592/983EA8A4BA2A4AE9B2AF5EEEE922E3C1/TI-89_Guidebook_EN.pdf>
- SHA-256: `95e086e54fa68df96b5a8249883a60797108dad2c32aa54b64fb84bf9150df1f`
- Appendix B: PDF physical page 926, printed page 924, exact cells 1–255

All 255 printed cells are visually identical between these two tables.

## Profile policy

`SOURCE_GLYPH` is the canonical, version-qualified AMS 2.0 profile. It
preserves C0 control identities and uses the closest readable Unicode glyphs
for calculator-specific graphic cells without claiming unsupported mathematical
or phonetic semantics. In particular:

- `0x95` uses U+1D07 as a readable small-cap-E glyph approximation. Unicode's
  assigned phonetic semantics are not claimed by the TI source.
- `0x96` uses U+1D452 MATHEMATICAL ITALIC SMALL E. U+212F SCRIPT SMALL E is a
  community semantic interpretation and is not what the PDF draws.
- `0x97` uses U+1D48A MATHEMATICAL BOLD ITALIC SMALL I.
- `0x98` uses U+02B3 as the closest readable raised-small-r approximation.
- `0x99` uses U+1D40 as the closest readable raised-capital-T approximation.
  U+22BA INTERCALATE is rejected.
- `0xB5` uses U+00B5 MICRO SIGN by its position in the otherwise Latin-1
  `0xA1–0xFF` run. The glyph alone cannot distinguish Greek U+03BC.
- `0xBC` uses U+1D451 MATHEMATICAL ITALIC SMALL D because that is the visible
  source glyph. U+2202 PARTIAL DIFFERENTIAL and U+2146 DIFFERENTIAL D would
  require semantics that Appendix B does not establish.

`VISIBLE` renders the printed C0 mnemonics as Unicode control pictures
U+2400–U+240A, U+240C, and U+240D. It does not substitute unrelated UI or emoji
symbols. Byte 0 maps to SYMBOL FOR NULL here, while the canonical profile keeps
semantic NUL. This profile is display-oriented and does not claim control
semantics.

`LOSSLESS_VPUA` retains ordinary uncontroversial Unicode mappings and assigns
source-qualified Plane-15 scalars U+F8900 plus byte value to the cells whose
scalar semantics or identity the official glyph table does not establish:

`00`, `95`, `96`, `98`, `99`, `B5`, and `BC`.

`RAW_VPUA` is the forensic profile: every byte maps one-to-one to U+F8A00 plus
its byte value. The canonical, visible, and mixed lossless profiles deliberately
retain the three synthetic sequences at `0x9A`, `0x9B`, and `0xB4` and require
longest-match-first reverse conversion. No profile performs Unicode
normalization or compatibility folding.

## Version boundary and oracle policy

This mapping is specifically AMS 2.0. Byte `0xAA` is the feminine ordinal
glyph in both cited official tables; reports of a superscript `g` in AMS 3.10
must use a separately sourced and separately named profile.

Pinned libticonv source was consulted only after the independent transcription
as an error-finding oracle. It is GPL-2.0-or-later and is neither packaged nor
used to generate this mapping. The TI PDFs are evidence copies only and are not
packaged. This provenance statement is an engineering boundary, not legal
advice.
