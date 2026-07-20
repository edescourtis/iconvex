# IANA ISO-10646 profiles

Iconvex implements the three historical IANA 16-bit big-endian profiles:

| Encoding | Repertoire | Wire form |
|---|---|---|
| `ISO-10646-UCS-Basic` | C0/C1 controls and Basic Latin | two-byte big-endian code units |
| `ISO-10646-Unicode-Latin1` | C0/C1, Basic Latin, and Latin-1 Supplement | two-byte big-endian code units |
| `ISO-10646-J-1` | Unicode 1.1 Japanese profile defined by RFC 1815 | two-byte big-endian code units |

The Japanese membership table is generated from pinned RFC 1815, UnicodeData
1.1.5, and the Unicode JIS X 0208 mapping. Each profile uses an 8 KiB bitset,
giving constant-time repertoire checks without a large map lookup.
