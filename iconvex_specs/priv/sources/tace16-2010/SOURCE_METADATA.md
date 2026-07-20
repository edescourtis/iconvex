# Tamil Virtual University TACE16 Appendix D source metadata

Iconvex implementation code and `appendix_d.csv` are licensed under
`LGPL-2.1-or-later`. The copyrighted government report is referenced and
digest-pinned but is not redistributed.

## Exact source

- Publisher: Tamil Virtual University / Government of Tamil Nadu committee.
- Title: *Report of the Committee on Adoption of Tamil Unicode* (2010).
- Source: <https://www.tamilvu.org/coresite/download/final_report.pdf>
- Retrieved size: 12,903,119 bytes.
- Retrieved SHA-256:
  `78c77c607892d8f70bda3bbd9ca01371ddf2fe5fc8f3ef0481975d59abf3435c`.
- Normative material transcribed: Appendix D, physical PDF pages 35-47,
  including D3 Letters and D4 Symbols.
- Normalized mapping SHA-256:
  `f48482c6dc89c70b5c04dc5314cbccbec810a11b9484eb9216db662b03928ebe`.

Appendix D assigns exactly 380 TACE16 Private Use Area values. It supplies a
Tamil Unicode equivalent for 360 values. The equivalent column is blank for
four historic symbols (`E108..E10B`) and 16 fractions (`E1A0..E1AF`); these 20
values decode to their declared PUA scalar so conversion remains lossless and
does not invent a Unicode semantic equivalent. All other unassigned 16-bit
values are invalid.

The report specifies 16-bit code values but does not define a byte order, BOM,
or byte-stream serialization. Iconvex therefore makes no ambiguous `TACE16`
byte codec claim. It exposes two explicit zero-BOM transports:

- `TAMILVU-TACE16-APPENDIX-D-2010-16BE`
- `TAMILVU-TACE16-APPENDIX-D-2010-16LE`

Encoding uses exact longest sequence matching through four Unicode scalars.
GNU libiconv 1.19 has no exact TACE16 comparator.
