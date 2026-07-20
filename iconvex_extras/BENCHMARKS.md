# Benchmarks

Run the production benchmark with:

```sh
ICONVEX_PATH=../iconvex MIX_ENV=prod mix run bench/benchmark.exs
```

It compares CP943 from this external package with core CP932 over byte-identical
mapping data, in both directions. This isolates package/registry dispatch from
codec algorithm and input differences. Results from the release verification
run are recorded below.

Apple M1, OTP 28, Elixir 1.19.5; median of 12 measured iterations after 3
warmups:

| Conversion | Throughput | Median | Reductions |
|---|---:|---:|---:|
| Core CP932 -> UTF-8 | 8.27 MiB/s | 88.61 ms | 2,566,932 |
| Extras CP943 -> UTF-8 | 8.14 MiB/s | 89.98 ms | 2,590,570 |
| UTF-8 -> core CP932 | 30.76 MiB/s | 35.72 ms | 1,688,833 |
| UTF-8 -> extras CP943 | 30.57 MiB/s | 35.93 ms | 1,691,730 |

Relative external-package cost is 1.6% for decoding and 0.6% for encoding in
this paired run. Both paths use the same packed data and native linear codec
engine; the difference is external registry and table-provider dispatch.

## Fair GNU conversion-engine gate

The exhaustive differential does not time `System.cmd/3`. The pinned GNU CLI
still produces the correctness bytes, but its process startup, file reads, and
stdout are excluded from performance ratios. A C11 helper under `tools/`,
linked to the GNU libiconv 1.19 prefix derived from `--iconv`, reads each input
before an internal `CLOCK_MONOTONIC` window and reports conversion-engine time
in fractional microseconds. Iconvex is measured with the same input already in
memory. Each side selects the fastest of three isolated samples; calibrated
batches give sub-millisecond conversions a measurable per-call value without a
denominator clamp. Forward and reverse ratios retain the independent 30x gate.

The final Extras-owned hotspot smoke after the review fixes used every one of
the 1,114,112 UCS-4BE code points and GNU `//IGNORE`. Both encoded streams,
both own round trips, and both cross-decodes were byte-exact:

| Codec/direction | Iconvex | GNU engine | Slowdown |
|---|---:|---:|---:|
| EUC-JISX0213 forward | 24,845.375 µs | 9,449.0 µs | 2.63x |
| EUC-JISX0213 reverse | 2,361.708 µs | 137.25 µs | 17.21x |
| CP943 forward | 85,254.75 µs | 23,037.0 µs | 3.70x |
| CP943 reverse | 2,542.792 µs | 110.0 µs | 23.12x |

The helper also checks that its converted byte count equals the independently
captured CLI output size on every timed direction. It is offline benchmark and
test tooling only; the Extras runtime has no C, NIF, or port dependency.
