# Iconvex integration harness

This is a non-publishable development project for testing the complete Iconvex
package family from sibling checkouts. Its dependencies are marked
`runtime: false`, so each test controls extension startup and shutdown rather
than inheriting Mix's dependency order.

Run it from this directory:

```sh
mix test --warnings-as-errors
```

When all sibling packages are checked out as one repository, GitHub discovers
the root [`.github/workflows/iconvex.yml`](../.github/workflows/iconvex.yml).
That workflow runs Core on the supported OTP/Elixir matrix, then compiles and
tests Extras, Telecom, Specs, all three archive shards, and this integration
harness from their actual package directories. Core's package-local workflow
remains the standalone-repository CI entry point.

That plain checkout command resolves Core, Extras, Telecom, Specs, and all three
archive shards from their seven sibling directories; no checkout-only
environment overrides or Hex downloads are required. Every dependency is
compile-only, and Core plus the archive shards are explicit dependency
overrides. The lifecycle contracts carry an explicit 300-second per-test bound.

The two registry contracts start Extras, Telecom, and Specs in all six orders
and require the same derived 2,093-name registry snapshot every time. They also
classify all 227 Specs/Extras overlaps (63 alias/canonical and 164 alias/alias),
require Extras' GNU codecs to win every overlap, preserve all 25 displaced RFC
tables under `RFC1345:` names, and stop/restart each overlapping package to
prove atomic fallback in both directions.

`tools/artifact_audit.exs` is also the reusable clean-consumer release probe:
run it from a temporary Mix project whose seven path dependencies point at the
unpacked Hex artifacts. Before any dependency application is started by the probe, it
requires the exact seven real artifact dependency roots and the exact seven Hex
tarballs from which they were unpacked. It verifies each outer tar file set,
Hex v3 inner checksum, package identity/version, and published dependency
requirements with Hex's own atom-safe reader, and byte-compares every tar
payload entry with the supplied unpacked root before starting any dependency
application. It then checks all 88 workspace release-evidence files
(top-level Markdown and CSV inventories,
`NOTICE`, and `mix.exs`) byte-for-byte against the package artifacts. The seven
repository-only exceptions are Core's GPL test-source notice
`LICENSE.GPL-3.0` and Specs' `ICU_SWAP_LFNL_DIFFERENTIAL.md`,
`OPENJDK_ENCODINGS.md`, `OPENJDK_EUC_JP_OPEN.md`, `OPENJDK_ISO2022_CN.md`,
`OPENJDK_ISO2022_JP.md`, and `UTF8_MAC.md`; each is intentionally excluded
from the corresponding LGPL package manifest. It pins all 2,255 recursively packaged files
(Core 127, Extras 99, Telecom 54, Specs 907, and 356 in each archive shard)
and byte-compares them. It then requires 2,093/2,093 full-stack codecs,
the exact 16-entry public provenance-helper allowlist, both packaged Kermit BSD/source
files and the pinned COPYING digest, both digest-pinned FIELDATA tables and
their source metadata while excluding the copyrighted manuals, the eight
digest-pinned MacOS Esperanto, VSCII-2, Lotus LICS, and U.S. Army Tap Code
source assets, the exact IBM 24/26 normalized table, both retained UTF-5/UTF-6
draft bundles, all four normalized Iowa punched-card evidence files and all
three normalized IBM Six-Bit Transcode evidence files while rejecting their
raw HTML/PDF sources, and semantic conversion probes for all four new families.
The Iowa probes round-trip the source-qualified packed and
16-bit word transports while preserving rejection of all three ambiguous
generic names.
The Transcode probes pin the primary-manual 0x0C profile split, both six-bit
packed orders, source-qualified aliases, and rejection of generic family names.
They digest-validate and parse both packaged CSVs, require exactly 64 ordered
units in each, and execute encode/decode checks for all 128 mapping cells.
They execute 102 canonical packed names and 220 packed alias forms, then reject
named-order conflicts and mistagged LSB containers with the typed
`:bit_order_mismatch` error.
It loads all 1,050 archive-shard tables through their registered providers, checks
the exact per-shard file sets and two-file/digest boundary, and verifies all ten
TI-89/TI-83 profile identities plus 1,841/1,841 runtime Specs encode/decode checks
and conversion probes from every extension package. FIELDATA release probes also
pin the source-qualified aliases, ambiguous-name rejection, proprietary U+F402F
glyph identity, and physical packed-error bit offset.
The audit also enforces all 25 GNU/RFC collision migrations and compares every
reclaimed GNU alias with its canonical target across all 256 input bytes.
The TI release probes additionally reject ambiguous bare TI-83 names, pin the
VPUA allocation ledger, exercise longest/decode-only reverse policy, readable
invalid tails, and mixed-lossless/raw round trips.

Build publishable tarballs with `ICONVEX_PATH` and `ICONVEX_ARCHIVE_PATH`
unset; those variables are checkout-only overrides, and Hex intentionally
rejects path dependencies in package metadata. After unpacking the seven
tarballs into the temporary consumer's dependency paths, run:

```sh
MIX_ENV=prod mix compile --warnings-as-errors
ICONVEX_ARTIFACT_ROOT=/absolute/path/to/unpacked/artifacts \
  ICONVEX_TARBALL_ROOT=/absolute/path/to/tarballs \
  ICONVEX_WORKSPACE_ROOT=/absolute/path/to/source/workspace \
  MIX_ENV=prod mix run --no-start --no-compile \
  /absolute/path/to/iconvex_integration/tools/artifact_audit.exs
```

The artifact root must contain the seven unpacked package directories as exact
immediate children named `<app>-<version>`. The audit rejects checkout or mixed
dependency paths and any extra, missing, corrupt, or dependency-inaccurate Hex
tar before starting dependency applications, compares the 88
source and artifact release-evidence files, then loads every one of the 1,050
archive-shard tables.

The generated comparison against GNU libiconv 1.19 is maintained at
[`../ICONVEX_FULL_STACK_SUPPORT.md`](../ICONVEX_FULL_STACK_SUPPORT.md). Regenerate
it with all local package dependencies through:

```sh
mix run ../iconvex_specs/tools/full_stack_support.exs
```
