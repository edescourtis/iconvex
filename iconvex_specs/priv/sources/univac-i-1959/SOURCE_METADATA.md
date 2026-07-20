# UNIVAC I expanded character code source metadata

The factual mapping in `table_8_2.csv` is an independent transcription of
Figure 8-2 in Sperry Rand's *UNIVAC I* programming manual (1959), PDF page
129 / printed page 124:

- URL: https://bitsavers.org/pdf/univac/univac1/UNIVAC1_Programming_1959.pdf
- SHA-256: `2b4c3c18112a5a0820cf886e417cb605408b635fdc6bdaf658638c7d738c3efc`
- retrieved: 2026-07-17
- copyright notice: Copyright 1958, 1959 by Sperry Rand Corporation

The device-action meanings and physical paper-tape track order are checked
against Remington Rand's one-page *UNIVAC* reference card (1951):

- URL: https://bitsavers.org/pdf/univac/univac1/UnivacI_RefCard.pdf
- SHA-256: `87a6858433286efffcbf4c7bcdb96460d62ad656d06d7125af924fed4542d97f`
- retrieved: 2026-07-17
- copyright notice: Copyright 1951 by Remington Rand Inc.

The 1959 manual defines the two-bit zone followed by the four-bit excess-three
field, identifies `11 1111` as `NOT USED`, and defines a preceding check bit
that makes the seven-bit representation odd parity. Its worked examples are
`A`: `010100` -> `1010100`, and digit `1`: `000100` -> `0000100`.
The reference card establishes that the first character of zones 00, 01, and
10 are printer-ignore, carriage-return, and tabulator actions, respectively;
the delta-shaped printer-space mark at `00 0001` is represented semantically
as U+0020. It also shows physical tape tracks in order `1,2,3,4,S,5,6,7`, with
the sprocket track `S` set.

The source PDFs are copyrighted and provide no reuse grant. They are not
redistributed by Iconvex or included in its package. This independently
transcribed factual table and the implementation are distributed under the
project's `LGPL-2.1-or-later` terms.
