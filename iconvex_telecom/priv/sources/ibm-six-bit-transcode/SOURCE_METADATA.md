# IBM Six-Bit Transcode source metadata

These CSV files are normalized factual transcriptions made for Iconvex. They
contain only the ordered six-bit unit and Unicode scalar selected for each
table cell; they do not copy page layout, prose, or artwork from the manuals.

## IBM 2780 profile

- Publication: *Component Description: IBM 2780 Data Transmission Terminal*,
  fourth edition (August 1971), order number GA27-3005-3.
- Source URL: https://www.bitsavers.org/pdf/ibm/2780/GA27-3005-3-2780_Data_Terminal_Description_Aug71.pdf
- Source size: 5845274 bytes.
- Source SHA-256: `3e631b8851217a848da3e2ca4ebf673978dcc87ed238407e35399024e98a75a8`.
- Table location: Figure 4, physical PDF page 10, printed page 10.
- Normalized transcription: `ga27-3005-3.csv`.
- Transcription SHA-256: `cbb94188f9ac1a8b9a95dcff91d0744c84f77ad53377d62dd76eff4d6a476416`.

The adjacent code-structure prose says the data is transmitted low-order first (543210).
Figure 4 prints a `P` column for internal/buffer checking; parity is not part of the six-bit wire unit
exposed by this codec.
GA27-3004-2 separately states that VRC is unavailable for Six-Bit Transcode.

## General BSC profile

- Publication: *General Information — Binary Synchronous Communications*,
  third edition (October 1970), order number GA27-3004-2.
- Source URL: https://www.bitsavers.org/pdf/ibm/datacomm/GA27-3004-2_General_Information_Binary_Synchronous_Communications_Oct70.pdf
- Source size: 2485327 bytes.
- Source SHA-256: `2589c426624f8e57158fe8256fbeecc17d779d2b4ca4cd73caddd28c4dc2f67f`.
- Table location: Figure 4, physical PDF page 11, printed page 11.
- Normalized transcription: `ga27-3004-2.csv`.
- Transcription SHA-256: `5dccf290006224a0de51dddda9ec227183f1527610f61cf2f70b606ccea7c31e`.

The two source tables agree in 63 of 64 cells. Unit `0x0C` is the square-lozenge
graphic (represented as U+2311) in GA27-3005-3, but less-than (U+003C) in
GA27-3004-2. Iconvex therefore publishes two source-qualified codec identities
and deliberately does not claim a generic `TRANSCODE` name.

## Redistribution boundary

The IBM manuals are copyrighted historical references. The raw PDFs are excluded
from `priv`, the Hex package, and all distributed source assets. Public
availability does not imply a redistribution license. Only the normalized
factual CSV transcriptions and this original metadata note are packaged under
the library's LGPL-2.1-or-later terms.
