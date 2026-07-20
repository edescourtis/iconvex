# GNU libiconv 1.19 test coverage

This document maps GNU libiconv 1.19's complete `tests/` directory and every
active `check` target to Iconvex verification. The mapping is enforced by
`test/upstream_coverage_audit_test.exs`; adding or removing an upstream case
without updating coverage fails CI.

## Provenance and corpus integrity

- Upstream: GNU libiconv 1.19, released 2026-03-07.
- Archive SHA-256:
  `88dd96a8c0464eca144fc791ae60cd31cd8ee78321e67397e25fc095c4a19aa6`.
- Imported archive test files: **267/267 upstream files**.
- Derived configured files: **1/1** (`Makefile`, generated from the upstream
  `Makefile.in`; it is not present in the release archive).
- Upstream-only aggregate SHA-256:
  `b328fa4374b3b76df8acc47009a2b39b5ff5aaa1d7430cb12d9ae89a20202225`.
- Derived-file aggregate SHA-256:
  `dd437384d8e116abb838757ec1d7809d17a5fae8b3fe48e08b3d6f31910ff09b`.
- Complete audited-corpus SHA-256:
  `546c5b74a57687415f6bc67548dc1a190e9be54417b4df530addf7f9b96b095d`.
- Corpus verification separately recomputes the 267-file upstream manifest,
  the one-file derived manifest, and their 268-file audited union in sorted
  filename order. A changed, missing, or extra file fails ExUnit.

Exact file accounting:

| Category | Files |
|---|---:|
| Primary `.TXT` charmaps | 164 |
| `.IRREVERSIBLE.TXT` inverse exceptions | 20 |
| Encoded snippets | 27 |
| Expected snippet `.UTF-8` files | 27 |
| Alternative valid snippets | 1 |
| Quote/transliteration fixtures | 6 |
| Shell/Windows check drivers | 10 |
| C test/generator/harness sources | 10 |
| Upstream `Makefile.in` | 1 |
| `qemu.h` harness header | 1 |
| **Upstream total** | **267** |
| Derived configured `Makefile` | 1 |
| **Audited total** | **268** |

The coverage audit builds these sets from filenames and requires their union to
equal the exact 268 audited files total. No unclassified file is allowed, and
the sole non-archive input is named and digested explicitly.

## Active upstream checks

| Upstream check | Upstream cases | Iconvex evidence | Disposition |
|---|---:|---|---|
| `check-stateless` | **165/165** | 164 raw charmaps tested forward; inverse built with upstream symmetric-difference rules and all 20 irreversible files; generated UTF-8 BMP case | Exact semantic port |
| `gengb18030z` | 2 revisions | Every scalar from **U+10000..U+10FFFF** encoded and decoded for GB18030:2005 and GB18030:2022 | Exhaustive algorithmic port |
| `check-stateful` | **27/27** | Every snippet decoded to its exact `.UTF-8` file and re-encoded byte-for-byte; `ISO-2022-JP-MS-snippet.alt` also decoded | Exact byte port |
| `check-translit` | 3 | `Quotes` to ISO-8859-1/ASCII and `Translit1` to ASCII compared to upstream files | Exact byte port |
| `check-translitfailure` | 1 | `TranslitFail1` required to return typed unrepresentable-character error | Exact failure port |
| `check-subst` | 1 driver, all enabled branches | ASCII/non-ASCII byte substitutions, ASCII/non-ASCII Unicode substitutions, ISO-8859-1 round-trips, 10,000-column formats | Behavioral port |
| `check-ebcdic` | 1 | IBM-1047 LF/NEL defaults, `ZOS_UNIX` both directions, transliteration, ignore, explicit surface options | Behavioral port |
| `test-discard` | 1 | Default, transliterate, ignore, non-identical discard, every suffix ordering, explicit-option equivalents | Behavioral port |
| `test-shiftseq` | 1 | UTF-7 whole/split malformed shift sequence and GNU byte position | Behavioral port |
| `test-to-wchar` | 1 | Incomplete UTF-8 conversion to native-endian UCS-4 equivalent | Native BEAM equivalent |
| `test-bom-state` | 1 | BE/LE BOM state retained across chunks for UCS-2, UCS-4, UTF-16, UTF-32 | Behavioral port |
| `check-tag` | 1 z/OS-only branch | Driver retained; audit verifies classification and upstream `openedition` guard | **Not applicable**: Iconvex returns binaries and never creates/tag files; upstream also skips outside z/OS |

The audit parses the imported `Makefile.in`, not a hand-copied invocation list.
It requires the active 165 stateless names and 27 stateful names to exactly equal
the dynamically generated ExUnit fixture sets. It separately inventories all
transliteration, shell, and C executable calls.

## Harness and disabled branches

- `table-from.c`: ported by raw forward charmap comparisons.
- `table-to.c` and `uniq-u.c`: ported by inverse-table generation using the same
  sort/symmetric-difference/unique semantics.
- `genutf8.c`: ported by exhaustive valid BMP scalar coverage.
- `gengb18030z.c`: ported by exhaustive supplementary scalar coverage.
- `is-native.c` and `qemu.h`: cross-execution harness only. Pure BEAM tests run
  substitution cases directly without locale/libc gating.
- `check-stateful.bat`, `check-stateless.bat`, and `check-translit.bat`: Windows
  duplicates of the shell drivers. All referenced fixtures and behaviors use the
  platform-neutral ExUnit ports.
- `check-subst`'s `widechar_t` block is guarded by literal `if false` upstream;
  it is not an executable upstream case. Iconvex has no platform `wchar_t` ABI.

## Verification commands

```sh
mix test
mix compile --warnings-as-errors
MIX_ENV=prod mix run bench/benchmark.exs
```

Current split result: Core 623 tests plus Extras 134 tests, all passing. Core
keeps the byte-exact 267-file upstream mirror plus the explicitly derived
configured `Makefile` and machine-checks all 268 audited files; the extras
package also carries its 92 applicable charmap/inverse files and two
ISO-2022-JP-3 snippet files. Core runs default-codec cases; extras runs all 85
non-default mapping cases plus package lifecycle, IBM-1047, stateful discard,
and combined exhaustive-differential regressions. Together no active portable
GNU case is dropped by the package boundary.
