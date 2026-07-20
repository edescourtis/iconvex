# Deep-dive remediation

This is the disposition for every finding in the supplied
`iconvex-deep-dive.md` review. The review described the pre-remediation state;
tests below are executable evidence for the current implementation.

The source review was re-read in full again on 2026-07-19 and has SHA-256
`573dad285c9911470e9b3600bd587eebca440ece6d817916e411fb389dfa1522`.
The re-audit first exposed a coverage RED (the ISO-2022-JP engine at 88.00%), then
added missing G2, JP-MS shift, kana-error, truncation, and extension-control
branches. Later independent reviews found additional unexercised state,
recovery, GNU fallback, and ISO-2022-JP-2 language-tag paths. The current clean
Core full coverage run on OTP 28 is 623 tests, zero failures, and 93.30% total
line coverage. The latest independent Dell OTP 27 coverage measurement predates
Cycles 141/142 and passed 620 tests with zero failures and 91.53% total line
coverage. It is retained as historical cross-runtime evidence, not rebound to
the current tree. Both measurements exceed the enforced 90% total gate.
Reviewed-engine line coverage is:

- OTP 28: Stream 95.36%, Unicode 96.90%, UTF-7 94.49%, Escape 96.18%, Tables
  94.77%, ISO-2022-JP 96.34%, Stateful 98.92%, TableCodec 92.65%, and
  ISO-2022-CN 99.49%.
- Historical OTP 27: Stream 93.72%, Unicode 96.90%, UTF-7 94.49%, Escape
  96.18%, Tables
  94.77%, ISO-2022-JP 91.55%, Stateful 91.08%, TableCodec 90.63%, and
  ISO-2022-CN 90.40%.

Coverage runtime artifact SHA-256: `83cfa289a9073de3ade15a464ef326a617ac4c7db3c7d8b3c534059b141369a5`.
Coverage test-suite SHA-256: `bd45ccbb81a9ee4f8a54a6ff44e43bc3f6bf8034aeda72589aa12a53da02f356`.
Normal release tests recompute both sorted-tree digests, so changing production
code, packed tables, or any executable test/fixture invalidates these saved
coverage claims.

Package scope is explicit because the supplied review predated the completed
split. Core provides 112 codecs, Extras provides 86, Telecom provides 54, and
Specs provides 1,841 runtime codecs and 1,843 catalog identities. The 1,050
archive codecs are included in the Specs runtime count, rather than added to it
a second time. The combined registry therefore exposes 2,093 unique canonical
names.

The saved exhaustive differential materializes all 1,114,112 code points from
U+0000 through U+10FFFF as sequential UCS-4BE, including all 2,048 surrogate
code points. It compares GNU libiconv and native Iconvex in both directions for
112/112 core codecs and records zero byte, reverse, or cross-decoder
mismatches. Its corpus, report, runner, and runtime SHA-256 values are verified
by the normal test suite so a source or fixture change cannot silently retain a
stale result.

| Review finding | Disposition | Executable evidence |
|---|---|---|
| Stateful discard/substitution restarted decoder state | Native and registered-callback recovery retains HZ, ISO-2022-JP/KR/CN, and UTF-7 modes/designations instead of restarting a desynchronized suffix | `deep_dive_regression_test.exs`, `state_machine_policy_matrix_test.exs`, `stateful_callback_recovery_test.exs`, `utf7_test.exs` |
| Buffered streaming consumed incomplete sequences under policies | `new/3`, `feed/2`, and `finish/1` form a buffered compatibility transaction: feeds retain the exact source and finalization performs one conversion | `options_and_streaming_test.exs`, `deep_dive_regression_test.exs` |
| True incremental conversion was not distinguished from buffered conversion | `stream/4` is the genuinely incremental API; it emits before source EOF, keeps bounded pending state, preserves stateful recovery across chunks, and finalizes once | `options_and_streaming_test.exs`, `review_rigor_stream_recovery_test.exs`, `stateful_callback_recovery_test.exs` |
| Destination multi-codepoint lookahead was lost | Buffered finalization uses the same longest-match encoder as one-shot conversion | BIG5-HKSCS `ê` + combining-caron regression in `options_and_streaming_test.exs` |
| CP1258/TCVN source composition was split | Source bytes remain contiguous until buffered finalization; incremental decoders retain the required pending composition state | CP1258 and TCVN composition regressions in `options_and_streaming_test.exs` |
| UTF-16/32 emitted repeated BOMs | Each destination encoder initializes and finalizes once, so exactly one BOM is emitted | generic UTF destination regressions in `options_and_streaming_test.exs` |
| `finished?` was unreachable | `finish_with_state/1` returns a terminal converter rejected by later feed/finalize calls | lifecycle regression in `deep_dive_regression_test.exs` |
| Options/suffixes were unchecked or raised incidental exceptions | Keys, duplicates, values, formats, widths, and suffixes have typed request errors | validation regressions in `release_coverage_matrix_test.exs` |
| Registry mutation changed existing converters | `new/3` pins immutable resolved entries, and a lazy stream pins its resolved callbacks before enumeration | stable external-codec regressions in `deep_dive_regression_test.exs` and `external_optional_hot_reload_test.exs` |
| Error offsets were chunk-local | Buffered finalization sees the complete source; `stream/4` carries an absolute `source_offset` and translates callback-relative positions into absolute stream offsets | offset regressions in `options_and_streaming_test.exs`, `callback_first_error_ordering_test.exs`, and `stateful_callback_recovery_test.exs` |
| Persistent caches survived upgrades and raced on cold use | Cache values are versioned; first load is serialized; ETF decoding is safe on a cold VM | `cache_lifecycle_test.exs`, `table_codec_cache_concurrency_test.exs` |
| Mapping assets used unrestricted ETF decoding | Core runtime assets use `binary_to_term(..., [:safe])` after finite schema-atom interning, including mixed-EBCDIC mode/schema atoms; the seven-package artifact audit also clean-loads and byte-binds every shipped table, including all 1,050 archive codecs | `cache_lifecycle_test.exs`, `../iconvex_integration/tools/artifact_audit.exs` |
| Substitution width was unbounded | Widths above 65,536 and malformed formats return typed request errors before allocation | validation regressions in `release_coverage_matrix_test.exs` |
| Full conversion can amplify memory | Buffered/full-list semantics and required application input limits are explicit; incremental `stream/4` keeps only codec state, pending suffixes, and the current output | README operational boundaries and bounded-state tests in `options_and_streaming_test.exs` |
| Lazy mapping footprint was undocumented | The supplied review recorded 62.9 MiB for a flat all-core-table materialization; README preserves that planning figure and documents package split/lazy loading. This is documentary evidence rather than a newly reproduced measurement | README operational boundaries |
| External callbacks are a trusted-code boundary | Callback trust, exception propagation, dependency isolation, return validation, state recovery, and optional incremental callbacks are explicit | `EXTENDING.md`, `external_codec_test.exs`, `stateful_callback_recovery_test.exs` |
| Coverage failed the 90% gate | Behavioral branch/state matrices keep the enforced gate green; current total line coverage is 93.30% on OTP 28; the historical OTP 27 measurement was 91.53%. Every listed decoder/stream engine remains above 90% in both measurements | `mix test --cover`, `coverage_gate_state_machine_test.exs`, `iso2022_variant_branch_test.exs`, `iso2022_jp2_language_tag_test.exs`, `release_coverage_matrix_test.exs`, `coverage_gap_iso_unicode_stream_test.exs`, `stateful_utf7_registry_coverage_test.exs`, `table_cache_boundary_contract_test.exs` |
| Saved GNU differential could become stale or sample only valid scalars | Report embeds corpus, runtime, and runner SHA-256 values; normal tests recompute them and assert the full 1,114,112-code-point domain, including 2,048 surrogates and 112/112 core codecs | `exhaustive_unicode_differential_test.exs`, `EXHAUSTIVE_UNICODE_DIFFERENTIAL.md` |
| Public specs/docs and ExDoc were absent | Public APIs now have docs/specs; strict `mix docs --warnings-as-errors` passes. `source_url` is bound to the public `edescourtis/iconvex` monorepo, and tagged ExDoc links include the `iconvex/` package subdirectory | `release_metadata_test.exs`, release check |
| Hex artifact was unnecessarily heavy | Consumer artifact excludes test/research/bench corpora while the repository retains all fixtures | `mix hex.build --unpack` |
| No clean-package/compatibility release check | Three Elixir/OTP CI pairs plus unpacked-artifact consumer smoke test | `.github/workflows/ci.yml`, `tools/release_check.exs` |
| Stateful/escape conversion was far slower than GNU | One-lookup precedence maps, direct nibble conversion, Unicode BIF fast paths, table-codec binary accumulators, and the direct ISO-2022-KR dense-table decoder retain exact fallbacks; the combined exhaustive gate enforces at most 30x GNU and records a 23.12x worst case (CP943) | combined Extras `EXHAUSTIVE_UNICODE_DIFFERENTIAL.md`, `performance_fast_path_test.exs`, `stateful_direct_ucs4_performance_test.exs`, `iso2022_kr_reverse_performance_test.exs` |

Additional RED/GREEN work found two issues not called out by the review: cold
safe-ETF loading needed explicit schema-atom interning, and Unicode malformed
policies needed to retain BOM-selected endianness. Both now have regressions.
