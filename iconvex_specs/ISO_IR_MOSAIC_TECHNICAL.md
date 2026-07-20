# ISO-IR mosaic and technical sets

These are raw ISO/IEC 2022 graphic sets: bytes are the registered code
positions, without an ISO-2022 escape/designation transport wrapped around
them. The tables are generated from the pinned ISO-IR sheets, the complete
ITU-T T.101:1994 source archive, Unicode WG2 N5028, and the revised IEC
mapping in WG2 N2032.

ISO-IR 71 and 129 use Unicode's sextant characters. ISO-IR 137 has twelve
standardized shapes with no exact Unicode character; they are mapped
losslessly to `U+F700 + encoded byte`. ISO-IR 173 maps DG01..DG50 and all
SG29..SG56 characters to exact Unicode drawing/smooth-mosaic characters.
DG51..DG65 have no exact Unicode characters and use `U+F800 + DG number`.
These PUA assignments are stable, one-to-one, documented in the normalized
mapping file, and included in exhaustive round-trip tests.

ISO-IR 129 deliberately decodes both 5/15 and 7/15 as FULL BLOCK, choosing
5/15 on encode. ISO-IR 181 deliberately has two APPROXIMATELY EQUAL TO
positions, choosing 3/8 on encode. Its 3/7 mapping follows revised WG2
N2032 (`U+2219 BULLET OPERATOR`), superseding Pike's older `U+22C5` value.

| Encoding | Decode | Encode | Direct Unicode | Stable PUA | Registration SHA-256 |
|---|---:|---:|---:|---:|---|
| `ISO-IR-71` | 94 | 94 | 94 | 0 | `e6b6e5c08bd91ed12d1913325d050f1199827ac059d2b2933cc93afaff2da6ac` |
| `ISO-IR-129` | 65 | 64 | 65 | 0 | `fe65b23482cace6a79ec2cc737021219f54b901e07565d193e69a44a14008dae` |
| `ISO-IR-137` | 59 | 59 | 47 | 12 | `d7252c700eaa517b49912c2465a14a4f9ce4e5daba6f07f255778f61678f88a9` |
| `ISO-IR-173` | 92 | 92 | 77 | 15 | `ea156b45c3e9aa67b397a4cbdc9f2a776c21806a621a4dae7df0f4e18947318c` |
| `ISO-IR-181` | 83 | 82 | 83 | 0 | `64ff12a2897e0fd168f78cf96c634892893ae072f354f26fb988bfabfa08e1ad` |


Source SHA-256 values:

- ITU-T T.101:1994 ZIP: `3ef283abe293cf2f8d531bccfa5716afb0969584527156ace3e164b25b768fbc`
- WG2 N2032: `ef4320cb50aff5b41a05211f89c433a08dc3966959fb7c4e732a81a61f9d9ac3`
- WG2 N5028: `e64a54b4b223b5e6a9d686a7a7ddd1fc98d0bc88585059be02078b082a760e61`
- N5028 `TELTXTG3.TXT`: `7a22e3566484d5f3f2fc645107588e521c8eb755fbd7b302180608d68ae8a7c3`
