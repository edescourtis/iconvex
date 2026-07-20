# TDD log

GSM 03.38 was developed RED/GREEN.

1. RED: 7 contract tests, 7 failures. The missing API, table inventory,
   independent pairs, malformed-input behavior, 39 names, and registration were
   all specified before implementation.
2. GREEN: the initial implementation passed all 7 contract tests.
3. RED: `valid_pairs/0` was specified; 14 tests ran with the new contract as the
   sole failure.
4. GREEN: all 14 tests passed with the complete 182-pair inventory.
5. Conformance GREEN: exhaustive cell tests, ICU differential fixture, wrapper
   wiring, lifecycle, UTF-8 errors, and linear discard coverage brought the
   suite to 17 tests with 0 failures.
6. Performance refactors were accepted only while the full suite remained
   GREEN; the benchmark retains the displaced implementations as A/B baselines.
7. RED/GREEN cycles added failing vectors first for SMS septet packing, TBCD,
   and all three UCS2 alpha-identifier forms. That suite had 29 tests.
8. RED: six ITA2 tests failed because the codec, state machine, packing API,
   exhaustive tables, and aliases did not exist. GREEN: all six passed; the
   package contract then intentionally remained RED until ITA2 was added to
   the support and conformance records.
9. RED: six CCIR 476 tests and the package contract failed before the 32
   traffic signals, service signals, seven-bit packing, FEC inversion, and
   SITOR/NAVTEX registration existed.
10. GREEN: implemented every M.476-5 table value, classified all 128 possible
    input units, and reused the exhaustively tested ITA2 state machine.
11. RED: six AIS6 tests and the package contract failed before Table 45,
    six-bit packing, IEC 61162 armoring/fill-bit validation, and aliases
    existed.
12. GREEN: implemented and exhaustively tested all 64 Table 45 values, strict
    malformed input, exact field packing, both armor ranges, and zero-fill
    validation; the focused six-test suite passed before documentation was
    updated to restore the full package contract.
13. RED: six ITU-T S.2 tests failed before its two-mode case state machine,
    single-capital behavior, three-capital lock optimization, initialization,
    and aliases existed.
14. GREEN: implemented the official S.2 state diagram and passed isolated,
    locked, figure-transition, initialization, full-alphabet, malformed-input,
    and registration vectors.
15. RED: the package contract had two failures when TBCD and SIM/USIM alpha
    identifiers were required as registered Iconvex codecs rather than helper
    APIs only.
16. GREEN: added strict codec adapters, direct UTF-8 paths, discard behavior,
    aliases, lifecycle registration, and end-to-end `Iconvex.convert/4` vectors;
    the focused helper/contract suite passed 12 tests before documentation
    restored the package-wide support assertion.
17. RED/GREEN: ITA1 began as six failing contracts for its complete 32-row
    polarity table, two state tables, national/non-text holes, all-octet
    classification, aliases, and five-bit packing. The complete table port made
    those six tests GREEN.
18. RED/GREEN: US-TTY and MTK-2 each began with six missing-codec failures.
    GREEN required every source-table cell, every register transition, complete
    repertoire round trips, high-bit rejection/discard, aliases, and pinned
    source identities.
19. RED/GREEN: ITA3 and ITA4 began with five contracts apiece. GREEN required
    all 32 traffic conversions, classification of all 256 octets, preservation
    of the ITA2 state machine, exclusion of service signals, and aliases.
20. RED/GREEN: T.50/IA5 began with six contracts for all 128 positions, the
    complete invalid high-bit domain, seven-bit packing, names, source pin, and
    UTF-8 boundaries. The exact IRV implementation made all six GREEN.
21. RED/GREEN: International Morse began with seven contracts for all 51
    graphic assignments, six procedural signals, explicit serialization,
    token offsets, discard/noninjective behavior, aliases, and the official
    source pin. The completed M.1677 implementation made all seven GREEN.
22. RED: the strengthened package contract exposed that seven GREEN codecs were
    missing from the published 45-codec list; a second failure required a
    nonexistent generated runtime inventory.
23. GREEN: the package now generates a 52-row canonical/alias/module/stateful
    inventory directly from runtime modules. Tests compare every field and the
    documentation names every registered canonical codec, preventing this class
    of drift from recurring.
24. Performance RED/GREEN: a retained map-lookup baseline showed the generic
    US-TTY/MTK-2 state engine lagging the specialized ITA2 loop. The optimized
    loop holds active decode/encode tables across ordinary characters and uses a
    compile-time cross-register index; all 12 focused contracts remained GREEN.
25. Alternating 12-run medians measured +46.3%/+20.1% US-TTY encode/decode and
    +34.3%/+14.7% MTK-2 encode/decode. The displaced implementation remains in
    `bench/five_unit_shift_benchmark.exs` as the reproducible A/B oracle.
26. RED: four packed-inventory contracts failed before a discoverable unified
    facade existed. GREEN: 49 profiles cover every fixed-width registered codec,
    both bit orders, exact standard-order metadata, the GSM published vector,
    runtime exclusions, and a generated CSV; 4 tests pass.
27. Performance RED: profile lookup rebuilt and sorted all 49 metadata maps on
    every message (~159 ms per 10,000 lookups). GREEN: immutable profiles and
    name/module indexes are cached in `persistent_term`; the focused contracts
    remain GREEN.
28. A/B GREEN: on 65,540 septets, the bounded streaming implementation measured
    173.5× faster packing and 59.6× faster unpacking than the retained
    whole-message GSM integer implementation. The benchmark executes both paths
    and verifies every returned result.
29. Review RED/GREEN: 16 focused tests initially produced 9 failures covering
    malformed SIM/TBCD fast callbacks, compressed-surrogate safety, strict GSM
    option validation, octet-atomic TBCD discard, UCS2 padding boundaries,
    ICU-pinned ESC fallbacks, packed-order errors, exhaustive extension cells,
    and application registration ownership. The focused suite then passed
    16/16 and the full package passed 108/108.
30. Registry-recovery RED/GREEN: the pre-fix worker-crash reproduction lost
    registrations while `:iconvex_telecom` remained started. The inherited
    registry now preserves GSM0338, TBCD, every other Telecom entry, and their
    exact application-owned tokens. The regression stops Telecom after recovery
    and proves token cleanup removes both named codecs; the complete focused
    review-regression file passes 13/13.
31. Late-startup rollback RED/GREEN: a deterministic conflict on the final
    SIM-alpha codec was specified before changing production. The first focused
    run was RED (14 tests, 1 failure) because the assertion omitted OTP's
    application-start error envelope. GREEN normalizes that envelope and proves all
    51 earlier codec modules and every one of their names are removed, the
    preexisting conflicting registration and ownership token survive, and a
    clean 52-codec restart succeeds. The existing ownership rollback needed no
    production change; the focused file passes 14/14.
32. Consumer-artifact RED/GREEN: the release audit and a new package contract
    reproduced that `test`, `bench`, and `tools` were selected for Hex. The
    corrected manifest keeps runtime assets, source/license notices, generated
    inventories, conformance evidence, and public documentation while leaving
    development corpora in the repository.
33. Managed-set RED/GREEN: cross-package startup first failed because Specs and
    Extras had retained overlapping names. Telecom now publishes all 52 codecs
    in one atomic managed set. A registry-repair RED also caught a transient
    missing `GSM0338`; repair now republishes complete name indexes before
    pruning stale rows. The full-stack harness passes all six extension start
    orders with 1,990 unique canonical names, and Telecom's complete suite
    passes 115/115 with warnings as errors.
34. Release-cardinality documentation RED/GREEN: the executable contract was
    added before changing prose and failed 1/7 on the stale 1,995 full-stack
    count. Current release prose now states the derived 2,005 cardinality; the
    package contract passes 7/7 and the complete suite passes 116/116 with
    warnings as errors.
35. Telecom-source provenance RED/GREEN: the two-contract suite was written
    before `SOURCE_PROVENANCE.md` or its package selector and failed 2/2
    (`seed: 0`). GREEN inventories every retained `tmp/` artifact by exact
    SHA-256, official parent or retrieval URL, ownership, and derived-file
    relationship. One 245-byte rejected-request HTML response masquerading as
    `itu-r-m1677-1.pdf` was removed. The retained S.13 PDF is correctly
    identified as the 1976 CCITT Orange Book despite its historical local
    filename. All upstream evidence is repository-only, no license is invented,
    and Hex packaging excludes `tmp/`. The focused suite passes 2/2 in 0.1 s;
    the complete package passes 118/118 with warnings as errors. The rebuilt
    Hex archive was inspected and contains no `tmp/` member.
36. IBM Transcode RED: two new test files were committed before runtime code,
    source assets, inventories, or the benchmark. The focused run produced
    14 tests and 14 failures: both modules and registrations were absent, both
    normalized source tables and metadata were absent, no packed profiles or
    inventory rows existed, and the benchmark script did not exist.
37. IBM Transcode GREEN: separate GA27-3005-3 and GA27-3004-2 codecs implement
    all 64 cells while preserving their sole `0x0C` disagreement. The suite
    classifies all 256 octets for both profiles, checks every Unicode scalar,
    exercises strict/discard/substitute/direct UTF-8 paths, verifies every
    source and UTF-8 stream split plus absolute error offsets, and pins complete
    MSB/LSB vectors, all packed tails, invalid lengths, nonzero padding, and
    transport types. The focused suite passes 14/14.
38. Source/package GREEN: both primary PDF URLs, sizes, SHA-256 values, exact
    table pages, normalized 64-row CSV digests, and low-order-first semantics
    are pinned. Only the original CSV facts and metadata are packaged; raw IBM
    PDFs remain excluded. Runtime inventories now contain 54 codecs and 51
    packed profiles (4 six-bit).
39. Performance GREEN: two production runs measured 14.792–49.251 MiB/s over
    twelve codec/transport paths. Native/reference latency was 0.704×–0.890×,
    and all four deterministic reduction-scaling gates were 1.881×–1.890×.
    The executable benchmark enforces the 30× ceiling and linear scaling.
40. Packed-name/benchmark review RED: suffix-resolution, transport-tag, benchmark,
    and run-provenance contracts were added before fixes. The focused 8-test run
    failed exactly 4 tests: packed names were unresolved, all mistagged LSB
    containers decoded, packed benchmark rows had no comparison, and the record
    contradicted itself about two versus three runs.
41. Packed-name/benchmark GREEN: all 102 canonical packed names and 220 packed
    alias forms now select their named order; explicit conflicts and all 51
    mistagged LSB profiles return `:bit_order_mismatch`. Independent bit-buffer
    references call no native packed API, compare exact output for both profiles
    and all six operations, enforce 12 relative ceilings, and enforce 12 linear
    reduction gates. Two production runs measured 13.934–42.258 MiB/s,
    0.439×–0.891× native/reference latency, and 1.685×–1.979× scaling. The
    focused suite passes 8/8, the full package passes 135/135 with warnings as
    errors, and a forced production compile passes with warnings as errors.
42. ADVERSARIAL PACKED/REFERENCE RED/GREEN: four semantic packed-decode vectors
    were added first at a nonzero unit index for ITA1, ITA3, ITA4, and CCIR476
    in both bit orders. RED returned unpacked byte offset 2 and an octet
    fragment; GREEN translates it to the physical `unit_index * unit_bits`
    offset and preserves exact-width MSB or integer LSB fragments. A separate
    benchmark-source RED rejected the self-derived `codec.table()` oracle.
    GREEN digest-validates and parses both packaged IBM 64-row CSVs, builds the
    decode/encode reference independently, and retains the independent packed
    bit-buffer paths. The focused suite passes 9/9.
43. Full-stack release-cardinality RED/GREEN: the executable package contract
    was changed first from 2,064 to the regenerated 2,100-codec registry and
    failed 1/7 against both stale release documents. README and changelog now
    state 2,100; the focused contract passes 7/7.
44. GSM TP-UDHL DOMAIN RED/GREEN: an adversarial boundary regression first
    failed 1/1 because the UDH alignment helper accepted 256 even though
    TP-UDHL is one octet. GREEN limits the documented TP-UDHL input to 0..255;
    255 remains aligned correctly while negative, 256, and noninteger values
    return the existing typed `:invalid_udh_octets` error. The focused
    regression passes 1/1 with warnings as errors.
45. REQUIRED EXTERNAL SUBSTITUTION CALLBACK RECURRENCE RED/GREEN: after Core
    made the linear `encode_substitute/2` path an explicit external-codec
    contract, the complete Telecom RED failed 1/137 because its late-startup
    conflict fixture still implemented the former callback set. GREEN gives
    that test-only codec the required callback without changing the conflict
    scenario. The focused lifecycle run passes 2/2 and the complete package
    passes 137/137 with warnings as errors.
46. PROVENANCE-QUARANTINE RELEASE CARDINALITY RED/GREEN: the executable release
    contract changed first and failed exactly 1/7 while README and changelog
    still claimed the former 2,100-codec registry. GREEN records the current
    2,093 unique canonical names after seven Specs codecs were quarantined; the
    focused package contract passes 7/7 with warnings as errors.
47. REDUCTION-HARNESS GC ISOLATION RED/GREEN: the final OTP 27 package run
    failed 1/137 when one IBM 2780 decode comparison charged an ordinary-heap
    garbage collection to only the 20,000-unit side and reported 1.579x.
    Independent measurement proved the same 20,000/40,000 path costs
    25,438/50,601 reductions, or 2.002x after fixed overhead, in a large-heap
    worker. An expectation-first source contract then failed until every
    reduction measurement ran in a monitored fresh one-million-word heap.
    GREEN preserves the two-sided 1.60x..2.60x algorithmic gate, output parity,
    and 30x native/reference ceiling. The focused benchmark test passes 1/1;
    two complete local runs report 1.982x..2.050x across all twelve paths.
48. SIM ALPHA FRAMING RECOVERY RED/GREEN: the exact `80 D8 00 00 41`
    reproducer first failed native discard by returning no suffix, while every
    Stream split was rejected as unsupported; the captured 2/2 RED log SHA-256
    is `8344c8dc0b2639bf2e9f7fffcf9b098e469bacf8f7b7468b09f98727d26ab7ce`.
    GREEN implements a bounded native state machine for GSM, `0x80`, `0x81`,
    and `0x82` fields. Recovery consumes the complete invalid UCS-2 unit,
    retains the selected frame, advances compressed payload counters, preserves
    trailing GSM record padding, and buffers target encoding until the final
    chunk. Discard keeps `A`; per-byte substitution yields `<d8><00>A`; callback
    replacement yields `?A` at offset 1 for every split. A supplemental
    `0x82` surrogate and all four valid forms prove state and split invariance.
    The focused suite passes 4/4, the SIM/review/package selection passes 30/30,
    and the complete package passes 141/141 with warnings as errors; full-run
    log SHA-256 is
    `f3579438107eb74c54dd4775e48c8b23ead28eecea3308cb30034f7c9b516e60`.
49. SIM FIRST-ERROR ORDER RED/GREEN: `80 D8 00 00` contains an invalid
    surrogate unit before its odd terminal byte. Public one-shot decoding first
    returned only the later truncation, while every Stream split correctly
    returned the surrogate at byte offset 1. The expectation-first focused run
    failed 2/7; its RED log SHA-256 is
    `5d31c74403f9f81a04d436e7ad4fb3aabc3600c2b60cd46f13c9e1440b54aa11`.
    GREEN scans complete UCS-2 units before classifying a trailing single byte,
    so the low-level API, codec fast path, one-shot conversion, and all five
    splits return the same invalid sequence. The focused run passes 7/7; its
    GREEN log SHA-256 is
    `d6d97d5714a0cf310aab1834496a641d14d87c4bd0f9cae6455100754d89bf97`.
50. SIM DECLARED-PAYLOAD EOF RED/GREEN: counted `0x81` and `0x82` records with
    one valid `A` byte and one declared-but-absent terminal payload byte first
    retained `A` in native discard but raised at every Stream split. A separate
    strict-parity RED showed one-shot errors at offset 0 with the full record
    while incremental decoding reported physical EOF with an empty sequence.
    The discard and strict RED log SHA-256 values are
    `29ee9c545777f250f89b31221bb8f2237f788b554d66bb83696347f97abe6b86`
    and
    `dd051bbd7a79366f83bb06e290b1397ef958d280e687635cd69a76d8eaa958f7`.
    GREEN retains the valid prefix only for plain discard and normalizes both
    complete compressed headers to the exact physical EOF coordinate.
    Strict, substitution, and callback policies remain incomplete errors with
    no callback for an absent byte. The focused run passes 9/9; its GREEN log
    SHA-256 is
    `8ad404dd60a5429b9ac7679b602ee4f86a7b162b68df5d5f1a0601f4878f6eb0`.
51. SIM COMPRESSED-PREFIX PARITY RED/GREEN: a bounded matrix first compared all
    25 unique proper prefixes of six representative `0x81`/`0x82` records under
    strict, discard, byte-substitution, and callback policies at every byte
    split. It includes every partial header, valid payloads, GSM extensions,
    surrogate and overflow bases, exact errors, outputs, and callback events.
    RED failed 2/2 because `82 02 D8 00 80` reported the later declared-payload
    EOF one-shot but the earlier invalid U+D800 unit in Stream. The RED log
    SHA-256 is
    `8d53977c59373d0b09532f7398dc1f449088620d8830d155f522f6c06ef3bf8f`.
    GREEN decodes every physically present compressed payload byte before
    classifying a later declared EOF. A trailing GSM escape with more declared
    payload is the physical incomplete frame rather than a local-offset leak.
    The final suite pins the five partial-header frames explicitly and passes
    4/4; its GREEN log SHA-256 is
    `938dcd11c5e826a8f0a5a7938674da317a4eae1219547fa23b97c62dce2f5009`.
52. SIM COMPLETE-RECORD BOUNDS RED/GREEN: expectation-first tests exposed the
    unbounded target list, unrestricted source length, and missing public
    record limit. The clean RED failed 6/8; its log SHA-256 is
    `bf39de1d6d39d19cefb05b528c56a1c5e40c7f7252eb9ce085c0a017029dc58d`.
    GREEN enforces the ETSI TS 102 221 section 8.2 255-octet linear-fixed-record
    boundary in the low-level helper, one-shot codec, and Stream paths. Decoder
    state records consumed octets separately from pending bytes and proves
    `total + pending <= 255` at every split of maximum GSM, `0x80`, `0x81`, and
    `0x82` records. Strict overflow reports byte 255; discard, substitution, and
    callback recovery remain split-invariant at stable offsets 255 and 256.
    Earlier GSM, surrogate, compressed trailing-escape, and intrinsic target
    errors retain priority. Target state and every temporary admission candidate
    are capped at 255 code points. Exact Stream admission has a fixed
    worst-case quadratic cost inside that protocol cap; one-shot strict encode
    uses a bounded prefix and binary search. A production micro-run measured a
    maximum 255-character strict encode at 375.92 microseconds and 3,267.52
    reductions, while the retained 255-code-point target state occupied 510
    flat words. The final focused suite passes 9/9 with log SHA-256
    `90f393f0320eae324189907b7c3836e4a64d4dde52ae50bb2c438bba5bebfd44`;
    the complete package passes 159/159 with warnings as errors and log SHA-256
    `59ab5269a981ebf18836ea66f151aa1507fcc72cf28627ea0acc873ee8e5ca67`.
    A forced production compile with warnings as errors passes with log SHA-256
    `4a38a51f5805f9738c367388016a161bee23e67c8781ce932db416e4fe79b368`.
53. SIM INITIAL-GSM RECOVERY COMMIT RED/GREEN: an adversarial audit supplied
    `83 80 00 41`. Strict decoding correctly rejected byte 0, but discard left
    the decoder in `:start`; byte 1 was therefore reselected as a `0x80` UCS2
    header and the result was `A` instead of GSM-mode `@A`. Expectation-first
    tests covered later `0x80`, `0x81`, and `0x82` octets under strict,
    discard, byte-substitution, callback, and every Stream split. A separate
    256-byte record proves the same transition through the 255-byte admission
    boundary, including first-error ordering and callback offsets 0, 1, and
    255. The focused RED ran 11 tests with 2 failures; its test-source SHA-256
    before production changed was
    `3b520c45bc1e0363251fa1a0225163e87326da36808a946c9e89f08136d8aaff`.
    GREEN commits `:start` to `:gsm` only after recovery consumes a physical
    invalid default-alphabet unit. Framed UCS2 and structural-EOF paths retain
    their existing states and error kinds. The focused run passes 11/11, the
    complete package passes 161/161, production compilation is warning-clean,
    and formatting passes. Final source/test SHA-256 values are
    `d8b8cd490e3c9b6f496a581366c311621f11446a14ce9bb60ce41681e55e5690`
    and
    `3528f59b85e10559622913c496d54a4c75fcada0283c7fe899fb0e73a1c05829`.
54. PACKAGED CORE LINK RED/GREEN: an expectation-first package contract
    required the independently published README to link Iconvex through its
    durable Hex package page and reject the checkout-only `../iconvex` target.
    RED ran 8 tests with the one intended failure. GREEN replaces only that
    link with `https://hex.pm/packages/iconvex`; the same focused file passes
    8/8.
55. MORSE TOKEN RECOVERY RED/GREEN: an expectation-first public recovery test
    supplied the invalid six-dot signal `......`. Native discard rejected the
    complete token, while callback discard consumed only its first octet and
    leaked the remaining five dots as the valid digit `5`. The focused RED ran
    8 tests with the one intended failure; its test-source SHA-256 was
    `707e8c466f768beefb14672867568a99f31e9e5219fb5b93bb8cf586a4f45f11`.
    GREEN gives Morse invalid-sequence recovery the exact reported token width.
    Callback discard/replacement now emits one event and consumes all six
    octets, while byte substitution emits six `<2e>` fragments. The focused
    suite passes 8/8 and the complete package passes 163/163 with warnings as
    errors. Production compilation is warning-clean and formatting passes; the
    final Morse source SHA-256 is
    `ed09cf72a92e0f4ffc0272ae59483db3ceecffde3c38cd66456c55c08a2322e0`.
