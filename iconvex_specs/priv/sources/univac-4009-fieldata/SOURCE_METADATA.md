# UNIVAC 4009 FIELDATA source metadata

The four runtime profiles in this directory are scoped to the SPERRY UNIVAC
4009 Display Console attached to a UNIVAC 1106 or 1108. They intentionally do
not claim the unqualified `FIELDATA` name: other UNIVAC peripherals and the
military FIELDATA family assigned different graphics or actions to several of
the same six-bit units.

## Primary source

- Artifact: `UP-7604r1_1106_1108_Systems_4009_Display_Console_Programmer_Reference_1974.pdf`
- Title: *SPERRY UNIVAC 1106/1108 Systems 4009 Display Console Programmer Reference*
- Publication: UP-7604 Rev. 1, 1968/1974
- Publisher: Sperry Rand Corporation
- URL: <https://www.fourmilab.ch/documents/univac/manuals/pdf/1108/UP-7604r1_1106_1108_Systems_4009_Display_Console_Programmer_Reference_1974.pdf>
- SHA-256: `469bcb196f0bc76b2bdbce3821a34fcd8e697bf20bb86a088746cd57ad673140`
- Exhaustive table: Table 3-1, PDF page 19 / printed page 3-4

The scan is not redistributed by the Hex package. The publication states
`Copyright 1968, 1974 - SPERRY RAND CORPORATION` and contains no permissive
reuse grant. The independently transcribed mapping facts and native Elixir
implementation are licensed under Iconvex Specs' LGPL-2.1-or-later terms.

## Directional policy

The manual specifies device behavior, not one symmetric character map:

- input unit 00 is a proprietary master-space key glyph;
- input unit 03 is the keyboard's `NL` function;
- unit 04 cannot be supplied as input;
- output units 00 and 04 are completely ignored;
- output unit 03 performs a combined carriage-return and line-feed action and
  displays or prints no glyph;
- unit 57 depicts a proprietary diamond-enclosed wave glyph; units 76 and 77
  depict a square lozenge and up arrow.

`UNIVAC-4009-FIELDATA-INPUT` therefore maps input NL to U+0085 NEXT LINE,
uses a source-qualified private-use scalar for the master-space key, and
rejects 04. `UNIVAC-4009-FIELDATA-OUTPUT` drops 00/04 and also maps 03 to
U+0085. NEL is the single Unicode control for the source's combined-new-line
function; the codec does not silently normalize it to LF or CRLF.
Unicode has no character whose identity and glyph exactly match the manual's
diamond-enclosed wave at unit 57. The readable profiles therefore use the
source-qualified private-use scalar U+F402F for that glyph. In particular they
do not use U+1F6D1 OCTAGONAL SIGN: its octagonal stop-sign appearance is a
modern semantic approximation unsupported by the pinned table. The square
lozenge is U+2311 and the arrow is U+2191.

`UNIVAC-4009-FIELDATA-LOSSLESS-VPUA` retains the readable semantic mappings
and assigns source-qualified Plane 15 private-use scalars U+F4000, U+F4004,
and U+F402F only to the master-space, unavailable/ignored, and proprietary-glyph
slots. All 64 values therefore round-trip without turning ordinary FIELDATA
text into opaque private-use strings.

`UNIVAC-4009-FIELDATA-RAW-VPUA` is the strictly raw forensic view: unit `n`
maps to U+F4000+n. U+F4000..U+F403F is reserved as the documented 4009 slot
namespace. This second profile never gives a raw unit a potentially disputable
Unicode semantic identity.

## Machine-readable evidence

`table_3_1.csv` contains all 64 octal units, both directional Unicode policies,
the readable lossless vector, the complete raw-VPUA vector, and each exceptional
disposition. It is a test oracle and provenance record; runtime code does not
load it.
