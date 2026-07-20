# Iconvex Extras

Optional GNU libiconv 1.19 codecs excluded from the default build. Installing
and starting `iconvex_extras` registers 86 codecs with Iconvex: 7 GNU extra,
9 AIX, 15 DOS, 2 OSF/1, and 53 z/OS codecs.

```elixir
def deps do
  [
    {:iconvex, "~> 0.1"},
    {:iconvex_extras, "~> 0.1"}
  ]
end
```

No extra configuration required. `Iconvex.encodings/0` returns 198 codecs while
this application runs and returns the 112 GNU default codecs without it.

The package contains 85 packed mapping tables plus the ISO-2022-JP-3 state
machine wrapper. Its application atomically registers one managed 86-codec set
and removes only that set when stopped. Shared core engines retain native linear
strict/discard paths and state across invalid input. The registration token
survives a supervised Iconvex registry-worker restart.

Extras can run beside Telecom and all 1,841 runtime Specs codecs in any start order.
For the 227 Specs/Extras name overlaps, canonical claims win first and Extras'
GNU identity wins equal-kind aliases; stopping Extras immediately exposes the
Specs fallback. The complete four-package registry has 2,093 unique canonical
names.

The generated full-stack codec comparison at `../ICONVEX_FULL_STACK_SUPPORT.md`
is workspace-level integration evidence for all 2,093 canonical names and GNU
libiconv 1.19. It is intentionally not included in this package artifact; use
the workspace-relative path only from the sibling-package source checkout.

## Exact support and verification

[SUPPORTED_ENCODINGS.md](SUPPORTED_ENCODINGS.md) is the generated complete
86-codec list with GNU definition origin. The parent project's matrix lists all
198 codecs and package ownership side by side.

The package ports every applicable extra mapping and inverse fixture, the
ISO-2022-JP-3 snippet round-trip, IBM-1047 surface behavior, long invalid-input
discard, lifecycle registration, and exact 758-alias union checks. Its committed
sequential UCS-4BE corpus contains every one of the 1,114,112 Unicode code
points: 1,112,064 scalar values plus all 2,048 surrogate code points, which are
not scalar values.
[EXHAUSTIVE_UNICODE_DIFFERENTIAL.md](EXHAUSTIVE_UNICODE_DIFFERENTIAL.md) records
the source-bound 198-codec forward, reverse, and cross-decode match against GNU
libiconv 1.19. The differential runner now keeps correctness and timing
independent: byte output comes from the pinned GNU CLI, while a benchmark-only
C helper linked from that CLI's installation prefix reads input before its
`CLOCK_MONOTONIC` window and reports in-memory conversion-engine microseconds.
Iconvex receives an already-resident binary. Both sides take the fastest of
three isolated samples, calibrate sub-millisecond work without a denominator
clamp, and gate forward and reverse ratios separately at 30x.

Changing either runtime or benchmark harness invalidates the committed report
until the complete 198-codec run is regenerated. The final source-bound run is
green over all 1,114,112 code points: EUC-JISX0213 is 2.63x forward/17.21x
reverse and CP943 is 3.70x/23.12x, with zero byte mismatches.

```sh
ICONVEX_PATH=../iconvex mix test
ICONVEX_PATH=../iconvex mix compile --warnings-as-errors
ICONVEX_PATH=../iconvex MIX_ENV=prod mix run bench/benchmark.exs
GNU_ICONV=/path/to/gnu-libiconv-1.19/bin/iconv \
  ICONVEX_PATH=../iconvex MIX_ENV=prod \
  mix run tools/exhaustive_unicode_differential.exs
```

The exhaustive performance run requires a C11 compiler. The helper under
`tools/` is offline benchmark/test tooling only; it is neither a NIF nor a
runtime dependency of Iconvex Extras.

`ICONVEX_PATH` is only the sibling-checkout development override. Published
builds use the normal `{:iconvex, "~> 0.1.0"}` Hex dependency.
