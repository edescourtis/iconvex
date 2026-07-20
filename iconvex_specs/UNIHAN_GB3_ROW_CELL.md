# Unicode 17 provisional kGB3 row/cell mapping

Iconvex Specs exposes two deliberately source-qualified surfaces for the
Unicode 17.0.0 provisional `kGB3` property:

- `UNIHAN-17.0.0-KGB3-ROW-CELL-DECIMAL-TOKEN` is a single-property-token
  mapping and is not registered as a byte-stream codec.
- `UNIHAN-17.0.0-KGB3-ROW-CELL-GL` serializes each assigned coordinate as
  `<<row + 0x20, cell + 0x20>>`.

The snapshot contains 7,236 unique coordinates and 7,236 unique Unicode
scalars. Its rectangular domain is rows 16 through 92 and cells 01 through 94;
coordinates `1893` and `9294` are unassigned. The dense decoder has 7,238
slots, while the encoder is a one-to-one scalar map.

These names do not claim that Unicode 17 is a complete mapping of published
GB 13131-1991. In particular, the standard's reported repertoire has 7,237
characters, `1893` is reserved pending encoding work, and later IRG material
records corrections after Unicode 17. Generic `GB13131`, `GB/T-13131`, `KGB3`,
EUC, GR, and ISO-2022 aliases are therefore intentionally absent.

The checked-in CSV is regenerated only from the pinned Unicode fixture:

```console
mix run tools/import_unihan17_kgb3_row_cell.exs
mix run tools/import_unihan17_kgb3_row_cell.exs -- --check
```

| Evidence | SHA-256 |
|---|---|
| Unicode 17 `Unihan_OtherMappings.txt` | `4fabda168d04a5ac360809a8bfa377fe54e04fbc069ba67cacad4df03d691fa0` |
| Unicode 17 `Unihan.zip` | `f7a48b2b545acfaa77b2d607ae28747404ce02baefee16396c5d2d7a8ef34b5e` |
| Normalized `row_cells.csv` | `63dd2f9d88dc53b9c3603fe798b6f414c578fc22b68d840225a5d44b890d6baf` |
| UAX #38 revision 39 HTML | `c860013dbd725652888296afe688ac5db9352d234e0741ad44e6cba6ab56852e` |
| Unicode L2/25-170 | `86324833bed515ecc06d58813b5dd6a19cc4ef99b0bedf82b2180f550bf5892a` |

Unicode data is covered by `LICENSE.UNICODE`; the implementation remains
LGPL-2.1-or-later.
