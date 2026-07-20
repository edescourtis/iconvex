# Evertype source-qualified single-byte mappings

These normalized artifacts independently express seven byte-to-Unicode mappings from Michael Everson's published Evertype tables. They contain only hexadecimal byte/scalar pairs in byte order; the upstream prose, comments, character names, and row formatting are not redistributed.

The upstream tables explicitly state that omitted C0 controls (`00`-`1F`) and DELETE (`7F`) use standard control mappings. Those 33 identity mappings are therefore materialized in every normalized CSV. Any other absent byte is invalid. Decode preserves every published mapping. Encode uses the lowest byte value when multiple bytes map to the same Unicode scalar; this affects U+0304 in Mac OS Barents Cyrillic (`C2` and `C3` decode to U+0304, while U+0304 encodes as `C2`).

The normalized artifacts and implementation are part of Iconvex and licensed under `LGPL-2.1-or-later`. No upstream copyright or license claim is made for the linked source files, which are not bundled. The Evertype name is used only to qualify provenance and does not imply vendor authorship, affiliation, approval, or endorsement.

| Canonical encoding | Table version | Date | Raw bytes | Raw SHA-256 | Normalized SHA-256 | Mapped | Invalid | Source |
|---|---:|---:|---:|---|---|---:|---:|---|
| `EVERTYPE-2001-LATIN-8-EXTENDED` | 1.00 | 2001-11-10 | 10813 | `bf737b4ade62c97acd5969f75916142748fcde041e8c97fd6663863ccc96a975` | `53750c83e4958e7f530f7eaa59163689caa12c3916cb4103ff066952ab61a13b` | 249 | 7 | [latin8_extended](https://www.evertype.com/standards/mappings/pc/LATIN8EX.TXT) |
| `EVERTYPE-2001-MAC-ARMENIAN` | 1.00 | 2001-11-10 | 10137 | `c194770439215b4fb2c9b3a5f232a9ae35371ccf8fbf26f9c13e03afe61a8536` | `696a5f6cd8145857990cf5e0c762c4f91ebb48f07f1744eff84ef0a56f7faba5` | 256 | 0 | [mac_armenian](https://www.evertype.com/standards/mappings/mac/ARMENIAN.TXT) |
| `EVERTYPE-2001-MAC-BARENTS-CYRILLIC` | 1.00 | 2001-11-10 | 11171 | `c8b84a870ff5344965a1874ca0001735e3e403c22a4f50c71979d90bd6a1fe31` | `f95ab935a572d1ee82b44228b610156bc2a75d07a3a85cd1d5988a587a751cfd` | 254 | 2 | [mac_barents_cyrillic](https://www.evertype.com/standards/mappings/mac/BARENCYR.TXT) |
| `EVERTYPE-2002-MAC-GEORGIAN` | 1.01 | 2002-02-20 | 9763 | `fcd491dbb7916fe477a2bab79872cef498d3a418594eba307ccbd14d095ce8cf` | `2d668f14a934f457495dc86a698f03845525cc9ff43f837fb0f3f98f41819897` | 256 | 0 | [mac_georgian](https://www.evertype.com/standards/mappings/mac/GEORGIAN.TXT) |
| `EVERTYPE-2001-MAC-MALTESE-ESPERANTO` | 1.00 | 2001-11-10 | 11671 | `a902a920790704905a9aa7d5ea03d19996c4bfe6e46501f53878f9b27107ef41` | `ed4516ebd16e1d715c2c271becf11cfcca8a57c0cf4e4f173d142393c8a88ffe` | 256 | 0 | [mac_maltese_esperanto](https://www.evertype.com/standards/mappings/mac/MALTESE.TXT) |
| `EVERTYPE-2001-MAC-OGHAM` | 1.00 | 2001-11-10 | 6422 | `d95239fc60b38ef80488cbc55b342a9d695953802ecce869077212256e50a13a` | `77a027e95f55949aa22756f45f14b7fb03253ff87d67311252d21910fccee3bf` | 167 | 89 | [mac_ogham](https://www.evertype.com/standards/mappings/mac/OGHAM.TXT) |
| `EVERTYPE-2002-MAC-TURKIC-CYRILLIC` | 1.01 | 2002-02-20 | 11974 | `26175fa84c20db0cab9c11ec532c622490796c6de1561b58313ed090a644e968` | `228b19300e6baefda3e6aa9d4e89343f42a660bd3d5989cbd52f9dae585a6277` | 256 | 0 | [mac_turkic_cyrillic](https://www.evertype.com/standards/mappings/mac/TURKCYR.TXT) |

## CER-GS 1.01 blocker

`CERGS.TXT` (table 1.01, 2002-02-20, 10,458 bytes, SHA-256 `9aece7742b4fc70f6047f888815efc1f21f08b521c03e07ed96e91b50fc25f36`) is deliberately not implemented. Its published rows assign bytes `B7`, `B8`, `B9`, and `BA` twice to different Unicode scalars and later place U+027C at `8F`, while the publisher's separate CER-GS repertoire page places U+027C at `BF`. No byte-exact codec can choose among those contradictions without an undocumented correction.

- Mapping table: https://www.evertype.com/standards/mappings/pc/CERGS.TXT
- Corroborating repertoire page: https://www.evertype.com/celtscript/celtcode.html
