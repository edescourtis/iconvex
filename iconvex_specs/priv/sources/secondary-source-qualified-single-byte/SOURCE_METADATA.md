# Secondary source-qualified single-byte mappings

These three normalized CSVs contain only byte positions, Unicode scalar
sequences, and assignment status. They are independently normalized factual
mappings, distributed with Iconvex under `LGPL-2.1-or-later`. The linked
Wikipedia revisions are licensed under
[CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/), recorded by
the runtime as `CC-BY-SA-4.0`; the original wikitext, prose, formatting, and
character names are not bundled. Attribution is to the contributors shown by
each pinned revision history. Naming a source, publisher, company, product, or
encoding does not imply vendor authorship, affiliation, approval, or endorsement.

That CC license applies only to the pinned Wikipedia revisions. The Wang PDF
is copyrighted vendor documentation for which no redistribution license was
identified (`NOASSERTION`). It is an external, digest-pinned chart reference
and is not bundled. It is not described as CC BY-SA or LGPL-covered evidence.

All unassigned cells are strictly undefined. Decode rejects them unless the
caller selects discard recovery. Encode uses longest Unicode-sequence match and
the lowest byte when duplicate byte mappings exist. None of the profiles claims
a generic encoding alias.

## `WANG-1983-WISCII-PDF-F4043449-WIKIPEDIA-REV1352856854`

- Primary-chart identity: Wang Laboratories, VS Multi-Station User's Reference,
  document 800-1149-01, December 1983, Appendix D page D-1
- Runtime source identity: Wang Laboratories, VS Multi-Station User's Reference, document 800-1149-01, December 1983, Appendix D page D-1
- Primary chart: Wang Laboratories, *VS Multi-Station User's Reference*,
  document 800-1149-01, December 1983, Appendix D page D-1.
- Primary URL:
  <https://bitsavers.org/pdf/wang/vs/800-1149-01_VS_Multi-Station_Users_Ref_198312.pdf>
- Primary PDF bytes: 7151974
- Primary PDF SHA-256:
  `f4043449df7ca900a8d2aef137b82ade74f6dcff46aed8b7d49f57af927b7dfe`
- Primary rights: copyrighted Wang documentation; no redistribution license
  was identified (`NOASSERTION`). The PDF is not bundled, and the
  `CC-BY-SA-4.0` declaration below does not apply to it.
- Unicode-binding identity: Wikipedia revision
  [1352856854](https://en.wikipedia.org/w/index.php?oldid=1352856854),
  2026-05-06T17:04:40Z, MediaWiki SHA-1
  `8a2bed93cde9e5a4ac2983bbb0ce52369c5dcfc0`.
- Unicode-binding license: `CC-BY-SA-4.0`.
- Pinned wikitext bytes: 16842; SHA-256:
  `1a9fceddcf9c4c647c88d750cdd60d9d14aecb339d727d3f7d781a826d85367f`.
- Normalized mapping SHA-256:
  `f40f80a592676f36f782481d9826996528471589795f969fe817fc3ac2c50bb7`.
- Cardinality: 221 assigned, 35 undefined.
- The primary scan fixes the byte-to-glyph chart. The licensed revision fixes
  the Unicode interpretation, including two-byte-to-sequence cells `B7` and
  `C7`. Five duplicate scalar mappings encode to their lowest byte.

## `WIKIPEDIA-REV1354794598-PARATYPE-WINDOWS-POLYTONIC-GREEK`

- Source identity: Wikipedia revision 1354794598 (current B5/FF ordering)
- Source license: `CC-BY-SA-4.0`.
- Licensed source: Wikipedia revision
  [1354794598](https://en.wikipedia.org/w/index.php?oldid=1354794598),
  2026-05-18T07:38:26Z, MediaWiki SHA-1
  `5eb9fc1a572b301732f0ffc7a552da92f1e4c6ad`.
- Pinned wikitext bytes: 22122; SHA-256:
  `5e7b59478b825549f63553c06e0e19a3cc2e6de1c334507a9797f605eec10a0f`.
- Normalized mapping SHA-256:
  `12774c7a072e9976b6903f8388130891833a24d10086e59d6878ebf45d99d324`.
- Cardinality: 256 assigned, 0 undefined.
- This identity selects the revision's current ordering. The page explicitly
  says an older FontLab mapping swaps bytes `B5` and `FF`; that older profile is
  not silently conflated with this one.

## `WIKIPEDIA-REV1340817319-EKI-SAMI-WIN-CP1270`

- Source identity: Wikipedia revision 1340817319 corroborated by EKI HTML SHA-256 f25f60fa
- Source license: `CC-BY-SA-4.0`.
- Licensed source: Wikipedia revision
  [1340817319](https://en.wikipedia.org/w/index.php?oldid=1340817319),
  2026-02-27T21:55:11Z, MediaWiki SHA-1
  `086415d538dbfe2c911994ed11c45f629ad59350`.
- Pinned wikitext bytes: 16887; SHA-256:
  `2dc0a6b1da5d1d279f4334cd1f8d95a9c878d022c02f6a27bd25eaf80d84ec57`.
- Independent EKI evidence:
  <https://arhiiv.eki.ee/letter/chardata.cgi?cp=SAMI_WIN%20(CP1270)&1st=with%20first%20half&table=on>,
  retrieved 2026-07-18, 28069 bytes, SHA-256
  `f25f60fa9608873563fd35449a937b1c3083169d876dd82b2c7a3b20345b6395`.
- Normalized mapping SHA-256:
  `9fdf47f7766938ab266cd5b9776d00329cf4083c1ce68af4fc4ce0a439ea32e4`.
- Cardinality: 249 assigned, 7 undefined (`81`, `8D`, `8E`, `8F`, `90`,
  `9D`, `9E`).
- The two independent tables agree at every non-NUL byte. EKI renders NUL as
  a blank browser cell; the Wikipedia revision and the requested EKI first-half
  profile make byte `00` the ordinary U+0000 identity.
