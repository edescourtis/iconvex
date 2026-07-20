# ECMA-44 raw punched-card transport source metadata

`Iconvex.Specs.ECMA44` implements the raw correspondence between ECMA 7-bit
or 8-bit code combinations and 12-row punched-card hole patterns. ECMA-44 is
not a Unicode character encoding. Unicode character meaning requires a
separately selected ECMA-6 or ECMA-43 repertoire and national profile.

- Standard: ECMA-44, first edition, September 1975
- Official source URL:
  https://www.ecma-international.org/wp-content/uploads/ECMA-44_1st_edition_september_1975.pdf
- Source PDF SHA-256:
  `09b71ed57db7a0b2c1e9bc7006f001df198450f37b706c01d2754ddb5a5de228`
- Forward table: PDF page 9, printed page 4, Table 1
- Inverse table: PDF page 11, printed page 6, Table 2
- Scope and seven-bit restriction: PDF page 8, printed page 3, clauses 4.1
  and 4.2
- Hole-pattern validity rule: PDF page 7, printed page 2, clause 3.2

`ecma44_table.csv` is an independent transcription of the 256 entries. Its
row selects the high nibble of the code combination, its column selects the
low nibble, and each cell is the corresponding 12-bit hexadecimal card mask.

Mask bits use the package's established physical row convention:

```text
row:  12   11    0    1    2    3    4    5    6    7    8    9
bit: 800  400  200  100  080  040  020  010  008  004  002  001
```

The official PDF is audit input and is deliberately not packaged. Only this
small transcription and metadata ship in the release artifact.
