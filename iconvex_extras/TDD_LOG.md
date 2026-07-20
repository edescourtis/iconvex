# TDD log

## External multibyte decode-recovery atomicity — RED/GREEN

- RED fixed four public-API reproductions before implementation: DEC-HANYU
  `C2 CB A1` leaked U+6C82 after callback discard and `C2 CB` produced two
  callback replacements; EUC-JISX0213 `8F A1` produced two replacements; and
  ISO-2022-JP-3 `ESC $` produced a replacement followed by a literal dollar.
  The focused contract failed 1/1 while strict decoding and each codec's native
  discard path already reported/removed the complete terminal unit.
- GREEN gives only DEC-HANYU, EUC-JISX0213, and ISO-2022-JP-3 an external
  `decode_error_consumption/2` override that consumes the complete sequence for
  terminal incompleteness while retaining one-byte recovery for other errors.
  For all four reproductions, public discard matches native discard, callbacks
  observe exactly one complete event, replacement occurs once, and byte
  substitution emits one marker for every source byte. Focused contract passes
  1/1 with warnings as errors.

## Fair GNU engine timing and Extras hotspot remediation — RED/GREEN

- TIMING RED changed the permanent contract before the runner: the focused
  suite failed 5/5 because results and reports exposed millisecond fields,
  `write_report!/8` and `gnu_engine_time!/4` did not exist, the C helper was
  absent, and directional gates still divided by a clamped CLI wall time.
- TIMING GREEN adds `tools/gnu_iconv_engine_benchmark.c`. The runner derives
  the GNU prefix from `--iconv`, compiles against its 1.19 header and exact
  library artifact, and binds source, executable, and library SHA-256 values
  into the report. The helper reads its file before timing in-memory
  `iconv(...//IGNORE)` with `CLOCK_MONOTONIC`; the GNU CLI remains the separate
  byte oracle. A fake helper that sleeps 50 ms but reports 123 µs proves the
  runner uses 123 µs, not command wall time. Focused contracts passed 5/5.
- SUB-MICROSECOND RED exposed an honest US-ASCII reverse conversion below the
  clock's integer-microsecond resolution. Its zero placeholder then made a
  failed report row raise division-by-zero; the new regression failed 1/6.
  GREEN calibrates small conversions in repeated isolated batches and reports
  fractional microseconds per conversion, with no denominator clamp. Failed
  rows render unavailable ratios instead of doing arithmetic on placeholders;
  focused contracts passed 6/6.
- REAL-HELPER GREEN compiles with C11 warnings as errors against
  `/opt/homebrew/opt/libiconv`, verifies the linked GNU libiconv runtime is
  1.19, processes the complete EILSEQ-heavy corpus through `US-ASCII//IGNORE`
  and `CP943//IGNORE`, and matches helper output-byte counts to independently
  captured CLI outputs. The permanent test repeats this check when a pinned
  GNU 1.19 installation is present. Focused contracts passed 7/7.
- The first fair four-codec smoke had zero mismatches but six real directional
  breaches: EUC-JISX0213 51.09x/67.41x, CP943 11.39x/40.47x, UTF-8
  34.43x/10.68x, and US-ASCII 39.56x/65.86x. The 30x ceiling was not changed.
- EXTRAS-PATH RED required explicit optimized CP943/EUC-JISX0213 paths before
  implementation; the focused suite failed 1/8 on the missing contract. GREEN
  compares concatenated complete mapping sequences against the generic table
  engine, specializes legal byte shapes, and makes EUC pair lookup conditional
  on the exact 21 possible first code points. A second cache-bound RED failed
  1/8 before the 262,144-byte CP943 and two 524,288-byte EUC dense decode caches
  existed; GREEN binds those exact bounds and preserves table results.
- EXTRAS PERFORMANCE GREEN ran all 1,114,112 code points in both directions and
  both cross-decodes with zero mismatches and zero breaches. EUC-JISX0213 is
  23.14x forward/24.68x reverse; CP943 is 11.25x/23.04x. Core-owned UTF-8 and
  US-ASCII remained separately RED, so the 198-codec regeneration was correctly
  withheld for Core remediation instead of hiding failures or relaxing 30x.

## Directional exhaustive-performance gate — RED/GREEN

- RED added two focused contracts around a synthetic result whose 31.00x
  forward conversion was hidden by a fast reverse conversion, plus the inverse
  case. The aggregate-only runner failed 2/2 because it neither exposed a
  directional breach function nor a separately rendered forward/reverse row.
- GREEN records forward and reverse timings separately, reports both ratios and
  their maximum, and treats each ratio over 30.00x as its own breach. The exact
  boundary remains inclusive: 30.00x passes, while 31.00x fails in either
  direction. Focused contracts pass 2/2 with warnings as errors.
- Every cheap Extras regression outside the digest-bound saved report passed
  107/107 before regeneration. Final GREEN refreshes the source-bound report:
  all 198 codecs are byte-exact over all 1,112,064 Unicode scalars, each
  direction is below 30.00x GNU, and UTF-32 is worst at 26.21x. The complete
  Extras suite now passes 109/109 with warnings as errors.

## Package split — RED/GREEN

- RED: the new core boundary tests failed 2/2 because core exposed 198 codecs
  and contained optional tables.
- GREEN target: this application is the exact 86-codec complement of GNU's 112
  default codecs, owns every optional implementation table, registers through
  the public extension API, and restores the exact core set when stopped.
- GREEN: 86 codec modules, 85 mapping tables, exact 342 additional aliases,
  lifecycle 112 -> 198 -> 112 -> 198, and no optional table duplicated in core.
- Fixture GREEN: all 85 applicable GNU charmap/inverse cases, ISO-2022-JP-3 exact
  snippet round-trip, IBM-1047 surfaces/policies, and a 250,000-byte invalid-run
  discard regression pass.
- Suite GREEN: 94 tests, 0 failures; warnings-as-errors passes.
- Differential GREEN: fresh combined run matched GNU libiconv 1.19 for 198/198
  codecs over all 1,112,064 Unicode scalars, with zero forward, reverse, or
  cross-decode mismatches.
- Benchmark GREEN: paired byte-identical CP932/CP943 conversion measured 1.6%
  decode and 0.6% encode overhead for package dispatch on OTP 28.

## Bound combined artifact and performance ceiling — RED/GREEN

- RED: the 198-codec report proved parity but did not bind itself to core/extras
  runtime sources or its runner. A new ordinary test failed against the stale report.
- GREEN freshness: report now hashes both packages' runtime sources/tables plus the
  runner. Any implementation or harness change invalidates the saved evidence.
- Performance RED: 31 codecs exceeded the requested 30x GNU ceiling; worst was
  ISO-2022-JP-3 at 279.1x.
- Performance GREEN: the regenerated report covers all 1,112,064 scalars for all
  198 codecs, has zero mismatches and zero slowdown failures, and records a worst
  slowdown of 26.84x. Wall time fell from 261,695 ms to 43,849 ms.
- Suite GREEN: 95 tests, 0 failures; warnings-as-errors passes.

## ISO-2022-JP-3 Stream state — RED/GREEN

- RED: the every-split source/target contract failed 1 of 4 focused tests because
  the external codec exposed no incremental state callbacks.
- GREEN: explicit decoder and encoder state now preserves designations and
  two-codepoint lookahead across every source-byte and UTF-8 split; 4/4 focused
  tests pass with output identical to one-shot conversion.

## Registry-worker recovery — RED/GREEN

- RED: killing `Iconvex.ExternalRegistry` while `:iconvex_extras` remained
  started changed `IBM-1047` from a registered codec to `:error`; application
  state still held cleanup tokens for registrations that no longer existed.
- GREEN: the inherited registry table preserves all 86 Extras entries and
  their exact tokens. The recovery test then stops Extras and proves those same
  tokens remove only the package-owned entries, restoring the 112-codec core.
- The first complete focused run also exposed an unloaded trace target in the
  performance contract. Loading `Iconvex.TableCodec` explicitly made the test
  independent of execution order; `package_test.exs` passes 10/10.

## Partial-startup rollback — RED/GREEN

- RED (rollback mutation): with codec cleanup removed, the deterministic
  conflict at the 86th/final registration left `ATARIST` and the other 84
  earlier codecs registered; the new regression failed on the first survivor.
- GREEN: the existing rollback removes all 85 earlier codec modules and every
  canonical/alias index plus the newly owned EUC-JISX0213 provider and token.
  The caller-owned `TDS565` conflict keeps its exact ownership token, and after
  removing it the application restarts with all 86 Extras codecs (198 total).
- Focused regression: 1 test, 0 failures; production behavior required no edit.

## Consumer artifact hygiene — RED/GREEN

- RED: the release audit found 111 `test`, `bench`, and `tools` entries in the
  checked-in Extras archive. The package contract reproduced the manifest leak
  before changing `mix.exs`.
- GREEN: the Hex manifest retains runtime code, tables, licenses, inventories,
  conformance evidence, and public documentation while excluding all three
  development-only trees. Tests and benchmarks remain in the repository.

## Final benchmark-narrative binding — RED/GREEN

- RED: the final review found that core benchmark prose still quoted the prior
  combined differential's 43,458 ms and 25.88x values. A cross-package artifact
  contract derived the wall time and maximum slowdown from the current report
  and failed against the stale narrative.
- GREEN: the narrative now records the digest-bound final run's 50,803 ms and
  UTF-32 24.33x maximum. The permanent test parses both documents, so any later
  report regeneration must update the public benchmark summary too. A final
  mutation review showed that changing only `198/198` to `197/198` survived the
  original time/slowdown contract; the expanded binding now also derives codec
  totals, mismatches, and performance-failure counts from the report. A second
  `30.00x` to `29.00x` mutation survived until the contract also bound the
  report's performance ceiling to the public prose.

## Managed package coexistence and refreshed differential — RED/GREEN

- RED: loading Extras before Telecom and Specs failed on Specs' retained
  `IBM037` claim; the reverse order failed on `CP1124`. The complete overlap
  audit found exactly 231 normalized names: 25 Specs-canonical/Extras-alias,
  63 Specs-alias/Extras-canonical, and 143 alias/alias.
- GREEN: the application publishes its 86 registrations as one managed set at
  priority 100. All six extension start orders produce the same 1,990-codec
  registry. Canonical claims beat aliases; Extras wins equal-kind GNU names,
  producing 206 Extras and 25 Specs winners while both packages are running.
  Set removal exposes every retained Specs claim without a lookup gap.
- The final digest-bound GNU libiconv 1.19 differential passes 198/198 codecs
  over all 1,112,064 Unicode scalars with zero mismatches and zero performance
  failures. It records 44,522 ms total measured wall time, a 30.00x ceiling,
  and a worst slowdown of 25.08x for UCS-4.

## Direct UTF-8 miss containment — RED/GREEN

- RED called the optional `encode_from_utf8/1` callbacks for EUC-JISX0213 and
  SHIFT_JISX0213 directly. A representable `"Aあ"` sample returned the internal
  `:miss` dispatch sentinel instead of the same `{:ok, bytes}` result as
  `encode/1`; the focused test failed on EUC-JISX0213.
- GREEN contains `:miss` inside shared codec support and performs the same
  Unicode-list table encoding used by the required callback. It preserves
  formal unrepresentable-character errors and reports exact source offsets and
  tails for invalid and incomplete UTF-8. Both direct callbacks now expose only
  public callback results.
- The focused callback contract passes 1/1; the table, package, and callback
  matrix passes 99/99. A fresh source-bound differential passes 198/198 codecs
  over all 1,112,064 Unicode scalars with zero mismatches and zero performance
  failures; measured wall time is 45,423 ms and worst slowdown is 25.92x for
  UTF-32 under the unchanged 30.00x ceiling. The complete Extras suite passes
  106/106.

## Release-cardinality document contract — RED/GREEN

- RED added the executable documentation contract before changing prose; the
  package test failed 1/13 on the stale 1,745 Specs and 1,995 full-stack counts.
- GREEN updates current release prose to the derived 1,755 Specs and 2,005
  full-stack cardinalities. The package contract passes 13/13 and the complete
  suite passes 107/107 with warnings as errors.

## Post-registry combined-evidence rebinding — RED/GREEN

- RED reran the permanent combined artifact contract after Core relinquished
  its incorrect ISO-IR-180 alias. One of two tests failed because the report's
  combined runtime digest still described the prior Core tree.
- GREEN reran GNU libiconv 1.19 against all 1,112,064 Unicode scalars for all
  198 Core-plus-Extras codecs. The new source-bound report records 198/198
  byte-exact codecs, zero mismatches, zero performance failures, 71,782 ms
  measured wall time, and a worst slowdown of 25.15x for UCS-4 under the 30.00x
  ceiling.
- The narrative-binding test then supplied the second RED against its stale
  derived figures. After refreshing those figures, both artifact contracts
  pass 2/2 with warnings as errors.

## Direct-fast-path closure evidence rebinding — RED/GREEN

- RED reran the permanent combined artifact contract after Core corrected
  strict stream error precedence for direct external encoders. The report's
  combined runtime digest no longer matched the executable tree. A fresh GNU
  libiconv 1.19 run then exercised every one of the 1,112,064 Unicode scalars
  across all 198 comparable codecs.
- GREEN records 198/198 byte-exact codecs, zero mismatches, and zero performance
  failures in 65,105 ms. The worst measured slowdown is UTF-32 at 24.63x under
  the enforced 30.00x ceiling. The narrative contract supplied a second RED
  against the previous 71,782 ms/UCS-4 snapshot; current prose now derives
  exactly from the fresh report. The complete Extras suite passes 107/107 with
  warnings as errors.

## Review-remediation evidence rebinding — RED/GREEN

- RED reran the permanent combined artifact contract after the reviewed Core
  stream, registry, table-cache, and UTF-7 fixes. One of two focused tests
  failed because the report's combined runtime digest still bound the previous
  executable tree (`22c96b…` instead of `7240d8…`).
- GREEN used the locally built GNU libiconv 1.19 reference with
  `--enable-extra-encodings` and regenerated the complete differential. Every
  one of 1,112,064 Unicode scalars passed forward, own-round-trip, and both
  cross-decode comparisons for 198/198 codecs with zero mismatches.
- The source-bound run records zero performance failures in 52,071 ms. UTF-32
  is the worst measured codec at 25.90x GNU, below the enforced 30.00x ceiling.
- Both evidence contracts pass 2/2, and the final warning-clean Extras suite
  passes 107/107.

## Final general-review evidence rebinding — RED/GREEN

- RED reran both permanent differential contracts after Core corrected
  GB18030 malformed diagnostic frames. The saved combined runtime digest still
  described the prior executable tree.
- GREEN rebuilt GNU libiconv 1.19 with `--enable-extra-encodings` and exercised
  every one of 1,112,064 Unicode scalars across all 198 Core-plus-Extras codecs.
  Forward bytes, both own round trips, and both cross-decodes are byte-exact;
  mismatches and performance failures remain zero.
- The source-bound run records runtime digest
  `8dd41323465b4672d2fde08221835d268351bb57aecb4336be88885c29742c52`,
  43,704 ms wall time, and a 26.32x worst slowdown for UCS-4 under the enforced
  30.00x ceiling. Both evidence contracts and the complete 107-test package
  suite pass with warnings as errors.

## Every-code-point differential and repeatable performance gate — RED/GREEN

- RED changed the artifact contract before creating the replacement corpus;
  one of two focused tests failed on the missing file. GREEN checks every
  sequential UCS-4BE word from U+0000 through U+10FFFF: 1,114,112 code points,
  comprising 1,112,064 scalar values and all 2,048 non-scalar surrogate code
  points. The 4,456,448-byte corpus has SHA-256
  `087f212baaa35562a226c5834e723620bb7d9f4103b76f9c7cbdaaff2d6cd67c`.
- TIMING RED failed 1/3 because the one-sample runner could report periodic GC
  spikes as codec regressions. GREEN takes three isolated samples in each
  direction and gates their fastest values independently; all work remains in
  total wall time. The bounded ASCII/JAVA/UTF-7 probe passes 3/3.
- The first repeatable full run made 11 genuine Unicode/JAVA directional
  breaches visible. Core RED/GREEN removed million-element intermediate lists
  across explicit/generic UCS-4, UTF-16, UTF-32, and JAVA, while preserving BOM,
  endian-switch, invalid-value, trailing-byte, and callback contracts. The
  former 29.57x UTF-32 reverse margin is now 1.80x.
- Final source-bound GREEN compares forward bytes, both own round trips, and
  both cross-decodes with GNU libiconv 1.19 built using
  `--enable-extra-encodings`. All 198/198 codecs match over all 1,114,112 code
  points, with zero mismatches and zero performance failures. Total wall time
  is 276,041 ms; EUC-JISX0213 is worst at 29.45x, below the 30.00x ceiling.

## Regenerated release cardinalities — RED/GREEN

- RED changed the package contract before release prose. The complete
  110-test Extras suite passed 109 tests and failed only because README still
  claimed 1,812 Specs codecs instead of 1,848.
- GREEN updates README and changelog to 1,848 Specs codecs and 2,100 unique
  full-stack canonical names. The focused package contract passes 13/13 with
  warnings as errors.

## Required external substitution callback recurrence — RED/GREEN

- RED reproduced a single failure in the final-codec rollback test because its
  test-only conflict codec still implemented the former external callback set.
- GREEN delegates `encode_substitute/2` to the real TDS565 implementation,
  retaining the exact startup-conflict scenario while satisfying Core's new
  linear substitution contract. The focused lifecycle regression passes 1/1
  with warnings as errors.

## Provenance-quarantine release cardinalities — RED/GREEN

- RED changed the executable package contract before release prose. The
  focused package run failed exactly 1/13 because README and changelog still
  claimed 1,848 Specs codecs and a 2,100-codec full stack.
- GREEN states the quarantined inventory precisely: 1,841 runtime Specs codecs
  and 2,093 unique full-stack canonical names. The focused package contract
  passes 13/13 with warnings as errors; historical evidence entries retain the
  cardinalities they recorded at the time.

## Direct EUC-JISX0213 UCS-4 decoding — RED/GREEN

- RED traced the explicit UCS-4 discard route and failed 1/1 because it decoded
  EUC-JISX0213 to UTF-8 before performing a second Unicode conversion. The
  complete quiet-host differential had exposed the reverse direction at
  32.53x GNU, above the immutable 30.00x ceiling.
- GREEN writes cached dense double- and triple-byte results directly in the
  requested UCS-4 byte order, with exact staged parity and no UTF-8 callback.
  The focused direct/cache selection passes warning-clean. The full Unicode
  corpus remains byte-identical to GNU libiconv 1.19, while quiet-host reverse
  timing fell to 11.25x GNU.

## Provably unmapped JISX0213 range skipping — RED/GREEN

- RED encoded 50,000 UCS-4 words from a range absent from both generated
  JISX0213 maps. Although the result was correctly empty, the route consumed
  400,058 reductions and failed the under-300,000 mechanism budget.
- GREEN skips eight consecutive provably unmapped words per recursion in both
  byte orders. A permanent contract verifies that neither singleton nor
  sequence mappings begin in any skipped range, so the optimization remains
  tied to the executable tables. The focused JIS/cache selection passes 9/9.
- On the isolated GNU host, SHIFT_JISX0213 is byte-exact at 2.49x forward and
  4.78x reverse; EUC-JISX0213 is byte-exact at 2.75x forward and 17.0x reverse,
  all beneath the unchanged 30.00x ceiling.

## Final all-code-point evidence rebinding — RED/GREEN

- RED copied the fresh source-bound differential before updating Core's
  derived benchmark prose. The evidence/digest assertion passed, and the
  narrative assertion failed 1/2 on the prior 276,041 ms and 29.45x values.
- GREEN records all 1,114,112 code points, including 2,048 surrogate values,
  through all 198 GNU-compatible Core-plus-Extras codecs. Forward bytes, both
  own round trips, and both cross-decodes are exact; mismatches and performance
  failures are zero.
- Two consecutive quiet-host runs pass the independent 30.00x directional
  ceiling. The checked-in run took 48,428 ms and is worst at EUC-JP 28.46x.
  Its runtime, runner, helper source/executable, GNU header/library, and host
  metadata hashes are bound by the normal 2/2 artifact/narrative contract.

## O(1) ISO-2022-JP-3 cache identity recurrence — RED/GREEN

- RED ran the unmodified 132-test suite after Core removed its test-only JP
  table warmer and replaced map equality with generation references. Exactly
  three cache contracts failed: one called the removed helper and two expected
  the complete EUC-JISX0213 map in the dense-cache descriptor. The fourth
  failure was the deliberately withheld, source-digest-bound differential
  report that must be regenerated after the complete review fix set.
- GREEN drives actual ISO-2022-JP-3 conversions for cold start, provider
  restart, and stale-cache rebuilding. The stale case installs two
  structurally valid 8,836-entry planes with a matching integrity witness but
  a distinct generation reference; conversion replaces them and the tests pin
  the cache and integrity records to the exact O(1) identity returned by the
  active table provider. No production warmer was restored.
- OTP 28 focused tests pass 3/3 with warnings as errors. All 130 ordinary tests
  outside the digest-bound artifact file pass, as does its independent 1/1
  benchmark-narrative test. OTP 27 repeats the same 3/3, 130/130, and 1/1
  results. Differential-report regeneration remains intentionally delegated to
  the final combined evidence run.

## Final frozen-source exhaustive and performance evidence — RED/GREEN

- RED retained the last runtime-bound report after the Core cache and decoder
  fixes. The package suite failed its stale source digest and failed-performance
  narrative; a new release-document binding contract separately failed 2/3 on
  the prior EUC-JISX0213, CP943, and Core worst-case measurements.
- GREEN reran every one of the 1,114,112 UCS-4 code-point words, including all
  2,048 surrogate values, through all 198 GNU-compatible Core-plus-Extras
  codecs against GNU libiconv 1.19 built with
  `--enable-extra-encodings`. Forward bytes, both own round trips, and both
  cross-decodes match exactly for all 198 codecs; mismatches and performance
  failures are zero. The checked-in run took 49,339 milliseconds and its
  report SHA-256 is
  `1b6f9a980ea3e4064f129861aaa2e7426672d5d0fc53a0b3a44a5ec044c167ee`.
- The immutable directional limit remains 30.00x. TDS565 is worst at 27.55x;
  EUC-JP is 5.52x forward and 10.27x reverse, while TCVN is 6.64x forward and
  11.00x reverse. Two full runs passed at 27.68x and 27.55x; one byte-exact run
  honestly retains a 32.43x IBM-1165 reverse failure. Seven isolated reruns
  each of IBM-1165 and TDS565 produced 0/28 directional breaches without
  changing the gate. The package passes 133/133, and the focused
  evidence-binding contract passes 3/3.

## Post-ISO-2022-KR exhaustive evidence refresh — RED/GREEN

- RED reran the complete 198-codec byte oracle after Core's ISO-2022-KR
  optimization. All codecs remained byte-exact, but two reverse measurements
  exceeded the unchanged 30.00x ceiling: IBM-1148 at 103.89x and ISO-8859-16
  at 42.75x. The failed report is retained at SHA-256
  `0d3a209d8f5f60b7496c750d886373353d2c46327dae889b78e887b6603f55c4`.
- Focused reruns immediately put both outliers below 10x without a code or gate
  change. The second full run passes 198/198 with zero byte/cross-decoder
  mismatches and zero performance failures in 62,807 ms. C99 is worst at
  23.68x; ISO-2022-KR reverse is 3.27x. The checked-in report SHA-256 is
  `880f310185d8f1b6b9a249e43a5ef3d30b52f882d9a0f91dc66b64cec02fdd99`.
- The existing 133-test suite then provided the documentation RED: 2 failures
  bound the prior wall time and EUC-JISX0213/CP943 measurements. GREEN records
  the current report values in README and BENCHMARKS while leaving the failed
  run auditable.

## Cycle 54 — release-candidate combined evidence rebinding — RED/GREEN

- RED ran the complete 134-test Extras gate after the final Core changes. Its
  only failure was the deliberately source-bound combined runtime digest: the
  saved report contained `e24df01c7fa8678743277ab9ca8bf6452fa1a468905931364c3870a7faff659e`
  while the current Core-plus-Extras runtime required
  `fc82147ed493c3c2beb0cc68e7f7c2bd0f3ca756be7bee17ab542c6266961976`.
- GREEN regenerated the complete corpus against GNU libiconv 1.19 built with
  `--enable-extra-encodings`. All 198/198 codecs pass over all 1,114,112 code
  points, including 2,048 surrogates, with zero byte/cross-decode mismatches
  and zero directional breaches of the unchanged 30.00x ceiling. The run took
  69,611 ms; C99 is worst at 25.20x. Report SHA-256 is
  `535f263c9a04a6d0b75f023a81c4548acf0f746d2dc38e962bd39f0b3b74c3ae`.
- DOCUMENTATION RED passed the newly rebound artifact assertion and failed 2/3
  because the previous wall-time, hotspot, and worst-case measurements remained
  in Core and Extras narratives. GREEN updates only report-derived values and
  required Core documentation mirrors. The focused artifact, narrative, and
  performance contracts pass 20/20.

## Cycle 55 — frozen Core-plus-Extras shipping evidence — RED/GREEN

- RED ran the permanent combined artifact and narrative contract against the
  final Core runtime. Two narrative tests remained green, while the artifact
  correctly rejected the saved combined runtime digest
  `fc82147ed493c3c2beb0cc68e7f7c2bd0f3ca756be7bee17ab542c6266961976`
  in favor of
  `c120d7985e170b479529949458a38fb7ca3b8f8387933f61c09fd9e47f8cfd00`:
  3 tests, 1 stale-evidence failure. The RED log SHA-256 is
  `32c65c8e287512ead7af110847d122e3eb49fa7ecc5d2bc2f7f635fe2e9f6719`.
- GREEN reran all 1,114,112 UCS-4BE code points, including the 2,048
  surrogates, through every one of the 198 GNU-compatible Core-plus-Extras
  codecs against GNU libiconv 1.19 built with `--enable-extra-encodings`.
  Forward bytes, both own round trips, and both cross-decodes are byte-exact;
  mismatches and directional breaches of the unchanged 30.00x ceiling are
  zero. The run took 65,926 ms and CP1129 reverse is worst at 27.54x. The
  runner log SHA-256 is
  `2db67392877f1fd6dbb17b1e0c5b685660e7d7003725b3accd41b699cba725c0`;
  the regenerated report SHA-256 is
  `a0e7be92c1aba86563d6f36637b1799d91a6efbac91106469c598879f513a60a`.
- The exact EUC-JISX0213 and CP943 rows, combined wall time, and worst-case
  result are rebound in Extras and Core release narratives and required Core
  mirrors. The focused artifact/narrative contract passes 3/3; its GREEN log
  SHA-256 is
  `722ba2528cc987c362e8d1657a233734ea79c8a361d0d3affd56b90c40a38a35`.
  Formatting is clean, and forced production compilation passes all four
  Extras files with warnings as errors; the compile log SHA-256 is
  `cff50afae4575de0ac18fcc82f22cdb3bfa1ce46aa61b5be48fd56b8eef1af95`.

## Cycle 56 — public-source metadata evidence rebind — RED/GREEN

- GREEN first reran the complete combined differential after Core and Extras
  gained authoritative public-repository metadata. All 198/198 codecs remain
  byte-exact against GNU libiconv 1.19 over all 1,114,112 code points, with
  zero mismatches and zero breaches of the unchanged 30.00x ceiling. CP943 is
  worst at 23.12x. The runner log SHA-256 is
  `75b656a1f1c1e6b1011ef199e87cfcb1b7164a3100809118f68f8f1d834b3b3e`;
  the report SHA-256 is
  `7ddb4aabccfaa3d3c1fc14ae57cfb2577257168260c9005abfe93a955a293d89`.
- DOCUMENTATION RED then rejected the prior 65,926 ms wall time and prior
  EUC-JISX0213/CP943 narrative measurements: 3 tests, 2 failures. Its log
  SHA-256 is
  `a6a3519c7882f853255a58920b45a424591e51fbbf159aa9e2651b9175c61ca5`.
- GREEN binds Core and Extras narratives to the regenerated 104,191 ms report,
  including EUC-JISX0213 at 2.63x/17.21x and CP943 at 3.70x/23.12x. The focused
  evidence/narrative contract passes 3/3; its log SHA-256 is
  `ba3d17f8bdc8d02fbdbc388f3ce47f755a75343eb1613f6b5962656a082855dc`.
