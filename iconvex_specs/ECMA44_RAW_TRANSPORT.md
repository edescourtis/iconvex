# ECMA-44 raw punched-card transport

`Iconvex.Specs.ECMA44` implements the complete ECMA-44 correspondence between
opaque 7-bit or 8-bit code combinations and 12-row punched-card patterns. It
is deliberately not an `Iconvex.Codec`: ECMA-44 does not supply one universal
Unicode repertoire, and national ECMA-6/ECMA-43 character meanings must not be
invented by mapping raw bytes to Latin-1 or private-use scalars.

The two discoverable raw profiles are:

- `ECMA-44-7BIT-CARD-RAW`, which accepts code combinations `00` through `7F`;
- `ECMA-44-8BIT-CARD-RAW`, which accepts all combinations `00` through `FF`.

Both expose a list-of-masks representation, an exact 12-bit MSB-first Elixir
bitstring, an explicit library-defined `Iconvex.Packed.LSB` representation,
and zero-padded `16BE` and `16LE` words. ECMA-44 itself names physical card
rows and does not define the packed bit order or a 16-bit byte order.

```elixir
alias Iconvex.Specs.ECMA44

{:ok, [0xC80]} = ECMA44.encode_masks(<<0x6B>>, :eight_bit)
{:ok, <<0xC80::12>>} = ECMA44.encode_packed(<<0x6B>>, :eight_bit)
{:ok, <<0x0C, 0x80>>} = ECMA44.encode_words(<<0x6B>>, :eight_bit, :big)
{:ok, <<0x6B>>} = ECMA44.decode_words(<<0x80, 0x0C>>, :eight_bit, :little)
```

Chunk decoders return original code-combination bytes plus an incomplete
physical-unit suffix. They never return text or UTF-8. Packed errors use
physical bit offsets; word errors use byte offsets.

The independently transcribed 256-cell table and provenance are in
`priv/sources/ecma-44`. The PDF is not packaged. Stable audit digests are:

- official PDF SHA-256:
  `09b71ed57db7a0b2c1e9bc7006f001df198450f37b706c01d2754ddb5a5de228`;
- transcribed CSV SHA-256:
  `834abb8180af52f790f09ace4f6bc75953a2c8e0df98bb5dcb33f62d3a644995`;
- masks as 256 unsigned 16-bit BE words:
  `bf6d824c690380439344c99e4ba68887241305b243456390aa23b8d94cc68119`;
- masks packed as contiguous 12-bit MSB units:
  `218cced6aee83c5ec3fa8823761556c60f872ea367d24c66e2dd43a5b83b6a75`.

## Benchmark reference

Command, run on 2026-07-17 with Elixir 1.19.5 / OTP 28.3:

```console
MIX_ENV=test mix run --no-compile bench/ecma44_benchmark.exs
```

Representative full-run throughput ranged from approximately 8.3 million
units/second for 8-bit `16LE` decode to 249 million units/second for mask
encoding. Serialized encoders were approximately 29–61 million units/second;
packed decoders were approximately 14–25 million units/second.

All twenty hard reduction gates passed. Doubling input from 20,000 to 40,000
units produced ratios from `1.857x` through `2.006x`, within the enforced
`1.75x..2.25x` linearity band. `test/ecma44_benchmark_test.exs` executes the
quick benchmark in CI and requires every mode, transport, direction, and gate.
