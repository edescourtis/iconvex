# Unihan 17 Chinese telegraph property tokens

Iconvex Specs exposes three source-qualified mappings for Unicode 17.0.0
`kMainlandTelegraph` and `kTaiwanTelegraph` values. They operate on exactly one
four-ASCII-digit property token at a time:

| Mapping | Assigned tokens | Reverse scalars | Reverse policy |
|---|---:|---:|---|
| `UNIHAN-17.0.0-KMAINLANDTELEGRAPH-DECIMAL-TOKEN` | 7,078 | 7,078 | exact |
| `UNIHAN-17.0.0-KTAIWANTELEGRAPH-DECIMAL-TOKEN-READABLE` | 9,026 | 9,024 | smallest numeric token for the two duplicate scalars |
| `UNIHAN-17.0.0-KTAIWANTELEGRAPH-DECIMAL-TOKEN-LOSSLESS-VPUA-1` | 9,026 | 9,026 | four explicit Plane-15 identities make every token reversible and normalization-stable |

These are property-token mappings, not `Iconvex.Codec` implementations. Unicode
Standard Annex #38 defines one `\d{4}` property subentry; it does not define how
multiple values become a byte stream or message. Iconvex therefore does not
invent concatenation, separators, BCD, shifts, resynchronization, regional
selection, or substitution/discard semantics. The mappings have no codec
aliases and are deliberately absent from `Iconvex.canonical_name/1`,
`Iconvex.convert/3`, and `Iconvex.stream/3`.

Use the modules directly:

```elixir
alias Iconvex.Specs.Unihan17MainlandTelegraphDecimalToken, as: Mainland
alias Iconvex.Specs.Unihan17TaiwanTelegraphDecimalTokenReadable, as: Taiwan

{:ok, 0x4E00} = Mainland.decode_token("0001")
{:ok, "0001"} = Mainland.encode_scalar(0x4E00)
{:ok, "一"} = Taiwan.decode_token_to_utf8("0001")
{:ok, "0001"} = Taiwan.encode_utf8_to_token("一")
```

`Iconvex.Specs.property_token_mappings/0` returns all three modules. Each module
implements `Iconvex.Specs.PropertyTokenMapping`, reports its exact mapping name
and metadata, and provides:

- `decode_token/1` and `decode_token_to_utf8/1`;
- `encode_scalar/1` and `encode_utf8_to_token/1`.

Malformed length, first non-decimal byte offset, unassigned token, invalid
Unicode scalar, malformed UTF-8 sequence and offset, and scalar-cardinality
errors are explicit tuples. The UTF-8 helper accepts exactly one scalar.

## Taiwan policies

The readable profile decodes every assigned token. For the two duplicate source
scalars it encodes to the smallest numeric token:

| Scalar | Canonical reverse | Decode-only token |
|---|---:|---:|
| U+5875 | `1057` | `7775` |
| U+843C | `5501` | `9795` |

Two compatibility ideographs also normalize onto other assigned source
scalars: token `0066` U+2F81B normalizes to U+51B5 at `0400`, and token `2210`
U+2F8BA normalizes to U+62FC at `2178`. The lossless profile applies only these
four documented rewrites:

| Token | Source scalar | Lossless output | Reason |
|---:|---:|---:|---|
| `0066` | U+2F81B | U+F8B00 | normalization collision |
| `2210` | U+2F8BA | U+F8B01 | normalization collision |
| `7775` | U+5875 | U+F8B02 | duplicate readable reverse |
| `9795` | U+843C | U+F8B03 | duplicate readable reverse |

U+F8B00..U+F8B03 is recorded in `VPUA_ALLOCATIONS.md`. All 9,026 lossless
outputs are distinct and stable under NFC, NFD, NFKC, and NFKD.

## Source and integrity boundary

The compact CSV files are independently derived from Unicode 17.0.0
`Unihan_OtherMappings.txt`. The source member, archive, UAX revision, compact
tables, and policy hashes are pinned in
`priv/sources/unihan-17.0.0-telegraph/SOURCE_METADATA.md`. Compilation verifies
the exact hashes and validates headers, token grammar and order, Unicode scalar
validity, source/policy agreement, duplicate roles, and lossless uniqueness
before emitting dense immutable lookup tables. Runtime lookup performs no file
I/O, ETS lookup, or persistent-term access.

The repository also retains exact Unicode 17.0.0 `Unihan_OtherMappings.txt` and
UnicodeData fixtures under `test/fixtures/unihan-17.0.0-telegraph`.
`tools/extract_unihan_telegraph.py` regenerates all three compact tables into a
scratch directory and refuses an implicit package overwrite.
`tools/verify_unihan_telegraph.py` is an independent parser: it imports no
generator code, checks all 30,000 Mainland/Taiwan-readable/Taiwan-lossless token
outcomes, derives duplicate reverses and all four normalization policies, and
exact-compares the packaged bytes. Permanent tests run both tools from an
unrelated working directory and prove that tampering with either a source
fixture or packaged table fails. The large fixtures and Python audit tools are
not included in the Hex artifact.

The tables use the Unicode License v3 reproduced in `LICENSE.UNICODE`.
Implementation code remains LGPL-2.1-or-later. GNU libiconv 1.19 exposes no
exact alias for any of these source-qualified property-token mappings, so no
GNU throughput or byte-stream equivalence claim is made.
