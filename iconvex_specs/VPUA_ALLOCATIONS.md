# Plane-15 VPUA allocations

Iconvex reserves the following inclusive blocks for source-qualified,
round-trip mappings. The intervals are sorted and strictly non-overlapping.
Any new allocation must extend the executable non-overlap contract before it
is registered.

| Allocation key | Inclusive range | Purpose |
|---|---:|---|
| `iso_ir_169` | U+F0000..U+F2283 | ISO-IR-169 graphic positions |
| `univac` | U+F4000..U+F403F | UNIVAC FIELDATA source identities |
| `univac_i_lossless` | U+F4040..U+F4040 | UNIVAC I printer-ignore source identity |
| `univac_i_raw` | U+F4080..U+F40BF | UNIVAC I expanded-code forensic identities |
| `ti83_large_lossless` | U+F8300..U+F83FF | TI-83 Plus large-font mixed-lossless bytes |
| `ti83_large_raw` | U+F8400..U+F84FF | TI-83 Plus large-font raw bytes |
| `ti83_small_lossless` | U+F8500..U+F85FF | TI-83 Plus small-font mixed-lossless bytes |
| `ti83_small_raw` | U+F8600..U+F86FF | TI-83 Plus small-font raw bytes |
| `ti89_lossless` | U+F8900..U+F89FF | TI-89/92 Plus mixed-lossless bytes |
| `ti89_raw` | U+F8A00..U+F8AFF | TI-89/92 Plus raw bytes |
| `chinese_telegraph_taiwan_lossless` | U+F8B00..U+F8B03 | Unihan 17 `kTaiwanTelegraph` token identities whose readable scalars collide |
| `pascii_10_lossless` | U+F8C00..U+F8CFF | PASCII C-DAC GIST 1.0 assigned upper-byte source identities |
| `pascii_10_raw` | U+F8D00..U+F8DFF | PASCII C-DAC GIST 1.0 forensic raw bytes |

The TI-83 compact mapping that consumes its four blocks is pinned by SHA-256
`186d80d270a6a27815df8d0b5ff993c65b158efb7f3d6ddd27533feb9cb96ccc`.
The TI-89/92 Plus compact mapping is pinned by SHA-256
`be205ae316b916d6f2b386fd85729f51cdcd6852c9db64f014d0187a6345fb44`.
The Taiwan telegraph source and explicit lossless policy are pinned by SHA-256
`15dc21eacf695ce038500e68fa40c125d0762b5e265c9683f82f17d2eac878a6` and
`79890c693597f1f25b4e68abe5627883c8299d7d382ed8865c42a3d361971696`.
The PASCII C-DAC GIST 1.0 mapping is pinned by SHA-256
`335236d0b61cf050f3d0ab1d0fed7b66df6bb1c317da4291d109a8eb769d2cf5`.
