# Kermit JIS7-KANJI source metadata

## Executable state-machine source

- Project: C-Kermit / Kermit 95
- Repository: <https://github.com/davidrg/ckwin>
- Revision: `8e977425d2f7f618d14aa466d516e9b79787ffc6`
- Canonical file-character-set name: `jis7-kanji`
- Hidden Kermit synonym: `iso2022jp-kanji`
- `ckuxla.c` SHA-256:
  `d4e73639659b948d4233431d541d4bd2938f0cae2505a0b00aa3aa52abb44dd0`
- `ckcfns.c` SHA-256:
  `e18da89dfa6cdaafd29483722fba7370648526d176cb300037c2fff83fc1942f`
- `ckuxla.h` SHA-256:
  `3352daca1cef3d015ad53d64032d49df1a4efac6f3013f8a75b975b4a63f97ee`
- Mapping implementation: `../dec-terminal-character-sets/kermit/ckcuni.c`
- Mapping SHA-256:
  `af93d5a1c779aa73fa3221ab5ec0125de20267110cf23395971ce35cc88527ca`
- License artifact: `../dec-terminal-character-sets/kermit/COPYING`
- License SHA-256:
  `067b8c8fc98d9359dfbd211820e1d57bed1e173144a184a21e8ead802b6502be`

The relevant source contract is split across the files. `fcstab` and
`fcsinfo` in `ckuxla.c` name `FC_JIS7`; `j7init()` and `getj7()` implement its
decoder; `jpnxas()`, `jpnxkt()`, `jpnxkn()`, and `xkanjz()` define the same
state transitions in the historical EUC transfer path. The active Unicode
file path in `ckcfns.c` maps through `un_to_sj()` and `sj_to_eu()` and emits
the same Roman, Katakana, and Kanji transitions. `ckcuni.c` supplies the
Unicode 3.0 Shift-JIS mapping used by those functions.

The three complete Kermit source files are retained, rather than edited
snippets, so comments, fall-through transitions, finalization, and malformed
input behavior remain independently auditable.

## JIS X 0208 mapping

- Artifact: `../JIS0208.TXT`
- Publisher: Unicode Consortium
- Table: JIS X 0208 (1990), table version 2.0
- SHA-256:
  `1c571870457f19c97720631fa83ee491549a96ba1436da1296786a67d8632e87`
- Assigned mappings: 6,879

An executable test converts every one of the 94×94 JIS positions to
Shift-JIS using Kermit's algorithm, indexes Kermit's two `sju_*` C arrays, and
compares every assigned result with `JIS0208.TXT`. The two sources have the
same 6,879 assigned positions and Unicode values, with no differences and no
duplicate Unicode targets. The independently published table is therefore
used to build the native Elixir lookup structures while the Kermit arrays
remain an exhaustive regression oracle.

Kermit's inverse is intentionally not assumed from that bijective table.
Executable `un_to_sj()` bounds Greek at U+039C and the `usj_ff00` lookup at
U+FF9F. Consequently 38 JIS-mapped characters are decode-only in this exact
revision: the 36 assigned Greek letters in U+039D..U+03C9 plus U+FFE3 and
U+FFE5. Tests pin both C conditions, all 6,879 decode mappings, the exact 6,841
JIS mappings reachable by Kermit's encoder, and the resulting complete 7,029
Unicode-scalar encode repertoire. This preserves the executable source
asymmetry rather than silently repairing it.

## Exact profile boundary

This profile is not ICU `JIS7` and is not a generic `ISO-2022-JP` alias.
Kermit's valid byte/state language has these source-proven properties:

- initial state is JIS X 0201 Roman, so bytes 5C and 7E decode to U+00A5 and
  U+203E;
- SO/SI invoke and leave the JIS X 0201 halfwidth Katakana septets;
- `ESC $ @` and `ESC $ B` select JIS X 0208;
- `ESC ( B` and `ESC ( J` both return to the same Roman state;
- `ESC ESC` is discarded without changing state;
- CR and LF are ordinary controls and do not reset designation;
- an encoder leaving Kanji or finalizing Kanji emits `ESC ( J`, while an
  encoder finalizing Katakana emits SI.

ICU's `JIS7` instead starts in ASCII, has a broader set of Japanese, Chinese,
Korean, Greek, and Latin designations, resets state at line boundaries, and
finalizes with `ESC ( B`. Treating the two as aliases would therefore corrupt
both Unicode values and bytes.

The C implementation is permissive for malformed streams: some unsupported
escapes are returned as literal controls, and some invalid pairs become
U+FFFD. The Iconvex codec preserves the exact valid state language but applies
the library's strict contract outside it: high-bit octets, unknown
designations, invalid graphic ranges, unassigned pairs, and truncated units
are reported with byte offsets and complete recovery widths. The three bytes
ESC, SO, and SI are not encodable as Unicode controls because they are syntax.
Kermit's non-round-trippable Shift-JIS private-use extension is likewise not
claimed as part of the 7-bit JIS X 0208 profile.

The native Elixir implementation is distributed under Iconvex Specs'
LGPL-2.1-or-later license. The retained Kermit audit sources remain under the
separate BSD-style terms in their pinned `COPYING` file.
