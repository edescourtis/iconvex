# Unicode 17 provisional kGB3 row/cell snapshot

`row_cells.csv` is a deterministic extraction of the provisional `kGB3`
property in Unicode 17.0.0 `Unihan_OtherMappings.txt`. It contains 7,236
one-to-one mappings. Coordinates are four decimal digits (`RRCC`), with rows
16 through 92 and cells 01 through 94. Positions `1893` and `9294` are absent.

The development fixture `Unihan_OtherMappings-17.0.0.txt` has SHA-256
`4fabda168d04a5ac360809a8bfa377fe54e04fbc069ba67cacad4df03d691fa0`.
The containing Unicode 17.0.0 `Unihan.zip` archive has SHA-256
`f7a48b2b545acfaa77b2d607ae28747404ce02baefee16396c5d2d7a8ef34b5e`.
The normalized `row_cells.csv` has SHA-256
`63dd2f9d88dc53b9c3603fe798b6f414c578fc22b68d840225a5d44b890d6baf`.

Unicode Standard Annex #38 revision 39 describes `kGB3` as a provisional
row/cell property for “GB/T 13131 (unpublished GB/T 7589-1987 unsimplified
form).” Its captured HTML has SHA-256
`c860013dbd725652888296afe688ac5db9352d234e0741ad44e6cba6ab56852e`.
Unicode proposal L2/25-170 has SHA-256
`86324833bed515ecc06d58813b5dd6a19cc4ef99b0bedf82b2180f550bf5892a`.

This package deliberately names the mapping after the exact Unicode property
and version. It does not claim exact GB 13131-1991 conformance: the published
standard claims 7,237 characters, Unicode 17 has no mapping for coordinate
`1893`, and post-Unicode-17 IRG work records pending source corrections. The
codec is an explicit raw GL row/cell projection (`row + 0x20`, `cell + 0x20`).
It defines no GR/EUC profile and no ISO-2022 designation.

Unicode data is redistributed under the Unicode License v3 in
`LICENSE.UNICODE`. Iconvex source code remains LGPL-2.1-or-later.

Sources:

- https://www.unicode.org/Public/17.0.0/ucd/Unihan.zip
- https://www.unicode.org/reports/tr38/tr38-39.html
- https://www.unicode.org/L2/L2025/25170-gb3-and-gb5.pdf
- https://www.unicode.org/irg/docs/n2863-GSourceIssues.pdf
