# Changelog

## Unreleased

- Re-run coverage on the exact shipping tree and bind the release evidence to
  623 passing Core tests at 93.30% total line coverage. The older OTP 27 result
  is now explicitly historical instead of being presented as a current-tree
  measurement; the split-suite count is corrected to Core 623 plus Extras 134.
- Rebind the shipping Core tree to a fresh all-code-point GNU libiconv 1.19
  differential after the final registry and UTF-7 fixes. All 112 codecs match
  in forward, reverse, and both cross-decoder directions across U+0000 through
  U+10FFFF, including the complete surrogate range.
- Preserve output order when streamed UTF-7 recovery follows a complete code
  point in an open shifted sequence. The pending code point is now emitted
  before the malformed-byte callback or byte substitution, matching one-shot
  conversion at every input split.
- Make configured external-codec startup transactional. Iconvex now validates
  the complete configured batch before touching registry state, conflict-checks
  every missing name before one atomic ETS publication, checkpoints only after
  full success, and restores inherited rows on rejection. A valid prefix can no
  longer survive a later invalid entry and reappear after a failed application
  start.
- Rebind release evidence after the final runtime and test changes. The complete
  1,114,112-code-point differential passes all 112 Core codecs against GNU
  libiconv 1.19 with zero forward, reverse, or cross-decoder mismatches, and
  source-bound coverage markers now identify the exact shipping tree.
- Preserve target/source error order during terminal external recovery with
  byte substitution: an earlier unrepresentable target character now wins over
  a later incomplete source unit for resynchronizing and stopping codecs.
- Keep external registry and Heir processes alive when unrelated mailbox
  messages arrive, without changing tagged ETS-transfer handling.
- Make package-local documentation warnings fatal and require immutable Mix
  locks in the aggregate extension CI matrix.
- Cut the exhaustive ISO-2022-KR reverse-discard hot path from 28,248 to 9,561
  reductions and from 277.436 to 153.290 microseconds in an identical
  calibrated OTP 28 run. The decoder now validates its dense Korean table once,
  indexes it in the state loop, and emits through a private-append binary while
  preserving byte-order, malformed-pair, truncated-escape, callback, and every-
  split behavior.
- Make external codec/provider route construction generation-coherent across
  conversion, buffered converters, and lazy streams. A shared pre-publication
  seqlock covers registry, Heir, initialization, and provider changes; bounded
  optimistic retries fall back to serialized capture and recover killed
  writers without exposing an old generation.
- Reject partial or metadata-changed managed package restarts after exact
  token-loss adoption fails, while retaining intentional coexistence with
  pre-existing strict and caller-owned codecs.
- Preserve external decoded prefixes during structural-EOF target arbitration
  by using the codec's required discard callback at the exact incomplete
  boundary. Earlier target errors can win without weakening the original
  strict source error.
- Preserve stable decoded prefixes when plain lazy-Stream discard reaches a
  counted frame that declares an absent terminal source byte. Structural EOF
  remains a typed incomplete error for strict, substitution, and callback
  policies, and no callback is invented without a physical byte.
- Preserve the external-codec API boundary for stateful metadata: one-shot
  substitution and invalid-byte callbacks use the required whole-input codec
  callbacks when optional incremental decoder callbacks are absent, while
  lazy Stream conversion continues to return `:streaming_unsupported`.
- Make core packed-decoder failures transport-native. Semantic failures now
  report physical bit offsets instead of temporary unpacked-byte offsets, with
  exact MSB bitstrings or self-describing LSB wire fragments for multibyte
  error sequences.
- Make stateful Stream boundaries byte-identical to one-shot conversion.
  ISO-2022-JP-MS now scans ignored SO/SI controls without corrupting its next
  mode, JP/CN callbacks retain the complete bounded invalid-escape diagnostic
  frame at every split, and UTF-7 keeps a plus inside an already-active Base64
  shift instead of prematurely emitting `-+-`.
- Make `encode_substitute/2` a required external-codec callback, parallel to
  `encode_discard/1`. Registration now rejects codecs without the one-pass
  callback, and malformed results return a typed request error instead of
  entering the occurrence-probing fallback. This makes repeated substitution
  linear while preserving codec-owned state and longest-match semantics.
- Extend the GNU libiconv 1.19 exhaustive differential from Unicode scalar
  values to every code point U+0000..U+10FFFF. The sequential UCS-4BE corpus
  now includes all 2,048 non-scalar surrogate code points, and forward,
  reverse, and both cross-decode directions use UCS-4BE byte comparisons.
- Add direct, endian-aware binary paths between explicit UCS-4 and the
  UCS-4/UTF-16/UTF-32/JAVA families, including generic BOM/endian recovery and
  callback-safe fallback. The combined performance gate now uses three
  isolated samples per direction to exclude GC outliers while retaining its
  strict 30x-GNU ceiling.
- Make table-provider ownership publication atomic and retry-safe. Package
  restarts recover the same cleanup token after a lost reply, interrupted
  legacy registrations are adopted, caller-created providers remain unowned,
  and stale tokens cannot remove replacements. Streaming recovery for a final
  truncated ISO-2022 escape now consumes the complete reported suffix, matching
  one-shot Iconvex and GNU libiconv without changing UTF-7 replay semantics.
- Replace generic UTF-16's per-code-unit BOM-filter reconstruction with an
  alignment-aware binary marker scan. The exhaustive reverse direction drops
  from a 38.11x GNU breach to 4.26x in the final combined run while retaining
  midstream endian changes,
  malformed fallback, and marker-like byte pairs spanning code-unit boundaries.
  The scan also falls back before removing a BOM immediately after a high
  surrogate, so it can never join surrogate halves that were not adjacent in
  the source.
- Completed GNU libiconv 1.19 boundary parity for C99, JAVA, UTF-7, UTF/UCS
  targets, and Unicode tags. C99 now accepts GNU's letter digits and full
  unsigned 32-bit escapes; JAVA and UTF-7 preserve isolated surrogate units
  supplied by explicit UCS-4 sources; default U+FFFD fallback, discard,
  transliteration, and substitution precedence are source-independent; and
  generic UTF-16/32 suppress their BOM when policy handling emits no character.
  External codec IDs cannot opt into built-in fallback by collision.
- Implemented the complete ISO-2022-JP-2 Unicode language-tag state machine.
  Case-insensitive `ja`, `ko`, and `zh` select GNU's Japanese, Korean, and
  Chinese preference order while cancellation, partial tags, G2 designation,
  newlines, recovery policies, and every streaming split remain orthogonal.
  Sparse preference overrides retain warm multi-million-codepoint throughput.
- Final general review now distinguishes GB18030 diagnostic framing from GNU
  recovery consumption. Strict errors and streaming callbacks retain the exact
  malformed 1-, 2-, 3-, or 4-byte candidate, while discard and substitution
  consume only the offending lead byte and reprocess the suffix exactly like
  GNU libiconv 1.19. Every chunk split is covered. A repeated registry-only
  crash regression also proves that OTP preserves the configured ETS heir.
- Made normal clean-checkout tests independent of ignored generated ExDoc
  files. A dedicated CI documentation job generates every mirror and then runs
  the byte-exact mirror contract explicitly.
- Closed the review-rigor-v2 correctness and performance findings. Native
  multibyte recovery now consumes complete invalid units while applying
  byte-substitution once per physical byte and reporting one absolute-offset
  event; ISO-2022-JP/CN retain every incomplete designated escape prefix;
  packed codecs honor their declared bit order; invalid conditional
  unregister calls return typed errors; and CP1258/TCVN encoders reuse cached
  base-byte sets instead of rescanning tables per code point. UTF-7 shifted
  output is provisional until base64 padding, UTF-16 units, and surrogate
  pairing validate, and byte-at-a-time shifted input is linear rather than
  quadratic. Versioned external-registry snapshots survive consecutive worker
  crashes but are erased at a clean application stop.
- Added five source-qualified native UNIVAC FIELDATA codecs through
  `iconvex_specs`: the complete reversible 1100 Series table and four 4009
  Display Console input, output, readable-lossless, and raw-forensic views.
  Primary-manual vectors cover every unit and directional action; strict,
  discard, substitution, direct UTF-8, split-safe streaming, registry, and
  packed MSB/LSB paths are exhaustive, including the historical layout of six
  characters per 36-bit word. Review follow-up corrects packed error offsets to
  physical bit positions, registers the source-qualified `EXEC-8-FIELDATA` and
  `FIELDATA-1100` aliases while rejecting ambiguous family labels, and preserves
  the 4009's proprietary diamond-enclosed wave as U+F402F instead of claiming
  the materially different modern U+1F6D1 sign.
- Added atomic multi-owner registration sets for the distributed Extras,
  Telecom, and Specs applications. The four packages now coexist in every
  start order with 2,093 unique canonical names; all 227 Specs/Extras name
  overlaps have deterministic canonical-first/package-priority winners, and
  stopping a winner exposes its fallback without a transient lookup gap.
  Public third-party registration remains strict and collision-rejecting.
- Made external codec ownership crash-safe and replacement read-atomic. A
  protected ETS heir preserves registrations and exact cleanup tokens across a
  supervised registry-worker restart, repairs interrupted name indexes, and
  republishes replacements at one module-row commit point.
- Added lazy bounded-memory `stream/4` and `stream!/4` conversion with
  split-safe table lookahead, built-in HZ/ISO-2022/UTF-7 state, UTF BOM
  handling, absolute enumeration-time errors, and explicit stateless/stateful
  callbacks for external codecs. Added `on_invalid_byte` so callers can assign
  file-format semantics to unmapped PETSCII controls without weakening strict
  standards mappings.
- Made the complete external specs stack publishable without reducing codec
  coverage: 1,050 historical ICU runtime tables now arrive through three
  transparent Hex-size-bounded provider shards. Core table entries honor the
  provider registry when no application is explicitly pinned; clean unpacked
  production compilation and all shard boundaries are release-tested. The
  finite safe-ETF schema now also covers mixed-EBCDIC mode/map atoms for truly
  cold archive loads.
- Added source-bound native SI 960/DEC Hebrew 7-bit and DEC Hebrew 8-bit
  profiles through `iconvex_specs`, including exhaustive byte/reverse tests,
  strict and discard paths, direct UTF-8 conversion, SI 960 MSB/LSB packed
  septets, generated inventories, and production benchmarks.
- Joined Kermit's `HEBREW-7` and the encyclopedia SI 960 identity under an
  audited exact bridge while retaining DEC Hebrew 8-bit as a separate cluster.
  At that audit step, the research catalog had 1,646 clusters, 1,226 implemented codecs,
  218 actionable codec gaps, and 168 research candidates.
- Audited numeric EBCDIC encyclopedia titles for the twenty exact implemented
  IBM code pages and joined DEC Multinational to DEC-MCS. The bridges are
  deliberately narrow and leave `EBCDIC 001` and `EBCDIC 8859` unresolved.
- Re-audited every item in the deep-dive review against executable evidence.
  Added the missing ISO-2022-JP policy/state branches after coverage exposed an
  88.00% regression, then added behavioral matrices for the remaining UTF-7,
  Stream, ISO-2022, Unicode, registry, and recovery paths. At that review
  checkpoint, the clean 325-test run measured 97.25% for ISO-2022-JP and 95.06%
  total coverage; all five
  reviewed decoder/stream engines are at least 96.34%.
- Bridged DEC Special Graphic and DEC Technical research identities to the
  pinned VT330/VT340 figures and four external GL/GR runtime profiles. The
  generated catalog now merges the Kermit, Wikidata, and Wikipedia titles as
  two high-confidence implemented clusters while preserving every alias and
  the exact DEC source.
- Regenerated research totals after the DEC audit: 1,668 clusters, 1,224
  implemented, 242 actionable codec gaps, and 168 research candidates.
- Audited encyclopedia-derived gaps: formal ISO/IEC 8859 part titles now merge
  with exact GNU identities, implemented Mac/ISCII/TSCII/ZX article names are
  source-bridged, and broad/withdrawn standards have explicit non-codec
  dispositions. Regenerated external inventory recognizes native ECMA-1 and
  DEC-SIXBIT plus their six-bit packed transports from `iconvex_specs`.
- Bridged the three incompatible DEC RADIX-50 word families to pinned PDP-9/15,
  PDP-6/10, and PDP-11 vendor manuals and the external package's exact 18-, 36-,
  and 16-bit APIs plus explicit endian byte transports. The generated catalog
  retains every normative source and classifies the encyclopedia title as
  implemented rather than a gap.
- Bridged CDC Display Code to Control Data's pinned NOS 63/64-character tables
  and all four external CDC/ASCII graphic runtime profiles. The research catalog
  now retains the vendor source and classifies the historical title as
  implemented rather than a gap.
- Extended that CDC bridge through the manual's complete 6/12 Display Code
  grammar and all 128 ASCII conversions, covering both 63- and 64-character
  modes plus MSB/LSB packed transports from the external specs package.
- Replaced per-unit generic packed-bit allocations with bounded binary chunks
  and specialized six-bit 24-bit groups. The production benchmark now measures
  162.87/40.14 MiB/s for six-bit MSB pack/unpack and 165.04/43.37 MiB/s for LSB.
- Reworked chunked conversion as an O(1)-per-feed buffered transaction whose
  final bytes and full-stream error offsets exactly match one-shot conversion
  across every split, policy, BOM, composition, and longest-match boundary.
- Added terminal converter state, immutable resolved codec handles, strict
  option/suffix validation, and stable behavior across external-registry changes.
- Added native state-preserving malformed-input recovery for ISO-2022, HZ,
  UTF-7, UTF-16/32, and UCS-2/4, including BOM-selected endian state.
- Versioned and serialized lazy table/transliteration caches, enabled safe ETF
  decoding on genuinely cold loads, and added concurrent cold-start tests.
- Raised measured line coverage from 68.75% to above 90% with malformed-state,
  variant, policy, every-position, and every-split branch matrices.
- Bound the saved all-scalar GNU differential to runtime and runner SHA-256
  digests so any implementation drift fails the ordinary test suite.
- Added a hard 30x-GNU performance ceiling to the combined 198-codec differential;
  versioned ISO-2022 precedence maps, retained HZ/KR table handles, direct nibble
  escape conversion, and BEAM Unicode transcodes cut total wall time by 83% while
  preserving byte-exact output.
- Added complete public API specs/docs, ExDoc, compatibility CI, and an unpacked
  Hex-artifact clean-consumer smoke test; verification corpora stay in source
  control instead of every consumer download.
- Split GNU's 86 non-default extra/platform codecs into the optional
  `iconvex_extras` package. Core now exactly matches the 112-codec default GNU
  build; the extras application auto-registers the complete complement.
- Added package-ownership parity tests, separate mapping artifacts, generated
  core/extras codec matrices, and independent 112-codec and combined 198-codec
  every-Unicode-scalar differential reports.
- Added `Iconvex.Codec` and supervised external codec registration, including
  configuration loading, aliases, conflict validation, stateful streaming,
  native linear discard callbacks, and optional direct UTF-8 fast paths.
- Mirrored
  267 GNU libiconv 1.19 test files plus one derived configured Makefile and
  ported the full portable charmap, snippet, transliteration, substitution,
  EBCDIC, discard, shift, Unicode BOM-state, and generated-range coverage to
  ExUnit.
- Added byte/Unicode substitution formats and IBM-1047 `ZOS_UNIX` surface support.
- Corrected UTF-7 shifted-sequence error offsets and streamed BOM byte-order state.
- Corrected GB18030:2005 generation to include irreversible BMP encodings without
  treating them as forward mappings.
- Added byte-exact GNU encoding-definition and `iconv -l` snapshots, exact parity
  checks for all 198 fixed codecs and 758 aliases, and a generated side-by-side
  support matrix.
- Added a deterministic UTF-32BE corpus containing all 1,112,064 Unicode scalar
  values and an executable forward/reverse/cross-decode differential harness;
  all 198 codecs match GNU libiconv 1.19 byte-for-byte.
- Replaced restart-based discard recovery with linear, state-preserving codec
  loops; corrected UTF-7 noncharacters, generic Unicode BOM behavior, Vietnamese
  combining state, exact GNU HZ tilde behavior, standard JIS row boundaries, and
  JP-2 conversion preference order exposed by the exhaustive run.

## 0.1.0

- Port all 198 portable GNU libiconv 1.19 canonical encodings and aliases.
- Add table, Unicode, GB18030, escape, HZ, UTF-7, and ISO-2022 state machines.
- Add GNU discard and transliteration behavior, typed errors, and chunked input.
- Add exhaustive generated-table and upstream-fixture conformance tests.
- Add dependency-free performance benchmarks and strict-mode fast paths.
