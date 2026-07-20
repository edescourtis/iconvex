# IBM/DEC additional single-byte code pages

This directory pins the source records and generated 256-byte mapping vectors
for six catalog gaps. A blank IBM registry cell is `UNDEFINED`; it is never
filled by guessing from a related page.

The generated vector format is exactly 256 LF-terminated rows, ordered by byte:
`XX=U+YYYY[+U+YYYY...]` or `XX=UNDEFINED`. The SHA-256 of the file is therefore
also the mapping-vector identity used by the exhaustive tests.

## Primary page records

| File | URL | SHA-256 | Rights/source confidence |
| --- | --- | --- | --- |
| `CP00310.txt` | https://public.dhe.ibm.com/software/globalization/gcoc/attachments/CP00310.txt | `a5fcdf29fe3de63927b7ab29fd2c03a6aecbd12f3909051b23a09cbb2d15e99c` | IBM corporate registry, copyright IBM; primary/high |
| `CP00310.pdf` | https://public.dhe.ibm.com/software/globalization/gcoc/attachments/CP00310.pdf | `af8c6a11e3e630eb136753fcafee48fd1bda2dc154d38183a58b1c87e4edcf0f` | IBM corporate registry, copyright IBM; primary/high |
| `CP00907.pdf` | https://web.archive.org/web/20170803005351id_/http://www-03.ibm.com/systems/resources/systems_i_software_globalization_pdf_cp00907z.pdf | `f643cce61bfdd3698538ca36c6ed574e557acac1f10017b8d29548b897af2ed2` | byte-exact archived original IBM PDF, created 1999-01-29; primary/high |
| `CP01116.pdf` | https://web.archive.org/web/20130121105553id_/http://www-03.ibm.com/systems/resources/systems_i_software_globalization_pdf_cp01116z.pdf | `e7f62540a940647735bab74e32f81ad26520c18d677bd66f21126c2040cdaa88` | byte-exact archived original IBM PDF, created 1999-02-01; primary/high |
| `CP01117.pdf` | https://web.archive.org/web/20130121105553id_/http://www-03.ibm.com/systems/resources/systems_i_software_globalization_pdf_cp01117z.pdf | `b43b945bff9a0757d218e216aa63ba41bd414e6e575499f186dd3a5c9b726655` | byte-exact archived original IBM PDF, created 1999-02-01; primary/high |
| `CP01287.txt` | https://public.dhe.ibm.com/software/globalization/gcoc/attachments/CP01287.txt | `d69294ca9e92e4ba1d70efbe0e7e2a19312e2e74530adbd82d01773c15fd3282` | IBM corporate registry; primary/high |
| `CP01287.pdf` | https://public.dhe.ibm.com/software/globalization/gcoc/attachments/CP01287.pdf | `7acba5b3ec8770714b7321cfd14cfa6446ef0ddb3a78dbf8eb56c1a404b96b96` | IBM corporate registry; primary/high |
| `CP01288.txt` | https://public.dhe.ibm.com/software/globalization/gcoc/attachments/CP01288.txt | `7e2428fb5c507610c57f0f3c4ff1e93b1ec1c9a4e26c2b27f07b2b4d19dc583f` | IBM corporate registry; primary/high |
| `CP01288.pdf` | https://public.dhe.ibm.com/software/globalization/gcoc/attachments/CP01288.pdf | `89c87f75c8c71d072be4daf9da52a465828a40cc390d0dcbc09f0558792290bb` | IBM corporate registry; primary/high |
| `DEC-PPL2-1994.pdf` | https://www.filibeto.org/dec/mds/mds-2000-01/cd3/PRINTER/PPLV2PMB.PDF | `0d47bb9b30100ab2b24bdf05cf565775970442736a42c7cbb9f98ca55a4cf13f` | Digital Equipment Corporation, revised August 1994, figures A-24 and A-27; primary/high |

The DEC manual explicitly defines the C0/GL/C1/GR structure (pages 2-2 through
2-6) and the Greek/Turkish supplemental glyph positions (PDF pages 212 and
215, printed pages A-33 and A-37). IBM's CPGID records independently identify
the same graphic positions and reserved cells.

## Pinned GCGID join records

The following public IBM registry pages identify GCGIDs at byte positions.
Their Unicode bindings come from the already-pinned ICU/IBM P100 UCMs named
below. These are composite interoperability profiles, not claims that IBM
published a direct CP310/907/1116/1117-to-Unicode converter.

| Registry file | SHA-256 | Paired pinned UCM |
| --- | --- | --- |
| `CP00293.txt` | `0f723444e11f78432168fe7c12d10c036593ac70330e18195a8e1e5cd2875e64` | `../icu-data-archive/ibm-293_P100-1995.ucm` (`70ca25804681baa573f84ec694951e50c0598d815d7683762e3281047abe1c14`) |
| `CP00437.txt` | `973a8ef3aa0690fd4ea918e7142f1447d0d16a68003eb9b761e028d8ab2b5638` | `../icu-data-archive/ibm-437_P100-1995.ucm` (`4875092cba330259cebbd4534634d83078cc1ea9470ad1c0eb17843fddea099b`) |
| `CP00775.txt` | `8b06074e87afef2b3228f301dbcf764b1e286f65286598656d316c67fe46aa3c` | `../icu-data-archive/ibm-775_P100-1996.ucm` (`6bc21a45b66dc1a28393d73370faa611c427f71b036e1a31bda9b6fc6a808ba2`) |
| `CP00850.txt` | `68cefeb52ce17ec100c4d845872dd03589432f4986a92ff8548c6fa2aed333a7` | `../icu-78.3/ibm-850_P100-1995.ucm` (`15bbc9b79c1082c6a5ded898de123c062bd67fccfc0ac62bac9d96f73bfa8435`) |
| `CP00857.txt` | `2a17021d45c8235ed7732db16271083adc26114889f02241e1d47b74fe9b571a` | `../icu-data-archive/ibm-857_P100-1995.ucm` (`83bac1ad2e228a243f8afc542695429dce608508def6a29a4915f6426c5406b9`) |
| `CP00875.txt` | `baaf5f62fb24fd81cf030af62ef6ec0e34d4fe9645ca197c714c74d076d5a20c` | `../icu-data-archive/ibm-875_P100-1995.ucm` (`c77699ab4daffc76b16f7201c2204b64703180073d0efcf2dab696fb8a3b4a3d`) |
| `CP01254.txt` | `c13575bc25e7339bbd4cd7b1c7f8617103fa7d4a110d7e88d77431eaeaae694d` | `../icu-data-archive/ibm-1254_P100-1995.ucm` (`81fd4890f30a47f3f5cf46e447d49a6d53aa2f7f10dd3ee857a73ea707ba86d1`) |

Deterministic join rule: target byte -> target GCGID; look up the same GCGID in
the paired registry pages in the table order above; use that paired UCM byte's
round-trip Unicode mapping. For IBM PC graphic C0 positions, use the UCM `|1`
graphic fallback rather than its `|0` control interpretation. If several pages
agree, the value is unchanged. The four known context collisions are resolved
as follows: `SM240000=U+00A7`, `SM250000=U+00B6`, `SM570000=U+2022`, and
`SD630000=U+00B7`. `SM910000` is page-profile-specific: CP907 and CP1117 use
the IBM-437 P100 value U+266B; CP1116 uses the IBM-850 P100 value U+266C.

CP310's `IBM-293-P100-COMPOSITE-VPUA` profile gives first priority to the
IBM-293 P100 VPUA binding whenever CP293 contains the GCGID. It then applies
the deterministic join above, and finally uses the pinned IBM/tnz row only for
a still-unbound GCGID. This priority is intentionally profile-specific; no
generic `IBM-310` identity is asserted.

## IBM/tnz CP310 revision

`ibm-tnz-cp310-07d60f4.py` is the exact `tnz/cp310.py` blob
`07d60f4de096704112b8701885d6dba682224426` at IBM/tnz commit
`b1eae3c8200188b77aceb40754bf89ccbf7646a4` (2026-07-13):

https://github.com/IBM/tnz/blob/b1eae3c8200188b77aceb40754bf89ccbf7646a4/tnz/cp310.py

SHA-256: `204acf3acc22396487b6cb450874af3f41e73f59fcbdcb16a86fa62c4f87ca42`.
IBM/tnz declares Apache-2.0. The exact revision profile preserves its table
byte-for-byte, including the underlined-letter rows whose comments mention a
combining low line that the Python string itself does not contain. It therefore
has only revision-specific names and must not receive a generic CP310 alias.
Unlike the 139-cell IBM registry page, this pinned revision also assigns bytes
E4–E7 to U+2364, U+2365, U+236A, and U+20AC. Those four revision-specific rows
remain defined only in the IBM/tnz profile, not the registry composite.

## Deterministic regeneration

From the repository checkout, regenerate every vector with:

```sh
elixir tools/ibm_additional_code_pages_generator.exs --write
```

The checked-in pure-Elixir generator parses the IBM registry text, the pinned
ICU UCM CHARMAP records, and IBM/tnz's ordered Python table directly. It also
implements the PDF LZW decoder and coordinate-grid extraction needed for the
three IBM pages published only as PDFs. Candidate UCM mappings prefer graphic
values over C0/C1 control interpretations and then round-trip (`|0`) mappings
over fallbacks; unresolved collisions use only the four documented GCGID
overrides and the page-specific `SM910000` choice stated above. CP310 applies
its separately documented IBM-293-first rule. Any remaining ambiguity or
unresolved GCGID aborts generation.

`test/ibm_additional_code_pages_review_test.exs` regenerates all seven files
in memory and requires byte identity with the shipped vectors. Hex releases
contain only those seven `.map` files and this metadata file; the PDFs, registry
text, UCMs, and IBM/tnz source remain repository-only pinned provenance.

## Generated mappings

| Profile | Defined bytes | Mapping SHA-256 |
| --- | ---: | --- |
| CP310 IBM-293 P100 composite VPUA | 139 | `2165de9ceec4811cc4305d3c3b45d595ddaf450ab3d4dff3b25bf62b8058494e` |
| CP310 IBM/tnz blob 07d60f4 | 143 | `96cdf110667cdc28bb0f5e4b3a7185e3427d295f7f132f0a66e906f5bedbe932` |
| CP907 CDRA P100 VPUA composite | 242 | `57f3c8b9b9a0cc40119e27315eb9748d75380d2690cd14b4816f0f9451299134` |
| CP1116 IBM-850 P100 composite | 255 | `0a802f4be6b771ad0b4c7d1f958da0f599025337b5592f917bc520081a0020cb` |
| CP1117 IBM-437 P100 composite | 254 | `9f00f6453bd43c81723b8f272999293d1fe2ddcf85ea8cce5b3f04e8d0ffd91e` |
| DEC Greek 8-bit, 1994 | 242 | `542afe11b341a24a9ac9547d2144e2aa88e0b2dc959bbf1c984b8ff6d6795525` |
| DEC Turkish 8-bit, 1994 | 248 | `6cb89e4f2a571b9664a8c8cd66a12bf3ce221153f44adee2c8ec4fa396ba03ba` |

Canonical encoding scans each vector from byte 00 through FF and selects the
last (therefore highest) byte for a duplicate Unicode scalar. The complete
collision set is: IBM/tnz CP310 U+2502 uses BF rather than 85; CP1116 U+00B6
uses F4 rather than 14 and U+00A7 uses F5 rather than 15; CP1117 U+00B6 uses F4
rather than 14. The other four vectors contain no duplicate Unicode scalars.

All IBM corporate-registry and Digital manual files retain their original
copyright notices. They are provenance/reference data and are not relicensed by
Iconvex. ICU UCM inputs retain the Unicode/ICU data-file terms. The generated
Elixir implementation remains under Iconvex's project license.
