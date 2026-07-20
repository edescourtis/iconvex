# Telecom conformance

## Runtime inventory

The generated `SUPPORTED_CODEC_INVENTORY.csv` is an exact snapshot of the 54
registered runtime modules. A package-contract test compares every canonical
name, every alias, module name, ordering, and statefulness flag against the
running application. This prevents an implemented codec from disappearing from
the published coverage list.

## ITA1 / original Baudot

The mapping follows all 32 polarity rows in Article 16 of the 1958 ITU
Telegraph Regulations. Tests prove the code permutation is exactly 0 through
31, exercise every international letters/figures entry, classify every octet
in both states, keep four national-use rows and two non-text signals unmapped,
and round-trip all 32 units through exact five-bit packing.

## ITA2

The ITA2 letters/figures state machine follows [ITU-T Recommendation
S.1](https://www.itu.int/rec/T-REC-S.1/en). The implementation exposes all 58
non-shift table entries, treats code 27 as FIGS and code 31 as LTRS, represents
WRU and BELL as U+0005 and U+0007, rejects nonzero high bits in the unpacked
form, and provides exact consecutive five-bit packing. Tests exhaust every
executable table cell, repeated and alternating shifts, malformed octets, and
packing round trips.

## ITA2 case preservation (ITU-T S.2)

The case-preserving state machine follows [ITU-T Recommendation
S.2](https://www.itu.int/rec/T-REC-S.2-198811-I), including both operating
modes, the one-character capital state, the `FS LS` capital-lock transition,
the `FS LS LS` initialization sequence, and the automatic terminal's
three-capital lookahead while ignoring separating nonletters. The audited
six-page PDF has SHA-256
`1b2bfef123c5cc2bb7ab5798094e68ac9d50d6c114766740651bc62d3f0c2a78`.
Tests cover isolated and locked capitals, figures in both modes, initialization,
the entire Latin alphabet in both cases, malformed octets, and aliases. S.2
permits the same principles for national alphabets but does not define their
character mappings, so no invented national tables are advertised.

## National and Russian five-unit alphabets

`ITA2-US-TTY` tests compare both complete executable tables, every national
figures position, every representable character, every high-bit octet, aliases,
discard semantics, and the pinned source digest. `MTK-2` similarly compares all
three Latin, Russian, and figures registers to the government-published table,
round-trips the union repertoire, documents the two noninjective national
aliases, and rejects the complete high-bit domain.

## ITA3 and ITA4

The ITA3 S.13 suite proves all 32 ITA2-to-three-of-seven conversions, the
three-of-seven invariant, and classification of every possible octet. The ITA4
R.44 suite proves all 32 six-unit conversions and likewise classifies the
complete octet domain. Both round-trip the full ITA2 state machine while
keeping ARQ/phasing service signals outside Unicode text.

## ITU-T T.50 / IA5

The in-force T.50 IRV is exhaustively checked at all 128 positions. Tests reject
all 128 high-bit octets, cover strict and discard conversion, exact seven-bit
packing, UTF-8 error boundaries, all registered names, and the pinned official
recommendation digest.

## International Morse

The M.1677-1 suite checks all 51 graphic signals from clauses 1.1.1 through
1.1.3, all six procedural signals, common aliases, exact token error offsets,
discard behavior, lowercase canonicalization, the deliberate multiplication/X
noninjectivity, UTF-8 boundaries, and the pinned official PDF digest. Since the
standard has no octet serialization, the package's explicit ASCII dot/dash
envelope is tested independently and documented as an Iconvex framing contract.

## CCIR 476 / SITOR / NAVTEX

The seven-unit mapping follows [ITU-R Recommendation
M.476-5](https://www.itu.int/dms_pubrec/itu-r/rec/m/R-REC-M.476-5-199510-I%21%21PDF-E.pdf),
Annex 1 tables 1 and 2. Tests cover every one of the 32 traffic signals, all
128 possible seven-bit input values, the four-of-seven invariant, all six
service signals, ITA2 letters/figures state, exact seven-bit packing, and the
specified 3B/4Y collective-FEC polarity inversion. The audited PDF has SHA-256
`f50dd15fc71e4430d08119c036c9df4b69ff82b7c258275d0974a28d5939de77`.

## AIS six-bit text and payload armoring

The text alphabet follows Table 45 of [ITU-R Recommendation
M.1371-6](https://www.itu.int/dms_pubrec/itu-r/rec/m/R-REC-M.1371-6-202602-I%21%21PDF-E.pdf),
the May 2026 edition approved on 2026-02-19. The audited PDF has SHA-256
`ffd335b364c6f73fee7aaf792db78d8a31610cc49b62e9c3c50bb7bd3c383b14`.
Tests exhaust all 64 table values, every invalid high-bit octet, exact
consecutive six-bit packing, and strict/discard paths.

The IEC 61162 AIVDM/AIVDO printable payload alphabet is intentionally exposed
as the separate `Iconvex.Telecom.AIS6.Armor` transport API. Tests exhaust its
two arithmetic ranges, excluded punctuation gap, arbitrary non-octet-aligned
bitstrings, declared fill counts, and rejection of nonzero fill bits. Keeping
this layer separate prevents printable payload bytes from being mistaken for
Table 45 character values.

## IBM Six-Bit Transcode

Two independently qualified profiles follow IBM GA27-3005-3 Figure 4 (physical
and printed page 10) and GA27-3004-2 Figure 4 (physical and printed page 11).
The primary PDFs are pinned by SHA-256 in packaged `SOURCE_METADATA.md`, while
the package contains only original normalized CSV facts—not the copyrighted
manual scans. Tests independently parse both 64-row CSVs, pin their digests,
round-trip every assignment, classify all 256 octets, and check every Unicode
scalar against the exact inverse repertoire.

The sources agree at 63 units and disagree only at `0x0C`: U+2311 in the 2780
manual and U+003C in the general BSC manual. Separate canonical names preserve
that fact; generic Transcode identities are deliberately unregistered. The
unpacked form requires both high bits zero. Streaming is tested at every source
and UTF-8 byte split with absolute error offsets. Historical packed transport
is LSB-first (`543210`); full 64-unit, four-unit, and tail vectors also pin the
explicit MSB transport. Invalid bit lengths, widths, and nonzero LSB padding
are rejected. Every canonical and alias `-PACKED-MSB`/`-PACKED-LSB` name is
round-tripped, conflicting named/explicit orders are rejected, and all 51
packed profiles reject an LSB container carrying a non-LSB order tag. Semantic
failures after unpacking are translated back to physical packed coordinates:
the offset is `unit_index * unit_bits`, with an exact-width MSB bitstring
fragment or the failing LSB unit integer.

## GSM 03.38

The implementation follows [3GPP TS 23.038 Release 19 / ETSI TS 123 038
V19.0.0 (2025-10)](https://www.etsi.org/deliver/etsi_ts/123000_123099/123038/19.00.00_60/ts_123038v190000p.pdf),
sections 6.2.1, 6.2.1.1, 6.2.1.2, annex A.2, and annex A.3. Runtime mapping
data is generated from Android's independently exercised
[`GsmAlphabet` tables](https://android.googlesource.com/platform/frameworks/base/+/1cdfff555f4a21f71ccc978290e2e212e2f8b168/telephony/common/com/android/internal/telephony/GsmAlphabet.java),
pinned by repository commit and file SHA-256.

## Exhaustive coverage

The test suite checks:

- all 1,651 non-escape positions in the 13 defined locking tables;
- all 23,296 extension positions: 13 locking tables × 14 single-shift tables ×
  128 positions;
- 31,433 representable pair/character round trips through codepoint and direct
  UTF-8 paths;
- all 182 independently selectable locking/single pairings;
- all 137 round-trip mappings in ICU's `gsm-03.38-2009.ucm` fixture in both
  directions;
- all 128 high-bit octets as invalid unpacked input;
- ICU-pinned reverse fallbacks for lone ESC, ESC ESC, and ESC followed by an
  undefined extension byte; invalid UTF-8 and high-bit septets; discard
  behavior; canonical one-septet encoding preference; every generated wrapper;
  and ownership-safe application registration lifecycle.

The committed [ICU fixture](https://github.com/unicode-org/icu/blob/338d762a8e642eb9693277dd4d53a16900e234a9/icu4c/source/data/mappings/gsm-03.38-2009.ucm)
has SHA-256
`e53e04bb4a022713276ff63702fd404681f70288b43eab14e467636a9c5edcba`.
The Android source file has SHA-256
`af28d761a4efbdafe6e5c65b23d0b3ace20164454f39db03dc796246772387ba`.

## Long-standing specification typos

The Release 19 PDF still prints three cells whose code points belong to the
wrong character or script. Following Android's audited implementation, this
package uses the intended values:

- Kannada locking `0x24`: U+0CA1, not U+0CAA;
- Tamil single shift `0x24`: U+0BEE, not the duplicated U+0BEF;
- Telugu single shift `0x22` and `0x23`: U+0C6C and U+0C6D, not Arabic
  U+06CC and U+06CD.

These corrections are explicit assertions in the test suite.

## Protocol encoding coverage

- `SUPPORTED_PACKED_CODEC_INVENTORY.csv` exactly matches all 51 fixed-width
  runtime profiles: 5 at five bits, 4 at six bits, and 42 at seven bits.
- Every profile round-trips representative text through both exact MSB-first
  bitstrings and physical LSB-first byte streams. LSB streams carry the exact
  meaningful bit count and reject nonzero final padding.
- The generic streaming loop matches GSM's canonical `hellohello` vector and
  is shared by all widths; standard order remains explicit per profile.

- GSM 7-bit TPDU packing uses explicit septet counts and UDH fill bits. Tests
  cover all fill-bit alignments over lengths 0 through 80 plus the canonical
  `hellohello` packed vector.
- TBCD covers `0`-`9`, `*`, `#`, `a`, `b`, and `c`, low nibble first, with
  strict final-only `0xF` filler validation. The registered codec maps the
  complete 15-symbol repertoire and adapts malformed filler positions to
  Iconvex byte-offset errors.
- SIM/USIM alpha identifiers cover GSM-default and the `0x80`, `0x81`, and
  `0x82` UCS2 forms, including mixed compressed strings, scalar validation, and
  code-unit-aware `0xFF` padding.
  The registered codec auto-selects GSM, compressed UCS2, or uncompressed UCS2
  and rejects supplementary characters because the field is UCS2, not UTF-16.
  ETSI TS 102 221 section 8.2 bounds a complete linear-fixed UICC record at 255
  octets. Tests exercise exact-size GSM, `0x80`, `0x81`, and `0x82` records at
  every Stream split; reject the first excess byte with a stable offset under
  strict, discard, substitution, and callback policies; and prove decoder
  `total + pending` and encoder state remain bounded. Earlier GSM, surrogate,
  and record-ending compressed-escape errors take precedence over later excess
  bytes. Recovery from an invalid first GSM-default octet commits the record to
  GSM mode, so later reserved header octets remain data under all four policies
  at every split. Target overflow uses the existing typed
  unrepresentable-character error and preserves first-codepoint ordering.

## Run

```sh
ICONVEX_PATH=../iconvex mix test
```
