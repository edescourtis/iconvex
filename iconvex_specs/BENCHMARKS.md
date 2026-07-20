# Benchmarks

Run `mix run bench/rfc1345_bench.exs` with `ICONVEX_PATH` pointing at the core
checkout. Results are intentionally generated on the target VM rather than
claimed across BEAM/OTP and CPU versions.

Reference run (Apple M1 arm64, Elixir 1.19.5, OTP 28):

| Operation | Throughput |
|---|---:|
| EBCDIC-US decode, 768-byte input | 14,880 ops/s |
| T.61 decode, 512-byte input | 15,440 ops/s |

Tables are cached in `persistent_term`; the timed loop excludes first-load and
warm-up work.

The final research-closure benchmarks cover
`CTAN-LY1-TEXNANSI-1.1-AGL-4036A9CA`,
`ADOBE-POSTSCRIPT-3-ISOLATIN1-AGL-4036A9CA`,
`TAMILVU-TACE16-APPENDIX-D-2010-16BE`,
`TAMILVU-TACE16-APPENDIX-D-2010-16LE`,
`WANG-1983-WISCII-PDF-F4043449-WIKIPEDIA-REV1352856854`,
`WIKIPEDIA-REV1354794598-PARATYPE-WINDOWS-POLYTONIC-GREEK`, and
`WIKIPEDIA-REV1340817319-EKI-SAMI-WIN-CP1270`. All 21 native/reference
scheduler-reduction gates pass: the secondary single-byte worst ratio is
0.740x, the glyph/TACE reference-run range is 0.534x–0.752x, and doubled-work
scaling is 1.857x–1.970x.

The glyph/TACE executable uses schema
`iconvex-glyph-vector-tace-benchmark` version 2. Every decode, encode, and
round-trip row reports both `native_to_reference_reductions` and the independently
measured `native_to_reference_elapsed` median. It gates all 12 elapsed-time
ratios at `<=30x` in addition to the 12 reduction gates. A quick 32,768-byte
2026-07-18 verification passed 12/12 elapsed gates at 0.307x–2.145x, 12/12
reduction gates at 0.501x–0.757x, and all four scaling gates at 1.812x–1.968x.

Run `mix run bench/algorithmic_bench.exs` for BOCU-1, CESU-8, IMAP UTF-7,
Java Modified UTF-8, and SCSU encode/decode throughput. It warms every path and
uses the same multilingual input for comparable scalar and byte counts.

Reference run on the same Apple M1 / Elixir 1.19.5 / OTP 28 host:

| Codec | Encode ops/s (1,792 scalars) | Decode ops/s | Encoded bytes |
|---|---:|---:|---:|
| BOCU-1 | 7,288 | 4,576 | 2,368 |
| CESU-8 | 5,166 | 5,181 | 3,776 |
| UTF-7-IMAP | 4,185 | 2,036 | 4,544 |
| JAVA-MODIFIED-UTF-8 | 9,009 | 8,699 | 3,776 |
| SCSU | 3,900 | 4,766 | 2,307 |
| UTF-EBCDIC | 2,475 | 2,361 | 3,840 |

## Punycode

Run `ICONVEX_PATH=../iconvex ICONVEX_ARCHIVE_PATH=.. MIX_ENV=prod mix run
bench/punycode_benchmark.exs`. The script executes the pinned CPython 3.14.6
module directly, first asserts byte-identical encoder output, takes the median
of seven warmed samples, and fails if any native operation exceeds the 30x
slowdown ceiling. Apple M1 arm64 / Elixir 1.19.5 / OTP 28 / Python 3.12.3
interpreter executing the pinned CPython 3.14.6 codec module:

| Workload | Operation | Scalars | Bytes | Native | CPython oracle | Ratio |
|---|---|---:|---:|---:|---:|---:|
| mixed multilingual | encode | 336 | 420 | 134.921 µs/op | 1,100.989 µs/op | 0.12x |
| mixed multilingual | decode | 336 | 420 | 172.222 µs/op | 267.729 µs/op | 0.64x |
| unique non-ASCII | encode | 192 | 361 | 118.545 µs/op | 6,301.934 µs/op | 0.02x |
| unique non-ASCII | decode | 192 | 361 | 31.361 µs/op | 327.880 µs/op | 0.10x |

The same executable benchmark doubles ordered and alternating 1,000-scalar
inputs and applies a hard `<3x` scheduler-reduction gate to both encode and
decode. Measured reduction ratios were 2.081x--2.324x (wall-clock ratios are
reported but are observational). The encoder uses a monotonic fast path and a
stable merge-ranking path for arbitrary order. The decoder uses an append fast
path and reconstructs arbitrary insertions with an order-statistic free-slot
tree. Generalized-integer arithmetic is bounded to the largest delta that can
still yield a Unicode scalar, avoiding adversarial big-integer growth while
retaining exact malformed offsets.

## UTF-5 draft profile

<!-- utf5-benchmark:start -->

Run `ICONVEX_PATH=../iconvex ICONVEX_ARCHIVE_PATH=.. MIX_ENV=test mix run
--no-compile bench/utf5_benchmark.exs --quick`. The harness checks four corpora
against an independent direct transcription of `draft-jseng-utf5-01`, then
gates native/reference latency and doubled-input scheduler reductions. GNU
libiconv 1.19 has no UTF-5 profile, so the benchmark does not manufacture an
alias-based GNU comparison.

The 2026-07-17 Apple M1 / Elixir 1.19.5 / OTP 28 quick run measured
3.178–77.492 MiB/s over eight paths. Native/reference latency was
0.342x–0.504x and reduction scaling was 1.931x–2.008x; all performance gates
passed. Benchmark source SHA-256:
`b17e0ab352d27ab93c56bb743a8846b4a866303f658a1827a405ddd603dbfc94`.
Runtime source SHA-256:
`0bce145bb958b7b60baf4d921ae72cc1b67af1413555918580d2fa26412e6a45`.

<!-- utf5-benchmark:end -->

## UTF-6 draft profile

<!-- utf6-benchmark:start -->

Run `ICONVEX_PATH=../iconvex ICONVEX_ARCHIVE_PATH=.. MIX_ENV=test mix run
--no-compile bench/utf6_benchmark.exs --quick`. Five hostname corpora exercise
same-byte compression, same-nibble compression, uncompressed UTF-16 units,
surrogate pairs, literal hyphens, and dot-separated components. Every result
must match the independent draft transcription; native/reference latency has a
hard 30x ceiling and scheduler work must remain linear. GNU libiconv 1.19 has
no `draft-ietf-idn-utf6-00` profile.

The 2026-07-17 Apple M1 / Elixir 1.19.5 / OTP 28 quick run measured
15.097–73.996 MiB/s over ten paths. Native/reference latency had a worst case
of 1.151x and reduction scaling was 1.956x–2.006x; all performance gates
passed. Benchmark source SHA-256:
`0846d5a2b875f5eb30bd893a4fe0ad86f5b4ab2a0a51a07ec8df0a04dc8f4dd5`.
Runtime source SHA-256:
`82ac0b0e4f914bac3bc1e98447f6c9b86b3f0f09eaea9dd5fdcd6d3d1d536a45`.

<!-- utf6-benchmark:end -->

## ICU LMBCS optimization groups

Run `ICONVEX_PATH=../iconvex ICONVEX_ARCHIVE_PATH=.. MIX_ENV=prod mix run
bench/icu_lmbcs_variants_benchmark.exs`. The script compiles its ICU 78.3 C
oracle once, checks canonical output separately with `uconv`, warms both paths,
and reports time measured inside the persistent C process. Oracle process
startup and compilation are therefore excluded. Each row is the median paired
native/ICU ratio from three independent trials. The executable gate fails if
any operation is more than 30x ICU or if doubling input grows a representative
native path by more than 3x.

Apple M1 arm64 / Elixir 1.19.5 / OTP 28 / ICU 78.3, 1,984 mixed-script
scalars per operation:

| Profile | Encode native/ICU | Decode native/ICU |
|---|---:|---:|
| LMBCS-1 | 2.61x | 22.63x |
| LMBCS-2 | 3.42x | 23.95x |
| LMBCS-3 | 3.19x | 24.08x |
| LMBCS-4 | 3.59x | 25.34x |
| LMBCS-5 | 3.11x | 23.22x |
| LMBCS-6 | 3.06x | 23.84x |
| LMBCS-8 | 3.10x | 24.07x |
| LMBCS-11 | 3.19x | 22.75x |
| LMBCS-16 | 3.17x | 24.85x |
| LMBCS-17 | 3.03x | 22.66x |
| LMBCS-18 | 3.75x | 25.63x |
| LMBCS-19 | 2.32x | 20.79x |

All 24 paths remain inside the 30x ceiling: encode spans 2.32--3.75x and decode
spans 20.79--25.63x. LMBCS-16 measured 2.37x encode and 1.48x decode time for a
2x input, confirming linear growth. Runtime data is
loaded once into `persistent_term`; no ICU code, executable, Port, or NIF is
used by the native codecs.

## Twelve-bit punched cards

Run `ICONVEX_PATH=../iconvex ICONVEX_ARCHIVE_PATH=.. MIX_ENV=prod mix run
bench/punched_card_benchmark.exs`. It benchmarks packed MSB, packed LSB, 16BE,
and 16LE encode/decode for all six profiles over 65,536 characters per
operation: forty-eight measured paths. Each profile has a 64-unit benchmark
alphabet loaded from the digest-pinned `canonical_maps.csv`; the three
63-row profiles repeat their first canonical scalar once, while the other
three use all 64 distinct rows. Thus every one of the 381 canonical rows is
present in every repetition without inventing a mapping. The independently
loaded `decode_aliases.csv` adds both proved alternate masks to the reference
decoder.

Before timing, native output must equal this CSV-derived encode/decode oracle,
every path must decode to the same input, both decode aliases must agree with
the evidence, and the 16BE/16LE words must carry identical twelve-bit masks.
The reference builder contains no runtime codec call.

The 2026-07-18 full Apple M1 arm64 / Elixir 1.19.5 / OTP 28 production run
measured the following million characters/s:

| Profile | MSB enc | MSB dec | LSB enc | LSB dec | 16BE enc | 16BE dec | 16LE enc | 16LE dec |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| IBM H report | 14.774 | 14.554 | 19.018 | 15.619 | 23.693 | 21.046 | 22.883 | 19.551 |
| IBM H program | 19.563 | 14.167 | 19.569 | 15.460 | 23.651 | 21.134 | 23.273 | 19.752 |
| IBM 1401 | 15.284 | 12.598 | 18.039 | 14.987 | 22.947 | 20.925 | 22.505 | 19.540 |
| CDC 167/166 1965 | 20.134 | 14.225 | 19.476 | 15.861 | 23.076 | 20.570 | 23.397 | 20.165 |
| CDC 6000 1970 | 20.772 | 14.045 | 19.146 | 15.977 | 23.668 | 21.508 | 23.736 | 19.534 |
| BCD CDC Iowa reconstruction | 20.551 | 13.662 | 18.870 | 16.294 | 22.971 | 21.073 | 22.987 | 19.950 |

Every transport and direction has a hard 20,000-to-40,000-character reduction
gate. Each count is the median of three measurements in fresh BEAM processes,
which isolates the result from prior heap and garbage-collection state:

| Operation | 20k reductions | 40k reductions | Ratio |
|---|---:|---:|---:|
| Packed MSB encode | 101,045 | 185,038 | 1.831x |
| Packed MSB decode | 76,006 | 144,020 | 1.895x |
| Packed LSB encode | 64,836 | 114,340 | 1.764x |
| Packed LSB decode | 104,007 | 208,018 | 2.000x |
| 16BE encode | 141,085 | 265,116 | 1.879x |
| 16BE decode | 116,011 | 224,841 | 1.938x |
| 16LE encode | 141,085 | 265,116 | 1.879x |
| 16LE decode | 116,007 | 228,018 | 1.966x |

All eight ratios must remain inside `1.75..2.25`. The observational 16BE wall
doubling remains observational; reductions are the hard linearity gate because
desktop scheduling makes wall samples noisy. The full source-independent run
measured native/reference ratios of 0.24x–15.66x across all 48 paths; Iowa
spanned 0.43x–10.26x. Every path remains below the 30x regression ceiling.

### IBM 24/26 arrangements A-K

Run `ICONVEX_PATH=../iconvex ICONVEX_ARCHIVE_PATH=.. MIX_ENV=test mix run
--no-compile bench/ibm_24_26_arrangements_benchmark.exs --quick`. The focused
harness covers all ten arrangements and both directions of packed MSB, explicit
packed LSB, zero-padded 16BE, and zero-padded 16LE transports. It first requires
40/40 transport round trips to agree, then applies scheduler-reduction and wall
scaling gates and a hard 30x dense-table-reference ceiling.

The Apple M1 / Elixir 1.19.5 / OTP 28 quick evidence run measured 9.00-13.09
million characters/s for encode paths and 12.42-19.12 million characters/s for
decode paths. The 20,000-to-40,000-character ratios were 1.879x reductions and
2.097x wall time. Native/reference ratios were 1.221x encode and 3.424x decode;
the 3.424x worst path passes the 30x gate.

## ECMA-44 raw punched-card transport

Run `ICONVEX_PATH=../iconvex ICONVEX_ARCHIVE_PATH=.. MIX_ENV=test mix run
--no-compile bench/ecma44_benchmark.exs`. The benchmark covers masks and all
four serialized transports in both directions for both raw modes. It proves
round-trip parity and identical 16BE/16LE masks before measuring.

The 2026-07-17 Apple M1 arm64 / Elixir 1.19.5 / OTP 28.3 reference run
measured these million raw combinations per second:

| Operation | 7-bit | 8-bit |
|---|---:|---:|
| Mask encode | 248.242 | 249.186 |
| Mask decode | 53.087 | 32.268 |
| Packed MSB encode | 29.063 | 32.411 |
| Packed MSB decode | 13.553 | 14.098 |
| Packed LSB encode | 57.817 | 60.978 |
| Packed LSB decode | 24.268 | 24.747 |
| 16BE encode | 29.205 | 30.049 |
| 16BE decode | 10.191 | 10.398 |
| 16LE encode | 32.621 | 32.978 |
| 16LE decode | 8.386 | 8.327 |

All twenty mode/operation scheduler-reduction gates compare 20,000 with 40,000
units in fresh processes. The reference ratios span `1.857x--2.006x`; each
must remain strictly inside the executable `1.75x..2.25x` band. The quick CI
contract requires all twenty throughput rows, all twenty scaling rows, and the
parity summary. GNU libiconv has no equivalent raw code-combination API, so no
semantically invalid slowdown ratio is reported. Full provenance and mapping
digests are in [`ECMA44_RAW_TRANSPORT.md`](ECMA44_RAW_TRANSPORT.md).

## TI-89 / TI-92 Plus AMS 2.0

Run `ICONVEX_PATH=../iconvex ICONVEX_ARCHIVE_PATH=.. MIX_ENV=prod mix run
bench/ti89_ams2_bench.exs`. The corpus deliberately makes bytes 9A, 9B, and B4
nine of every eleven source units, so encode timing exercises longest-match
two-scalar reverse conversion instead of an ASCII-only shortcut. Every profile
must round-trip the corpus through both direct callbacks and
`Iconvex.convert/4` before timing.

The 2026-07-17 Apple M1 / Elixir 1.19.5 / OTP 28.3 production run measured
these MiB of actual operation input per second:

| Profile | Direct decode | Direct encode | Public decode | Public encode |
|---|---:|---:|---:|---:|
| Source glyph | 35.90 | 15.17 | 23.01 | 15.11 |
| Visible controls | 40.18 | 15.16 | 23.17 | 15.27 |
| Lossless VPUA | 39.44 | 15.43 | 22.85 | 15.51 |
| Raw VPUA | 41.23 | 28.64 | 26.78 | 28.18 |

Encode throughput uses the actual UTF-8 byte count; this matters because the
raw profile emits four-byte Plane-15 scalars. Direct paths use compile-time
tuples/maps and bounded 4,096-unit binary chunks. Every timed path also has an
executable throughput floor in MiB of actual operation input per second:

| Profile group | Operation | Recorded family minimum | Minimum / 30 | Executable floor |
|---|---|---:|---:|---:|
| Three readable profiles | Direct decode | 35.90 | 1.197 | 1.20 |
| Three readable profiles | Direct encode | 15.16 | 0.505 | 0.51 |
| Three readable profiles | Public decode | 22.85 | 0.762 | 0.77 |
| Three readable profiles | Public encode | 15.11 | 0.504 | 0.51 |
| Raw VPUA | Direct decode | 41.23 | 1.374 | 1.38 |
| Raw VPUA | Direct encode | 28.64 | 0.955 | 0.96 |
| Raw VPUA | Public decode | 26.78 | 0.893 | 0.90 |
| Raw VPUA | Public encode | 28.18 | 0.939 | 0.94 |

The gates are the recorded minimum for the relevant profile family divided by
30 and rounded upward to the next 0.01 MiB/s; no floor is rounded down. Every
floor is therefore at least its recorded minimum divided by 30, so a slowdown
greater than 30x fails the benchmark. This leaves ordinary shared-CI headroom
while enforcing the stated boundary exactly. All sixteen operation/profile
gates separately compare scheduler reductions for 524,288 and 1,048,576 source
bytes in fresh processes. The measured ratios span
`1.995x--2.041x`, inside the executable `1.65x..2.35x` band. Those gates are
evidence about scheduler-work scaling, not peak allocation or resident memory.
The quick CI contract requires all throughput rows and floors, scaling rows,
and round-trip summaries.

GNU support is reported only after running the configured executable with
`iconv -l`, splitting its listed aliases, normalizing ASCII case and
punctuation, and comparing exact normalized names against every canonical TI
name and alias. `--version` is queried only afterward to label the result. A
fake-executable regression proves that a punctuation-equivalent alias is
accepted and a longer wrapper name containing the TI text is rejected. GNU
libiconv 1.19 lists no exact TI-89/TI-92 Plus AMS 2.0 alias, so no invalid
slowdown ratio is claimed.

## TI-83 Plus 2002 large/small fonts

Run `ICONVEX_PATH=../iconvex ICONVEX_ARCHIVE_PATH=.. MIX_ENV=prod mix run
bench/ti83_plus_2002_bench.exs`. The benchmark runs all six profiles through
direct decode/encode and public decode/encode. Its readable corpus is dominated
by bytes 11, CB, CC, and D8, so reverse timing exercises longest two-scalar
matches; 1D and DE are independently proved decode-only. Separate corpora put
invalid bytes throughout strict, discard, and replacement recovery paths.

The 2026-07-17 Apple M1 / Elixir 1.19.5 / OTP 28.3 seven-sample production run
recorded these family minima in MiB of actual operation input per second:

| Profile family | Direct decode | Direct encode | Public decode | Public encode |
|---|---:|---:|---:|---:|
| Readable (large/small) | 39.54 | 14.38 | 24.00 | 15.16 |
| Mixed-lossless VPUA (large/small) | 39.27 | 15.04 | 23.61 | 15.20 |
| Raw VPUA (large/small) | 39.17 | 27.23 | 25.99 | 27.29 |

The invalid-path family minima were 40.05 direct strict, 16.81 direct discard,
40.12 public strict, 11.17 public discard, and 1.10 public replacement MiB/s.
All 34 paths enforce the following ceiling-derived floors; none is rounded down:

| Family | Direct decode/strict | Direct encode/discard | Public decode/strict | Public encode/discard | Public replacement |
|---|---:|---:|---:|---:|---:|
| Readable | 1.32 | 0.48 | 0.81 | 0.51 | — |
| Mixed lossless | 1.31 | 0.51 | 0.79 | 0.51 | — |
| Raw | 1.31 | 0.91 | 0.87 | 0.91 | — |
| Invalid recovery | 1.34 | 0.57 | 1.34 | 0.38 | 0.04 |

Each floor is `ceil(recorded family minimum / 30, 0.01)`, so a slowdown greater
than 30x fails. All 34 fresh-process scheduler-reduction ratios for a 2x input
span `1.995x--2.162x` inside the executable `1.65x..2.35x` band. Reduction
scaling is reported only as scheduler-work evidence, not peak-memory evidence.

GNU support is derived by querying `iconv -l` first and exact-matching normalized
canonical names and aliases. A fake executable proves a punctuation-equivalent
positive and a deceptive substring negative. GNU libiconv 1.19 lists no exact
TI-83 Plus profile, so the report correctly marks comparison unavailable rather
than inventing a semantically invalid slowdown ratio.

## ICU historical archive tables

Run `MIX_ENV=prod mix run bench/icu_archive_bench.exs`. The script selects a
revision from each storage/state family, warms the lazy tables, and reports the
median of nine 1,000-operation samples. Apple M1 / Elixir 1.19.5 / OTP 28:

| Family and revision | Scalars | Bytes | Encode ops/s | Decode ops/s |
|---|---:|---:|---:|---:|
| SBCS `aix-IBM_1046-4.3.6` | 1,020 | 1,020 | 19,911.2 | 27,563.6 |
| DBCS `ibm-835_P100-1995` | 1,024 | 2,048 | 20,328.0 | 10,329.8 |
| MBCS `euc-jp-2007` | 1,024 | 1,776 | 19,690.0 | 8,065.9 |
| four-byte MBCS `ibm-5487_P100-2001` | 1,024 | 4,096 | 17,173.4 | 9,326.2 |
| SI/SO MBCS `ibm-25546_P100-1997` | 1,024 | 1,552 | 10,445.5 | 19,147.2 |

The archive uses the same lazily loaded compressed `persistent_term` tables as
the smaller mapping families. Stateful encode consolidates adjacent DBCS output
under one Shift Out/Shift In pair.

## Native non-octet formats

Run `ICONVEX_PATH=../iconvex MIX_ENV=prod mix run bench/non_octet_benchmark.exs`.
The input has 16,384 mixed one-, two-, and three-nonet scalars; results are the
median of nine production-build samples after two warmups. Apple M1 / OTP 28 /
Elixir 1.19.5:

| Operation | Scalars/s | Median |
|---|---:|---:|
| UTF-9 packed encode | 12,860,283 | 1.27 ms |
| UTF-9 packed decode | 5,048,998 | 3.25 ms |
| UTF-9 16BE encode | 5,031,941 | 3.26 ms |
| UTF-9 16BE decode | 4,496,158 | 3.64 ms |
| UTF-18 packed encode | 12,622,496 | 1.30 ms |
| UTF-18 packed decode | 17,541,756 | 0.93 ms |
| UTF-18 24BE encode | 12,700,775 | 1.29 ms |
| UTF-18 24BE decode | 16,062,745 | 1.02 ms |

All implementations are tail-recursive linear passes. Exact-bit APIs build one
reversed iolist of bitstring chunks; word transports build binary iodata. The
timed functions include strict scalar/padding validation.

## Six-bit historical codecs

Run `ICONVEX_PATH=../iconvex MIX_ENV=prod mix run bench/six_bit_bench.exs`.
The input is 1 MiB of valid six-bit units; each path gets three warmups and the
best of nine production-build samples. Apple M1 / OTP 28 / Elixir 1.19.5:

| Operation | Throughput |
|---|---:|
| ECMA-1 decode | 148.54 MiB/s |
| ECMA-1 encode | 78.95 MiB/s |
| DEC-SIXBIT decode | 131.87 MiB/s |
| DEC-SIXBIT encode | 59.64 MiB/s |

No GNU libiconv comparison ratio exists because GNU libiconv 1.19 implements
neither codec. Both native paths are allocation-linear tail-recursive passes;
DEC decoding uses arithmetic and ECMA-1 decoding uses a compile-time tuple.

Run `ICONVEX_PATH=../iconvex MIX_ENV=prod mix run bench/cdc_display_code_bench.exs`
for CDC Display Code. It measures 1 MiB through direct `Iconvex.convert/4`, with
three warmups, garbage collection before each of nine samples, and the median:

| Profile | Decode to UTF-8 | Encode from UTF-8 |
|---|---:|---:|
| CDC graphics 63 | 68.72 MiB/s | 16.14 MiB/s |
| CDC graphics 64 | 68.04 MiB/s | 14.59 MiB/s |
| ASCII graphics 63 | 68.68 MiB/s | 15.89 MiB/s |
| ASCII graphics 64 | 69.40 MiB/s | 16.08 MiB/s |

The initial direct decoders built one input-sized reversed list and measured
only 16.48–16.65 MiB/s. Bounded 4,096-unit binary chunks raise decoding to
68.04–69.40 MiB/s and keep all four profiles within 2%. Encoding is dominated
by strict UTF-8 validation and reverse-map lookup. GNU libiconv 1.19 has no CDC
Display Code codec, so no GNU ratio exists.

Run `ICONVEX_PATH=../iconvex MIX_ENV=prod mix run bench/cdc_6_12_display_code_bench.exs`
for full-ASCII CDC 6/12. Inputs cycle through every representable ASCII value;
the table reports median production-build throughput after three warmups and
garbage collection before each of nine samples:

| Operation | Throughput |
|---|---:|
| 63-character byte decode | 20.00 MiB/s encoded units |
| 63-character byte encode | 17.87 MiB/s UTF-8 input |
| 64-character byte decode | 22.26 MiB/s encoded units |
| 64-character byte encode | 17.59 MiB/s UTF-8 input |
| 64-character packed MSB decode | 10.29 MiB/s packed input |
| 64-character packed MSB encode | 15.28 MiB/s UTF-8 input |
| 64-character packed LSB decode | 10.46 MiB/s packed input |
| 64-character packed LSB encode | 15.03 MiB/s UTF-8 input |

The first generic packed run measured only 3.75 MiB/s decode and 4.25 MiB/s
encode. Bounded bit buffers and specialized four-unit 6-bit groups raise those
paths to 10.29–15.28 MiB/s while preserving exact error offsets for every width.
GNU libiconv 1.19 has no CDC 6/12 codec, so no GNU ratio exists.

## DEC terminal graphic sets

Run
`ICONVEX_PATH=../iconvex MIX_ENV=prod mix run bench/dec_terminal_character_sets_bench.exs`.
Each profile cycles through every defined table cell in a 1 MiB corpus. The
script performs three warmups and reports the median of nine production-build
samples after explicit garbage collection. Apple M1 / OTP 28 / Elixir 1.19.5:

| Profile | Decode to UTF-8 | Encode from UTF-8 |
|---|---:|---:|
| DEC Special GL | 15.46 MiB/s | 15.32 MiB/s |
| DEC Special GR | 15.42 MiB/s | 15.28 MiB/s |
| DEC Technical GL | 17.08 MiB/s | 9.47 MiB/s |
| DEC Technical GR | 17.46 MiB/s | 9.42 MiB/s |

| Packed GL transport | Encode | Decode |
|---|---:|---:|
| DEC Special MSB | 11.56 MiB/s | 7.45 MiB/s |
| DEC Special LSB | 8.77 MiB/s | 7.92 MiB/s |
| DEC Technical MSB | 7.94 MiB/s | 7.56 MiB/s |
| DEC Technical LSB | 6.52 MiB/s | 8.54 MiB/s |

The corpus includes the complete non-ASCII repertoires, so Technical encode
parses multi-byte UTF-8 for every input character. Direct paths use compile-time
tuples/maps and bounded 4,096-unit chunks; packed paths reuse the bounded generic
bit engine. GL/GR pairs stay within 1% on direct conversion. GNU libiconv 1.19
has neither DEC set, so no GNU slowdown ratio exists.

## DEC Hebrew profiles

Run `ICONVEX_PATH=../iconvex MIX_ENV=prod mix run bench/dec_hebrew_bench.exs`.
Each direct profile cycles through its complete defined alphabet in a 1 MiB
corpus. The packed SI 960 corpus contains every septet. Results are medians of
nine production-build samples after three warmups and explicit garbage
collection on Apple M1 / OTP 28 / Elixir 1.19.5:

| Operation | Throughput |
|---|---:|
| SI 960 decode to UTF-8 | 58.57 MiB/s |
| SI 960 encode from UTF-8 | 13.82 MiB/s |
| DEC Hebrew 8 decode to UTF-8 | 54.81 MiB/s |
| DEC Hebrew 8 encode from UTF-8 | 14.17 MiB/s |
| SI 960 packed MSB encode | 10.77 MiB/s |
| SI 960 packed MSB decode | 11.66 MiB/s |
| SI 960 packed LSB encode | 8.37 MiB/s |
| SI 960 packed LSB decode | 12.68 MiB/s |

Both direct paths use compile-time tuples/maps and bounded 4,096-unit chunks;
the packed paths use the bounded generic seven-bit engine. GNU libiconv 1.19
implements neither profile, so no GNU slowdown ratio exists.

## Short KOI / KOI-7 N2

Run `ICONVEX_PATH=../iconvex MIX_ENV=prod mix run bench/short_koi_bench.exs`.
The 1 MiB corpus cycles through all 128 valid septets, including every
Cyrillic cell. Results are production-build medians of nine samples after three
warmups and explicit garbage collection on Apple M1 / OTP 28 / Elixir 1.19.5:

| Operation | Throughput |
|---|---:|
| Decode to UTF-8 | 66.38 MiB/s |
| Encode from UTF-8 | 16.45 MiB/s |
| Packed MSB encode | 12.27 MiB/s |
| Packed MSB decode | 11.98 MiB/s |
| Packed LSB encode | 9.27 MiB/s |
| Packed LSB decode | 13.07 MiB/s |

The initial decode measured 19.53 MiB/s because a tiny output helper remained
as a function call for every septet. Inlining that helper and the scalar-to-UTF-8
branch raises decode by 3.40x while retaining bounded 4,096-unit chunks and
exact error offsets. GNU libiconv 1.19 does not provide Short KOI / KOI-7 N2,
so no GNU slowdown ratio exists.

## ELOT 927 profiles

Run `ICONVEX_PATH=../iconvex MIX_ENV=prod mix run
bench/kermit_elot927_greek_bench.exs`. Each 1 MiB corpus cycles through every
defined septet. Results are production-build medians of nine samples after
three warmups and explicit garbage collection on Apple M1 / OTP 28 / Elixir
1.19.5:

| Profile and operation | Throughput |
|---|---:|
| Standard ELOT 927 decode to UTF-8 | 6.90 MiB/s |
| Standard ELOT 927 encode from UTF-8 | 7.30 MiB/s |
| Standard packed MSB encode | 6.65 MiB/s |
| Standard packed MSB decode | 4.01 MiB/s |
| Standard packed LSB encode | 5.76 MiB/s |
| Standard packed LSB decode | 4.36 MiB/s |
| Kermit ELOT927 decode to UTF-8 | 67.65 MiB/s |
| Kermit ELOT927 encode from UTF-8 | 17.33 MiB/s |
| Kermit packed MSB encode | 12.57 MiB/s |
| Kermit packed MSB decode | 12.02 MiB/s |
| Kermit packed LSB encode | 9.52 MiB/s |
| Kermit packed LSB decode | 13.18 MiB/s |

The standard profile uses the shared RFC 1345 table engine; the separately
implemented Kermit profile uses compile-time tuple/map branches and bounded
4,096-unit chunks. GNU libiconv 1.19 exposes neither ELOT 927/ISO-IR-88 nor the
Kermit terminal profile, so no GNU slowdown ratio exists.

## DEC National Replacement Character Sets

Run `ICONVEX_PATH=../iconvex MIX_ENV=prod mix run
bench/dec_national_replacement_sets_bench.exs`. Every direct corpus is 1 MiB
and cycles through all 128 septets. Results are production-build medians of
nine samples after three warmups and explicit garbage collection on Apple M1 /
OTP 28 / Elixir 1.19.5:

| Profile | Decode to UTF-8 | Encode from UTF-8 |
|---|---:|---:|
| United Kingdom | 73.56 MiB/s | 19.40 MiB/s |
| Dutch | 64.91 MiB/s | 18.31 MiB/s |
| Finnish | 67.31 MiB/s | 18.50 MiB/s |
| French | 64.10 MiB/s | 18.08 MiB/s |
| French Canadian | 65.17 MiB/s | 18.19 MiB/s |
| German | 67.10 MiB/s | 18.50 MiB/s |
| Italian | 62.50 MiB/s | 18.07 MiB/s |
| Norwegian/Danish | 69.18 MiB/s | 18.70 MiB/s |
| Portuguese | 66.62 MiB/s | 18.63 MiB/s |
| Spanish | 66.28 MiB/s | 18.48 MiB/s |
| Swedish | 62.03 MiB/s | 18.30 MiB/s |
| Swiss | 61.87 MiB/s | 17.78 MiB/s |

| Representative packed operation | Throughput |
|---|---:|
| Dutch MSB encode / decode | 13.08 / 11.60 MiB/s |
| Dutch LSB encode / decode | 9.70 / 12.72 MiB/s |
| French MSB encode / decode | 13.07 / 11.67 MiB/s |
| French LSB encode / decode | 9.77 / 12.72 MiB/s |

The first implementation reused the generic RFC table engine for six
byte-identical profiles and measured only 7.52–8.18 MiB/s direct conversion.
Dedicated compile-time tuple/map paths raised those decodes by 7.86–8.94x and
encodes by 2.36–2.44x; all twelve now share bounded 4,096-unit behavior and
exact offsets. GNU libiconv 1.19 exposes none of these NRC profiles, so no GNU
slowdown ratio exists.

## Versioned Kermit single-byte profiles

Run `ICONVEX_PATH=../iconvex MIX_ENV=prod mix run
bench/kermit_versioned_single_byte_bench.exs`. Each 1 MiB mixed corpus cycles
through every octet whose meaning is shared by the historical profile and GNU
comparison codec. Results are medians of seven samples after two warmups on
Apple M1 / OTP 28 / Elixir 1.19.5:

| Profile | Direction | Iconvex | GNU libiconv 1.19 | GNU/Iconvex |
|---|---|---:|---:|---:|
| Greek ISO / ELOT 928 | decode | 32.20 MiB/s | 60.58 MiB/s | 1.88x |
| Greek ISO / ELOT 928 | encode | 29.85 MiB/s | 59.93 MiB/s | 2.01x |
| Hebrew ISO historical | decode | 36.50 MiB/s | 61.46 MiB/s | 1.68x |
| Hebrew ISO historical | encode | 29.07 MiB/s | 64.29 MiB/s | 2.21x |
| Latin-6 ISO | decode | 32.91 MiB/s | 60.70 MiB/s | 1.84x |
| Latin-6 ISO | encode | 28.66 MiB/s | 63.02 MiB/s | 2.20x |
| Macintosh Latin | decode | 32.43 MiB/s | 54.63 MiB/s | 1.68x |
| Macintosh Latin | encode | 28.74 MiB/s | 55.76 MiB/s | 1.94x |

Latin-6 is byte-exact with GNU. Greek excludes GNU's three modernized cells,
Hebrew excludes its three historical/modern differences, and Macintosh excludes
the U+F8FF cell that GNU MacIceland rejects. The benchmark enforces a 30x
ceiling. Compile-time tuples/maps, bounded chunks, and eight-byte ASCII batching
keep every measured direction between 1.68x and 2.21x of GNU.

## KOI8-F / KOI8 Unified

Run `ICONVEX_PATH=../iconvex ICONVEX_ARCHIVE_PATH=.. MIX_ENV=prod mix run
bench/koi8_f_bench.exs`. The 1 MiB mixed corpus covers ASCII, symbols,
Cyrillic, and the canonical 0x9A encoding of the duplicate U+00A0 mapping.
Results are medians of nine samples after three warmups on Apple M1 / OTP 28 /
Elixir 1.19.5. Native and generic timings are collected as adjacent pairs with
alternating execution order; relative latency is the median of the nine
within-pair ratios, so scheduler drift between two independent timing phases
cannot manufacture a regression:

KOI8-F benchmark source binding:
`85ea440a39f664b818c477f241e724486c6620a61dd79c50333b183bf3d68dd7`.

| Direct callback | Throughput | 20k-to-40k reduction scaling | Native/generic latency |
|---|---:|---:|---:|
| Decode to UTF-8 | 51.211 MiB/s | 2.018x | 0.268x |
| Encode from UTF-8 | 67.113 MiB/s | 1.934x | 0.456x |

The generic comparator composes the ordinary decode/encode callbacks with
Unicode conversion. The permanent test requires 1.75x–2.25x doubled-input
reduction scaling and caps either native callback at 1.25x of that comparator.
Precomputed byte-to-UTF-8 cells and bounded 64 KiB UTF-8 parsing make both
native callbacks faster while preserving split scalars, exact malformed
suffixes, absolute offsets, and first-error ordering. GNU libiconv 1.19 does
not expose this source-qualified NMSU 2008 mapping, so the benchmark explicitly
refuses an alias-based GNU parity or slowdown claim.

## Kermit vendor byte profiles

Run `ICONVEX_PATH=../iconvex ICONVEX_ARCHIVE_PATH=.. MIX_ENV=prod mix run
bench/kermit_vendor_8bit_bench.exs`. Each 1 MiB encoded corpus cycles through
every defined octet in its profile. Results are medians of seven samples after
two warmups on Apple M1 / OTP 28 / Elixir 1.19.5; encode throughput uses the
actual variable-width UTF-8 input size:

| Profile | Decode input | Encode input |
|---|---:|---:|
| BULGARIA-PC | 31.63 MiB/s | 44.73 MiB/s |
| MAZOVIA | 16.18 MiB/s | 37.99 MiB/s |
| QNX-CONSOLE | 29.96 MiB/s | 52.03 MiB/s |
| DG-INTERNATIONAL | 32.06 MiB/s | 43.52 MiB/s |
| KERMIT-DG-LINEDRAWING | 30.46 MiB/s | 56.63 MiB/s |
| KERMIT-DG-WORDPROCESSING | 24.73 MiB/s | 60.44 MiB/s |
| KERMIT-HP-MATH-TECHNICAL | 24.35 MiB/s | 54.71 MiB/s |
| KERMIT-SNI-BRACKETS | 23.49 MiB/s | 68.64 MiB/s |
| KERMIT-SNI-EURO | 24.83 MiB/s | 51.32 MiB/s |
| KERMIT-SNI-FACET | 27.24 MiB/s | 61.25 MiB/s |
| KERMIT-SNI-IBM | 25.87 MiB/s | 59.87 MiB/s |

The executable benchmark uses per-process scheduler reductions as the hard
linear-work signal. All 22 512 KiB-to-1 MiB gates pass at 1.971x--2.042x
against a 2.3x ceiling. The seven 94-position sets use their true identity
prefix in the fast path; bytes 21--7E cannot accidentally take the ASCII-copy
branch. GNU libiconv 1.19 lists none of these exact profiles, so no semantic
slowdown ratio is claimed.

## Source-qualified IBM and DEC code pages

Run `ICONVEX_PATH=../iconvex ICONVEX_ARCHIVE_PATH=.. MIX_ENV=prod mix run
bench/ibm_additional_code_pages_bench.exs`. Each 1 MiB encoded corpus cycles
through every defined byte in its profile. Results are medians of seven samples
after two warmups on Apple M1 / OTP 28 / Elixir 1.19.5; encode throughput uses
the actual variable-width UTF-8 input size, not the encoded-output size:

| Profile | Decode input | Encode input |
|---|---:|---:|
| IBM-310 / IBM-293 P100 VPUA composite | 5.52 MiB/s | 11.95 MiB/s |
| IBM/tnz CP310 b1eae3c | 5.81 MiB/s | 12.96 MiB/s |
| IBM-907 CDRA P100 VPUA composite | 6.01 MiB/s | 9.88 MiB/s |
| IBM-1116 / IBM-850 P100 composite | 8.94 MiB/s | 12.45 MiB/s |
| IBM-1117 / IBM-437 P100 composite | 8.96 MiB/s | 9.51 MiB/s |
| DEC Greek 8-bit 1994 | 13.36 MiB/s | 13.92 MiB/s |
| DEC Turkish 8-bit 1994 | 12.89 MiB/s | 13.72 MiB/s |

The executable benchmark uses per-process scheduler reductions as the hard
linear-work signal. All fourteen 512 KiB-to-1 MiB gates pass at 2.008x–2.215x
against a 2.3x ceiling; wall-time scaling is reported separately and is not a
correctness gate. Compile-time decode tuples, preferred-inverse maps, direct
UTF-8 paths, and bounded 4,096-unit chunks keep memory and work linear. GNU
libiconv 1.19 exposes none of these seven qualified profile identities, so a
semantically valid GNU/Iconvex slowdown ratio cannot be reported.

## DEC RADIX-50 word families

Run `ICONVEX_PATH=../iconvex MIX_ENV=prod mix run bench/dec_radix50_bench.exs`.
The input is 1 MiB of packed words. Each direct `Iconvex.convert/4` path gets
three warmups and nine production-build samples, with garbage collection before
each timed sample; the table reports the median. Apple M1 / OTP 28 / Elixir
1.19.5:

| Operation | Packed throughput |
|---|---:|
| PDP-11 16BE decode to UTF-8 | 25.50 MiB/s |
| PDP-11 16BE encode from UTF-8 | 30.78 MiB/s |
| PDP-11 16LE decode to UTF-8 | 25.35 MiB/s |
| PDP-11 16LE encode from UTF-8 | 30.72 MiB/s |
| PDP-6/10 36BIT/40BE decode to UTF-8 | 31.39 MiB/s |
| PDP-6/10 36BIT/40BE encode from UTF-8 | 12.17 MiB/s |
| PDP-6/10 36BIT/40LE decode to UTF-8 | 30.79 MiB/s |
| PDP-6/10 36BIT/40LE encode from UTF-8 | 12.26 MiB/s |
| PDP-9/15 18BIT/24BE decode to UTF-8 | 27.69 MiB/s |
| PDP-9/15 18BIT/24BE encode from UTF-8 | 13.62 MiB/s |
| PDP-9/15 18BIT/24LE decode to UTF-8 | 27.36 MiB/s |
| PDP-9/15 18BIT/24LE encode from UTF-8 | 13.60 MiB/s |

The hot paths batch 1,024 words per binary allocation. Endianness is selected
once at entry; direct digit arithmetic avoids whole-input charlists and
per-word temporary lists, while explicit byte arithmetic avoids BEAM's slow
repeated little-endian bit-syntax extraction. Before that refactor the new
PDP-6/10 and PDP-9/15 paths measured only 5.83–8.47 MiB/s; the final range is
12.17–31.39 MiB/s and endian pairs differ by at most 2%. GNU libiconv 1.19 has
no RADIX-50 codec, so no GNU slowdown ratio exists.

## UNIVAC I expanded code

Run
`ICONVEX_PATH=../iconvex ICONVEX_ARCHIVE_PATH=.. MIX_ENV=prod mix run
bench/univac_i_1959_bench.exs`. The harness measures 262,144 logical units,
with two warmups and nine medians on Apple M1 / OTP 28 / Elixir 1.19.5. Its
source-binding SHA-256 is
`c4f44fc1912628bda78b76cd8cd17c7d66957fd327eecd197d63a58fa26a036c`.

| Operation family | Final throughput range | Native/generic latency | 20k-to-40k reductions |
|---|---:|---:|---:|
| Byte decode to UTF-8 (five profiles) | 17.88–27.24 Mi units/s | 0.859x–1.166x | 1.954x–1.967x |
| UTF-8 encode to bytes (five profiles) | 22.73–28.13 Mi units/s | 0.620x–0.719x | 1.822x–1.996x |
| Packed six-bit encode (three profiles, both orders) | 17.71–23.08 Mi units/s | n/a | n/a |
| Packed six-bit decode (three profiles, both orders) | 6.74–11.84 Mi units/s | n/a | n/a |
| Packed checked-septet encode (both orders) | 8.91–12.51 Mi units/s | n/a | n/a |
| Packed checked-septet decode (both orders) | 5.80–7.02 Mi units/s | n/a | n/a |

The first RED benchmark exposed the hand-written UTF-8 encoder at 2.034x the
generic baseline. The final implementation parses bounded 64 KiB chunks with
the VM Unicode primitive, uses precomputed UTF-8 decode cells, and keeps direct
callbacks at or below 1.25x of the independent callback composition. The
executable gate also requires doubled-input scheduler work in 1.70x–2.30x and
checks a conservative 0.20 Mi-unit/s floor for every byte and packed path.
GNU libiconv 1.19 exposes no source-qualified UNIVAC I expanded-code codec, so
the benchmark records the comparator as unavailable instead of timing an
unrelated alias.

## UNIVAC FIELDATA

Run
`ICONVEX_PATH=../iconvex ICONVEX_ARCHIVE_PATH=.. MIX_ENV=prod mix run bench/fieldata_bench.exs`.
Each result is the median of nine 262,144-unit production-build samples after
two warmups. Throughput is measured in logical six-bit units so the byte and
packed transports remain directly comparable. Apple Silicon / OTP 27 / Elixir
1.18.3:

| Profile | Byte decode | Byte encode | Packed MSB encode | Packed MSB decode | Packed LSB encode | Packed LSB decode |
|---|---:|---:|---:|---:|---:|---:|
| UNIVAC 1100 | 44.49 Mi units/s | 13.48 Mi units/s | 12.77 Mi units/s | 21.34 Mi units/s | 12.81 Mi units/s | 21.52 Mi units/s |
| 4009 input | 44.45 Mi units/s | 13.53 Mi units/s | 12.85 Mi units/s | 20.29 Mi units/s | 12.77 Mi units/s | 21.49 Mi units/s |
| 4009 output | 43.63 Mi units/s | 13.51 Mi units/s | 12.77 Mi units/s | 21.25 Mi units/s | 12.79 Mi units/s | 21.51 Mi units/s |
| 4009 lossless VPUA | 44.33 Mi units/s | 13.47 Mi units/s | 12.77 Mi units/s | 21.19 Mi units/s | 12.78 Mi units/s | 21.12 Mi units/s |
| 4009 raw VPUA | 28.30 Mi units/s | 10.04 Mi units/s | 9.50 Mi units/s | 14.81 Mi units/s | 9.43 Mi units/s | 14.69 Mi units/s |

The four semantic profiles stay within 2% on byte decode and within 1% on
byte encode. The raw profile deliberately emits four-byte Plane-15 scalars for
every source unit, explaining its lower logical-unit rate. Direct paths use
compile-time tuples/maps and bounded 4,096-unit chunks. The focused test also
checks scheduler-reduction scaling for 20,000 versus 40,000 units against a
1.7x--2.3x linearity gate. GNU libiconv 1.19 has no source-qualified UNIVAC
FIELDATA codec, so no semantically valid GNU/Iconvex slowdown ratio exists.

## Unihan 17 Chinese telegraph property tokens

Run
`ICONVEX_PATH=../iconvex ICONVEX_ARCHIVE_PATH=.. MIX_ENV=prod mix run bench/unihan_telegraph_property_token_bench.exs`.
The harness measures 262,144 one-token calls per sample, with two warmups and
seven fresh-process medians on Apple Silicon / OTP 28 / Elixir 1.19.5. It
reports tokens/s and logical throughput at four source bytes per token. Source
fixtures are loaded only to build the benchmark corpus, outside every timed
closure; runtime mapping calls use the compiled tables.

| Operation | Recorded conservative minimum | Strict 30x floor | Independent final range across three profiles |
|---|---:|---:|---:|
| assigned decode | 130.41 MiB/s | 4.35 MiB/s | 130.41–133.73 MiB/s |
| unassigned decode | 149.21 MiB/s | 4.98 MiB/s | 149.21–154.08 MiB/s |
| reverse encode | 54.45 MiB/s | 1.82 MiB/s | 54.45–55.56 MiB/s |
| token to UTF-8 | 78.67 MiB/s | 2.63 MiB/s | 78.67–84.65 MiB/s |
| UTF-8 to token | 42.68 MiB/s | 1.43 MiB/s | 42.68–44.26 MiB/s |

Two uncontended final-code runs span 11.19–40.39 million tokens/s. Each of the fifteen paths
also measures scheduler reductions at 131,072 and 262,144 tokens in isolated
fresh processes; every ratio is 1.999x–2.000x. Floors are the recorded minimum
divided by 30 and rounded **up** to the next 0.01 MiB/s. The benchmark and its
test independently recompute that ceiling, so no accepted result can exceed a
30x regression.

The one-scalar UTF-8 encode path uses an exact bitstring match before the
general malformed/cardinality validator. The initial 50,000-call RED recorded
1,129,331 reductions against a 900,000 test-first budget. The permanent gate
avoids freezing an absolute VM-specific reduction count: it measures the UTF-8
helper and direct scalar path in separate fresh worker processes inside the
same test VM, and requires the helper to stay within 35% of the direct path.
The final 42.68 MiB/s minimum is 15.6% above the audited 36.93 MiB/s
pre-fast-path minimum; empty, multi-scalar, and malformed inputs retain the
bounded general path and exact public errors.

GNU libiconv 1.19 was queried with `iconv -l` before its version was read. It
lists no exact normalized alias for any of the three source-qualified mappings.
Because Unicode defines one property token but no concatenated stream, the
harness reports no fabricated GNU equivalence or slowdown ratio.

## PASCII C-DAC GIST 1.0 profiles

Run `ICONVEX_PATH=../iconvex ICONVEX_ARCHIVE_PATH=.. MIX_ENV=test mix run
bench/pascii_10_benchmark.exs --quick`. The harness independently parses the
frozen 256-row mapping, proves exact output before timing, and measures direct
and public encode/decode for all four explicit profiles. Doubled-input process
reductions must remain in `1.55x..2.60x`, throughput must exceed 0.19 MiB/s,
and no native path may exceed the simple exact Elixir reference by 2x. GNU
libiconv 1.19 has no PASCII identity, so the comparator is explicitly N/A.

The 2026-07-17 Apple M1 / Elixir 1.19.5 / OTP 28 quick run passed all 16 paths
at 5.684–26.524 MiB/s. Reduction scaling was 1.835x–2.535x and the worst
native/reference result was 1.520x. The permanent unit suite separately limits
the direct callbacks to 1.25x the composed primitive paths by reductions. The
0.19 MiB/s absolute floor rounds 5.684/30 upward, so it cannot permit a
regression beyond the requested 30x ceiling from that recorded minimum.
Runtime source SHA-256:
`6ce25915c0559abde8f9300c7c5d6ba160de62045ac95c1850b73fe89909890d`.
Benchmark source SHA-256:
`1f3f1c83ef84ef04e5f866c62acefe8d94fbd761e9b3ff22f47a01f33adf21b5`.

## Recent source-qualified profile batch

The fourteen batches below have dedicated native-runtime harnesses. Run them from
this package with `ICONVEX_PATH=../iconvex ICONVEX_ARCHIVE_PATH=.. MIX_ENV=prod
mix run PATH`; append `--quick` for every harness except the observational
OML/OMS harness. OML/OMS reports seven-sample medians after three warmups for
both direct and composed paths. The other thirteen harnesses emit a versioned TSV
schema and stop with a nonzero exit when a declared throughput, scheduler-work,
or native/reference-latency gate fails.

| Batch | Executable coverage | Throughput floor | Reduction scaling | Native/reference ceiling |
|---|---|---:|---:|---:|
| OML/OMS | 2 profiles; direct/composed encode and decode | observational | observational | observational |
| Cork/T1 | 2 profiles × 3 corpora × encode/decode | 0.25 Mi encoded units/s | 1.60x–2.60x | 1.25x |
| CTAN CMap 1.0j OT1/OT1TT | 2 profiles × 3 corpora × encode/decode | 0.20 Mi encoded units/s | 1.60x–2.60x | 3.00x |
| Formal SignWriting | encode/decode plus all 63,010 exact mappings | 0.50 MiB/s | 1.70x–2.30x | 1.15x decode; 1.25x encode |
| PDP-1 | 4 transports × encode/decode; 8 explicit public initial-state profiles | 0.20 Mi units/s | 1.70x–2.30x | 1.40x |
| Kamenický/KEYBCS2 | 2 profiles × 2 corpora × encode/decode | 1.00 MiB/s | 1.60x–2.60x | 1.25x |
| ABICOMP | 1 profile × 3 corpora × encode/decode | 1.00 MiB/s | 1.60x–2.60x | 1.25x |
| BraSCII | complete 256-byte corpus × encode/decode | 1.00 MiB/s | at most 2.40x | 1.35x |
| MacOS Esperanto | complete 256-byte corpus × encode/decode | 1.00 MiB/s | at most 2.40x | 1.35x |
| VSCII-2 | 1 exact VN2 profile × 4 corpora × encode/decode | 1.00 MiB/s | 1.60x–2.60x | 1.25x |
| Kermit JIS7-KANJI | Roman and complete-repertoire corpora × encode/decode | 1.00 MiB/s | 1.50x–2.60x | 1.25x |
| Lotus LICS | complete 256-byte corpus × encode/decode | 1.00 MiB/s | at most 2.40x | 1.35x |
| U.S. Army Tap Code pair values | 1 exact profile × 4 corpora × encode/decode | 1.00 MiB/s | 1.60x–2.60x | 1.25x |
| PASCII C-DAC GIST 1.0 | 4 profiles × direct/public encode/decode | 0.19 MiB/s | 1.55x–2.60x | 2.00x exact reference; 1.25x composed reductions |

GNU libiconv 1.19 exposes no exact source-qualified identity for any row, so
the executable reports the comparator as unavailable instead of timing a
nearby but semantically different codec. `test/recent_source_qualified_benchmark_contract_test.exs`
independently reads the package manifest and public codec selection, verifies
every retained evidence asset, and recomputes both raw-file digests below. A
runtime or harness edit therefore invalidates this packaged prose until the
claims are rerun and deliberately rebound. Runtime code, source evidence, and
these documents ship in `iconvex_specs`; benchmark programs remain
development-only and are not selected into the release artifact.

<!-- recent-source-qualified-benchmark-contract:start -->
| Batch ID | Claim ID | Package | Runtime source SHA-256 | Benchmark source SHA-256 | Release selection | Harness selection |
|---|---|---|---|---|---|---|
| `tex-oml-oms` | `median-direct-composed:2-profiles` | `iconvex_specs` | `15861a0db9b51327ac6c3401c50474582272497f596ea9eb8b3d02799fd69708` | `5141ccfcc037996fc09450a92c6019eb6995d5a1d420bf7c2b9ea026b2e2baa9` | `runtime+evidence` | `development-only` |
| `cork-t1` | `gated-schema-v1:2-profiles:3-corpora` | `iconvex_specs` | `fa18ce77f16870ebf8da1ce6eb6b83850919556e9fd1ae4d27ccce5a2e95aaed` | `d965fc80ccb81fd0f503e51678aa33ed9f545383e89a4cf7cd81e53cd2be188b` | `runtime+evidence` | `development-only` |
| `ot1-cmap-1.0j` | `gated-schema-v1:2-profiles:3-corpora` | `iconvex_specs` | `f2f1e7ed1d38901698fb2e678914d660f359bd233b7a4f9175324ede0b427442` | `3372f88fe4c1d3dc222a4d4bbf4418bd4294574d3566215f4baef62485be95d3` | `runtime+evidence` | `development-only` |
| `formal-signwriting` | `gated-schema-v1:63010-mappings` | `iconvex_specs` | `af17725198976aba16d87633c80cee9b143df394310f6f7fd2c444e331af5e5c` | `c6c74e8352e70fd965c1af8002df091b061654a992a6fe34dd852f17e26c85a2` | `runtime+evidence` | `development-only` |
| `pdp1-character-codes` | `gated-schema-v1:4-transports:8-profiles` | `iconvex_specs` | `54e2277fe286f6732b07413c065de04a5604141b2fd5e0f8ebe0597f4991ad79` | `384adc56bfdaa56ae6a6ea9842ad07d01d829a9623e859f39118769e4013c92c` | `runtime+evidence` | `development-only` |
| `kamenicky-keybcs2` | `gated-schema-v1:2-profiles:2-corpora` | `iconvex_specs` | `962d264ee65065537ba416be778cab03e5809fcb8c82c659a7684ef558e01487` | `6ee77c8d54128a66fda3dd57011528d8760dab34cbbd962138c016626bc327a2` | `runtime+evidence` | `development-only` |
| `abicomp` | `gated-schema-v1:1-profile:3-corpora` | `iconvex_specs` | `e08ee7157607bd22154cf7e13bc8167e4cdb440315e1c218e2365618773d3d9c` | `3784ea9b415351c61b2970baeaa4c5b71c37bc197a920412fe2ec2fdde8c1fbb` | `runtime+evidence` | `development-only` |
| `brascii` | `gated-schema-v1:256-byte-classification` | `iconvex_specs` | `4a9451ada3ac1f678284b6a46a978f30db5b9fbeff14f7f8f012d0947ce31ccf` | `9efc2e1a99b13cb665cc2a41bc8d73d82ea89de158c5f3eb5f37cfa3167ae207` | `runtime+evidence` | `development-only` |
| `macos-esperanto` | `gated-schema-v1:256-unique-octets` | `iconvex_specs` | `0b55badb14dcf71c86ae6cc6efae95da1bcad78825ee045e83566874c4f0b602` | `c6d995fce3810de4716f770fd09e15bf8346e749123223bcf105bcb0690ea771` | `runtime+evidence` | `development-only` |
| `vscii-2` | `gated-schema-v1:1-profile:4-corpora` | `iconvex_specs` | `0bac46db8658fb3553de544f4b45a05b513e3e9598a14ee50351bb8ac2cac138` | `be4a0f429f3957425f47bb16decba96cee963d5bb74856821759dcaf982bf7b9` | `runtime+evidence` | `development-only` |
| `kermit-jis7-kanji` | `gated-schema-v1:2-corpora:4-gates` | `iconvex_specs` | `c1f32fbb289df9681bb9c7decd7ec76648ed1086f7a36359c6c73b9f4322f2e4` | `d474c2dd057ab17e66e91184671854c2399f0af264a7b6a44384637ff9fa4b44` | `runtime+evidence` | `development-only` |
| `lotus-lics` | `gated-schema-v1:239-assigned-octets:234-unique-scalars` | `iconvex_specs` | `7a3efcb43ed7edeaa61f3458464554d898eb89c8c07973e4670b8fac84cebdfd` | `a5c50b9db7e1ca309e9a5654154663c087106dc33c0b042ea0f50b36d61c307a` | `runtime+evidence` | `development-only` |
| `us-army-tap-code-pair-values` | `gated-schema-v1:25-pairs:4-corpora` | `iconvex_specs` | `07080a8ce2eae86e0cd47c0e4b1857ca89d1456dd89dfabe5fb18b42275e2ae0` | `3625d307cc1daf3e417be86a0e9fa83bfd099436bd59260c324fc9b63dbf634e` | `runtime+evidence` | `development-only` |
| `pascii-cdac-gist-1.0-2002` | `gated-schema-v1:4-profiles:16-paths` | `iconvex_specs` | `6ce25915c0559abde8f9300c7c5d6ba160de62045ac95c1850b73fe89909890d` | `1f3f1c83ef84ef04e5f866c62acefe8d94fbd761e9b3ff22f47a01f33adf21b5` | `runtime+evidence` | `development-only` |
<!-- recent-source-qualified-benchmark-contract:end -->

## Audited upstream-source families

Run `ICONVEX_PATH=../iconvex ICONVEX_ARCHIVE_PATH=.. MIX_ENV=prod mix run
bench/source_audit_families_benchmark.exs -- --quick`. The executable checks a
representative profile from each newly audited runtime family, validates every
timed result, gates throughput against a recorded-rate/30 floor, and rejects
pathological scheduler-work scaling. CPython's `iso2022_jp_ext` is also run as
an executable oracle: output must match exactly and native encode/decode must
remain within the hard 30x slowdown ceiling. Families without a semantically
identical executable upstream codec use the pinned native floor rather than a
misleading nearby comparator.

The retained Apple M1 arm64 / Elixir 1.19.5 / OTP 28 quick calibration covers 20 native
paths and passed. Throughput spans 3.931–107.021 MiB/s; 2x-input scheduler-work
ratios span 1.607x–3.475x. The CPython comparison measured 0.450x encode and
5.631x decode, both exact and below 30x.

<!-- source-audit-families-benchmark:start -->

| Family | Representative profiles | Recorded quick result |
| --- | --- | --- |
| `utf8-mac` | UTF8-MAC / HFS Plus decomposition | 14.513–20.606 MiB/s |
| `cpython` | ISO-2022-JP-EXT | 3.931–22.620 MiB/s; CPython ratio 0.450x/5.631x |
| `dotnet` | x-Europa, CP50227 | 9.157–107.021 MiB/s |
| `glibc` | IBM423 | 12.131–18.851 MiB/s |
| `windows-best-fit` | Windows-1252 best-fit | 11.855–20.666 MiB/s |
| `iana` | Amiga-1251, PCL HP Desktop, ISO-10646 Basic | 12.245–105.574 MiB/s |
| `ibm-ccsid` | CCSID 1200 | 23.866–24.778 MiB/s |

Benchmark source SHA-256:
`a2e0cc5b82862169e11ad158d3fa8a177fca9ba88f0ae6f108c5f9571d10dd93`.

<!-- source-audit-families-benchmark:end -->

## Unicode 17 kGB3 row/cell projection

Run `ICONVEX_PATH=../iconvex ICONVEX_ARCHIVE_PATH=.. MIX_ENV=test mix run
--no-compile bench/unihan17_kgb3_row_cell_benchmark.exs`. The harness validates
the exact 7,236-row Unicode 17 `kGB3` fixture before timing and compares four
native paths with an independent source parser. GNU libiconv 1.19 has no
equivalent source-qualified `kGB3` row/cell converter, so the report marks that
comparison unavailable instead of substituting a nearby GB encoding.

Two independent post-optimization Apple M1 arm64 / Elixir 1.19.5 / OTP 28
production runs over 1.10 MiB of row/cell data and 1.66 MiB of UTF-8 produced:

| Operation | Throughput range | Worst native/reference | Hard floor |
|---|---:|---:|---:|
| Direct decode to UTF-8 | 4.525–5.438 MiB/s | 0.914x | 0.16 MiB/s |
| Direct encode from UTF-8 | 13.560–17.366 MiB/s | 0.414x | 0.46 MiB/s |
| Composed decode | 3.044–3.622 MiB/s | 1.527x | 0.11 MiB/s |
| Composed encode | 16.477–19.194 MiB/s | 0.455x | 0.55 MiB/s |

Across the complete four-path matrix, measured throughput was
3.044–19.194 MiB/s.

Doubling scheduler work measured 1.990x–2.007x against a hard `1.80..2.20`
gate. Each throughput floor is the slower production rate divided by 30 and
rounded upward, so no path can regress more than the requested 30x. The hot
encoder stores prepacked row/cell bytes and performs neither division nor
temporary UTF-8 binary allocation per character. Runtime source SHA-256:
`8269a3f227cee5220d15adfcea9847986717039a26a7e0d73966d7816d47bfa8`.
Benchmark source SHA-256:
`a79dca2ea76657463d18981cb84d6f917e43d70f0de3ed219de1981b4932f71e`.
Mapping SHA-256:
`63dd2f9d88dc53b9c3603fe798b6f414c578fc22b68d840225a5d44b890d6baf`.

## Content-addressed Iowa punched-card profiles

Run `ICONVEX_PATH=../iconvex ICONVEX_ARCHIVE_PATH=.. MIX_ENV=test mix run
--no-compile bench/iowa_card_profiles_benchmark.exs`. The harness loads and
digest-validates the four normalized Iowa CSVs independently of the runtime
tables. For each of DEC 026, DEC 029, EBCD, and GE 600 it checks packed MSB,
explicit packed LSB, 16BE, and 16LE encode/decode output against a minimal
source-derived reference before timing it.

The 2026-07-18 arm64 / Elixir 1.19.5 / OTP 28 production run used 65,536
characters per timed operation. All 32 native/reference ceilings passed. The
worst native/reference result was 2.926x, and native throughput spanned
approximately 3.69–21.96 million characters/s. All 32 deterministic scheduler
reduction gates passed when doubling 20,000 to 40,000 characters; ratios
spanned 1.962x–2.127x against the hard `1.70..2.30` interval.

GNU libiconv has no exact content-addressed Iowa punched-card identities, so a
nearby named encoding would be a semantically invalid comparator. The benchmark
instead applies the same hard 30x ceiling to independent, digest-pinned Elixir
reference loops. Runtime source SHA-256:
`f1f6ff0a9cdbb03cdb73d65910507fc1e9874295d245645ad083dfc83fc39eaf`.
Benchmark source SHA-256:
`686387f0605bc10b62c99deec6f57185e5bd836acd0d412c7f0390dbce305384`.
