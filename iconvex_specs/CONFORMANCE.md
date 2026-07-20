# Conformance

The importer pins byte-for-byte source digests for RFC 1345, the RFC Editor's
errata records, Unicode's JIS 0208/JIS 0212/KS X 1001 mapping files, and the
Unicode-hosted Microsoft CP936 mapping used for the GB 2312 grid.

The generated corpus currently contains 53,565 decode mappings and 990
two-byte combining mappings. Tests load every generated ETF table, exercise
every canonical encoder mapping, and run every concrete decoder cell through a
decode-encode-decode cycle.

Final research-closure conformance covers
`CTAN-LY1-TEXNANSI-1.1-AGL-4036A9CA`,
`ADOBE-POSTSCRIPT-3-ISOLATIN1-AGL-4036A9CA`,
`TAMILVU-TACE16-APPENDIX-D-2010-16BE`,
`TAMILVU-TACE16-APPENDIX-D-2010-16LE`,
`WANG-1983-WISCII-PDF-F4043449-WIKIPEDIA-REV1352856854`,
`WIKIPEDIA-REV1354794598-PARATYPE-WINDOWS-POLYTONIC-GREEK`, and
`WIKIPEDIA-REV1340817319-EKI-SAMI-WIN-CP1270`. Tests exhaust 1,280 byte/word
positions plus both complete 65,536-word TACE transports, every mapped row,
all Unicode scalars for each encoder, and every public streaming split in both
directions.

WISCII provenance is also executable data: `source_*` identifies only the
external copyrighted Wang chart (`NOASSERTION`), while `provenance/0` records
the separate `CC-BY-SA-4.0` Wikipedia Unicode-binding revision, digest, and
MediaWiki identity. Tests reject the former chart/license conflation.

The glyph/TACE benchmark schema version 2 separately records and enforces
12/12 measured elapsed-time native/reference ratios at `<=30x`; scheduler
reductions remain an additional 12/12 gate and are not presented as wall time.

Separate exhaustive suites execute all 43,685 Adobe/Apple decoder mappings,
all 43,607 vendor encoder mappings, all 16,395 executable LOC MARC-8 scalar
mappings, every MARC combining/spanning form, 13,069 ICU4J ISCII oracle
vectors, and all 22,249 decoder / 22,172 canonical encoder mappings from the
29 pinned glibc charmaps. A test independently re-parses every CHARMAP row,
checks every source digest, and exercises both directions. MARC's syntactic ESC
row and its two second-half markers are reported separately instead of being
counted as ordinary scalar mappings.

The ICU UCM suite pins all 135 standalone single-byte converter sources in
ICU 78.3. Tests independently parse 48,555 mapping rows, verify every source
digest, classify all 34,560 possible input bytes, and exercise all 33,730
strict canonical encoder mappings. Precision flags are directional: `|0`
round trips, `|3` decodes only, `|4` encodes only, `|2` is ignored, and `|1`
fallbacks are excluded except for ICU's five always-enabled private-use
compatibility mappings. A separately compiled ICU 78.3 oracle validates
68,290 decode/encode cases with digest
`92303333a47ac0efde9bee7a4668e1fb4aac76580a61bb862d31411b7e3cf3c3`.

The multibyte UCM suite applies the same directional rules to 30 complete
`MBCS`/`DBCS` definitions: 475,838 source rows, 470,101 decoder mappings, and
471,795 canonical encoder mappings. Every generated mapping is executed in
the default suite. ICU 78.3 independently confirmed 885,966 mapped cases with
SHA-256 `763e3c2cc5b1dd93b85a32ac60a7f58cd069608685b4351376769cc77e727ba9`.
The runtime does not expose the `CNS-11643-1992`, `ISO-IR-165`, or `JISX-212`
component maps as openable converter names; those three retain byte-for-byte
source, digest, independent-parser, and complete mapping execution evidence,
but are excluded from the runtime differential count.

All ten ICU `EBCDIC_STATEFUL` definitions use a native streaming SI/SO engine,
not a flattened table. The suite executes 182,035 decoder and 181,796 encoder
mappings, verifies shift consolidation and flush closure, and independently
matches ICU 78.3 on 363,831 cases with digest
`9c837dd4dc2540108e3a9192c09a228bf187e12ec3f57e459711e58e4f23ec0e`.

The historical ICU data-repository audit pins all 1,050 UCM files rather than
silently selecting a current revision: 760 SBCS, 149 MBCS, 66 DBCS, 46
`EBCDIC_STATEFUL`, and 29 older unclassified definitions. Tests independently
re-parse all 4,475,652 source rows and execute 4,354,740 operational decoders and
4,361,478 encoders. Forty-eight sources use the native SI/SO engine, including
two MBCS files whose explicit `.s` transitions override their nominal class.
ICU reserves U+FFFE/U+FFFF as decode sentinels in two GB18030 revision maps; the
four source rows remain counted and encodeable but are not advertised as ICU
decoder mappings.

ICU 78.3 `makeconv` independently accepts 977 archive sources. Each is packaged
as custom ICU data so a same-named built-in converter cannot mask the historical
revision. All 7,075,555 accepted strict mappings match the C runtime oracle.
The stable transcript SHA-256 is
`dd1a8e76aa2c14dc3d53bf0452a6b37a1d59cf2f406bcdd313a2b36dd8742e4d`;
[ICU_ARCHIVE_DIFFERENTIAL.md](ICU_ARCHIVE_DIFFERENTIAL.md) inventories all 73
legacy files rejected by the modern compiler and their normalized diagnostics.

The Unicode miscellaneous suite pins both published APL/ISO-IR-68 mapping
revisions and KPS 9566-2003. The APL files each contain 236 rows, including
three-byte overstrike sequences with backspace, four byte-sequence ambiguities,
and 70 duplicate Unicode targets. Decoder and canonical encoder choices preserve
first source order; the current table's documented 2020 correction swaps the
old `0x28`/`0x29` AND/OR assignments. KPS tests execute every one of its 16,959
unique mappings (128 single-byte controls/ASCII plus 16,831 double-byte cells).

Thirty-eight complete corrected tables from the RFC errata page replace their
original RFC blocks. The importer rejects byte overflow rather than allowing
BEAM bit syntax to truncate it. This check is what quarantines IBM423.

RFC `&duplicate` directives can intentionally define encode-only compatibility
mappings, so they are reported separately instead of being mislabeled as
round-trip failures.

## Algorithmic specifications

- BOCU-1 follows Unicode Technical Note #6 and matches its `FB EE 28` BOM
  vector plus ICU 78.3 over every Unicode scalar.
- Punycode follows RFC 3492 as a complete-string Bootstring transform, without
  adding IDNA's `xn--` prefix or applying IDNA mapping. Tests parse all nineteen
  section 7.1 examples directly from the pinned RFC, execute the RFC's optional
  mixed-case digit annotations, differentially check 517 deterministic scalar
  strings against the pinned CPython 3.14.6 implementation, and exhaustively
  compare all 65,793 inputs through two octets. Strict/discard/substitute
  policies, UTF-8 direct paths, malformed offsets, scalar overflow, and bounded
  generalized-integer arithmetic have permanent regressions.
- LMBCS follows ICU 78.3's pinned `ucnv_lmb.cpp`, Lotus exception table, and
  thirteen national subconverters. Exactly the twelve instantiated optimization
  groups are exposed. All 1,112,064 Unicode scalars produce byte-identical
  canonical output for every profile in a single ICU call; ICU and the native
  discard decoders agree on all 1,112,062 non-sentinel results. Permanent tests
  additionally execute 72,378 reachable explicit forms, all 71,452 implicit
  variant mappings, invalid/truncated grammar branches, UTF-16 surrogate pairs,
  strict/discard/substitute and direct UTF-8 policies, and one-byte stream
  boundaries. See `ICU_LMBCS_DIFFERENTIAL.md`.
- SCSU follows Unicode Technical Standard #6, including all static and dynamic
  windows, extended supplementary windows, both modes, quoted UTF-16 units,
  reserved commands, and surrogate reconstruction. ICU cross-decodes the full
  scalar stream in both directions; encoded bytes are not required to match
  because SCSU compression is intentionally non-unique.
- CESU-8 follows Unicode Technical Report #26 and is byte-identical to ICU for
  all Unicode scalars.
- UTF-7-IMAP follows RFC 3501 section 5.1.3 and is byte-identical to ICU after
  flushing the mandatory final shift terminator.
- Java Modified UTF-8 follows Java's `DataInput`/`DataOutput` modified UTF
  representation without the `writeUTF` length prefix.
- UTF-EBCDIC follows Unicode Technical Report #16 version 8, including the
  normative 256-byte I8/EBCDIC permutation, shortest I8 forms, and the
  `DD 73 66 73` signature vector.
- `x-user-defined` follows the WHATWG Encoding Standard's complete mapping.
- UTF-9 follows every RFC 4042 octal vector. The suite round-trips all 1,112,064
  Unicode scalars through exact 9-bit bitstrings and both 16-bit-endian word
  transports, and rejects overlong starts, truncation, surrogates, overflow,
  and nonzero word padding.
- UTF-18 follows every RFC 4042 octal vector and exhausts every Unicode scalar
  in planes 0, 1, 2, and 14. The suite rejects surrogates, planes 3–13 and
  15–16, partial 18-bit values, and nonzero padding in both 24-bit-endian word
  transports.

## UNIVAC I expanded code (1959)

The independent 64-row transcription is compile-time checked against the
runtime semantic, lossless, and raw tables. Tests exhaust all 64 basic
patterns, all 128 checked septets, and all 256 physical paper-tape rows. They
pin the manual's `A` and digit `1` vectors, validate the sprocket track and odd
parity, reject every high octet without masking, and distinguish printer-ignore
from space, carriage return, and horizontal tab.

All 1,112,064 Unicode scalars are checked against each of the five encoder key
sets. Every source and UTF-8 stream split, malformed and incomplete suffix,
first-error ordering case, strict/discard/substitute policy, packed truncation,
and bit offset is exercised. Twelve six-bit characters occupy exactly 72 bits;
two twelve-character checked words occupy exactly 168 bits / 21 bytes. The
copyrighted primary scans are not packaged—only the digest-bound independent
table and provenance metadata ship.

## Unihan 17 Chinese telegraph property tokens

The Mainland, Taiwan-readable, and Taiwan-lossless profiles exhaust all 10,000
four-digit tokens against independently filtered Unicode 17.0.0 fixtures.
Tests also exhaust every reverse entry: 7,078 Mainland, 9,024 Taiwan-readable,
and 9,026 Taiwan-lossless scalars. The Taiwan fixture has 9,026 tokens and two
duplicate source scalars; the lossless policy additionally separates the two
source scalars that normalize onto other assigned entries. All 9,026 lossless
outputs are distinct and remain unchanged under NFC, NFD, NFKC, and NFKD.

The repository retains the exact `Unihan_OtherMappings.txt` and UnicodeData
17.0.0 source fixtures. A deterministic extractor regenerates all three compact
tables byte-for-byte. A separately implemented verifier does not import that
extractor: it reparses both sources, compares every one of the 30,000 token
outcomes, independently derives reverse minima, duplicates, normalization
hazards and VPUA policy, and rejects source or packaged-table tampering.

Malformed tests pin length, first invalid-byte offset, unassigned token,
Unicode scalar validity, UTF-8 sequence kind/offset, and exactly-one-scalar
cardinality. Compile-time adversarial tests recompute hashes after corrupting
headers, token order, scalar validity, source/policy agreement, and lossless
uniqueness; each semantic corruption is rejected. A runtime trace confirms
lookups do not read packaged files. Package tests select only the three compact
tables, metadata, mapping inventory, documentation, and Unicode license.
The large source fixtures and audit tools are deliberately excluded from the
Hex artifact.

These are deliberately outside `Iconvex.Codec`: the normative property grammar
defines one token but no message framing. Registry tests prove both the three
source-qualified names and generic Chinese telegraph names remain unknown to
the byte-pipeline API. GNU libiconv 1.19 lists no exact source-qualified alias,
so there is no fabricated GNU equivalence claim.

## TI-89 / TI-92 Plus AMS 2.0

- The source-glyph, visible-control, mixed lossless-VPUA, and raw-VPUA profiles
  each classify all 256 bytes and prove every canonical reverse. The first
  three preserve the exact two-scalar mappings at 9A, 9B, and B4 with
  longest-match-first encoding; raw VPUA is one scalar per byte.
- The source-glyph profile keeps C0 semantics. The visible profile uses Unicode
  control pictures only where the guidebook prints C0 mnemonics. The mixed
  lossless profile reserves U+F8900 plus byte value for exactly 00, 95, 96, 98,
  99, B5, and BC; the raw profile reserves U+F8A00–U+F8AFF. No profile
  normalizes input, so ten independently tested NFKC collision pairs and the
  B4 versus AD+31 collision retain their distinct byte identities.
- Tests independently parse the packaged 256-row CSV, pin both official PDF
  hashes and exact physical/printed pages, and enforce the evidence boundary:
  byte 0 belongs to the official 0–255 domain but is absent from the printed
  table. The base `00 -> U+0000` choice is explicitly oracle-corroborated;
  lossless and raw profiles do not rely on it. No PDF or GPL table is packaged.
- Strict, discard, substitution, direct UTF-8, malformed UTF-8 offsets, every
  source-byte and UTF-8-byte stream split, terminal multi-scalar prefixes, all
  aliases, package selection, and bounded large-input scheduler-reduction
  scaling have permanent tests. The scaling test makes no allocation or
  peak-memory claim. Direct callback errors use the public codec tuple contract,
  so strict public conversion does not repeat work through the generic path.
- The benchmark enforces all sixteen scheduler-reduction gates and a separate
  wall-throughput floor for every direct/public encode/decode path. Floors range
  from 0.51 to 1.38 MiB of actual input per second. Each is the recorded minimum
  for its profile family divided by 30 and rounded upward to 0.01 MiB/s, never
  down. A slowdown greater than 30x therefore fails, without pretending that
  scheduler reductions measure wall time.
- GNU support status is derived from `iconv -l`, not from the executable's
  version banner. Exact ASCII-case-and-punctuation-normalized matching covers
  all canonical names and aliases; a fake executable permanently tests both a
  punctuation-equivalent positive and a deceptive substring negative.

## TI-83 Plus 2002

- The large- and small-font tables are separate six-profile identities: each
  has readable, mixed-lossless VPUA, and raw VPUA forms. No ambiguous bare
  font alias is accepted. The readable invalid sets are exactly 00/F2–FF for
  large and 00/ED–FF for small.
- Tests independently parse all 256 rows, execute every forward mapping and
  every canonical/alias/decode-only reverse disposition, and round-trip all
  131,072 adjacent-byte pairs across the two mixed-lossless profiles. Six
  multi-scalar cells, longest-match prefixes, terminal prefixes, and the 1D/DE
  decode-only collisions are explicit.
- Every source and UTF-8 stream split is exercised with strict, discard, and
  substitution behavior; malformed UTF-8 retains exact byte offsets. Direct
  UTF-8 callbacks, public conversion, no-normalization collision matrices,
  bounded 4,096-unit iodata chunks, and large-input scheduler scaling have
  permanent regressions.
- Compilation reads each packaged asset once, checks the exact mapping and
  metadata SHA-256 values before parsing, then enforces the exact header, 256
  ordered uppercase byte tokens, Unicode scalar validity, policy consistency,
  alias-to-canonical ownership, canonical reverse uniqueness, and lossless
  bijections. Recomputed-hash negative fixtures exercise every guard, including
  lowercase byte text, a surrogate, an unknown policy, alias-to-alias routing,
  and a duplicate canonical reverse.
- The executable benchmark covers all 24 direct/public profile paths and ten
  readable-invalid paths. Every path has a wall-throughput floor equal to the
  ceiling at 0.01 MiB/s of its recorded family minimum divided by 30, plus an
  isolated fresh-process 2x-input scheduler-reduction gate. GNU status starts
  with `iconv -l` and exact normalized matching; GNU libiconv 1.19 lists none
  of the six names.

## Six-bit historical standards

- ECMA-1 follows all 64 cells of the normative 1963 table. The public
  `ECMA-1` profile selects the first graphic at positions where the withdrawn
  standard permits a sender/receiver choice, and selects `[`, `\\`, `]` rather
  than an unspecified three-letter national extension. The byte API rejects
  all values above 63; packed MSB/LSB transports preserve exact bit length.
- DEC-SIXBIT follows the documented DECsystem-10 transformation for all 64
  values: decode adds octal 040, while encode subtracts octal 040 after folding
  lowercase ASCII to uppercase. It is intentionally distinct from ECMA-1.
- `FIELDATA-UNIVAC-1100` follows all 64 unique assignments in UP-7824 Rev. 1
  Table 6-1. An independent CSV parser checks every unit and canonical inverse;
  the codec rejects all 192 high octets without masking and never folds
  lowercase. Its MSB packed vector proves the documented layout of six
  characters per 36-bit word, while LSB packing remains an explicit library
  transport.
- The four `FIELDATA-UNIVAC-4009-*` profiles preserve UP-7604 Rev. 1 Table 3-1
  as directional device semantics rather than forcing one symmetric mapping.
  Input rejects unavailable unit 04; output consumes ignored units 00 and 04;
  both map the combined-new-line action to U+0085. The readable lossless view
  reserves U+F4000 and U+F4004 for non-character slots and U+F402F for the
  proprietary diamond-enclosed wave glyph, while the raw forensic view maps all
  64 units bijectively to U+F4000–U+F403F. Exhaustive tests prove
  that the standard 1100 and readable 4009 tables differ at exactly octal 00,
  03, 04, 46, 52, 57, and 77. Stateless streaming is checked in both directions
  at every UTF-8 byte split with strict, discard, and replacement policies.
- CDC Display Code follows Control Data's NOS tables for every unit in both CDC
  graphic and ASCII graphic profiles. The 64-character profiles map code 00 to
  colon and 63 to percent; separate 63-character profiles reject code 00 and map
  63 to colon. CDC mathematical/arrow graphics are mapped to their exact Unicode
  characters rather than substituted with the materially different ASCII set.
- CDC 6/12 Display Code implements table A-2 for all 128 ASCII values. Tests
  execute every canonical encode/decode mapping and independently classify all
  4,096 possible two-unit inputs in each 63/64 mode. They also cover every high
  octet, both escape-prefix truncations, all undefined 74/76 pairs, the alternate
  code-00 colon, the 63-character percent exclusion, discard recovery, and exact
  42-bit MSB/LSB examples.
- DEC Special Graphic and DEC Technical follow every cell in DEC's rendered
  Figures 2-7 and 2-8. The suite independently classifies all 256 octets in GL
  and GR for both sets (1,024 cases), checks all 94 positions in each profile,
  and proves all defined reverse mappings. Technical's nine blank cells remain
  invalid. U+23B2..U+23B5 and U+23B7 use Unicode's standardized joining glyphs,
  so no historical private-use assignment leaks into the public mapping.
- SI 960 exhaustively tests all 128 septets and rejects all 128 high octets at
  both zero and nonzero offsets. DEC Hebrew 8-bit independently classifies all
  256 octets against the tested RFC DEC-MCS table plus DEC's exact E0–FA Hebrew
  overlay and C0–DF/FB–FF removals. Both profiles prove every preferred reverse
  mapping, strict/discard/direct UTF-8 behavior, aliases, and malformed offsets;
  SI 960 additionally proves exact 14-bit MSB/LSB packed examples.
- All eight scanned vendor/standard source PDFs are pinned byte-for-byte and
  their normative pages were visually inspected after rendering. Tests execute
  every unit or defined sequence in every profile, strict and discard errors,
  direct UTF-8 conversion, and both packed bit orders.

## Twelve-bit punched-card profiles

- IBM A24-0520-3 contributes all ten IBM 24/26 special-character arrangements
  A-K (I is not a source arrangement). Tests compare every one of the 110
  Figure 23 cells with a digest-pinned machine-readable extraction, independently
  regenerate the 37 shared Figure 28 punches, and enumerate all 4,096 masks for
  every arrangement in logical, 16BE, and 16LE form.
- The complete 1,112,064-scalar corpus is classified independently through MSB
  packed, explicit LSB packed, 16BE, and 16LE paths for every arrangement.
  U+2311 SQUARE LOZENGE and the explicit U+2032 PRIME retain their source
  semantics. Six duplicate punches decode while the documented base-first,
  Figure-23-left-to-right policy makes reverse encoding deterministic.
- Every source-byte stream split exercises full-word invalid recovery under
  discard, callback, and byte-substitution policies. Exact suffixed aliases
  register without claiming generic IBM-24, IBM-26, or IBM-026 identities.
- Five logical profiles are extracted from pinned IBM and CDC primary manuals:
  the distinct IBM 7040/7044 report and programming H codes, the strict IBM
  1401 baseline, the CDC 167/166 translator table from 1965, and the CDC 6000
  Standard Hollerith table from 1970. The complete Iowa reconstruction is a
  sixth profile under the source-qualified `BCD-CDC-IOWA` name only; generic
  CDC identities remain deliberately unclaimed.
- Tests independently parse the canonical CSV evidence, execute every
  canonical inverse, and enumerate all 4,096 possible 12-bit masks for every
  profile. Only two CDC 1970 alternate punches decode beyond the canonical
  rows, exactly as its primary-table footnote specifies.
- Every profile round-trips through exact MSB-first bitstrings, explicit
  byte-backed LSB streams, and zero-padded 16-bit big- and little-endian
  transports. Nonzero upper nibbles, undefined masks, partial units, nonzero
  LSB padding, malformed UTF-8, replacement/discard progress, streaming
  boundaries, registry aliases, and generated inventories have permanent
  regressions.
- Mapping code contains literal independently implemented facts. Normalized
  extraction CSVs and digest-bearing metadata are packaged; the retained scans,
  HTML, and Unicode proposal remain repository-only evidence and are not
  required to compile the published package.

## ECMA-44 raw punched-card transport

- `Iconvex.Specs.ECMA44` implements the complete raw correspondence in
  ECMA-44 Tables 1 and 2 without assigning Unicode meaning. Its independently
  transcribed 256-cell CSV is checked against a separately literalized runtime
  table, 256 canonical inverses, normative anchors, and stable U16BE and
  contiguous-12-bit SHA-256 digests.
- Both modes classify every one of the 4,096 possible masks. Eight-bit mode
  accepts exactly the 256 physical patterns permitted by clause 3.2; seven-bit
  mode accepts exactly the first 128 table entries and rejects every upper-half
  combination in both directions. The suite separately recomputes the physical
  rule from the five unrestricted rows and at most one punch in rows 1--7.
- Every combination round-trips through mask lists, exact 12-bit MSB
  bitstrings, explicitly library-defined LSB containers, and zero-padded 16BE
  and 16LE words. ECMA-44 defines none of those serialization orders. Tests
  enforce malformed physical bit/byte offsets, nonzero padding rejection,
  partial-unit chunk handling, large-input linearity, and complete exclusion
  from every Unicode and packed-codec registry.
- The release ships the independent table, source metadata, raw inventory, and
  [`ECMA44_RAW_TRANSPORT.md`](ECMA44_RAW_TRANSPORT.md), but not the copyrighted
  source PDF. Raw-profile claims live only in
  [`SUPPORTED_RAW_TRANSPORT_INVENTORY.csv`](SUPPORTED_RAW_TRANSPORT_INVENTORY.csv)
  and do not inflate Unicode codec counts.

## DEC RADIX-50 word families

- PDP-11 uses the complete table and base-40 formula from printed page A-3 of
  DEC's June 1977 *FORTRAN IV Language Reference Manual*. Tests exhaust all
  65,536 possible 16-bit words: every word below 64,000 whose three digits avoid
  unassigned value 29 round-trips exactly and every other word is rejected. The
  published `X2B = 115402` octal vector passes in both byte orders.
- PDP-6/10 uses DEC's separate 40-character alphabet, six digits in the low 32
  bits of a 36-bit word, and four high tag bits. Every digit is exercised in all
  six positions. The manual's `RADIX50 10,SYMBOL = 126633472376` octal vector
  passes, including tag extraction; text transports require tag zero. Both
  exact 36-bit packed values and explicit zero-padded 40BE/40LE storage exist.
- PDP-9/15 uses its own 40-character alphabet, three digits in the low 16 bits,
  and two classification bits. Every digit is exercised in all three positions.
  The published `SYMNAM` words `475265` and `053665` octal pass, including the
  first word's classification value. Both exact 18-bit packed values and
  explicit zero-padded 24BE/24LE storage exist.
- All three source PDFs are pinned by SHA-256 and their cited pages were visually
  inspected after rendering. Tests additionally cover right-space padding,
  partial words, metadata/padding overflow, precise error offsets, discard
  framing, invalid UTF-8, registry aliases, and direct UTF-8 paths.

## IBM ISO-2022 Japanese profiles

The IBM-5052/5053/958/5055 engine uses IBM's documented ESID 5404 escape-based
scheme and exact pinned IBM-895, IBM-952, and IBM-955 components. IBM-5052 and
IBM-5053 return to the IBM Roman G0 designation; IBM-958 and IBM-5055 return to
ASCII. The 1983 profiles designate JIS with `ESC $ B`; the 1978 profiles use
`ESC $ @`. Tests execute 35,598 component positions/canonical mappings, plus
strict escape truncation, invalid octets, discard paths, UTF-8 fast paths, and
all seven CCSID names.

IBM-965 uses the same documented escape-sequence scheme with ASCII CP367 and
the exact pinned IBM-960 CNS 11643 plane-1 component. It designates G1 with
`ESC $ ) G`, invokes it with SO, returns with SI, and resets designation at
line boundaries. Tests classify every ASCII/control position, all 94×94 graphic
positions, and all 5,916 canonical CP960 encoder mappings, then exercise strict
state errors, discard behavior, and direct UTF-8 conversion.

IBM-17354 is independently composed from IBM's published CCSID definition:
ESID 5404, ASCII CP367 in G0, and KSC X5601-1989 CP971 in G1. It designates the
registered Korean G1 set with `ESC $ ) C`, uses SO/SI invocation, and resets at
line boundaries. Tests classify all 8,836 graphic positions, execute all 8,412
preferred CP971 encoders, and cover strict state, discard, aliases, and UTF-8.

IBM-1175 is audited against IBM's January 2013 CDRA `0497B4B0.TXMAP`: all 256
forward mappings are exactly equal to pinned table `icu_archive_374`, including
Turkish lira at `9A` and euro at `9F`. Tests also execute every preferred reverse
mapping and all strict/discard/direct UTF-8 paths.

## IBM PC mixed data

IBM identifies CCSIDs 934 and 938 as PC mixed encoding scheme 2300, and AIX
identifies them as the Korean and Traditional Chinese PC members of its
compatible multibyte families. IBM-934 combines the exact pinned CP891 SBCS and
CP926 DBCS revisions; IBM-938 combines CP904 and CP927. Their mapped lead-byte
sets are disjoint from their SBCS byte sets, so decoding is deterministic
without an invented shift protocol. Tests classify all 256 initial octets and
all 44,288 possible lead/trail inputs, execute all 31,329 decoder mappings and
31,140 preferred encoders, and cover prefix errors, discard, aliases, and
direct UTF-8 paths.

## Recent source-qualified research profiles

- OML and OMS independently execute every one of their 128 source slots and
  every Unicode scalar, keep the two semantic tables distinct, reject all high
  octets, and publish explicit MSB/LSB seven-bit transports. Cork independently
  checks both 256-slot interpretations, their nine intentional differences,
  the undefined slot, every preferred reverse, policies, offsets, and streaming.
- Formal SignWriting v1.0.0 exhausts all 62,504 symbols, all 262,144 shaped
  symbol candidates, all 250,000 coordinate pairs, all structural markers,
  every Unicode scalar, malformed offsets, policies, and stream splits. It does
  not accept syntax outside the pinned v1.0.0 grammar.
- PDP-1 tests every Concise and physical transport value in both shift states
  for the 1960 and 1963 revisions, all parity outcomes, controls, policies,
  offsets, stream splits, and all Unicode scalars. Four six-bit profiles expose
  both MSB- and LSB-packed forms; physical odd-parity profiles remain octet
  transports. Exact initial state is part of each of the eight public names.
- Original KEYBCS2 and the MySQL variant each classify all 256 bytes, prove a
  unique inverse for every mapping, exercise every Unicode scalar and every
  source/UTF-8 streaming boundary, and pin their one-byte difference. ABICOMP
  likewise tests all 256 bytes, all 192 reverses, all 64 holes, every Unicode
  scalar and split boundary. BraSCII tests all 256 bytes, its D7/F7 substitutions,
  every scalar, all source and UTF-8 splits, policies, malformed offsets, and
  compile-time source tampering.
- Kermit JIS7-KANJI compares all 6,879 assigned JIS X 0208 decoder positions
  against both Kermit's executable Shift-JIS tables and Unicode's independent
  mapping. Tests cover every Roman and shifted-kana character, all nine encoder
  state transitions, both Kanji designations, both Roman designations, SO/SI,
  doubled ESC, line-state persistence, exact finalizers, every stream split,
  malformed widths/offsets, policies, all Unicode scalars, and the asymmetric
  encoder boundary present in Kermit's source. Cross-tests prove it is not ICU
  JIS7 and no broad ISO-2022-JP alias is exported.
- MacOS Esperanto checks every one of the source's 223 published positions and
  the explicit C0/DEL transport additions, then proves all 256 unique reverses,
  every Unicode scalar, every byte/scalar split and singleton chunk, policies,
  malformed UTF-8 precedence/offsets, and source tampering. VSCII-2 checks all
  224 assignments and 32 holes, all Unicode scalars, raw combining mappings,
  every stream split, policies, malformed offsets, and structural/digest
  tampering against ISO-IR-180 and an independent VN2 charmap.
- Lotus LICS classifies all 256 octets as 239 assignments and 17 explicit
  invalid bytes, proves the 234 canonical inverses and five duplicate compose-
  mark pairs, and exhausts every Unicode scalar, source and UTF-8 stream split,
  strict/discard/substitution policies, malformed UTF-8 offsets, and source
  tampering. The four HP 1991 extension rows remain distinguishable from the
  independently matching 1988 Xerox profile.
- The U.S. Army Tap Code pair-value profile classifies all 65,536 possible
  numeric-octet pairs as 25 valid matrix positions and 65,511 invalid pairs,
  checks every Unicode scalar against its 26 accepted uppercase inputs, and
  preserves pending row counts across every source split. Tests also cover the
  lossy K-to-C encoder policy, exact errors and recovery consumption, every
  complete-matrix encoder split, source tampering, and the independently
  matching Army and Naval History publications without claiming a generic Tap
  Code or an official byte transport.
- PASCII C-DAC GIST 1.0 independently checks all 256 source bytes in all four
  explicit profiles, every canonical inverse, every Unicode scalar, every
  two-scalar RHEY sequence/collision outcome, direct UTF-8 equivalence, public
  one-shot policies, and every stream boundary. Dedicated edge tests cover a
  terminal RHEY prefix, a nonmatching scalar in the next chunk, and a later
  malformed UTF-8 byte without losing first-error precedence. Exact assigned-
  byte and forensic raw profiles are bijective; the Urdu/Kashmiri and Sindhi
  profiles are visibly labeled non-normative Unicode 17 best fits. Byte 80 is
  unassigned, FA/FB/FE/FF are reserved, and no bare `PASCII`, Persian, or Arabic
  best-fit identity is invented. Compile-time validation freezes the ordered
  CSV, provenance classes, national deltas, sequence inference, VPUA blocks,
  source metadata, and both SHA-256 digests.
- Registry tests permanently separate the three Vietnamese identities:
  ISO-IR-180 and `VSCII` select VN2 `VSCII-2`; RFC 1456 `VISCII` remains the
  GNU-compatible Core codec; `TCVN`/`TCVN5712-1:1993` remain VN1. Core contains
  no fallback ISO-IR-180 alias, preventing an external-provider collision or a
  silent byte-incompatible conversion when Specs is absent.
- Every retained mapping and metadata asset is SHA-256 checked before its table
  is accepted. The package carries independently normalized factual tables and
  the licenses needed for retained upstream sources; copyrighted manuals are
  reference-only and are not redistributed. GNU libiconv 1.19 exposes no exact
  alias for these source-qualified profiles, so reports mark GNU comparison
  unavailable instead of claiming a false differential.

The corresponding runtime/harness digests, executable gate envelopes, and
release-versus-development package selection are machine-checked in the
"Recent source-qualified profile batch" section of `BENCHMARKS.md`.

`test/fixtures/all-unicode-scalars.utf32be` has 4,448,256 bytes, 1,112,064
ordered scalar values, and SHA-256
`d037f6200ae8845906b4372a8b3fcd39730e3a61c4af0e354823010e6f93be54`.
The default test suite performs every algorithmic round trip; the differential
runner additionally cross-checks ICU and writes `ALGORITHMIC_DIFFERENTIAL.md`.
