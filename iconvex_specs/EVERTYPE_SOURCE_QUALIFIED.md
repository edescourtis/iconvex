# Evertype source-qualified single-byte codecs

Iconvex Specs provides seven byte-exact codecs from versioned Evertype mapping
tables. The Evertype name qualifies provenance only; it does not imply vendor
authorship, affiliation, approval, or endorsement. These codecs deliberately
export no generic aliases.

| Canonical encoding | Source table | Version/date | Mapped bytes | Invalid bytes |
|---|---|---|---:|---:|
| `EVERTYPE-2001-LATIN-8-EXTENDED` | `LATIN8EX.TXT` | 1.00 / 2001-11-10 | 249 | 7 |
| `EVERTYPE-2001-MAC-ARMENIAN` | `ARMENIAN.TXT` | 1.00 / 2001-11-10 | 256 | 0 |
| `EVERTYPE-2001-MAC-BARENTS-CYRILLIC` | `BARENCYR.TXT` | 1.00 / 2001-11-10 | 254 | 2 |
| `EVERTYPE-2002-MAC-GEORGIAN` | `GEORGIAN.TXT` | 1.01 / 2002-02-20 | 256 | 0 |
| `EVERTYPE-2001-MAC-MALTESE-ESPERANTO` | `MALTESE.TXT` | 1.00 / 2001-11-10 | 256 | 0 |
| `EVERTYPE-2001-MAC-OGHAM` | `OGHAM.TXT` | 1.00 / 2001-11-10 | 167 | 89 |
| `EVERTYPE-2002-MAC-TURKIC-CYRILLIC` | `TURKCYR.TXT` | 1.01 / 2002-02-20 | 256 | 0 |

Every normalized CSV materializes the 33 identity control mappings that the
published table declares but omits: bytes `00`-`1F` and `7F`. Every other
absent byte is invalid. Strict decode reports the exact failing byte and its
offset; discard skips it. Encode uses the lowest byte when a scalar has more
than one source byte. The sole duplicate is U+0304 in Barents Cyrillic: `C2`
and `C3` both decode to U+0304, and U+0304 encodes canonically as `C2`.

The reusable native engine compiles each CSV into a 256-entry decode tuple, a
pre-encoded UTF-8 tuple, and a canonical inverse map. Compile-time validation
pins normalized SHA-256, source URL, table version/date/size/SHA-256,
cardinality, byte ordering, Unicode scalar validity, and the control policy.
The upstream source files are linked for verification but are not bundled.
The independently expressed normalized artifacts and runtime are licensed as
part of Iconvex under `LGPL-2.1-or-later`.

## Conformance and performance

`test/evertype_source_qualified_test.exs` exhausts all 256 byte positions for
all seven codecs and covers registry isolation, known vectors, duplicate
inversion, strict/discard/substitute policies, streams, direct UTF-8 paths,
malformed UTF-8, and public `Iconvex.convert/4` recovery.

Run the evidence-independent benchmark with:

```sh
ICONVEX_PATH=../iconvex ICONVEX_ARCHIVE_PATH=.. MIX_ENV=test \
  mix run --no-compile bench/evertype_source_qualified_bench.exs --quick
```

The 2026-07-18 Apple M1 / Elixir 1.19.5 / OTP 28 quick run covered all 1,694
normalized rows. All 21 decode, encode, and direct UTF-8 comparisons passed the
30x ceiling against maps independently parsed from the pinned CSVs. Native
throughput was 6.408-102.721 million input units/s, the worst
native/reference latency was 1.578x, and all three doubled-input reduction
gates passed at 1.723x-1.879x.

GNU libiconv 1.19 exposes no exact identity for these source/version-qualified
tables, so the benchmark does not substitute a semantically different nearby
codec.

## CER-GS 1.01 remains blocked

No CER-GS codec is exported. The published `CERGS.TXT` 1.01 table assigns
bytes `B7`, `B8`, `B9`, and `BA` twice to different scalars and conflicts with
the publisher's separate repertoire page about `8F` versus `BF`. Correcting
those byte labels without an exact independent source would create a best-fit
reconstruction, not a byte-exact source-qualified codec. The raw table digest
and exact blocker evidence are pinned in
`priv/sources/evertype-source-qualified/SOURCE_METADATA.md`.
