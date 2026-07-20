# lietuvybė.lt LST table snapshots

These normalized mapping tables are factual transcriptions of the character
tables in the `lietuvybe-lt/lietuvybe.lt` repository at the immutable commit
`52a97895aad2ba40e93a1da28a63c964ad63b9eb` (2026-05-13). They support
source-qualified compatibility codecs only. Their presence does not imply
authorship, affiliation, approval, or endorsement by the repository authors,
the Lithuanian Standards Board, or the Lithuanian Standards Department.

This is not an implementation claim for the official standards. In particular,
the official correction documents `LST 1564:2000/P:2012`,
`LST 1590-2:2000/P:2012`, and `LST 1590-4:2000/P:2012` were identified in the
Lithuanian Standards Department catalogue/bulletins, but their normative text
was not publicly readable during this audit. Consequently the codecs expose no
generic `LST` or DOS/Windows code-page aliases.

The official designation/status evidence is the Lithuanian Standards
Department bulletin `LST biuletenis 2022-11-30 Nr. 22`:
<https://lsd.lrv.lt/uploads/lsd/documents/files/Biuletinis/2022/LST_biuletenis_2022-11-30__Nr__22.pdf>.
That bulletin establishes the correction identifiers, not their normative byte
tables, so it cannot remove the source-qualification boundary above.

## Pinned source

- Repository commit: `52a97895aad2ba40e93a1da28a63c964ad63b9eb`
- Commit URL: <https://github.com/lietuvybe-lt/lietuvybe.lt/tree/52a97895aad2ba40e93a1da28a63c964ad63b9eb>
- Mapping source: `content/standartai/rašmenų-koduotės/index.md`
- Raw source URL: <https://raw.githubusercontent.com/lietuvybe-lt/lietuvybe.lt/52a97895aad2ba40e93a1da28a63c964ad63b9eb/content/standartai/ra%C5%A1men%C5%B3-koduot%C4%97s/index.md>
- Source size: `42924` bytes
- Source SHA-256: `ac4ae79efcf577157ed00972960711966c2375285128c07a6ad2485d983f8077`
- Table-introduction commit: `5e931495ae6cf3c1f8c05c4c61eed85b25d4660b`
- Table-introduction date: `2025-01-13T22:36:00+02:00`
- Table author/attribution: Rimas Kudelis / lietuvybė.lt
- Upstream repository license: `CC-BY-4.0`
- Upstream license URL: <https://github.com/lietuvybe-lt/lietuvybe.lt/blob/52a97895aad2ba40e93a1da28a63c964ad63b9eb/LICENSE>
- Upstream license SHA-256: `9ba9550ad48438d0836ddab3da480b3b69ffa0aac7b7878b5a0039e7ab429411`

The upstream prose and images are not redistributed here. The normalized CSV
files contain only byte positions and Unicode scalar sequences. Iconvex source
code remains `LGPL-2.1-or-later`.

## Linked graphic-table pins

- LST 1564 image: `1564.gif`, 26644 bytes,
  SHA-256 `24dfb403effbb247290c8f2cd4a5a51955545e9063c60d0edf45d43a94ccc40b`
- LST 1590-2 image: `1590-2.gif`, 27135 bytes,
  SHA-256 `87141757b543b2a6142e4dff91f0bc8af6ebeabef062e3194e234dc4ac965790`
- LST 1590-4 image: `1590-4.gif`, 26995 bytes,
  SHA-256 `a64df42822d17a01455927ff8cf3c6fe578d6f04f311ea13b05278d1bd0768dd`

Each image URL is the corresponding file below the pinned repository path
`content/standartai/rašmenų-koduotės/`.

For LST 1564, ISO/IEC JTC 1/SC 2/WG 2 document N4191 (Lithuanian Standards
Board contribution, 2011-12-05) independently reproduces the 2000 code table
on page 17 and lists the Unicode 6.0 Lithuanian named sequences on page 18.
The archived PDF is 1113048 bytes with SHA-256
`796923eb8b61c77d0bb713de8e4c7c6cb8e0dbdb77b5a149c84c3a6f6eb07be4`:
<https://web.archive.org/web/20220119201229id_/http://std.dkuug.dk/jtc1/sc2/wg2/docs/n4191.pdf>.

## Exact profile policies

- Bytes `00`-`7F` are ASCII/Unicode identity, as stated by the source page.
- A blank source table cell is strictly undefined. LST 1564 bytes `80`-`9F`
  are tagged `reserved_control` and rejected by the strict profile. The source
  prose separately notes that applications may choose a practical C1 identity
  interpretation; that optional interpretation is deliberately not folded into
  these `STRICT-BLANKS` codecs.
- Multi-scalar cells retain the exact Unicode sequence in the pinned Markdown.
  Inverse conversion uses unique longest match. All three tables have no
  duplicate complete Unicode mappings.
- The pinned LST 1590-4 snapshot maps byte `86` to U+025B. A secondary
  Wikipedia table maps that position to U+025C. The explicit commit-qualified
  identity preserves U+025B and prevents that disagreement from being hidden
  behind a generic standard name.

## Normalized artifacts

- `lst1564.csv`: 224 mapped bytes, 32 strict reserved-control slots,
  SHA-256 `fdc7ccd7e311b4530d58606ea47deb30186c143f84fbecb01062d45bd5326d04`
- `lst1590_2.csv`: 256 mapped bytes, no undefined slots,
  SHA-256 `defee7782bcba01ea7b3f6d85a0103813f6e72d2aaab728892b6bfbfa3fd4240`
- `lst1590_4.csv`: 249 mapped bytes, 7 undefined slots,
  SHA-256 `8d7325c6785dd6a18af90e576c827ed8386f1f6b14e1aed97618e650c3214b13`
