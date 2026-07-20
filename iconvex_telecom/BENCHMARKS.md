# Benchmarks

Run:

```sh
ICONVEX_PATH=../iconvex MIX_ENV=prod mix run bench/gsm0338_benchmark.exs
```

Representative result from 2026-07-15 on Apple M1, Darwin 25.3.0 arm64,
OTP 28, Elixir 1.19.5. Each bulk result is the median of 12 measured runs after
three warmups; garbage collection is performed before each measured run.

| Case | Throughput | Median |
|---|---:|---:|
| Direct GSM → UTF-8 | 12.31 MiB/s | 99.95 ms |
| Old binary-iodata decoder | 11.21 MiB/s | 109.70 ms |
| Iconvex GSM → UTF-8 | 12.39 MiB/s | 99.32 ms |
| Direct UTF-8 → GSM | 11.33 MiB/s | 113.65 ms |
| Old tiny-binary encoder | 7.44 MiB/s | 172.98 ms |
| Iconvex UTF-8 → GSM | 10.31 MiB/s | 124.91 ms |

For 160-byte telecom-sized inputs the same run measured 185,487 decodes/s and
103,089 encodes/s.

The retained A/B baselines show why the final hot paths use BEAM's Unicode list
conversion and integer iodata: 9.8% faster decoding and 52.3% faster encoding
than the preliminary per-character-binary implementations on this run.
Numbers vary with scheduler and heap state; the benchmark script is the source
of truth for the current machine.

`bench/transport_bench.exs` on the same VM measured:

| Protocol operation | Throughput |
|---|---:|
| Pack 160 septets | 80,878 ops/s |
| Unpack 160 septets | 104,085 ops/s |
| Encode 15 TBCD digits | 5,300,541 ops/s |
| Auto-encode mixed SIM alpha identifier | 143,340 ops/s |

The same script also benchmarks the telegraph codecs on 160 characters. The
input produces 191 signal units because it repeatedly crosses the
letters/figures boundary.

| Telegraph operation | Throughput |
|---|---:|
| ITA2 encode, 160 characters | 308,870 ops/s |
| ITA2 decode, 191 units | 782,666 ops/s |
| ITA2 pack, 191 five-bit units | 472,444 ops/s |
| ITA2 unpack, 191 five-bit units | 790,525 ops/s |
| CCIR 476 encode, 160 characters | 304,667 ops/s |
| CCIR 476 decode, 191 units | 743,641 ops/s |
| CCIR 476 pack, 191 seven-bit units | 470,205 ops/s |
| CCIR 476 unpack, 191 seven-bit units | 1,060,733 ops/s |

These figures are from the same Apple M1 / OTP 28 / Elixir 1.19.5 host. A
GREEN-preserving optimization replaced decoder map lookups with 32-entry
tuples and fused CCIR↔ITA2 state conversion into one pass. On this workload,
ITA2 decode rose from 216,165 to 782,666 ops/s; CCIR encode rose from 205,340
to 304,667 ops/s and decode from 159,270 to 743,641 ops/s. The displaced
two-pass figures are retained here as the A/B baseline.

The same transport benchmark now includes the stateless AIS6 paths:

| AIS operation | Throughput |
|---|---:|
| Encode 160 Table 45 characters | 655,130 ops/s |
| Decode 160 unpacked units | 1,161,278 ops/s |
| Pack 160 six-bit units | 500,560 ops/s |
| Unpack 160 six-bit units | 955,662 ops/s |
| Armor 160 AIVDM/AIVDO units | 634,997 ops/s |
| Dearmor 160 AIVDM/AIVDO units | 688,066 ops/s |

AIS6 uses a 64-element tuple for decode and a compile-time inverse map for
encode; transport paths build integer iodata or bitstrings in one linear pass.

ITU-T S.2 case preservation adds bounded three-letter lookahead and a larger
state machine. The same run measured 183,153 encodes/s for 140 mixed-case
characters and 595,666 decodes/s for the resulting 189 units.

## Expanded telecom inventory

The benchmark now covers every non-GSM codec family added after the original
run. A production-mode run on the same Apple M1 / OTP 28 / Elixir 1.19.5 host
on 2026-07-15 measured:

| Codec operation | Throughput |
|---|---:|
| ITA1 encode, 140 characters | 163,539 ops/s |
| ITA1 decode, 140 units | 526,832 ops/s |
| ITA1 pack / unpack, 140 units | 103,988 / 230,538 ops/s |
| ITA3 encode / decode, 160 characters / 191 units | 103,982 / 123,325 ops/s |
| ITA3 pack / unpack, 191 units | 151,605 / 453,673 ops/s |
| ITA4 encode / decode, 160 characters / 191 units | 70,182 / 209,789 ops/s |
| ITA4 pack / unpack, 191 units | 118,700 / 581,028 ops/s |
| T.50/IA5 encode / decode, 160 units | 254,639 / 264,489 ops/s |
| T.50/IA5 pack / unpack, 160 units | 177,882 / 278,856 ops/s |
| Morse encode, 160 characters | 64,932 ops/s |
| Morse decode, 659 envelope octets | 15,283 ops/s (9.6 MiB/s) |

`bench/five_unit_shift_benchmark.exs` retains the displaced generic map-lookup
state engine and alternates it with the optimized implementation over 12 runs,
reporting median throughput. Holding the active tuple/map across ordinary
characters and using a compile-time cross-register index produced:

| Shared state operation | Map baseline | Optimized | Change |
|---|---:|---:|---:|
| US-TTY encode, 160 characters | 92,119 ops/s | 134,756 ops/s | +46.3% |
| US-TTY decode, 191 units | 231,642 ops/s | 278,287 ops/s | +20.1% |
| MTK-2 encode, 140 characters | 92,996 ops/s | 124,897 ops/s | +34.3% |
| MTK-2 decode, 169 units | 227,288 ops/s | 260,760 ops/s | +14.7% |

The full functional suite is the acceptance gate for this optimization; the
benchmark does not weaken strict, discard, shift, alias, or error-offset
semantics.

## Unified packed facade

Run `ICONVEX_PATH=../iconvex MIX_ENV=prod mix run
bench/packed_facade_benchmark.exs`. It alternates the retained GSM whole-message
integer implementation with the generic bounded streaming loop over 65,540
septets. Isolated Apple M1 / OTP 28 / Elixir 1.19.5 medians:

| Operation | Median | Relative to retained path |
|---|---:|---:|
| Retained integer pack | 528.70 ms | 1.00× |
| Streaming generic pack | 3.05 ms | 173.51× |
| Retained integer unpack | 254.83 ms | 1.00× |
| Streaming generic unpack | 4.27 ms | 59.64× |

The streaming loop keeps only a bounded shift buffer, making memory linear in
the result rather than in an ever-growing bignum. The facade additionally caches
its immutable 51-profile inventory. A warm 10,000-lookup sample measured about
2.05 µs per canonical-name lookup.

## IBM Six-Bit Transcode

Run `ICONVEX_PATH=../iconvex MIX_ENV=prod mix run
bench/ibm_six_bit_transcode_benchmark.exs`. Two isolated runs on 2026-07-18
used Apple M1 / Darwin 25.3.0, OTP 28, and Elixir 1.19.5. Each number is a
seven-run median after two warmups over 65,536 unpacked units.

| Profile / operation | Throughput across two runs |
|---|---:|
| GA27-3005-3 decode | 40.401–41.834 MiB/s |
| GA27-3005-3 encode | 33.976–34.485 MiB/s |
| GA27-3005-3 LSB pack / unpack | 30.605–31.002 / 14.535–15.842 MiB/s |
| GA27-3005-3 MSB pack / unpack | 30.972–31.032 / 13.934–14.110 MiB/s |
| GA27-3004-2 decode | 41.145–42.258 MiB/s |
| GA27-3004-2 encode | 33.422–33.894 MiB/s |
| GA27-3004-2 LSB pack / unpack | 29.016–29.663 / 14.265–14.441 MiB/s |
| GA27-3004-2 MSB pack / unpack | 29.990–30.019 / 14.200–14.530 MiB/s |

GNU libiconv has no matching Transcode codec, so the reproducible comparator
digest-validates and parses both packaged 64-row IBM CSVs into an independent
dense tuple/map, then uses its own bit-buffer implementation. It never derives
tables from the runtime codec, and the packed reference paths call neither
native packed API. All 12 native
outputs were byte-exact equal to their references. Native/reference latency was
0.439×–0.891× (lower is faster), well inside the required 30× ceiling.
Scheduler-reduction measurements run in fresh one-million-word heap workers so
an unrelated garbage-collection step cannot be charged to only one side of the
comparison. Fresh 20,000-to-40,000-unit scaling was 1.982×–2.050× across both
profiles and all six operations. The benchmark fails on any output mismatch,
native/reference ratio above 30×, or reduction ratio outside 1.60×–2.60×;
ordinary-heap wall-clock medians remain the end-to-end performance measurement.
