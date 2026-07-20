# PASCII C-DAC GIST 1.0 (October 2002)

## Primary byte-code evidence

- Title: **PASCII (Perso-Arabic Standard for Information Interchange) Version 1.0**.
- Publisher/origin: C-DAC GIST, India, under the TDIL initiative.
- Printed date: October 2002. The PDF metadata title is `TDIL-Jan-2002`.
- Relevant chart: physical PDF pages 4–7, printed pages 61–64.
- URL:
  `https://www.cs.cmu.edu/afs/cs.cmu.edu/project/cmt-40/Nice/Urdu-MT/code/Tools/Encoding_Conversion/EncodingInfo/PASCIIStandard.pdf`
- Size: 459623 bytes.
- SHA-256:
  `8eb605e3a7e0dcfed1fdb58de7ddfa2171d964b7b43220a234cbd6924608ecea`.

The C-DAC chart defines ASCII in the lower half and assigned PASCII cells in
the upper half. Byte `80` is unassigned: the detailed chart begins at `81`.
Cells `FA`, `FB`, `FE`, and `FF` are explicitly marked reserved.
It supplies glyphs and character descriptions, but it does not publish a
normative PASCII-to-Unicode conversion table. The PDF is a copyrighted reference only
and has no redistribution grant. It is not included in the
repository package or Hex archive. C-DAC's current standardization overview is
`https://www.cdac.gov.in/index.aspx?id=mlc_gist_standardisation`.

## Independently expressed mapping asset

`mapping.csv` is an independently authored, normalized statement of mapping
facts and explicit Iconvex policies. It has 256 ordered rows and SHA-256:

`335236d0b61cf050f3d0ab1d0fed7b66df6bb1c317da4291d109a8eb769d2cf5`

The CSV and implementation are distributed under `LGPL-2.1-or-later`. No PDF
chart, screenshot, extracted artwork, or source prose is redistributed.

Unicode names and scalar assignments were checked against UnicodeData 17.0.0:

- URL: `https://www.unicode.org/Public/17.0.0/ucd/UnicodeData.txt`
- Local normalized source SHA-256:
  `2e1efc1dcb59c575eedf5ccae60f95229f706ee6d031835247d843c11d96470c`
- Unicode data license: Unicode License v3.

The Wikipedia table at oldid `1348507090` (last edited 2026-04-13) was used
only as a secondary cross-check. It is neither the source of the C-DAC byte
chart nor normative mapping evidence. In particular, Iconvex does not copy its
presentation-form sequence for byte `9E`, its obsolete absence for byte `CB`,
or its `0649` assignment for byte `BA`.

## Explicit profiles

- `PASCII-CDAC-GIST-1.0-2002-LOSSLESS-VPUA-1` is the exact opaque
  source-identity profile. ASCII remains Unicode identity. Every assigned upper
  byte maps to `U+F8C00 + byte`; the unassigned and reserved cells remain
  invalid.
- `PASCII-CDAC-GIST-1.0-2002-RAW-VPUA-1` is the forensic profile. Every byte,
  including reserved values, maps to `U+F8D00 + byte`.
- `PASCII-CDAC-GIST-1.0-2002-URDU-KASHMIRI-UNICODE17-BEST-FIT` is a
  non-normative Unicode 17.0.0 best-fit projection.
- `PASCII-CDAC-GIST-1.0-2002-SINDHI-UNICODE17-BEST-FIT` is the corresponding
  Sindhi projection.

The primary document says PASCII covers Urdu, Persian, Sindhi, Kashmiri, and
Arabic, but supplies neither a normative Unicode mapping nor language choices
for ambiguous upper-half cells. Persian and Arabic best-fit projections are intentionally withheld
until authoritative mapping evidence exists. Their
source-byte repertoire remains completely available through the exact
`LOSSLESS-VPUA-1` profile; this avoids inventing national mappings.

There is intentionally no unqualified PASCII alias. Callers must choose the
exact source-identity profile, the forensic profile, or a named language
projection.

## Projection policy and exceptional cells

The two best-fit profiles differ at `8C`, `98`, `9D`, `AB`, and `BA`. The
Urdu/Kashmiri values are respectively `0679`, `0688`, `0691`, `06A9`, and
`06CC`; the Sindhi values are `067D`, `068A`, `0699`, `06AA`, and `064A`.

- `9E` is the source letter RHEY. Its logical `0699+06BE` sequence is an
  Iconvex best-fit inference; the source does not define Unicode conversion.
- `C4` is the Kashmiri wavy-hamza-above source cell and retains its
  source-qualified `F8CC4` token because no standalone scalar is exact.
- `CB` uses the nearest Unicode 17 best-fit scalar, `FBC2 ARABIC SYMBOL WASLA
  ABOVE`. The source cell is a combining diacritic mark, while `FBC2` is a
  spacing pedagogical symbol (`General_Category=Sk`), so this is explicitly
  not an exact identity mapping.
- `D4` is combining superscript kaf and retains `F8CD4` because Unicode 17 has
  no exact scalar.
- `EF` is the assigned PASCII ATR control. The supplied standard does not
  define stand-alone behavior, so it retains `F8CEF`.
- `F8` and `FC` use nearest display equivalents `25CF` and `25CC` only in the
  named best-fit projections.

For duplicate Unicode results, best-fit encoding uses the lowest PASCII byte.
Two-scalar sequences are matched before single scalars. The exact lossless and
raw profiles are bijective and do not use this collision policy.

GNU libiconv 1.19 does not expose a PASCII codec. These profiles therefore do
not claim GNU alias identity or GNU differential equivalence. PASCII is an
octet encoding, so packed non-octet transports do not apply.
