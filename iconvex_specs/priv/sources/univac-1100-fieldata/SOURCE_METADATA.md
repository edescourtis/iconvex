# UNIVAC 1100 Series FIELDATA source metadata

This directory pins the standard six-bit FIELDATA alphabet documented for the
UNIVAC 1100 Series. It is a separate codec from the direction-dependent 4009
Display Console profiles under `../univac-4009-fieldata/`.

## Primary source

- Artifact: `UP-7824r1_EXEC_8_Hw_Sw_Summary_1974.pdf`
- Title: *SPERRY UNIVAC 1100 Series Executive System — EXEC 8 Hardware and Software Summary*
- Publication: UP-7824 Rev. 1, 1974
- Publisher: Sperry Rand Corporation
- URL: <https://bitsavers.org/pdf/univac/1100/exec/UP-7824r1_EXEC_8_Hw_Sw_Summary_1974.pdf>
- SHA-256: `de2f25c0ebff74ee75c6fba8a4125b733800200525b8df84a9e40c667400f6ab`
- Exhaustive table: PDF page 113 / printed page 6-1

The scan is not redistributed by the Hex package. Its copyright page states
`Copyright 1971, 1974 - SPERRY RAND CORPORATION` and grants no permissive
reuse or software license. The normalized factual table and independent native
Elixir implementation are licensed under Iconvex Specs' LGPL-2.1-or-later
terms; those terms do not apply to the source manual.

## Profile identity

All 64 units have unique Unicode bindings and are exactly reversible. Octal 04
is U+0394 GREEK CAPITAL LETTER DELTA, 76 is U+2311 SQUARE LOZENGE, and 77 is
U+2260 NOT EQUAL TO. Values 40 through FF hexadecimal are outside the six-bit
code and are invalid; the codec never masks them into range and never folds
lowercase input.

The standard table differs from the 4009 console at exactly seven octal units:
00, 03, 04, 46, 52, 57, and 77. Unit 76 is the same square lozenge in both
primary sources. This distinction is guarded exhaustively by tests.

`table_6_1.csv` is the complete source-derived test oracle. Runtime code embeds
an independent table and does not load this file.
