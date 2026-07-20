# UTF-8-MAC / HFS Plus source metadata

This repository-only source set pins Apple `libiconv-115.100.1` at revision `f96c1fcdbb308374e39290676b5fea40a3859d17`, Apple's archived TN1150 table, and Unicode 3.2 normalization data. The upstream files are generator/conformance evidence and are excluded from Hex. Each artifact retains its own upstream ownership and terms; none is relicensed as LGPL.

The generator reads the effective decomposition keys and exact precomposition pairs from the BSD-2-Clause `citrus_utf8mac.c`, then combines those facts with Unicode 3.2 decomposition data. The resulting generated runtime manifest, `priv/utf8_mac_manifest.etf`, is shipped in Hex. The complete BSD-2-Clause attribution for that shipped derivation is retained in `../../../LICENSE.BSD-2-CLAUSE`. The native Elixir control flow remains LGPL-2.1-or-later; this statement does not relicense the generated tables.

The retained `libiconv_test.c` expressly invokes APSL-1.0. The exact Apple Public Source License 1.0 text is in `LICENSE.APSL-1.0`, SHA-256 `54702bc17c8ac3601637577c8f92e5992be79110df72c7ff6fe20d75d4df2745`; its canonical SPDX text source is <https://github.com/spdx/license-list-data/blob/main/text/APSL-1.0.txt>. The source header's historical Apple URL is retained verbatim but no longer resolves.

| Artifact | Official upstream | SHA-256 | License/ownership |
|---|---|---|---|
| `libiconv_test.c` | <https://github.com/apple-oss-distributions/libiconv/blob/f96c1fcdbb308374e39290676b5fea40a3859d17/tests/libiconv/libiconv_test.c> | `67f8a968f8c17dbef0338aa7c3e909139dbc8bb5187a24b62552a0b4067cb1c6` | Apple Inc.; APSL-1.0 as stated in header |
| `citrus_utf8mac.c` | <https://github.com/apple-oss-distributions/libiconv/blob/f96c1fcdbb308374e39290676b5fea40a3859d17/libiconv_modules/UTF8MAC/citrus_utf8mac.c> | `2a018de7f0ce2b641bfae97ff4c2c8cf5e12789239d7d77b3f11ec63e224936d` | BSD-2-Clause; complete terms embedded in source header; derived Apple components are noted in-file |
| `tn1150table.html` | <https://developer.apple.com/library/archive/technotes/tn/tn1150table.html> | `67c7f9572752693800df3cd79974b59374e36b2240bc7f31a14192efa57a5e03` | Copyright 2018 Apple Inc. All Rights Reserved; repository-only documentation evidence |
| `CompositionExclusions-3.2.0.txt` | <https://www.unicode.org/Public/3.2-Update/CompositionExclusions-3.2.0.txt> | `1d3a450d0f39902710df4972ac4a60ec31fbcb54ffd4d53cd812fc1200c732cb` | Unicode License V3; exact package text at `../../../LICENSE.UNICODE` |
| `NormalizationTest-3.2.0.txt` | <https://www.unicode.org/Public/3.2-Update/NormalizationTest-3.2.0.txt> | `c4513869bb7098d19838be4a1fd5d760843c5804bfe03bd6bbb20623ceb6e57d` | Unicode License V3; exact package text at `../../../LICENSE.UNICODE` |
| `UnicodeData-3.2.0.txt` | <https://www.unicode.org/Public/3.2-Update/UnicodeData-3.2.0.txt> | `5e444028b6e76d96f9dc509609c5e3222bf609056f35e5fcde7e6fb8a58cd446` | Unicode License V3; exact package text at `../../../LICENSE.UNICODE` |
| `LICENSE.APSL-1.0` | <https://github.com/spdx/license-list-data/blob/main/text/APSL-1.0.txt> | `54702bc17c8ac3601637577c8f92e5992be79110df72c7ff6fe20d75d4df2745` | Exact APSL-1.0 text retained for `libiconv_test.c` |
