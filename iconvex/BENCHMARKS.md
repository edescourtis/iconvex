# Benchmarks

Measured on an Apple M1 running macOS 26.3, OTP 28, and Elixir 1.19.5. Each
result is the median of 12 production-build iterations after 3 warmups. Rates
are based on input bytes; results vary by machine, runtime, and data mix.

Run with:

```sh
MIX_ENV=prod mix run bench/benchmark.exs
```

| Conversion | Baseline MiB/s | Optimized MiB/s | Speedup |
|---|---:|---:|---:|
| UTF-8 -> UTF-8 | 23.69 | 134.70 | 5.69x |
| CP1252 -> UTF-8 | 3.81 | 9.48 | 2.49x |
| UTF-8 -> CP1252 | 5.02 | 7.44 | 1.48x |
| SHIFT_JIS -> UTF-8 | 3.89 | 5.72 | 1.47x |
| UTF-8 -> SHIFT_JIS | 17.91 | 20.51 | 1.15x |
| GB18030 -> UTF-8 | 2.18 | 5.25 | 2.41x |
| UTF-8 -> GB18030 | 7.87 | 14.96 | 1.90x |

The exhaustive packed-table conformance test also fell from 36.9 seconds to
1.8 seconds after replacing a quadratic table encoder with a linear specialized
loop.

## Optimizations retained

- Valid UTF-8 identity conversion returns the original reference after validation.
- Single-byte table decoding writes UTF-8 directly without an intermediate list.
- Single-codepoint table encoding uses a linear recursive loop.
- GB18030 dispatches by byte shape instead of performing repeated longest-map probes.
- Mapping terms are compressed on disk, loaded lazily, and cached in `persistent_term`.

Strict conversion uses the fast paths. Discard conversion uses linear native
loops for each codec family, preserving table longest matches and stateful
designation/shift state without restarting at every rejected code point.

The exhaustive differential run exposed a quadratic `length/1` call in the
ISO-2022-JP-3 JIS X 0213 selector. The all-scalar case exceeded 90 seconds before
interruption and takes about 1.2–2.3 seconds after the constant-time head-pair
probe. The complete 198-codec forward/reverse/cross-decode run took 171.36 seconds
on the benchmark machine; per-codec timings are recorded in
`EXHAUSTIVE_UNICODE_DIFFERENTIAL.md`.

## Final verification after upstream-suite port

The same production benchmark was rerun after adding the complete test corpus,
substitution policies, and EBCDIC surface handling. A final warm run measured:

| Conversion | MiB/s | Median |
|---|---:|---:|
| UTF-8 -> UTF-8 | 158.19 | 7.38 ms |
| CP1252 -> UTF-8 | 11.69 | 82.84 ms |
| UTF-8 -> CP1252 | 6.90 | 169.34 ms |
| SHIFT_JIS -> UTF-8 | 5.70 | 128.46 ms |
| UTF-8 -> SHIFT_JIS | 20.33 | 54.03 ms |
| GB18030 -> UTF-8 | 4.71 | 162.11 ms |
| UTF-8 -> GB18030 | 11.88 | 70.25 ms |

The new policy handling does not change the strict fast-path dispatch. Throughput
varies between runs because these are scheduler/GC-sensitive pure-BEAM workloads;
the benchmark script records exact inputs, warmups, iterations, medians, and
reductions for reproducibility.

## External codec dispatch

External codecs are registered through a serialized process, but conversions
read their immutable metadata directly from protected ETS with concurrent-read
optimization. Built-in names resolve from compiled maps first and never touch
ETS. Registered codec modules may provide direct UTF-8 callbacks to avoid an
intermediate code-point list.

Run the dedicated benchmark with:

```sh
MIX_ENV=prod mix run bench/external_codec_benchmark.exs
```

Apple M1, OTP 28, Elixir 1.19.5; median of 12 iterations after 3 warmups:

| External ASCII conversion | Throughput | Median |
|---|---:|---:|
| Generic external -> UTF-8 | 30.82 MiB/s | 33.42 ms |
| Zero-copy external -> UTF-8 | 591.26 MiB/s | 1.74 ms |
| UTF-8 -> generic external | 19.93 MiB/s | 51.68 ms |
| UTF-8 -> zero-copy external | 586.21 MiB/s | 1.76 ms |

| Name lookup | Cost |
|---|---:|
| Built-in string | 1267.6 ns/op |
| External string | 1713.8 ns/op |
| External module | 247.1 ns/op |

The same run of the original bundled-codec benchmark measured 160.17 MiB/s for
UTF-8 identity, 17.65 MiB/s for CP1252 decoding, 20.68 MiB/s for Shift-JIS
encoding, and 15.01 MiB/s for GB18030 encoding. External support therefore did
not introduce a material built-in throughput regression on this run.

## Post-split release verification

After moving all 86 non-default codecs into `iconvex_extras`, the core production
benchmark was rerun on Apple M1, OTP 28, and Elixir 1.19.5:

| Conversion | MiB/s | Median |
|---|---:|---:|
| UTF-8 -> UTF-8 | 244.20 | 4.78 ms |
| CP1252 -> UTF-8 | 24.36 | 39.74 ms |
| UTF-8 -> CP1252 | 12.51 | 93.42 ms |
| SHIFT_JIS -> UTF-8 | 8.44 | 86.73 ms |
| UTF-8 -> SHIFT_JIS | 31.93 | 34.41 ms |
| GB18030 -> UTF-8 | 7.68 | 99.28 ms |
| UTF-8 -> GB18030 | 22.06 | 37.82 ms |

The extras package's byte-identical CP932/CP943 paired benchmark measured only
1.6% decode and 0.6% encode overhead for external-package dispatch. Full values
and reductions are in `iconvex_extras/BENCHMARKS.md`.

## Fixed-width bit packing

Run `MIX_ENV=prod mix run bench/packed_benchmark.exs`. It executes strict
packing and unpacking over 1 MiB of units, with two warmups and the median of
seven production-build samples. An isolated Apple M1 / OTP 28 / Elixir 1.19.5
run measured:

| Width/order | Pack MiB/s | Unpack MiB/s |
|---|---:|---:|
| 5-bit MSB | 61.41 | 14.06 |
| 5-bit LSB | 23.27 | 19.25 |
| 6-bit MSB | 162.87 | 40.14 |
| 6-bit LSB | 165.04 | 43.37 |
| 7-bit MSB | 47.31 | 14.55 |
| 7-bit LSB | 21.30 | 15.90 |

The implementation validates and emits in one linear pass. Generic widths use
bounded 4,096-unit binary chunks rather than allocating one bitstring or list
node per unit. Six-bit MSB and LSB paths additionally consume four units as one
24-bit group. Exact bit length, invalid-unit offsets, truncated groups, and
final-octet padding validation remain part of the timed API.

## Post-review performance gate

After the deep-dive fixes, the combined all-scalar differential exposed repeated
table searches in stateful encoders and per-codepoint string formatting in JAVA
and C99. Versioned precedence maps now reduce ISO-2022/HZ encoding to one map
lookup per scalar; escape codecs use direct nibble conversion; compatible
Unicode pairs transcode through BEAM's Unicode BIF with exact native fallback.

Same Apple M1 / OTP 28 / Elixir 1.19.5 process and corpus:

| Codec | Before | Final | Improvement |
|---|---:|---:|---:|
| ISO-2022-JP-2 | 13,172 ms | 332 ms | 39.7x |
| ISO-2022-JP-MS | 10,350 ms | 286 ms | 36.2x |
| ISO-2022-JP-3 | 9,488 ms | 508 ms | 18.7x |
| ISO-2022-CN-EXT | 6,020 ms | 365 ms | 16.5x |
| JAVA | 7,167 ms | 1,677 ms | 4.3x |
| C99 | 5,543 ms | 1,283 ms | 4.3x |
| HZ | 2,220 ms | 275 ms | 8.1x |

The original optimized 198-codec forward/reverse/cross-decode gate fell from
261,695 ms to 43,849 ms. It fails if any codec exceeds 30.00x its GNU 1.19
reference time. The latest source-bound rerun took 104,191 ms: 198/198 codecs
were byte-exact, with zero mismatches and zero performance failures. It covers
all 1,114,112 Unicode code points and records the fastest of three isolated
samples per direction; its worst measured slowdown was CP943 at 23.12x.

A reproducibility audit retained every outcome rather than discarding a failed
sample. The first post-optimization complete run was byte-exact but recorded
non-reproducing reverse outliers for IBM-1148 (103.89x) and ISO-8859-16
(42.75x). An immediate focused rerun passed both beneath 10x, and the second
complete run passed all 198 codecs with C99 worst at 23.68x. The failed run
remains recorded as scheduler/CPU-frequency noise rather than being hidden or
used to relax the unchanged 30.00x gate.

Final production application benchmark:

| Conversion | MiB/s | Median |
|---|---:|---:|
| UTF-8 -> UTF-8 | 233.14 | 5.01 ms |
| CP1252 -> UTF-8 | 28.09 | 34.47 ms |
| UTF-8 -> CP1252 | 12.62 | 92.60 ms |
| SHIFT_JIS -> UTF-8 | 8.94 | 81.92 ms |
| UTF-8 -> SHIFT_JIS | 32.06 | 34.26 ms |
| GB18030 -> UTF-8 | 8.33 | 91.60 ms |
| UTF-8 -> GB18030 | 23.73 | 35.16 ms |
