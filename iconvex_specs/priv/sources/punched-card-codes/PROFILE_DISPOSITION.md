# Punched-card profile disposition

## Bit and transport convention

The physical card-row order is `12, 11, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9`.
The research CSVs assign those rows from most- to least-significant bit:

| Row | 12 | 11 | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Mask | `800` | `400` | `200` | `100` | `080` | `040` | `020` | `010` | `008` | `004` | `002` | `001` |

The implementation should expose 16-bit word forms in both byte orders, with
the upper nibble required to be zero, and a packed 12-bit MSB-first form.
An LSB-first packed convenience form must remain explicitly named/wrapped; it
is not a historical card-file standard and must not become an unqualified
alias.

## Profiles ready from primary tables

### `IBM-7040-H-REPORT`

Ready. Figure 23 proves 64 unique canonical mappings, including no-punch
space. Use U+2422 BLANK SYMBOL for the slashed-b substitute-blank graphic,
U+221A for tape mark, U+2BD2 for group mark, U+0394 for mode change,
U+2021 for record mark, U+22CE for word separator, and U+29FB for tape
segment mark. Every listed Unicode scalar has one punch mask and vice versa.

### `IBM-7040-H-PROGRAM`

Ready. It is a separate 64-character profile, not aliases over the report
profile. It differs at bare 12, 8+3, 8+4, 8+5, 12+8+4, and 0+8+4.

### `IBM-1401-CARD`

Ready as a strict 63-character baseline profile. Figure 267 does not assign a
card code to the cent/A-bit row; in particular 8+2 (`0x082`) is not a baseline
1401 card code. Reject it. The optional compatibility behavior mentioned in
the manual must be a separately proved and named RPQ/profile if ever added.
Decode 12+0 to question mark (the manual's `Plus Zero`) and 11+0 to
exclamation mark (`Minus Zero`), not to digit zero and hyphen, so the physical
codes remain round-trippable.

### `CDC-167-BCD-HOLLERITH-1965`

Ready as the exact 166-series printer/167-2 translator profile. It has 63
canonical mappings. Colon/BCD 00 has no Hollerith code, so 8+2 (`0x082`) and
all other unlisted masks are invalid. Its print-chain graphics include percent
at 11+0, tilde at 0+8+7, and question mark at 12+8+6; do not silently replace
those with the later logical-operator graphics.

### `CDC-6000-STANDARD-HOLLERITH-1970`

Ready as a distinct 63-character Standard 6000 profile. Here 8+2 is colon,
while 8+6 (`0x00A`) is unassigned. Canonical encode uses 0+11 (`0x600`) for
logical OR and 0+12 (`0xA00`) for less-than because those are the rows printed
in Appendix C. Strict decode additionally accepts:

- 11+8+2 (`0x482`) as logical OR;
- 12+8+2 (`0x882`) as less-than.

Those two aliases are noncanonical on encode. They are the only alternate
punches proved by the table footnote.

## Source-qualified secondary profile

### `BCD-CDC-IOWA`

The Iowa page gives a complete, internally one-to-one 64-character table and
explicit glyph corrections, so `canonical_maps.csv` records it exactly. It
combines colon at 8+2 and percent at 8+6 and uses 11+8+0 (`0x602`) for logical
OR and 12+0+8 (`0xA02`) for less-than. The three-punch OR form is not either
OR form authorized by the 1970 Appendix C footnote.

Disposition: implemented only under the explicit `BCD-CDC-IOWA` and
`BCD-CDC-IOWA-RECONSTRUCTED` names. It is not advertised as the generic or
primary `CDC` code. The two primary CDC profiles above remain separately named,
so the historical version split stays visible.

### `IBM-029-CARD-IOWA-824E61A9`

The pinned Iowa page gives a complete IBM 029 diagram with a 64-column header
and twelve independently extractable punch rows. The source displays blank in
both the no-punch column and the `0-8-2` column. To preserve an unambiguous
Unicode inverse, U+0020 canonically encodes as no-punch (`0x000`) while strict
decode also accepts `0-8-2` (`0x282`) as a decode-only alias. The other 62
graphics are one-to-one, for 63 canonical Unicode scalars and 64 accepted
punch masks.

Disposition: implemented only with `IOWA-824E61A9` in every logical and word
transport name. The digest prefix identifies the exact pinned secondary
artifact. No generic `IBM 029`, `IBM029`, `IBM-029-CARD`, or Hollerith alias is
claimed. MSB-first packed 12-bit and explicit LSB-first packed wrappers are
available alongside zero-padded 16BE and 16LE word transports.

### Four additional content-addressed Iowa profiles

The pinned Iowa page also contains four complete 64-column rows whose source
graphics and twelve physical punch rows can be extracted independently:

- `DEC-026-CARD-IOWA-824E61A9` is the page's `DEC6` row;
- `DEC-029-CARD-IOWA-824E61A9` is the page's `DEC9` row;
- `EBCD-CARD-IOWA-824E61A9` is the page's `EBCD` row; and
- `GE-600-CARD-IOWA-824E61A9` is the page's `GE` row after applying the two
  corrections stated immediately below its diagram: 11-8-2 is U+2191
  UPWARDS ARROW and 0-8-2 is U+2190 LEFTWARDS ARROW (the assignment arrow).

Every row has 64 distinct Unicode scalars and 64 distinct 12-bit masks. Each
is implemented only with `IOWA-824E61A9` in every public logical and transport
identity. The DEC page text attributes its rows to a 1972 handbook and warns
that the DEC 026 source may contain typographical errors; EBCD is attributed
to Dik Winter's collection; and GE combines a translation table with a card
owned by the page author. These are therefore exact reconstructions of the
pinned secondary artifact, not claims about unqualified vendor standards.

Each profile exposes packed 12-bit MSB-first form, an explicitly wrapped
LSB-first convenience form, and zero-padded 16BE and 16LE word transports.
Unlisted masks and words with a nonzero upper nibble are invalid.

### Hollerith consensus row: blocked

The page's “consensus code” is not one complete codec table. Four diagram
cells are printed as `?`, and the prose says there was variation in the coding
of those positions. It also supplies no single set of graphics for those
variant cells. Assigning any one mask/graphic combination would therefore
invent a profile that the cited source does not specify.

Disposition: do not implement `Hollerith consensus punched-card code` from
this artifact. Retain a blocker until a versioned primary source defines one
complete table, including the four variant cells and its exact Unicode
bindings. The evidence is recorded in
`hollerith_consensus_iowa_824e61a9_blocker.md`.

## Unicode binding

The historical sources define print shapes and functions, not Unicode. The
IBM bindings follow the Unicode Consortium's group-mark proposal, which
identifies the existing Unicode representations for the same BCDIC symbols:
U+0394 mode change, U+22CE word separator, U+29FB tape segment mark, U+2422
blank symbol, U+221A tape mark, and U+2021 record mark; U+2BD2 is the assigned
GROUP MARK. See <https://www.unicode.org/L2/L2015/15083r-group-mark.pdf>,
especially pages 7-8. These are semantic bindings, not lossy visual guesses.

## Canonical inverse and error rules

- Every canonical table is one-to-one by both Unicode scalar and 12-bit mask.
- The only duplicate decode results are the two explicit CDC 1970 aliases in
  `decode_aliases.csv`; encode always emits the canonical mask.
- A 16-bit word with any upper-nibble bit set is invalid even if its low 12
  bits name a valid character.
- Any unlisted low-12-bit mask is invalid. Do not treat it as blank, NUL, or a
  replacement character in strict mode.
- Packed input must contain a whole number of 12-bit units. A trailing partial
  unit is incomplete input, not an invalid character.
- Discard/replacement recovery consumes exactly one full 12-bit unit (or one
  16-bit transport word) after framing has established that a unit exists.

## RED/GREEN implementation contract

Before implementation, RED tests should import the CSVs and assert every
valid vector, both directions, for every profile. They should enumerate all
4096 masks and prove that only canonical rows plus documented aliases decode.
Separate tests must cover BE/LE byte order, nonzero upper nibbles, packed MSB
and explicit packed LSB forms, trailing partial units, replacement/discard
progress, streaming chunk boundaries, plus-zero/minus-zero, and all IBM
control graphics.

GREEN should use compile-time encode maps and a dense 4096-entry decode tuple
or equally constant-time native Elixir structure. Benchmark long homogeneous
and mixed card streams in word and packed forms; assert linear scaling and
record throughput against a minimal table-driven Elixir oracle. GNU libiconv
does not provide these punched-card profiles, so it is not a meaningful speed
oracle for them. Registry, inventories, generated manifests, and catalog
dispositions should change atomically only after the exhaustive vectors pass.
