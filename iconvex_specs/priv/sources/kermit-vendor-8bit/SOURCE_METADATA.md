# Kermit vendor 8-bit source metadata

The executable mappings in this slice are transcribed from the named
`x_to_unicode` tables in the pinned C-Kermit `ckcuni.c` source already vendored
under `priv/sources/dec-terminal-character-sets/kermit/`. The accompanying
BSD-3-Clause terms are shipped at
`priv/sources/dec-terminal-character-sets/kermit/COPYING`.

The exact source table names are:

- `u_cp856`: Bulgarian DATECS PC page, exposed as `BULGARIA-PC` rather than the
  conflicting IBM Hebrew `CP856`.
- `u_mazovia`: the original Mazovia/CP667 profile.
- `u_qnxgrph`: the QNX console PC-graphics profile.
- `u_dgi`: Data General International.
- `u_dgline`: Data General line-drawing repertoire, exposed as the
  source-qualified `KERMIT-DG-LINEDRAWING`.
- `u_dgword`: Data General word-processing repertoire, exposed as the
  source-qualified `KERMIT-DG-WORDPROCESSING`.
- `u_hpmath`: HP math/technical repertoire, exposed as the source-qualified
  `KERMIT-HP-MATH-TECHNICAL`.
- `u_snibrack`, `u_snieuro`, `u_snifacet`, and `u_sniibm`: Siemens Nixdorf
  97801 terminal repertoires, exposed under source-qualified `KERMIT-SNI-*`
  canonical names.

Pinned source SHA-256:
`af93d5a1c779aa73fa3221ab5ec0125de20267110cf23395971ce35cc88527ca`.

Independent primary/vendor documentation used during the identity audit:

- SunOS 5.9 `iconv_maz(5)`, “code set conversion tables for Mazovia”:
  <https://shrubbery.net/solaris9ab/SUNWaman/hman5/iconv_maz.5.html>
- QNX `devc-con` documentation, PC character-set designation `ESC ) U` and PC
  character-set charts:
  <https://www.qnx.com/developers/docs/8.0/com.qnx.doc.neutrino.utilities/topic/d/devc-con.html>
- DATECS printer command reference, code-table selector 8, “Bulgarian (856)”:
  <https://www.datecs.bg/en/downloads/pdf?id=CRM_ESC_POS_printeri_271120.pdf>
- Data General, *Programming the Display Terminals Models D217, D413, and D463*,
  table 2-7 and the Data General International charts:
  <https://bitsavers.trailing-edge.com/pdf/dg/terminals/14-002111-00_Programming_the_Display_Terminals_Models_D217_D413_and_D463_Oct91.pdf>

The independently parsed unit tests use the pinned C tables as the exact Unicode
oracle and separately guard the documented identities and near-matches. They
exercise all 256 possible input octets for every profile, including the
94-position tables' identity prefix and invalid tail, and verify the complete
first-byte canonical inverse. This is necessary because historical sources
disagree on some glyph semantics; the codec names identify the exact
Kermit/vendor profiles rather than silently normalizing them to a nearby IBM or
RFC table. The two Kermit tables explicitly marked "Needs to be checked"
(`u_dgspec` and `u_hpline`) remain excluded.
