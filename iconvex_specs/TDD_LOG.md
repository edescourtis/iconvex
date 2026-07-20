# TDD Log

## Review follow-up — clean-release Crypto dependency

- RED: the focused 9-test package-contract run failed because
  `iconvex_specs.app` omitted `:crypto` even though shipped source validators
  call `:crypto.hash/2`; an independently assembled clean release reproduced an
  `UndefinedFunctionError` from `ABICOMP.SourceAsset.high_hex/0`.
- GREEN: `extra_applications: [:crypto]` is declared in package metadata. The
  focused contract passes, and the clean production release includes Crypto
  and executes the validator successfully.

1. RED: RFC corpus/API contract failed because no importer or runtime existed.
2. GREEN: imported 145 definitions and implemented external table codecs.
3. RED: exhaustive round-trip tests exposed RFC IBM423's 272-cell overflow and
   intentional RFC `&duplicate` asymmetry.
4. GREEN: applied 38 pinned errata tables, rejected overflow, and published
   unresolved versus intentionally undefined counts.
5. RED: East Asian grid vectors failed because RFC synthetic mnemonics have no
   Unicode values.
6. GREEN: merged pinned JIS 0208, JIS 0212, KS X 1001, and CP936/GB-grid maps;
   143 of 145 RFC sets are now complete.
7. RED: RFC 3501 vectors failed because modified IMAP UTF-7 was absent.
8. GREEN: implemented strict direct/shift syntax, modified Base64, UTF-16BE,
   aliases, and malformed/noncanonical rejection.
9. RED: Java Modified UTF-8 and WHATWG `x-user-defined` had six missing-codec
   failures.
10. GREEN: implemented both and exhaustively inverted all 256
    `x-user-defined` bytes.
11. RED: BOCU-1 BOM, boundary, reset, ordering, and malformed-trail tests failed.
12. GREEN: ported Unicode Technical Note #6 and matched ICU's complete scalar
    stream byte-for-byte.
13. RED: SCSU ICU vectors, quoted surrogate pairs, reserved commands, and all
    range transitions failed.
14. GREEN: implemented both SCSU modes, all windows/definitions, strict state
    handling, and bidirectional ICU cross-decoding of every Unicode scalar.
15. RED: UTF-EBCDIC signature, I8 length boundaries, malformed trails, and
    canonical-form tests failed because UTR #16 was unimplemented.
16. GREEN: ported the normative I8 transform and complete 256-byte EBCDIC
    permutation, then round-tripped every Unicode scalar.
17. RED: seven Adobe/Apple contract tests failed before vendor mapping modules,
    pinned sources, providers, and registration existed.
18. GREEN: imported all 28 codec-bearing Unicode vendor maps (43,685 decoder
    and 43,607 encoder mappings), classified `CORPCHAR.TXT` and `UKRAINE.TXT`
    as non-codec inputs, and executed every generated mapping.
19. RED: nine MARC-8/ANSEL tests failed before LOC code tables, ISO 2022
    designation state, reversed combining order, and spanning-mark pairs existed.
20. GREEN: implemented all 12 MARC component sets, 16,395 executable scalar
    mappings, 60 combining mappings, both half-marker pairs, and 24-bit EACC.
21. RED: five ISCII tests failed before script variants, ATR/EXT state, and
    contextual Indic mappings existed.
22. GREEN: implemented ISCII-91 plus all ten Microsoft names and matched 13,069
    generated ICU4J 78.1 encode/decode vectors, including Gurmukhi clusters.
23. RED: five TSCII/BRF tests failed before the glibc charmap providers existed.
24. GREEN: imported TSCII 1.7 and BRF, including TSCII byte sequences that map
    to up to four Unicode code points, and executed every generated mapping.
25. RED: three extended-glibc tests failed because the 27 remaining charmaps,
    pinned revision metadata, representative multibyte mappings, and aliases
    were absent.
26. GREEN: imported all 27, then independently re-parsed and executed every row
    across all 29 pinned charmaps (22,249 decoder and 22,172 encoder mappings).
27. RED: five ICU UCM contract tests failed before the pinned source inventory,
    native codecs, source digests, aliases, and exhaustive direction checks
    existed.
28. GREEN: imported all 135 standalone ICU 78.3 SBCS revisions, classified all
    UCM precision flags, exercised 34,560 possible bytes and every canonical
    encode mapping, then passed 68,290 cases against the independent ICU 78.3
    runtime oracle.
29. RED: five multibyte UCM tests failed before the 30-source inventory,
    variable-length native tables, prefix errors, mapping exhaustiveness, and
    registration existed.
30. GREEN: imported 30 complete MBCS/DBCS definitions, executed 941,896
    generated directional mappings, and passed 885,966 mapped cases against
    the independent ICU runtime; three non-openable component maps remain
    explicitly source-verified.
31. RED: five mixed-EBCDIC tests failed before the ten-source inventory,
    SI/SO stream state, exhaustive mapping paths, canonical flush behavior,
    and registration existed.
32. GREEN: implemented a native SBCS/DBCS state machine, executed all 363,831
    generated directional mappings, and matched 363,831 independent ICU 78.3
    runtime cases including canonical shift framing.
33. RED: the historical-archive contract ran as two failures because no pinned
    1,050-source inventory, canonical namespace, manifest, or codec family existed.
34. GREEN: imported every UCM from pinned `icu-data` revision
    `d7d6dd5bb68930c5e6b3dd4491574153d3a1ba5a`, preserving all five declared
    classes plus 29 pre-class files under `ICU-ARCHIVE-*` names.
35. RED: registration failed when the unprefixed historical
    `cns-11643-1992` shadowed the current component map; the uniform archive
    namespace made all 1,050 revisions co-installable.
36. RED: ICU's independent oracle found `ibm-25546` decoding `21 21` in the
    wrong state because it declares MBCS while its explicit state table uses
    SI/SO transitions. It then exposed ICU's asymmetric U+FFFE/U+FFFF decoder
    sentinel behavior in `ibm-5487`/`ibm-5488`.
37. GREEN: `.s` state transitions now select the native SI/SO engine regardless
    of nominal class, decoder sentinels remain encode-only, all 8,716,218
    operational source directions execute, and ICU independently matches
    7,075,555 cases across all 977 archive sources accepted by modern
    `makeconv`. Repeating the complete run produced the same transcript digest.
38. RED: three Unicode-miscellaneous tests failed before the two separately
    versioned APL/ISO-IR-68 codecs and KPS 9566-2003 existed.
39. GREEN: pinned all three Unicode sources, implemented one/three-byte APL
    overstrikes and one/two-byte KPS mappings, preserved source-order ambiguity
    policy, and exhaustively executed every unique decoder and encoder mapping.
40. RED: the exact generated package inventory exposed a stale 1,555-codec
    assertion after newer public-spec families had landed. GREEN: runtime CSV
    generation and the package contract now agree field-for-field for every
    canonical name, alias, module, and statefulness flag.
41. RED: five IBM ESID 5404 contracts failed before the four ISO-2022 Japanese
    profiles existed. GREEN: IBM-5052/956, IBM-5053/957, IBM-958, and
    IBM-5055/959 execute all 35,598 IBM-895/952/955 source positions and
    canonical mappings, exact designations, strict errors, and UTF-8 paths.
42. RED: six UTF-9 contracts failed because no native nonet API or unambiguous
    byte transport existed. GREEN: all RFC 4042 vectors and all 1,112,064
    Unicode scalars pass through exact 9-bit, 16BE, and 16LE forms; malformed,
    overlong, surrogate, overflow, padding, and discard cases are strict.
43. RED: five UTF-18 contracts failed before the companion RFC 4042 format
    existed. GREEN: every scalar in planes 0/1/2/14 passes exact 18-bit, 24BE,
    and 24LE paths; every excluded plane, surrogate, partial value, and nonzero
    padding form is rejected.
44. RED: adding the non-octet families made both generated inventories and the
    package counts fail. GREEN: 1,657 registered byte transports, 1,659 audited
    entries, and two bare non-octet formats now have exact runtime snapshots.
45. RED: five IBM-965 contracts failed before its ESID 5404 state machine was
    implemented. The first GREEN attempt exposed a mistaken modern-CNS vector;
    exact CP960 maps U+4E00 to `44 21`, proving why the component revision must
    not be substituted. GREEN: all 8,836 graphic positions, 5,916 canonical
    mappings, ASCII, state framing, errors, discard, aliases, and UTF-8 paths
    pass; the inventory contract then intentionally turned RED.
46. GREEN: regenerated runtime inventory and package assertions now agree on
    1,658 registered codecs and 1,660 audited entries including IBM-965.
47. RED: four IBM PC-mixed contracts failed before CCSIDs 934 and 938 existed.
    GREEN: exact pinned CP891+CP926 and CP904+CP927 composition classifies all
    256 initial bytes and all 44,288 lead/trail inputs, executes 31,329 decoder
    and 31,140 canonical encoder mappings, and passes strict/discard/UTF-8/name
    contracts. Component lead and SBCS sets are proven disjoint.
48. RED/GREEN inventory: adding the two complete codecs made all three exact
    package-count assertions fail; regenerated inventory and assertions agree
    on 1,660 registered and 1,662 audited entries.
49. RED: four IBM-1175 contracts failed before the standards-facing CCSID
    existed. GREEN: all 256 bytes and every preferred encoder match IBM's 2013
    CDRA table; an independent comparison proves zero differences against the
    pinned IBM-authored ICU component, including lira/euro updates.
50. RED: four IBM-17354 contracts failed before its ESID 5404 profile existed.
    GREEN: exact ASCII+CP971 composition classifies all 8,836 graphic positions,
    executes all 8,412 encoders, and passes designation, shift, reset, strict,
    discard, alias, and UTF-8 paths.
51. RED: both additions made the three exact inventory/count assertions stale.
    GREEN: regenerated inventory and assertions agree on 1,662 registered and
    1,664 audited entries.
52. RED: seven six-bit contracts failed before ECMA-1, DEC-SIXBIT, their pinned
    scanned sources, strict unit handling, registry entries, and packed
    transports existed.
53. GREEN: implemented all 64 cells of ECMA-1's primary table and DEC's full
    ASCII projection/lowercase fold; every unit and both MSB/LSB packed orders
    pass. Production throughput is 59.64–148.54 MiB/s across four directions.
54. RED: adding both codecs made all three exact package-count assertions and
    the generated runtime inventory stale.
55. GREEN: regenerated inventories and assertions agree on 1,664 registered
    byte codecs, 1,666 audited entries, and two explicit six-bit packed
    profiles.
56. RED: six PDP-11 RADIX-50 contracts failed before the normative source,
    table, formula, explicit-endian transports, strict errors, and registry
    aliases existed.
57. GREEN: the DEC `X2B = 115402` octal vector, all 39 assigned digits in all
    three positions, both endian transports, padding, strict/discard/UTF-8, and
    registry conversion pass. An additional exhaustive test classifies all
    65,536 possible words.
58. RED: discard-only input emitted an invented all-space word. GREEN: an empty
    surviving stream now emits no bytes while mixed input retains word framing.
59. PERFORMANCE: the first production benchmark exposed asymmetric, slow
    little-endian extraction. The direct conversion path now batches 1,024
    words per allocation and selects endian handling at entry; median throughput
    is 25.81–30.65 packed MiB/s with no GNU codec available for a ratio.
60. RED/GREEN inventory: the two transports made the exact count and generated
    inventory stale. Regeneration now agrees on 1,666 registered and 1,668
    audited codecs.
61. AUDIT RED: treating the Wikipedia RADIX-50 family as only PDP-11 concealed
    two incompatible DEC formats. Pinned PDP-10 and PDP-9/15 manuals prove
    distinct alphabets, word widths, metadata bits, and published vectors.
62. RED: eight non-octet contracts failed before exact PDP-6/10 36-bit and
    PDP-9/15 18-bit APIs, explicit byte transports, strict metadata/padding
    handling, source digests, and registry names existed.
63. GREEN: every PDP-10 digit passes in all six positions and every PDP-9 digit
    in all three. DEC's `SYMBOL` and `SYMNAM` octal vectors, exact packed words,
    tag/class helpers, both endian transports, strict/discard/direct UTF-8, and
    registry conversion pass; the focused matrix now has nine tests.
64. PERFORMANCE RED/GREEN: first production measurements were only 5.83–8.47
    MiB/s because direct paths materialized whole charlists and temporary lists
    per word. Bounded 1,024-word chunks and direct digit/byte arithmetic raise
    final throughput to 12.17–31.39 MiB/s with at most 2% endian skew.
65. RED/GREEN inventory: four byte transports made exact counts stale. Generated
    inventories and assertions now agree on 1,670 registered byte codecs, 1,672
    audited entries, and four exact non-octet formats.
66. SOURCE AUDIT: Control Data's rendered NOS appendix proves that CDC Display
    Code has distinct CDC/ASCII graphic tables and a separate 63-character
    colon/percent anomaly; all printed pages A-1 through A-4 are pinned.
67. RED: five CDC contracts failed before the four profiles, exact tables,
    strict undefined/high-unit handling, direct paths, registry aliases, and
    packed transports existed.
68. GREEN: all 64 code values pass in both 64-character profiles; both
    63-character profiles reject code 00, map code 63 to colon, and reject
    percent. Direct/discard paths and both packed orders pass for every profile.
69. PERFORMANCE RED/GREEN: whole-input reverse lists limited direct decode to
    16.48–16.65 MiB/s. Bounded 4,096-unit chunks raise production medians to
    68.04–69.40 MiB/s; encode medians are 14.59–16.14 MiB/s.
70. RED/GREEN inventory: four byte codecs and four packed profiles made runtime
    snapshots and counts fail. Regeneration agrees on 1,674 registered codecs,
    1,676 audited entries, and six explicit packed six-bit profiles.
71. SOURCE AUDIT: rendered NOS pages A-5 through A-7 complete the prior CDC
    source review. Table A-2 defines canonical 6/12 sequences for every ASCII
    value, four valid 74 escapes, 63 valid 76 escapes, and all undefined pairs.
72. RED: six contracts failed before full 63/64-mode codecs, all-ASCII mappings,
    exhaustive two-unit grammar tests, direct/discard paths, registry names, and
    exact packed transports existed.
73. GREEN: every one of 128 ASCII mappings, all 8,192 two-unit mode/input cases,
    all 192 high octets at two input positions, truncation, contextual
    colon/percent rules, and 42-bit MSB/LSB samples pass.
74. PERFORMANCE RED/GREEN: initial generic packed throughput was 3.75–4.25
    MiB/s. Bounded core buffers and specialized four-unit six-bit groups raise
    MSB/LSB packed throughput to 10.29–15.28 MiB/s; byte paths are
    17.59–22.26 MiB/s.
75. RED/GREEN inventory: two byte codecs and two packed profiles made all exact
    snapshots/counts fail. Regeneration agrees on 1,676 registered codecs,
    1,678 audited entries, and eight explicit packed six-bit profiles.
76. SOURCE AUDIT: rendered DEC's VT330/VT340 Figures 2-7 and 2-8 and visually
    resolved GL/GR invocation, nine Technical undefined cells, parenthesis-hook
    glyphs, Greek-symbol identities, and the seven large-sigma joining pieces.
    Unicode L2/98-354, Unicode 17 data, WG2 N5028, and a licensed Kermit source
    cross-check are pinned by digest.
77. RED: 19 focused tests produced 13 failures before four byte profiles,
    aliases, registry entries, and two packed seven-bit transports existed. The
    independent oracle covers all 94 positions and all 256 octets in each GL/GR
    profile, strict/discard/direct UTF-8 behavior, and source licenses.
78. GREEN: `DEC-SPECIAL`, `DEC-SPECIAL-GR`, `DEC-TECHNICAL`, and
    `DEC-TECHNICAL-GR` pass all 19 contracts. Unicode U+23B2..U+23B5 replaces
    the old Kermit PUA joining pieces; every defined cell round-trips and all
    nine Technical holes remain invalid.
79. PERFORMANCE: 1 MiB production medians are 9.42–17.46 MiB/s for direct
    conversion and 6.52–11.56 MiB/s for packed MSB/LSB conversion. Bounded
    4,096-unit output chunks avoid whole-input temporary charlists; GL/GR direct
    pairs differ by at most 1%. GNU libiconv has no comparison codec.
80. RED/GREEN inventory: four byte codecs and two packed profiles made the
    exact snapshots/counts fail. Regeneration agrees on 1,680 registered codecs,
    1,682 audited entries, and ten packed fixed-width profiles.
81. SOURCE AUDIT: rendered and visually inspected printed page 19 of DEC's
    *Digital Guide to Developing International Software*. It separately defines
    ASCII-based DEC Hebrew 7-bit / SI 960 and DEC-MCS-based DEC Hebrew 8-bit.
    DEC's VT510 manual and Kermit's licensed tables independently fix the
    seven-bit Hebrew range at hexadecimal 60–7A; all four artifacts are pinned
    by SHA-256 with page-level metadata.
82. RED: five focused contracts produced five failures before either codec,
    their aliases, direct paths, registry entries, or SI 960's packed septets
    existed. The oracle classifies all 128 septets, all 128 forbidden high
    octets at two offsets, and all 256 DEC Hebrew 8-bit positions against the
    independently tested RFC DEC-MCS table plus the exact DEC overlay.
83. GREEN: `SI-960` and `DEC-HEBREW-8` pass all five exhaustive contracts,
    including every reverse mapping, strict/discard/direct UTF-8 behavior,
    malformed offsets, aliases, and exact 14-bit MSB/LSB samples.
84. PERFORMANCE: production 1 MiB medians are 54.81–58.57 MiB/s decode and
    13.82–14.17 MiB/s encode. SI 960 packed paths measure 8.37–12.68 MiB/s.
    Compile-time tuples/maps and bounded 4,096-unit chunks keep the direct paths
    allocation-linear. GNU libiconv 1.19 contains neither profile.
85. RED/GREEN inventory: two byte codecs and one packed profile made every
    exact snapshot/count contract stale. Regeneration agrees on 1,682 registered
    codecs, 1,684 audited entries, and eleven packed fixed-width profiles.
86. RELEASE RED: the first `mix hex.build --unpack` failed the 128 MiB
    uncompressed limit because the package manifest included the full 337 MiB
    verification source archive. Restricting the artifact to runtime data then
    exposed the stricter 16 MiB compressed limit: the 1,050 historical ICU
    revision tables alone compressed to 31 MiB.
87. GREEN architecture moves only those generated archive tables behind three
    transparent applications covering IDs 1–350, 351–700, and 701–1050. Core's
    table loader now honors registered providers for entries without an explicit
    application; every other specs table remains owned by `iconvex_specs`.
88. GREEN release checks build and unpack all four Hex artifacts within both
    limits, force-compile the unpacked sources with warnings as errors, assert
    provider ownership at all six range boundaries, fetch a table from each,
    and retain all 1,682 public codecs.
89. GREEN regression coverage checks provider ownership and physical table
    presence for every one of the 1,050 archive IDs. The repository still
    retains all source fixtures, importers, benchmarks, and tests; only the Hex
    delivery layout changes.
90. COLD-LOAD RED/GREEN: the first clean unpacked all-table probe reached a
    mixed-EBCDIC artifact before its engine module had interned `sbcs`/`dbcs`
    atoms, so safe ETF decoding rejected the otherwise trusted generated term.
    Core's finite schema allowlist now includes both mode and decode-map atoms.
    A new VM then safely loads all 1,050 tables and converts both Hebrew profiles.
91. AUDIT RED/GREEN: a source-to-runtime executable comparison rejected one of
    17 proposed Kermit title bridges: historical `HEBREW-ISO` differs from the
    current ISO-8859-8 mapping at AF, FD, and FE. The retained 16 bridges are
    byte-exact in both directions; ELOT 928, Hebrew ISO, Latin-6, and Macintosh
    Latin have permanent measured-difference guards.
92. RED: five Short KOI contracts produced five failures before the codec,
    source metadata, registry aliases, direct paths, and packed septets existed.
    The oracle parses the pinned Kermit `u_koi7` table, executes and reverses all
    128 septets, and checks all 128 high octets at two error offsets.
93. GREEN: `SHORT-KOI` / KOI-7 N2 passes all five contracts, including strict,
    discard, direct UTF-8, malformed input, historical aliases, and exact 21-bit
    MSB/LSB samples. It remains distinct from stateful `KOI7-switched`.
94. PERFORMANCE RED/GREEN: the first production decode measured 19.53 MiB/s
    because a per-septet output helper remained uninlined. Inlining the emission
    and UTF-8 branches raises decode 3.40x to 66.38 MiB/s; encode is 16.45 MiB/s
    and packed paths are 9.27–13.07 MiB/s.
95. RED/GREEN inventory: one byte codec and one packed profile made both exact
    runtime snapshots and all package counts stale. Regeneration now agrees on
    1,683 registered codecs, 1,685 audited entries, and twelve packed profiles.
96. SOURCE AUDIT: rendered all six pages of ISO registration 88 and visually
    checked its complete chart. Standard ELOT 927 is byte-exact with RFC 1345
    `greek7`; Kermit's `u_elot927` differs at 54 printable positions and its
    encoder contains incompatible high-bit lowercase arithmetic.
97. RED/GREEN: five profile contracts failed before aliases, source metadata,
    exhaustive 128-cell oracles, and the separately named Kermit codec existed.
    Both standard and historical identities now pass strict, discard, direct
    UTF-8, invalid-octet, canonical-inverse, and alias tests.
98. PACKED RED/GREEN: standard `ELOT-927` initially had no exact packed profile
    even after the Kermit profile passed. Registry-aware alias resolution and a
    second seven-bit profile now round-trip both identities in MSB/LSB order.
99. PERFORMANCE: production 1 MiB medians are 6.90/7.30 MiB/s for standard
    table decode/encode and 67.65/17.33 MiB/s for the specialized Kermit paths;
    packed paths span 4.01–13.18 MiB/s. GNU libiconv 1.19 has neither profile.
100. RED/GREEN inventory: the new byte codec and two packed profiles made both
     exact runtime snapshots stale. Regeneration now agrees on 1,684 registered
     codecs, 1,686 audited entries, and fourteen packed profiles.
101. SOURCE AUDIT / RED: DEC's pinned VT330/VT340 manual was rendered at
     printed pages 24–25. Four exhaustive contracts failed before all twelve
     seven-bit NRC identities, aliases, strict inverse maps, and packed forms
     existed. The oracle names every replacement cell from Table 2-1.
102. GREEN: all twelve NRCs pass every one of 1,536 septet mappings, their full
     reverse repertoires, high-octet offset checks, simple national aliases,
     and complete MSB/LSB packed round trips. Six mappings are independently
     byte-exact with existing RFC tables.
103. ORACLE DEFECT GUARD: Kermit's Dutch table differs from the DEC manual at
     two cells (florin and acute accent), while its Portuguese table is a
     six-cell copy of Norwegian/Danish. Permanent tests assert both counts and
     use the normative manual instead.
104. PERFORMANCE RED/GREEN: reusing the generic RFC table engine left six NRC
     profiles at 7.52–8.18 MiB/s decode. Giving all twelve dedicated
     compile-time tuple/map paths raises those six by 7.86–8.94x; final decode
     spans 61.87–73.56 MiB/s, encode 17.78–19.40 MiB/s, and representative
     packed paths 9.70–13.08 MiB/s.
105. RED/GREEN inventory and research: regeneration now agrees on 1,696
     registered codecs, 1,698 audited entries, and 26 packed profiles. Seven
     former NRC catalog gaps are closed; the catalog has 1,627 clusters, 1,234
     implemented codecs, 191 codec gaps, and 168 research candidates.
106. RED: five versioned single-byte contracts failed before `GREEK-ISO`,
     `HEBREW-ISO`, `LATIN6-ISO`, and `MACINTOSH-LATIN` existed. Independent
     parsers cover every octet from two ICU UCMs, Kermit, RFC 1345, and GNU
     libiconv 1.19 test data.
107. SOURCE GREEN: Greek ISO and ELOT 928 are byte-exact ISO 8859-7:1987
     identities; Hebrew is exact ISO 8859-8:1988; Latin-6 deliberately follows
     current GNU ISO-8859-10 rather than Kermit's 16-cell near-match; Macintosh
     Latin is exact Windows-10079, including U+F8FF.
108. BEHAVIOR GREEN: all 1,024 octets, complete canonical inverses, undefined
     cells, nonzero offsets, strict/discard policies, malformed UTF-8, aliases,
     and direct-path chunk boundaries pass.
109. PERFORMANCE GREEN: mixed 1 MiB corpora measure 51.71–65.15 MiB/s decode
     and 19.16–24.02 MiB/s encode. GNU/Iconvex ratios are 1.51–1.80x decode and
     4.31–5.26x encode, below the executable benchmark's 30x ceiling.
110. INVENTORY/RESEARCH GREEN: regeneration agrees on 1,700 registered codecs,
     1,702 audited entries, and 26 packed profiles. The byte-identical ELOT 928
     and Greek ISO research rows join; all four profiles are implemented. The
     catalog now has 1,626 clusters, 1,238 implemented codecs, 186 codec gaps,
     and 168 research candidates.
111. REVIEW RED: package-contract tests exposed the stale 1,700/1,702 counts
     after adding `BULGARIA-PC`, `MAZOVIA`, `QNX-CONSOLE`, and
     `DG-INTERNATIONAL`; the generated registered-codec inventory omitted all
     four names.
112. COLLISION RED: exhaustive registry-identity tests found 33 advertised
     codec modules skipped by built-in-name collisions, including 20 whose
     mappings differed from the built-in codec selected for the same name.
113. COLLISION GREEN: the exact registration manifest now exposes all 1,704
     codecs. The 33 conflicts use source-qualified canonical names (22 RFC
     1345, ten Apple Unicode, one ICU multibyte), while safe aliases remain.
     Tests prove exact module/canonical/alias identity and every one-byte input
     for every conflict, plus a mapped multibyte sequence where applicable.
114. OWNERSHIP RED/GREEN: application-stop tests first showed that caller-owned
     CESU-8 and table providers were removed. Specs and all three archive shards
     now use atomic ownership-token registration and only unregister their own
     tokens. Preexisting registrations and registrations replaced after start
     both survive stop.
115. UTF-8 CALLBACK RED/GREEN: direct and generated codec callbacks returned an
     empty error sequence for malformed UTF-8. Thirty representative codecs
     now prove exact invalid and truncated tails with exact offsets; the shared
     decoder helper and all direct/macro paths preserve the offending bytes.
116. DIFFERENTIAL RED/GREEN: the checked report advertised only seven
     algorithmic codecs and had no implementation binding. A fresh exhaustive
     run covers all 1,112,064 Unicode scalars for all eight codecs, including
     UTF-1, with zero mismatches; the artifact verifies both runner and exact
     runtime-source SHA-256 digests.
117. COMPOUND-MAPPING GREEN: all 16 three- and four-codepoint MacKeyboard
     mappings round-trip from their encoded byte sequences through public
     `Iconvex.convert/3`, guarding the complete longest vendor expansions.
118. FORMAT GREEN: the main Specs package and all three archive packages pass
     explicit formatter checks after normalizing the previously unformatted
     generated and hand-written sources.
119. PETSCII STREAM RED/GREEN: strict N5028 decoding rejected command bytes in
     one-byte chunks. Caller-owned `on_invalid_byte` policy now translates CR,
     reverse-video, and color commands with absolute offsets while leaving the
     standards mapping unchanged; 8/8 focused legacy tests pass.
120. NATIVE-SUBSTITUTION RED: the exact 1,704-codec runtime inventory found
     only 1,589 native `encode_substitute/2` callbacks, leaving 115 codecs on
     Core's suffix-rescanning fallback. Eighty of those codecs rejected the
     test scalar while accepting its ASCII replacement; repeated failures in
     VIQR, ANSEL, and DEC-SIXBIT showed the resulting superlinear slowdown.
121. NATIVE-SUBSTITUTION GREEN: generated families, finite table codecs, and
     every custom/stateful engine now substitute in one state-preserving pass.
     The executable audit reports 1,704/1,704 registered codecs with native
     callbacks; focused custom-state tests pass 3/3 and the definitive isolated
     Specs suite passes 436/436.
122. PERFORMANCE GREEN: a CPU-isolated, warmed benchmark on freshly compiled
     beams exercised fourteen representative custom/stateful codecs at 400,
     800, 1,600, and 3,200 repeated substitutions. Median-of-three doubling
     ratios stay between 1.77 and 2.49 across the full range, demonstrating
     linear scaling after removal of the fallback rescans.
123. REGISTRY-RECOVERY RED/GREEN: the pre-fix worker-crash reproduction lost
     all Specs codec registrations while the application and its archive-shard
     providers remained started. The inherited registry now preserves exact
     codec ownership tokens and all 1,704 identities across worker restart.
     The regression then stops Specs and each shard, proving the surviving
     codec and provider tokens remove only their owners' registrations before
     clean restart; the focused registration-identity file passes 7/7.
124. PARTIAL-STARTUP ROLLBACK RED/GREEN: the lifecycle coverage audit found
     every late-failure rollback branch unexecuted despite the prior ownership
     claim. Five deterministic last-registration conflicts now exercise the
     main provider phase, all 1,704 main codec registrations, and every one of
     the 349 acquired providers in each ICU archive shard. GREEN proves every
     newly acquired module/provider is removed, each preexisting conflict and
     exact codec token survives, and all four applications restart completely;
     the focused registration-identity file passes 12/12.
125. PUNYCODE RED: seven RFC/oracle/API tests produced six failures before a
     codec module or registrations existed; only immutable-source verification
     was green.
126. PUNYCODE GREEN: all nineteen RFC 3492 vectors, 517 deterministic scalar
     strings, and all 65,793 inputs through two octets match the pinned CPython
     implementation. Eight focused tests also cover exact malformed offsets,
     scalar/overflow bounds, strict/discard/substitute policies, registry
     aliases, and direct UTF-8 callbacks.
127. PUNCHED-CARD RED: eleven primary-evidence contracts produced nine missing
     module/profile failures before any logical or word transports existed.
128. PUNCHED-CARD REVIEW RED: the first LSB error path reported a prior valid
     mask instead of the invalid second mask, and publication tests exposed
     missing logical profiles, wide-profile aliases, and specialized inventory
     rows.
129. PUNCHED-CARD GREEN: five primary-source logical profiles exhaust every one
     of 4,096 masks; ten 16BE/16LE codecs, exact MSB and explicit LSB paths,
     policies, streaming, aliases, and generated inventories pass 42 focused
     tests. Production package unpack/compile succeeds without historical
     source artifacts, doubled-input reductions scale by 2.051x, and the worst
     native/dense-table ratio is 3.12x.
130. ICU LMBCS VARIANT RED: the pinned ICU 78.3 source/hash contract passed,
     while the first public LMBCS-2 contract failed with
     `UndefinedFunctionError`; two tests produced one failure before any new
     optimization-group module existed.
131. ICU LMBCS VARIANT GREEN: one native engine now implements the exact ICU
     optimization semantics for LMBCS-1/2/3/4/5/6/8/11/16/17/18/19, with
     eleven authoritative canonical registrations and no invented aliases or
     unsupported optimization groups.
132. ICU LMBCS REVIEW RED/GREEN: exhaustive implicit-form decoding exposed a
     terminal single-byte MBCS bug for groups 17--19. The strengthened parser
     now distinguishes non-lead `0x80`/`0xFF` mappings from incomplete lead
     bytes and preserves split surrogate/group prefixes in streaming state.
133. ICU LMBCS DIFFERENTIAL GREEN: all 1,112,064 Unicode scalar encodings for
     every one of the twelve ICU profiles match a pinned ICU 78.3 one-call
     oracle byte-for-byte. Tests additionally cover 71,452 reachable implicit
     variant mappings, 72,378 explicit forms, malformed and incomplete input,
     strict/discard/substitute policies, direct UTF-8 paths, and every encoded
     and UTF-8 streaming boundary; the final focused runs pass 15/15 and the
     registry lifecycle suite passes 12/12.
134. ICU LMBCS PERFORMANCE GREEN: a persistent public-ICU C oracle excludes
     compiler and process startup. A fresh three-trial paired-median run covers
     all twelve profiles: production encode ratios are 2.32--3.75x, decode
     ratios are 20.79--25.63x, and doubled-input LMBCS-16 time scales by 2.37x
     encode and 1.48x decode, all within the 30x/linear gates.
135. PUNYCODE PERFORMANCE REVIEW RED: the original ordered 1,000-to-2,000
     reduction gate measured 3.936x encode and 4.007x decode; an initial
     ordered-only repair remained quadratic on alternating front/end
     insertions.
136. PUNYCODE PERFORMANCE REVIEW GREEN: monotonic/append fast paths plus
     stable merge ranking and order-statistic reconstruction keep both ordered
     and alternating encode/decode reduction ratios at 2.081x--2.324x. Nine
     focused tests pass, byte output remains identical to the pinned CPython
     implementation, and every measured native/oracle ratio is below 1x on
     the reference run.
137. PUNYCODE DIFFERENTIAL RED/GREEN: adding the full-scalar Punycode row made
     the artifact contract fail at its former 8/8 roster. A fresh runner now
     binds `punycode.ex` into the runtime digest and records 9/9 codecs, all
     1,112,064 scalars, zero mismatches, and a byte-exact Punycode round trip;
     the digest-bound artifact test passes.
138. PUNCHED-CARD BENCHMARK REVIEW RED: the executable benchmark contract
     found only twenty packed-MSB/16BE rows, no packed-LSB or 16LE timing, no
     cross-transport parity assertion, and one 16BE encode-only reduction
     gate. The initial expanded runner then exposed a precedence bug in its
     reduction-median pipeline before any gate could pass.
139. PUNCHED-CARD BENCHMARK GREEN: all five profiles now prove round-trip
     parity and benchmark both directions through packed MSB, explicit packed
     LSB, 16BE, and 16LE: forty timed paths. The executable focused contract
     passes 1/1, the combined punched-card run passes 20/20, and isolated quick
     and full production runs both pass all eight fresh-process median
     reduction gates.
140. PUNCHED-CARD SCALING GREEN: exact full-run 20k-to-40k ratios are
     1.831x/1.895x packed MSB, 1.781x/1.962x packed LSB, 1.879x/1.948x 16BE,
     and 1.879x/1.966x 16LE for encode/decode. Throughput spans 5.103--10.175
     million characters/s; packed-MSB native/oracle ratios are 0.62x encode
     and 3.12x decode, all within their executable gates.
141. PUNYCODE ADVERSARIAL GREEN: 3,906 duplicate-heavy sequences through
     length five over ASCII delimiter/basic and three adjacent non-basic
     values are byte-identical to pinned CPython. All 97,656 sequences through
     length seven encode/decode exactly, exercising equal-key merge ranks and
     reverse insertion reconstruction.
142. PUNYCODE RECOVERY RED/GREEN: generic callback recovery attempted to decode
     incomplete prefix `a-z`, crashed while constructing UTF-8, and decoded a
     desynchronized suffix after `abc-!`. Punycode now declares whole-string
     stop recovery: native discard retains `a`/`abc`, one exact invalid-byte
     event or replacement is appended, and the suffix is never reinterpreted.
     Focused Specs and core external-codec runs pass 11/11 and 22/22.
143. IBM/DEC CODE-PAGE RED: strict first tests for CP310, CP907, CP1116,
     CP1117, IBM-1287, and IBM-1288 failed thirty cases because no native
     profiles, mappings, recovery behavior, streaming surface, provenance, or
     registrations existed. Generic CP310/907/1116/1117 aliases were explicitly
     forbidden until a direct Unicode identity could be proven.
144. IBM/DEC CODE-PAGE GREEN: seven qualified profiles now classify every one
     of their 256 bytes, reserved cell, preferred inverse, strict/discard/
     substitute result, direct UTF-8 path, and encoded/UTF-8 streaming split.
     The exact IBM/tnz revision preserves its four E4--E7 additions and has 143
     defined bytes; the IBM registry composite remains a distinct 139-byte
     profile. The focused implementation/review run passes 49/49.
145. IBM/DEC REGENERATION RED/GREEN: the first review contract failed because
     the checked-in vectors had no executable derivation; its initial PDF pass
     also assumed the wrong dictionary-key order. A deterministic pure-Elixir
     generator now parses pinned IBM registry text, ICU UCMs, IBM/tnz Python,
     and LZW-compressed IBM PDF grids with explicit join, priority, and
     collision rules. It reproduces all seven 256-row maps byte-for-byte.
146. IBM/DEC ALL-SCALAR GREEN: the digest-pinned UTF-32BE corpus executes all
     1,112,064 Unicode scalars against every profile. Discard encoding emits
     exactly the sorted canonical repertoire under the documented last-byte
     collision policy, and decoding that output returns exactly those scalars.
147. IBM/DEC HEX RELEASE RED/GREEN: the first package audit excluded every map
     and embedded checkout-absolute provenance paths. Hex now ships exactly
     seven generated maps plus `SOURCE_METADATA.md`; primary PDFs, TXT, UCM,
     and Python inputs remain repository-only. A clean unpack compiles with
     warnings as errors, and all seven public map/metadata paths are readable
     beneath `:code.priv_dir(:iconvex_specs)` after the original source tree is
     absent. Runtime registration also resolves 7/7 from that unpacked build.
148. IBM/DEC REGISTRY GREEN: all seven qualified identities and only the direct
     DEC aliases (`IBM-1287`/`CP1287`/`EL8DEC` and
     `IBM-1288`/`CP1288`/`TR8DEC`) resolve without collision. The generated
     inventory and every cardinality contract now record 1,733 runtime codecs
     and 1,735 catalogued entries.
149. IBM/DEC PERFORMANCE GREEN: the executable mixed-repertoire benchmark
     covers both directions for all seven profiles. Input throughput is
     5.52--13.92 MiB/s, and all fourteen per-process scheduler-reduction gates
     scale 2.008x--2.215x from 512 KiB to 1 MiB against a 2.3x ceiling. Wall
     time is reported separately; GNU libiconv 1.19 exposes none of the seven
     qualified identities, so no misleading slowdown ratio is claimed.
150. IBM/DEC FINAL INTEGRATION GREEN: the focused implementation, generator,
     all-scalar, benchmark, registry, package, and licensing selection passes
     71/71. The complete isolated Iconvex Specs suite passes 531/531, and a
     clean unpacked Hex package compiles with warnings as errors before its
     seven installed provenance paths and registrations pass a fresh runtime
     smoke test.
151. RELEASE-PROVIDER RED: a clean unpacked seven-package sweep raised for
     IBM-1175 and ISO-IR-42 because their bridge modules pinned ICU archive
     tables 374 and 726 to the main Specs application even though release
     packaging correctly places those tables in shards B and C. The new
     package callback contract reproduced the bug as 5 tests with 1 failure:
     the provider cache remained absent.
152. RELEASE-PROVIDER GREEN: all seven decode/encode callbacks on each bridge
     use provider-aware table APIs. The focused package/IBM/ISO run passes
     16/16; fourteen cache assertions prove the shard cache is populated while
     the nonexistent main-package cache stays absent. A static scan finds no
     other ICU archive bridge using a non-provider CodecSupport entry point.
153. RELEASE-PROVIDER INTEGRATION GREEN: a fresh unpacked Specs artifact ships
     zero `icu_archive_*.etf` tables, compiles in production with warnings as
     errors against its three shards, and executes empty decode/encode sweeps
     for all 1,733 registrations with zero exceptions. The authoritative clean
     suite passes 533/533.
154. RELEASE-PROVENANCE RED: an exact compiled-application export contract
     found 137 public path/directory helpers. Only the sixteen IBM additional
     code-page helpers resolve packaged files through `:code.priv_dir`; the
     other 121 returned checkout-absolute paths, including forty-five helpers
     outside the two names sampled by review and three relocation-unsafe
     `dec_mcs_path/0` delegates.
155. RELEASE-PROVENANCE GREEN: removed all 121 checkout-only runtime helpers
     while preserving URL, digest, page, manifest, and `@external_resource`
     provenance. Source-verification tests and the ICU archive tool now use
     repository-local paths. The exact allowlist contract passes with all
     sixteen packaged paths below the runtime priv directory, and the 27-file
     focused source suite passes 154/154 with warnings as errors.
156. KERMIT TERMINAL-SUBSET RED: the first exact source-parser run covered
     `u_dgline`, `u_dgword`, `u_hpmath`, `u_snibrack`, `u_snieuro`,
     `u_snifacet`, and `u_sniibm`. Six focused tests produced four failures:
     every new canonical and alias resolved as unknown, and neither direct
     conversion direction existed. The existing four vendor profiles stayed
     green.
157. KERMIT TERMINAL-SUBSET GREEN: seven source-qualified codecs now reproduce
     every cell in the pinned BSD Kermit tables. Exhaustive tests cover all
     1,792 possible input octets, complete first-byte canonical inverses,
     aliases, strict/discard policies, malformed UTF-8, and chunk boundaries.
     The generic native macro now pads short tables with invalid cells and
     limits ASCII batching to the table's actual identity prefix; this prevents
     bytes 21--7E in the terminal subsets from bypassing their mappings. The
     focused mapping suite passes 6/6.
158. KERMIT TERMINAL-SUBSET INVENTORY GREEN: registration, package, ownership,
     and native-substitution contracts now record 1,740 runtime codecs and
     1,742 catalogued entries. The deterministic inventory was regenerated with
     exactly 1,740 rows. The combined mapping/package/identity/substitution run
     passes 28/28 with warnings as errors.
159. KERMIT VENDOR PERFORMANCE RED/GREEN: the benchmark contract first failed
     because no executable vendor-profile benchmark existed. The new benchmark
     covers both directions for all eleven exact profiles. All 22 scheduler-
     reduction gates scale 1.916x--2.224x from 512 KiB to 1 MiB against a 2.3x
     ceiling; production input throughput is 20.76--41.05 MiB/s. GNU libiconv
     1.19 exposes none of these exact mappings, so no invalid ratio is claimed.
     The executable benchmark contract passes 1/1.
160. KERMIT VENDOR EVIDENCE RED/GREEN: an explicit chunk-boundary assertion
     failed because the fixed repetition count produced only 2,112 units for
     one terminal profile, below the native 4,096-unit flush threshold. The
     corpus now derives its repetition count from each canonical inverse and
     asserts that every profile exceeds the threshold. The independent oracle
     parses the C struct's declared size and offset, asserts `94,33` for all
     seven terminal subsets, and checks strict/discard and malformed UTF-8
     behavior at nonzero offsets for each one. The focused mapping and
     benchmark contracts pass 8/8 with warnings as errors.
161. KERMIT HEX-LICENSE RED/GREEN: the release contract first failed because
     the exact BSD terms and source metadata were not selected by the Hex
     manifest. The Specs package now declares BSD-3-Clause in addition to the
     implementation and fixture licenses and ships Kermit's complete COPYING
     file (SHA-256
     `067b8c8fc98d9359dfbd211820e1d57bed1e173144a184a21e8ead802b6502be`)
     beside digest-bearing source metadata. The focused license contract passes
     2/2, and the package NOTICE keeps the native implementation under
     LGPL-2.1-or-later.
162. MULTI-PACKAGE REGISTRY RED/GREEN: starting the three extension packages in
     opposite orders failed on Specs/Extras `IBM037` and `CP1124` name
     conflicts. Specs now installs all 1,740 registrations in one atomic
     managed set. Across the exact 231 overlaps, canonical claims outrank
     aliases and Extras wins equal-kind GNU identities; the all-loaded result
     is 25 Specs and 206 Extras winners. The integration harness proves all six
     start orders yield one 1,990-codec snapshot and that stopping either
     package exposes all 231 retained claims without a transient miss.
163. UNIVAC FIELDATA RED: two independently transcribed, digest-pinned primary
     tables drove a new ten-test suite before implementation. After correcting
     one Range/iodata assertion in the test itself, nine tests failed solely on
     absent codecs, registrations, packed profiles, and generated inventories;
     the source-oracle and historical 36-bit-word vectors were already fixed.
164. UNIVAC FIELDATA ENGINE GREEN: five source-qualified native codecs now
     cover the complete 64-cell UNIVAC 1100 alphabet plus 4009 input, output,
     readable-lossless VPUA, and raw-forensic VPUA views. Exhaustive tests cover
     all 64 units, all 192 invalid high octets per profile, directional ignored
     and unavailable actions, strict/discard/substitute paths, malformed UTF-8
     offsets, allocation boundaries, and the exact seven differing table cells.
165. UNIVAC FIELDATA INVENTORY GREEN: the byte inventory now has 1,745 runtime
     rows and the catalog retains 1,747 entries. Five new six-bit profiles raise
     the packed inventory to 36 rows; exact MSB bytes prove continuous
     six-character 36-bit words, while the separately typed LSB transport is
     explicitly non-historical. The focused suite passes 10/10.
166. UNIVAC FIELDATA PACKED REVIEW RED/GREEN: the all-profile packed sweep first
     failed because it fed ASCII `ABC` to the intentionally opaque raw-VPUA
     codec. A representable U+F4006/U+F4007/U+F4008 sample now exercises both bit
     orders without weakening the raw identity; the packed contract passes 7/7.
167. UNIVAC FIELDATA RESEARCH GREEN: regenerating the provenance catalog splits
     the formerly conflated record into authoritative UP-7824 and UP-7604 rows.
     The merged catalog moves from 1,614 to 1,615 clusters, implemented rows from
     1,278 to 1,280, actionable gaps from 105 to 104, and the exact high-priority
     blocker ledger from 26 to 25 rows. Its focused audit passes 34/34 while the
     ambiguous FIELDATA family and both under-specified TI children remain open.
168. UNIVAC FIELDATA PERFORMANCE GREEN: production medians over 262,144 logical
     units measure 43.63--44.49 Mi units/s semantic byte decode, 13.47--13.53
     Mi units/s semantic byte encode, and 12.77--21.52 Mi units/s semantic packed
     paths. Raw VPUA measures 9.43--28.30 Mi units/s because every unit emits a
     four-byte Plane-15 scalar. The 20k-to-40k scheduler-reduction ratio remains
     inside the executable 1.7x--2.3x linearity gate; GNU libiconv 1.19 exposes
     no source-qualified FIELDATA codec, so no invalid comparison is reported.
169. UNIVAC FIELDATA REGENERATION/RELEASE GREEN: rerunning the RFC importer
     preserves the complete independently maintained document prefix exactly
     and reproduces both RFC ETF digests byte-for-byte. All seven Hex artifacts
     rebuild; a clean production consumer compiles with warnings as errors and
     proves 1,995/1,995 full-stack registrations, both packaged FIELDATA tables
     at their pinned digests, both metadata files, no copyrighted manual PDFs,
     and 1,745/1,745 empty Specs encode/decode paths.
170. UNIVAC FIELDATA FINAL GREEN: isolated warning-as-error runs pass Core
     339/339, Specs 548/548, and full-stack integration 2/2. The generated GNU
     comparison contains all five new canonical names, 1,995 ASCII-case-unique
     full-stack codecs, all 198 GNU libiconv 1.19 fixed codecs, and zero GNU-only
     canonical gaps.
171. UNIVAC FIELDATA STREAMING RED/GREEN: a final coverage audit found that the
     fixed-width codecs had not opted into external incremental callbacks. A new
     test failed exactly on missing `decode_chunk/2`; native stateless callbacks
     now stream every profile in both directions across every UTF-8 byte split,
     including four-byte raw-VPUA scalars, with strict, discard, and replacement
     policies. The focused suite passes 11/11 and the fresh full Specs suite
     passes 548/548 with warnings as errors.
172. UNIVAC FIELDATA PACKED-OFFSET RED/GREEN: adversarial review reproduced an
     invalid 4009 input unit at packed bit 24 reporting the byte-codec offset 4.
     Dedicated MSB and LSB tests failed 2/2 before the fix. Packed single-unit
     decode failures now translate byte-unit indexes to physical bit offsets and
     retain the order-specific offending-unit representation; the focused
     regression passes 2/2.
173. UNIVAC FIELDATA REGISTRY RED/GREEN: a catalog-to-runtime test failed on the
     first unregistered historical label, `EXEC-8-FIELDATA`. The source-qualified
     `EXEC-8-FIELDATA` and `FIELDATA-1100` aliases now resolve to
     `FIELDATA-UNIVAC-1100`; ambiguous `FIELDATA-UNIVAC` and `UNIVAC-FIELDATA`
     labels were removed from the generated catalog and remain rejected. The
     catalog test calls `Iconvex.canonical_name/1` for every retained label.
174. UNIVAC 4009 GLYPH RED/GREEN: a semantic-policy test failed because octal 57
     decoded as modern U+1F6D1 OCTAGONAL SIGN although the pinned table only
     depicts a proprietary diamond-enclosed wave. Input, output, and lossless
     profiles now use source-qualified U+F402F and reject U+1F6D1; the independent
     CSV, digest, metadata, artifact audit, and inventories were updated. Focused
     review coverage passes 28/28; fresh warning-as-error suites pass Core
     339/339 and Specs 552/552.
175. ECMA-44 RAW RED: after correcting one Range-to-binary typo in the new test
     itself, the valid pre-implementation run failed 12/12 solely because
     `Iconvex.Specs.ECMA44` and `Iconvex.Specs.RawTransports` did not exist.
     The fixed independent oracle already contained all 256 transcribed cells,
     both table digests, every mask disposition, and the registry boundary.
176. ECMA-44 RAW GREEN: the focused suite passes 12/12. The native raw engine
     exhausts all 256 eight-bit combinations, the exact 128-entry seven-bit
     subset, every one of 4,096 physical masks in both modes, MSB/LSB/16BE/16LE
     round trips, strict padding and offsets, chunk carry, source metadata,
     inventories, and large-input linearity without entering a Unicode registry.
177. ECMA-44 BENCHMARK RED/GREEN: the executable contract first failed 1/1
     because `bench/ecma44_benchmark.exs` was absent. It now passes 1/1 and
     requires all twenty mode/operation rows, pre-timing transport parity, and
     all twenty hard scheduler-reduction gates. The production reference spans
     8.327--249.186 million raw units/s and scales 1.857x--2.006x for a 2x input.
178. ECMA-44 RELEASE RED/GREEN: a new manifest regression failed 1/13 because
     the detailed raw audit document was not selected for packaging. The
     manifest now ships that document, the separate raw inventory, and the
     independently transcribed CSV plus metadata while selecting no PDF; the
     focused raw suite passes 13/13.
179. TI AMS 2.0 RED: an independent 256-row transcription and digest-bearing
     disposition record preceded runtime code. The valid initial suite passed
     its two source/evidence tests and failed 11/13 only on absent codecs,
     registration, direct paths, streams, and performance behavior.
180. TI AMS 2.0 ENGINE GREEN: four version-qualified profiles now cover all 256
     source bytes: audited source glyphs, visible C0 pictures, mixed lossless
     VPUA, and raw forensic VPUA. Exhaustive forward/reverse checks, the three
     two-scalar sequences, longest-match encoding, ten NFKC collision pairs,
     strict/discard/substitution, malformed offsets, and every stream split pass
     13/13 after correcting the raw profile's table-derived policy vector.
181. TI AMS 2.0 BENCHMARK RED/GREEN: the executable contract first failed 1/1
     because `bench/ti89_ams2_bench.exs` was absent, then exposed an incorrectly
     grouped reduction median before passing. It now requires four direct/public
     paths for all four profiles, a sequence-heavy 9A/9B/B4 corpus, round-trip
     parity, and sixteen hard scheduler-reduction gates.
182. TI AMS 2.0 RELEASE RED/GREEN: an explicit manifest check failed 1/14 on the
     absent mapping selection. The manifest now ships the independent CSV and
     metadata and selects no PDF. Four registrations move the exact runtime
     inventory to 1,749 rows and the audit catalog to 1,751 entries.
183. TI AMS 2.0 CALLBACK REVIEW RED/GREEN: adversarial review found all three
     direct UTF-8 unrepresentable branches returned an internal
     `:encode_error` tuple, forcing public conversion to repeat work. Direct
     snowman and terminal/nonmatching U+207B regressions failed 2/15 before all
     branches adopted the codec contract. Functional plus benchmark coverage
     now passes 16/16.
184. TI AMS 2.0 PERFORMANCE GREEN: production direct/public decode measures
     22.85--41.23 Mi input bytes/s; readable encode measures 15.11--15.51 and
     raw-VPUA encode 28.18--28.64 Mi input bytes/s. All sixteen 2x-input
     reduction ratios span 1.995x--2.041x. The GNU libiconv 1.19 `iconv -l`
     listing has no exact normalized matching alias, so the report records a
     qualified N/A instead of a false ratio.
185. TI AMS 2.0 FINAL GREEN: a release-mode Hex unpack contains the mapping CSV
     and metadata at their pinned hashes, all four inventory rows, and no PDF.
     A fresh isolated build compiles all Specs sources with warnings as errors;
     the complete Specs suite passes 582/582.
186. TI AMS 2.0 REVIEW RED/GREEN: review found that a large-input test claimed
     allocation evidence while measuring only scheduler reductions, and that
     the benchmark printed throughput without enforcing a floor. The first
     strengthened benchmark run failed 2/2 on a missing floor and a GNU probe
     that called `--version` before `-l`; a second strict RAW-floor run failed
     1/1 on the deliberately stale 1.00 MiB/s expectation. The test now states
     only its bounded scheduler-reduction claim, and all sixteen timed paths
     enforce operation-specific throughput floors while retaining all sixteen
     scheduler-reduction gates.
187. TI AMS 2.0 GNU-PROBE GREEN: support status now starts with `iconv -l`,
     normalizes ASCII case and punctuation, and exact-matches every listed token
     against all four canonical names and aliases. `--version` is used only to
     label an already-classified listing. A fake executable proves that a
     punctuation-equivalent TI alias is accepted while a longer wrapper token
     containing the same text is rejected.
188. TI AMS 2.0 STRICT 30X RED/GREEN: a precision audit found that nearest-cent
     rounding permitted a 30.32x slowdown despite the strict greater-than-30x
     boundary. A test pinned ceiling-derived values first and failed 1/1 on the
     old 0.50 MiB/s direct-encode floor. All eight profile-family/path floors are
     now the ceiling to 0.01 MiB/s of the recorded family minimum divided by 30:
     readable 1.20/0.51/0.77/0.51 and raw 1.38/0.96/0.90/0.94. No floor rounds
     down, so a slowdown greater than 30x fails. The regression independently
     recalculates every ceiling from its recorded minimum and passes 2/2.
189. ECMA-44 LINEARITY-HARNESS RED/GREEN: the isolated full-suite audit
     reproduced a 2.460x false failure for mask encoding because the focused
     test measured one short and one long call in the shared ExUnit process;
     garbage collection from earlier tests was charged to only the long side.
     The authoritative benchmark already measured fresh-process three-sample
     medians at 1.857x. The focused regression now uses the same fresh-heap
     median method, passes 1/1, and leaves the native transport unchanged.
190. SPECS RUNTIME-ASSET CACHE RED/GREEN: a final all-folder audit found seven
     lazy Specs assets still using unrestricted ETF decoding and unversioned,
     racy persistent terms. The focused contract failed 3/4 before the shared
     loader existed. All seven now use safe decoding with a finite cold-VM atom
     schema, an application-versioned cache value, and a double-checked global
     cold-load lock. The versioned value replaces both stale-version tuples and
     legacy raw cache values at the original key. The contract passes 4/4, a
     fresh OS BEAM safely loads all seven assets, the affected codec suites pass
     52/52, and a forced Specs compile passes with warnings as errors.
191. TI-83 PLUS 2002 RED/GREEN: an independent compact 256-row numeric asset and
     digest-bearing metadata preceded runtime code; the valid initial suite
     passed only its source-boundary checks and failed 13/17 on the six absent
     font-qualified profiles. Native compile-time tables now implement readable,
     mixed-lossless VPUA, and raw VPUA forms for both fonts with no bare aliases;
     all bytes, canonical/alias/decode-only reverses, 131,072 lossless adjacent
     pairs, longest prefixes, normalization collisions, streams, invalid offsets,
     direct UTF-8, and bounded reduction scaling pass 19/19. Benchmark tests then
     failed 2/2 on the absent executable and now pass 2/2 with 24 direct/public
     profile gates, ten invalid-policy gates, strict ceiling-derived 30x floors,
     isolated 2x-input reduction gates, and exact `iconv -l` matching. Review
     reproduced that the old engine could report a pinned digest without binding
     compilation to the asset: the metadata callback RED failed 1/1 and a
     tamper-validator RED failed because no validator existed. Compilation now
     hashes the exact mapping and metadata bytes before parsing and enforces the
     header, 256 ordered uppercase byte tokens, scalar/policy consistency,
     alias-to-canonical ownership, canonical reverse uniqueness, and lossless
     bijections. Recomputed-hash mutations cover mapping/metadata tampering,
     duplicate/lowercase byte tokens, a surrogate, unknown policy, alias-to-alias
     routing, and duplicate canonical output. Inventory/package contracts move
     to 1,755 runtime and 1,757 catalogued codecs; the full-stack derived count is
     2,005 and the centralized eight-range VPUA ledger is non-overlapping. A
     clean consumer built all seven unpacked Hex artifacts with warnings as
     errors and passed the exact asset/profile/count audit, including all 1,755
     empty Specs encode/decode checks.
192. ECMA-44 SOURCE-ASSET INTEGRITY RED/GREEN: the source validator was absent,
     and a copied downstream consumer still compiled after exact-byte CSV
     tampering; the focused contract failed 2/15. Compilation now binds the
     pinned SHA-256 digest, exact header, 16x16 row order, uppercase three-digit
     hexadecimal cells, uniqueness and punched-card physical validity, and
     semantic equality with the hardcoded 256-mask runtime tuple. The focused
     raw suite passes 15/15, raw plus benchmark passes 16/16, and a forced Specs
     compile passes with warnings as errors; the runtime hot paths are unchanged.
193. TI AMS 2.0 SOURCE-ASSET INTEGRITY RED/GREEN: an isolated copied consumer
     accepted mapping and metadata tampering, changed byte `01` from U+0001 to
     U+0002, and still reported the original mapping digest. The focused RED
     suite failed 2/16 on the absent validator and metadata-digest callback.
     Compilation now hashes exact mapping and metadata bytes before parsing and
     enforces the exact preamble/header, 256 ordered uppercase byte tokens, five
     fields, one-or-two valid Unicode scalars, and unique reverse mappings in all
     four profiles. Recomputed-digest regressions exercise every schema guard.
     The focused functional suite passes 16/16, functional plus benchmark passes
     18/18, and a fresh 118-file Specs compile passes with warnings as errors.
     The same isolated consumer now fails compilation independently on either
     the tampered mapping or tampered metadata digest.
194. UNIHAN TELEGRAPH PROPERTY-TOKEN RED/GREEN: frozen Unicode 17.0.0 Mainland,
     Taiwan, and explicit Taiwan-lossless fixtures preceded runtime code. The
     valid focused RED run passed source facts and normalization analysis but
     failed 9/29 exactly on the absent validator/API/profiles, package selection,
     and central VPUA ledger entry. Three non-codec modules now implement a
     dedicated one-token behavior over dense compile-time 10,000-entry tuples
     and reverse maps. Exhaustive tests cover all 30,000 decode outcomes, all
     25,128 profile reverses, exact malformed errors, UTF-8 cardinality and
     offsets, every normalization form, runtime no-I/O tracing, and registry
     nonclaims; the focused GREEN run passes 29/29.
195. UNIHAN TELEGRAPH ASSET/RELEASE GREEN: compilation hashes the exact three
     compact CSVs and sanitized metadata before validating headers, row counts,
     strictly increasing four-digit tokens, Unicode scalar validity, regional
     duplicate facts, minimum-token reverse ownership, source/policy agreement,
     the four exact VPUA rewrites, and lossless uniqueness. Recomputed-hash
     mutations exercise header, ordering, surrogate, cross-table, and duplicate
     output rejection. The release manifest selects only those four assets,
     the separate three-row property-token inventory, documentation, and the
     Unicode license. The central U+F8B00..U+F8B03 allocation and executable
     range contract are non-overlapping. The independent research verifier now
     requires exactly its frozen pre-allocation snapshot plus the implemented
     block in live mode; the executable ledger passes and the stale frozen-only
     ledger is permanently rejected as live evidence.
196. UNIHAN TELEGRAPH BENCHMARK STRICT-30X RED/GREEN: fifteen fresh-process
     paths measure assigned/unassigned decode, scalar reverse, token-to-UTF-8,
     and UTF-8-to-token for all three profiles. A cross-track audit found the
     first floors rounded minimum/30 down and could accept a 30.14x regression;
     the strengthened test failed 1/2 on the stale 4.37 MiB/s output. All floors
     now use a ceiling to 0.01 MiB/s, independently prove recorded/floor <= 30,
     and pass 2/2. Final-code values and the fast-path refresh are recorded in
     cycle 201. GNU libiconv 1.19 has no exact profile alias.
197. UNIHAN TELEGRAPH CATALOG RED/GREEN: the focused catalog contract failed
     1/37 while the three explicit property-token clusters were absent. The
     generator now emits a separate `implemented_property_token_mapping`
     disposition without claiming byte-codec support: 1,618 total clusters,
     three property mappings, 1,283 implemented codec clusters, and 101 codec
     gaps. A second adversarial RED failed 1/38 when an unknown future property
     row was incorrectly folded into codec gaps. Inventory-backed rows now use
     `implemented_property_token_mapping`; absent rows use the distinct
     `property_token_mapping_gap`. Current counts are 1,618 total, 1,283 codec
     implementations, three property mappings, 101 codec gaps, zero property
     mapping gaps, 140 research candidates, and 91 other audited clusters. The
     generic `Chinese telegraph code` record remains a codec gap until an
     authoritative concatenated transport is selected. Regenerated artifacts
     pass 38/38 and the full core suite passes 345/345.
198. PROPERTY-TOKEN INVENTORY GENERATOR RED/GREEN: the public metadata snapshot
     test failed 1/11 while its generator was absent. A deterministic generator
     now derives the exact three-row inventory from the public profile metadata;
     generated bytes and package selection pass, with the expanded functional
     file green at 14/14 after subsequent contracts.
199. UTF-8 CARDINALITY BOUNDS RED/GREEN: a one-million-scalar ASCII regression
     killed the old list-materializing helper under a 250,000-word max heap.
     Replacing it with validation plus a tail-recursive scalar scan made that
     bounded case green. A second RED exposed that `String.length/1` counted
     graphemes rather than scalars for decomposed accents and an emoji family;
     exact UTF-8 bitstring scalar counting now returns 2 and 7 respectively and
     preserves the core malformed kind, byte offset, and remaining bytes.
200. DURABLE UNIHAN SOURCE ORACLE RED/GREEN: the strict source contract failed
     before its tools and exact sources existed. The repository now retains the
     pinned 3.5 MiB Unihan member and 2.1 MiB UnicodeData 17.0.0 fixtures. A
     deterministic extractor regenerates all three compact CSVs byte-for-byte;
     a separately implemented verifier imports no generator and checks all
     30,000 outcomes, reverse minima, duplicates, four normalization forms and
     the VPUA policy. Cwd-independent positive, source-tamper, table-tamper and
     implicit-package-overwrite checks pass. Hex excludes the large fixtures and
     tools.
201. UNIHAN UTF-8 HOT-PATH/PERFORMANCE RED/GREEN: review found every successful
     one-scalar encode was validated and scanned twice. The new 50,000-call
     contract failed at 1,129,331 reductions against a 900,000 budget. An exact
     `<<scalar::utf8>>` clause now handles that path while empty, multi-scalar and
     malformed inputs keep the bounded validator. The permanent gate was then
     hardened against OTP-specific absolute counts by measuring each side in a
     separate fresh worker process inside the same test VM and requiring at most
     35% overhead versus the direct scalar path; it and all functional tests pass.
     Two uncontended 262,144-token production runs record
     conservative minima 130.41/149.21/54.45/78.67/42.68 logical MiB/s and strict
     ceiling-derived floors 4.35/4.98/1.82/2.63/1.43; the test-first floor refresh
     failed 1/1 on stale executable values then passes 2/2. UTF-8-to-token reaches
     a 42.68 MiB/s minimum, 15.6% above the audited pre-fast-path 36.93 minimum;
     all fifteen reduction-scaling ratios remain 1.999x–2.000x.
202. UNIHAN FINAL REVIEW-ORACLE RED/GREEN: two independent audits found the
     runtime no-I/O test traced the ExUnit process with itself as tracer. Adding
     a deliberate `File.read!` positive control failed 1/1 with an empty
     mailbox, proving the oracle was inert. GREEN runs a distinct traced worker,
     keeps the test process as tracer, synchronizes with `trace_delivered`, and
     proves the control read is visible before exercising all six public calls
     for all three profiles with zero `File`/`:file` calls. The inventory test
     then failed when the generator ignored a requested temporary output path;
     the executable now supports `--output` and `--check`, reproduces exact
     bytes, accepts a current file, and rejects a stale file. The source test
     permanently invokes the extractor's package-overwrite refusal. Benchmark
     prose now states the actual separate-worker/same-test-VM evidence without
     claiming an unexecuted supported-OTP matrix. Functional plus benchmark
     coverage passes 16/16; companion Core cycle 54 closes the property-kind
     classifier-precedence collision under its own failing regression.
203. KOI8-F SOURCE-EXACT RED/GREEN: source and license contracts preceded the
     implementation and failed while no `KOI8-F` profile existed. GREEN adds
     the complete 256-octet NMSU KOI8 Unified Cyrillic 2.1 table under only
     source-qualified aliases, checks every octet and canonical reverse, and
     permanently pins the duplicate U+00A0 cells plus 0x95 U+2219 deviation.
     The exact mapping and its MIT notice ship with digest-bearing provenance;
     the focused functional suite passes 5/5. Package/cardinality contracts
     then moved to 1,756 runtime, 1,758 catalogued, and 2,006 full-stack codecs;
     the expanded source, license, package, identity, and substitution run
     passes 30/30, and an unpacked Hex artifact contains all three required
     KOI8-F evidence files at their pinned hashes.
204. KERMIT SINGLE-BYTE UTF-8 PERFORMANCE RED/GREEN: the KOI8-F benchmark was
     tightened before implementation to require both direct UTF-8 callbacks to
     stay within 1.25x of their generic callback composition. The fresh RED run
     passed all new 64 KiB split-scalar and first-error-order checks but failed
     1/7 because encode measured 2.955x its baseline. GREEN precomputes the
     byte-to-UTF-8 tuple and parses UTF-8 in bounded 64 KiB chunks, carrying a
     split scalar while retaining absolute offsets, the complete malformed
     suffix, and unrepresentable-versus-malformed ordering. The same fresh
     suite passes 7/7; the complete shared-macro regression passes 24/24. A
     final quick run records 35.781 MiB/s decode at 0.745x baseline and 50.970
     MiB/s encode at 0.716x baseline, with near-exact doubled-input reduction
     scaling and no false GNU comparison for the source-qualified profile.
205. KOI8-F PERFORMANCE-EVIDENCE BINDING RED/GREEN: a packaged-document
     contract failed 1/2 while the measured KOI8-F prose had no deterministic
     connection to its runtime and benchmark sources. After adding the digest,
     an exact-space assertion remained RED across ordinary Markdown wrapping;
     the final semantic whitespace contract passes 2/2 and pins SHA-256
     `a3f631940e665456f6252149595589ecd6bb15c33b5690d413602ab01cece372`.
     An isolated production run passes both gates at 25.924 MiB/s decode,
     0.306x generic latency, 37.135 MiB/s encode, and 0.388x generic latency.
     Full production runs refresh the four versioned Kermit GNU ratios to
     1.68x–2.21x and all eleven vendor profiles; their 22 scheduler-reduction
     ratios remain 1.971x–2.042x against the 2.3x ceiling.
206. UNIVAC I SOURCE/TRANSPORT RED: after correcting two oracle-only assertion
     mistakes, the focused suite passed its independent 64-row source audit but
     failed 10/11 while the five source-qualified runtime profiles, registry
     aliases, and packed transports were absent. The RED surface covered every
     basic unit, all 128 checked septets, all 256 physical tape rows, strict and
     policy callbacks, every stream split, direct UTF-8 ordering, inventories,
     and reduction scaling before production code was added.
207. UNIVAC I ENGINE GREEN: one compile-time source-bound engine now exposes
     semantic, lossless VPUA, raw VPUA, odd-parity septet, and physical
     `1,2,3,4,S,5,6,7` tape-row codecs. The table has exactly 63 assignments and
     one explicit `NOT USED` pattern; high octets are never masked. Manual
     vectors `A=0x54` / digit `1=0x04` in checked form and tape rows
     `A=0xAC` / digit `1=0x0C` pass. Four non-octet profiles publish both MSB
     and LSB forms, and the focused suite passes 11/11.
208. UNIVAC I PERFORMANCE RED/GREEN: the first executable benchmark failed its
     1.25x native/generic gate because the hand-written UTF-8 encoder measured
     2.034x its baseline. GREEN uses bounded 64 KiB VM Unicode parsing and
     precomputed UTF-8 decode cells while preserving first-error ordering. The
     final 262,144-unit production run records 17.88–27.24 Mi-unit/s byte
     decode, 22.73–28.13 encode, 5.80–23.08 packed throughput, native/generic
     ratios no worse than 1.166x, and 1.822x–1.996x doubled-input scheduler
     work. GNU 1.19 has no matching codec and is explicitly unavailable.
209. UNIVAC I CATALOG RED/GREEN: the Core research suite failed 1/42 while its
     old generic row remained an open medium-confidence gap. The source now
     names the exact expanded 1959 family, retains generic historical labels
     only as catalog aliases, and binds the primary manual. Regeneration keeps
     1,614 clusters while moving to 1,285 implemented codec clusters and 97
     actionable codec gaps; the complete catalog suite passes 42/42.
210. TEX OML/OMS SOURCE-EXACT RED/GREEN: isolated contracts preceded the two
     seven-bit codecs and pinned all 128 slots from the exact `cmmi10` and
     `cmsy10` ToUnicode tables in LaTeX commit `7c8574ae`. GREEN adds distinct
     source-qualified OML and OMS profiles, rejects every high octet, tests all
     source units and Unicode scalars, and publishes explicit packed MSB/LSB
     transports. The focused functional suite passes 9/9.
211. TEX OML/OMS PERFORMANCE GREEN: production-sized direct callbacks use
     precomputed UTF-8 cells and bounded parsing. Decode reaches 23.97–25.98
     Mi units/s at 0.39x–0.41x composed latency; encode reaches 8.25–11.90 Mi
     units/s and stays within the 1.25x direct/composed ceiling. GNU libiconv
     has no exact profile aliases, so no misleading GNU ratio is reported.
212. CORK T1 SOURCE-EXACT RED/GREEN: two semantic-profile tests were written
     from the complete 256-slot Cork source before runtime registration. GREEN
     exposes the EC-glyph and CTAN CMap 1.0j interpretations separately,
     preserves their nine intentional slot differences and undefined 0x18,
     tests all bytes, reverses, policies, offsets and Unicode scalars, and
     passes 13/13. Production direct/reference ratios are 0.031x–0.562x with
     1.610x–2.090x doubled-input scheduler scaling.
213. TEX/CORK SHARED-INTEGRATION AND CATALOG RED/GREEN: count, registry,
     packed-profile, package and generated-inventory expectations were raised
     first; the focused shared run failed four assertions before the four
     profiles were registered and their provenance assets selected. It then
     passed 70/70. Three catalog assertions failed before the source-qualified
     Cork, OML and OMS rows were supplied; regeneration closed exactly those
     gaps and the complete research suite passed 43/43.
214. FORMAL SIGNWRITING V1.0.0 RED/GREEN: the source and exhaustive lexical
     contract failed 12/12 while `FSW` was absent. GREEN implements the pinned
     Zenodo v1.0.0 grammar only: five markers, 500 number coordinates, and all
     62,504 `S10000..S38b07` symbols mapped to their declared Unicode design.
     Tests enumerate all symbols, 262,144 shaped candidates, 250,000 coordinate
     pairs, every Unicode scalar, malformed offsets, policies and stream splits;
     the expanded focused suite passes 14/14.
215. FORMAL SIGNWRITING PERFORMANCE RED/GREEN: the first direct decoder was a
     whole-input composition and failed the tightened latency contract. A
     per-token scanner was measured and rejected at 3.049x; the final bounded
     hybrid retains exact absolute errors without unbounded lists. Production
     decode reaches 10.60 MiB/s at 0.547x baseline latency and encode reaches
     22.95 MiB/s at 0.955x, with 1.987x/2.006x reduction scaling.
216. FORMAL SIGNWRITING PACKAGE/CATALOG RED/GREEN: raised public counts and
     provenance selection failed three of six package assertions before the
     profile and source assets were integrated. Four of 44 catalog tests then
     failed before the exact Zenodo row replaced the broad historical gap.
     Regeneration kept 1,614 clusters and moved to 1,289 implemented codecs and
     93 gaps; package and catalog gates pass 20/20 and 44/44 respectively.
217. PDP-1 SOURCE/STATE/TRANSPORT RED/GREEN: twelve isolated tests failed while
     no PDP-1 implementation existed. GREEN transcribes the April 1960 and
     October 1963 DEC handbooks into eight explicit profiles: Concise and
     physical odd-parity transports, each revision with lower or upper initial
     case. All 64/256 source units in both states, parity, shifts, controls,
     policies, offsets, all Unicode scalars and stream splits pass 13/13.
218. PDP-1 SHARED-INTEGRATION RED/GREEN: public counts, the exact packed roster,
     package assertions and inventories were raised before registration; the
     focused run failed 4/13. All eight profiles are now registered, the four
     six-bit Concise profiles expose named MSB/LSB transports, provenance assets
     ship, and regenerated inventories contain 1,774 codecs and 46 packed
     profiles. PDP-1 plus shared contracts pass 26/26.
219. PDP-1 CATALOG RED/GREEN: the catalog contract and aggregate counts were
     changed first and failed 5/45 while the medium-confidence umbrella remained
     a gap. The exact eight-profile supplement now joins that one historical
     row without claiming ambiguous bare runtime aliases and cites both DEC
     manuals. Regeneration keeps 1,614 clusters, moves to 1,290 implemented
     codecs and 92 actionable gaps, and passes 45/45.
220. KAMENICKÝ SOURCE-EXACT RED/GREEN: ten tests failed before the source assets
     and profiles existed. GREEN normalizes the public-domain 1996 KEYBCS2
     description, proves every byte against pinned Free Pascal and DOSEMU
     tables, and exposes the maintained MySQL one-byte variant separately.
     Both profiles define 256 unique scalar outputs; exhaustive byte/reverse,
     policy, malformed UTF-8, split and all-scalar checks pass 10/10. Numeric
     CP895/CP867 aliases remain excluded because they collide with IBM pages.
221. KAMENICKÝ SHARED-INTEGRATION/PERFORMANCE RED/GREEN: package counts and
     exact inventory assertions were raised first and failed 3/6. Registering
     `KEYBCS2` and `MYSQL-KEYBCS2`, selecting their digest-bound assets, and
     regenerating the runtime inventory yields 1,776 profiles. An added public
     streaming matrix checks every source-byte and UTF-8 byte split for both
     profiles; functional plus package contracts pass 17/17. Production ASCII reaches about 133 MiB/s,
     full-alphabet decode 52 MiB/s and encode 36 MiB/s; native callbacks use
     0.41x–0.53x reference time with linear scheduler work. GNU has no exact
     alias and is reported unavailable.
222. KAMENICKÝ CATALOG RED/GREEN: aggregate and exact-source assertions failed
     while the encyclopedia-only row remained a gap. The source-qualified
     supplement now records both safe runtime profiles and both mapping
     authorities without admitting ambiguous numeric aliases. After the live
     runtime inventory was regenerated, the complete research suite passes
     46/46 at 1,614 clusters, 1,291 implemented codecs and 91 actionable gaps.
223. ABICOMP SOURCE-EXACT RED/GREEN: five isolated tests failed while the
     profile and source assets were absent. GREEN adds the exact Brazil CP3848
     table: ASCII/control identity, 64 assigned A0--DF cells, and explicit
     undefined 80--9F/E0--FF ranges. Expanded coverage checks all 256 bytes,
     all 192 reverses, every Unicode scalar, every stream split, policies,
     source tampering and provenance at 8/8. Independent Star, Epson and
     FreeDOS evidence agrees; PCL-13P/14P and ABICOMP-INTERNATIONAL remain
     excluded rather than guessed. The production benchmark records
     33.2--290.7 MiB/s, native/reference 0.145x--0.800x and linear reductions;
     GNU 1.19 has no exact comparator.
224. BRASCII SOURCE-EXACT RED/GREEN: eleven tests were written before the
     implementation and all failed. GREEN implements all 256 NBR-9611 bytes,
     identity except D7/F7 to U+0152/U+0153, with an explicit C0/C1 Unicode-
     identity text policy. The same 11/11 suite exhausts every byte, every
     Unicode scalar, every source and UTF-8 split, policies, malformed offsets,
     tampering and provenance. Two differently encoded Star PDF containers
     were reconciled by a byte-identical rendered source page. Production
     decode/encode reaches 223.36/39.65 MiB/s at 0.076x/0.293x baseline latency
     with linear work; GNU 1.19 exposes no BraSCII or CP3847 identity.
225. KERMIT JIS7-KANJI SOURCE/STATE/PERFORMANCE RED/GREEN: the initial source-
     qualified suite failed 13/13 before the three-state codec existed. GREEN
     implements Kermit's initial JIS Roman state, SO/SI kana, its four exact
     designations, doubled ESC, persistent line state and ESC-(J finalizer.
     All 6,879 decoder mappings match both Kermit's executable tables and
     Unicode JIS0208.TXT; the expanded state/scalar suite passed 15/15. A later
     executable-source RED failed 3/16 because a symmetric inverse over-
     accepted 38 mappings that Kermit's `un_to_sj()` bounds make decode-only.
     The exact 6,841-entry encoder subset and 7,029-scalar total repertoire now
     pass 16/16, every Unicode scalar, and 24/24 combined ICU cross-checks.
     Production throughput is 16.30--330.80 MiB/s, native/composed no worse
     than 0.994x, and reduction scaling 1.899x--2.000x. It is neither ICU JIS7
     nor a generic ISO-2022-JP alias; GNU has no exact comparator.
226. ABICOMP/BRASCII/JIS7 SHARED-INTEGRATION AND CATALOG RED/GREEN: public
     runtime/catalog counts and package assertions were raised first; six
     package tests failed three assertions at 1,776 versus 1,779 profiles.
     Registering the exact three codecs, selecting all mapping/source/license
     assets, and regenerating the inventory produced a focused 40/40 GREEN;
     current Kermit plus package verification is 22/22. The catalog contract
     then failed 7/47 before the three source-qualified records existed.
     Regeneration preserves 1,614 audited clusters, moves to 1,294 implemented
     codec clusters and 88 actionable gaps, and passes the complete 47/47
     research suite. The packed inventory remains 46 because all three use
     octet/stateful transports rather than non-octet units.
227. MACOS ESPERANTO SOURCE-EXACT RED/GREEN: eleven tests failed before the
     codec and evidence assets existed. GREEN transcribes all 223 rows in
     Michael Everson's MacOS Esperanto table v0.3 and explicitly assigns
     Unicode-identity text transport to the omitted C0/DEL positions. The
     resulting 256 mappings are unique. The 11/11 suite checks every byte,
     every Unicode scalar, every source/scalar split and one-unit chunking,
     policies, malformed UTF-8 precedence and offsets, source tampering and
     linear work. A 1 MiB production run records 48.60 MiB/s decode and 21.60
     MiB/s encode at 0.186x/0.287x baseline latency; GNU 1.19 has no exact
     MacEsperanto codec.
228. VSCII-2 / TCVN VN2 SOURCE-EXACT RED/GREEN: nine tests failed while the
     ISO-IR-180 profile and assets were absent. GREEN classifies all 256 bytes
     as 224 unique assignments and the exact 80--9F hole, checks all Unicode
     scalars, combining-mark no-normalization behavior, policies, malformed
     offsets, every stream split and structural/digest tampering. A follow-up
     registry-state RED failed 1/9 after Core removed its false
     ISO-IR-180-to-VISCII alias; digest-bound metadata now records that resolved
     finding. Production corpora reach 25.48--111.10 MiB/s decode and
     17.20--25.19 encode, native/reference at most 0.615x, with linear work.
     GNU VISCII is RFC 1456 and GNU TCVN is VN1, so neither is misused as a
     comparator.
229. MACOS ESPERANTO/VSCII-2 SHARED-INTEGRATION RED/GREEN: counts, canonical
     assertions, catalogued totals and generated inventory expectations were
     raised before registration. The six package tests failed exactly three
     assertions at 1,779 versus 1,781 runtime codecs and 1,781 versus 1,783
     catalogued definitions. GREEN registers both modules, packages only their
     normalized mapping/provenance assets, and regenerates 1,781 inventory rows;
     isolated codecs plus package contracts pass 26/26 before the added
     external-identity regression. That regression proves ISO-IR-180/VSCII
     resolve to VSCII-2 while RFC 1456 VISCII and VN1 TCVN remain distinct.
     Both profiles are octet codecs, so the 46-row packed inventory is unchanged.
230. MACOS ESPERANTO/VSCII-2 CATALOG RED/GREEN: aggregate and exact-source
     contracts failed 8/48 while the two encyclopedia rows remained gaps and
     the summary retained the earlier totals. Source-qualified supplements now
     bind Everson's v0.3 table and ISO-IR-180 plus the independent VN2 charmap,
     without importing VISCII/VN1 aliases. Regeneration preserves 1,614 audited
     clusters, moves to 1,296 implemented codec clusters and 86 actionable
     gaps, and the complete research suite passes 48/48.
231. RECENT SOURCE-QUALIFIED BENCHMARK EVIDENCE RED/GREEN: the new digest and
     package-selection contract was written before its BENCHMARKS marker and
     table existed. RED (`seed: 267486`) failed 1/1 at the absent marker.
     GREEN added exact runtime/harness SHA-256 rows for OML/OMS, Cork, Formal
     SignWriting, PDP-1, Kamenický, ABICOMP, BraSCII, and Kermit JIS7-KANJI;
     after formatting, `seed: 179854` passed 1/1. The contract independently
     verifies public module selection, every retained source asset, release
     inclusion of runtime/evidence/docs, development-only exclusion of each
     harness, its schema/summary markers, and both raw-file digests. All eight
     harnesses then executed successfully (the seven gated schemas reported
     passing summaries), the eight codec suites plus the contract passed
     96/96 (`seed: 985424`), and package plus evidence contracts passed 7/7
     (`seed: 971107`).
232. LOTUS LICS BENCHMARK/RELEASE EVIDENCE RED/GREEN: `lotus-lics` was added
     to the recent source-qualified benchmark contract before its evidence row
     or package selectors. RED (`seed: 0`) failed 1/1 with the exact ten-row
     actual set versus the expected eleven-row set. The prepared evidence binds
     runtime SHA-256 `7a3efcb43ed7edeaa61f3458464554d898eb89c8c07973e4670b8fac84cebdfd`
     and harness SHA-256
     `a5c50b9db7e1ca309e9a5654154663c087106dc33c0b042ea0f50b36d61c307a`,
     selects only the normalized CSV and provenance record, and records the
     executable gates and exhaustive conformance. After shared registration,
     the contract is GREEN at 1/1 and the isolated LICS suite is GREEN at 11/11
     (`seed: 0`). Its quick gate records 18.314--34.265 MiB/s,
     1.927x--2.011x reduction scaling, and 0.479x--0.718x baseline latency.
233. U.S. ARMY TAP CODE SOURCE/PERFORMANCE EVIDENCE RED/GREEN: the exact
     `us-army-tap-code-pair-values` batch was added to the contract before its
     benchmark row. RED (`seed: 0`) failed 1/1 with eleven actual rows versus
     twelve expected rows. GREEN binds runtime SHA-256
     `07080a8ce2eae86e0cd47c0e4b1857ca89d1456dd89dfabe5fb18b42275e2ae0`
     and harness SHA-256
     `3625d307cc1daf3e417be86a0e9fa83bfd099436bd59260c324fc9b63dbf634e`,
     packages only the 25-row mapping and provenance record, and documents the
     independently matching Army and Naval History sources plus the explicitly
     project-defined numeric-count-octet transport. The 11/11 codec suite
     exhausts all 65,536 octet pairs and every Unicode scalar. Its eight quick
     paths pass at 67.568--353.107 MiB/s, 1.908x--2.000x reduction scaling, and
     0.259x--0.500x native/reference latency.
234. LICS/TAP SHARED REGISTRATION/RELEASE EVIDENCE RED/GREEN: the prepared LICS
     evidence first reached the sole missing `Specs.codecs/0` membership
     assertion. Shared registration now exposes both exact modules, and the
     package selects both normalized CSVs and metadata while excluding both
     development-only harnesses. The final twelve-batch digest/release contract
     passes 1/1, and the combined exhaustive codec run passes 22/22
     (`seed: 0`), all with warnings treated as errors.
235. IBM 24/26 ARRANGEMENTS SOURCE/TRANSPORT/PERFORMANCE RED/GREEN: the focused
     suite was added before source assets, modules, registrations, inventories,
     or benchmark and failed 10/10 (`seed: 0`). GREEN pins IBM A24-0520-3 and
     its exact 110-cell Figure 23 extraction, adds all arrangements A-K over the
     shared 37-character Figure 28 repertoire, and preserves six duplicate
     punches as decode aliases under a deterministic base-first/left-to-right
     inverse. The 10/10 suite enumerates 40,960 logical mask dispositions,
     every Unicode scalar through MSB, LSB, 16BE, and 16LE, every source-byte
     stream split, recovery policies, exact registrations, generic-name safety,
     and generated inventories. The focused quick benchmark covers 80 timed
     paths with 1.879x reduction and 2.097x wall scaling; the worst dense-table
     reference ratio is 3.424x, below the 30x ceiling.
236. SOURCE-AUDIT/TELECOM-PROVENANCE/PERFORMANCE RED/GREEN: source-contract
     tests were added before remediation. The isolated specs RED failed 5/5
     (`seed: 0`) for the absent OpenJDK license bundles, UTF8-MAC and CPython
     metadata, consolidated SOURCES/NOTICE classifications, and executable
     benchmark. Telecom RED failed 2/2 (`seed: 0`) for the absent per-artifact
     provenance manifest and package selection. GREEN pins the four exact
     OpenJDK GPLv2+Classpath bundles at revision
     `6ae23a0d6574dc8139aea93ea3c562a7410fcb34`, the canonical APSL 1.0 text,
     CPython 3.14.6/PSF2, .NET/MIT, glibc/LGPL, Unicode Windows Best Fit, and
     conservative repository-only IANA/IBM boundaries. Every retained source
     file has a digest and exact origin. Telecom removed one 245-byte rejected
     HTML response masquerading as a PDF, records every remaining PDF,
     rendering, extraction and capture, and excludes all `tmp/` evidence from
     Hex. Its focused suite is GREEN at 2/2 in 0.1 s and the rebuilt package
     checksum is
     `39305a5f46ec44203483a2977d6c65aabafa59c5745f7b92f4b3a48b70e61e4c`.
     The specs contract reached 4/5 before BENCHMARKS was bound, then 5/5.
     The first executable calibration exposed and rejected a 3.475x stateful
     escape-transition scaling sample under an overly narrow 2.75x bound; the
     final explicit 4.00x hard bound passes all 28 paths. Calibration completed
     in 5.5 s and the non-calibration gate in 6.3 s, with 2.719–107.021 MiB/s,
     1.607x–3.475x scheduler scaling, exact CPython output, and 0.450x/5.631x
     native-to-CPython ratios under the 30x ceiling.
237. UTF-5 EXACT-DRAFT ENGINE RED/GREEN: the source-bound contract was written
     before the module, registration, or draft bundle and failed 7/7 because
     `Iconvex.Specs.UTF5` did not exist. GREEN independently implements the
     exact uppercase variable-length hexadecimal transform in
     `draft-jseng-utf5-01`, with strict grammar, native discard/substitution,
     direct UTF-8 callbacks, streaming callbacks, exact error offsets, and the
     draft's vectors. The expanded 9/9 suite exhausts all 1,112,064 Unicode
     scalar values. The retained draft is byte-exact at SHA-256
     `12ae18367c110b5dcef9cc3f06b6ae40e60c8fde489fdd161f1bb98e3e5f2375`.
     A rerun of the four-corpus quick benchmark measured 5.526–76.850 MiB/s,
     1.909x–2.009x scheduler-reduction scaling, and 0.288x–0.493x
     native/reference latency; all gates pass and GNU libiconv 1.19 exposes no
     UTF-5 comparator.
238. UTF-6 DRAFT ENGINE RED/GREEN: the ten-test contract was added before any
     runtime or source bundle. RED (`seed: 0`) failed 10/10 because
     `Iconvex.Specs.UTF6` and the pinned draft were absent. GREEN independently
     implements `draft-ietf-idn-utf6-00` as a whole-hostname transform over
     UTF-16 code units, including surrogate reconstruction, all three
     compression branches, case-insensitive reverse input, RFC 1035 label
     bounds, synchronized `:stop` recovery, and native scalar policies. The
     focused suite passes 10/10 in 3.3 s and exhausts every Unicode scalar in a
     reverse-legal context. The source SHA-256 is
     `80033b5e41bc9f2fd01bddf99a300827b837f06ba93ef303bc54bc53df3755ca`.
     Its five-corpus quick benchmark passes at 8.781–55.704 MiB/s,
     1.956x–2.006x reduction scaling, and 0.229x–1.082x native/reference
     latency, beneath the 30x ceiling; GNU libiconv 1.19 has no UTF-6 profile.
239. UTF-6 SHARED REGISTRATION/INVENTORY RED/GREEN: public membership, exact
     aliases, conversion vectors, package source selection, consolidated
     totals, and inventory assertions were raised before registration. RED
     (`seed: 0`) failed exactly 4/17 at 1,804 versus 1,805 runtime codecs, 1,806
     versus 1,807 catalogued definitions, absent UTF-6 membership, and the
     stale byte inventory. GREEN registers the one source-qualified module and
     regenerates all five inventories under `MIX_ENV=test`: 1,805 byte/runtime
     codec rows, 19 non-octet rows, 56 packed rows, three property-token rows,
     and two raw transports. The focused integration passes 17/17 and the six
     count/identity/inventory suites pass 52/52 with warnings as errors. UTF-6
     does not change the non-octet, packed, property-token, or raw totals. A
     clean Hex dependency rehearsal unpacks successfully and contains the
     runtime plus all three UTF-6 source/provenance files; the packaged draft
     recomputes to the pinned SHA-256.
240. ALGORITHMIC DIFFERENTIAL ROSTER RECURRENCE RED/GREEN: the artifact guard
     was expanded before the runner or report to require UTF-5 as the tenth
     full-repertoire row, bind both new runtime sources, and require an explicit
     non-row disposition for UTF-6. RED (`seed: 0`) failed 1/1 because the
     checked-in 9/9 report had the stale runtime digest and no UTF-5/UTF-6
     evidence. GREEN executes UTF-5 over all 1,112,064 Unicode scalars in one
     stream and records a 5,558,000-byte result with SHA-256
     `af4168758fe965816194aa1919c721f85c84ddbf571d133123ba41693b64e406`;
     the complete runner reports 10/10 with zero mismatches. UTF-6 is
     source-bound but deliberately excluded from that monolithic row because
     its draft's 63-byte hostname-label limit makes the corpus an invalid
     single UTF-6 value; `utf6_test.exs` remains the exhaustive alternative,
     checking every scalar in a reverse-legal hostname context. The focused
     artifact plus UTF-5/UTF-6 suites pass 21/21 (`seed: 0`), the artifact guard
     passes again at seed 90210, and both changed Elixir files pass the formatter.
241. UTF-5 BOUNDED STREAMING REVIEW RED/GREEN: malformed non-final and
     adversarial streaming contracts were added before the decoder changed.
     RED (`seed: 0`) failed exactly 2/11: `K1!` was retained wholesale instead
     of reporting the one-shot-equivalent byte-2 error, and a 32 KiB impossible
     suffix was returned as unbounded pending data instead of rejecting the
     six-byte overflowing sequence `K10000`. GREEN replaces the last-initial
     scan plus prefix re-decode with one strict streaming state machine. It
     preserves delimiter-sensitive scalar and surrogate handling, reports the
     same offsets and sequences as complete decoding, retains at most the
     six-byte modern-scalar maximum, and rejects an arbitrarily long attacker
     tail after constant work. The permanent reduction gate measures 1.000x
     rejection work when that tail doubles and 1.935x work when valid streamed
     input doubles. UTF-5 passes 11/11; the combined UTF-5/UTF-6 suite passes
     22/22 with warnings as errors. Quick benchmarks pass every gate: UTF-5
     measures 3.178–77.492 MiB/s, 1.931x–2.008x reduction scaling, and
     0.342x–0.504x native/reference latency; UTF-6 measures
     3.567–22.133 MiB/s, 1.956x–2.006x reduction scaling, and a worst 1.417x
     native/reference ratio.
242. UTF-6 STRUCTURAL POLICY REVIEW RED/GREEN: direct and public discard and
     substitution contracts were added before the policy callbacks changed.
     The first RED (`seed: 0`) failed 1/1 because a trailing dot is a valid
     Unicode scalar but an unrepresentable UTF-6 hostname position, and both
     callbacks returned the strict error instead of applying the policy. A
     review follow-up added two more REDs: discarding one supplementary scalar
     after 58 BMP units incorrectly discarded a later fitting BMP scalar, and
     doubling repeated empty-label substitutions exceeded the permanent 2.35x
     scheduler ceiling. A final adversarial RED showed global dot normalization
     reversing strict error order for `A-.` and measured 3.969x work when a
     dot-bearing terminal-hyphen replacement doubled from 200 to 400 labels.
     GREEN leaves strict draft validation unchanged and uses one unified
     worklist with a bounded current component and deferred separator. It
     discards only the exact over-width occurrence and locally enqueues
     protected replacement text without rescanning an accepted hostname
     prefix. Invalid replacement text returns a typed error rather than
     recursively substituting. Repeated equal scalars at the length boundary
     replace the actual final occurrence. The focused suite passes 15/15,
     exhausts every Unicode scalar, preserves strict failure order, and bounds
     empty-label discard/substitution doubling to 1.65x–2.35x; the former
     dot-bearing reproducer is now 2.002x. The five-corpus benchmark passes all
     ten paths at 15.097–73.996 MiB/s, 1.956x–2.006x reduction scaling, and a
     worst 1.151x native/reference ratio, beneath the 30x ceiling.
243. DRAFT RELEASE EVIDENCE AND RUNTIME REBINDING RED/GREEN: the release
     contract was written before UTF-5/UTF-6 appeared in SOURCES, NOTICE, or
     BENCHMARKS and failed 1/1. GREEN packages both exact draft bundles, records
     their redistribution notices, selects them explicitly in `mix.exs`, and
     binds both executable benchmark sources. A later L4-style recurrence RED
     strengthened the same contract with final runtime digests and exact
     post-remediation measurements; it failed 1/1 against the pre-fix prose.
     GREEN records UTF-5 at 3.178–77.492 MiB/s, 0.342x–0.504x reference
     latency, and 1.931x–2.008x scaling, bound to runtime SHA-256
     `0bce145bb958b7b60baf4d921ae72cc1b67af1413555918580d2fa26412e6a45`.
     UTF-6 records 15.097–73.996 MiB/s, worst 1.151x reference latency, and
     1.956x–2.006x scaling, bound to runtime SHA-256
     `82ac0b0e4f914bac3bc1e98447f6c9b86b3f0f09eaea9dd5fdcd6d3d1d536a45`.
     The source-bound algorithmic guard then correctly rejected its stale
     runtime digest after the streaming/policy fixes. Regeneration executes all
     1,112,064 scalars and returns 10/10, zero mismatches, runtime aggregate
     SHA-256 `bc9fee70d311f00f0f7572c04c876455dc73702cb690bcb63028ed316a086134`,
     plus the explicit source-bound UTF-6 disposition. The combined draft,
     runtime, release, and algorithmic focused suite passes 28/28. Release
     documents and contracts also agree on 1,805 runtime codecs, 1,807
     catalogued definitions, and 2,055 unique full-stack canonical names.
244. NON-OCTET INVENTORY FULL-SUITE RECURRENCE RED/GREEN: the complete Specs
     suite was run after the IBM 24/26 logical profiles became part of the
     public non-octet inventory. RED (`seed: 0`) finished 833 tests with exactly
     two failures: the independent DEC Radix-50 and UTF-18 exact-list contracts
     still expected the former nine-profile inventory. GREEN extends both
     contracts with arrangements A, B, C, D, E, F, G, H, J, and K in the same
     deterministic order already enforced by the UTF-9 and generated-inventory
     contracts. The focused regression passes 14/14 with warnings as errors.
     The complete warnings-as-errors GREEN rerun passes 833/833 in 275.3 ExUnit
     seconds.
245. PASCII C-DAC GIST 1.0 RED/GREEN: the source-qualified contract and
     independent four-profile oracle were written before the runtime existed;
     the focused RED exited nonzero at the absent module. A review-driven RED
     then separated unassigned byte 80 from reserved FA/FB/FE/FF, classified
     CB as a nearest Unicode 17 best fit rather than an exact identity, marked
     the 9E logical sequence as an Iconvex inference, and documented why
     Persian and Arabic projections are withheld. The performance RED measured
     direct decode at 2.4998x the composed reduction baseline. Public edge REDs
     also exposed a core stream bug where a later malformed UTF-8 byte masked
     an earlier unresolved target prefix. GREEN provides four explicit names:
     Urdu/Kashmiri best fit, Sindhi best fit, exact assigned-byte VPUA identity,
     and forensic raw-byte VPUA identity; no bare `PASCII` alias exists. The
     ordered 256-row mapping SHA-256 is
     `335236d0b61cf050f3d0ab1d0fed7b66df6bb1c317da4291d109a8eb769d2cf5`;
     metadata SHA-256 is
     `7681febbdefbd5304a8f6402f7ebc34c742e0fdbaea0da690f7ca15e81d32c4e`;
     the copyrighted primary PDF remains reference-only at SHA-256
     `8eb605e3a7e0dcfed1fdb58de7ddfa2171d964b7b43220a234cbd6924608ecea`.
     Tests cover all 256 bytes, every canonical inverse, all 1,112,064 Unicode
     scalars, direct/public policies, every stream boundary, RHEY prefix error
     ordering, source tampering, VPUA allocation, and package selection. The
     optimized callbacks compose the already efficient primitives for valid
     input and retain the ordered malformed fallback; fresh-process gates hold
     native/composed reductions to 1.25x and doubled work to 2.60x. The final
     PASCII suite passes 13/13 in 1.6 s, the core stream regression passes
     16/16, and the benchmark evidence contract passes 2/2. Independent review
     added same-chunk, malformed optional-fast-path, invalid error-shaped, and
     stateful-target precedence REDs before the core fix was generalized. A
     separate performance RED proved the former 0.10 MiB/s floor permitted a
     56.84x regression from the recorded minimum; GREEN raises it to 0.19 MiB/s
     and therefore enforces the requested 30x ceiling. The post-fix quick rerun
     passes all 16 paths at 7.614–43.929 MiB/s, 1.858x–2.119x reduction scaling,
     and a worst 1.448x exact-reference ratio. The original quick benchmark
     covers 16 paths at 5.684–26.524 MiB/s, 1.835x–2.535x reduction scaling,
     and a worst 1.520x exact-reference ratio under the 2x ceiling; GNU
     libiconv 1.19 has no PASCII comparator. Inventories now contain 1,809
     runtime codecs and 1,811 catalogued definitions; the full stack has 2,059
     unique canonical names. Catalog ENC-1307 is implemented, leaving 81 codec
     gaps and 217 closure-audit rows.
     The final all-package recurrence passes the complete Specs suite at
     847/847 with warnings as errors after every review fix and evidence gate.
246. UNICODE 17 kGB3 RED/GREEN: eleven source-qualified contracts were written
     before the runtime existed. RED covered the exact 7,236 assigned
     coordinates, both holes, all 65,536 two-byte words, every single byte,
     every Unicode scalar, chunk boundaries, direct/public error policies,
     decimal property tokens, absent aliases, source tampering, and generated
     inventory drift. GREEN imports the pinned Unicode 17 `kGB3` property,
     exposes `UNIHAN-17.0.0-KGB3-ROW-CELL-DECIMAL-TOKEN`, and registers the
     deliberately qualified `UNIHAN-17.0.0-KGB3-ROW-CELL-GL` projection without
     claiming generic GB 13131, EUC, or ISO-2022 transport identity. The
     focused correctness suite passes 11/11 with warnings as errors; generator
     `--check` reproduces the fixture byte-for-byte.
247. kGB3 PERFORMANCE RED/GREEN: the first benchmark runs found the native
     encode path 1.8x–2.9x slower than its independent parser and exposed a
     flaky 3.008x doubled-work sample. GREEN stores prepacked output pairs in
     the scalar map and derives malformed UTF-8 offsets from input/rest sizes,
     eliminating per-character division, remainder, and temporary binaries.
     A review recurrence then turned RED because the pre-fix throughput minima
     would permit more than a 30x regression from the optimized rates. Two new
     production passes pin slower rates of 4.525, 13.560, 3.044, and 16.477
     MiB/s; upward-rounded `/30` floors are 0.16, 0.46, 0.11, and 0.55 MiB/s.
     All four direct/composed paths pass at 3.044–19.194 MiB/s, at most 1.527x
     their independent reference, with 1.990x–2.007x reduction scaling. The
     benchmark tests pass 2/2 and the combined kGB3 suite passes 13/13.
248. BCD-CDC-IOWA RED/GREEN: the exact secondary reconstruction was added to
     the punched-card oracle before any runtime module existed. RED failed
     10/19 focused contracts on the absent logical profile, 16BE/16LE codecs,
     packed inventory, and registry entries. GREEN implements all 64
     independently extracted scalar/mask pairs with the existing constant-time
     4,096-cell decode tuple and encode map. It exhausts all 4,096 masks, all
     1,112,064 Unicode scalars, packed MSB and explicit LSB bitstreams, both
     zero-padded endian word forms, public conversion policies, malformed UTF-8,
     streaming splits, and generated inventories. Only `BCD-CDC-IOWA` and
     `BCD-CDC-IOWA-RECONSTRUCTED` identities are exposed; generic `BCD-CDC` and
     CDC card names remain unresolved. A separate package-boundary RED failed
     until the two normalized CSVs and two evidence Markdown files were selected
     without selecting any retained PDF or HTML artifact. The focused suite is
     GREEN at 20/20.
249. BCD-CDC-IOWA CATALOG/PERFORMANCE RED/GREEN: a catalog RED required the
     exact implemented reconstruction to remain separate from generic
     `CDC punched-card BCD`. GREEN keeps the generic row at ENC-0091 as a
     `codec_gap`, adds the implemented source-qualified child at ENC-0092, and
     synchronizes all 217 closure-audit IDs. The catalog now has 1,625 clusters,
     1,313 implemented codecs, 81 codec gaps, and 105 supplemental records.
     The benchmark RED first exposed truncation of the longer profile label;
     GREEN widens the output field and covers all 48 profile/transport/direction
     paths. Two production runs measure the Iowa profile at 9.605–16.140 million
     characters/s, 0.53x–0.65x native/reference encode, and 2.63x–3.16x
     native/reference decode. All eight deterministic reduction gates remain
     1.763x–1.966x, and the worst reference ratio is far below the 30x ceiling.
     Inventories now contain 1,812 byte codecs, 1,814 catalogued definitions,
     20 non-octet profiles, and 57 packed profiles; the full stack contains
     2,062 unique canonical codecs.
250. PUNCHED-CARD BENCHMARK INDEPENDENCE RED/GREEN: adversarial review found
     that the 48-path comparator built its lookup table by invoking the native
     encoder and timed only digits plus uppercase letters. The permanent source
     contract was added first and failed because neither evidence CSV was
     referenced. GREEN loads and digest-validates `canonical_maps.csv` and
     `decode_aliases.csv`, builds the encode/decode oracle without any runtime
     codec call, and validates all 381 canonical rows plus both proved decode
     aliases. Each profile now uses a 64-unit alphabet containing every one of
     its canonical rows; the three 63-row profiles add one deterministic repeat
     rather than an invented mapping. The focused contract and executable test
     pass 2/2. The quick benchmark passes all 48 evidence-independent ceiling
     gates and all eight reduction gates; its worst reference ratio is 8.67x.
     A refreshed full production run covers 65,536 scalars per operation at
     12.598–23.736 million characters/s, with all reference ratios between
     0.24x and 15.66x, below the hard 30x ceiling.
251. BCD-CDC-IOWA ADVERSARIAL RECURRENCE RED/GREEN: an independent HTML-column
     reconstruction test was added before changing the mapping and proved that
     U+003C occupies mask `0xA02`; the runtime's earlier `0x882` value failed
     that source-derived oracle. A second strict RED exercised partial LSB
     tails and exposed error/discard precedence that could consume the wrong
     retained bits. GREEN corrects the table, keeps malformed-tail offsets and
     strict/discard behavior ordered, and independently parses all 64 source
     columns rather than restating runtime data. The punched-card suite passes
     24/24 and the complete Specs suite passes 864/864 with warnings as errors.
     The seven clean Hex artifacts then compile in a production-only consumer
     and pass the recursive audit at 2,208 packaged files, 2,064 full-stack
     codecs, 1,050 archive tables, and 1,812 Specs empty encode/decode probes.
252. GNU/RFC 1345 COLLISION RED/GREEN: the report verifier first failed at
     `IBM037` byte `0x04`, proving that the prior Specs canonical winner was
     not GNU-equivalent. A registry RED also showed the RFC identity and its
     aliases were still unqualified. GREEN source-qualifies all identities and
     aliases for the 25 semantically conflicting RFC tables while retaining the
     direct RFC API. All 758 spellings parsed from GNU libiconv 1.19 now resolve
     directly to their GNU canonical targets; every reclaimed alias is compared
     across all 256 input bytes. The 25 RFC tables remain registered under
     `RFC1345:*` identities and are covered by the existing exhaustive mapping
     test. Specs remains at 1,812 codecs and the full stack at 2,064 canonical
     names; Specs/Extras overlap becomes 227 alias claims, all won by Extras.
     The compatibility migration is explicit in the packaged changelog.
253. MULTIBYTE SUBSTITUTION RECURRENCE RED/GREEN: the complete 867-test Specs
     run turned RED in four assertions after Core correctly began emitting one
     byte substitution for every byte consumed by a malformed native unit.
     The IBM 24/26 word, Unihan kGB3 pair, US Army pair, and punched-card word
     expectations were updated to preserve that physical-byte contract while
     retaining one error callback per malformed logical unit. The focused
     regression is GREEN at 53/53, and the complete Specs suite is GREEN at
     867/867 with warnings as errors.
254. WTF-8 GNU TARGET-FALLBACK RECURRENCE RED/GREEN: the complete 873-test
     Specs run reached one stale assertion after Core implemented GNU's
     source-independent U+FFFD fallback. WTF-8 correctly decoded an isolated
     U+D800, but the old test still expected UTF-8 target encoding to error.
     GNU UCS-4BE probes establish default/transliteration U+FFFD, `//IGNORE`
     discard, and raw U+D800 Unicode substitution. GREEN covers all four
     policies plus byte-exact WTF-8 self-roundtrip; the focused suite passes
     6/6 with warnings as errors.
255. OTP CRYPTO RELEASE DEPENDENCY RED/GREEN: the package contract was added
     first and failed 1/9 because the Specs application metadata omitted
     `:crypto`, even though shipped source-integrity validators call
     `:crypto.hash/2`. GREEN declares `extra_applications: [:crypto]`; the
     focused package contract passes 9/9 with warnings as errors. An isolated
     production consumer then compiled every path dependency and assembled a
     release containing OTP `crypto-5.8`. Evaluation through that release
     started `:crypto` with Specs and executed
     `Iconvex.Specs.ABICOMP.SourceAsset.high_hex/0`, producing the expected
     1,024-byte hexadecimal table (SHA-256
     `b66b2a056d3079c01bc5122921048892b98c6d7a94b7cec129090e0706d6db57`).
256. EVERTYPE SOURCE-QUALIFIED SINGLE-BYTE RED/GREEN: seven independently
     normalized mapping artifacts and five focused contracts were added before
     any runtime codec or registry accessor existed. The 2026-07-18 RED run
     (`mix test test/evertype_source_qualified_test.exs --seed 0`) passed the
     complete artifact/provenance oracle but failed 4/5 runtime contracts on
     absent family accessor and codec modules. GREEN uses one reusable native
     macro/engine to compile the seven pinned CSVs into 256-entry decode and
     direct-UTF-8 tuples plus deterministic lowest-byte inverse maps. The seven
     source/year-qualified canonical identities have no aliases; all 1,792
     byte positions, strict/discard/substitute and stream policies, malformed
     UTF-8, registry isolation, and provenance pins pass 5/5 focused tests.
     A decode-contract recurrence was then driven RED at 2/5 because the first
     implementation returned destination-tagged `decode_error` tuples and a
     retained tail. GREEN returns the ordinary decode `error` tuple with the
     exact one-byte failing unit, while public `Iconvex.convert/4` strict and
     discard recovery and malformed input to `encode_from_utf8/1` retain their
     distinct contracts. The benchmark contract first failed on its absent
     executable, then passed 1/1: the independent CSV-derived reference covers
     1,694/1,694 mapped rows, all 21 hot-path 30x gates pass with a worst
     native/reference result of 1.578x, throughput spans 6.408-102.721 million
     units/s, and all three reduction gates pass at 1.723x-1.879x. CER-GS table
     1.01 remains deliberately blocked because its conflicting published byte
     rows cannot define a byte-exact codec without an undocumented correction.
257. IOWA CONTENT-ADDRESSED PUNCHED-CARD RED/GREEN: ten permanent contracts
     were added before the DEC 026, DEC 029, EBCD, or GE 600 logical profiles,
     word transports, normalized CSVs, and benchmark existed. The RED run
     (`mix test --no-compile test/iowa_card_profiles_test.exs --seed 0`)
     failed 9/10 tests on exactly those missing boundaries. GREEN independently
     reconstructs every Unicode scalar and punch mask from the four complete
     64-column diagrams in the SHA-256-pinned Iowa snapshot, then compiles each
     CSV into a direct encode map and dense 4,096-cell decode tuple. All 256
     source rows, 16,384 possible masks per transport matrix, all 1,112,064
     Unicode scalars per logical profile, packed MSB and explicit LSB forms,
     zero-padded 16BE/16LE words, public strict/discard conversion, every stream
     byte split, malformed tails, and high-nibble rejection pass 10/10 focused
     tests and 42/42 with the shared punched-card suites. Only names containing
     `IOWA-824E61A9` are exposed. The Hollerith consensus row remains blocked:
     its cited diagram marks four cells `?` and explicitly says those positions
     varied, so choosing one mapping would invent a profile. The production
     65,536-character benchmark passes all 32 independent source-reference 30x
     ceilings with a worst ratio of 2.926x and all 32 scheduler-work gates at
     1.962x–2.127x.
258. CTAN CMAP 1.0J OT1/OT1TT RED/GREEN: six contracts were written before
     either versioned profile, source artifact, parser, registry entry, or
     package selector existed. The isolated `--no-compile` RED failed 6/6 on
     those missing modules and boundaries. GREEN retains the verbatim LPPL
     `ot1.cmap` and `ot1tt.cmap` artifacts, validates their SHA-256 digests and
     exact code spaces at compile time, and exposes only
     `TEX-OT1-CMAP-1.0J` and `TEX-OT1TT-CMAP-1.0J` identities. All 256 octets,
     deterministic scalar inverses, `ffi`/`ffl`/`ff`/`fi`/`fl` longest
     matching, every Unicode scalar, malformed UTF-8, strict/discard/replace,
     chunk lookahead, public conversion, provenance and package selection pass
     6/6 with warnings as errors. A separate benchmark-contract RED failed on
     the absent harness/document binding before GREEN. Its 12 native/reference
     and linear-work gates pass at 5.322–14.008 Mi encoded units/s,
     1.758x–2.047x reduction scaling, and at most 0.833x the independent
     reference. GNU libiconv exposes neither exact CMap profile.
259. ABC800/RFC698 SOURCE-QUALIFIED RED/GREEN: the ABC800 four-test RED failed
     4/4 before the 1981 BASIC II character-mode table and module existed. The
     RFC 698 five-test RED likewise failed 5/5 before its two section-6 graphic
     interpretations existed. GREEN digest-pins and exhausts every one of the
     128 positions in all three profiles, every high-octet error, inverse,
     recovery and public path. Bare `ABC800`, generic Stanford Extended ASCII,
     graphics mode, and RFC 698's separate nine-bit Telnet modifier transport
     remain excluded. The shared vendor benchmark first went RED on three
     missing rows, then passes all 28 reduction gates; new-profile throughput
     spans 19.82–30.33 MiB/s and native/reference ratios stay at or below
     2.019x. Package-selection RED/GREEN retains both normalized tables and
     provenance metadata.
260. IBM029 IOWA CONTENT-ADDRESSED RED/GREEN: nine tests were added before the
     source-qualified logical profile, 16BE/16LE transports, packed profiles,
     normalized table and provenance existed and failed 9/9. GREEN reconstructs
     all 63 canonical scalar/mask pairs plus the source-proved decode-only
     `0-8-2` blank alias. It exhausts all 4,096 masks, all Unicode scalars,
     packed 12-bit MSB/LSB forms, endian words, stream splits, malformed tails,
     public policies and source-boundary aliases. The 64,512-character
     benchmark passes every comparison and scaling gate, with a worst 2.333x
     source-reference ratio and 1.973x–2.078x doubled-work scaling. Only the
     content-addressed `IBM-029-CARD-IOWA-824E61A9` family is registered.
261. LST/VNI FAMILY-INTEGRATION RED/GREEN: independent implementation cycles
     first established three commit-qualified lietuvybe LST profiles and four
     2002 VietUnicode VNI profiles, but deliberately left central selection
     unwired. New registration tests then failed at 1/1 for each family before
     GREEN added provenance-specific `LIETUVYBE-COMMIT` and
     `VIETUNICODE-2002` registration groups and release selectors. The merged
     focused recurrence passes 8/8 with warnings as errors. LST covers all 729
     mapped rows at 0.66x–1.46x its independent reference across 12 gates; its
     unavailable `/P:2012` correction prevents generic official aliases. VNI
     covers 1,041 normalized rows, every token/octet boundary, every Unicode
     scalar and Encode::VN 0.06 parity with zero missing or extra mappings;
     12 reference plus three linear gates pass with a worst 1.45x ratio. No
     bare `LST`, `VNI`, or profile-ambiguous alias is introduced.
262. SECONDARY SOURCE-QUALIFIED SINGLE-BYTE RED/GREEN: eight complete
     contracts were written before the three codec modules, native macro,
     normalized assets, provenance record, or blocker record existed. After
     correcting two test-only match expressions, the 2026-07-18
     `mix test --no-compile
     test/secondary_source_qualified_single_byte_test.exs --seed 0 --trace`
     RED reached the expected `{:invalid_codec, :module_not_loaded}` setup
     failure and invalidated all 8 runtime contracts. GREEN compiles WISCII's
     221 assignments, the revision-pinned Paratype Polytonic Greek table's 256,
     and the Wikipedia/EKI CP1270 table's 249 into direct 256-cell decode and
     UTF-8 tuples with longest-sequence/lowest-byte inverse maps. The focused
     suite passes 8/8 with warnings as errors: all 768 byte positions, all
     3,336,192 Unicode scalar probes, duplicate inverses, WISCII two-scalar
     cells, lookahead, invalid/discard/replace, malformed UTF-8, external-codec
     public conversion, and streaming are exhaustive. Only source/content-
     qualified identities are exposed and no generic aliases are claimed.
     The benchmark contract separately failed 1/1 on its absent executable
     before GREEN. Its independent CSV reference covers 726/726 assigned rows
     and 768/768 total positions; all 9 hard 30x gates pass with a worst
     native/reference ratio of 0.740x, 5.969-32.740 million units/s, and three
     doubled-work gates at 1.857x-1.967x. GNU exposes no exact comparator.
     ENC-0067 remains blocked because BICS is a prefixed two-byte set with
     explicitly non-Unicode cells; ENC-0985 because its all-rights-reserved
     authoritative table uses joining-control sequences that conflict with
     the cited presentation-form mapping; and ENC-1265 because it conflates
     two Modified HP Roman-8 variants whose tables explicitly offer alternative
     Unicode mappings.
263. LY1/POSTSCRIPT LATIN 1/TACE16 SOURCE-QUALIFIED RED/GREEN: eleven
     correctness contracts were written before any profile module, normalized
     mapping, or benchmark existed; the isolated `--no-compile` RED failed
     11/11 on those missing boundaries. GREEN digest-pins CTAN TeX'n'ANSI 1.1,
     Adobe Glyph List commit `4036a9ca`, PostScript Language Reference third
     edition Table E.7, and Tamil Virtual University Appendix D (2010). The
     focused suite passes 11/11 with warnings as errors and exhausts all 512
     glyph-vector octets, all 65,536 TACE words in both explicit byte orders,
     every normalized row, deterministic lowest-unit inverses, one-to-four
     scalar longest matching, every stream split, malformed input and recovery
     policy, plus all 1,112,064 Unicode scalars for every encoder. LY1 maps 250
     octets and rejects five `.notdef` cells plus source-internal `cwm`;
     PostScript assigns 205 octets and rejects 51; TACE assigns 380 words with
     360 Unicode equivalents and 20 lossless source-declared PUA identities.
     Bare profile-ambiguous aliases and an unspecified TACE byte order remain
     excluded. A separate benchmark-contract RED failed on its absent harness
     before GREEN; all 12 native/reference reduction gates pass at
     0.534x-0.752x the independent table reference, and all four doubled-work
     gates pass at 1.858x-1.970x. GNU libiconv 1.19 exposes no exact comparator
     for these source-qualified composite profiles.
264. FINAL RESEARCH-CLOSURE INTEGRATION RED/GREEN: the seven new public
     transports first failed the central registration contract 1/1 because
     their exact modules were not present in `Iconvex.Specs.registrations/0`.
     GREEN adds collision-safe source groups for the three secondary
     single-byte codecs, two glyph-vector codecs, and two explicit-endian
     TACE16 transports; the same contract passes 1/1. A separate package
     selector RED failed on the first missing source tree before GREEN retained
     all three provenance directories and passed 1/1. The generated live
     inventory now contains 1,848 registered codecs and the audit surface
     contains 1,850 definitions including the two quarantined RFC tables. The
     four-package integration count independently failed at the old 2,064
     expectation, then passed the full start-order/identity test at 2,100
     collision-free canonical names. Catalog regeneration classifies 1,340
     public concepts as implemented; its complete 64-test contract passes with
     70 codec gaps, 122 research candidates, 192 exact closure-audit rows, and
     zero remaining `implement_exact_codec` dispositions. A final documentation
     RED failed on the first absent canonical identity; GREEN binds all seven
     names across README, supported inventory, changelog, sources, benchmarks,
     and conformance evidence and passes 1/1.
265. NON-OCTET INVENTORY RECURRENCE RED/GREEN: the captured complete Specs
     seed-0 RED failed its exact inventory assertion with 25 live names against
     a stale 20-name expectation. GREEN adds the five already-implemented Iowa
     card transports to that test-only expectation in runtime order; the
     focused warnings-as-errors recurrence passes 9/9. No production change
     was required.
266. CLOSURE-REVIEW PROVENANCE/PERFORMANCE RED/GREEN: a focused WISCII
     provenance contract was added before changing runtime metadata. Its RED
     failed 1/1 on the old combined `Wang ... + Wikipedia revision` identity,
     proving that the Wang PDF URL and digest were still incorrectly associated
     with `CC-BY-SA-4.0`. GREEN exposes a structured `provenance/0`: the
     copyrighted external Wang chart is `NOASSERTION`, not bundled, and has no
     identified redistribution license; the separately digest-pinned Wikipedia
     Unicode binding alone is `CC-BY-SA-4.0`; the normalized factual mapping
     remains `LGPL-2.1-or-later`. The complete secondary focused suite passes
     9/9 with warnings as errors, including all 3,336,192 scalar probes. A
     separate glyph/TACE benchmark-contract RED failed 1/1 because schema 1
     emitted no elapsed-time gate. GREEN schema 2 adds a measured
     `native_to_reference_elapsed` median to every decode, encode, and round-trip
     row and hard-gates all 12 at `<=30x`, independently of the existing 12
     reduction and four scaling gates. The focused contract passes 1/1; a quick
     32,768-byte run passes elapsed ratios at 0.307x-2.145x, reduction ratios at
     0.501x-0.757x, and scaling at 1.812x-1.968x.
267. KOI8-F PAIRED-TIMING RECURRENCE RED/GREEN: the captured full-suite RED
     reported a 1.299x encode/generic latency ratio above the unchanged 1.25x
     gate. Five isolated test-build runs measured 0.711x-0.878x instead, and
     five production quick runs measured 0.235x-0.910x before a sixth run
     falsely failed decode at 2.443x. The old harness collected two independent
     timing phases, so load drift could penalize only one side of the ratio. A
     new executable-evidence assertion then failed 1/2 because no paired timing
     method was emitted. GREEN collects adjacent native/reference pairs,
     alternates their execution order, and gates the median of within-pair
     ratios without changing the 1.25x ceiling. The focused warnings-as-errors
     suite passes 2/2. Six subsequent production quick runs all pass with
     0.607x-0.742x decode and 0.378x-0.645x encode ratios. The full nine-pair
     production run passes at 51.211 MiB/s and 0.268x for decode, 67.113 MiB/s
     and 0.456x for encode, with 2.018x and 1.934x reduction scaling. No codec
     runtime change was required; benchmark prose is rebound to SHA-256
     `85ea440a39f664b818c477f241e724486c6620a61dd79c50333b183bf3d68dd7`.
268. FULL-SUITE INVENTORY/PROVENANCE RECURRENCE RED/GREEN: the complete
     958-test seed-0 RED exposed three additional 20-name non-octet assertions,
     a stale 20/57 non-octet/packed cardinality pair, and a generated-inventory
     literal that omitted the five implemented Iowa card transports. GREEN
     updates only those exact expectations to 25/62 and the current ordered
     inventory; the four focused files pass 36/36 with warnings as errors. The
     same RED also rejected the OT1 benchmark source binding after its harness
     was formatted. GREEN records the recomputed SHA-256
     `3372f88fe4c1d3dc222a4d4bbf4418bd4294574d3566215f4baef62485be95d3`;
     the two source-qualified benchmark contracts pass 2/2. No runtime codec
     change was required.
269. CENTRAL REGISTRATION LIFECYCLE RECURRENCE RED/GREEN: the captured
     958-test seed-0 run failed the complete registration-identity assertion at
     `CTAN-LY1-TEXNANSI-1.1-AGL-4036A9CA`, although the same assertion passed
     in a fresh focused VM. A lifecycle regression assertion was added before
     changing the fixtures; its focused RED failed 1/1 because the glyph/TACE
     conversion test used replacement-semantics `register_codec_owned/1` and
     then token-unregistered the replacement, permanently removing the
     application-owned registration-set row. The same stale fixture pattern
     was found in the Iowa card, IBM-029 Iowa, and VNI conversion tests. GREEN
     uses non-replacing `register_codec_if_absent/1`, conditionally removes only
     a registration actually acquired by the fixture, and asserts every codec
     still resolves afterward. The four lifecycle tests plus the exhaustive
     1,848-registration identity assertion pass 5/5 with warnings as errors at
     seed 0. No production registry or codec change was required.
270. GLIBC IBM423 PROVENANCE-CARDINALITY RED/GREEN: an independent final
     requirements audit parsed 246 assigned byte positions from the pinned
     revision's `IBM423` charmap, matching the existing exhaustive codec test,
     but found that `SOURCE.md` still claimed 249 and named Iconvex Extras as
     the implementation owner. RED extended the source-note contract first and
     failed 1/4 against both stale statements. GREEN records 246 defined
     positions and the collision-free Iconvex Specs owner; the focused pinned
     hashes, all-byte charmap parity, canonical inverse, and provenance-note
     suite passes 4/4 with warnings as errors. Runtime tables and source hashes
     did not change.
271. UTF-18 FIRST-ERROR RED/GREEN: an adversarial direct-path regression first
     failed 1/1 because malformed UTF-8 after an earlier RFC-unrepresentable
     scalar masked that scalar in both 24BE and 24LE transports. GREEN checks
     the successfully decoded prefix before returning the later UTF-8 error,
     preserving the exact malformed byte offset when the prefix is
     representable. The focused regression and complete UTF-18 suite pass 1/1
     and 6/6 with warnings as errors.
272. PUNCHED-CARD PACKED FIRST-ERROR RED/GREEN: a shared-path regression over
     all 21 twelve-bit profiles, both bit orders, and the public packed facade
     first failed 1/1 because a malformed UTF-8 suffix masked an earlier
     unrepresentable scalar. GREEN validates the converted prefix against the
     profile map before returning the later UTF-8 error and retains the exact
     malformed byte offset for representable prefixes. The focused regression
     passes 1/1 and the complete punched-card plus Radix-50 run passes 33/33
     with warnings as errors.
273. DEC RADIX-50 FIRST-ERROR RED/GREEN: a separate four-transport regression
     first failed 1/1 because whole-input `String.valid?/1` reported a later
     malformed byte before an earlier unrepresentable character. GREEN uses
     prefix-aware UTF-8 classification for the 18-bit and 36-bit BE/LE word
     codecs while preserving the optimized encoder for wholly valid input and
     exact malformed offsets when the prefix is representable. The focused
     regression passes 1/1 and the combined relevant suite passes 33/33 with
     warnings as errors.
274. OPENJDK/UTF-8-MAC PROVENANCE RED/GREEN: a review-driven license contract
     first failed 2/6 because the OpenJDK ISO-2022 source metadata called the
     runtime independent despite the JP module/support document explicitly
     calling it a port and both importers inspecting distinctive Java state-
     machine branches, while the shipped UTF-8-MAC manifest lacked the BSD-2-
     Clause attribution of the C tables from which its decomposition keys and
     exact precomposition pairs are parsed. GREEN removes the unsupported
     independent-origin claim, records the OpenJDK translation/license seam as
     an unresolved factual release blocker without offering legal advice, and
     ships the exact BSD-2-Clause terms as `LICENSE.BSD-2-CLAUSE` (SHA-256
     `10a62f2fa2653c3a669e0a17ebd06fa8300d2f949aee2b1f191d957eada61618`).
     The effective-package negative contract proves that all 31 retained GPL+
     Classpath JP/CN source files and both APSL oracle/license files remain out
     of Hex while the three generated runtime assets remain selected. The
     focused suite passes 6/6 with warnings as errors; codec runtime behavior
     and generated table bytes did not change.
275. TABLE-PREFIX RECOVERY / EXTERNAL UTF-8 FIRST-ERROR RED/GREEN: the first
     recovery test enumerated all six strict MINITEL-G0 incomplete prefixes and
     every byte split. RED failed 1/1 when `19 41` substitution produced
     `<19>A` instead of consuming one incomplete table unit. GREEN exposes the
     shared table codec's incomplete-unit width through the N5028 callbacks;
     one-shot and streaming discard/substitution now agree for every prefix and
     split. A separate runtime-wide RED classified all 1,848 direct encoders,
     derived an actual target-unrepresentable scalar for 1,811, appended both
     invalid and incomplete UTF-8, and found 410 violations: 69 direct callbacks
     and 136 public conversions across the two suffix classes. After all seven
     OpenJDK-derived codecs were quarantined, the GREEN matrix covers all 1,841
     runtime callbacks, including all 1,804 with a derived unrepresentable
     scalar, and passes every direct/public ordering assertion. Prefix-aware
     shared helpers repair the remaining table, six-bit, stateful, IBM, CDC,
     ISCII, MARC, and historical families; UTF-8-MAC preserves its existing
     bounded source
     diagnostic while checking the valid prefix first. Fresh forced compilation
     is warnings-clean. The new tests plus UTF-8-MAC pass 11/11, and 25 complete
     affected-family files pass 133/133 with warnings as errors. A fresh build
     after the complete seven-codec quarantine passes the combined recovery,
     first-error, UTF-8-MAC, and quarantine-contract selection 17/17.
276. NON-OCTET BENCHMARK CARDINALITY RED/GREEN: a review-driven benchmark
     contract first failed 1/1 because the common reporter implicitly used the
     UTF-9 scalar-list length for every throughput result. GREEN passes the
     measured workload cardinality explicitly to all eight UTF-9/UTF-18 encode
     and decode cases and computes each rate from that value, so future corpus
     divergence cannot silently distort UTF-18 throughput. The focused source
     contract passes 1/1 with warnings as errors.
277. OPENJDK ISO-2022 LGPL QUARANTINE RED/GREEN: an expectation-first
     quarantine contract failed 4/4 against the five registered GPL-derived
     source-informed translations, their two runtime modules, two importers,
     four generated ETF assets, packaged support matrices, and stale 1,848
     count. GREEN removes `x-windows-50220`, `x-windows-50221`,
     `x-windows-iso2022jp`, `x-ISO-2022-CN-GB`, and `x-ISO-2022-CN-CNS`
     from the runtime and release while preserving the exact 16-file JP and
     15-file CN upstream snapshots solely as repository-only GPL-plus-Classpath
     provenance. Specs now exposes 1,843 registered and 1,845 catalogued
     definitions; the full-stack canonical count is 2,095. The regenerated
     research catalog records 1,333 implemented entries, 77 codec gaps, and
     121 candidates. Seven rows become gaps: the five exact removed codecs and
     two separate catalog identities (`CP50220` and ICU
     `ISO_2022,locale=zh,version=2`) whose prior implemented status depended
     only on aliases supplied by the quarantined codecs. The focused release
     contracts pass 21/21, related runtime/count tests pass 51/51, and the
     catalog/release-metadata suite passes 70/70. A clean production compile
     passes with warnings as errors. Actual Hex unpack proves that no removed
     module, generated asset, JP/CN support document, or 31-file GPL source
     snapshot is selected; the shipped runtime inventory has exactly 1,843
     rows (SHA-256
     `68834cd3f33850d977a28177a63911cf243ccdcb9f7b33f805992ee99fb0eb97`).
278. COMPLETE OPENJDK PROVENANCE QUARANTINE RED/GREEN: a second
     expectation-first contract failed 2/2 because `x-eucJP-Open` and
     `x-MS950-HKSCS-XP` plus their merged ETF tables were still shipped under
     an unsupported independent-origin/LGPL-only provenance claim. Repository
     evidence shows that the EUC generator parsed five OpenJDK JIS maps and
     inspected/reproduced Java standard-first/Solaris-second routing, the
     `b > 0x7500` plane branch, duplicate priority, and canonical reverse
     choices. The MS950 generator parsed its two maps and inspected/reproduced
     Java HKSCS-override/MS950-fallback order plus encoded-row duplicate and
     reverse priority. No independent repository source established those
     choices. Without deciding copyrightability or offering legal advice,
     GREEN conservatively quarantines both runtime modules, importers, tests,
     tables, manifests, registrations, and packaged support matrices. All
     seven OpenJDK-derived codecs are now absent from the LGPL release; the
     four exact upstream snapshots (50 files) remain repository-only under
     their recorded GPL-plus-Classpath terms. Specs exposes 1,841 registered
     and 1,843 catalogued definitions; full-stack canonical count is 2,093.
     The regenerated research catalog records 1,331 implemented entries, 79
     codec gaps, and 121 candidates, with 200 exact closure rows and 33
     high-confidence blockers. The complete quarantine/release contracts pass
     23/23, related runtime/count tests pass 52/52, and catalog/release metadata
     passes 70/70. A clean production compile passes with warnings as errors.
     Actual Hex unpack proves that no removed module, table, manifest, support
     document, or OpenJDK source snapshot is selected. The final 1,841-row
     runtime inventory is SHA-256
     `60c8e508bce95efa238c72c854921a142b6dcf7ddec424ba6b7961666856feb3`.
279. FINAL SPECS REGRESSION RED/GREEN: a fresh isolated full-suite run first
     failed 9/955. One failure was an intentionally deferred generated
     algorithmic-differential runtime digest. A registration fixture lacked
     the newly required one-pass `encode_substitute/2` callback; that root
     failure prevented Specs from starting and deterministically caused the
     next six application-state assertions to fail. The remaining actionable
     failure showed that the UniHan telegraph property-token helper returned
     the whole malformed UTF-8 suffix instead of Core's exact one-byte invalid
     sequence. An expectation-first sibling GB3 regression then produced a
     focused 3/3 RED across the fixture, telegraph, and GB3 cases. GREEN gives
     the fixture a linear substitution callback and makes both token helpers
     retain Core's exact offset and offending byte while preserving incomplete
     suffix diagnostics and bounded scalar counting. The focused suite passes
     3/3, the complete registration ownership/rollback file passes 14/14, and
     the OpenJDK quarantine contracts pass 12/12 with warnings as errors. The
     fresh full suite now passes every functional assertion: 953/955 pass, with
     only the explicitly deferred checked-in algorithmic report digest and
     GB3 benchmark source digest awaiting final evidence regeneration. The
     malformed `/tmp` Mix-build crash dump was deleted and no zero-byte
     production source remains.
280. SPECS HEX LICENSING BOUNDARY RED/GREEN: two expectation-first release
     assertions failed 2/8 because the broad VietUnicode selector shipped the
     raw HTML snapshot and its Base64 duplicate despite no recorded
     redistribution grant, and package metadata omitted the separately
     applicable LPPL-1.0-or-later grant. GREEN selects only the normalized VNI
     CSV and digest-bearing source metadata while retaining both raw snapshots
     for repository source validation. It also ships byte-exact official LPPL
     1.0 and 1.3c texts, declares both upstream `-or-later` grants, and records
     their paths and digests in package documentation and source metadata. The
     focused license contract passes 8/8. A separate release-artifact guard
     then failed 1/1 by opening the old package tar in memory and identifying
     twelve quarantined OpenJDK runtime/table entries; after that evidence was
     captured, the stale tar was removed and the guard passed 1/1. The combined
     license, package, VNI, glyph-vector, and OT1 suites pass 47/47. Hex
     unpack selects the two normalized VNI files, both complete LPPL texts, and
     no quarantined OpenJDK artifact; the unpacked source compiles with warnings
     as errors. Hex 2.3.1 emits only its SPDX-vocabulary warning because it
     recognizes `LPPL-1.0` and `LPPL-1.3c` but not the requested accurate
     `-or-later` spellings.
281. FINAL DERIVED EVIDENCE RED/GREEN: the checked-in algorithmic differential
     first failed 1/1 because its runtime digest described the pre-remediation
     codec sources. GREEN regenerated it against ICU 78.3 and the normative
     specifications: all ten rows pass over all 1,112,064 Unicode scalars with
     zero mismatches, and the digest-bound artifact contract passes 1/1 with
     warnings as errors. The four-package support generator then replaced the
     stale 2,100-row report with the executable registry: 2,093 ASCII-case-
     unique canonical codecs, 198 GNU libiconv 1.19 extra-build codecs, 198
     shared, 1,895 Iconvex-only, zero GNU-only, and all 758/758 GNU source
     spellings resolved.
282. FINAL BENCHMARK-EVIDENCE / GC-ISOLATION RED/GREEN: the isolated OTP 27
     package run failed three of 958 tests. Two were deliberate evidence pins:
     OT1's runtime digest changed only with its corrected LPPL source metadata,
     while kGB3's runtime digest changed with its first-invalid-byte error
     normalization. GREEN rebinds those exact runtime hashes and the current
     Cork harness hash. The third failure was a warm-heap reduction flake in
     Cork's 32,768/65,536-byte identity smoke test; repeated runs varied solely
     with garbage-collection placement. Expectation-first benchmark contracts
     required isolated one-million-word workers. GREEN measures the intended
     65,536/131,072 workloads in three fresh workers and takes the median while
     retaining the strict 1.60x..2.60x scheduler-work gate. The Cork harness
     passes all twelve output, throughput, relative-latency, and scaling gates;
     focused source/evidence tests pass warning-clean.
283. OPENJDK QUARANTINE FILE-BOUNDARY RED/GREEN: the final full extension run
     failed 3/959 because four zero-byte source remnants still occupied the
     exact runtime paths that the quarantine contracts require to be absent.
     Although they defined no modules and the seven affected codecs were
     already absent from every registry, retaining those paths contradicted
     the documented source/package boundary. GREEN deletes all four remnants:
     EUC-JP-Open, MS950-HKSCS-XP, ISO-2022-JP, and ISO-2022-CN. The focused
     license, quarantine, and package matrix passes 26/26 and the complete
     Specs suite passes 959/959 with warnings as errors.
284. UNDISCLOSED OPENJDK BOM IDENTITY RED/GREEN: the Review Rigor money lane
     found three shipped codecs whose filenames, module/codec identifiers,
     documentation, tests, exact vendor spellings, and one runtime source URL
     attributed them to OpenJDK even though the release boundary disclosed
     and quarantined only seven other OpenJDK-derived runtimes. An
     expectation-first license/provenance contract failed 1/9 because no
     neutral packaged source record existed. Without deciding whether the
     small algorithmic implementations were derivative or offering legal
     advice, GREEN removes both vendor-attributed runtime files and their old
     tests, IDs, names, aliases, and URL. Three newly authored `ICONVEX-`
     signature profiles now compose the existing LGPL Core UTF-16/UTF-32
     engines with only an explicit signature/default-endian policy. Packaged
     metadata cites Unicode Standard 16.0.0, explains why the profiles are not
     Unicode-standard encoding schemes, and records the absence of imported
     vendor code or tables. The runtime count remains 1,841, its exact
     inventory is regenerated, the focused license/profile/package/UTF-8
     callback matrix passes 31/31, the pinned 1,112,064-scalar corpus round
     trips through all three profiles in one stream (2/2 focused exhaustive
     tests), and the complete Specs suite passes 960/960 with warnings as
     errors (`seed: 0`, 426.6 seconds).
285. QUARANTINE MANIFEST DENYLIST RED/GREEN: the independent Codex lane proved
     that the prior broad `priv/*.etf` and `priv/tables` selectors would have
     selected all eight stale OpenJDK runtime assets found in the frozen tree.
     Although Cycle 284 deleted those assets, an expectation-first package
     contract still failed 1/1 because the effective Hex exclusion rules did
     not reject a reintroduced top-level manifest. GREEN adds one explicit
     denylist for OpenJDK ETF paths at both selected depths, including
     AppleDouble resource-fork names, while preserving the ICU archive-shard
     exclusion. The focused contract passes 1/1. A real Hex unpack built with
     two temporary adversarial fixtures then excluded both paths; removing the
     fixtures and rebuilding leaves zero OpenJDK paths in the effective
     manifest.
286. SUPPORT-DOCUMENT AUTHORITY RED/GREEN: an expectation-first package
     contract failed 1/1 because the README incorrectly presented the family
     summary as the exhaustive per-name authority and omitted four of the five
     package inventory regeneration commands. The RED log SHA-256 is
     `f910ee7623b0ee71b29de39e842dfc420c4cdf3885e5381040e90fb38ef3bbc4`.
     GREEN identifies `SUPPORTED_CODEC_INVENTORY.csv` as the exact 1,841-codec
     canonical/alias/module/statefulness snapshot, limits
     `SUPPORTED_ENCODINGS.md` to family and mapping-count summaries, names all
     five inventory generators, and narrows the RFC importer warning to only
     its generated RFC section. The complete 14-test package-contract file
     passes from a fresh build; its log SHA-256 is
     `ef0a53a72c804be8e851d5d0952b87a388a5ee4cc17cc314922037dcdb1bef0e`.
287. MEASURED AGGREGATE EVIDENCE RED/GREEN: expectation-first contracts failed
     2/3 because the aggregate called a same-codec Iconvex alias comparison an
     exhaustive GNU equivalence and rendered an unchecked 1,050 archive count.
     They also required both Specs documents to identify the runtime-derived
     ownership proof. The RED log SHA-256 is
     `f0b99ee37e619fa82dfd21f797996f79c86f5e1cc4a0f7e0222effe516008b4d`.
     GREEN honestly labels the 25×256 checks as internal Iconvex alias routing
     and binds the independent GNU claim to the existing 198/198, zero-mismatch,
     zero-performance-failure exhaustive report and its SHA-256. The generator
     now derives archive IDs from `Iconvex.Specs.ICUArchive.encodings/0`, scans
     all live provider ownership tokens, requires the exact three-provider
     union to equal the manifest, and verifies every owned release table before
     rendering the measured 1,050 total and 350/350/350 membership.
     A second expectation-first docs test failed 1/1 because all four package
     READMEs linked outside their Hex artifacts; its RED log SHA-256 is
     `c712fcc3f66b2d2411bfd0088026e80140e35b4fc9f11f8fd2101118107223e5`.
     GREEN names the workspace-relative aggregate as code instead of an ExDoc
     link. The focused suite passes 3/3, the affected Specs matrix passes 21/21,
     Integration passes 25/25, and Core ExDoc is warning-clean. Two independent
     aggregate generations exactly match the checked report at SHA-256
     `a4b8ef74ab4074f266f635b9d0af0aed790ca4138ea2c0918c7f302a780074c9`.
288. GNU EXTRA-ENCODINGS EVIDENCE CONJUNCTION RED/GREEN: an executable
     expectation-first contract supplied the real aggregate generator with a
     temporary exhaustive report that retained the exact 198/198 pass count,
     zero mismatches, zero performance failures, and GNU libiconv 1.19
     reference while removing only the required `--enable-extra-encodings`
     provenance marker. RED failed 1/4 because the old disjunction ignored the
     injected report and emitted a 2,093-codec aggregate. GREEN adds an
     isolated evidence-path override and requires both the exact parsed fields
     and the provenance marker before report emission. The focused generator
     contract passes 4/4 and the invalid-evidence run exits nonzero without
     creating an output report.
289. PACKAGED CORE LINK RED/GREEN: an expectation-first package contract
     required the independently published README to link Iconvex through its
     durable Hex package page and reject the checkout-only `../iconvex` target.
     RED ran 15 tests with the one intended failure. GREEN replaces only that
     link with `https://hex.pm/packages/iconvex`; the same focused file passes
     15/15.
290. BOCU-1 ATOMIC RECOVERY RED/GREEN: the final independent cross-model lane
     found that strict BOCU-1 correctly reported the invalid pair
     `D0 00`, and native discard removed it atomically, but callback and byte
     substitution recovery consumed only `D0` and decoded the illegal trail
     as U+0000. The expectation-first public conversion test failed 1/8 with
     `<<0, 65>>` instead of `"A"`; its RED log SHA-256 is
     `8e105b4a1b44ec04c3c18d3d2eae258b30aab4e40956e3d11eaf4b48d05d4757`.
     GREEN declares the codec's error-consumption width as the complete strict
     error sequence, preserving native reset semantics. Callback discard now
     emits `"A"` once, and byte substitution emits `"<d0><00>A"`; the focused
     file passes 8/8. Its GREEN log SHA-256 is
     `44cf537a71b46584d3d65d67a4c113c1d9b5dda6f0f838912a55991cb3ecd7bc`.
291. GENERATED TABLE ATOMIC EOF RECOVERY RED/GREEN: the final registry sweep
     found 41 two-byte terminal prefixes whose generated external wrappers
     reported one complete `:incomplete_sequence` and whose native discard
     removed that unit, but public callback recovery consumed one byte at a
     time. Callback replacement therefore emitted `"??"` or leaked a decoded
     ASCII suffix such as `"?0"`. An expectation-first matrix pins every
     affected glibc-charmap, ICU archive, and ICU multibyte wrapper; RED failed
     1/2 with `"??"` instead of one `"?"`. Its log SHA-256 is
     `6c268fd9f0db88844f00e91ab5cbf530283deaa89ba1cd2de921f906951ec792`.
     GREEN makes all three generated wrapper families delegate recovery width
     to the same table engine that defines native discard. Each complete
     terminal unit now produces exactly one callback event; callback discard,
     replacement, and per-byte substitution retain their distinct contracts.
     The exact 41-case matrix passes 2/2; its log SHA-256 is
     `c811668db00b95f11c9749dae3c64cd957b35db2568f3a1c64731c21d71c1602`.
292. ALGORITHMIC UNICODE SUBSTITUTION RED/GREEN: a public UCS-4BE conversion
     matrix proved that ten algorithmic codecs and all six ICU Unicode-variant
     wrappers exported `encode_substitute/2` but ignored its replacement
     callback. Every target returned an unrepresentable-character error for an
     isolated surrogate (or U+110000 for WTF-8). RED failed 16/16; its log
     SHA-256 is
     `235dffd9cb8537e811d8d3ef04adeacef19e32fbaca27f4752a2aa5c71ba2c20`.
     GREEN performs scalar representability checks, transforms failures with
     the caller's replacement, and invokes the target encoder once over the
     complete transformed stream. Exact output matches a strict whole-message
     encode, so state and UTF-8/UTF-16 signatures occur once. The focused
     public matrix passes 16/16; its log SHA-256 is
     `380ae00b2256f523eb3920491eb47542cbf6dd20bf04a70059fc0211b1ba490b`.
293. STATEFUL SIGNATURE / ATOMIC SOURCE RECOVERY RED/GREEN: an
     expectation-first public conversion matrix failed 2/2. UTF-8-SIG and all
     three `ICONVEX-` UTF-16/UTF-32 signature profiles restarted suffixes as
     new messages after an invalid unit, which could consume an embedded
     U+FEFF or lose the UTF-16 endian selected by the initial signature. IMAP
     UTF-7 and SCSU callback recovery also consumed only the first byte of
     strict multi-byte errors that their native discard decoders remove as one
     unit. The RED log SHA-256 is
     `69234480fdcd5c2b8fdb7de1154a9638b49b85bf39ef54da72671a206afb959c`.
     GREEN adds codec-owned incremental decoder state for beginning-of-stream,
     fixed endian, and SCSU window state; complete strict error consumption for
     IMAP UTF-7 and SCSU; and matching incremental encoder callbacks. One-shot
     and every-source-split callback discard, callback replacement, and
     per-byte substitution now match native framing for all six codecs. The
     focused matrix passes 2/2; its GREEN log SHA-256 is
     `b872f21a3936e4cce75ca9a6ffd114c478a2eb5d6beeea65fe44b6cf074ec49d`.
     The affected regression matrix passes 39/39.
294. SOURCE-BOUND ALGORITHMIC EVIDENCE RED/GREEN: the deterministic full
     Specs gate failed exactly 1/969 because the checked exhaustive report's
     runtime SHA-256 still described the pre-recovery algorithmic sources.
     The RED gate log SHA-256 is
     `566d04966a2c006a01f484407b6d1acf2c8d9297df87fe497043f188beb26425`.
     GREEN reruns `tools/exhaustive_algorithmic_differential.exs` over all
     1,112,064 Unicode scalar values against the exact final sources and ICU
     78.3. All 10/10 codec rows pass with zero mismatches; the runtime digest
     is `30f5c209155484fe0ff79fe250a07998efcea13dbee6e02d5f70afaad5fe571d`
     and the regenerated report SHA-256 is
     `53818b81d6c8ded8d18d9a87e001a137c45a53245327d4d70aa015a10fdfc11d`.
     The source-binding contract passes 1/1; its GREEN log SHA-256 is
     `b11fe21d5e2a9283c1575b7af23628d67de90dd72deffa12d18b9d8959c26f55`.
295. FINAL SOURCE-BOUND SHIP GATE RED/GREEN: the first complete deterministic
     gate ran 987 tests and failed exactly five artifact contracts, with all
     runtime behavior otherwise green. Four forbidden OpenJDK runtime paths
     were zero-byte touch artifacts with the same timestamp; existing LGPL
     quarantine contracts require their absence. The codec inventory still
     described the pre-Cycle-293 stateful flags, and the workspace aggregate
     still pinned the preceding 198-codec GNU report SHA-256. The RED log
     SHA-256 is
     `5a394fc400186ed6dfa55361d3dd9d8e53ee2b7d3e0f36c44d29a5e4723ab32a`.
     GREEN deletes only the four empty denied artifacts, regenerates the exact
     1,841-row inventory at SHA-256
     `5bc5cf6348db9435a35bea01ba52e3a59e9199a62d14de4f8c377c104b354d47`,
     and regenerates the 2,093-codec workspace aggregate at SHA-256
     `36c7d7cd83163990b6a1e39c0e233c9c0332fd55c834b68dd9713a3bb0e2823f`.
     The five affected contract files pass 34/34. From a fresh physical build
     path, formatting and forced production compilation with warnings as
     errors pass; the full deterministic gate passes 987/987 in 349.0 seconds.
     Its GREEN log SHA-256 is
     `c96de7c84ca10b595ddbabf45f9811c95907ed5516c5ff809be34222903d32b3`.
