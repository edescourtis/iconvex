# Iconvex

Iconvex is a pure native Elixir/BEAM character-set conversion library based on
GNU libiconv 1.19. The runtime uses no NIFs, ports, operating-system `iconv`, or
external processes.

GNU libiconv 1.19 was released on 2026-03-07 and was the latest release verified
when this port was generated on 2026-07-15. The core Iconvex package exactly
matches GNU's 112 default fixed codecs and 416 spellings/aliases. The separate
`iconvex_extras` package adds the remaining 86 extra, AIX, DOS, OSF/1, and z/OS
codecs and 342 spellings, producing the complete 198-codec/758-alias union.

## Features

- Single-byte and multibyte table codecs, including ISO-8859, Windows, Mac, EUC,
  Big5, and Shift-JIS; extras adds EBCDIC, DOS, and platform extensions.
- Algorithmic UTF-7/8/16/32, UCS-2/4, GB18030:2005/2022, C99, and Java codecs.
- Stateful HZ and ISO-2022-JP/JP-1/JP-2/JP-MS/KR/CN/CN-EXT codecs; extras adds
  ISO-2022-JP-3.
- GNU-compatible `//IGNORE`, `//NON_IDENTICAL_DISCARD`, and `//TRANSLIT` suffixes.
- GNU byte and Unicode substitution formats plus the optional IBM-1047
  `ZOS_UNIX` surface from extras.
- Typed errors, bang functions, buffered transactions, and lazy `Stream` conversion.
- External codec behaviour with validated runtime/config registration, optional
  linear substitution, and direct UTF-8 fast paths.
- Optional `iconvex_extras` application with all GNU non-default codecs.
- Packed mapping tables loaded lazily into `persistent_term`.
- Exact MSB-first bitstrings and byte-backed LSB-first streams for every fixed
  unit width from 1 through 8 bits.

## Installation

Add `iconvex` to `mix.exs` once published, or use the local path while developing:

```elixir
def deps do
  [{:iconvex, path: "../iconvex"}]
end
```

Add the optional package for GNU's complete non-default encoding set:

```elixir
def deps do
  [
    {:iconvex, "~> 0.1"},
    {:iconvex_extras, "~> 0.1"}
  ]
end
```

Starting `iconvex_extras` automatically registers its codecs. No core
configuration or manual registration is needed.

## Usage

```elixir
{:ok, "café"} = Iconvex.convert(<<0x63, 0x61, 0x66, 0xE9>>, "CP1252", "UTF-8")

<<"caf", 0xE9>> = Iconvex.convert!("café", "UTF-8", "CP1252")

{:ok, "Strasse EUR"} =
  Iconvex.convert("Straße €", "UTF-8", "ASCII//TRANSLIT")

{:ok, "AB"} = Iconvex.convert("A😀B", "UTF-8", "ASCII//NON_IDENTICAL_DISCARD")
```

Options can also be passed explicitly:

```elixir
Iconvex.convert(input, from, to,
  invalid: :discard,
  unrepresentable: :discard,
  transliterate: true,
  byte_substitute: "<0x%02x>",
  unicode_substitute: "<U+%04X>",
  on_invalid_byte: fn event -> {:replace, "<byte-#{event.byte}>"} end
)
```

The `byte_substitute` option replaces malformed source bytes; `unicode_substitute`
replaces characters unavailable in the destination. The formats accept GNU-style
`%x`/`%X` fields, including zero-padded widths. With `iconvex_extras` installed,
IBM-1047 newline behavior can be selected by name or explicitly:

Default destination handling mirrors GNU libiconv. An ordinary character that
the target cannot represent is an error. Extended UCS values that reach a
Unicode-family target use U+FFFD when that target defines and can encode the
fallback; `unrepresentable: :discard`, transliteration, or
`unicode_substitute` takes precedence. JAVA and UTF-7 intentionally preserve
isolated 16-bit surrogate units when the source codec exposes them. Generic
UTF-16 and UTF-32 emit a BOM only when at least one target character is emitted.
ISO-2022-JP-2 also implements GNU's case-insensitive `ja`, `ko`, and `zh`
Unicode language tags, including cancellation and streaming state.

```elixir
Iconvex.convert(input, "IBM-1047/ZOS_UNIX", "UTF-8")
Iconvex.convert(input, "UTF-8", "IBM-1047", to_surface: :zos_unix)
```

PETSCII currently comes from the local `iconvex_specs` development workspace
and will move to `iconvex_retro`; consumers must not add that future dependency
until the migration actually exists. The following examples require the
current local Specs application to be available and started.

`on_invalid_byte` handles source bytes a codec cannot decode. The callback gets
an `Iconvex.InvalidByte` containing canonical encoding, error kind, absolute
offset, current byte, and codec error sequence. It returns `:default`, `:error`,
`:discard`, or `{:replace, utf8_or_codepoints}`. This is useful for PETSCII
files whose command bytes are intentionally absent from graphic-character
mappings:

```elixir
controls = fn
  %Iconvex.InvalidByte{byte: 0x0D} -> {:replace, "\n"}
  %Iconvex.InvalidByte{byte: 0x12} -> {:replace, "<reverse-on>"}
  %Iconvex.InvalidByte{} -> :error
end

Iconvex.convert(petscii, "PETSCII", "UTF-8", on_invalid_byte: controls)
```

Iconvex does not label an unmapped byte as a display command, corruption, or
application control. That decision belongs to the file format and caller; the
same callback works in one-shot and lazy Stream conversion.

External fixed-width codecs can declare multi-byte recovery consumption, and
whole-string transforms can declare stop-on-error recovery so callbacks never
restart a desynchronized suffix. See [EXTENDING.md](EXTENDING.md).

Errors contain the source byte offset or unrepresentable Unicode code point:

```elixir
{:error, %Iconvex.Error{kind: :invalid_sequence, offset: 3}} =
  Iconvex.convert(input, "UTF-8", "CP1252")
```

For lazy bounded-memory conversion, input enumerable emits binaries and output
is an Elixir Stream of converted binaries:

```elixir
output =
  File.stream!(path, [], 64 * 1024)
  |> Iconvex.stream!("PETSCII", "UTF-8", on_invalid_byte: controls)
  |> Enum.into("")
```

Multibyte lookahead, multi-code-point target mappings, source offsets, UTF BOM
state, and built-in HZ/ISO-2022/UTF-7 state survive chunk boundaries. A UTF-7
shifted run is committed only after its base64 padding and complete UTF-16
payload have been validated; a plus inside an active shift remains in that
Base64 run, and byte-at-a-time shifted input is processed in linear time.
ISO-2022 diagnostic frames and JP-MS SO/SI state are likewise split-invariant.
Output chunks need not align with input chunks. Conversion failures raise
`Iconvex.Error` during enumeration because earlier output may already have
been consumed. External codecs use the incremental callbacks documented in
[EXTENDING.md](EXTENDING.md).

For a buffered chunked transaction:

```elixir
{:ok, converter} = Iconvex.new("UTF-8", "SHIFT_JIS")
{:ok, <<>>, converter} = Iconvex.feed(converter, chunk1)
{:ok, <<>>, converter} = Iconvex.feed(converter, chunk2)
{:ok, output, finished} = Iconvex.finish_with_state(converter)
{:error, :already_finished} = Iconvex.feed(finished, chunk3)
```

Every source is buffered until `finish/1` or `finish_with_state/1`. Each feed is
O(1), and finalization performs one conversion over the accumulated iodata.
This contract makes chunked output byte-identical to one-shot output across
every split, including stateful designations, malformed-input policies,
Vietnamese composition, multi-code-point destination mappings, and UTF BOMs.
Errors use offsets from the beginning of the complete stream. `finish/1` keeps
the original compatibility return shape; use `finish_with_state/1` when the
terminal converter state and repeated-finish rejection are required.

Use `Iconvex.encodings/0` for canonical names and
`Iconvex.canonical_name/1` to resolve an alias.

## Non-octet packed transports

Codecs that expose one complete signal unit per octet can be packed without
copying their mapping logic:

```elixir
{:ok, packed} = Iconvex.Packed.encode_from_utf8("Hello", "ASCII", 7)
{:ok, "Hello"} = Iconvex.Packed.decode_to_utf8(packed, "ASCII", 7)

{:ok, lsb} = Iconvex.Packed.encode_from_utf8_lsb("hellohello", "ASCII", 7)
"E8329BFD4697D9EC37" = Base.encode16(lsb.data)
{:ok, "hellohello"} = Iconvex.Packed.decode_to_utf8_lsb(lsb, "ASCII")
```

`pack/2` returns an exact MSB-first Elixir bitstring. `pack_lsb/2` returns an
`Iconvex.Packed.LSB` value carrying the byte data, exact meaningful bit count,
and unit width; this prevents final-octet padding from becoming ambiguous.
If unpacking succeeds but the named codec rejects one or more logical units,
the returned `Iconvex.Error` uses `offset_unit: :bit` and a physical bit
offset. MSB errors retain the exact offending bitstring; LSB errors retain a
self-describing `Iconvex.Packed.LSB` fragment rather than exposing temporary
one-byte-per-unit coordinates.
Every unit value and width 1–8 is exhaustively tested in both orders. Wider
formats with codec-specific scalar rules, including UTF-9 and UTF-18, live in
`iconvex_specs` with explicit endian transports.

## External codec libraries

External packages implement `Iconvex.Codec`, then atomically register a module
at startup:

```elixir
defmodule MyLibrary.Codec do
  use Iconvex.Codec

  def canonical_name, do: "X-MY-CODEC"
  def decode(binary), do: MyLibrary.Decoder.decode(binary)
  def decode_discard(binary), do: MyLibrary.Decoder.decode_discard(binary)
  def encode(codepoints), do: MyLibrary.Encoder.encode(codepoints)
  def encode_discard(codepoints), do: MyLibrary.Encoder.encode_discard(codepoints)
  def encode_substitute(codepoints, replacer),
    do: MyLibrary.Encoder.encode_substitute(codepoints, replacer)
end

{:ok, ownership} = Iconvex.register_codec_if_absent(MyLibrary.Codec)
{:ok, output} = Iconvex.convert(input, "X-MY-CODEC", "UTF-8")
```

If `ownership` is a reference, retain it and conditionally unregister with
`Iconvex.unregister_codec(MyLibrary.Codec, ownership)` on shutdown. The
`:existing` result means another caller owns the registration and it must be
left in place. Versioned recovery snapshots preserve registrations and exact
ownership tokens across consecutive supervised registry-worker crashes while
the `:iconvex` application remains running. A clean application stop erases
that recovery state, so registrations never cross a deliberate stop/start
boundary. Replacement publishes at one commit point, so concurrent lookups
resolve the complete old registration or the complete new registration.

Strict per-commit durability is deliberate. Every successful registry
mutation writes a synchronous recovery snapshot of the complete registry to
`:persistent_term`; replacing that term can schedule VM-wide garbage
collection. Keep registration on the control plane rather than a request hot
path. Package authors with many codecs should use the internal `register_set`
path, which publishes the set atomically and amortizes the snapshot to one
checkpoint. Debouncing this write would weaken the documented consecutive
worker-crash guarantee.

Mapping tables and their dense/sparse decode accelerators are also lazy
`:persistent_term` entries. The shipped resident set is bounded by the finite
codec inventories of the applications actually loaded; each table identity
has one base term and at most one term for each of the three derived cache
shapes. Unregistering a table provider erases its base term and all three
derived keys under their build locks, so repeated external-package
load/use/unload cycles do not accumulate provider cache generations. Provider
startup and shutdown therefore belong on the control plane as well; arbitrary
hot-path LRU replacement would impose the VM-wide cost that these immutable
caches are designed to avoid.

If a module's declared name collides with another source, register it under an
explicit source-qualified name. The declared canonical name is replaced for
that registration; module aliases and option aliases are still registered and
collision-checked:

```elixir
:ok =
  Iconvex.register_codec(MyLibrary.Codec,
    canonical: "MY-SOURCE-X-MY-CODEC",
    aliases: ["MY-SOURCE-MYCODEC"]
  )
```

Consumer configuration can load modules automatically with
`config :iconvex, external_codecs: [MyLibrary.Codec]`. Tuple entries accept the
same `:canonical` and `:aliases` options. Registered codecs appear
in `Iconvex.encodings/0`; built-in names cannot be overridden. See
[EXTENDING.md](EXTENDING.md) for callback/error contracts, aliases, stateful
streaming, required linear substitution and optional zero-copy UTF-8 callbacks, performance results, and an
external-library test checklist. `iconvex_extras` is the reference external
codec package: it shares core conversion engines while keeping every optional
mapping table and codec module outside the core artifact.

The distributed Extras, Telecom, and Specs applications install one atomic
managed registration set apiece. Their integration contract requires all four
packages to run together in any start order: their 2,093 canonical names must
remain unique, while all 227 overlapping Specs/Extras names use deterministic
canonical-first, package-priority claims. Stopping a winning package must expose
the remaining claim without a transient lookup gap. Third-party registrations
through the public API remain strict: any distinct module claiming an existing
name gets a `{:name_conflict, name}` error rather than silently joining that
managed set.

The generated full-stack codec comparison at `../ICONVEX_FULL_STACK_SUPPORT.md`
is workspace-level integration evidence for all 2,093 canonical names and GNU
libiconv 1.19. It is intentionally not included in this package artifact; use
the workspace-relative path only from the sibling-package source checkout.

## Current Specs package and planned split

The local `iconvex_specs` development workspace currently supplies
1,841 byte-pipeline codecs: 1,050 archive codecs and 791 non-archive codecs. Its
release inventory contains 1,843 catalogued Specs codec identities; catalogued
research identities are not automatically runtime registrations. It also
supplies four property-token mapping APIs, which are intentionally not counted
as byte codecs. Those are current implementation and conformance surfaces; they
are not seven already released leaf packages.

The seven replacement packages do not exist yet:

- `iconvex_unicode`
- `iconvex_standards`
- `iconvex_bibliographic`
- `iconvex_retro`
- `iconvex_platforms`
- `iconvex_icu`
- `iconvex_icu_archive`

Until every codec has an exact generated owner, clean-consumer coverage, and a
release rehearsal, the proposed split must not be published as if it were
implemented. In the final topology, `iconvex_specs` becomes an unpublished
integration, generation, research, and conformance workspace rather than a
runtime catch-all.

The current integration harness is GREEN in checkout mode. Its plain documented
command resolves all seven sibling packages without environment overrides, and
its two contracts run every extension start order and fallback lifecycle under
an explicit 300-second per-test bound. This baseline must remain GREEN before
the 1,841-codec ownership freeze or any package-extraction release claim.

PETSCII's final owner remains `iconvex_retro`; punched cards, FIELDATA, and TI
calculator profiles belong there too. Punycode and Unihan telegraph
property-token mappings belong in `iconvex_standards`, while source-qualified
IBM compatibility profiles require per-codec ownership review rather than a
whole-directory move.

## Operational and trust boundaries

- One-shot conversion and the buffered `new/feed/finish` API materialize the
  complete source and, on general paths, a Unicode code-point list. Use
  `stream/4` or `stream!/4` for lazy bounded-memory conversion. Applications
  using the materializing APIs must enforce an input-size limit derived from
  their own memory budget; Iconvex deliberately does not choose a universal cap.
- Runtime mapping tables load lazily. A process using every core table should
  budget more than the measured 62.9 MiB flat decoded-table size, plus BEAM map,
  code, output, and temporary-list overhead. Typical workloads load only touched
  tables; optional mappings remain in `iconvex_extras`/other external packages.
- Substitution printf widths are validated and capped at 65,536 digits. Unknown,
  duplicate, or malformed options return typed request errors.
- Shipped table/transliteration ETF assets use safe decoding, versioned caches,
  and serialized cold loads. External codec modules remain trusted application
  code: callback exceptions may propagate. A malformed `encode_substitute/2`
  result returns a typed `{:invalid_codec_callback_return, ...}` request error.

## Verification

```sh
mix test
MIX_ENV=prod mix run bench/benchmark.exs
MIX_ENV=prod mix run bench/external_codec_benchmark.exs
GNU_ICONV=/path/to/gnu-libiconv-1.19/bin/iconv \
  MIX_ENV=prod mix run tools/exhaustive_unicode_differential.exs
```

No public source-repository URL is currently declared for this distribution.
The public source monorepo is
[`edescourtis/iconvex`](https://github.com/edescourtis/iconvex). ExDoc source
links are pinned to the matching `v0.1.0` tag and the `iconvex/` subdirectory,
so published documentation resolves to the exact release source.

The repository carries
267 byte-exact upstream files plus one derived configured `Makefile` in its
268-file GNU libiconv 1.19 test-fixture set (9.0 MB). Separate
and combined aggregate SHA-256 values verify their provenance boundary. The set
is intentionally excluded from the consumer Hex artifact; generated runtime
tables and public conformance documents remain in that artifact. Core ExUnit
runs the applicable default-codec cases; `iconvex_extras` carries and runs the
92 extra charmap/inverse fixtures plus ISO-2022-JP-3 and IBM-1047 behavioral
cases.
Together the suites port the 164 stateless charmap/inverse checks, all 27 snippet
round-trips, the complete GB18030 supplementary range,
transliteration/substitution/EBCDIC/discard checks, and the four C regression
tests. The z/OS filesystem-tag check remains platform-only, just as upstream
skips it outside z/OS. See
[UPSTREAM_TEST_COVERAGE.md](UPSTREAM_TEST_COVERAGE.md) for the machine-checked
traceability matrix. [SUPPORTED_ENCODINGS.md](SUPPORTED_ENCODINGS.md) lists all
198 codecs side-by-side with package ownership and GNU definition/default-build
status. Also see
[EXHAUSTIVE_UNICODE_DIFFERENTIAL.md](EXHAUSTIVE_UNICODE_DIFFERENTIAL.md) for the
112-codec core run, and the extras package's report for the combined 198-codec,
1,114,112-code-point forward/reverse/cross-decode differential against GNU
libiconv 1.19. The sequential UCS-4BE corpus contains all 1,112,064 Unicode
scalar values plus all 2,048 surrogate code points; surrogates are code points,
not scalar values. The combined directional performance gate records the
fastest of three isolated samples and enforces a 30x-GNU ceiling. Also see
[BENCHMARKS.md](BENCHMARKS.md) and
[TDD_LOG.md](TDD_LOG.md).
The disposition of every independent review finding is in
[DEEP_DIVE_REMEDIATION.md](DEEP_DIVE_REMEDIATION.md).

`elixir tools/release_check.exs` builds docs, unpacks the exact Hex artifact into
a temporary directory, and verifies compilation and representative conversions
from a clean consumer project.

To regenerate the registry, mappings, extensions, and transliteration table from
an unpacked GNU libiconv 1.19 source tree:

```sh
elixir tools/generate_registry.exs /path/to/libiconv-1.19
mix format
```

The generator writes the 112 default codecs into this package and the exact
86-codec complement into the sibling `iconvex_extras` package.

## License

Iconvex and its derived GNU mapping/transliteration data are distributed under
LGPL-2.1-or-later. The repository-only upstream test mirror includes GNU's
test-only `uniq-u.c`, licensed GPL-3.0-only; that source and its license text are
excluded from the Hex artifact. See [LICENSE](LICENSE),
[GNU GPL 3.0](https://www.gnu.org/licenses/gpl-3.0.html), and [NOTICE](NOTICE).
