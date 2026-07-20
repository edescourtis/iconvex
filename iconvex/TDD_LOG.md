# TDD log

Each feature starts with a test observed failing (RED), followed by minimal implementation
that makes it pass (GREEN), then refactoring with full suite remaining green.

## Review follow-up — provider ownership and stateful EOF recovery

- Provider RED: two new lifecycle contracts failed in an 8-test focused run.
  Same-application retry returned `:existing` instead of the committed token,
  and an interrupted legacy provider record could not be adopted for cleanup.
- Provider GREEN: owned registrations publish `{app, {:owned, token}}` in one
  persistent-term write, retry returns that exact token, legacy records migrate
  under the per-provider lock, and unowned manual registrations retain their
  independent lifecycle. The focused cache/stream/engine run passes 19/19.
- Provider coverage RED: the first fresh 443/443 run remained behaviorally
  green, but the new ownership branches reduced the table-provider module's line coverage
  to 79.44% and total coverage to 94.00%, below the 87%/94.3% gates.
- Provider coverage GREEN: five focused lifecycle contracts cover atomic and
  legacy conflicts, same-app unowned preservation, legacy token migration,
  wrong/invalid token cleanup, and fetch normalization. The focused run passes
  13/13; a fresh full run passes 448/448 with the table-provider module at 91.59% and
  total coverage at 94.44%.
- Stateful RED: a 5-test focused run failed when a streamed, truncated
  ISO-2022 escape consumed only `ESC` and leaked the remaining syntax byte.
- Stateful GREEN: non-UTF7 built-in stateful codecs consume the complete
  reported `:incomplete_sequence` at EOF. ISO-2022-JP, JP-1, JP-2, JP-MS, KR,
  CN, and CN-EXT now match one-shot recovery across every byte split for
  discard and per-byte substitution; UTF-7 keeps introducer-only replay.

## Review follow-up — directional UTF-16 performance

- RED: after the exhaustive gate began evaluating each direction independently,
  all 198 codecs remained byte-exact but generic UTF-16 reverse conversion took
  1,067 ms versus GNU's 28 ms, a 38.11x breach hidden by the prior aggregate.
- GREEN: the decoder now finds aligned BOM/swap markers with `:binary.match/3`
  and copies only the few surviving binary spans instead of allocating one list
  cell and sub-binary per UTF-16 unit. The same 1,112,064-scalar directional
  probe passes byte-exactly at 146 ms versus GNU's 46 ms (3.17x), even while the
  full Specs suite was concurrently active. The final isolated combined run
  records 98/23 ms (4.26x), and the performance/algorithmic selection passes
  12/12.

## Cycle 1 — public contract, registry, first conversion

- RED: `mix test`
- Observed: 3 tests, 3 failures; `Libiconv` module/functions undefined.
- GREEN target: 198 canonical encodings, case-insensitive aliases, CP1252 → UTF-8.
- GREEN observed: `mix test` — 3 tests, 0 failures.

## Cycle 2 — generic table codecs

- RED target: reverse single-byte conversion, multibyte conversion, typed invalid-sequence error.
- RED observed: test compilation fails because `Libiconv.Error` does not exist; conversion paths also unsupported.
- Naming requirement added before GREEN: public library/module changed to `Iconvex`.
- GREEN observed: `mix test` — 6 tests, 0 failures.

## Cycle 3 — algorithmic codecs

- RED target: Unicode BOM/endian/surrogates, C99/JAVA escapes, GB18030 supplementary plane.
- RED observed: 5 tests, 5 failures; all algorithmic targets report `:unsupported_conversion`.
- GREEN observed: `mix test` — 11 tests, 0 failures.

## Cycle 4 — HZ and ISO-2022-KR state machines

- RED target: GNU 1.19 snippets plus explicit shift/designation behavior.
- RED observed: 4 tests, 4 failures; both encodings report `:unsupported_conversion`.
- GREEN observed: `mix test` — 15 tests, 0 failures.

## Cycle 5 — ISO-2022-JP family

- RED target: GNU 1.19 snippets for JP, JP-1, JP-2, JP-3, and JP-MS plus explicit mode changes.
- RED observed: 6 tests, 6 failures; all five variants report `:unsupported_conversion`.
- GREEN observed: `mix test` — 21 tests, 0 failures. The large JP-3 and JP-MS fixtures
  exercise JIS X 0213 combining mappings and CP50221 extensions byte-for-byte.

## Cycle 6 — ISO-2022-CN family

- RED target: GNU 1.19 ISO-2022-CN and ISO-2022-CN-EXT snippets.
- RED observed: 2 tests, 2 failures; both variants report `:unsupported_conversion`.
- GREEN observed: `mix test` — 23 tests, 0 failures.

## Cycle 7 — UTF-7

- RED target: GNU 1.19 snippet, direct/plus/supplementary handling, malformed shifts.
- RED observed: 3 tests, 3 failures; UTF-7 reports `:unsupported_conversion`.
- GREEN observed: `mix test` — 26 tests, 0 failures.

## Cycle 8 — iconv options and streaming

- RED target: `//IGNORE`, `//NON_IDENTICAL_DISCARD`, `//TRANSLIT`, typed bang API,
  multibyte chunk splits, and safe stateful-source streaming.
- RED observed: 5 tests, 5 failures; suffixes were unresolved and all new APIs undefined.
- GREEN observed: `mix test` — 31 tests, 0 failures.

## Cycle 9 — exhaustive generated-table conformance

- RED target: decode and semantic re-encode of every packed mapping entry.
- RED observed: CP1258 exposed accidental composition across fixture boundaries; after isolating
  entries, a no-NUL fixed-width code set exposed a separator assumption.
- GREEN/refactor: all mappings pass. A specialized single-codepoint encoder removed an O(n²)
  `length/1` loop, reducing this test from 36.9 seconds to 1.8 seconds.
- GREEN observed: `mix test` — 33 tests, 0 failures.

## Cycle 10 — Unicode and CN-EXT expansion

- GNU UCS-2/4 and UTF-16/32 fixtures passed on first execution.
- RED target: ISO-IR-165 G1 designation, using a character absent from GB2312 and CNS.
- RED observed: missing `iso_ir_165.etf` exposed an internal ID mismatch.
- GREEN observed: exact GNU bytes `ESC $ ) E SO 7E 57 SI`; full suite green.

## Cycle 11 — untrusted name hardening

- RED target: 100 unknown encoding names must not add atoms.
- RED observed: atom count increased by exactly 100.
- GREEN: generated aliases now use binary keys; unknown names leave atom count unchanged.

## Performance refactor

- Baseline and optimized production benchmarks are recorded in `BENCHMARKS.md`.
- Strict fast paths and byte-shape dispatch retained only with the full suite green.
- Final correctness run: 45 tests, 0 failures; warnings-as-errors compilation and Hex package
  validation also pass.

## Cycle 12 — complete upstream test corpus and unit-test ports

- RED corpus target, later provenance-corrected in Cycle 105: audit 267 exact
  GNU libiconv 1.19 `tests/` files plus one derived configured `Makefile` and
  verify deterministic separate and combined aggregate SHA-256 values.
- RED behavior target: port `check-translit`, `check-translitfailure`, `check-subst`,
  `check-ebcdic`, `test-discard`, `test-shiftseq`, `test-to-wchar`, and `test-bom-state`.
- RED observed: 10 behavior tests, 8 failures. Missing behavior was byte/Unicode
  substitution, target-sensitive transliteration and failure, the `ZOS_UNIX` surface,
  UTF-7 shifted error position, and byte-order state across streamed chunks.
- GREEN behavior observed: 39 tests, 0 failures across the behavior ports and all 27
  stateful/Unicode/table snippet pairs.
- RED charmap observed: 167 tests, 4 failures. One was a separator assumption, two were
  a test-range typo, and one exposed omitted GB18030:2005 irreversible BMP encodings.
- GREEN charmap observed: 167 tests, 0 failures after correcting the harness and table
  generator. This covers all 164 supplied mapping files and U+10000..U+10FFFF for both
  GB18030 revisions.
- Final GREEN observed: `mix test` — 249 tests, 0 failures. Compilation with
  `--warnings-as-errors` and the production benchmark also pass.

## Cycle 13 — upstream coverage traceability

- RED target: machine-check all 268 files and every active `Makefile.in` invocation
  against a published traceability matrix.
- RED observed: 6 audit tests, 1 failure; coverage document absent.
- GREEN target: exact file-category union, 165/165 stateless calls, 27/27 stateful calls,
  all transliteration/shell/C calls, digest, and explicit platform-only disposition.
- GREEN observed: 6 audit tests, 0 failures; full suite 255 tests, 0 failures.

## Cycle 14 — exhaustive codec parity

- RED target: independently parse byte-exact GNU encoding definitions and default
  `iconv -l`; prove canonical-set, alias, and implementation parity; publish both lists.
- RED observed: 6 parity tests, 1 failure; support matrix absent.
- GREEN target: 198/198 fixed codecs, 758/758 aliases, 112/112 default `iconv -l`
  groups, zero fixed-codec differences, explicit `CHAR`/`WCHAR_T` adapter disposition.
- GREEN observed: 6 parity tests, 0 failures; full suite 261 tests, 0 failures;
  warnings-as-errors and Hex package validation pass.

## Cycle 15 — every-scalar GNU differential

- RED target: generate all 1,112,064 Unicode scalar values as UTF-32BE; for every
  fixed codec compare Iconvex and GNU 1.19 `//IGNORE` forward bytes, reverse
  results, and both cross-decodes.
- RED observed: artifact test failed before corpus/runner/report existed. First
  full execution passed 193/198; failures were CP1258, TCVN, JIS_X0212,
  ISO-2022-JP-1, and ISO-2022-JP-2. Earlier representative RED runs also exposed
  UTF-7 U+FFFE handling, repeated UTF-16 BOMs, HZ tilde behavior, and JIS vendor
  row leakage.
- GREEN implementation: native linear discard loops retain encoder state and
  longest mappings; Vietnamese decoders reproduce GNU buffering/composition;
  JIS row boundaries and JP-2 preference order now match GNU. Removed quadratic
  JIS X 0213 `length/1` probing.
- GREEN observed: 198/198 codecs, 0 mismatches, 1,112,064/1,112,064 scalars;
  corpus SHA-256 `d037f6200ae8845906b4372a8b3fcd39730e3a61c4af0e354823010e6f93be54`.
- Final GREEN observed: `mix test` — 262 tests, 0 failures; compilation with
  `--warnings-as-errors` and Hex package validation pass.

## Cycle 16 — external codec libraries

- RED target: behaviour-backed codecs registered by canonical name, alias, or
  module; fast UTF-8 callbacks; native discard callbacks; stateful streaming;
  configured startup; and built-in/external collision rejection.
- RED observed: focused suite 5 tests, 5 failures; `Iconvex.Codec`,
  `register_codec/1`, and `unregister_codec/1` did not exist.
- First GREEN exposed a second RED when an optional UTF-8 encoder returned its
  normal strict error tuple: conversion raised a function-clause error instead
  of returning `Iconvex.Error`.
- Policy error coverage exposed a third RED with the same failure shape from an
  external `encode_discard/1` callback; the adapter now normalizes both paths.
- GREEN implementation: supervised read-concurrent ETS registry, compile-map-first
  built-in resolution, validated metadata/callbacks, direct module lookup,
  application configuration, stateful buffering, linear discard dispatch, and
  strict fast-path error adaptation.
- GREEN observed: focused suite 6 tests, 0 failures; full suite 268 tests,
  0 failures. Dedicated production benchmark records zero-copy external ASCII
  at 591.26 MiB/s into UTF-8 and 586.21 MiB/s from UTF-8.

## Cycle 17 — core/extras package boundary

- RED target: core must equal GNU `encodings.def` exactly; every codec from
  `encodings_extra.def`, `encodings_aix.def`, `encodings_dos.def`,
  `encodings_osf1.def`, and `encodings_zos.def` must be absent from core and
  supplied by a separately startable package.
- RED observed: focused boundary suite 2 tests, 2 failures. Core still exposed
  all 198 codecs and shipped non-default mapping tables.
- GREEN implementation: generator partitions the same GNU source union into 112
  core and 86 `iconvex_extras` wrappers, prunes stale tables from both packages,
  assigns stable shared-engine IDs, and auto-registers/unregisters extras with
  its OTP application.
- GREEN package evidence: core has exactly 112 codecs, 416 aliases, and 86 table
  files (84 codec tables plus two CP50221 helpers). Extras has exactly 86 codecs,
  342 aliases, and 85 tables plus ISO-2022-JP-3. Stopping extras restores 112;
  restarting restores 198 and all 758 aliases.
- GREEN tests: core `mix test` — 183 tests, 0 failures; extras `mix test` — 94
  tests, 0 failures; both compile with warnings treated as errors.
- GREEN exhaustive evidence: fresh core run matched GNU 112/112; fresh combined
  run matched GNU 198/198. Both processed all 1,112,064 Unicode scalars with 0
  mismatches using corpus SHA-256
  `d037f6200ae8845906b4372a8b3fcd39730e3a61c4af0e354823010e6f93be54`.
- GREEN performance: byte-identical CP932/CP943 pair measured 1.6% decode and
  0.6% encode overhead for extras dispatch on OTP 28; both paths use the same
  native linear packed-table engine.

## Cycle 18 — runtime name inventory and IBM-5054

- RED target: ICU's pinned converter registry says `ibm-5054` is an alias of
  `ISO-2022-JP-1`; the existing exhaustive codec returned `:error` for that
  name. Focused contract result: 5 tests, 1 failure.
- GREEN alias: added the ICU spelling to the generated specification-alias map;
  the ISO-2022-JP-1 byte implementation and its whole-Unicode differential
  remain unchanged.
- Second RED: the research catalog could not discover the new runtime alias,
  and no exact published core name inventory existed.
- GREEN inventory: `SUPPORTED_NAME_INVENTORY.csv` is generated from the
  compiled registry and checked field-for-field against all 442 core names and
  canonical targets. Research consumes the CSV directly.
- GREEN evidence: combined parity/catalog suite 17 tests, 0 failures; core
  remains exactly 112 GNU-default codecs and resolves all 416 GNU core
  spellings plus 26 separately attributed specification/ICU aliases.

## Cycle 19 — generic fixed-width packed transports

- RED target: exact MSB and physical LSB packing, strict range/padding/length
  validation, all widths 1–8, GSM's published `hellohello` vector, and direct
  UTF-8 helpers. The new test initially failed because `Iconvex.Packed` did not
  exist.
- GREEN observed: 5 tests, 0 failures. Every possible unit at every supported
  width round-trips in both bit orders; exact non-byte-aligned lengths survive.
- Performance gate: the production benchmark measures 1 MiB inputs separately
  for widths 5, 6, and 7. The streaming LSB loop is also retained as the A/B
  replacement for telecom's whole-message big-integer implementation.

## Cycle 20 — deep-dive conversion-state regressions

- RED target: reproduce every confirmed finding in the supplied
  `iconvex-deep-dive.md` review:
  stateful malformed recovery, incomplete-policy chunking, destination lookahead,
  Vietnamese source composition, repeated destination BOMs, mutable external
  registration, full-stream offsets/lifecycle, and request validation.
- RED observed: `test/deep_dive_regression_test.exs` started at 7 tests, 7 failures.
- GREEN implementation: chunk feeds append reversed iodata in O(1) and finalization
  performs one conversion through entries resolved at `new/3`; native recovery loops
  retain ISO-2022/HZ/UTF-7 state; `finish_with_state/1` exposes the terminal value;
  options and suffixes return one typed non-raising contract.
- GREEN observed: focused regression and existing streaming/stateful suites pass.

## Cycle 21 — cache lifecycle and cold safety

- RED target: stale-version invalidation, concurrent cold first use, and safe ETF
  decoding. Initial cache tests failed on stale terms and duplicate cold loads.
- First GREEN exposed a second cold-only RED: `binary_to_term(..., [:safe])` rejected
  generated `MapSet` table-schema atoms that a warm VM had already interned.
- GREEN implementation: cache values carry schema/application versions, cold loads
  serialize through `:global.trans/2`, table schema atoms are explicitly interned,
  and both table/transliteration assets use safe ETF decoding.
- GREEN observed: 64-way cold fetches return the same exact term; stale entries are
  replaced; HZ/KSC/CNS tables load in a genuinely new BEAM.

## Cycle 22 — branch-focused coverage gate

- RED observed: full suite passed but built-in line coverage was 68.75%, below the
  configured 90% gate; state engines ranged from 40.18% to 63.83%.
- GREEN tests inject malformed bytes at every position of representative state
  streams, test every split under strict/discard/substitution, cover JP/CN external
  variants with synthetic external tables, and exercise every Unicode width/endian,
  escape, GB18030, table, packed, and provider error branch.
- GREEN observed: 227 tests, 0 failures, 91.22% total coverage; every state-machine
  engine is at least 90%. Subsequent Unicode BOM-policy branches keep total coverage
  above the 90% gate.

## Cycle 23 — differential freshness and policy parity

- RED target: bind the saved 1,112,064-scalar report to source artifacts and the
  runner. The old report lacked both hashes, so its normal artifact test failed.
- First fresh GNU 1.19 run found 110/112 PASS: HZ source bytes and ISO-2022-JP-MS
  discard recovery had drifted from the saved report. Focused all-scalar reruns
  turned both GREEN after restoring GNU's literal-tilde quirk and consuming SO/SI
  in the JP-MS recovery loop.
- A targeted GNU probe exposed another RED after a little-endian UTF-16 BOM:
  discard produced `A䈀` instead of `AB`, and byte substitution lost endian state.
  Native UTF-16/32 and UCS-2/4 recovery now consumes the complete malformed unit,
  substitutes each offending byte, and retains BOM-selected byte order.
- GREEN gate: the report records corpus, runtime-artifact, and runner SHA-256 values;
  changing any runtime source/table/tool makes `mix test` fail until a fresh GNU
  differential regenerates the report.

## Cycle 24 — 30x GNU performance ceiling

- RED observed: the source-bound 198-codec run was correct but 31 codecs exceeded
  30x GNU. Worst cases were ISO-2022-JP-3 at 279.1x, JP-MS at 199.0x, JP-2 at
  153.2x, JP-1 at 107.4x, and ISO-2022-CN-EXT at 102.0x.
- Profile RED: JP-2 spent 15,628 ms encoding and 48 ms decoding; JP-MS spent
  11,418 ms encoding and 23 ms decoding. Repeated table/closure dispatch, not
  state decoding, was the defect.
- GREEN implementation: versioned stateful precedence maps perform one lookup per
  scalar; HZ/KR retain table handles; JAVA/C99 use nibble arithmetic; explicit
  Unicode pairs use direct BEAM transcodes with exact malformed/native fallback.
- GREEN correctness: focused state/variant/Unicode tests, fresh 112/112 core and
  198/198 combined all-scalar differentials, zero mismatches.
- GREEN performance: combined wall time fell from 261,695 ms to 43,849 ms. The
  executable combined gate reports zero codecs above 30.00x GNU; worst was
  generic UCS-4 at 26.84x.
- Coverage RED/GREEN: new branches initially reduced total coverage to 88.79%;
  targeted fast/fallback tests restored 91.21% with 233 tests and zero failures.

## Cycle 25 — encyclopedic gap identity audit

- RED observed: two research contracts failed because already implemented
  Mac/ISCII/TSCII/ZX mappings appeared as missing under article titles, while
  umbrella standards such as EBCDIC, ISO 646, ISO/IEC 8859, and ECMA-48 were
  counted as byte-codec gaps.
- GREEN implementation: exact formal ISO/IEC 8859 part normalization, seven
  source-backed article-title bridges, and explicit family/control/withdrawn/
  repertoire dispositions. The Wikipedia-sourced actionable queue fell from
  84 to 54 without claiming an unverified mapping.
- GREEN observed: 14 focused research contracts, zero failures; every numbered
  published ISO/IEC 8859 part merges with its GNU and Iconvex identity, while
  never-published part 12 remains explicitly unassigned.

## Cycle 26 — official six-bit standards bridge

- RED originated in `iconvex_specs`: seven contracts failed before ECMA-1 and
  DEC-SIXBIT codecs, pinned normative sources, and packed transports existed.
- GREEN research integration consumes the regenerated external inventory and
  joins both distinct codecs to the historical `DEC SIXBIT/ECMA-1` catalog row.
  The row is now implemented with both source URLs and remains GNU-unsupported.

## Cycle 27 — distinct DEC RADIX-50 word-family bridge

- RED observed: the Wikipedia-title research contract still classified DEC
  Radix-50 as a codec gap after both explicit-endian native transports were
  added to `iconvex_specs`.
- A second RED required the catalog row to preserve distinct PDP-9/15,
  PDP-6/10, and PDP-11 normative sources and exact-width runtime identities;
  the PDP-11 manual alone did not substantiate the whole encyclopedia family.
- GREEN integration adds all three pinned DEC manuals, bridges the exact 18-,
  36-, and 16-bit APIs plus explicit endian byte transports, and consumes the
  regenerated external inventories. The merged row retains all three source
  URLs and remains GNU-unsupported.
- GREEN observed: 15 focused research contracts, zero failures. Catalog totals
  are 1,671 clusters, 1,221 implemented, 247 codec gaps, and 169 research
  candidates; Wikipedia-sourced codec gaps fall from 53 to 52.

## Cycle 28 — CDC Display Code 63/64 profile bridge

- RED observed: the catalog still reported CDC Display Code as a codec gap after
  the external package added four names; the encyclopedia record had no
  authoritative mapping source or exact profile identities.
- GREEN integration adds Control Data's May 1980 NOS Operators Guide, including
  its distinct CDC/ASCII graphic tables and 63/64-character colon/percent
  anomaly, then consumes all four runtime and packed-profile identities.
- GREEN observed: 16 focused research contracts, zero failures. Catalog totals
  remain 1,671 clusters while implemented rises to 1,222 and codec gaps fall to
  246; the Wikipedia-sourced codec-gap count falls from 52 to 51.

## Cycle 29 — complete CDC NOS 6/12 Display Code

- Source audit rendered and inspected the pinned NOS Operators Guide's printed
  pages A-1 through A-7. Tables A-1/A-2 define every one of the 128 ASCII
  conversions, the `74`/`76` escape grammar, and the distinct 63/64 profiles.
- RED observed in `iconvex_specs`: six new conformance tests produced six
  failures before either 6/12 codec existed. The research bridge then produced
  one failure in 16 contracts until the exact runtime names and source scope
  were catalogued.
- GREEN implementation adds `CDC-6-12-DISPLAY-CODE-63` and `-64`, strict and
  discard conversion, direct UTF-8 paths, aliases, and generic packed MSB/LSB
  transports. The independent oracle checks all 128 canonical mappings, all
  4,096 two-unit inputs in each mode, every high octet at two positions,
  malformed/truncated escapes, alternate colon decoding, and an exact 42-bit
  packed example.
- Performance RED measured the initial packed CDC path at 3.75 MiB/s decode and
  4.25 MiB/s encode. Bounded generic chunks plus specialized four-unit six-bit
  groups raise the production core API to 162.87/40.14 MiB/s MSB pack/unpack and
  165.04/43.37 MiB/s LSB; the complete codec pipelines measure 10.29–10.46
  MiB/s decode and 15.03–15.28 MiB/s encode.
- GREEN observed: all six codec contracts and all 16 research contracts pass;
  generated inventories contain 1,676 registered codecs and eight packed
  profiles. Research totals remain unchanged because this is a deeper exact
  implementation of the existing CDC Display Code cluster.
- Source-bound differential refresh: all 1,112,064 Unicode scalars remain
  byte-exact for 112/112 core and 198/198 combined GNU codecs. Both runs report
  zero mismatches; the combined run has zero 30x performance-gate failures and
  a worst slowdown of 25.88x.

## Cycle 30 — DEC terminal graphic-set bridge

- Source audit rendered and inspected DEC's VT330/VT340 Figures 2-7 and 2-8,
  proving separate GL/GR invocation, every Special/Technical position, and the
  Technical set's undefined cells. Unicode L2/98-354, Unicode 17, WG2 N5028,
  and licensed Kermit tables resolve the modern Unicode mappings.
- RED in `iconvex_specs`: 19 focused tests produced 13 failures before four
  byte profiles and two seven-bit packed transports existed. The oracle covers
  all 94 table positions, all 256 octets for each of four profiles, strict and
  discard paths, malformed UTF-8 offsets, aliases, source hashes, and licenses.
- GREEN implementation adds `DEC-SPECIAL`, `DEC-SPECIAL-GR`, `DEC-TECHNICAL`,
  and `DEC-TECHNICAL-GR`; Unicode-standard U+23B2..U+23B5 replaces historical
  private-use joining pieces. All 19 contracts pass, and generated inventories
  contain 1,680 registered, 1,682 audited, and ten packed profiles.
- Research RED found three separate DEC Special rows and two separate Technical
  rows. Audited canonical bridges plus the pinned manual collapse them to two
  high-confidence implemented clusters. All 17 research contracts pass;
  catalog totals are 1,668 clusters, 1,224 implemented, 242 codec gaps, and 168
  research candidates.
- Production 1 MiB medians are 9.42–17.46 MiB/s direct and 6.52–11.56 MiB/s
  packed. GNU libiconv 1.19 contains neither set, so no GNU ratio exists.

## Cycle 31 — deep-dive closure re-audit

- Re-read all 460 lines of the supplied `iconvex-deep-dive.md` review and bound the
  remediation ledger to source SHA-256
  `573dad285c9911470e9b3600bd587eebca440ece6d817916e411fb389dfa1522`.
- RED observed: the full coverage run remained globally green at 90.02%, but
  the ISO-2022-JP engine had regressed to 88.00%, contradicting the recorded
  per-state-engine 90% gate.
- GREEN tests add valid and malformed JP-2 G2 recovery, replacement-mode
  designations, JP-MS SO/SI transitions, invalid kana, truncated JIS pairs,
  and JP-extension control handling. The focused suite passes 19 tests. Later
  review-driven behavioral matrices supersede the original coverage snapshot;
  the clean full run now passes 325 tests with 95.06% total and 97.25% JP codec
  coverage.

## Cycle 32 — audited numeric EBCDIC and DEC MCS identity bridges

- RED observed: twenty implemented EBCDIC code-page titles and DEC
  Multinational remained separate codec gaps despite exact runtime identities.
  The contract deliberately excludes the materially different `EBCDIC 001` and
  `EBCDIC 8859` encyclopedia rows.
- GREEN adds narrow canonical-title bridges for exactly IBM 037, 1025, 1026,
  1047, 273, 277, 278, 280, 284, 285, 297, 423, 424, 500, 870, 871, 875, 880,
  905, and 924, plus DEC Multinational/DEC-MCS. All 18 research contracts pass.
- Regeneration yields 1,647 clusters, 1,224 implemented, 221 codec gaps, and
  168 research candidates without globally transitive alias merging.

## Cycle 33 — SI 960 and DEC Hebrew source bridge

- Source audit rendered and visually inspected DEC's 1991 *Digital Guide* at
  printed page 19 and the VT510 Hebrew invocation page. The former separately
  defines the ASCII-based seven-bit SI 960 mapping and DEC-MCS-based eight-bit
  DEC Hebrew mapping; the latter and licensed Kermit data independently confirm
  the 60–7A Hebrew range.
- RED in `iconvex_specs`: five contracts produced five failures before both
  codecs and SI 960's packed septets existed. RED in the research catalog then
  showed SI 960 lacked runtime aliases/source evidence; a second RED exposed a
  duplicate standalone Kermit `HEBREW-7` cluster.
- GREEN adds two registered codecs, one packed profile, exact source digests,
  exhaustive 128/256-position oracles, strict/discard/direct paths, and a narrow
  `HEBREW-7`/SI 960 canonical bridge while keeping DEC Hebrew 8-bit separate.
  All 19 research contracts pass. Final catalog totals are 1,646 clusters,
  1,226 implemented, 218 codec gaps, and 168 research candidates.
- Production 1 MiB medians are 54.81–58.57 MiB/s decode, 13.82–14.17 MiB/s
  encode, and 8.37–12.68 MiB/s for SI 960 packed conversion. GNU libiconv 1.19
  contains neither profile, so no GNU ratio exists.

## Cycle 34 — publishable external archive providers

- RELEASE RED: `iconvex_specs` exceeded Hex's 128 MiB uncompressed limit while
  carrying the verification corpus; after excluding source-only evidence, its
  1,050 ICU historical runtime tables still exceeded the 16 MiB compressed
  limit. Dropping codecs was not accepted as a fix.
- GREEN splits only those generated tables across three transparent external
  applications with exact 350-table ranges. Provider-aware table entries keep
  the same codec modules, names, mappings, lazy cache, and direct conversion API.
- All four Hex artifacts build and unpack successfully. A clean production
  compile from the unpacked artifacts passes warnings-as-errors, verifies all
  six range boundaries and 1,682 public codecs, while a permanent test checks
  provider ownership and physical table presence for all 1,050 archive IDs.
- COLD-LOAD RED found mixed-EBCDIC schema/mode atoms missing from core's finite
  safe-ETF allowlist when an unpacked artifact loaded those tables before the
  state engine. GREEN explicitly interns the four generated atoms; a new VM
  then safely fetches all 1,050 shard tables.

## Cycle 35 — executable Kermit identity audit and Short KOI

- RED catalog coverage showed 17 legacy Kermit titles as standalone gaps. A
  permanent source-to-runtime byte audit then caught one false bridge:
  historical `HEBREW-ISO` differs from current ISO-8859-8 at AF, FD, and FE.
- GREEN retains only 16 byte-exact canonical bridges. ELOT 928, Hebrew ISO,
  Latin-6, and Macintosh Latin remain distinct with asserted difference counts
  of 3, 3, 16, and 7 respectively.
- RED/GREEN adds the separately specified stateless `SHORT-KOI` / KOI-7 N2
  external codec and merges the duplicate Wikipedia `KOI7` research title.
  The regenerated catalog has 1,629 clusters, 1,227 implemented codecs, 200
  codec gaps, and 168 research candidates.
- Exhaustive tests execute all 128 septets and reject all 128 high octets at
  two offsets. Production decode improved from 19.53 to 66.38 MiB/s after
  inlining the per-unit emitter; encode is 16.45 MiB/s and packed conversion is
  9.27–13.07 MiB/s. GNU libiconv 1.19 has no corresponding codec.

## Cycle 36 — standard ELOT 927 versus Kermit terminal Greek

- RED source audit rendered all six pages of ISO registration 88 and compared
  every chart position with RFC 1345 `greek7` and Kermit's `u_elot927` table.
  Standard ELOT 927 is exactly `greek7`; Kermit's uppercase-only terminal table
  differs at 54 printable positions and therefore cannot be an alias.
- GREEN keeps `ELOT-927`/`ELOT927` on the standard codec and adds only the
  explicit `KERMIT-ELOT927-GREEK` codec for the historical table. Exhaustive
  tests cover all 128 septets, all high octets, deterministic reverse mappings,
  strict/discard/direct UTF-8 paths, and both packed bit orders.
- A second packed RED showed that standard ELOT 927 itself lacked an exact
  seven-bit transport. Both identities now publish MSB- and LSB-first forms.
- The regenerated catalog has 1,628 clusters, 1,228 implemented codecs, 198
  codec gaps, and 168 research candidates. GNU libiconv 1.19 has neither ELOT
  profile; production measurements are recorded in `iconvex_specs/BENCHMARKS.md`.

## Cycle 37 — all twelve DEC national replacement sets

- RED source audit rendered the pinned VT330/VT340 manual's Table 2-1 and
  transcribed every changed position for United Kingdom, Dutch, Finnish,
  French, French Canadian, German, Italian, Norwegian/Danish, Portuguese,
  Spanish, Swedish, and Swiss. Four initial contracts failed across mapping,
  reverse, alias, malformed, and packed behavior.
- The manual exposed two historical-oracle defects: Kermit's Dutch table is
  wrong at two cells, and its Portuguese table is a six-cell copy of
  Norwegian/Danish. Exact difference-count guards prevent either from becoming
  the implementation oracle.
- GREEN adds dedicated native byte and MSB/LSB packed paths for all twelve
  profiles. Exhaustive tests execute 1,536 septets, all reverse repertoires,
  every simple national alias, and high-octet errors at a nonzero offset.
- PERFORMANCE RED/GREEN replaces six initially reused generic RFC paths that
  measured 7.52–8.18 MiB/s. Their specialized decode is 7.86–8.94x faster;
  final direct ranges are 61.87–73.56 MiB/s decode and 17.78–19.40 MiB/s encode.
- Regeneration closes seven former NRC gaps: 1,627 clusters, 1,234 implemented
  codecs, 191 codec gaps, and 168 research candidates.

## Cycle 38 — versioned Kermit single-byte profiles

- RED added source-independent, exhaustive contracts for `GREEK-ISO` /
  `ELOT928-GREEK`, `HEBREW-ISO`, `LATIN6-ISO`, and `MACINTOSH-LATIN`; all four
  names were initially unresolved. A separate research RED kept all four as
  codec gaps and failed the exact ELOT 928/Greek identity requirement.
- GREEN adds four native codecs with embedded compile-time maps and pinned ICU,
  RFC, GNU libiconv 1.19, and Kermit oracles. Tests execute all 1,024 octets,
  full canonical inverses, undefined cells, policy/error behavior, malformed
  UTF-8, aliases, and direct paths across allocation boundaries.
- Permanent identity guards distinguish archived Greek from both modern GNU
  and RFC 1345, historical Hebrew from modern ISO-8859-8, current-standard
  Latin-6 from Kermit's 16-cell near-match, and Macintosh Latin's U+F8FF cell
  from GNU MacIceland.
- Mixed 1 MiB benchmarks are 51.71–65.15 MiB/s decode and 19.16–24.02 MiB/s
  encode. GNU/Iconvex ratios remain 1.51–5.26x, enforced below a 30x ceiling.
- Regeneration yields 1,626 research clusters, 1,238 implemented codecs, 186
  codec gaps, and 168 research candidates. The Specs runtime now publishes
  1,700 codecs and retains 1,702 audited entries.

## Cycle 39 — lazy Stream conversion and PETSCII byte policy

- RED added lazy `Stream`, split-boundary, callback-offset, malformed-final,
  and unsupported-state contracts. The first focused run had 11 tests and 5
  failures because `stream/3-4` and `stream!/3-4` were not exported.
- GREEN adds bounded incremental source/target state, longest-match suffixes,
  absolute error offsets, and stateful HZ, ISO-2022-JP/JP-2/KR/CN, and UTF-7
  conversion. Every representative source-byte and UTF-8 target split matches
  one-shot bytes; lazy stateful output appears before source EOF.
- A second RED found Stream HZ escaping a literal tilde instead of preserving
  GNU's pinned encoder quirk: 14 focused tests, 1 failure. GREEN now matches
  one-shot GNU bytes across that chunk boundary and retains the existing
  malformed reverse behavior.
- A third RED split generic UTF-16 after its two-byte BOM: 16 focused tests, 1
  failure. GREEN carries generic UTF-16/UTF-32 byte order across every split and
  emits exactly one target BOM.
- External codecs have separate stateless and explicit-state Stream callback
  contracts. Focused external tests pass 11/11.
- PETSCII contract tests lock caller-owned control semantics through
  `on_invalid_byte`; focused N5028 tests pass 8/8, including one-byte chunks,
  translated CR/reverse/color commands, and absolute callback offsets.

## Cycle 40 — crash-safe ownership and atomic registry replacement

- RED reproduced both registry lifecycle failures before implementation. Two
  focused ownership tests failed 2/2: replacing a codec with 2,000 aliases
  produced 4,152 transient missing-module reads, and killing the supervised
  registry worker lost the registration and its cleanup token.
- A strengthened restart RED killed and restarted the ETS heir before killing
  the registry. The external-codec file ran 14 tests with one failure because
  the replacement heir had not been installed and the table was destroyed.
- GREEN moves names to a staged name-to-module index and publishes replacement
  with one module-row commit. Concurrent readers now resolve both the module
  and a retained alias continuously as either the complete old or new entry.
- GREEN gives the protected ETS table to a separately supervised heir. A new
  registry reclaims the exact table and token references, repairs missing and
  stale name-index rows, and restores configured codecs only when absent. A
  caller-authenticated heir handshake also survives heir replacement.
- ADVERSARIAL RED added three deterministic boundaries and failed 3/3: a
  post-commit worker death returned only a killed `GenServer.call` to the owner,
  an arbitrary process installed itself as ETS heir, and an arbitrary process
  reclaimed the inherited table. GREEN uses the caller-generated ownership
  reference as a bounded idempotency key, adopts the exact committed token
  after confirmed worker death, and authenticates both handshakes against the
  registered sibling process. The blocking commit hook exists only in test
  builds; the production branch contains no receive or blocking hook.
- Atomic-claim tests launch 64 concurrent codec and provider registrations and
  prove exactly one ownership token plus 63 `:existing` results. Conditional
  cleanup, preownership, caller replacement, and startup rollback remain
  covered by core and extension-package lifecycle tests. The final external
  registry and provider lifecycle files pass 21/21.

## Cycle 41 — unambiguous ownership RPC and crash-safe shutdown

- RED reproduced a post-commit/live-worker ambiguity: a finite `GenServer.call`
  timeout can report failure even though the queued registration later commits,
  orphaning its cleanup token. A five-second boundary test now holds the worker
  after commit and proves the owner waits for the authoritative reply.
- GREEN makes ownership-changing registration calls infinite, reuses the
  caller-generated reference as both request identity and cleanup token, and
  adopts that exact token from inherited ETS state after a worker dies before
  replying. Retry exhaustion also checks the committed row before returning.
- A teardown RED exercised lookup while the named ETS table was deleted and
  raised `ArgumentError`. GREEN lookup/match wrappers make concurrent
  application shutdown resolve as an ordinary miss.
- A shutdown RED killed the registry with token-conditional unregister queued:
  the caller exited with `{:killed, {GenServer, :call, ...}}` and the owned row
  survived restart. GREEN retries exact-token cleanup across worker death and
  never removes a caller replacement.
- The same five-second RED on unconditional unregister returned
  `{:timeout, {GenServer, :call, ...}}` while its delete remained queued. GREEN
  waits for the authoritative reply, preventing that delayed delete from
  surprising a caller that already observed a timeout.
- A stronger RED suspended the registry supervisor beyond the retry budget;
  cleanup returned `{:error, {:registry_restart_timeout, nil}}` while the exact
  owned row remained live. GREEN removes that budget: while the heir owns ETS,
  it performs an exact-token conditional delete; during an ownership transition
  cleanup waits and retries until the row is gone or replaced.
- Focused registry/cache lifecycle evidence is 25 tests, zero failures,
  including unauthorized heir installation/reclamation, wrong-token deletion,
  lost replies, five-second live calls, worker/heir crashes, and suspended
  supervisors.

## Cycle 42 — codec-aware malformed-unit recovery

- RED first showed that generic one-byte recovery lost the second byte of an
  invalid 16-bit punched-card word. A codec-declared consumption callback now
  keeps one-shot and Stream discard/substitution aligned to the complete unit.
- A stronger RED showed that the same prefix/skip/restart algorithm is invalid
  for whole-string transforms: Punycode `a-z!more` crashed after independently
  decoding incomplete prefix `a-z`, while `abc-!garbage` reinterpreted a
  desynchronized tail.
- GREEN adds validated `decode_error_recovery/0` metadata. The default remains
  `:resynchronize`; `:stop` obtains the codec-native `decode_discard/1` prefix,
  invokes exactly one error event or byte replacement, and never decodes the
  tail. The core external-codec regression passes 22/22, including invalid
  metadata rejection and exact event offset/byte/sequence.

## Cycle 43 — versioned IBM/DEC catalog identities

- RED required seven source-bound runtime identities in the generated research
  catalog while keeping generic CP310, CP907, CP1116, and CP1117 records as
  gaps. The focused test failed because none of the versioned identities had a
  supplemental source record.
- GREEN adds the exact runtime names and aliases with pinned IBM registry,
  IBM/tnz revision, archived IBM PDF, and DEC 1994 manual URLs. CP1287/1288
  merge into the exact DEC Greek/Turkish rows; the four under-specified generic
  records remain separate. The regenerated-catalog test passes 33/33.

## Cycle 44 — truthful release metadata and memory boundary

- RED showed two release-documentation mismatches: ExDoc was given the Hex
  package page as though it were a source-code browser, and the remediation
  ledger claimed an application input-limit requirement that README did not
  state. The focused contract failed 2/2.
- GREEN omits `source_url` until a real public repository is declared, keeps
  the Hex page as homepage/source archive, and explicitly requires applications
  using materializing APIs to enforce a memory-budget-derived input limit.
  The focused release contract passes 2/2.

## Cycle 45 — review-driven behavioral coverage closure

- RED reproduced the review's clean baseline: 297 tests passed, but total line
  coverage was only 83.28%; Stateful measured 81.43%, UTF-7 79.06%,
  ISO-2022-CN 86.00%, and ISO-2022-JP 89.01%.
- GREEN adds public-API behavioral matrices for incremental UTF-7, HZ and all
  ISO-2022 state transitions, Unicode BOM/surrogate recovery, Stream callback
  failures, registry restart/configuration paths, packed six-bit tails, table
  lookahead, and substitution dispatch. These exercise real outcomes rather
  than excluding modules or lowering thresholds.
- The authoritative clean run passes 325 tests with 95.06% total coverage.
  UTF-7 is 96.34%, Stream 96.99%, ISO-2022-JP 97.25%, Stateful 97.50%, and
  ISO-2022-CN 99.33%.

## Cycle 46 — atomic multi-owner package coexistence

- INTEGRATION RED started Extras, Telecom, and Specs in all six orders. The
  first two cases failed on `IBM037` and `CP1124` name conflicts: Specs and
  Extras intentionally share 231 normalized names, comprising 25
  Specs-canonical/Extras-alias, 63 Specs-alias/Extras-canonical, and 143
  alias/alias claims.
- GREEN adds one managed registration set per distributed extension. Winners
  rank canonical claims before aliases and then use a fixed package priority;
  built-ins and public third-party registrations remain strict. All six start
  orders now expose exactly 1,990 case-fold-unique canonical names with the
  same complete name-to-module snapshot. With every package loaded, Specs wins
  25 overlaps and Extras wins 206.
- ATOMIC-REMOVAL RED observed 98,286 transient unresolved fallback reads while
  removing the winning set. GREEN publishes one tombstone commit that switches
  every affected name to its retained claim before cleanup; deterministic and
  concurrent readers observe no gap. Stopping Extras exposes all 231 Specs
  claims, restarting restores the 25/206 split, and stopping Specs exposes all
  231 Extras claims.
- RESTART/RETRY REDs reproduced a transient missing `GSM0338` during registry
  repair, a queued replacement rejected as `:registration_replaced_during_retry`,
  and a reader paused on a removed winner returning `:error`. GREEN republishes
  complete indexes before pruning stale rows, distinguishes a retry by its
  expected registration token, and performs a bounded winner re-read. Managed
  set tokens and claims survive both registry and heir recovery.
- The focused managed-registry and queued-replacement evidence passes 13/13.
  The non-publishable `iconvex_integration` harness passes 2/2 and permanently
  enforces all six start orders, exact overlap categories and winners, and both
  stop/restart fallback directions.

## Cycle 47 — ECMA-44 raw-transport catalog closure

- RED required the catalogued ECMA-44 punched-card representation to name both
  source-qualified raw profiles and report Iconvex support without pretending
  that either profile is a Unicode codec. The focused test failed on the first
  absent `ECMA-44-7BIT-CARD-RAW` label.
- GREEN feeds the generated raw-transport inventory back into catalog support
  classification and binds the two raw profile names to the exact ECMA-44
  record. The catalog remains 1,615 clusters, moves to 1,281 supported and
  implemented rows, and reduces actionable codec gaps from 104 to 103. The
  focused catalog contract passes 1/1.

## Cycle 48 — TI-89/TI-92 Plus AMS 2.0 catalog closure

- RED required the exact AMS 2.0 source, visible-control, mixed-lossless VPUA,
  and raw VPUA profiles to close the TI-89/TI-92 Plus catalog row. The focused
  test failed because the generated row still had no runtime labels and the
  high-confidence blocker ledger still described the mapping as unextracted.
- GREEN regenerates the catalog from the shipped Specs inventory and removes
  only that resolved blocker. The catalog remains 1,615 clusters, moves to
  1,282 supported and implemented rows, reduces actionable codec gaps from 103
  to 102, and leaves 24 independently audited high-confidence blockers. The
  complete catalog contract passes 36/36.

## Cycle 49 — external direct-encoder compatibility

- RED registered a deliberately stateful legacy external codec whose
  `encode_from_utf8/1` returned
  `{:encode_error, :unrepresentable_character, codepoint}`. The public result
  was correct only after the required `encode/1` fallback ran; the sentinel
  assertion failed with one fallback call instead of zero.
- GREEN treats both the documented `{:error, ...}` result and the legacy
  destination-tagged result as conclusive fast-path errors. The callback type
  and extension guide document this backward-compatible boundary, and the
  counting regression proves one direct call and zero fallback calls.
- The exact regression passes 1/1 and the complete external-codec matrix passes
  24/24. Fresh exhaustive differentials remain byte-identical to GNU libiconv
  1.19 for 112/112 core codecs and 198/198 combined codecs over all 1,112,064
  Unicode scalars, with zero mismatches; the source-bound reports were refreshed.
  The complete core suite passes 342/342.

## Cycle 50 — TI-83 Plus catalog closure

- RED required the source-qualified large- and small-font TI-83 Plus readable,
  mixed-lossless VPUA, and raw VPUA profiles to close the primary vendor-manual
  catalog row. The focused contract failed on `TI-83 Plus character set`
  because the generated catalog still classified it as an unaudited gap.
- GREEN binds all six explicit profile names to the pinned 2002 TI developer
  guide, regenerates the catalog from the final 1,755-row Specs inventory, and
  removes only the resolved TI-83 blocker from the evidence ledger. The catalog
  remains 1,615 clusters, moves to 1,283 supported and implemented rows,
  reduces actionable codec gaps from 102 to 101, and leaves 23 independently
  audited high-confidence blockers.
- The complete generated-catalog contract passes 36/36 with warnings treated
  as errors.

## Cycle 51 — release-cardinality document contract

- RED added executable release-document contracts before changing prose. The
  focused Core, Extras, and Telecom runs each failed exactly one test against
  the stale 1,995 full-stack and 1,745 Specs counts.
- GREEN states the derived 2,005 full-stack and 1,755 Specs cardinalities in
  each current release document, keeps all three checked-in Core documentation
  mirrors byte-identical to their sources, and passes Core 3/3, Extras 13/13,
  and Telecom 7/7 focused tests. The complete affected suites pass Core 343/343,
  Extras 107/107, and Telecom 116/116 with warnings as errors.

## Cycle 52 — TDD documentation-mirror closure

- RED extended the executable documentation-mirror contract to the checked-in
  TDD log and failed 1/3 because `doc/tdd_log.md` stopped at cycle 49 while the
  authoritative source included the TI-83 catalog and release-cardinality
  cycles.
- GREEN refreshes the mirror byte-for-byte from `TDD_LOG.md`; the complete
  release-metadata contract passes 3/3 with warnings treated as errors.
  The complete core suite passes 343/343.

## Cycle 53 — property-token catalog architecture

- RED first failed 1/37 while the three explicit Unicode 17 telegraph
  property-token profiles were absent from the generated catalog. GREEN added
  the separate `implemented_property_token_mapping` disposition without
  claiming byte-codec support.
- An adversarial second RED failed when a synthetic, inventory-absent future
  `unicode_property_token_mapping` row became a `codec_gap`. GREEN now derives
  implemented mapping keys from the exact shipped Specs property-token
  inventory and classifies an absent mapping as the distinct
  `property_token_mapping_gap`, even when a research row says `iconvex=yes`.
- Regenerated artifacts form a non-overlapping 1,618-row partition: 1,283
  implemented codec clusters, three implemented property-token mappings, 101
  codec gaps, zero property-token mapping gaps, 140 research candidates, and
  91 other audited clusters. Both generated CSVs reproduce byte-for-byte and
  Markdown/JSON reproduce modulo generation timestamps. The catalog suite
  passes 38/38 and the complete core suite passes 345/345 with warnings as
  errors.

## Cycle 54 — property-token classifier precedence

- A final adversarial audit found that exact audited non-codec names were
  classified before semantic kinds. The existing future-property probe was
  extended with an `Adobe-Japan1` name collision and failed 1/1: the synthetic
  property mapping became a `repertoire_profile` instead of a
  `property_token_mapping_gap`.
- GREEN gives `unicode_property_token_mapping` semantic precedence over the
  name-only non-codec table. Inventory-backed names remain implemented; every
  inventory-absent property mapping remains a property-mapping gap regardless
  of `iconvex` status or a normalized-name collision. The focused regression
  passes 1/1, the catalog suite passes 38/38, and the complete core suite passes
  345/345 with warnings as errors.

## Cycle 55 — current versus planned package-split release contract

- RED extended the release metadata contract to distinguish the current Specs
  implementation from the proposed seven-package split. The complete Core run
  failed 1/346 because README did not state the current 1,755 byte-codec and
  three property-mapping surfaces or warn that the replacement packages do not
  exist yet.
- GREEN documents all seven proposed package names without presenting them as
  released, keeps `iconvex_specs` as the current local implementation, states
  its planned unpublished role, and identifies PETSCII's current and future
  owner. The README mirror is byte-identical; the release metadata contract
  passes 4/4 with warnings as errors.
- FOLLOW-UP RED failed 1/4 because the draft omitted the exact 1,050/705
  archive partition, placed PETSCII availability after examples, and did not
  report the currently failing integration harness. GREEN moves the provider
  warning before both examples, records the reproduced dependency/lifecycle
  failures, separates contract from verified release evidence, and classifies
  the newly added Retro/Standards families. The focused contract passes 4/4.

## Cycle 56 — plain-checkout integration closure

- RED ran the integration README's command with both checkout override
  variables unset and isolated build/dependency paths. Dependency convergence
  failed before tests: the three unpublished archive shards were requested from
  Hex, while Core's sibling path conflicted with a transitive Hex declaration.
  The earlier lifecycle run also exceeded ExUnit's implicit 60-second bound.
- GREEN declares all seven sibling packages as compile-only path dependencies,
  gives Core and the three archive shards explicit override ownership, and
  applies a 300-second module timeout to the lifecycle contract. A new
  dependency contract pins those paths and options so checkout mode cannot
  silently regress to remote resolution.
- The exact environment-neutral, fresh-build command now compiles all seven
  packages and passes 3/3 in 43.6 seconds with warnings treated as errors. Core
  README states the verified checkout contract and its documentation mirror is
  byte-identical.

## Cycle 57 — research-catalog identity merge closure

- RED used the pinned GNU libiconv 1.19 definitions and exact runtime inventory
  to prove that IBM-932 maps to CP932 and IBM-949 maps to CP949, while the
  generated research rows still counted those identities as gaps. A companion
  source-label contract exposed Wikidata Q17190477 as an opaque title. The
  focused fresh run failed 2/2.
- GREEN joins only the four audited source IDs to their exact GNU anchors,
  avoiding unsafe transitive CP932/CP949 alias merging, and applies the
  authoritative `U-PRESS` entity label while retaining that undocumented
  mapping as a codec gap. The targeted run passes 2/2 and the complete research
  suite passes 41/41 with warnings as errors.
- Two cached rebuilds are deterministic. The 1,614-row partition now contains
  1,284 implemented codecs, three implemented property-token mappings, 98
  codec gaps, 138 research candidates, and 91 other audited records. The two
  generated CSVs are pinned at SHA-256 `0d10e4f709bf2861e50375f00f01dacf757e14c4f9a8425112f1216f22bf90fe`
  and `67ef3d1fa61e8931f179cdab52578525e02cddaed0283c5e32810236c37bf82c`.

## Cycle 58 — Markdown-whitespace release contract

- RED from the independent deep-dive closure audit ran 49 focused Core tests
  and found one failure: the release metadata assertion required a literal
  space where normal Markdown line wrapping placed a newline between
  `documented` and `command`.
- GREEN makes only that prose contract whitespace-tolerant while retaining the
  complete required sentence. A fresh release-metadata run passes 4/4 with
  warnings as errors; the source README and checked-in Markdown mirror remain
  byte-identical.

## Cycle 59 — current deep-dive coverage disposition

- A fresh independent closure audit passed the complete Core suite 349/349,
  then passed the isolated coverage suite 349/349 at 93.67%, above the 90%
  gate. Reviewed engines measure UTF-7 96.34%, Stream 96.99%, ISO-2022-JP
  97.25%, Stateful 97.50%, and ISO-2022-CN 99.33%.
- RED found that `DEEP_DIVE_REMEDIATION.md` still presented an older 325-test,
  95.06% run as current. A release-metadata assertion failed first against that
  stale evidence.
- GREEN records the exact current total and five engine figures, adds the
  remediation document to the byte-identical mirror contract, and retains the
  assertions inside the existing four-test release suite so documenting the
  count does not itself change it. The focused run passes 4/4 with warnings as
  errors.

## Cycle 60 — public lazy-Stream review matrix

- The final deep-dive audit marked a test-adequacy RED: implementation probes
  were correct, but committed regressions for split malformed-input policies,
  malformed stateful recovery, and registry mutation exercised only the
  buffered compatibility API rather than public lazy `stream!/4`.
- GREEN extends the existing deep-dive tests through the public lazy API.
  Byte-split UTF-8 remains pending under discard and byte substitution;
  byte-by-byte malformed ISO-2022-JP retains JIS designation for both policies;
  and a stream created with an external codec remains bound to that resolved
  codec after unregister/re-register mutation. The fixtures now expose the
  required incremental callbacks.
- No production change was needed. The deep-dive file passes 9/9, the complete
  review-focused set passes 49/49, and the full warnings-as-errors Core suite
  remains 349/349. The assertions were integrated into existing tests, so the
  source-bound coverage count and 93.67% result remain current.

## Cycle 61 — ISO-IR-180 ownership correction

- RED changed the public identity contract to require Core to leave
  `ISO-IR-180` unclaimed; the focused run failed because the alias incorrectly
  resolved to RFC 1456 `VISCII`. ISO-IR-180 actually registers TCVN 5712
  profile VN2 (`VSCII-2`), whose bytes are not VISCII.
- GREEN removes only the false alias from Core. The generated snapshot moves
  from 442 to 441 normalized Core names, preserves all 416 GNU spellings, and
  explicitly proves `ISO-IR-180` is absent so the exact Specs provider can own
  it without a collision. A standalone parity RED also exposed an order-
  dependent `function_exported?/3` assertion; the test now loads the Registry
  module before introspection and then failed on the expected 442/441 snapshot
  transition.
- The regenerated inventory, identity contract, and standalone parity suite
  pass together at 12/12. The source-qualified Specs integration separately
  proves `ISO-IR-180` resolves to `VSCII-2` while `VISCII` and VN1 `TCVN`
  retain their distinct Core identities.
- The first complete Core run then produced two evidence REDs: the mirrored
  TDD ledger was stale and the runtime-bound exhaustive report still named the
  pre-correction digest. The mirror was refreshed mechanically and the GNU
  libiconv 1.19 runner was executed again over all 1,112,064 Unicode scalars
  and all 112 Core codecs. It passes 112/112 with zero mismatches; the two
  focused evidence contracts pass 5/5 against the newly generated report.

## Cycle 62 — combined exhaustive artifact rebinding

- RED reran the permanent Extras artifact contract after the Core registry
  correction. One of two tests failed because the checked-in 198-codec report
  still named the pre-correction combined runtime digest.
- GREEN regenerated the report with GNU libiconv 1.19 over all 1,112,064
  Unicode scalars and all 198 Core-plus-Extras codecs. Every forward,
  round-trip, and cross-decode comparison is byte-exact, with zero mismatches
  and zero performance failures under the 30.00x ceiling.
- A second RED then proved the public benchmark narrative was bound to the old
  run. Updating only its derived measurements closes the chain: 71,782 ms
  total and a 25.15x maximum for UCS-4. The cross-package artifact contract now
  passes 2/2, the focused Core review matrix passes 24/24, and the complete
  warnings-as-errors Core suite passes 356/356.

## Cycle 63 — source-qualified LICS and Army tap pair catalog closure

- RED first changed the research contract to require 1,298 implemented
  clusters, 84 actionable codec gaps, and 89 supplemental source records, then
  required exact rows for the complete June 1991 HP 95LX Appendix F LICS
  profile and the January 2015 U.S. Army GTA 31-70-001 pair-value profile. The
  focused run failed 2/2 against the prior 1,296/86/87 partition and the
  still-unqualified LICS row.
- GREEN adds exactly two conservative supplements and derives implementation
  only from the generated 1,783-row Specs runtime inventory. `LICS` retains
  only `LOTUS-INTERNATIONAL-CHARACTER-SET`; its May 1988 Xerox cross-check is
  explicitly earlier and incomplete. The Army profile retains only its three
  narrow pair-value aliases; generic Tap Code, physical wire bytes, spaces,
  numbers, and alternate matrices remain outside the runtime identity.
- Consecutive cached regenerations preserve byte-identical catalog CSVs and
  content-identical generated reports after excluding their timestamp fields.
  The merged catalog remains 1,614 rows: 1,298 implemented codecs, three
  implemented property-token mappings, 84 codec gaps, 138 research candidates,
  and 91 other audited records. The complete warnings-as-errors research suite
  passes 49/49 with seed 0.
- The final catalog and GNU-unsupported CSV SHA-256 values are
  `45ef419e0640c203640a8aa450dae2af078b6e62aed4fd3fa05c873a16afc7e0`
  and `f5891c10f2cec80a482938ef603001053cd1ab86848bc1817d24e13ba9968901`;
  normalized Markdown and manifest content hash to
  `06492b545d72ead0825977064913b27f78284e9a0d71ff1570b28bdc201cf628`
  and `5d63becc05acc081c50525a7ee811d499302e4d3a918ade893a100017cb9f57c`.

## Cycle 64 — current coverage and clean seven-artifact closure

- RED first raised the release-metadata contract to the freshly measured Core
  coverage result. One of four focused tests failed against the prior 349-test,
  93.67% snapshot. GREEN records the isolated warnings-as-errors coverage run:
  357 tests, zero failures, and 93.70% total line coverage.
- A second release RED ran the strengthened clean-consumer probe against the
  previously frozen archives. It failed at the derived 2,033-codec assertion;
  the stale Specs archive exposed only 1,745 inventory rows and omitted LICS
  and the Army Tap Code pair-value codec, while Core/Extras evidence files were
  no longer byte-identical to their sources.
- GREEN rebuilds all seven Hex archives with checkout dependency overrides
  unset, unpacks them into a new consumer, and compiles the complete production
  dependency graph with warnings as errors. The reusable audit passes 2,033 of
  2,033 full-stack codecs, 1,783 of 1,783 Specs empty encode/decode checks, all
  16 public provenance helpers, all six archive-shard boundaries, and the
  digest-pinned MacOS Esperanto, VSCII-2, Lotus LICS, and U.S. Army Tap Code
  assets plus semantic conversions. Packaged release documents and generated
  inventories are byte-identical to the final workspace sources.
- Final ordinary warnings-as-errors suites pass Core 357/357, Extras 107/107,
  Telecom 116/116, Specs 790/790, and the six-order integration harness 4/4.

## Cycle 65 — UTF-6 catalog and aggregate release recurrence RED/GREEN

- RED first required the generated research catalog to classify UTF-6 as the
  exact `draft-ietf-idn-utf6-00` implementation rather than a Wikipedia
  candidate. The release contracts then raised the live family totals from
  2,033 to 2,055 full-stack codecs and from 1,783 to 1,805 Specs codecs; the
  focused Core run failed 2/4 against the stale prose and mirrored documents.
- GREEN adds the exact draft supplement, regenerates the catalog, and removes
  UTF-6 from the unresolved closure ledger. The non-overlapping catalog has
  1,622 rows: 1,310 implemented codecs, three implemented property-token
  mappings, 82 codec gaps, 136 research candidates, 101 source supplements,
  and 91 other audited records. All 218 remaining gap/candidate rows have one
  evidence-backed closure-audit row. The research suite passes 54/54.
- Release prose, tests, and generated support evidence now agree on 2,055
  unique full-stack canonical names, 1,805 runtime Specs codecs, 1,807
  catalogued Specs definitions, and the 1,050 archive/755 non-archive split.
  Core passes 362/362 with warnings as errors. A fresh isolated coverage run
  also passes 362/362 and retains 93.70% total line coverage; the executable
  coverage statement and its generated Markdown mirror were raised through a
  separate failing 1/4 release-metadata boundary before returning GREEN 4/4.
## Cycle 66 — direct-fast-path streaming error precedence

- RED began with a PASCII stream split where an unresolved destination prefix
  preceded malformed UTF-8. The stream reported the later source error instead
  of the strict direct encoder's earlier unrepresentable character.
- The first GREEN finalized retained target prefixes before raising. Independent
  review then found a same-chunk recurrence, a malformed optional callback
  returning either an atom or a negative error-shaped codepoint, and a stateful
  callback whose current encoder state cannot be reconstructed by restarting a
  direct probe. Each reproducer was committed as a failing public regression
  before the next production change.
- Final GREEN probes the actual strict direct callback only for table codecs and
  stateless external codecs, accepts only validated non-negative target errors,
  and otherwise preserves source-first fallback. Stateful external direct
  encoders prevalidate UTF-8 before their one-shot fast path; valid input still
  uses that fast path, while malformed input and lazy streaming now agree
  without retaining unbounded source history. The focused core stream suite
  passes 16/16 and the PASCII suite passes 13/13. The complete Core suite
  passes 367/367 with warnings as errors. Fresh GNU libiconv 1.19 evidence
  covers 112/112 Core codecs and 198/198 Core-plus-Extras codecs across all
  1,112,064 Unicode scalars with zero mismatches; the combined run's worst
  slowdown is UTF-32 at 24.63x, below the enforced 30x ceiling.

## Cycle 67 — post-catalog coverage evidence refresh

- RED began from the release contract and both deep-dive documents still
  claiming the earlier 362-test, 93.70% snapshot and Stream at 96.99%. An
  authoritative full `mix test --cover --warnings-as-errors --seed 0` run
  first established the new evidence: 368 tests, zero failures, 93.78% total
  line coverage, and Stream at 97.97%.
- The executable release expectation was raised before the prose. Its focused
  run failed exactly one of four tests on the stale 362-test statement, proving
  the evidence boundary RED rather than editing test and documentation in one
  step.
- GREEN updates the source and generated deep-dive documents together. The
  focused release-metadata suite passes 4/4, the complete ordinary
  warnings-as-errors suite passes 368/368, and both TDD/documentation mirrors
  are byte-identical. The stray standalone marker before Cycle 66 was also
  removed from both logs.

## Cycle 68 — source-qualified IBM Six-Bit Transcode catalog split

- RED first required the historical `Transcode` row to describe IBM's six-bit,
  low-order-first family rather than a seven-bit code and required both exact
  primary-manual profiles as implemented children. The focused catalog suite
  failed until the 1970 BSC U+003C and 1971 IBM 2780 U+2311 variants were
  represented separately and generic `TRANSCODE` remained unclaimed.
- A second RED rejected a combined escaped source token: the generic family
  needed two independently addressable primary-manual URLs plus the historical
  inventory record. GREEN supplies two distinct supplements, makes the merged
  family record count three, and links both source-qualified runtime names from
  the closure ledger without choosing either profile as the generic identity.
- The generated catalog now has 1,627 non-overlapping entries: 1,315
  implemented codecs, four implemented property-token mappings, 81 codec gaps,
  136 research candidates, and 109 supplemental source records. The closure
  audit remains current at 217 rows; the focused research suite passes 56/56
  and the complete Core suite passes 368/368 with warnings as errors.
- Final SHA-256 values are
  `c14f6a60891c3bd2cce84d9b667dece1fb5aa5359f3bb6a21f823b071c4d6c0e`
  for `known_encodings.csv` and
  `8f24dbe7dd8f6182ac615011b6695e434dd48142bec10a9aeef5603bc57bd750`
  for the GNU-unsupported CSV.

## Cycle 69 — review-rigor-v2 correctness and performance closure

- Registry RED reproduced a consecutive supervised worker crash after the ETS
  heir had already transferred ownership once; the application stopped and
  exact cleanup tokens were lost. GREEN checkpoints a versioned recovery
  snapshot after every serialized mutation and heir removal, repairs a missing
  table from that snapshot, and erases it on a clean application stop. The
  focused ownership/recovery matrix passes 39/39.
- Streaming RED added five multibyte-policy cases that exposed partial-unit
  consumption and chunk-local substitution coordinates. GREEN derives the
  invalid native-unit width from the codec, invokes byte substitution for each
  consumed physical byte, emits one callback event at the absolute unit
  offset, and buffers a short non-final suffix. All five focused regressions
  pass. A separate ISO-2022 RED exposed designated `ESC N`/`ESC O` prefixes
  split across chunks; the expanded split matrix passes 31/31 after GREEN.
- UTF-7 correctness RED ran eight provisional shifted-sequence cases and failed
  five because decoded UTF-16 output escaped before padding and surrogate
  validation. GREEN holds a complete shifted run until validation and passes
  40 focused cases. Complexity RED then failed two of 12 deterministic tests:
  pending input grew with every byte and doubled work by 3.50–3.92x. GREEN uses
  a bounded UTF-7 replay contract; 50 focused tests and 2,956,516 adversarial
  GNU comparisons pass, doubling costs 1.96–2.00x reductions, and the
  10,669-byte byte-at-a-time case improves from 939,933 to 8,685 microseconds.
- Performance RED demonstrated a repeated table scan for every CP1258/TCVN
  source code point. GREEN caches the immutable base-byte sets and avoids
  flattening already-flat lists; the focused 48-test matrix passes, with the
  isolated old-scan comparison improving by about 800x for CP1258 and 338x for
  TCVN. Packed-bit-order and typed invalid-unregister regressions also pass.
- Final GREEN rebuilds GNU libiconv 1.19 with
  `--enable-extra-encodings` and compares all 1,112,064 Unicode scalars through
  every one of the 112 Core GNU codecs in both directions with zero mismatches.
  The clean warnings-as-errors coverage run passes 403/403 at 94.51% total;
  UTF-7 is 97.58%, Stream 98.03%, ISO-2022-JP 97.27%, Stateful 98.57%, and
  ISO-2022-CN 99.35%.

## Cycle 70 — final general-review closure

- DOCUMENT-COUNT RED added one full-stack integration contract whose source of
  truth is the executable Specs/Extras claim intersection and Telecom packed
  inventory. It failed on the first stale current document: Core still said
  231 overlaps after RFC 1345 qualification had reduced the live intersection
  to 227. GREEN corrects five current Core/Extras release documents, preserves
  the historical 231-state TDD entries, and corrects Core's 49-profile claim
  to the runtime-derived 51. The focused integration file passes 3/3 and the
  complete integration suite passes 16/16.
- CLEAN-CHECKOUT RED failed 1/1 after proving that an ordinary test run required
  ignored `doc/*.md` output. GREEN makes mirror comparison explicit through
  `ICONVEX_VERIFY_DOC_MIRRORS=1` and adds a CI documentation job that generates
  ExDoc before enforcing byte equality. A fresh copied tree with no `doc/`,
  `_build/`, or dependencies passes 5/5 normally; after `mix docs`, the explicit
  mirror run also passes 5/5.
- GB18030 RED added three malformed-candidate tests and failed two because
  strict/callback sequences were truncated and depended on chunk boundaries.
  GREEN retains exact 1-, 2-, 3-, and 4-byte diagnostic frames while preserving
  GNU libiconv 1.19's one-byte invalid recovery. Five malformed GNU oracle
  vectors match for discard and byte substitution at every split; 111 related
  tests and all 407 non-artifact Core tests pass.
- The proposed ETS-heir rearm LOW was refuted before any production change.
  Twenty-five repetitions covering 50 registry-only crashes proved that OTP
  preserves the configured heir after table reclamation. A permanent
  supervisor-suspended two-crash regression proves the second transfer retains
  codec resolution; the 41-test lifecycle matrix remains green.
- FINAL GREEN passes 408/408 with warnings as errors and 94.52% total line
  coverage. The Core differential passes 112/112 GNU codecs and the combined
  Core/Extras differential passes 198/198 across all 1,112,064 Unicode scalars
  with zero mismatches. The combined source-bound run takes 43,704 ms and its
  worst measured slowdown is UCS-4 at 26.32x, below the 30.00x ceiling.

## Cycle 71 — GNU escape, fallback, and ISO-2022-JP-2 boundary closure

- JAVA/C99/UTF-7 RED first exposed malformed-prefix recurrence, GNU's
  alphanumeric digit grammar, C99 unsigned-32-bit values, UTF-7 empty-shift
  framing, and target-policy precedence. The focused escape/Unicode matrix
  reached 47/47 after GREEN. A separate 22-test fallback RED failed five cases
  for supplementary UCS-2 replacement, explicit-UCS surrogate fallback, and
  Unicode-tag dropping; the same command then passed 22/22.
- ISO-2022-JP-2 language-tag RED was recorded before production edits: 6 tests
  failed 5 because Korean/Chinese preferences stayed Japanese, cancellation
  cleared G2, parser state did not survive recovery, and streaming diverged.
  GREEN implements the authoritative GNU state machine and sparse preference
  overrides. The focused suite passes 7/7 and the wider JP/stateful suite
  passes 74/74, including pinned JIS/GB/KSC bytes and every public byte split.
- A 10,304-case independent UCS-4 boundary sweep then found only two remaining
  roots. RED showed JAVA/UTF-7 incorrectly replacing isolated surrogate units
  and generic UTF-16/32 emitting a BOM after discarding every character; a
  second focused RED caught the UTF-32BE fast path. GREEN passes 87/87 wider
  UTF/Unicode/JAVA/stream tests and all 10,304 oracle cases with zero mismatch.
  A distinct 1,176-case endian, tag, noncharacter, target-family, and policy
  audit also reports zero mismatch and zero stream/one-shot divergence.
- The supplied 460-line deep-dive review was re-read in full and its SHA-256
  remains `573dad285c9911470e9b3600bd587eebca440ece6d817916e411fb389dfa1522`.
  The clean Core suite now passes 439/439 with warnings as errors; coverage is
  94.33% total. Fresh exhaustive evidence passes 112/112 Core and 198/198
  Core-plus-Extras GNU codecs across all 1,112,064 Unicode scalars with zero
  forward, round-trip, or cross-decoder mismatch. The combined run has zero
  performance failures; UTF-32 is worst at 26.00x under the 30.00x ceiling.

## Cycle 72 — UTF-16 binary-marker fast-path recurrence

- RED inserted a BOM between a big-endian high and low surrogate. The new
  binary filter removed that marker before validation and incorrectly joined
  the non-adjacent halves into U+10000: the focused fast-path suite failed 1/7
  in strict mode, and discard returned the same scalar. GNU libiconv 1.19 and
  the pre-optimization native path both reject the high surrogate at offset
  zero; GNU `//IGNORE` and native discard emit nothing.
- GREEN conservatively abandons the filter when an aligned big-endian BOM is
  immediately preceded by a high surrogate, leaving the native state machine
  to preserve syntax and recovery. The focused suite passes 7/7 and the wider
  Unicode/GNU regression selection passes 35/35 with warnings as errors.
- An independent adversarial sweep compared the optimized and forced-native
  paths over 54,241 sequences of zero through four units under four policy
  profiles. It includes aligned and cross-unit marker bytes, empty and terminal
  markers, endian swaps, every surrogate boundary, repeated markers, and an
  explicit multi-segment iodata-order oracle; all comparisons pass.
- Final exhaustive GREEN covers all 1,112,064 Unicode scalars through 198/198
  GNU codecs with zero mismatch and zero directional performance failures.
  Generic UTF-16 reverse is 4.26x GNU; the report's overall worst direction is
  UTF-32 at 26.21x, below the 30.00x ceiling.

## Cycle 73 — every-code-point UCS-4BE differential closure

- CORPUS RED changed the permanent artifact contracts before creating data.
  Core failed 1/1 and Extras failed 1/2 because the required sequential
  `all-unicode-codepoints.ucs4be` corpus did not exist. GREEN generates and
  checks all 1,114,112 code points U+0000..U+10FFFF in order, including the
  1,112,064 scalar values and all 2,048 surrogate code points, which are not
  scalar values. Both checked-in copies are 4,456,448 bytes with SHA-256
  `087f212baaa35562a226c5834e723620bb7d9f4103b76f9c7cbdaaff2d6cd67c`.
- UTF-7 PARITY RED failed 1/3 focused GNU vectors at `+2AA-`. GNU retains its
  pre-error base64 bit state while consuming the shift prefix plus one byte;
  the former whole-shift discard lost that state. GREEN ports that recovery
  machine and writes UCS-4 directly. The focused matrix passes 3/3, and the
  complete reverse corpus is byte-identical to GNU (8,650,748 bytes,
  SHA-256 `f2160cebd419b582f5bf4185d94cf85c7b02cdc18b03f6799fac0c5a9316f63d`).
- PERFORMANCE RED first recorded 11 repeatable directional breaches after
  excluding one-shot GC noise: JAVA forward; both directions for UCS-4,
  UCS-4-SWAPPED, and UCS-4LE; UCS-4-INTERNAL reverse; UTF-16 reverse; and
  UTF-16BE/LE forward. The list-materialization contracts failed with decoder
  call counts 6 and 2 instead of zero. GREEN adds endian-aware binary paths;
  9/9 focused tests pass. A callback recurrence then failed 1/10 because
  generic UCS-4 discard bypassed `on_invalid_byte`; callback-safe fallback
  restores 10/10.
- UTF-32 MARGIN RED refused the passing-but-fragile 29.57x reverse result. The
  focused contracts failed with three explicit-target decoder calls and one
  generic reverse call. GREEN handles generic BOMs, endian switches, invalid
  surrogates, values above U+10FFFF, trailing bytes, and callbacks without a
  code-point list. UTF-32 improved from 27.88x/29.57x to 2.53x/1.80x in the
  final full run; the focused suite remains 10/10.
- HARNESS RED failed 1/3 because a single timing sample admitted periodic GC
  spikes. GREEN reports the fastest of three isolated samples per direction
  while including all samples in wall time. Final source-bound evidence passes
  112/112 Core and 198/198 combined GNU libiconv 1.19 codecs over every code
  point with zero forward, reverse, or cross-decode mismatch and zero
  performance failures. The combined run records 276,041 ms total; its worst
  direction is EUC-JISX0213 at 29.45x under the unchanged 30.00x ceiling.

## Cycle 74 — TACE16 catalog-concept merge

- RED required the direct `TACE16` Wikipedia concept to be merged into the
  implemented `Tamil All Character Encoding` record. The focused test failed
  1/1 because `TACE16` still existed as an unresolved standalone candidate;
  after catalog regeneration it remained RED until the obsolete closure row
  was removed.
- GREEN adds the audited canonical merge, retains `TACE16` only as a catalog
  concept alias (not a bare runtime codec identity), and preserves both pinned
  Wikipedia source IDs plus the primary Appendix D evidence on one implemented
  record. The regenerated catalog has 1,626 merged entries, 1,340 implemented
  clusters, 70 codec gaps, 121 research candidates, and 191 exact closure rows.
  The complete catalog contract passes 64/64 and Core formatting is clean.

## Cycle 75 — regenerated release cardinalities

- RED changed the executable release expectations before prose. The complete
  462-test Core suite passed 460 tests and failed only the two stale document
  assertions for 2,100 full-stack names and 1,848 Specs byte-pipeline codecs.
- GREEN updates README, extension guidance, and changelog to the generated
  2,100 full-stack / 1,848 Specs / 798 non-archive counts. The focused release
  metadata contract passes 6/6 with warnings as errors.

## Cycle 76 — post-fast-path coverage evidence refresh

- MEASURE established a clean `mix test --cover --warnings-as-errors --seed 0`
  baseline of 462/462 tests and 93.72% total coverage. The newly added direct
  Unicode paths increased executable branch surface; the enforced 90% project
  gate remains green. Current reviewed-engine figures are UTF-7 90.78%, Stream
  97.52%, ISO-2022-JP 96.30%, Stateful 98.55%, ISO-2022-CN 99.35%, and Unicode
  98.58%.
- RED changed the release metadata contract to require the measured count,
  percentages, 2026-07-18 review date, and full-domain differential facts. It
  failed 1/6 against the stale 448-test / 94.44% remediation document.
- GREEN refreshes the deep-dive disposition and records that the saved corpus
  contains all 1,114,112 code points, including all 2,048 surrogates, and
  covers 112/112 Core codecs. The focused release metadata contract passes
  6/6 with warnings as errors.

## Cycle 77 — upstream-suite traceability count refresh

- RED extended the executable upstream-coverage document contract to require
  the measured 462-test Core and 110-test Extras suite sizes. The focused audit
  failed 1/6 because the prose still recorded the older 448/109 split.
- GREEN updates only that evidence line. The focused upstream corpus,
  Makefile-invocation, digest, platform-disposition, and suite-count audit
  passes 6/6 with warnings as errors.

## Cycle 78 — terminal ISO-2022-KR recovery parity

- ISO-2022-KR RED added three non-designation ESC fragments shorter than the
  four-byte `ESC $ ) C` designator. The focused suite failed 1/6 because
  one-shot discard retained the bytes after ESC while strict decoding,
  streaming, and GNU libiconv 1.19 classify the entire terminal fragment as
  one incomplete unit. GREEN makes one-shot discard and byte substitution
  consume that exact unit; the focused matrix passes 6/6 and a wider
  state-machine selection passes 45/45.
- An adversarial sweep generated 107,590 HZ, ISO-2022-KR/JP/JP-2/CN, and UTF-7
  inputs of zero through four bytes. Discard and byte substitution produced
  zero one-shot/stream mismatch across 215,180 comparisons; strict framing
  likewise matched across all 96,479 non-UTF-7 cases. UTF-7 strict framing is
  intentionally stream-specific so errors retain the complete original shift
  source, and remains covered by its dedicated regression suite.
- The full suite then RED-failed only its source-bound exhaustive-report hash.
  GREEN refreshes that runtime digest to
  `e6201c03d44af870cb791825c6341a9e528ebd641711844d54a7d7f6c4446f6b`;
  the complete Core suite passes 463/463 with warnings as errors.

## Cycle 79 — bounded UTF-8 invalid-sequence diagnostics

- RED changed the invalid-byte callback contract first to require only the
  offending UTF-8 byte for `<<"A", 0xFF, "B">>`. The focused test failed 1/1
  because the reported sequence incorrectly retained the valid suffix `"B"`.
- GREEN bounds an invalid UTF-8 diagnostic to the byte consumed by recovery;
  incomplete UTF-8 still retains its complete trailing unit. The complete
  review-rigor coverage contract passes 9/9 with warnings as errors.

## Cycle 80 — required linear external substitution

- RED added the external-registration and malformed-result contracts first.
  The 41-test focused run failed exactly 2 tests: a codec without
  `encode_substitute/2` registered successfully, and malformed callback output
  re-entered the occurrence-probing fallback. GREEN makes the callback required,
  removes both probing paths, and returns the stable typed request error
  `{:invalid_codec_callback_return, module, {:encode_substitute, 2}, result}`;
  the focused selection passes 41/41.
- The deterministic performance regression exercises 100, 200, 400, and 800
  consecutive rejects. At every size it observes exactly one codec callback,
  zero strict `encode/1` calls, and exactly N replacement steps, while the
  multi-code-point fixture retains its longest-match boundary. This proves the
  dispatch path is one linear codec-owned pass without a timing-only assertion.
- A generator RED then failed 1/14 because both Extras module templates omitted
  the newly required callback, and the executable external benchmark RED-failed
  registration for the same reason. GREEN updates both templates and benchmark
  codecs; the focused generator suite passes 14/14 and the benchmark completes,
  measuring 24.86/247.53 MiB/s external-to-UTF-8 and 24.21/920.44 MiB/s
  UTF-8-to-external for generic/direct paths on OTP 28 and Elixir 1.19.5.
- The complete Core suite after the runtime contract change passes 466/466 with
  warnings as errors. Formatting, production compilation with warnings as
  errors, and strict documentation generation are clean; the later non-runtime
  generator guard is covered by its focused GREEN run above.

## Cycle 81 — remove superseded recovery exports

- RED loaded both modules explicitly, then failed 1/1 because the obsolete
  internal stream-invalid-byte helper (arity 6) and
  `Iconvex.UTF7Codec.decode_discard_gnu/1` helpers were still exported even
  though all callers use their replacement paths.
- GREEN removes those two functions and the now-unreachable private UTF-7
  loop while retaining the live GNU UCS-4 recovery helper. The focused public
  surface contract passes 1/1 with warnings as errors.

## Cycle 82 — immutable CI dependency resolution

- RED added a workflow contract first and failed 1/1 because neither Core CI
  dependency-fetch step checked the committed lockfile.
- GREEN uses `mix deps.get --check-locked` in compatibility and documentation
  jobs. The focused workflow contract requires exactly those two guarded
  fetches and rejects a bare `mix deps.get`; it passes 1/1 with warnings as
  errors.

## Cycle 83 — table-prefix recovery and external first-error ordering

- RECOVERY RED enumerated all 678 strict EUC-TW incomplete table prefixes and
  every possible byte split. The 7-test focused run failed when `8E A1 A1`
  substitution produced `<8e>` plus U+3000 instead of treating all three bytes
  as the terminal incomplete unit; discard streaming had the same suffix-
  reinterpretation root cause.
- RECOVERY GREEN gives table codecs native incomplete-unit consumption while
  retaining one-byte invalid-unit resynchronization. Discard and per-byte
  substitution now agree between one-shot and streaming conversion for all 678
  prefixes and every split; the focused Core matrix passes 7/7.
- FIRST-ERROR RED in the complete suite exposed a stale stateful-external
  contract: malformed UTF-8 after a target-unrepresentable prefix returned the
  later source error. GREEN invokes validated stateful direct callbacks on the
  malformed input and independently re-encodes any reported valid prefix before
  accepting a source error. The combined recovery/external selection passes
  35/35 and the direct-state regression plus recovery matrix passes 23/23 with
  warnings as errors. This adapter also enforces the ordering contract for
  third-party codecs whose optional direct callback reports the later error.

## Cycle 84 — shared target arbitration and hot-reload-safe callbacks

- ARBITRATION RED pinned the rule that an earlier target-unrepresentable
  prefix wins over a later malformed source unit in one-shot conversion and at
  every stream split. It covered built-in, stateless external, incremental
  external, and stateful direct targets, including unresolved multi-code-point
  prefixes and callback recovery before—but never after—the winning error.
- HOT-RELOAD RED registered codecs, then added or removed each optional UTF-8,
  UCS-4, incremental, and error-consumption callback. It also required pinned
  converters to observe the live module and required callback-internal
  `UndefinedFunctionError` exceptions to propagate instead of being mistaken
  for a removal race.
- GREEN centralizes first-error chronology in the internal `TargetArbitrator`
  for one-shot and streaming paths. The internal `ExternalCallbacks` adapter now performs
  purge-safe optional dispatch, falls back only when the exact callback is
  absent, and returns typed streaming errors when an incremental callback
  disappears. The focused arbitration selection passes 37/37, the broader
  callback selection passes 108/108, and the hot-reload suite passes 10/10;
  forced test and production compilation are warning-clean.

## Cycle 85 — synchronized, self-validating conversion caches

- RED raced cold and stale cache misses and traced the builders. It exposed
  duplicate publication work in table, Extras binary, and stateful pair caches;
  separate poison tests showed that same-source, same-sized malformed values
  could otherwise survive a shallow cache hit.
- GREEN serializes only cold or invalid rebuilds, publishes schema/kind/source
  and integrity witnesses with each artifact, and verifies descriptor shape
  before reuse. Concurrent callers now observe one exact published artifact,
  stale or poisoned entries repair themselves, and source-valid warm hits stay
  lock-free. The focused Core cache selection passes 26/26 and the Extras
  selection passes 17/17.

## Cycle 86 — lazy stateful startup

- RED stopped and restarted the applications with direct-table cache keys
  erased. Core startup still invoked the global stateful warmer and Extras
  eagerly materialized the ISO-2022-JP-3 planes. A measured Core start took
  303,585 µs and allocated 42,937,901 bytes; loading Core plus Extras eagerly
  retained about 81.76 MiB.
- GREEN removes both startup warmers while preserving on-first-conversion
  construction and application restart semantics. Core startup measured
  8,283 µs and 327,615 bytes, while Core plus Extras retained about
  1.8–2.2 MiB before use. The Core lazy-start contract passes 1/1 and the
  Extras JP3/cache selection passes 8/8.

## Cycle 87 — direct stateful UCS-4 across the BMP

- RED required HZ and ISO-2022-KR, as well as the JP/CN state machines, to
  decode and encode explicit big- and little-endian UCS-4 without building the
  prior million-element code-point list. Malformed input and discard recovery
  had to remain identical to the staged reference path.
- GREEN writes UCS-4 units directly and scans explicit UCS-4 input in place.
  HZ and ISO-2022-KR match staged encoding for all 65,536 BMP units in both
  byte orders, including every surrogate unit, and valid fixture bytes remain
  exact. A 107,590-input adversarial sweep over zero- through four-byte HZ,
  KR, JP, JP-2, and CN fragments preserves staged discard semantics in both
  endians. The broad stateful selection passes 95/95 and the consolidated
  direct-path selection passes 12/12.

## Cycle 88 — source-bound, fair GNU timing provenance

- RED first added the report-provenance contract; it failed because the
  execution-bound `write_report!/9` surface did not exist. Separate timing
  REDs required one untimed Iconvex warm conversion, three isolated timed
  samples, byte equality for every sample, and validation outside the measured
  interval.
- GREEN benchmarks GNU libiconv 1.19 through a compiled in-memory C helper
  using `CLOCK_MONOTONIC`, excluding process startup, file I/O, and stdout from
  engine time while retaining the GNU CLI as the byte oracle. Reports bind
  Elixir, OTP, ERTS, OS, architecture, scheduler and word-size data; timing
  constants; and exact paths plus SHA-256 digests for the GNU CLI, header,
  helper source/executable, and loaded library.
- The performance-gate suite passes 15/15, the isolated timing-helper
  selection passes 3/3, and forced compilation is warning-clean. Directional
  slowdown remains independently enforced against the unchanged 30.00x
  ceiling; failed conversions cannot hide behind zero timing placeholders.

## Cycle 89 — batch-indexed external registry claims

- RED registered one canonical name plus 512 aliases under trace. Registration
  performed 1,539 whole-claim scans and took 57.5 seconds; removal performed
  513 scans and took 5.7 seconds, demonstrating work proportional to both the
  batch and the complete registry.
- GREEN groups candidates once and snapshots affected existing claims with at
  most one ETS scan for registration, removal, and strict replacement. The
  same 513-name probe records at most one scan per phase and measured
  20.206 ms to register and 5.410 ms to remove. The focused scan contract
  passes 1/1, package ownership semantics pass 15/15, and the wider external
  registry consumers pass 56/56; production compilation is warning-clean.

## Cycle 90 — exhaustive Wikipedia-versus-GNU gap report

- RED required a checked generator plus machine- and human-readable reports
  for every directly Wikipedia-sourced catalog cluster absent from GNU
  libiconv 1.19. The focused contract failed 1/1 because the generator and
  reports did not yet exist.
- GREEN adds `generate_wikipedia_gap_report.py` with a deterministic `--check`
  mode and links both generated artifacts from the research summary. The
  report proves 394 unique absent-GNU clusters: 241 implemented by Iconvex and
  153 remaining, classified as 15 codec gaps, 121 research candidates,
  14 encoding families, one repertoire abstraction, one repertoire profile,
  and one withdrawn/unassigned part. Every row retains its Wikipedia and full
  source IDs/URLs and the Markdown binds the source-catalog SHA-256. The
  focused generator contract passes 1/1 and the broader research catalog
  selection passes 65/65.

## Cycle 91 — direct explicit UCS-4-to-C99 encoding

- RED added a mechanism test that traces the all-codepoint conversion route.
  It failed 1/5 because explicit UCS-4 still invoked `UnicodeCodec.decode/2`
  and then `EscapeCodec.encode_discard/2`; the missing direct function also
  produced the expected compile warning. On the quiet benchmark host this
  staged route was byte-exact but 62.67x GNU in the forward direction.
- GREEN scans aligned big- or little-endian UCS-4 words once and emits raw C99
  control bytes or fixed-width `\\u`/`\\U` escapes directly, without an
  intermediate code-point list. The focused mechanism selection passes 5/5,
  traces zero staged decode/encode-discard calls and exactly one direct call;
  the broader escape/stream selection passes 31/31 with warnings as errors.
  GNU libiconv 1.19 differential output remains byte-identical over all
  1,114,112 code points, and the quiet-host forward ratio fell to 26.17x under
  the unchanged 30.00x ceiling.

## Cycle 92 — direct EUC-JISX0213 dense-cache UCS-4 decoding

- RED required the Extras adapter to emit explicit UCS-4 from its dense double-
  and triple-byte caches. It failed 1/1 because the route called
  `decode_to_utf8/2` and then performed a second Unicode conversion; no direct
  dense UCS-4 callback existed. The complete quiet-host run measured the
  reverse path at 32.53x GNU.
- GREEN mirrors the discard resynchronization state machine while writing
  cached one- or two-code-point entries directly in the requested byte order.
  The focused test proves exact staged parity in both endiannesses, exactly one
  direct call and zero UTF-8-route calls. The 1,114,112-code-point GNU
  differential remains byte-identical; quiet-host measurements are 27.68x
  forward and 11.25x reverse, both below the unchanged 30.00x ceiling.

## Cycle 93 — state-preserving callback recovery

- RED exercised malformed bytes after valid shifted text in HZ and the
  ISO-2022-JP, KR, and CN families. All four probes failed because one-shot
  callback recovery recursively decoded the remaining suffix from the initial
  state, corrupting or dropping characters after the callback.
- GREEN routes callback-enabled stateful decoding through the same incremental
  state machine and first-error target arbitrator used by streams. The focused
  recovery matrix passes 7/7 and covers every split, repeated malformed input,
  absolute offsets, invalid handler returns, and source-versus-target error
  chronology. The broader callback/stateful selection passes 138/138 with
  warnings as errors.

## Cycle 94 — sparse variable-width trie fast rejection

- RED traced CP1255 decoding for 992 ordinary ASCII bytes and observed 992
  calls to the recursive longest-trie matcher even though the root had no
  child for any byte. The mechanism assertion failed because it required zero
  matcher calls on that sparse hot path.
- GREEN rejects a missing root child before entering recursive matching while
  preserving mapped multibyte and incomplete-prefix behavior. The trace now
  records zero matcher calls, and the broader table/cache selection passes
  22/22.

## Cycle 95 — linear explicit UCS-4 binary construction

- RED decoded 2,048 dense CP932 mappings and 4,096 single-byte CP1252 mappings
  in both byte orders. Exact bytes were correct, but the trace counted 4,096
  per-mapping `ucs4_word/2` allocations in the dense route instead of zero.
- GREEN uses endian-specialized tail-recursive writable-binary accumulators,
  with validated tuple expansion and whole-input restart after poisoned-cache
  repair. Exact big- and little-endian output, including a mid-input poison
  regression, passes 19/19 focused and 88/88 broader tests warning-clean.
- On OTP 28, a 1 MiB CP1252 result fell from about 24.6 ms/940k reductions to
  2.969 ms/262,624 (8.3x faster, 72% fewer reductions); a 512 KiB CP932 result
  fell from about 9.1 ms/451k to 2.565 ms/134,579 (3.5x faster, 70% fewer
  reductions). BEAM disassembly confirms `private_append` at every hot output
  site, establishing linear writable-binary construction independently of
  timing.

## Cycle 96 — final exhaustive evidence rebinding

- RED promoted the new complete differential before refreshing its derived
  benchmark narrative. The artifact/digest assertion passed, while the second
  contract failed 1/2 on the prior 276,041 ms and 29.45x figures.
- GREEN binds the checked-in Core report to the current runner/runtime and all
  112 codecs, and binds the combined report to the current Core-plus-Extras
  runtime, runner, C helper, GNU header/library, and execution environment.
  Core is byte-exact 112/112 over all 1,114,112 Unicode code points.
- Two consecutive quiet-host combined runs are byte-exact 198/198 with zero
  mismatches and zero performance failures. The promoted 48,428 ms run has
  EUC-JP as its worst direction at 28.46x, beneath the unchanged 30.00x gate;
  the permanent report/narrative contract passes 2/2 warning-clean.

## Cycle 97 — cross-runtime state-machine coverage closure

- RED was the clean OTP 27 coverage run: all 551 behavioral tests passed, but
  total line coverage was 88.95%, below the unchanged 90% gate.
  ISO-2022-JP measured 81.69%, Stateful 86.98%, Table 87.34%, and
  ISO-2022-CN 88.32%, identifying designation, recovery, and direct-UCS-4
  branches that had only indirect differential evidence.
- GREEN adds 11 expectation-first public-contract tests for every CN
  designated plane, JP G2 reuse/reset, JP-MS shifts, JP-EXT Roman/kana/Python
  mappings, both JP-3 planes and composite mappings, KR incomplete/invalid
  shifted pairs, generic multi-codepoint table fallback, Vietnamese
  non-compositions, and single-byte expansions in both UCS-4 byte orders.
  The focused suite passes 11/11 with warnings as errors and exercises 79
  executable lines missed by the clean OTP 28 baseline; no runtime code or
  coverage exclusion changed.
- The clean OTP 28 run passes 562/562 at 93.20% total coverage, with JP at
  96.06%, Stateful 99.17%, Table 96.03%, and CN 99.49%. The independent OTP 27
  run passes 562/562 at 91.04%, with the same four engines individually above
  the gate at 91.27%, 90.30%, 93.30%, and 90.36%, respectively.

## Cycle 98 — deep-dive evidence refresh

- RED changed the release and upstream-coverage documentation contracts first
  to require the final 562-test OTP 28/27 coverage results, all four package
  scopes, the 2,093-name no-double-count arithmetic, separate buffered and
  incremental streaming semantics, callback-state recovery, and an honest
  disposition for the historical 62.9 MiB figure and absent `source_url`. The
  focused run failed 2/12 against the stale 462-test/93.72% and Extras-110
  prose.
- GREEN updates the deep-dive disposition and GNU test-port summary, including
  executable evidence for incremental state/offset recovery and safe packaged
  table loading. The mirror-enforced focused run passes 12/12. Strict ExDoc
  initially identified three stale private-symbol links in this log; replacing
  those links with non-public implementation descriptions makes HTML,
  Markdown, and EPUB generation warning-clean.

## Cycle 99 — stateful terminal error and callback-ordering closure

- RED first added an explicit failing contract probe and failed 1/1 because
  the existing stateful and EUC-TW recovery blocks asserted only recovered
  values, not strict Stream metadata or invalid-byte callback behavior. The
  first concrete probe also rejected callback-versus-output-yield timing;
  review against the documented contract showed that chunk yield timing is not
  guaranteed, so the executable expectation was narrowed to source-order
  metadata and first-error target arbitration rather than adding an accidental
  API promise.
- GREEN covers the common terminal `ESC $` fragment for seven ISO-2022
  variants at all 35 split points, three additional ISO-2022-KR terminal
  fragments at all 17 split points, and every one of the 678 EUC-TW incomplete
  prefixes (67 one-byte, 8 two-byte, and 603 three-byte) at all 3,926 split
  points. One-shot and Stream strict failures now require canonical encoding,
  `:incomplete_sequence`, absolute offset, and the complete source unit;
  callback recovery requires exactly one event with the same metadata and
  first byte.
- The documented ordering rule is exercised independently: an earlier
  unrepresentable ASCII-target character suppresses every later terminal
  callback in one-shot conversion and at 5,394 split points across the same
  688 terminal cases. The focused file passes 7/7 warning-clean without a
  runtime implementation change.

## Cycle 100 — O(1) table decode-cache generation validation

- RED added a cache-shape performance contract requiring dense and variable-
  width UCS-4 discard caches to retain a constant-size table generation token.
  It failed 1/6 because each cache instead retained the complete `many` map;
  the warm guard compared that copied map structurally with the provider map.
- GREEN publishes a unique reference with each table-cache generation,
  atomically migrates legacy three-element cache records, pins the reference
  in per-conversion snapshots, and uses it for warm build and repair checks.
  Reloaded provider tables still invalidate both artifact kinds, malformed
  artifacts still rebuild once under concurrency, and the focused cache,
  lifecycle, and UCS-4 selection passes 33/33 warning-clean. The broader
  table/state-machine/review selection passes 78/78 warning-clean.
- In an OTP 28 mechanism benchmark, 20,000 CP932 equality checks over the
  copied 9,604-entry source maps took 4,511,623 microseconds; the generation-
  reference checks took 10,247 microseconds. Twenty thousand complete warm
  CP932 conversions after the change took 39,655 microseconds. The executable
  gate asserts the constant-size cache shape rather than timing.

## Cycle 101 — exact registry validation and double-crash recovery contracts

- RED used three explicit implementation mutations. Drifting one of the seven
  registration-set reason atoms failed the new exhaustive assertion 1/1;
  drifting the registry child-start wrapper failed the exact application error
  assertion 1/1; and suppressing the pre-reply recovery checkpoint failed the
  Heir-plus-registry crash-window assertion 1/1 because the owned token was
  absent from the persisted rows.
- GREEN binds all seven managed-set registration validation errors to their exact
  typed reasons and replaces both wildcard application-start assertions with
  the complete application, supervisor, child, wrapper, and root-cause shape.
  Invalid sets also assert that no module was partially installed.
- A call-site audit found that the live heir-installation protocol is cast-only,
  as required to let a replacement heir finish initialization while the
  registry is suspended. The unreachable synchronous handler and its synthetic
  call-only test were removed. The existing double-crash regression now also
  binds the versioned pre-reply snapshot token, replacement table owner and
  heir, and recovered ETS token. The focused registry selection passes 57/57
  with warnings as errors, and the touched tree is formatter-clean.

## Cycle 102 — remove test-only stateful table warmers

- RED replaced the aggregate warming call with codec-behavior contracts and
  added an exact production-surface assertion. The focused selection failed
  1/14 because `StatefulCodec.warm_direct_tables/0` remained exported; the new
  behavioral and cold-start expectations already passed against the old code.
- GREEN removes the aggregate warmer and the JP/CN variant warmers. HZ, KR,
  all six JP variants, and both CN variants now reach every formerly warmed
  decoder table and encoder descriptor only through real direct or ordinary
  encode/decode behavior in the tests. The internal-surface contract rejects
  either warmer arity on all three production modules.
- Startup laziness is verified from the absence of every stateful pair-cache
  and JP/CN encoder-dispatch entry, without tracing a deleted function. The
  final focused selection passes 14/14 and the broader stateful/ISO-2022
  selection passes 90/90, both warning-clean; touched files are formatter-clean.

## Cycle 103 — repository-only GPL test boundary

- RED added a release-metadata contract requiring the LGPL Hex artifact to
  exclude `LICENSE.GPL-3.0` while the exact upstream `uniq-u.c` fixture and its
  license remain available in the repository. The focused run failed 1/7
  because the package file list still selected the GPL text even though the
  corresponding test source was never packaged.
- GREEN removes only that repository-only license from the package selector.
  README and NOTICE now say explicitly that both the GPL test source and its
  license text are repository-only and excluded from Hex. The source files
  remain unchanged for exact upstream test provenance, and the LGPL runtime
  license declaration is unchanged.
- The focused release suite passes 7/7 with documentation-mirror verification
  enabled. The clean-artifact audit separately byte-binds the resulting Hex
  tree and rejects any repository-only evidence that enters it.

## Cycle 104 — opaque external arbitration lower bound and no-op reuse

- RED added a deterministic callback-count contract for one valid target
  prefix followed by three discarded malformed UTF-8 units. The focused run
  failed 1/10 because opaque arbitration encoded the identical `[?A]` prefix
  four times—once before the first handler, again before both no-op handlers,
  and once for final output—instead of the required probe plus final encode.
- GREEN retains a successfully validated opaque probe when the next arbitration
  contributes zero Unicode code points. This preserves target-first error
  ordering while reducing that case from four encoder calls to two; the
  initial focused run passed 10/10. Two stateful one-shot proof fixtures bind
  the irreducible boundary: a code point can fail alone but succeed after
  retained shift state, while another can succeed alone but fail in that
  state, so probing only deltas would change both error ordering and exact
  `0E 41 01 0F` bytes. Probes after newly contributed code points still
  require the documented cumulative fallback unless the codec supplies
  incremental encoder callbacks.
- The final callback-ordering suite passes 12/12 on OTP 28 and 12/12 on OTP
  27. The broader external-codec, Stream, fast-path, and review regression
  selection passes 74/74 with warnings as errors; production compilation is
  warning-clean and the touched files are formatter-clean.

## Cycle 105 — exact upstream-versus-derived corpus accounting

- RED split the imported test-fixture contract into archive-origin and derived
  sets. The focused run failed 2/7: the fixture helper had no independently
  checkable upstream/derived manifests, and the published traceability document
  still called all 268 files upstream even though the release archive contains
  no configured `tests/Makefile`.
- GREEN identifies that single configured file explicitly. The remaining
  267/267 files have exactly the same names and bytes as GNU libiconv 1.19's
  `tests/` directory. Separate sorted-manifest digests bind the 267 upstream
  files, the one derived file, and their 268-file audited union; every file
  remains classified by the executable coverage inventory.
- The initial focused corpus and coverage selection passed 7/7. A follow-up
  release-prose contract then failed 1/8 on the same 268-as-upstream wording in
  README, NOTICE, and CHANGELOG; GREEN corrects those documents and their exact
  mirrors. The combined corpus, coverage, and release selection passes 15/15
  with warnings as errors. Direct extraction from the pinned
  `libiconv-1.19.tar.gz` confirms all 267 archive files are byte-identical to
  the local upstream subset.

## Cycle 106 — non-terminal recovery state and global first-error ordering

- RED added four expectation-first regressions. C99 `<<92, 255>>` with
  invalid-byte discard raised a terminal backslash error at all three split
  points instead of retaining `"\\"`; a compliant external stateful source
  converted `A!B` to `Ab` instead of the one-shot `AB`; UTF-8
  `<<C2, AB, FF>>` to HZ reported the later source error in one-shot and three
  stream layouts instead of the earlier target U+00AB error; and an external
  stateful direct target lost the same chronology when malformed UTF-8 shared
  a chunk with its valid prefix. The focused RED run failed 4/4.
- GREEN decodes stable recovery prefixes non-finally and carries the resulting
  source state into the suffix, while escape recovery uses its full-input
  boundary scanner so a backslash made literal by the following invalid byte
  remains observable. Target arbitration now runs at every decoder-reported
  error boundary, including strict conversions without callbacks, and one-shot
  strict fallback uses the same chronological rule. UTF-7 retains its
  GNU-compatible strict offset and callback-only replay frame.
- The new matrix passes all 21 split executions: 3/3 C99, 4/4 external
  stateful source, 4/4 HZ, and 5/5 external stateful-target splits under both
  strict and callback modes, with exact target identity/codepoint and callback
  suppression. The focused suite passes 4/4, the broader recovery, callback,
  Stream, external, escape, UTF-7, and stateful selection passes 117/117, and
  the final touched-path selection passes 46/46 with warnings as errors;
  compilation and formatting are clean. Streams remain bounded because
  arbitration occurs only at source-error boundaries and advances cloned
  incremental target state rather than buffering the input.

## Cycle 107 — generation-pinned table providers across converter lifecycles

- RED created IBM-17354 decode and encode buffered converters, fed them,
  stopped archive shard C, installed shard B as the live provider for ICU
  archive table 735, and finalized. The focused test failed 1/1 with
  `File.Error` for shard B's nonexistent table: the codec entry was pinned but
  bare `Tables.fetch!` routing was not. A second RED constructed a lazy
  external Stream, replaced its provider before enumeration, and failed 1/1
  during transform with the replacement application's missing `priv` path.
- GREEN snapshots the provider directory once per generation as an immutable
  persistent-term map shared by reference, stores it in resolved
  Converter/Stream state, and restores it process-locally around one-shot
  conversion, buffered finish, Stream initialization, every lazy transform,
  and finalization. Provider changes use a two-cell atomics generation/active
  clock; registration and stop do no full-map work, the next resolution
  rebuilds once, and old maps are garbage-collected with converter values. No
  table map, provider ownership token, or 1,050-table set is copied.
- Exact lifecycle contracts cover source and target IBM-17354 converters
  through shard-C stop, live shard-B replacement, and restart; one-shot
  replacement during a codec callback; nested context restoration; warm
  snapshot physical identity; and lazy Stream transform/final callbacks. Core
  focused passes 16/16, broader relevant Core passes 95/95, focused IBM passes
  5/5, and Specs/archive passes 23/23; archive C compiles with warnings as
  errors and all touched files are formatter-clean.

## Cycle 108 — O(1) stateful UCS-4 pair-cache generation validation

- RED retained the exhaustive 107,590-input staged-versus-direct semantic
  matrix that exceeded its 300-second timeout, then added a deterministic
  cache-shape contract. The focused contract failed 1/1 because production
  pair caches had no generation-token API and retained complete source maps.
  Profiling isolated the warm-path cost to structural validation of the
  6,879-entry JIS X 0208, 7,445-entry GB2312, 8,421-entry ISO-IR-165, and
  61,311-entry EUC-TW maps. Empty-input direct calls cost 449.37–6,869.37
  microseconds despite performing no state-machine mapping work.
- GREEN adds reference-token overloads for seven-bit, EUC-TW, and
  EUC-JISX0213 descriptors and wires HZ, ISO-2022-KR, every JP variant, and
  both CN variants to the existing exact table-generation identities. Legacy
  source-map validation remains available for synthetic callers and its
  corruption/concurrency contracts. A changed generation still rebuilds the
  descriptor, while repeated calls with the same identity retain the original
  witness without comparing or retaining a second source map.
- Twenty thousand warm token validations took 1.561–1.827 microseconds each,
  independent of source-map size. Warm empty-input direct decoding now takes
  4.25–10.51 microseconds across HZ, KR, JP, JP-2, CN, and CN-EXT, or
  2.6x–10.3x their staged paths. The complete 107,590-input matrix passes in
  1.773 seconds of test time, and the full focused file passes 13/13 in 7.9
  seconds. The broader OTP 28 stateful/cache selection passes 121/121; OTP 27
  passes the focused file 13/13 and broader compatible selection 88/88.
  Production compilation is warning-clean and all touched files are
  formatter-clean.

## Cycle 109 — bounded-depth EUC-JP reverse decoding

- RED added a deterministic hot-path contract over every 14,889 valid EUC-JP
  two- and three-byte mapping, ASCII, invalid boundary grids, and incomplete
  terminal prefixes in both explicit UCS-4 byte orders. It failed 1/1 because
  a single reverse pass entered the generic recursive variable-width matcher
  36,789 times; the contract requires exact staged-decoder bytes with zero
  generic matcher calls rather than relying on a timing threshold.
- GREEN selects an endian-specialized, depth-three unrolled walk for the
  built-in EUC-JP trie. It preserves longest-match consumption and
  GNU-compatible invalid/incomplete discard recovery, falls back to the
  generic matcher for a valid nonstandard provider shape, and fails closed
  through the existing cache-repair path for malformed nodes. A dedicated
  poisoned-branch regression proves repair before reuse. The focused
  cache/UCS-4 selection passes 22/22, and the broader table,
  generated-conformance, engine, review, and recovery selection passes 55/55
  with warnings as errors on both OTP 28 and OTP 27; touched files are
  formatter-clean.
- On isolated Dell OTP 27, a same-BEAM 21-sample paired mechanism benchmark
  reduced the median generic-trie reverse pass from 1,975.698 to 871.286
  microseconds, a 2.268x speedup. The pinned GNU libiconv 1.19
  `--enable-extra-encodings` differential remains byte-exact for all 1,114,112
  corpus code points: 36,915 EUC-JP bytes and 15,019 round-trip code points
  with zero mismatches. Calibrated reverse timing is 1,081.921 microseconds
  versus GNU's 174.168125 microseconds (6.21x), and forward is 5.70x, both well
  below the 30x gate.

## Cycle 110 — sparse Vietnamese reverse decoding

- RED added a deterministic TCVN exhaustive-reverse mechanism contract. The
  byte-exact result still passed, but the 382-byte corpus entered the generic
  65,536-entry dense walker 646 times across both UCS-4 byte orders; the test
  requires the public direct path to select the Vietnamese sparse walker and
  make zero dense-walker calls.
- GREEN adds an identity-bound sparse two-level composition cache for CP1258
  and TCVN. It discriminates pair-prefix bytes in O(1), batches adjacent
  non-prefix single bytes, preserves longest-match and discard boundaries, and
  falls back to the existing dense/general paths for unsupported provider
  shapes. Malformed cached rows repair before reuse, and external table
  generation changes rebuild against the new identity.
- The dedicated suite passes 4/4 and compares every 65,536 byte pair for both
  codecs in both explicit UCS-4 byte orders. The broader table/cache/recovery
  selection passes 60/60 on OTP 28 and OTP 27 with warning-clean compilation.
  On isolated Dell OTP 27, the pinned GNU libiconv 1.19 differential is
  byte-exact with zero performance failures: forward is 6.88x GNU and reverse
  is 8.24x GNU, reduced from the reproduced 43.89x breach.

## Cycle 111 — positive EUC-JP fast-path and provider-fallback evidence

- RED mutation-tested the Cycle 109 mechanism contract by forcing the selected
  EUC-JP trie cache to `:unsupported`. The old byte-parity and zero-generic-call
  assertions still passed even though neither trie matcher ran. Adding the
  missing positive selection assertion failed 1/1 with zero
  `euc_jp_trie_match/2` calls, proving the review's test-adequacy finding.
- GREEN traces both matchers: the complete built-in mapping/boundary corpus must
  enter the bounded EUC-JP matcher and make zero recursive generic calls. A
  registered synthetic provider with independent and overlapping two- and
  three-byte leaves, malformed bytes, and an incomplete terminal prefix must
  preserve staged output while entering both the bounded matcher and its valid
  generic fallback in both UCS-4 byte orders.
- The strengthened OTP 28 UCS-4 file passes 17/17, the source-bound
  report/UCS-4/Vietnamese selection passes 22/22, and isolated OTP 27 passes the
  two hot-path files 21/21 with warnings as errors. Production source did not
  change; `table_codec.ex` remains
  `dd91ab8dc45095d747e7410488517b809ee1cf99918895fca7f04b4db30d55ea`.

## Cycle 112 — final frozen-source exhaustive and performance evidence

- RED left the source-bound reports untouched after the last runtime changes.
  Core's normal suite failed only the stale exhaustive runtime digest; Extras
  failed its stale failed-performance report and 48,428-millisecond benchmark
  narrative. A new package-document binding contract then failed 2/3 on the old
  CP943/EUC-JISX0213 measurements and old Core benchmark summary.
- GREEN regenerated the sequential 1,114,112-code-point oracle against pinned
  GNU libiconv 1.19 with `--enable-extra-encodings`. Core passes 112/112 with
  zero forward, reverse, or cross-decoder mismatches in 40,076 milliseconds;
  the report is bound to runtime digest
  `d839fc223699b69d4350f83db222e1aa47af45f397fb38720c2dd7dea008fdcf`.
  The complete Core-plus-Extras run passes 198/198 with zero mismatches and zero
  performance failures in 49,339 milliseconds; TDS565 is worst at 27.55x,
  EUC-JP is 5.52x/10.27x, and TCVN is 6.64x/11.00x under the unchanged 30.00x
  directional ceiling.
- All performance outcomes remain auditable. Two complete frozen-source runs
  passed at 27.68x and 27.55x worst; one byte-exact run retained a 32.43x
  IBM-1165 reverse failure. Seven isolated reruns each of IBM-1165 and TDS565
  then produced 0/28 directional breaches. The IBM numerator stayed
  7.127–7.427 microseconds instead of the non-reproducing 21.515-microsecond
  sample; no result was erased and the threshold was not relaxed. Final Core
  passes 584/584, Extras passes 133/133, and the new evidence-binding contract
  passes 3/3.

## Cycle 113 — final cache-boundary coverage evidence

- RED mutation-tested three previously implicit table-cache boundaries. With
  cache sharing, Vietnamese shortcut arbitration, and corrupt sparse-cache
  repair each disabled in turn, the new focused file failed 3/3. Separately,
  rebinding the release evidence to the new test inventory first failed the
  stale coverage and upstream-cardinality contracts before any prose was
  updated.
- GREEN adds only executable boundary contracts: nested conversions must share
  and restore the populated process cache even when the caller raises;
  Vietnamese composition codecs must refuse the single-byte shortcut without
  fetching their pair table; and malformed selected sparse leaves and
  lookahead rows must repair to exact staged parity in both explicit UCS-4 byte
  orders. No runtime source changed.
- The final source-bound OTP 28 run passes 587/587 at 93.26% total coverage:
  the Tables module is 93.57% and the TableCodec module is 92.59%. The independent
  OTP 27 run passes 587/587 at 91.18% total coverage, with those modules at
  92.40% and 90.56%. The OTP 28 log SHA-256 is
  `fccca449b70db8c5de5f4d0e41933cf3bfad0f866ae9ab500c6f233bbfc211b4`;
  the OTP 27 log SHA-256 is
  `99be54c5b437e565bafa4210202d4123b0c7a5076e603b877b16b300d933b5d6`.
  Release and upstream evidence contracts then pass 14/14. Runtime digest
  remains
  `d839fc223699b69d4350f83db222e1aa47af45f397fb38720c2dd7dea008fdcf`;
  the final sorted test-suite digest is
  `bb313e79a8c896f9a236ff4ae1df3ffd2d3a58b4aaec9bd6b7e171c7be327e09`.

## Cycle 114 — bounded derived table-cache lifecycle

- RED exercised one owned provider each for the dense two-byte, Vietnamese
  sparse, and variable-width trie accelerators, warmed the exact base and
  derived terms, then unregistered with the ownership token. The focused run
  failed 1/17 because provider removal erased only the base table: the CP932
  dense tuple remained resident, so later cache families were not reached.
  The captured RED log SHA-256 is
  `95807b4824e4c2412e5af8aae6670723525cf3240956450103e9d655e992c487`.
- GREEN gives `TableCodec` one authoritative list of its three derived key
  families and erases each key under the same per-key build lock used for
  publication. Provider removal first withdraws its route and base generation,
  then clears every derived accelerator. The unchanged ownership checks mean a
  stale or foreign token still cannot evict a replacement provider's caches.
  The focused lifecycle run passes 17/17; its log SHA-256 is
  `eea73ee24f282829e0125da652c803582d4b456c1bdf584092ad5b934cb2c4c9`.
- The runtime and extension documentation now states the finite shipped-cache
  bound, provider-unload cleanup contract, and control-plane cost of
  `persistent_term` replacement instead of implying an unbounded hot-path LRU.

## Cycle 115 — same-owner managed-set restart adoption

- RED added an exact token-loss regression for an optional codec package: a
  managed set registers successfully, its caller loses the opaque token, and
  the same owner registers the identical set before shutdown. The focused
  command failed 1/1 because the second call returned a fresh token whose empty
  set could not remove the original modules or claims. The captured RED log
  SHA-256 is
  `1b58c6b7cbdffc695c11573af7f3736688da872518d33aa56ab80a0ecc5f403d`.
- GREEN adopts the original committed token only when owner, priority, complete
  module membership, each module's managed token, and rebuilt codec metadata
  all match. Empty, strict, partial, replaced, or changed registrations retain
  the existing path, including the contract that unrelated pre-existing strict
  codecs survive managed-set shutdown. Unregistering the adopted token now
  removes the original module, names, claims, and set row.
- The focused regression passes 1/1 and the complete package-claim file passes
  17/17. Independently isolated registry consumers pass 29/29, 14/14, and 9/9;
  the application restart/configuration case passes 1/1. An exploratory
  seed-zero multi-file grouping exposed that stateful configuration test's
  pre-existing cross-test ordering dependency and is not reported as a GREEN
  combined run. Production compilation passes all 26 files with warnings as
  errors, and both touched source files are formatter-clean.

## Cycle 116 — terminal source-versus-target error chronology

- RED first locked the exact built-in UTF-8 `<<C4, 80, C4>>` to US-ASCII
  contract for strict one-shot conversion, all four Stream splits, and the
  buffered `new/feed/finish` API. That built-in case already passed through its
  consumable-error arbitration path. Two terminal-only regressions then used a
  compliant external UTF-8 decoder that declares the complete two-byte unit
  width while only one lead byte remains; the focused run failed 2/3 because
  both resynchronizing and stopping one-shot paths returned the later
  incomplete-source error instead of the earlier target U+0100 error.
- GREEN probes the stable terminal source prefix with the existing incremental
  target arbitrator before returning an incomplete or invalid source error.
  Stream includes pending target state and deferred replacement codepoints;
  one-shot resynchronizing recovery uses its decoded prefix, while stopping
  recovery obtains the exact retained prefix through the codec's required
  discard callback. If that prefix is representable, the original source kind,
  offset, and sequence remain unchanged.
- The final focused file passes 4/4, covering strict and callback one-shot
  conversion, every terminal Stream split, buffered conversion, callback
  suppression, both external recovery declarations, and the representable-
  prefix control. The broader ordering, recovery, streaming, external-codec,
  provider-lifecycle, and state-machine selection passes 135/135 on OTP 28;
  the focused file passes 4/4 on OTP 27. Production compilation is warning-
  clean and all three touched Elixir files are formatter-clean.

## Cycle 117 — external stateful decode-policy continuation

- RED added a stateful external source whose valid prefix changes decoding
  state before an invalid unit. One-shot byte substitution failed 1/1 with a
  `MatchError`: the generic stateless prefix helper received the codec's
  four-element incremental result. A second contract requires an invalid-unit
  consumption to advance codec-owned state instead of preserving a stale
  bounded-frame counter. The focused RED log SHA-256 is
  `4cfe693eb966bac422718b758077e89ff8de81c27d81ac64e29b82adc31773c0`.
- GREEN routes replacement and callback policies for resynchronizing stateful
  external sources through their existing incremental decoder. The optional
  `decode_recovery_state/4` callback receives the valid-prefix state, strict
  error frame, and complete consumed unit, allowing counters and bounded
  payload frames to advance without interpreting malformed bytes as ordinary
  input. Missing callbacks retain the prefix state, and `:stop` codecs retain
  their whole-string path.
- The focused global-order suite passes 6/6 and the broader external,
  stateful, stream-recovery, terminal-ordering, and parity selection passes
  58/58; its log SHA-256 is
  `f5f994243b9f5d7ad8c013b2e544cca4e0cec98f34e9933702343de58f0dadfd`.
  The source-bound release contract correctly reports the prior frozen runtime
  digest stale and is left for the final evidence regeneration. Production
  compilation passes 26 files with warnings as errors, and all touched Core
  files are formatter-clean.

## Cycle 118 — state-machine split-boundary equivalence

- RED independently reproduced all three provisional state-machine findings.
  For JP-MS, `1B 24 42 0E 46 7C 1B 28 42 41 42` decodes to `日AB` in GNU
  libiconv 1.19 and one-shot Iconvex, but Stream split 9 silently produced
  `日疎` and split 10 reported a spurious incomplete `B`. For each JP/JP-1/
  JP-2/JP-MS/CN/CN-EXT source, Stream splits 2 and 3 truncated the invalid-
  escape callback frame for `1B 41 53 43`, changing a sequence-dependent
  callback decision. Finally, UTF-8 `A£+` encoded to GNU's `A+AKMAKw-` in
  one-shot conversion but every lazy Stream split produced `A+AKM-+-`. The
  expectation-first run failed 3/4; the fourth test proved ISO-2022-KR already
  retains its four-byte frame at every split. The RED log SHA-256 is
  `759a6de08851d2836be019b473c83879a6f8eacee950c7130e0f241af5e92931`.
- GREEN makes the JP-MS scanner consume SO/SI as one control byte in every
  mode, toggling only Roman/Kana as the decoder does, so an ignored shift can
  no longer steal half of a two-byte character or hide the following escape.
  JP/CN non-final decoders retain an invalid ESC suffix until its bounded
  four-byte diagnostic frame is complete or EOF fixes its shorter size.
  UTF-7 now emits `+-` only from direct mode; a plus encountered in an active
  shift is encoded as its UTF-16 unit in the same Base64 run.
- The focused strict/discard/byte-substitution/callback matrix passes 4/4 on
  OTP 28 and OTP 27; the focused GREEN log SHA-256 is
  `1d5b58bdef8fe0d2769530b031570c7c182abc7413c52a83084e93a620aa03d9`.
  The complete 19-file stateful selection passes 167/167 with log SHA-256
  `a751d4248738131ce019d770fa2eb54208e409146ec9ca3c37c6742deb1fe8ac`.
  An additional exhaustive short-sequence probe compares 1,555 UTF-7 inputs at
  all 13,375 byte splits with zero mismatches. Pinned GNU output is independently
  confirmed as hex `e697a54142` for the JP-MS vector and
  `412b414b4d414b772d` for UTF-7. Production compilation is warning-clean and
  the two source files plus the regression file are formatter-clean.

## Cycle 119 — coherent codec/provider route construction

- RED deterministically paused construction after resolving an old external
  codec entry, completed old codec/provider teardown and new provider/codec
  startup for the same dynamic table ID, then resumed. One-shot conversion
  spliced the old codec to the new provider, and the bounded-retry contract had
  no implementation; the original 2/2 failure log SHA-256 is
  `1e1e475b02ea8b8f9d824f31a5c154a50482146e50ac94a4748bc191de928130`.
  A pre-publication barrier separately proved that mutation did not invalidate
  readers before its write; that RED log SHA-256 is
  `1b422253512addba2044509181f0dfe4efe2aee2b448e09537f3e195441270b4`.
  Killing a provider updater then stranded the old provider clock indefinitely
  (`0c0ba9ba554d77d2c85cda981a5033d6e0c8a951806b486cb03ebafcaf0b8ac1`).
  A final repair-window barrier exposed active clearing before the abandoned
  generation bump; its RED log SHA-256 is
  `ee87f86ea532dfd82278efa70908625296c491ae8fe88391860758d9c3142fe1`.
  Heir-owned lookup with no registered worker then proved the nil branch could
  bypass an active route epoch
  (`beb716ce20a53bb12c76ec18ffcc16f08158acb5100bd26197c60784c099fcc0`).
  Finally, a serialized capture and replacement registry initialization
  deadlocked on each other's route lock/readiness wait; that RED log SHA-256 is
  `094e114a55c4b83353efae531017ffe2de840cc522a0af29f97fba05ae2d9264`.
  A public-constructor control then removed the sentinel handler and reproduced
  the leaked `WithClauseError` while an inherited pending set awaited rollback;
  its RED log SHA-256 is
  `e0fbe6c1ccc29f9c9aee203d29c475e4d7649d91192135ec122ac11a0279b597`.
- GREEN adds one shared route seqlock across external-registry commits, Heir
  cleanup, registry initialization, and provider publication. Writers mark the
  route invalid before publishing and close it in `after`; provider snapshot
  generation is pre-bumped and has no kill-strandable active counter. A dead
  writer is repaired under the serialized route lock. Registry readiness keeps
  direct lookups behind complete inherited-table repair and configured-codec
  reconciliation without holding that lock across the Heir handoff. A
  readiness collision while already owning the route lock returns an internal
  retry sentinel, releases the lock, waits outside it, and recaptures; it never
  exposes the replacement's unrepaired inherited table.
- `convert/4`, `new/3`, and therefore `stream/4` capture both codec entries and
  the provider map under one validated generation. Eight lock-free attempts
  precede a single serialized fallback, bounding reader-side retries under
  churn while completed converters remain lock-free. Supported lifecycle order
  removes codecs before providers and starts providers before codecs, so every
  stable intermediate resolves unknown; crossing a mutation retries. An
  intentionally published provider replacement while its old codec remains
  registered is a package-defined stable state and must retain that ordering.
- The final focused suite passes 8/8; its log SHA-256 is
  `25e1aad3eda42bde15d440c54f5026ddd0886d205fa18435ab0df9af5595e30f`.
  The registry/provider/cache/recovery selection passes 109/109 with log
  SHA-256
  `34645d3696a99079d08d090ff5c1bb2137876af8e501d6bda1a4f45cb60643ca`.
  Production compilation passes 27 files with warnings as errors and all
  touched Elixir files are formatter-clean.

## Cycle 120 — packed semantic-error coordinates

- RED packed the exact four-unit review reproducer
  `<<0x5C, 0x65, 0x00, 0x00>>` at seven bits per unit and decoded it as
  `JIS_X0208` in both bit orders. Both public helpers leaked the temporary
  octet-buffer error at byte offset 2 instead of the physical packed failure
  at bit offset 14. The focused 2-test run failed twice; its log SHA-256 is
  `397ad41cc8bfe6c87aaea7e12b7999bd024ca44463dd10f4248ee8e5433e98e3`.
- GREEN gives conversion errors an explicit byte-or-bit coordinate unit and
  remaps both invalid and incomplete semantic failures after unpacking. MSB
  errors carry an exact bitstring; LSB errors carry a new self-contained
  `Iconvex.Packed.LSB` fragment with its wire order, unit width, and meaningful
  bit count intact. The packed focused selection passes 9/9; its log SHA-256
  is `ad75c10fc58d0f14cd5d7b1501040321f6b516d8c35f4f1e4e8ac4048e285de0`.

## Cycle 121 — exact managed-set restart rejection

- RED registered a two-module managed set, lost its token, then retried with a
  partial set and with changed metadata. Exact adoption correctly declined,
  but the insertion path silently skipped each pre-existing managed module and
  committed a fresh empty or partial set. The focused regression failed 1/1;
  its log SHA-256 is
  `a0512724c9d821b00483ca32bfdd0205a2154936f850681a1e08f6e10a95f086`.
- GREEN treats a pre-existing managed module as a typed
  `managed_registration_conflict` whenever exact committed-set adoption has
  failed. Exact owner/priority/module/metadata adoption remains unchanged, and
  pre-existing strict or caller-owned modules retain the intentional skip
  contract.
- The focused regression passes 1/1 with log SHA-256
  `488456c903653c0ac8f34bdc0d19c62d54d14d19922b82e5b0185103fa861764`;
  the complete package-claim suite passes 18/18 with log SHA-256
  `6bbcb86caa0f91357b33cf817d4abe474b4f90a29b473803f9e164a7dbc458ce`.

## Cycle 123 — one-shot stateful codec compatibility

- RED registered a compliant external codec that declares `stateful?: true`
  but intentionally implements only the required whole-input callbacks. Valid
  and malformed one-shot conversion with byte substitution or an invalid-byte
  callback crashed because Cycle 117 selected the optional Stream decoder
  solely from metadata. The lazy Stream rejection control already passed. The
  focused run failed 2/3; its log SHA-256 is
  `aa7a5ab06bae4442613ebf0b56b042097e754a713d22e34f89c53b43c69563e3`.
- GREEN selects incremental one-shot recovery only when both
  `stream_decoder_init/0` and `decode_chunk/3` are exported. Otherwise the
  existing required-callback path retains valid conversion, byte replacement,
  callback framing, and absolute offsets; lazy Stream remains explicitly
  unsupported. The focused run passes 3/3 with warnings as errors; its log
  SHA-256 is
  `74f0108eeeb4456f63b8db69855cfa8b25e4ecc73a178a4f603daa0cd6e543e7`.

## Cycle 125 — terminal-empty incomplete discard

- RED added a counted stateful external source whose valid payload prefix is
  shorter than its declared length. The decoder reaches physical EOF with an
  exact empty error sequence: there is no byte available to consume. One-shot
  native discard retained the valid prefix, but every lazy Stream split raised
  the terminal incomplete error. The focused 2-test run failed 1/2; its RED
  log SHA-256 is
  `9e3df938553a9ced554555cda5e8574be3530df861c7449abbba87d86a93f3ef`.
- GREEN gives only plain `invalid: :discard` a narrow terminal rule for an
  incomplete source at physical EOF with an empty sequence and no remaining
  byte. It retains the already-decoded stable prefix without inventing an
  invalid-byte event. Strict conversion, byte substitution, and callbacks
  still return the original structural truncation; callbacks are not invoked
  without a physical byte.
- The synthetic focused suite passes 2/2; its GREEN log SHA-256 is
  `09f15db9e61a617e69a7e2d056ddb800d5d0069d3f4af85d88d706eebd77ebb2`.

## Cycle 126 — external structural-EOF prefix arbitration

- RED reused the counted external codec whose stable payload ends in a
  declared but absent unit. One-shot terminal arbitration assumed decoding the
  physical prefix must succeed and crashed on the codec's structural-EOF
  result, so both the original source error and an earlier target error were
  lost. The focused run failed 2/4; its RED log SHA-256 is
  `41d9e2969a31f610d236d9caaa0d616c98dbff2dbbe7643940a2d4fcca577d14`.
- GREEN lets external terminal-prefix recovery use the codec's required
  `decode_discard/1` callback only when ordinary decoding reports the exact
  incomplete boundary. A representable prefix still returns the original
  structural EOF, while an earlier unrepresentable target code point wins in
  one-shot and Stream conversion.
- The focused strict/source/target arbitration suite passes 4/4; its GREEN log
  SHA-256 is
  `9c540f104bf8f36a0667ec532cea93d40c29d55628fd54889e7aa96430c52e23`.

## Cycle 131 — ISO-2022-KR exhaustive reverse throughput

- RED uses the exact 16,588-byte ISO-2022-KR stream emitted from the complete
  U+0000..U+10FFFF UCS-4BE corpus. Its encoded SHA-256 is
  `ace54173454b6d2baaa97952a4d31f712e0bf9ef468eb9754ca56baac42d6e9f`;
  the 33,408-byte discard round trip is pinned to
  `d175c3852790a9bf22c978209c85abc3f827ed0ba150f256659bc4ff0bc98549`.
  The expectation-first test found 8,227 public
  `StatefulPairCache.lookup/4` dispatches in one reverse conversion and failed
  1/1. Its RED log SHA-256 is
  `f7784df9c6c918ebaa4ba4516903ec83637af57102c741072b85d621a1218032`.
- GREEN acquires and validates the dense 94x94 descriptor once, indexes it in
  the ISO-2022-KR recursion, and writes selected UCS-4 words into one
  private-append binary accumulator. Missing or malformed table entries still
  discard only the first byte, truncated escapes still retain their stable
  prefix, and both output byte orders retain the prior semantics.
- Identical isolated OTP 28 measurements use 15 calibrated samples of at least
  5 ms after warmup. Median wall time fell from 277.436 to 153.290 microseconds
  (1.81x), and isolated-process reductions fell from 28,248 to 9,561 (66.2%).
  The benchmark logs have SHA-256
  `be6251eab5c9a83d4cb46625ca7cf14695984330c71b37217008c9ae45c9e5ee`
  before and
  `a15f69c5fcaa4a67ede1d0f3a454f8d9d1d873ed5ff3a139e9ce2407a0572bfc`
  after.
- The final focused GREEN passes 1/1 with log SHA-256
  `6d58ad1b36d817604e5ba25f0dd84787416fce2b6cd3393a973371f09867c8a2`.
  The direct/adversarial suite passes 14/14, including 107,590 short inputs in
  both endians, with log SHA-256
  `f03d2379de620f84bee3fa0970512a5fd72d183824e7714cba23d7a997c65010`.
  The broader stateful, policy, callback, split, terminal, and ISO selection
  passes 110/110 with log SHA-256
  `a42d133be812868486b5f6da68428f965638f6b9daf05085687b173a7e8adf4f`.
  Production compilation passes 27 files with warnings as errors, and the
  implementation, regression, and documentation files are formatter-clean.

## Cycle 132 — post-optimization exhaustive and coverage rebinding

- RED retained the prior runtime-bound Unicode and coverage evidence after the
  ISO-2022-KR hot-path change. Core failed only the stale coverage-runtime
  assertion; the complete OTP 28 run still executed 620 tests and measured
  93.42% total line coverage. The combined 198-codec runner was byte-exact but
  honestly failed two non-reproducing timing samples before any prose changed.
- GREEN reran the sequential 4,456,448-byte UCS-4BE corpus over all 1,114,112
  code points, including 2,048 surrogates. Core passes 112/112 codecs with zero
  forward, reverse, or cross-decoder mismatch; the report SHA-256 is
  `f2295dda20a0dee1a8869f55748a040cc27490fa01a60debdd58a5774b7ac1f8`
  and runtime digest is
  `dc17a7c505089e6705fd7d113d1133c5fda5331b613f9dd8c53ef8861acd1ad8`.
- The repeat combined run passes 198/198 with zero mismatches and zero
  directional breaches in 62,807 ms. C99 is worst at 23.68x and ISO-2022-KR
  reverse is 3.27x, down from the review's 41.44x failure. The combined report
  SHA-256 is
  `880f310185d8f1b6b9a249e43a5ef3d30b52f882d9a0f91dc66b64cec02fdd99`.
- The source-bound OTP 28 coverage RED measured 620 tests with only the stale
  evidence assertion failing, 93.42% total, and Stateful at 98.92%. After the
  evidence update, the complete OTP 28 run passes 620/620 at the same 93.42%.
  The exact snapshot plus its sibling Specs research evidence was copied to
  Dell; OTP 27/Elixir 1.19.5 passes 620/620 at 91.53% total, with Stream at
  93.72%, Tables at 94.77%, Stateful at 91.08%, and TableCodec at 90.63%.

## Cycle 137 — terminal substitution target arbitration

- RED extended both resynchronizing and stopping external-source terminal-EOF
  contracts to byte substitution. An earlier U+0100 target failure was masked
  by the source's later incomplete byte in both paths; the focused run failed
  2/4. Its log SHA-256 is
  `a8369e5200768f51149e3e720548d4832dd05de7f16cc8ed65614e461c98dbda`.
- GREEN routes terminal structural-EOF prefixes through the same target probe
  used by strict and callback recovery. An earlier target failure now wins;
  a representable prefix still preserves the original incomplete-source error.
  The focused one-shot/every-split suite passes 4/4; its log SHA-256 is
  `d6bf94472722693eaea1dfb28060c2e0a37ffd2d25d414aa9febc6c26caea9f6`.

## Cycle 138 — registry mailbox resilience

- RED sent unrelated messages to both external-registry singletons. The main
  registry crashed with a `FunctionClauseError`, so the focused run failed
  1/10. Its log SHA-256 is
  `c412c7cde7504e6f4bebb0515143b8c7c85fea2f1b90cf7f31141b025b427ea6`.
- GREEN makes both GenServers retain state for unrelated mailbox messages while
  preserving their exact tagged ETS-transfer handling. The focused lifecycle
  suite passes 10/10; its log SHA-256 is
  `83e7ed07b9aeadf8e0a38967333b18bc6a8c67fd473a42b631bde74794c16721`.

## Cycle 139 — immutable CI inputs and strict documentation

- RED required the package-local documentation job to fail on warnings and the
  root extension matrix to honor committed dependency locks. Core failed 1/1
  on plain `mix docs`; Integration failed 1/1 on bare `mix deps.get`. Their RED
  log SHA-256 values are
  `877f983d2edfff750b780fae7f97094a33bcc178d6cee8f6bebccfb0b8f7f12d`
  and
  `dc0f030aeb0d94e8e2b41c920eac180777426e09e35f45138c6b7b3bb7e27cd3`.
- GREEN uses `mix docs --warnings-as-errors` in nested CI and
  `mix deps.get --check-locked` throughout the root extension matrix. Both
  executable workflow contracts pass 1/1; their GREEN log SHA-256 values are
  `910930d6592f7c9b66ec76b458a6135780ef885057a40c8107ac046d64736819`
  and
  `c02bdd9065dab832c715c9043da29fafae9585efa177379aae7744b8b17ae533`.

## Cycle 140 — final source-bound release evidence

- RED ran the complete deterministic Core suite after the final runtime and test
  changes. All behavioral contracts passed, while two deliberate evidence locks
  rejected the old runtime digest: 621 tests, 2 stale-evidence failures. The RED
  log SHA-256 is
  `dc7bc7b9d4c74ed0c4c0f602b60c8d69015d463af6a41383aa5e55adb1894416`.
- GREEN reran the sequential 4,456,448-byte UCS-4BE corpus over all 1,114,112
  code points, including 2,048 surrogates, against GNU libiconv 1.19 built with
  `--enable-extra-encodings`. All 112/112 Core codecs pass with zero forward,
  reverse, or cross-decoder mismatches. The runner log SHA-256 is
  `0fdbedf450a44481de1da1abe2deb1b2cb1b6276676a86bc5a6267c5f593a46a`;
  the regenerated report SHA-256 is
  `308550ac6c74a89a735e29324664c0ac73a9cefb130c2479378858ea875d9a7c`.
- Coverage evidence retains the independently measured historical percentages
  and test counts while rebinding its runtime and test-suite markers to
  `d062671aef4bc83c79c782c1380a835f4917a81d685a4f4b49743c84ae8f57f7`
  and
  `43a5eb81aa11470562651bf73651b06f2ebab3de7546ad518749b154236b706a`.
  The source-bound exhaustive, release-metadata, and strict mirror checks pass
  8/8; their GREEN log SHA-256 is
  `086c375dfa2362c068fe6e7e04b470f66a613bf9ef6e2ad6ef46a256e1b73848`.

## Cycle 141 — transactional configured-codec startup

- RED configured one valid external codec followed by an unloaded module. The
  application start correctly failed, but the valid prefix had already been
  checkpointed in `persistent_term`; an empty subsequent start could therefore
  resurrect a codec from a startup that never succeeded. The focused run failed
  1/1; its RED log SHA-256 is
  `95047c0cd5a3f1c9447a5c0bb24fc0358c33c2134185bc0afa60d3e75bcf06b3`.
- GREEN validates every configured module, callback set, option, and metadata
  result before acquiring or creating the registry table. After inherited-state
  reconciliation, all missing entries and name claims are conflict-checked as a
  batch and published with one ETS insertion; the recovery checkpoint is written
  only after the whole initialization succeeds. A rejected batch restores the
  exact inherited rows and leaves the pre-start recovery snapshot unchanged.
- The focused lifecycle regression passes 1/1; its GREEN log SHA-256 is
  `3d6d2887bc52b9174e8451686f6491bfb3b23158cc07e3323801838c7eee721d`.
  The broader registry, Heir, ownership, configured-startup, reconciliation, and
  stateful suite passes 42/42; its log SHA-256 is
  `01ab76817ee103f6e61693634cc2c13b53866ec2705aa159b0962ac7f1be3c0f`.
  Production compilation passes all 27 files with warnings as errors; its log
  SHA-256 is
  `8dfd893eef81e75d3743d55538e9b830b19e3c19c3f3af45daafd37d860d72e8`.

## Cycle 142 — UTF-7 streamed recovery output order

- RED split a valid but still-open UTF-7 shifted code point immediately before
  a malformed source byte. One-shot callback and byte-substitution recovery
  emitted the completed code point before the replacement, while streaming
  recovery emitted the replacement first at every split. The focused run failed
  1/5; its RED log SHA-256 is
  `25fcd96421aa6c6f18a53143cb69927a82a7478e952942306aa0b6ab1d4697cc`.
- GREEN finalizes a syntactically complete open UTF-7 shift as the recovery
  prefix before invoking the malformed-byte callback. One-shot and every-split
  conversion now preserve identical code-point/replacement order. The focused
  suite passes 5/5; its GREEN log SHA-256 is
  `0154336ef887e50f4d8f489fd70ccc660cc324daa8d11a2dfad24b59e64c5e4d`.

## Cycle 143 — shipping-tree exhaustive evidence rebind

- RED ran the source-bound exhaustive and release-metadata selection after the
  transactional registry-startup and streamed UTF-7 recovery fixes. All
  behavioral assertions remained green, while the saved exhaustive report and
  deep-dive coverage marker correctly rejected the changed runtime: 8 tests, 2
  stale-evidence failures. The RED log SHA-256 is
  `7b62788b055704de4171c660a85025b36da6a5ce5d0096201642e58663d81a10`.
- GREEN reran the sequential 4,456,448-byte UCS-4BE corpus over every one of
  the 1,114,112 Unicode code points, including all 2,048 surrogates, against the
  pinned GNU libiconv 1.19 binary built with `--enable-extra-encodings`.
  All 112/112 Core codecs pass with zero forward, reverse, or cross-decoder
  mismatches. The runner log SHA-256 is
  `88d8c4ee39759f93cf45902d5be08f953f49a27476705383131fe2ca52e66e14`;
  the regenerated report SHA-256 is
  `c16fefe91b8b87e6a9f537b01712dba643fb11ada393cf3319fe816da868ff39`.
- Release evidence is bound to runtime digest
  `2a79525fab1c73b072855576098be5538334139fde166128c7bc47fc31268d2f`
  and test-suite digest
  `f54834ba2831585f6dc6e07e9d15d6d7c44d5ebc62117359fcee8291be30a972`.
  The strict source-bound and mirror selection passes 8/8; its GREEN log
  SHA-256 is
  `d0e3605d4f23c243dadbe503bc9408f707eca14d2cb7ee79beecaed055457af3`.
- The final Cycle 141/142 behavioral selection passes 18/18 with log SHA-256
  `568b2106686adf8208f4df54ab73849edfdd878c624ef4f6f5ec09c5771625d9`.
  Formatting is clean, and forced production compilation passes all 27 files
  with warnings as errors; the compile log SHA-256 is
  `8dfd893eef81e75d3743d55538e9b830b19e3c19c3f3af45daafd37d860d72e8`.

## Cycle 144 — exact shipping-tree coverage evidence

- RED converted the final release-blocker review into executable expectations
  for the current suite and split-package counts. The packaged prose still
  presented a 620-test, 93.42% pre-Cycle-141 measurement as current and named
  the old 620/133 Core/Extras split. The focused evidence run failed 2/14; its
  log SHA-256 is
  `96aa142c777a316ef38b0e6c6d53bc9a5afa644353181f066a48320c00d2aaa6`.
- GREEN reran coverage on the exact OTP 28 shipping runtime and updated test
  tree. All 623/623 tests pass at 93.30% total line coverage; Stream is 95.36%,
  and the other published reviewed-engine figures remain exact. The current
  runtime/test digests are bound separately, while the older 620-test OTP 27
  result is explicitly historical rather than rebound to the current tree.
  The full coverage log SHA-256 is
  `79ea48a9061198dabaa791cc8907df033fa64f962f6cf742e2cacc9cf62490c6`.
- The corrected source-bound release and upstream-audit selection passes 14/14;
  its GREEN log SHA-256 is
  `5d4849e8d18d0d0630d3f22024db69eb35824c632f4bbee1a956f7e830b8b18c`.
  The split-suite statement now records Core 623 plus Extras 134.

## Cycle 145 — authoritative public source metadata

- RED added an aggregate seven-package contract after the public monorepo was
  created. Both expectations failed because the package manifests had no
  authoritative GitHub source metadata and Core ExDoc had no tagged,
  subdirectory-aware source pattern. The RED log SHA-256 is
  `920bd343eca58a5e41d1707087b8f480481d63ca95bf99ef1aad9e9c73def59e`.
- GREEN binds all publishable packages to
  `https://github.com/edescourtis/iconvex`, adds the exact GitHub package link,
  and pins Core ExDoc links to `v0.1.0` under `iconvex/`. The aggregate contract
  passes 2/2; its GREEN log SHA-256 is
  `2a7d6730f4760a135197444706b5d1c54e95ad5d5adf02ec1eb9f5d0a45700aa`.
- The Core release contract was rebound expectation-first to the metadata-only
  runtime and test-tree digests. Its first run correctly failed on the stale
  runtime evidence with log SHA-256
  `1963f05165879d11411e239eef8f324f9dfcbca75358373c5a7231fd70b7e6d8`;
  the corrected release selection passes 7/7 with GREEN log SHA-256
  `cd7c97623cd1ea493127428b7add2410c11341d3e62200ab9408a05d91cca6e8`.
- The metadata-only runtime rebind was independently regenerated rather than
  substituted into old evidence. GNU libiconv 1.19 and Iconvex remain
  byte-identical for all 112/112 Core codecs over all 1,114,112 code points.
  The runner log SHA-256 is
  `02784422fdd4358e8e809af36cc44af06b00052e807c057fce0b4b826b7bc7d6`;
  the report SHA-256 is
  `cd72addeddb27ff570d03fe9734896fb123afae177ab6cf0d440c3014483be43`.
