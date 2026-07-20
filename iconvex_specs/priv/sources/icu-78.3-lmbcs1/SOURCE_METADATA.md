# ICU 78.3 LMBCS source evidence

- Upstream: Unicode ICU
- Release tag: `release-78.3`
- Resolved commit: `21d1eb0f306e1141c10931e914dfc038c06121da`
- Algorithm source: `icu4c/source/common/ucnv_lmb.cpp`
- Converter registry evidence: `icu4c/source/data/mappings/convrtrs.txt`
- Immutable upstream tree: <https://github.com/unicode-org/icu/tree/21d1eb0f306e1141c10931e914dfc038c06121da/icu4c/source>
- ICU license: <https://github.com/unicode-org/icu/blob/21d1eb0f306e1141c10931e914dfc038c06121da/LICENSE>

The committed algorithm and registry files were fetched from that resolved
commit. Their SHA-256 digests are:

| File | SHA-256 |
|---|---|
| `ucnv_lmb.cpp` | `0ca62b7469713bb992f418dc216e0395b175e51047f6a56e67b7524b1452f39b` |
| `convrtrs.txt` | `29340d12f664416d51c9b9d8d34e6364a10b456e668eb3155fd5f59beaf743e9` |

`ucnv_lmb.cpp` instantiates exactly these optimization groups: 1, 2, 3, 4,
5, 6, 8, 11, 16, 17, 18, and 19. `convrtrs.txt` advertises `LMBCS-1` and
retains the other eleven canonical names as commented, working converters.
They therefore have canonical names but no additional authoritative aliases.
Groups 7, 9, 10, 12, 13, 14, 15, and 20 are not instantiated and are not
implemented by Iconvex Specs.

The exact mapping-table inputs and their individual hashes are recorded in
`priv/icu_lmbcs1_manifest.etf`. The reproducible executable differential is
`tools/verify_icu_lmbcs_variants.exs`; it requires ICU `uconv` 78.3 and uses a
single block larger than the scalar corpus. That block size is material:
ICU's `lastConverterIndex` is local to each conversion callback, so `uconv`'s
default 4096-byte input blocks may select different, still-valid ambiguous
groups than one batched `ucnv_fromUnicode` call.
