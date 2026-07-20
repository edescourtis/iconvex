# Iconvex

Iconvex is a pure native Elixir character-set conversion stack based on GNU
libiconv 1.19. It includes the GNU-compatible core, optional extra encodings,
telecom and non-octet codecs, public-specification codecs, ICU archive shards,
and exhaustive differential/integration verification.

## Packages

| Hex package | Directory | Purpose |
| --- | --- | --- |
| `iconvex` | `iconvex/` | Core API and GNU libiconv-compatible codecs |
| `iconvex_extras` | `iconvex_extras/` | GNU `--enable-extra-encodings` and platform codecs |
| `iconvex_telecom` | `iconvex_telecom/` | Telecom, septet, packed, and non-octet codecs |
| `iconvex_specs_icu_archive_a` | `iconvex_specs_icu_archive_a/` | ICU historical mapping shard A |
| `iconvex_specs_icu_archive_b` | `iconvex_specs_icu_archive_b/` | ICU historical mapping shard B |
| `iconvex_specs_icu_archive_c` | `iconvex_specs_icu_archive_c/` | ICU historical mapping shard C |
| `iconvex_specs` | `iconvex_specs/` | Codecs recovered from public specifications |
| — | `iconvex_integration/` | Full-stack artifact and release verification |

Version 0.1.0 exposes 2,093 unique canonical codec names across the combined
registry. The release candidate passed 2,255 recursively pinned artifact-file
checks, 2,093 codec inventory checks, 1,050 ICU archive table checks, and 1,841
Specs runtime encode/decode probes.

## Install

Start with the core package:

```elixir
def deps do
  [
    {:iconvex, "~> 0.1.0"}
  ]
end
```

Add `iconvex_extras`, `iconvex_telecom`, or `iconvex_specs` only when those
codec families are required. See each package README for its API, inventories,
conformance evidence, and licensing details.

## Verify

Each directory is an independent Mix project. The aggregate GitHub Actions
workflow compiles and tests the supported OTP/Elixir matrix. The complete
release evidence and package relationships are recorded in
[`ICONVEX_FULL_STACK_SUPPORT.md`](ICONVEX_FULL_STACK_SUPPORT.md).

The guarded Hex release script is
[`iconvex_integration/tools/publish_hex.sh`](iconvex_integration/tools/publish_hex.sh).
Its default mode verifies the tracked
[`iconvex_release_0.1.0`](iconvex_release_0.1.0/) candidate and performs Hex
dry-runs only. Live publication requires `--publish` and an exact confirmation
phrase.

## License

Iconvex uses the same license family as GNU libiconv:
LGPL-2.1-or-later. Some optional mapping data carries additional compatible
licenses; see the package-local `LICENSE*` and `NOTICE` files.
