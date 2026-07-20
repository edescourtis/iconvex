# Punched-card code source metadata

These artifacts are pinned as mapping evidence. They are not copied into the
library's executable code. The historical manuals and the Iowa page retain
their respective owners' copyright; no permissive redistribution grant was
found in any artifact. Their mapping facts can be independently implemented
under Iconvex Specs' LGPL-2.1-or-later license, but the scans and HTML do not
inherit that license.

## IBM 7040/7044 H code

- Artifact: `ibm-7040-7044-student-text-c22-6732-1.pdf`
- Title: *IBM 7040 and 7044 Data Processing Systems — Student Text*
- Publisher: International Business Machines Corporation
- Form: C22-6732-1 (the archive filename omits the leading C)
- URL: <https://bitsavers.org/pdf/ibm/7040/22-6732-1_7040StudentText.pdf>
- SHA-256: `46336c0ed59e04fdc5c7c9553e668f8fcbb000caa88a54dca72d943d0fed28bb`
- Relevant text: PDF page 23 / printed page 21 identifies H code as the
  standard IBM card code and says it has 64 combinations.
- Exhaustive table: Figure 23, PDF page 24 / printed page 22, separately
  enumerates report-writing and programming-language graphics for every H
  code, including no-punch.
- License: IBM publication; no reuse license is stated in the scan.

## IBM 1401 card code

- Artifact: `ibm-1401-reference-a24-1403-5.pdf`
- Title: *Reference Manual — IBM 1401 Data Processing System*
- Edition: A24-1403-5, major revision April 1962
- Publisher: International Business Machines Corporation
- URL: <https://www.bitsavers.org/pdf/ibm/1401/A24-1403-5_1401_Reference_Apr62.pdf>
- SHA-256: `ab9d79ef05aa5c23e83f251c829607c2e9cb2dd89b368dd4565bcaff79af6ef9`
- Exhaustive table: Figure 267, PDF page 184 / printed page 170, gives the
  defined character, card code, BCD code, and print graphic in collating
  sequence.
- License notice: `© 1960, 1961, 1962 by International Business Machines
  Corporation`; no reuse license is stated.

## CDC 167-2 / 166-series BCD translator profile

- Artifact: `cdc-167-2-card-reader-60022000d.pdf`
- Title: *167-2 Card Reader — Reference/Instruction & Diagrams Manual*
- Publication: 60022000D, February 1965
- Publisher: Control Data Corporation
- URL: <https://www.bitsavers.org/pdf/cdc/160/options/60022000D_167-2_Card_Reader_Reference_196502.pdf>
- SHA-256: `f3dce73c357934c252d54563b2d9271bc46e990a1ddbeda5f9f0c24967175bbd`
- Exhaustive table: Table 2-4, PDF page 13 / printed page 2-6, lists BCD
  codes 00-77, printer characters, and Hollerith punches. BCD 00 colon is
  explicitly `illegal` in Hollerith, leaving 63 card characters.
- License notice: `© 1965, Control Data Corporation`; no reuse license is
  stated.

## Independent CDC training-manual cross-check

- Artifact: `cdc-punched-card-equipment-training-60239300.pdf`
- Title: *Punched Card Equipment Training Manual*
- Publication: 60239300, August 1967
- Publisher: Control Data Institute / Control Data Corporation
- URL: <https://www.bitsavers.org/pdf/cdc/training/60239300_Punched_Card_Equipment_Training_Manual_Aug67.pdf>
- SHA-256: `e908fedc429cf9f65495d588092988c2a4d79d1159bdb290a63196f5566f467d`
- Exhaustive table: PDF page 16 / printed page 1-8 repeats the character,
  Hollerith, external BCD, and internal BCD table. It independently marks
  colon/Hollerith as illegal.
- License notice: `Copyright 1967, Control Data Corporation`; no reuse
  license is stated.

## CDC 6000 Standard Hollerith profile

- Artifact: `cdc-6000-interactive-graphics-44616800-rev03.pdf`
- Title: *Control Data 6000 Series Computer Systems — Interactive Graphics
  System Preliminary Reference Manual*
- Publication: 44616800, revision 03, January 1970
- Publisher: Control Data Corporation
- URL: <https://bitsavers.org/pdf/cdc/graphics/44616800-03_Interactive_Graphics_System_Prelim_Ref_197001.pdf>
- SHA-256: `275d0c2e8b3edacbd356f614d1e8ee0b63b9c159f0e1f68583e7169546b4810d`
- Exhaustive table: Appendix C, PDF pages 193-194 / printed pages C-1-C-2,
  lists Standard 6000 printed graphics and Hollerith rows for display codes
  01-77. This profile has 63 canonical characters: it assigns colon to 2+8
  and leaves 6+8 unassigned.
- Alternate-punch footnote: `0,11` is equivalent to `11,8,2`, and `0,12`
  is equivalent to `12,8,2`.
- License notice: `Copyright Control Data Corp., 1969, 1970`; no reuse
  license is stated.

## Iowa reconstruction and correction source

- Artifact: `uiowa-punched-card-codes.html`
- Title: *Punched Card Codes*
- Author: Douglas W. Jones, University of Iowa
- URL: <https://homepage.cs.uiowa.edu/~jones/cards/codes.html>
- SHA-256: `824e61a9687f7fa0b9c9dd3c966ca02020bf8af1ab6671e9bd2e131f22f47b18`
- Relevant sections: IBM 7040/1401 and Control Data Corporation. The page
  supplies semantic corrections for glyphs that historical fonts approximate
  poorly and documents the 64-character `BCD-CDC` reconstruction.
- Diagram extraction: the 64 column masks are reconstructed directly from the
  twelve punch rows. In particular, less-than is 12+0+8 (`0xA02`); it is not
  the 12+8+2 alternate accepted by the separately named 1970 CDC profile.
- Provenance limitation: the CDC section says this is `BCD-CDC` in Dik
  Winter's collection. It does not identify one primary CDC publication that
  contains that exact 64-character union profile.
- License: no reuse license or copyright grant is stated in the saved page.

### Content-addressed IBM 029 profile

- Runtime identity: `IBM-029-CARD-IOWA-824E61A9`.
- Relevant section: `The IBM model 029 keypunch` in the pinned Iowa artifact.
- Source qualification: the identity includes both `IOWA` and the first eight
  hexadecimal characters of the artifact SHA-256. It deliberately does not
  claim the unqualified `IBM 029`, `IBM029`, or `IBM-029-CARD` names.
- Diagram extraction: the header and all twelve punch rows independently
  yield 64 source columns. The no-punch column and `0-8-2` column both render
  blank. The normalized inverse therefore encodes U+0020 with no punches and
  accepts `0-8-2` only as a decode alias.
- Machine-readable extraction:
  `ibm_029_card_iowa_824e61a9.csv`, SHA-256
  `c7a394f8ed6b025b6058a10e23c35036b6b50c8fc70db6da07c9724967c45373`.

### Other exact source-qualified rows in the Iowa snapshot

- `DEC6` / `DEC-026-CARD-IOWA-824E61A9`:
  `dec_026_card_iowa_824e61a9.csv`, SHA-256
  `b5e4bd965af2c72f2b643e2681792e2c39d5dc25819268181f74f2cac94cc5d4`.
- `DEC9` / `DEC-029-CARD-IOWA-824E61A9`:
  `dec_029_card_iowa_824e61a9.csv`, SHA-256
  `810293f09cc61dc043f122465edb13a85d319f0c5c494882b7e9a715dc5222ba`.
- `EBCD` / `EBCD-CARD-IOWA-824E61A9`:
  `ebcd_card_iowa_824e61a9.csv`, SHA-256
  `1a57f8721c556354d6b3dde76d62ab9fbe6d8e405d4d7bf93e053d989bc4f588`.
- corrected `GE` / `GE-600-CARD-IOWA-824E61A9`:
  `ge_600_card_iowa_824e61a9.csv`, SHA-256
  `d2e0846ed24df4b20492191a781238fb9e507b0628173ca504091a0c38313c7d`.

The GE normalization applies only the two corrections stated in the source:
11-8-2 is U+2191 and 0-8-2 is U+2190. The four rows are each complete and
one-to-one. They remain explicitly source-qualified because the snapshot is
secondary evidence and states qualifications about each row's provenance.

The earlier Hollerith “consensus code” diagram is not normalized as a codec:
four cells are marked `?`, and the accompanying prose explicitly says those
positions varied. See `hollerith_consensus_iowa_824e61a9_blocker.md`.

## Unicode binding for IBM special graphics

- Artifact: `unicode-l2-15-083r-group-mark.pdf`
- Title: *Proposal for addition of Group Mark symbol*, L2/15-083R
- Author: Ken Shirriff; revised May 14, 2015
- Publisher: Unicode Consortium document register
- URL: <https://www.unicode.org/L2/L2015/15083r-group-mark.pdf>
- SHA-256: `421c2a627a43a7b26c252024e480b59e8c61f42e9ddab660bba8a2ca350f3eee`
- Relevant pages: PDF pages 7-8 identify U+0394 mode change, U+22CE word
  separator, U+29FB tape segment mark, U+2422 blank symbol, U+221A tape
  mark, and U+2021 record mark as the existing Unicode representations;
  pages 6-7 specify U+2BD2 GROUP MARK.
- License: Unicode technical submission. The PDF carries its own submission
  and font-use terms; no license grant makes the retained artifact part of
  Iconvex Specs' LGPL-covered code. The independently implemented mapping
  facts remain under Iconvex Specs' license.

## Machine-readable evidence

- `canonical_maps.csv` contains the complete canonical Unicode-to-12-bit
  tables for all six named profiles. Row masks use the convention documented
  in `PROFILE_DISPOSITION.md`. SHA-256:
  `541347c32f7610d3830b9259a68891b6ae2a410b1251f039f37930b83c3476c7`.
- `decode_aliases.csv` contains only the two noncanonical decode aliases
  explicitly authorized by the 1970 CDC Appendix C footnote. SHA-256:
  `da98e499e2b860bea2f35b7fbd66e14db1142047a7ac9ffe5b84174875b65323`.
- `ibm_029_card_iowa_824e61a9.csv` contains the complete 64-column extraction
  for the content-addressed Iowa IBM 029 profile: 63 unique canonical Unicode
  scalars plus the source's `0-8-2` decode-only blank alias. SHA-256:
  `c7a394f8ed6b025b6058a10e23c35036b6b50c8fc70db6da07c9724967c45373`.
