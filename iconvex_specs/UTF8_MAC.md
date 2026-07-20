# UTF-8-MAC / HFS Plus normalization codec

This codec implements Apple's frozen HFS Plus canonical decomposition,
using the exact tables in Apple libiconv libiconv-115.100.1 at commit
`f96c1fcdbb308374e39290676b5fea40a3859d17` and Unicode 3.2 normalization data. Characters
absent from Apple's implementation table remain unchanged; Hangul
syllables are handled by the normative algorithm. Like Apple's module,
decoding greedily precomposes adjacent supported pairs and retains
Unicode composition exclusions.

- Current Apple implementation decomposition rows: **970**
- Historical TN1150 HTML rows: **942**
- Unicode 3.2 additions over that historical table: **44**
- Unicode 3.2 removals from that historical table: **16**
- Algorithmic Hangul syllables: **11,172**
- Exact Apple implementation composition pairs: **917**
- Apple-only versus Unicode-derived reverse pairs: **44**
- Unicode-derived-only versus Apple table: **4**
- Nonzero combining-class entries: **327**
- Unicode composition exclusions: **81**
- Source-set SHA-256: `7601e4829c3adc8f818a3172284c4e305264e72e4ce9f1376e810d6f48dd6817`

The upstream files below remain repository-only. The generated Hex runtime
manifest contains decomposition keys and exact precomposition pairs parsed
from the BSD-2-Clause C tables plus Unicode 3.2 data; the complete attribution
ships as `LICENSE.BSD-2-CLAUSE`.

| Pinned source | Origin | SHA-256 |
|---|---|---|
| `CompositionExclusions-3.2.0.txt` | [official source](https://www.unicode.org/Public/3.2-Update/CompositionExclusions-3.2.0.txt) | `1d3a450d0f39902710df4972ac4a60ec31fbcb54ffd4d53cd812fc1200c732cb` |
| `NormalizationTest-3.2.0.txt` | [official source](https://www.unicode.org/Public/3.2-Update/NormalizationTest-3.2.0.txt) | `c4513869bb7098d19838be4a1fd5d760843c5804bfe03bd6bbb20623ceb6e57d` |
| `UnicodeData-3.2.0.txt` | [official source](https://www.unicode.org/Public/3.2-Update/UnicodeData-3.2.0.txt) | `5e444028b6e76d96f9dc509609c5e3222bf609056f35e5fcde7e6fb8a58cd446` |
| `citrus_utf8mac.c` | [official source](https://github.com/apple-oss-distributions/libiconv/blob/f96c1fcdbb308374e39290676b5fea40a3859d17/libiconv_modules/UTF8MAC/citrus_utf8mac.c) | `2a018de7f0ce2b641bfae97ff4c2c8cf5e12789239d7d77b3f11ec63e224936d` |
| `libiconv_test.c` | [official source](https://github.com/apple-oss-distributions/libiconv/blob/f96c1fcdbb308374e39290676b5fea40a3859d17/tests/libiconv/libiconv_test.c) | `67f8a968f8c17dbef0338aa7c3e909139dbc8bb5187a24b62552a0b4067cb1c6` |
| `tn1150table.html` | [official source](https://developer.apple.com/library/archive/technotes/tn/tn1150table.html) | `67c7f9572752693800df3cd79974b59374e36b2240bc7f31a14192efa57a5e03` |
