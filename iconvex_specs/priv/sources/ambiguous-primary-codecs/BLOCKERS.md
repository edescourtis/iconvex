# Ambiguous primary codec blockers

This directory pins the primary or best-available artifacts used to reject six
apparently implementation-ready catalog rows.  These are positive blocker
results: the evidence is sufficient to show that an exact Unicode codec cannot
yet be derived without guessing, conflating profiles, or silently changing the
published mapping.

The dispositions below deliberately do not select replacement characters,
private-use characters, visually similar characters, or mappings from a related
code page.  Such substitutions would make round trips look complete while
changing the encoded character repertoire.

## CER-GS (`ENC-0095`)

Primary/source-qualified table:
<https://www.evertype.com/standards/mappings/pc/CERGS.TXT>, version 1.01 dated
2002-02-20, 10,458 bytes, SHA-256
`9aece7742b4fc70f6047f888815efc1f21f08b521c03e07ed96e91b50fc25f36`.

The published table is not byte-unique.  It assigns B7=U+1E40 and B7=U+1E41,
B8=U+02C6 and B8=U+1E81, B9=U+1E56 and B9=U+1E57, and BA=U+1E60 and
BA=U+1E83.  It also assigns byte 8F to U+027C while the publisher's repertoire
page, <https://www.evertype.com/celtscript/celtcode.html>, places U+027C at BF.

**Closure requirement:** Do not implement CER-GS until the publisher supplies a
corrected, byte-unique revision (or an independently authoritative erratum)
that resolves every duplicate and the 8F/BF conflict.

## IBM code page 1058 (`ENC-0149`)

Pinned IBM primary graphic grid: `CP01058.pdf`, CP01058Z, created 1999-02-01,
243,106 bytes, SHA-256
`c806982963594a77a3f1484592fae738fcf95e8531a419e9205d187287468b36`.
It was recovered from
<https://web.archive.org/web/20130121110539id_/http://www-03.ibm.com/systems/resources/systems_i_software_globalization_pdf_cp01058z.pdf>.

The grid assigns 255 byte positions through IBM GCGIDs, not Unicode.  Joining
those GCGIDs to the pinned IBM/ICU mappings leaves these eight identities
without an exact Unicode binding: 5E `SD150200`, 60 `SD130100`, 7C `SF660000`,
9E `LL640000`, 9F `LL630000`, AB `SM160000`, AC `LN630000`, and F8
`SD270200`.  At 0E, `SM910000` is ambiguous between U+266B and U+266C in the
available crosswalks.

The superficially related PC8 Danish/Norwegian (PCL 11U) mapping is not an
identity proof.  Of 246 positions resolved through GCGIDs, seven disagree:
7E (U+007E/U+02DC), 7F (U+2592/U+2302), E1 (U+03B2/U+00DF), E6
(U+03BC/U+00B5), FC (U+03B7/U+207F), FE (U+25A0/U+25AA), and the PCL table
does not assign IBM's 20 `SP010000` position.

**Closure requirement:** Do not implement code page 1058 until an IBM converter
table or equally authoritative GCGID-to-Unicode source resolves the eight
unbound identities and `SM910000`; a related PC8 profile must not be substituted.

## IBM code page 1118 (`ENC-0167`)

Pinned IBM primary graphic grid: `CP01118.pdf`, CP01118Z, created 1999-02-01,
241,940 bytes, SHA-256
`360ca9a155ef35171365d943b38faaa2ca553b0252e41261cd0f1b387d7940e9`.
It was recovered from
<https://web.archive.org/web/20130121105411id_/http://www-03.ibm.com/systems/resources/servers_eserver_iseries_software_globalization_pdf_cp01118z.pdf>.

The grid has 255 assigned, distinct GCGIDs.  The pinned crosswalk leaves
EF `SA140000` and FA `SD290000` unresolved, while 0E `SM910000` again has the
U+266B/U+266C conflict.  GNU/ICU CP774 is related, but it is a text-converter
profile rather than proof of identity with this graphic grid.  Across the 252
GCGID-resolved positions, 32 differ: the IBM grid gives graphics at C0 byte
positions where CP774 gives controls, IBM 7F is U+2302 where CP774 is DELETE,
and IBM E1's beta GCGID resolves to U+03B2 where CP774 maps U+00DF.

**Closure requirement:** Do not implement the generic code-page-1118 identity
until an exact IBM/LST1283 converter mapping resolves EF, FA, 0E, and the
C0/DEL semantics.  Keep CP774 available only under its own exact profile name.

## IBM code page 899 (`ENC-0266`)

Pinned IBM primary tables:

- `CP00899.txt`, 8,150 bytes, SHA-256
  `35c61df06c2f004b8c01f166339e943829767a9dec79e70a04bf8a1a1828b464`,
  from <https://public.dhe.ibm.com/software/globalization/gcoc/attachments/CP00899.txt>;
- `CP00259.txt`, 7,882 bytes, SHA-256
  `2a034df8a13bd44a26ee12439eb670fe8966499dc06280d692bd448d5eecdd57`,
  from <https://public.dhe.ibm.com/software/globalization/gcoc/attachments/CP00259.txt>;
- the pinned ICU IBM-259 P100 mapping
  `../icu-data-archive/ibm-259_P100-1995.ucm`, SHA-256
  `05577c5aa09a23b3d330f96be59789c4789a97c64864b501725315bce5c3535d`;
- `CP01445.txt`, SHA-256
  `d0499e82d6dd32524dd9ac98e8f793b56841b85e42edd740233b7710499790aa`,
  from <https://public.dhe.ibm.com/software/globalization/gcoc/attachments/CP01445.txt>.

CP899 contains 192 assigned byte positions and 190 distinct GCGIDs.  A
CP259-priority GCGID/P100 join resolves 188 of those 190 identities.  It leaves
only byte 99 `SM600001` ("Solid Triangle, Rotated") and byte B4 `SA350008`
("Angle Symbol") without standardized Unicode bindings.  CP1445 associates
`SA350008` only with IBM AFP private-use position U+0FF020; that is not a
standard character identity.  A survey of the current public IBM CP text
registry found no second binding for `SM600001`.

**Closure requirement:** Do not implement code page 899 until IBM or another
authoritative source gives standardized Unicode identities for `SM600001` and
`SA350008`.  Do not guess visually similar triangle/angle characters or expose
an AFP private-use assignment as a portable mapping.

## IBMEL punched-card code (`ENC-0961`)

Best-available complete table:
<https://homepage.cs.uiowa.edu/~jones/cards/codes.html>, archived locally as
`../punched-card-codes/uiowa-punched-card-codes.html`, SHA-256
`824e61a9687f7fa0b9c9dd3c966ca02020bf8af1ab6671e9bd2e131f22f47b18`.
The page attributes the table to Dik Winter, so it is a complete secondary
reconstruction rather than Electrologica primary documentation.

The page explicitly corrects its HTML superscript-three placeholder at punch
mask 0x282 `subscript ten`.  That semantic character has no single assigned
Unicode identity, and mapping it to U+00B3 or silently expanding one card column
to the two-code-point string U+2081 U+2080 would not preserve the source code.

**Closure requirement:** Do not implement IBMEL until primary Electrologica
documentation or an authoritative encoding registry supplies the exact Unicode
binding and sequence policy for the `subscript ten` position.

## UNIVAC 1108 punched-card code (`ENC-1443`)

Best-available table and provenance are the same University of Iowa artifact,
SHA-256
`824e61a9687f7fa0b9c9dd3c966ca02020bf8af1ab6671e9bd2e131f22f47b18`.
The page says this table was inferred from a single punched card.

Two centered-dot placeholders at punch masks 0x006 and 0x806 are only described
as codings that differ from the IBM 70x convention.  The source does not name
either graphic, so treating both as U+00B7 would convert editorial placeholders
into invented character assignments.

**Closure requirement:** Do not implement the UNIVAC 1108 card code until a
primary UNIVAC table or independent exact source identifies both unnamed
graphics at 0x006 and 0x806.
