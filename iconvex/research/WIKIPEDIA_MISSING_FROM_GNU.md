# Wikipedia character-set clusters missing from GNU libiconv 1.19

This is a deterministic projection of `known_encodings.csv`. A cluster is included
only when its merged source set contains the direct `wikipedia` source and GNU
libiconv 1.19 support is `no`. The separate `wikipedia_historical` source is not
implicitly treated as direct Wikipedia category membership.

Source catalog SHA-256: `76e9b26b75e8142573df72a576061cfbdc8c0acc35723186b610d64f9e42821f`.

## Summary

- Wikipedia-sourced clusters absent from GNU libiconv 1.19: **394**.
- Implemented by Iconvex: **241**.
- Remaining: **153**.
- Codec gaps: **15**.
- Research candidates: **121**.
- Encoding families: **14**.
- Repertoire abstraction: **1**.
- Repertoire profile: **1**.
- Withdrawn/unassigned part: **1**.

`codec_gap` is an actionable codec target. `research_candidate` requires an
exact mapping/specification before implementation. Family, repertoire, profile,
and withdrawn-part rows are catalogued identities but are not standalone codecs.
The CSV preserves aliases, kinds, all source identities, all source URLs, and the
audited disposition for every row.

## Remaining clusters (153)

| Catalog ID | Identity | Confidence | Iconvex | Disposition | Wikipedia source | Other specification/evidence |
|---|---|:---:|:---:|---|---|---|
| ENC-0010 | ALCOR | candidate | no | `research_candidate` | [wikipedia:pageid 4862582](https://en.wikipedia.org/wiki/ALCOR) | — |
| ENC-0023 | Apple I character set | candidate | no | `research_candidate` | [wikipedia:pageid 61693236](https://en.wikipedia.org/wiki/Apple_I_character_set) | — |
| ENC-0027 | ARIB STD B24 character set | medium | no | `codec_gap` | [wikipedia:pageid 54428551](https://en.wikipedia.org/wiki/ARIB_STD_B24_character_set) | [source 1](https://www.wikidata.org/wiki/Q39087152) |
| ENC-0028 | ArmSCII | candidate | no | `encoding_family` | [wikipedia:pageid 932710](https://en.wikipedia.org/wiki/ArmSCII) | — |
| ENC-0035 | Bangladesh Standard Code for Information Interchange | candidate | no | `research_candidate` | [wikipedia:pageid 76409395](https://en.wikipedia.org/wiki/Bangladesh_Standard_Code_for_Information_Interchange) | — |
| ENC-0043 | BCD (character encoding) | candidate | no | `research_candidate` | [wikipedia:pageid 29603924](https://en.wikipedia.org/wiki/BCD_%28character_encoding%29) | — |
| ENC-0067 | Bitstream International Character Set | medium | no | `codec_gap` | [wikipedia:pageid 54274255](https://en.wikipedia.org/wiki/Bitstream_International_Character_Set) | [source 1](https://www.wikidata.org/wiki/Q30694105) |
| ENC-0071 | Box-drawing characters | candidate | no | `research_candidate` | [wikipedia:pageid 1295471](https://en.wikipedia.org/wiki/Box-drawing_characters) | — |
| ENC-0072 | Braille | candidate | no | `research_candidate` | [wikipedia:pageid 3933](https://en.wikipedia.org/wiki/Braille) | — |
| ENC-0080 | BSCII | candidate | no | `research_candidate` | [wikipedia:pageid 76409398](https://en.wikipedia.org/wiki/BSCII) | — |
| ENC-0084 | Caret notation | candidate | no | `research_candidate` | [wikipedia:pageid 2265038](https://en.wikipedia.org/wiki/Caret_notation) | — |
| ENC-0086 | Casio calculator character sets | medium | no | `encoding_family` | [wikipedia:pageid 54221610](https://en.wikipedia.org/wiki/Casio_calculator_character_sets) | [source 1](https://www.wikidata.org/wiki/Q30693953) |
| ENC-0095 | CER-GS | candidate | no | `research_candidate` | [wikipedia:pageid 53321435](https://en.wikipedia.org/wiki/CER-GS) | — |
| ENC-0102 | Chinese Character Code for Information Interchange | medium | no | `codec_gap` | [wikipedia:pageid 1497620](https://en.wikipedia.org/wiki/Chinese_Character_Code_for_Information_Interchange) | [source 1](https://www.wikidata.org/wiki/Q1073697) |
| ENC-0112 | CJK characters | candidate | no | `research_candidate` | [wikipedia:pageid 160987](https://en.wikipedia.org/wiki/CJK_characters) | — |
| ENC-0113 | CJK Unified Ideographs | candidate | no | `research_candidate` | [wikipedia:pageid 6094332](https://en.wikipedia.org/wiki/CJK_Unified_Ideographs) | — |
| ENC-0114 | Cluff–Foster–Idelson code | candidate | no | `research_candidate` | [wikipedia:pageid 57932208](https://en.wikipedia.org/wiki/Cluff%E2%80%93Foster%E2%80%93Idelson_code) | — |
| ENC-0115 | Code page 0 | candidate | no | `research_candidate` | [wikipedia:pageid 50892857](https://en.wikipedia.org/wiki/Code_page_0) | — |
| ENC-0141 | Code page 1036 | candidate | no | `research_candidate` | [wikipedia:pageid 53195030](https://en.wikipedia.org/wiki/Code_page_1036) | — |
| ENC-0142 | Code page 1038 | candidate | no | `research_candidate` | [wikipedia:pageid 54497992](https://en.wikipedia.org/wiki/Code_page_1038) | — |
| ENC-0147 | Code page 1050 | candidate | no | `research_candidate` | [wikipedia:pageid 51294077](https://en.wikipedia.org/wiki/Code_page_1050) | — |
| ENC-0149 | Code page 1058 | candidate | no | `research_candidate` | [wikipedia:pageid 73689995](https://en.wikipedia.org/wiki/Code_page_1058) | — |
| ENC-0151 | Code page 1090 | candidate | no | `research_candidate` | [wikipedia:pageid 54488718](https://en.wikipedia.org/wiki/Code_page_1090) | — |
| ENC-0152 | Code page 1093 | candidate | no | `research_candidate` | [wikipedia:pageid 64303905](https://en.wikipedia.org/wiki/Code_page_1093) | — |
| ENC-0162 | Code page 1111 | candidate | no | `research_candidate` | [wikipedia:pageid 53254354](https://en.wikipedia.org/wiki/Code_page_1111) | — |
| ENC-0165 | Code page 1116 | medium | no | `codec_gap` | [wikipedia:pageid 63939909](https://en.wikipedia.org/wiki/Code_page_1116) | [source 1](https://www.wikidata.org/wiki/Q96375205) |
| ENC-0166 | Code page 1117 | medium | no | `codec_gap` | [wikipedia:pageid 43222757](https://en.wikipedia.org/wiki/Code_page_1117) | [source 1](https://www.wikidata.org/wiki/Q17510261) |
| ENC-0167 | Code page 1118 | candidate | no | `research_candidate` | [wikipedia:pageid 43210137](https://en.wikipedia.org/wiki/Code_page_1118) | — |
| ENC-0175 | Code page 1200 | candidate | no | `research_candidate` | [wikipedia:pageid 54488655](https://en.wikipedia.org/wiki/Code_page_1200) | — |
| ENC-0176 | Code page 12000 | candidate | no | `research_candidate` | [wikipedia:pageid 54488649](https://en.wikipedia.org/wiki/Code_page_12000) | — |
| ENC-0182 | Code page 165 | candidate | no | `research_candidate` | [wikipedia:pageid 77125435](https://en.wikipedia.org/wiki/Code_page_165) | — |
| ENC-0201 | Code page 28600 | candidate | no | `research_candidate` | [wikipedia:pageid 39199111](https://en.wikipedia.org/wiki/Code_page_28600) | — |
| ENC-0202 | Code page 28601 | candidate | no | `research_candidate` | [wikipedia:pageid 39199120](https://en.wikipedia.org/wiki/Code_page_28601) | — |
| ENC-0203 | Code page 28602 | candidate | no | `research_candidate` | [wikipedia:pageid 39199129](https://en.wikipedia.org/wiki/Code_page_28602) | — |
| ENC-0205 | Code page 28604 | candidate | no | `research_candidate` | [wikipedia:pageid 39199150](https://en.wikipedia.org/wiki/Code_page_28604) | — |
| ENC-0207 | Code page 28606 | candidate | no | `research_candidate` | [wikipedia:pageid 39199162](https://en.wikipedia.org/wiki/Code_page_28606) | — |
| ENC-0209 | Code page 310 | medium | no | `codec_gap` | [wikipedia:pageid 57395884](https://en.wikipedia.org/wiki/Code_page_310) | [source 1](https://www.wikidata.org/wiki/Q55607840) |
| ENC-0210 | Code page 351 | candidate | no | `research_candidate` | [wikipedia:pageid 57419375](https://en.wikipedia.org/wiki/Code_page_351) | — |
| ENC-0211 | Code page 353 | candidate | no | `research_candidate` | [wikipedia:pageid 53184113](https://en.wikipedia.org/wiki/Code_page_353) | — |
| ENC-0212 | Code page 354 | candidate | no | `research_candidate` | [wikipedia:pageid 76998339](https://en.wikipedia.org/wiki/Code_page_354) | — |
| ENC-0213 | Code page 355 | candidate | no | `research_candidate` | [wikipedia:pageid 53205873](https://en.wikipedia.org/wiki/Code_page_355) | — |
| ENC-0214 | Code page 357 | candidate | no | `research_candidate` | [wikipedia:pageid 53205876](https://en.wikipedia.org/wiki/Code_page_357) | — |
| ENC-0215 | Code page 358 | candidate | no | `research_candidate` | [wikipedia:pageid 53205878](https://en.wikipedia.org/wiki/Code_page_358) | — |
| ENC-0216 | Code page 359 | candidate | no | `research_candidate` | [wikipedia:pageid 53205879](https://en.wikipedia.org/wiki/Code_page_359) | — |
| ENC-0217 | Code page 360 | candidate | no | `research_candidate` | [wikipedia:pageid 53205882](https://en.wikipedia.org/wiki/Code_page_360) | — |
| ENC-0219 | Code page 38596 | candidate | no | `research_candidate` | [wikipedia:pageid 39199475](https://en.wikipedia.org/wiki/Code_page_38596) | — |
| ENC-0222 | Code page 57344 | candidate | no | `research_candidate` | [wikipedia:pageid 50892894](https://en.wikipedia.org/wiki/Code_page_57344) | — |
| ENC-0223 | Code page 61439 | candidate | no | `research_candidate` | [wikipedia:pageid 50892905](https://en.wikipedia.org/wiki/Code_page_61439) | — |
| ENC-0224 | Code page 65280 | candidate | no | `research_candidate` | [wikipedia:pageid 50892912](https://en.wikipedia.org/wiki/Code_page_65280) | — |
| ENC-0225 | Code page 65533 | candidate | no | `research_candidate` | [wikipedia:pageid 50892926](https://en.wikipedia.org/wiki/Code_page_65533) | — |
| ENC-0226 | Code page 65534 | candidate | no | `research_candidate` | [wikipedia:pageid 50892886](https://en.wikipedia.org/wiki/Code_page_65534) | — |
| ENC-0227 | Code page 65535 | candidate | no | `research_candidate` | [wikipedia:pageid 50892870](https://en.wikipedia.org/wiki/Code_page_65535) | — |
| ENC-0237 | Code page 790 | candidate | no | `research_candidate` | [wikipedia:pageid 39233396](https://en.wikipedia.org/wiki/Code_page_790) | — |
| ENC-0266 | Code page 899 | candidate | no | `research_candidate` | [wikipedia:pageid 67764915](https://en.wikipedia.org/wiki/Code_page_899) | — |
| ENC-0267 | Code page 900 | candidate | no | `research_candidate` | [wikipedia:pageid 42689138](https://en.wikipedia.org/wiki/Code_page_900) | — |
| ENC-0272 | Code page 907 | medium | no | `codec_gap` | [wikipedia:pageid 54734716](https://en.wikipedia.org/wiki/Code_page_907) | [source 1](https://www.wikidata.org/wiki/Q56291572) |
| ENC-0278 | Code page 919 | candidate | no | `research_candidate` | [wikipedia:pageid 53254523](https://en.wikipedia.org/wiki/Code_page_919) | — |
| ENC-0284 | Code page 932 (Microsoft Windows) | candidate | no | `research_candidate` | [wikipedia:pageid 49785337](https://en.wikipedia.org/wiki/Code_page_932_%28Microsoft_Windows%29) | — |
| ENC-0286 | Code page 936 (IBM) | candidate | no | `research_candidate` | [wikipedia:pageid 49785584](https://en.wikipedia.org/wiki/Code_page_936_%28IBM%29) | — |
| ENC-0287 | Code page 936 (Microsoft Windows) | candidate | no | `research_candidate` | [wikipedia:pageid 2955551](https://en.wikipedia.org/wiki/Code_page_936_%28Microsoft_Windows%29) | — |
| ENC-0298 | Code page 991 | candidate | no | `research_candidate` | [wikipedia:pageid 39210446](https://en.wikipedia.org/wiki/Code_page_991) | — |
| ENC-0299 | Code page 999 | candidate | no | `research_candidate` | [wikipedia:pageid 50892829](https://en.wikipedia.org/wiki/Code_page_999) | — |
| ENC-0301 | Compatibility Encoding Scheme for UTF-16 | candidate | no | `encoding_family` | [wikipedia:pageid 50619754](https://en.wikipedia.org/wiki/Compatibility_Encoding_Scheme_for_UTF-16) | — |
| ENC-0302 | Compucolor II character set | candidate | no | `research_candidate` | [wikipedia:pageid 59332643](https://en.wikipedia.org/wiki/Compucolor_II_character_set) | — |
| ENC-0413 | CROSCII | candidate | no | `research_candidate` | [wikipedia:pageid 22341642](https://en.wikipedia.org/wiki/CROSCII) | — |
| ENC-0414 | CS Indic character set | candidate | no | `research_candidate` | [wikipedia:pageid 61357173](https://en.wikipedia.org/wiki/CS_Indic_character_set) | — |
| ENC-0419 | CSX Indic character set | candidate | no | `research_candidate` | [wikipedia:pageid 61357290](https://en.wikipedia.org/wiki/CSX_Indic_character_set) [wikipedia:pageid 61357438](https://en.wikipedia.org/wiki/CSX%2B_Indic_character_set) | — |
| ENC-0442 | Digital encoding of APL symbols | candidate | no | `research_candidate` | [wikipedia:pageid 24955657](https://en.wikipedia.org/wiki/Digital_encoding_of_APL_symbols) | — |
| ENC-0443 | DIN 66303 | candidate | no | `research_candidate` | [wikipedia:pageid 66458011](https://en.wikipedia.org/wiki/DIN_66303) | — |
| ENC-0444 | DIN 91379 | candidate | no | `research_candidate` | [wikipedia:pageid 70348251](https://en.wikipedia.org/wiki/DIN_91379) | — |
| ENC-0447 | DKOI | candidate | no | `research_candidate` | [wikipedia:pageid 56530611](https://en.wikipedia.org/wiki/DKOI) | — |
| ENC-0455 | EBCDIC | medium | no | `encoding_family` | [wikipedia:pageid 9773](https://en.wikipedia.org/wiki/EBCDIC) | [source 1](https://www.wikidata.org/wiki/Q627945) [source 2](https://en.wikipedia.org/wiki/List_of_information_system_character_sets) |
| ENC-0475 | EBU Latin | candidate | no | `research_candidate` | [wikipedia:pageid 82218481](https://en.wikipedia.org/wiki/EBU_Latin) | — |
| ENC-0477 | ECMA-121 | candidate | no | `research_candidate` | [wikipedia:pageid 53203221](https://en.wikipedia.org/wiki/ECMA-121) | — |
| ENC-0480 | ECMA-6 | medium | no | `encoding_family` | [wikipedia:pageid 50662940](https://en.wikipedia.org/wiki/ECMA-6) | [source 1](https://en.wikipedia.org/wiki/List_of_information_system_character_sets) |
| ENC-0481 | ECMA-94 | candidate | no | `research_candidate` | [wikipedia:pageid 51221074](https://en.wikipedia.org/wiki/ECMA-94) | — |
| ENC-0491 | Extended ASCII | candidate | no | `research_candidate` | [wikipedia:pageid 18950011](https://en.wikipedia.org/wiki/Extended_ASCII) | — |
| ENC-0495 | Extended Unix Code | candidate | no | `research_candidate` | [wikipedia:pageid 546341](https://en.wikipedia.org/wiki/Extended_Unix_Code) | — |
| ENC-0499 | Fieldata | medium | no | `encoding_family` | [wikipedia:pageid 383855](https://en.wikipedia.org/wiki/Fieldata) | [source 1](https://www.wikidata.org/wiki/Q1411578) [source 2](https://en.wikipedia.org/wiki/List_of_information_system_character_sets) |
| ENC-0500 | File System Safe UCS Transformation Format | candidate | no | `research_candidate` | [wikipedia:pageid 50619689](https://en.wikipedia.org/wiki/File_System_Safe_UCS_Transformation_Format) | — |
| ENC-0502 | FOCAL character set | candidate | no | `research_candidate` | [wikipedia:pageid 56210570](https://en.wikipedia.org/wiki/FOCAL_character_set) | — |
| ENC-0504 | FSS-UTF | candidate | no | `research_candidate` | [wikipedia:pageid 36941603](https://en.wikipedia.org/wiki/FSS-UTF) | — |
| ENC-0505 | GB 12052 | medium | no | `codec_gap` | [wikipedia:pageid 65439469](https://en.wikipedia.org/wiki/GB_12052) | [source 1](https://www.wikidata.org/wiki/Q9363228) |
| ENC-0506 | GB 12345 | medium | no | `codec_gap` | [wikipedia:pageid 70740645](https://en.wikipedia.org/wiki/GB_12345) | [source 1](https://www.wikidata.org/wiki/Q10847246) |
| ENC-0519 | GCCS (character set) | candidate | no | `research_candidate` | [wikipedia:pageid 52504751](https://en.wikipedia.org/wiki/GCCS_%28character_set%29) | — |
| ENC-0521 | GEM character set | candidate | no | `research_candidate` | [wikipedia:pageid 52866923](https://en.wikipedia.org/wiki/GEM_character_set) | — |
| ENC-0525 | GOST 10859 | medium | no | `encoding_family` | [wikipedia:pageid 11646457](https://en.wikipedia.org/wiki/GOST_10859) | [source 1](https://en.wikipedia.org/wiki/List_of_information_system_character_sets) |
| ENC-0527 | Government Chinese Character Set | candidate | no | `research_candidate` | [wikipedia:pageid 3300720](https://en.wikipedia.org/wiki/Government_Chinese_Character_Set) | — |
| ENC-0540 | Hardware code page | candidate | no | `research_candidate` | [wikipedia:pageid 39171547](https://en.wikipedia.org/wiki/Hardware_code_page) | — |
| ENC-0547 | Hong Kong Supplementary Character Set | candidate | no | `research_candidate` | [wikipedia:pageid 685827](https://en.wikipedia.org/wiki/Hong_Kong_Supplementary_Character_Set) | — |
| ENC-0548 | HP calculator character sets | candidate | no | `research_candidate` | [wikipedia:pageid 51287359](https://en.wikipedia.org/wiki/HP_calculator_character_sets) | — |
| ENC-0549 | HP Roman | candidate | no | `research_candidate` | [wikipedia:pageid 23752603](https://en.wikipedia.org/wiki/HP_Roman) | — |
| ENC-0550 | HP Roman Extension | candidate | no | `research_candidate` | [wikipedia:pageid 51294990](https://en.wikipedia.org/wiki/HP_Roman_Extension) | — |
| ENC-0964 | Ideographic Research Group | candidate | no | `research_candidate` | [wikipedia:pageid 1581861](https://en.wikipedia.org/wiki/Ideographic_Research_Group) | — |
| ENC-0977 | International Reference Alphabet | candidate | no | `research_candidate` | [wikipedia:pageid 32184690](https://en.wikipedia.org/wiki/International_Reference_Alphabet) | — |
| ENC-0984 | Iran System encoding | candidate | no | `research_candidate` | [wikipedia:pageid 5209052](https://en.wikipedia.org/wiki/Iran_System_encoding) | — |
| ENC-0997 | ISO 10585 | candidate | no | `research_candidate` | [wikipedia:pageid 17136645](https://en.wikipedia.org/wiki/ISO_10585) | — |
| ENC-1067 | ISO/IEC 10367 | candidate | no | `research_candidate` | [wikipedia:pageid 54362040](https://en.wikipedia.org/wiki/ISO/IEC_10367) | — |
| ENC-1075 | ISO/IEC 2022 | candidate | no | `research_candidate` | [wikipedia:pageid 493590](https://en.wikipedia.org/wiki/ISO/IEC_2022) | — |
| ENC-1076 | ISO/IEC 646 | candidate | no | `research_candidate` | [wikipedia:pageid 193891](https://en.wikipedia.org/wiki/ISO/IEC_646) | — |
| ENC-1077 | ISO/IEC 8859 | medium | no | `encoding_family` | [wikipedia:pageid 15020](https://en.wikipedia.org/wiki/ISO/IEC_8859) | [source 1](https://en.wikipedia.org/wiki/List_of_information_system_character_sets) |
| ENC-1078 | ISO/IEC 8859-12 | medium | no | `withdrawn_unassigned_part` | [wikipedia:pageid 428014](https://en.wikipedia.org/wiki/ISO/IEC_8859-12) | [source 1](https://www.wikidata.org/wiki/Q606464) |
| ENC-1104 | ITU T.61 | candidate | no | `research_candidate` | [wikipedia:pageid 1009605](https://en.wikipedia.org/wiki/ITU_T.61) | — |
| ENC-1111 | Japanese language in EBCDIC | candidate | no | `research_candidate` | [wikipedia:pageid 67794413](https://en.wikipedia.org/wiki/Japanese_language_in_EBCDIC) | — |
| ENC-1144 | JUS I.B1.003 | candidate | no | `encoding_family` | [wikipedia:pageid 50735765](https://en.wikipedia.org/wiki/JUS_I.B1.003) | — |
| ENC-1145 | JUS I.B1.004 | candidate | no | `research_candidate` | [wikipedia:pageid 50735766](https://en.wikipedia.org/wiki/JUS_I.B1.004) | — |
| ENC-1150 | KanjiTalk | candidate | no | `research_candidate` | [wikipedia:pageid 17707662](https://en.wikipedia.org/wiki/KanjiTalk) | — |
| ENC-1154 | KOI character encodings | candidate | no | `research_candidate` | [wikipedia:pageid 704726](https://en.wikipedia.org/wiki/KOI_character_encodings) | — |
| ENC-1157 | KOI8-B | medium | no | `repertoire_profile` | [wikipedia:pageid 54572661](https://en.wikipedia.org/wiki/KOI8-B) | [source 1](https://www.wikidata.org/wiki/Q39087696) |
| ENC-1159 | KOI8-O | candidate | no | `research_candidate` | [wikipedia:pageid 76990738](https://en.wikipedia.org/wiki/KOI8-O) | — |
| ENC-1166 | KS X 1002 | medium | no | `codec_gap` | [wikipedia:pageid 65447546](https://en.wikipedia.org/wiki/KS_X_1002) | [source 1](https://www.wikidata.org/wiki/Q12581371) |
| ENC-1194 | Lotus Multi-Byte Character Set | medium | no | `encoding_family` | [wikipedia:pageid 52386027](https://en.wikipedia.org/wiki/Lotus_Multi-Byte_Character_Set) | [source 1](https://www.wikidata.org/wiki/Q28454421) |
| ENC-1238 | Macintosh Font X encoding | candidate | no | `research_candidate` | [wikipedia:pageid 67807842](https://en.wikipedia.org/wiki/Macintosh_Font_X_encoding) | — |
| ENC-1250 | Main code page (Russian) | candidate | no | `research_candidate` | [wikipedia:pageid 56493039](https://en.wikipedia.org/wiki/Main_code_page_%28Russian%29) | — |
| ENC-1251 | MAKSCII | candidate | no | `research_candidate` | [wikipedia:pageid 50735772](https://en.wikipedia.org/wiki/MAKSCII) | — |
| ENC-1254 | Matsushita JR series | candidate | no | `research_candidate` | [wikipedia:pageid 29496347](https://en.wikipedia.org/wiki/Matsushita_JR_series) | — |
| ENC-1255 | Mattel Aquarius | candidate | no | `research_candidate` | [wikipedia:pageid 268943](https://en.wikipedia.org/wiki/Mattel_Aquarius) | — |
| ENC-1265 | Modified HP Roman-8 | candidate | no | `research_candidate` | [wikipedia:pageid 51292914](https://en.wikipedia.org/wiki/Modified_HP_Roman-8) | — |
| ENC-1268 | Mojikyō | medium | no | `codec_gap` | [wikipedia:pageid 1601755](https://en.wikipedia.org/wiki/Mojiky%C5%8D) | [source 1](https://www.wikidata.org/wiki/Q830907) |
| ENC-1271 | MouseText | candidate | no | `research_candidate` | [wikipedia:pageid 9853359](https://en.wikipedia.org/wiki/MouseText) | — |
| ENC-1277 | National Replacement Character Set | candidate | no | `research_candidate` | [wikipedia:pageid 13246836](https://en.wikipedia.org/wiki/National_Replacement_Character_Set) | — |
| ENC-1288 | NEC APC character set | medium | no | `codec_gap` | [wikipedia:pageid 54266640](https://en.wikipedia.org/wiki/NEC_APC_character_set) | [source 1](https://www.wikidata.org/wiki/Q35146040) |
| ENC-1306 | PCW character set | candidate | no | `research_candidate` | [wikipedia:pageid 54560173](https://en.wikipedia.org/wiki/PCW_character_set) | — |
| ENC-1311 | Popularity of text encodings | candidate | no | `research_candidate` | [wikipedia:pageid 67131807](https://en.wikipedia.org/wiki/Popularity_of_text_encodings) | — |
| ENC-1312 | Portable character set | medium | no | `repertoire_abstraction` | [wikipedia:pageid 2405344](https://en.wikipedia.org/wiki/Portable_character_set) | [source 1](https://www.wikidata.org/wiki/Q4350686) |
| ENC-1315 | PostScript Standard Encoding | candidate | no | `research_candidate` | [wikipedia:pageid 53165942](https://en.wikipedia.org/wiki/PostScript_Standard_Encoding) | — |
| ENC-1316 | PrintableString | candidate | no | `research_candidate` | [wikipedia:pageid 11856681](https://en.wikipedia.org/wiki/PrintableString) | — |
| ENC-1332 | RISC OS character set | candidate | no | `research_candidate` | [wikipedia:pageid 53256679](https://en.wikipedia.org/wiki/RISC_OS_character_set) | — |
| ENC-1336 | RPL character set | medium | no | `codec_gap` | [wikipedia:pageid 51221648](https://en.wikipedia.org/wiki/RPL_character_set) | [source 1](https://www.wikidata.org/wiki/Q28453805) |
| ENC-1337 | SAM Coupé character set | candidate | no | `research_candidate` | [wikipedia:pageid 73665458](https://en.wikipedia.org/wiki/SAM_Coup%C3%A9_character_set) | — |
| ENC-1341 | Sanyo PHC-25 | candidate | no | `research_candidate` | [wikipedia:pageid 26340704](https://en.wikipedia.org/wiki/Sanyo_PHC-25) | — |
| ENC-1344 | SEASCII | candidate | no | `research_candidate` | [wikipedia:pageid 53417122](https://en.wikipedia.org/wiki/SEASCII) | — |
| ENC-1346 | Sega SC-3000 character set | medium | no | `codec_gap` | [wikipedia:pageid 59787448](https://en.wikipedia.org/wiki/Sega_SC-3000_character_set) | [source 1](https://www.wikidata.org/wiki/Q65117806) |
| ENC-1347 | Semigraphics | candidate | no | `research_candidate` | [wikipedia:pageid 33078541](https://en.wikipedia.org/wiki/Semigraphics) | — |
| ENC-1353 | Sharp MZ character set | candidate | no | `research_candidate` | [wikipedia:pageid 59216433](https://en.wikipedia.org/wiki/Sharp_MZ_character_set) | — |
| ENC-1354 | Sharp pocket computer character sets | candidate | no | `research_candidate` | [wikipedia:pageid 53299882](https://en.wikipedia.org/wiki/Sharp_pocket_computer_character_sets) | — |
| ENC-1362 | Sinhala input methods | candidate | no | `research_candidate` | [wikipedia:pageid 34925840](https://en.wikipedia.org/wiki/Sinhala_input_methods) | — |
| ENC-1365 | SLOSCII | candidate | no | `research_candidate` | [wikipedia:pageid 50735775](https://en.wikipedia.org/wiki/SLOSCII) | — |
| ENC-1372 | SRPSCII | candidate | no | `research_candidate` | [wikipedia:pageid 50735774](https://en.wikipedia.org/wiki/SRPSCII) | — |
| ENC-1391 | T.50 (standard) | candidate | no | `research_candidate` | [wikipedia:pageid 1009486](https://en.wikipedia.org/wiki/T.50_%28standard%29) | — |
| ENC-1405 | Teletext character set | candidate | no | `encoding_family` | [wikipedia:pageid 58602386](https://en.wikipedia.org/wiki/Teletext_character_set) | — |
| ENC-1408 | Thomson EF9345 | candidate | no | `research_candidate` | [wikipedia:pageid 67921294](https://en.wikipedia.org/wiki/Thomson_EF9345) | — |
| ENC-1409 | TI calculator character sets | medium | no | `encoding_family` | [wikipedia:pageid 23235262](https://en.wikipedia.org/wiki/TI_calculator_character_sets) | [source 1](https://www.wikidata.org/wiki/Q17082293) |
| ENC-1417 | TRON (encoding) | candidate | no | `research_candidate` | [wikipedia:pageid 1889610](https://en.wikipedia.org/wiki/TRON_%28encoding%29) | — |
| ENC-1435 | Unified Hangul Code | candidate | no | `research_candidate` | [wikipedia:pageid 2997032](https://en.wikipedia.org/wiki/Unified_Hangul_Code) | — |
| ENC-1445 | Universal Coded Character Set | candidate | no | `research_candidate` | [wikipedia:pageid 23431060](https://en.wikipedia.org/wiki/Universal_Coded_Character_Set) | — |
| ENC-1489 | Videotex character set | medium | no | `encoding_family` | [wikipedia:pageid 59888016](https://en.wikipedia.org/wiki/Videotex_character_set) | [source 1](https://www.wikidata.org/wiki/Q61757001) |
| ENC-1503 | Western Latin character sets | candidate | no | `research_candidate` | [wikipedia:pageid 2189529](https://en.wikipedia.org/wiki/Western_Latin_character_sets) | — |
| ENC-1506 | Windows code page | candidate | no | `research_candidate` | [wikipedia:pageid 2698630](https://en.wikipedia.org/wiki/Windows_code_page) | — |
| ENC-1519 | Windows Cyrillic + French | candidate | no | `research_candidate` | [wikipedia:pageid 63990342](https://en.wikipedia.org/wiki/Windows_Cyrillic_%2B_French) | — |
| ENC-1520 | Windows Cyrillic + German | candidate | no | `research_candidate` | [wikipedia:pageid 63990126](https://en.wikipedia.org/wiki/Windows_Cyrillic_%2B_German) | — |
| ENC-1617 | Xerox Character Code Standard | medium | no | `codec_gap` | [wikipedia:pageid 52093502](https://en.wikipedia.org/wiki/Xerox_Character_Code_Standard) | [source 1](https://www.wikidata.org/wiki/Q17651329) |
| ENC-1619 | YUSCII | medium | no | `encoding_family` | [wikipedia:pageid 4710349](https://en.wikipedia.org/wiki/YUSCII) | [source 1](https://www.wikidata.org/wiki/Q4053427) |

## Implemented by Iconvex (241)

| Catalog ID | Identity | Confidence | Iconvex | Disposition | Wikipedia source | Other specification/evidence |
|---|---|:---:|:---:|---|---|---|
| ENC-0002 | ABC 800 | high | yes | `implemented` | [wikipedia:pageid 584429](https://en.wikipedia.org/wiki/ABC_800) | [source 1](https://www.abc80.net/archive/luxor/ABC80x/ABC800-manual-BASIC-II.pdf) |
| ENC-0003 | ABICOMP character set | high | yes | `implemented` | [wikipedia:pageid 51976001](https://en.wikipedia.org/wiki/ABICOMP_character_set) | [source 1](https://www.wikidata.org/wiki/Q28454173) [source 2](https://archive.org/download/manuallib-id-2525457/2525457.pdf) |
| ENC-0014 | American National Standard Extended Latin Alphabet Coded Character Set for Bibliographic Use (ANSEL) | high | yes | `implemented` | [wikipedia:pageid 410443](https://en.wikipedia.org/wiki/ANSEL) | [source 1](https://itscj.ipsj.or.jp/ir/231.pdf) [source 2](https://www.wikidata.org/wiki/Q2819298) [source 3](https://www.loc.gov/marc/specifications/codetables/ExtendedLatin.html) |
| ENC-0016 | Amstrad CP/M Plus character set | candidate | yes | `implemented` | [wikipedia:pageid 54335453](https://en.wikipedia.org/wiki/Amstrad_CP/M_Plus_character_set) | — |
| ENC-0017 | Amstrad CPC character set | candidate | yes | `implemented` | [wikipedia:pageid 63377119](https://en.wikipedia.org/wiki/Amstrad_CPC_character_set) | — |
| ENC-0024 | Apple II character set | medium | yes | `implemented` | [wikipedia:pageid 54566027](https://en.wikipedia.org/wiki/Apple_II_character_set) | [source 1](https://www.wikidata.org/wiki/Q39087662) |
| ENC-0030 | ASMO_449 | high | yes | `implemented` | [wikipedia:pageid 5546531](https://en.wikipedia.org/wiki/ASMO_449) | [source 1](https://www.iana.org/assignments/character-sets/character-sets.xhtml) [source 2](https://sourceware.org/glibc/manual/latest/html_node/Generic-Charset-Conversion.html) [source 3](https://www.rfc-editor.org/rfc/rfc1345.html) [source 4](https://www.wikidata.org/wiki/Q11189653) |
| ENC-0031 | Atari ST character set | medium | yes | `implemented` | [wikipedia:pageid 49729654](https://en.wikipedia.org/wiki/Atari_ST_character_set) | [source 1](https://www.wikidata.org/wiki/Q15784268) |
| ENC-0033 | ATASCII | medium | yes | `implemented` | [wikipedia:pageid 560142](https://en.wikipedia.org/wiki/ATASCII) | — |
| ENC-0041 | Baudot code | medium | yes | `implemented` | [wikipedia:pageid 4748](https://en.wikipedia.org/wiki/Baudot_code) | — |
| ENC-0066 | Big5hk | candidate | yes | `implemented` | [wikipedia:pageid 52504591](https://en.wikipedia.org/wiki/Big5hk) | — |
| ENC-0069 | BOCU-1 | high | yes | `implemented` | [wikipedia:pageid 1552730](https://en.wikipedia.org/wiki/Binary_Ordered_Compression_for_Unicode) [wikipedia:pageid 2461738](https://en.wikipedia.org/wiki/BOCU-1) | [source 1](https://www.iana.org/assignments/character-sets/character-sets.xhtml) [source 2](https://raw.githubusercontent.com/unicode-org/icu/main/icu4c/source/data/mappings/convrtrs.txt) |
| ENC-0075 | BraSCII | high | yes | `implemented` | [wikipedia:pageid 53292599](https://en.wikipedia.org/wiki/BraSCII) | [source 1](https://www.wikidata.org/wiki/Q9642584) [source 2](https://files.support.epson.com/pdf/sc200_/sc200_u1.pdf) |
| ENC-0087 | CCIR 476 | high | yes | `implemented` | [wikipedia:pageid 62089600](https://en.wikipedia.org/wiki/CCIR_476) | [source 1](https://www.wikidata.org/wiki/Q85749828) [source 2](https://www.itu.int/rec/R-REC-M.476/en) |
| ENC-0088 | CCITT 2 | candidate | yes | `implemented` | [wikipedia:pageid 53850148](https://en.wikipedia.org/wiki/CCITT_2) | — |
| ENC-0090 | CDC display code | high | yes | `implemented` | [wikipedia:pageid 4488830](https://en.wikipedia.org/wiki/CDC_display_code) | [source 1](https://www.wikidata.org/wiki/Q5009913) [source 2](https://en.wikipedia.org/wiki/List_of_information_system_character_sets) [source 3](https://bitsavers.org/pdf/cdc/cyber/nos/60435600L_NOS_Version_1_Operators_Guide_May1980.pdf) |
| ENC-0096 | CESU-8 | high | yes | `implemented` | [wikipedia:pageid 2232502](https://en.wikipedia.org/wiki/CESU-8) [wikipedia:pageid 50624363](https://en.wikipedia.org/wiki/Compatibility_Encoding_Scheme_for_UTF-16%3A_8-Bit) | [source 1](https://www.iana.org/assignments/character-sets/character-sets.xhtml) [source 2](https://raw.githubusercontent.com/unicode-org/icu/main/icu4c/source/data/mappings/convrtrs.txt) [source 3](https://raw.githubusercontent.com/openjdk/jdk/master/make/data/charsetmapping/charsets) [source 4](https://www.wikidata.org/wiki/Q455180) |
| ENC-0103 | Chinese character encoding | candidate | yes | `implemented` | [wikipedia:pageid 274699](https://en.wikipedia.org/wiki/Chinese_character_encoding) | — |
| ENC-0116 | Code page 10000 | candidate | yes | `implemented` | [wikipedia:pageid 1451206](https://en.wikipedia.org/wiki/Code_page_10000) | — |
| ENC-0117 | Code page 10004 | candidate | yes | `implemented` | [wikipedia:pageid 43244374](https://en.wikipedia.org/wiki/Code_page_10004) | — |
| ENC-0118 | Code page 10006 | candidate | yes | `implemented` | [wikipedia:pageid 43244373](https://en.wikipedia.org/wiki/Code_page_10006) | — |
| ENC-0119 | Code page 10007 | candidate | yes | `implemented` | [wikipedia:pageid 1459403](https://en.wikipedia.org/wiki/Code_page_10007) | — |
| ENC-0120 | Code page 10017 | candidate | yes | `implemented` | [wikipedia:pageid 43244395](https://en.wikipedia.org/wiki/Code_page_10017) | — |
| ENC-0121 | Code page 10029 | candidate | yes | `implemented` | [wikipedia:pageid 1459612](https://en.wikipedia.org/wiki/Code_page_10029) | — |
| ENC-0122 | Code page 1004 | candidate | yes | `implemented` | [wikipedia:pageid 57409565](https://en.wikipedia.org/wiki/Code_page_1004) | — |
| ENC-0123 | Code page 1006 | medium | yes | `implemented` | [wikipedia:pageid 64296319](https://en.wikipedia.org/wiki/Code_page_1006) | [source 1](https://www.wikidata.org/wiki/Q96375197) |
| ENC-0124 | Code page 10079 | candidate | yes | `implemented` | [wikipedia:pageid 43244400](https://en.wikipedia.org/wiki/Code_page_10079) | — |
| ENC-0125 | Code page 1008 | medium | yes | `implemented` | [wikipedia:pageid 64296679](https://en.wikipedia.org/wiki/Code_page_1008) | [source 1](https://www.wikidata.org/wiki/Q96375198) |
| ENC-0126 | Code page 10081 | candidate | yes | `implemented` | [wikipedia:pageid 54344602](https://en.wikipedia.org/wiki/Code_page_10081) | — |
| ENC-0127 | Code page 10082 | candidate | yes | `implemented` | [wikipedia:pageid 54344610](https://en.wikipedia.org/wiki/Code_page_10082) | — |
| ENC-0128 | Code page 1009 | medium | yes | `implemented` | [wikipedia:pageid 49798554](https://en.wikipedia.org/wiki/Code_page_1009) | [source 1](https://www.wikidata.org/wiki/Q25304982) |
| ENC-0129 | Code page 1010 | medium | yes | `implemented` | [wikipedia:pageid 49798752](https://en.wikipedia.org/wiki/Code_page_1010) | [source 1](https://www.wikidata.org/wiki/Q25304984) |
| ENC-0130 | Code page 1012 | medium | yes | `implemented` | [wikipedia:pageid 52499316](https://en.wikipedia.org/wiki/Code_page_1012) | [source 1](https://www.wikidata.org/wiki/Q28454464) |
| ENC-0131 | Code page 1013 | medium | yes | `implemented` | [wikipedia:pageid 52499365](https://en.wikipedia.org/wiki/Code_page_1013) | [source 1](https://www.wikidata.org/wiki/Q28454465) |
| ENC-0132 | Code page 1014 | medium | yes | `implemented` | [wikipedia:pageid 52499398](https://en.wikipedia.org/wiki/Code_page_1014) | [source 1](https://www.wikidata.org/wiki/Q28454466) |
| ENC-0133 | Code page 1015 | medium | yes | `implemented` | [wikipedia:pageid 53170206](https://en.wikipedia.org/wiki/Code_page_1015) | [source 1](https://www.wikidata.org/wiki/Q30591602) |
| ENC-0134 | Code page 1016 | medium | yes | `implemented` | [wikipedia:pageid 53170389](https://en.wikipedia.org/wiki/Code_page_1016) | [source 1](https://www.wikidata.org/wiki/Q30591606) |
| ENC-0135 | Code page 1017 | medium | yes | `implemented` | [wikipedia:pageid 53170423](https://en.wikipedia.org/wiki/Code_page_1017) | [source 1](https://www.wikidata.org/wiki/Q30591609) |
| ENC-0136 | Code page 1018 | medium | yes | `implemented` | [wikipedia:pageid 53170460](https://en.wikipedia.org/wiki/Code_page_1018) | [source 1](https://www.wikidata.org/wiki/Q30591613) |
| ENC-0137 | Code page 1019 | medium | yes | `implemented` | [wikipedia:pageid 53170513](https://en.wikipedia.org/wiki/Code_page_1019) | [source 1](https://www.wikidata.org/wiki/Q30591611) |
| ENC-0138 | Code page 1020 | medium | yes | `implemented` | [wikipedia:pageid 53172597](https://en.wikipedia.org/wiki/Code_page_1020) | [source 1](https://www.wikidata.org/wiki/Q30591649) |
| ENC-0139 | Code page 1021 | medium | yes | `implemented` | [wikipedia:pageid 53173141](https://en.wikipedia.org/wiki/Code_page_1021) | [source 1](https://www.wikidata.org/wiki/Q30591657) |
| ENC-0140 | Code page 1023 | medium | yes | `implemented` | [wikipedia:pageid 53173745](https://en.wikipedia.org/wiki/Code_page_1023) | [source 1](https://www.wikidata.org/wiki/Q30591667) |
| ENC-0143 | Code page 1040 | medium | yes | `implemented` | [wikipedia:pageid 64298324](https://en.wikipedia.org/wiki/Code_page_1040) | [source 1](https://www.wikidata.org/wiki/Q96375199) |
| ENC-0145 | Code page 1043 | medium | yes | `implemented` | [wikipedia:pageid 64304487](https://en.wikipedia.org/wiki/Code_page_1043) | [source 1](https://www.wikidata.org/wiki/Q96375201) |
| ENC-0146 | Code page 1046 | medium | yes | `implemented` | [wikipedia:pageid 64304859](https://en.wikipedia.org/wiki/Code_page_1046) | [source 1](https://www.wikidata.org/wiki/Q96375203) |
| ENC-0148 | Code page 1051 | candidate | yes | `implemented` | [wikipedia:pageid 51286814](https://en.wikipedia.org/wiki/Code_page_1051) | — |
| ENC-0150 | Code page 1089 | candidate | yes | `implemented` | [wikipedia:pageid 53255063](https://en.wikipedia.org/wiki/Code_page_1089) | — |
| ENC-0153 | Code page 1098 | medium | yes | `implemented` | [wikipedia:pageid 56933244](https://en.wikipedia.org/wiki/Code_page_1098) | [source 1](https://www.wikidata.org/wiki/Q55639457) |
| ENC-0154 | Code page 1100 | candidate | yes | `implemented` | [wikipedia:pageid 52462384](https://en.wikipedia.org/wiki/Code_page_1100) | — |
| ENC-0155 | Code page 1101 | medium | yes | `implemented` | [wikipedia:pageid 53171706](https://en.wikipedia.org/wiki/Code_page_1101) | [source 1](https://www.wikidata.org/wiki/Q30591634) |
| ENC-0156 | Code page 1102 | medium | yes | `implemented` | [wikipedia:pageid 53173409](https://en.wikipedia.org/wiki/Code_page_1102) | [source 1](https://www.wikidata.org/wiki/Q30591658) |
| ENC-0157 | Code page 1103 | medium | yes | `implemented` | [wikipedia:pageid 53172192](https://en.wikipedia.org/wiki/Code_page_1103) | [source 1](https://www.wikidata.org/wiki/Q30591640) |
| ENC-0158 | Code page 1104 | medium | yes | `implemented` | [wikipedia:pageid 53172499](https://en.wikipedia.org/wiki/Code_page_1104) | [source 1](https://www.wikidata.org/wiki/Q30591647) |
| ENC-0159 | Code page 1105 | medium | yes | `implemented` | [wikipedia:pageid 53171983](https://en.wikipedia.org/wiki/Code_page_1105) | [source 1](https://www.wikidata.org/wiki/Q30591638) |
| ENC-0160 | Code page 1106 | medium | yes | `implemented` | [wikipedia:pageid 53172255](https://en.wikipedia.org/wiki/Code_page_1106) | [source 1](https://www.wikidata.org/wiki/Q30591645) |
| ENC-0161 | Code page 1107 | medium | yes | `implemented` | [wikipedia:pageid 53171921](https://en.wikipedia.org/wiki/Code_page_1107) | [source 1](https://www.wikidata.org/wiki/Q30591633) |
| ENC-0163 | Code page 1114 | candidate | yes | `implemented` | [wikipedia:pageid 64306001](https://en.wikipedia.org/wiki/Code_page_1114) | — |
| ENC-0164 | Code page 1115 | medium | yes | `implemented` | [wikipedia:pageid 64306528](https://en.wikipedia.org/wiki/Code_page_1115) | [source 1](https://www.wikidata.org/wiki/Q96375204) |
| ENC-0168 | Code page 1124 | medium | yes | `implemented` | [wikipedia:pageid 53170645](https://en.wikipedia.org/wiki/Code_page_1124) | [source 1](https://www.wikidata.org/wiki/Q30591615) |
| ENC-0169 | Code page 1127 | candidate | yes | `implemented` | [wikipedia:pageid 64317073](https://en.wikipedia.org/wiki/Code_page_1127) | — |
| ENC-0170 | Code page 1129 | candidate | yes | `implemented` | [wikipedia:pageid 64317192](https://en.wikipedia.org/wiki/Code_page_1129) | — |
| ENC-0171 | Code page 1133 | medium | yes | `implemented` | [wikipedia:pageid 12852680](https://en.wikipedia.org/wiki/Code_page_1133) | [source 1](https://www.wikidata.org/wiki/Q5140102) |
| ENC-0172 | Code page 1163 | candidate | yes | `implemented` | [wikipedia:pageid 64317200](https://en.wikipedia.org/wiki/Code_page_1163) | — |
| ENC-0173 | Code page 1167 | candidate | yes | `implemented` | [wikipedia:pageid 53269356](https://en.wikipedia.org/wiki/Code_page_1167) | — |
| ENC-0174 | Code page 1168 | candidate | yes | `implemented` | [wikipedia:pageid 52471565](https://en.wikipedia.org/wiki/Code_page_1168) | — |
| ENC-0177 | Code page 1201 | candidate | yes | `implemented` | [wikipedia:pageid 54488659](https://en.wikipedia.org/wiki/Code_page_1201) | — |
| ENC-0178 | Code page 1275 | candidate | yes | `implemented` | [wikipedia:pageid 54488729](https://en.wikipedia.org/wiki/Code_page_1275) | — |
| ENC-0179 | Code page 1276 | candidate | yes | `implemented` | [wikipedia:pageid 53165950](https://en.wikipedia.org/wiki/Code_page_1276) | — |
| ENC-0180 | Code page 1287 | medium | yes | `implemented` | [wikipedia:pageid 53173888](https://en.wikipedia.org/wiki/Code_page_1287) | [source 1](https://www.wikidata.org/wiki/Q28814797) |
| ENC-0181 | Code page 1288 | medium | yes | `implemented` | [wikipedia:pageid 53173987](https://en.wikipedia.org/wiki/Code_page_1288) | [source 1](https://www.wikidata.org/wiki/Q28814800) |
| ENC-0183 | Code page 17248 | candidate | yes | `implemented` | [wikipedia:pageid 52396560](https://en.wikipedia.org/wiki/Code_page_17248) | — |
| ENC-0184 | Code page 20105 | candidate | yes | `implemented` | [wikipedia:pageid 50872123](https://en.wikipedia.org/wiki/Code_page_20105) | — |
| ENC-0185 | Code page 20106 | candidate | yes | `implemented` | [wikipedia:pageid 50872096](https://en.wikipedia.org/wiki/Code_page_20106) | — |
| ENC-0186 | Code page 20127 | candidate | yes | `implemented` | [wikipedia:pageid 43244567](https://en.wikipedia.org/wiki/Code_page_20127) | — |
| ENC-0187 | Code page 20261 | candidate | yes | `implemented` | [wikipedia:pageid 54344628](https://en.wikipedia.org/wiki/Code_page_20261) | — |
| ENC-0188 | Code page 20269 | candidate | yes | `implemented` | [wikipedia:pageid 54344617](https://en.wikipedia.org/wiki/Code_page_20269) | — |
| ENC-0189 | Code page 20866 | candidate | yes | `implemented` | [wikipedia:pageid 42878117](https://en.wikipedia.org/wiki/Code_page_20866) | — |
| ENC-0190 | Code page 21866 | candidate | yes | `implemented` | [wikipedia:pageid 42878224](https://en.wikipedia.org/wiki/Code_page_21866) | — |
| ENC-0192 | Code page 28591 | candidate | yes | `implemented` | [wikipedia:pageid 39199002](https://en.wikipedia.org/wiki/Code_page_28591) | — |
| ENC-0193 | Code page 28592 | candidate | yes | `implemented` | [wikipedia:pageid 39199019](https://en.wikipedia.org/wiki/Code_page_28592) | — |
| ENC-0194 | Code page 28593 | candidate | yes | `implemented` | [wikipedia:pageid 39199030](https://en.wikipedia.org/wiki/Code_page_28593) | — |
| ENC-0195 | Code page 28594 | candidate | yes | `implemented` | [wikipedia:pageid 39199044](https://en.wikipedia.org/wiki/Code_page_28594) | — |
| ENC-0196 | Code page 28595 | candidate | yes | `implemented` | [wikipedia:pageid 39199056](https://en.wikipedia.org/wiki/Code_page_28595) | — |
| ENC-0197 | Code page 28596 | candidate | yes | `implemented` | [wikipedia:pageid 39199067](https://en.wikipedia.org/wiki/Code_page_28596) | — |
| ENC-0198 | Code page 28597 | candidate | yes | `implemented` | [wikipedia:pageid 39199076](https://en.wikipedia.org/wiki/Code_page_28597) | — |
| ENC-0199 | Code page 28598 | candidate | yes | `implemented` | [wikipedia:pageid 39199088](https://en.wikipedia.org/wiki/Code_page_28598) | — |
| ENC-0200 | Code page 28599 | candidate | yes | `implemented` | [wikipedia:pageid 39199107](https://en.wikipedia.org/wiki/Code_page_28599) | — |
| ENC-0204 | Code page 28603 | candidate | yes | `implemented` | [wikipedia:pageid 39199136](https://en.wikipedia.org/wiki/Code_page_28603) | — |
| ENC-0206 | Code page 28605 | candidate | yes | `implemented` | [wikipedia:pageid 39199155](https://en.wikipedia.org/wiki/Code_page_28605) | — |
| ENC-0208 | Code page 293 | medium | yes | `implemented` | [wikipedia:pageid 54991743](https://en.wikipedia.org/wiki/Code_page_293) | [source 1](https://www.wikidata.org/wiki/Q39090898) |
| ENC-0218 | Code page 367 | candidate | yes | `implemented` | [wikipedia:pageid 43222415](https://en.wikipedia.org/wiki/Code_page_367) | — |
| ENC-0220 | Code page 38598 | candidate | yes | `implemented` | [wikipedia:pageid 39199214](https://en.wikipedia.org/wiki/Code_page_38598) | — |
| ENC-0221 | Code page 437 | medium | yes | `implemented` | [wikipedia:pageid 1028188](https://en.wikipedia.org/wiki/Code_page_437) | [source 1](https://www.wikidata.org/wiki/Q1105757) |
| ENC-0228 | Code page 667 | candidate | yes | `implemented` | [wikipedia:pageid 39210455](https://en.wikipedia.org/wiki/Code_page_667) | — |
| ENC-0231 | Code page 737 | medium | yes | `implemented` | [wikipedia:pageid 1462345](https://en.wikipedia.org/wiki/Code_page_737) | [source 1](https://www.wikidata.org/wiki/Q1105733) |
| ENC-0232 | Code page 771 | medium | yes | `implemented` | [wikipedia:pageid 43209996](https://en.wikipedia.org/wiki/Code_page_771) | [source 1](https://www.wikidata.org/wiki/Q17510274) |
| ENC-0233 | Code page 772 | medium | yes | `implemented` | [wikipedia:pageid 53184662](https://en.wikipedia.org/wiki/Code_page_772) | [source 1](https://www.wikidata.org/wiki/Q17510276) |
| ENC-0235 | Code page 774 | medium | yes | `implemented` | [wikipedia:pageid 53184663](https://en.wikipedia.org/wiki/Code_page_774) | [source 1](https://www.wikidata.org/wiki/Q17510281) |
| ENC-0238 | Code page 806 | candidate | yes | `implemented` | [wikipedia:pageid 53267304](https://en.wikipedia.org/wiki/Code_page_806) | — |
| ENC-0239 | Code page 808 | candidate | yes | `implemented` | [wikipedia:pageid 40751811](https://en.wikipedia.org/wiki/Code_page_808) | — |
| ENC-0240 | Code page 813 | candidate | yes | `implemented` | [wikipedia:pageid 53254453](https://en.wikipedia.org/wiki/Code_page_813) | — |
| ENC-0241 | Code page 819 | candidate | yes | `implemented` | [wikipedia:pageid 39211041](https://en.wikipedia.org/wiki/Code_page_819) | — |
| ENC-0242 | code page 850 | medium | yes | `implemented` | [wikipedia:pageid 1002424](https://en.wikipedia.org/wiki/Code_page_850) | [source 1](https://www.wikidata.org/wiki/Q1105754) |
| ENC-0252 | Code page 861 | medium | yes | `implemented` | [wikipedia:pageid 1462384](https://en.wikipedia.org/wiki/Code_page_861) | [source 1](https://www.wikidata.org/wiki/Q663479) |
| ENC-0253 | Code page 862 | medium | yes | `implemented` | [wikipedia:pageid 2819436](https://en.wikipedia.org/wiki/Code_page_862) | [source 1](https://www.wikidata.org/wiki/Q1105760) |
| ENC-0254 | Code page 863 | medium | yes | `implemented` | [wikipedia:pageid 1462262](https://en.wikipedia.org/wiki/Code_page_863) | [source 1](https://www.wikidata.org/wiki/Q959205) |
| ENC-0255 | Code page 864 | medium | yes | `implemented` | [wikipedia:pageid 33983238](https://en.wikipedia.org/wiki/Code_page_864) | [source 1](https://www.wikidata.org/wiki/Q1105762) |
| ENC-0256 | Code page 865 | medium | yes | `implemented` | [wikipedia:pageid 1459655](https://en.wikipedia.org/wiki/Code_page_865) | [source 1](https://www.wikidata.org/wiki/Q1105768) |
| ENC-0257 | code page 866 | medium | yes | `implemented` | [wikipedia:pageid 1436942](https://en.wikipedia.org/wiki/Code_page_866) | [source 1](https://www.wikidata.org/wiki/Q1105775) |
| ENC-0258 | Code page 867 | medium | yes | `implemented` | [wikipedia:pageid 39176528](https://en.wikipedia.org/wiki/Code_page_867) | [source 1](https://www.wikidata.org/wiki/Q18348141) |
| ENC-0259 | Code page 868 | medium | yes | `implemented` | [wikipedia:pageid 53226255](https://en.wikipedia.org/wiki/Code_page_868) | [source 1](https://www.wikidata.org/wiki/Q30680447) |
| ENC-0260 | Code page 869 | medium | yes | `implemented` | [wikipedia:pageid 1462364](https://en.wikipedia.org/wiki/Code_page_869) | [source 1](https://www.wikidata.org/wiki/Q598294) |
| ENC-0262 | Code page 878 | candidate | yes | `implemented` | [wikipedia:pageid 52465836](https://en.wikipedia.org/wiki/Code_page_878) | — |
| ENC-0263 | Code page 895 | medium | yes | `implemented` | [wikipedia:pageid 39176538](https://en.wikipedia.org/wiki/Code_page_895) | [source 1](https://www.wikidata.org/wiki/Q25303652) |
| ENC-0264 | Code page 896 | medium | yes | `implemented` | [wikipedia:pageid 55771308](https://en.wikipedia.org/wiki/Code_page_896) | [source 1](https://www.wikidata.org/wiki/Q47218937) |
| ENC-0268 | Code page 901 | candidate | yes | `implemented` | [wikipedia:pageid 56933482](https://en.wikipedia.org/wiki/Code_page_901) | — |
| ENC-0269 | Code page 902 | candidate | yes | `implemented` | [wikipedia:pageid 56933526](https://en.wikipedia.org/wiki/Code_page_902) | — |
| ENC-0271 | Code page 904 | medium | yes | `implemented` | [wikipedia:pageid 57388409](https://en.wikipedia.org/wiki/Code_page_904) | [source 1](https://www.wikidata.org/wiki/Q55607846) |
| ENC-0273 | Code page 912 | medium | yes | `implemented` | [wikipedia:pageid 43201834](https://en.wikipedia.org/wiki/Code_page_912) | [source 1](https://www.wikidata.org/wiki/Q17510301) |
| ENC-0274 | Code page 913 | candidate | yes | `implemented` | [wikipedia:pageid 53254367](https://en.wikipedia.org/wiki/Code_page_913) | — |
| ENC-0275 | Code page 914 | candidate | yes | `implemented` | [wikipedia:pageid 53254446](https://en.wikipedia.org/wiki/Code_page_914) | — |
| ENC-0276 | Code page 915 | medium | yes | `implemented` | [wikipedia:pageid 43201840](https://en.wikipedia.org/wiki/Code_page_915) | [source 1](https://www.wikidata.org/wiki/Q17510305) |
| ENC-0277 | Code page 916 | candidate | yes | `implemented` | [wikipedia:pageid 53199065](https://en.wikipedia.org/wiki/Code_page_916) | — |
| ENC-0279 | Code page 920 | candidate | yes | `implemented` | [wikipedia:pageid 53254527](https://en.wikipedia.org/wiki/Code_page_920) | — |
| ENC-0280 | Code page 921 | medium | yes | `implemented` | [wikipedia:pageid 56933443](https://en.wikipedia.org/wiki/Code_page_921) | [source 1](https://www.wikidata.org/wiki/Q55639458) |
| ENC-0281 | Code page 922 | medium | yes | `implemented` | [wikipedia:pageid 56933521](https://en.wikipedia.org/wiki/Code_page_922) | [source 1](https://www.wikidata.org/wiki/Q55639460) |
| ENC-0282 | Code page 923 | candidate | yes | `implemented` | [wikipedia:pageid 53254530](https://en.wikipedia.org/wiki/Code_page_923) | — |
| ENC-0288 | Code page 942 | medium | yes | `implemented` | [wikipedia:pageid 49785466](https://en.wikipedia.org/wiki/Code_page_942) | [source 1](https://www.wikidata.org/wiki/Q25304954) |
| ENC-0290 | Code page 950 | medium | yes | `implemented` | [wikipedia:pageid 2988645](https://en.wikipedia.org/wiki/Code_page_950) | [source 1](https://www.wikidata.org/wiki/Q5140107) |
| ENC-0291 | Code page 951 | medium | yes | `implemented` | [wikipedia:pageid 51590742](https://en.wikipedia.org/wiki/Code_page_951) | [source 1](https://www.wikidata.org/wiki/Q28453953) |
| ENC-0292 | Code page 952 | candidate | yes | `implemented` | [wikipedia:pageid 56933581](https://en.wikipedia.org/wiki/Code_page_952) | — |
| ENC-0293 | Code page 953 | candidate | yes | `implemented` | [wikipedia:pageid 56933585](https://en.wikipedia.org/wiki/Code_page_953) | — |
| ENC-0294 | Code page 954 | candidate | yes | `implemented` | [wikipedia:pageid 54754915](https://en.wikipedia.org/wiki/Code_page_954) | — |
| ENC-0295 | Code page 955 | candidate | yes | `implemented` | [wikipedia:pageid 56933583](https://en.wikipedia.org/wiki/Code_page_955) | — |
| ENC-0296 | Code page 970 | candidate | yes | `implemented` | [wikipedia:pageid 56933662](https://en.wikipedia.org/wiki/Code_page_970) | — |
| ENC-0297 | Code page 971 | candidate | yes | `implemented` | [wikipedia:pageid 67772679](https://en.wikipedia.org/wiki/Code_page_971) | — |
| ENC-0303 | Cork encoding | high | yes | `implemented` | [wikipedia:pageid 7790359](https://en.wikipedia.org/wiki/Cork_encoding) | [source 1](https://www.wikidata.org/wiki/Q1133004) [source 2](https://www.tug.org/TUGboat/tb11-4/tb30ferguson.pdf) |
| ENC-0427 | DEC Hebrew | high | yes | `implemented` | [wikipedia:pageid 53198556](https://en.wikipedia.org/wiki/DEC_Hebrew) | [source 1](https://www.wikidata.org/wiki/Q28814802) [source 2](https://www.bitsavers.org/pdf/dec/_Books/_Digital_Press/Kennelly_Digital_Guide_To_Developing_International_Software_1991.pdf) |
| ENC-0428 | DEC Radix-50 | high | yes | `implemented` | [wikipedia:pageid 2183554](https://en.wikipedia.org/wiki/DEC_RADIX_50) | [source 1](https://www.wikidata.org/wiki/Q580875) [source 2](https://www.bitsavers.org/pdf/dec/pdp11/rt11/v4.0_Mar80/4_fortran/DEC-11-LFLRA_FORTRAN_Language_Reference_Manual_Jun77.pdf) [source 3](https://www.bitsavers.org/pdf/dec/pdp9/DEC-9A-GUAB-D_UTILITIES.pdf) [source 4](https://bitsavers.org/pdf/dec/pdp10/TOPS10_softwareNotebooks/vol13/AA-C780C-TB_Macro_Assembler_Reference_Manual_Apr78.pdf) |
| ENC-0433 | DEC-MCS | high | yes | `implemented` | [wikipedia:pageid 310033](https://en.wikipedia.org/wiki/Multinational_Character_Set) | [source 1](https://www.iana.org/assignments/character-sets/character-sets.xhtml) [source 2](https://sourceware.org/glibc/manual/latest/html_node/Generic-Charset-Conversion.html) [source 3](https://www.rfc-editor.org/rfc/rfc1345.html) [source 4](https://www.kermitproject.org/k95charsets.html) [source 5](https://www.wikidata.org/wiki/Q1152919) |
| ENC-0434 | DEC-SPECIAL | high | yes | `implemented` | [wikipedia:pageid 54329742](https://en.wikipedia.org/wiki/DEC_Special_Graphics) | [source 1](https://www.kermitproject.org/k95charsets.html) [source 2](https://www.wikidata.org/wiki/Q28600467) [source 3](https://bitsavers.org/pdf/dec/terminal/vt340/EK-VT3XX-TP-002_VT330_VT340_Text_Programming_198805.pdf) |
| ENC-0435 | DEC-TECHNICAL | high | yes | `implemented` | [wikipedia:pageid 54344958](https://en.wikipedia.org/wiki/DEC_Technical_Character_Set) | [source 1](https://www.kermitproject.org/k95charsets.html) [source 2](https://www.wikidata.org/wiki/Q30694350) [source 3](https://bitsavers.org/pdf/dec/terminal/vt340/EK-VT3XX-TP-002_VT330_VT340_Text_Programming_198805.pdf) |
| ENC-0438 | DG-INTERNATIONAL | medium | yes | `implemented` | [wikipedia:pageid 53256517](https://en.wikipedia.org/wiki/DG_International) | [source 1](https://www.kermitproject.org/k95charsets.html) [source 2](https://www.wikidata.org/wiki/Q30592414) |
| ENC-0445 | DIN_66003 | high | yes | `implemented` | [wikipedia:pageid 49798801](https://en.wikipedia.org/wiki/DIN_66003) | [source 1](https://www.iana.org/assignments/character-sets/character-sets.xhtml) [source 2](https://sourceware.org/glibc/manual/latest/html_node/Generic-Charset-Conversion.html) [source 3](https://www.rfc-editor.org/rfc/rfc1345.html) [source 4](https://www.kermitproject.org/k95charsets.html) [source 5](https://www.wikidata.org/wiki/Q1153802) |
| ENC-0476 | ECMA-1 | candidate | yes | `implemented` | [wikipedia:pageid 52401768](https://en.wikipedia.org/wiki/ECMA-1) | — |
| ENC-0494 | Extended Latin-8 | high | yes | `implemented` | [wikipedia:pageid 53321280](https://en.wikipedia.org/wiki/Extended_Latin-8) | [source 1](https://www.evertype.com/standards/mappings/pc/LATIN8EX.TXT) |
| ENC-0535 | greek7 | high | yes | `implemented` | [wikipedia:pageid 54265514](https://en.wikipedia.org/wiki/ELOT_927) | [source 1](https://www.iana.org/assignments/character-sets/character-sets.xhtml) [source 2](https://sourceware.org/glibc/manual/latest/html_node/Generic-Charset-Conversion.html) [source 3](https://www.rfc-editor.org/rfc/rfc1345.html) [source 4](https://www.wikidata.org/wiki/Q35146256) |
| ENC-0537 | GSM 03.38 | high | yes | `implemented` | [wikipedia:pageid 23752827](https://en.wikipedia.org/wiki/GSM_03.38) | [source 1](https://www.wikidata.org/wiki/Q1441241) [source 2](https://www.etsi.org/deliver/etsi_ts/123000_123099/123038/19.00.00_60/ts_123038v190000p.pdf) |
| ENC-0541 | HEBREW-7 | high | yes | `implemented` | [wikipedia:pageid 38986175](https://en.wikipedia.org/wiki/SI_960) | [source 1](https://www.kermitproject.org/k95charsets.html) [source 2](https://www.wikidata.org/wiki/Q17081980) [source 3](https://www.bitsavers.org/pdf/dec/_Books/_Digital_Press/Kennelly_Digital_Guide_To_Developing_International_Software_1991.pdf) |
| ENC-0559 | HP-ROMAN9 | high | yes | `implemented` | [wikipedia:pageid 51286929](https://en.wikipedia.org/wiki/HP_Roman-9) | [source 1](https://sourceware.org/glibc/manual/latest/html_node/Generic-Charset-Conversion.html) |
| ENC-0565 | IA5 (character encoding) | candidate | yes | `implemented` | [wikipedia:pageid 50806583](https://en.wikipedia.org/wiki/IA5_%28character_encoding%29) | — |
| ENC-0965 | IEC_P27-1 | high | yes | `implemented` | [wikipedia:pageid 54548872](https://en.wikipedia.org/wiki/IEC-P27-1) | [source 1](https://www.iana.org/assignments/character-sets/character-sets.xhtml) [source 2](https://sourceware.org/glibc/manual/latest/html_node/Generic-Charset-Conversion.html) [source 3](https://www.rfc-editor.org/rfc/rfc1345.html) |
| ENC-0967 | Indian Script Code for Information Interchange | medium | yes | `implemented` | [wikipedia:pageid 533706](https://en.wikipedia.org/wiki/Indian_Script_Code_for_Information_Interchange) | [source 1](https://www.wikidata.org/wiki/Q1661279) |
| ENC-0969 | INIS character set | candidate | yes | `implemented` | [wikipedia:pageid 54551850](https://en.wikipedia.org/wiki/INIS_character_set) | — |
| ENC-0973 | INIS-8 | high | yes | `implemented` | [wikipedia:pageid 54552145](https://en.wikipedia.org/wiki/INIS-8) | [source 1](https://www.iana.org/assignments/character-sets/character-sets.xhtml) [source 2](https://sourceware.org/glibc/manual/latest/html_node/Generic-Charset-Conversion.html) [source 3](https://www.rfc-editor.org/rfc/rfc1345.html) |
| ENC-0975 | International Alphabet No. 5 | candidate | yes | `implemented` | [wikipedia:pageid 32184698](https://en.wikipedia.org/wiki/International_Alphabet_No._5) | — |
| ENC-0978 | International Telegraph Alphabet No. 1 | candidate | yes | `implemented` | [wikipedia:pageid 22661027](https://en.wikipedia.org/wiki/International_Telegraph_Alphabet_No._1) | — |
| ENC-0979 | International Telegraph Alphabet No. 2 | candidate | yes | `implemented` | [wikipedia:pageid 35392385](https://en.wikipedia.org/wiki/International_Telegraph_Alphabet_No._2) | — |
| ENC-0980 | International Telegraph Alphabet No. 3 | candidate | yes | `implemented` | [wikipedia:pageid 53554842](https://en.wikipedia.org/wiki/International_Telegraph_Alphabet_No._3) | — |
| ENC-0983 | IRA (character encoding) | candidate | yes | `implemented` | [wikipedia:pageid 50806582](https://en.wikipedia.org/wiki/IRA_%28character_encoding%29) | — |
| ENC-0998 | ISO 5426 | candidate | yes | `implemented` | [wikipedia:pageid 54385770](https://en.wikipedia.org/wiki/ISO_5426) | — |
| ENC-0999 | ISO 6438 | medium | yes | `implemented` | [wikipedia:pageid 8604469](https://en.wikipedia.org/wiki/ISO_6438) | [source 1](https://www.wikidata.org/wiki/Q1015387) |
| ENC-1014 | ISO IR-68 | medium | yes | `implemented` | [wikipedia:pageid 54332654](https://en.wikipedia.org/wiki/ISO-IR-68) | [source 1](https://www.wikidata.org/wiki/Q30688881) |
| ENC-1050 | ISO-8859-8-I | high | yes | `implemented` | [wikipedia:pageid 2763121](https://en.wikipedia.org/wiki/ISO-8859-8-I) | [source 1](https://www.iana.org/assignments/character-sets/character-sets.xhtml) [source 2](https://encoding.spec.whatwg.org/) [source 3](https://learn.microsoft.com/en-us/windows/win32/intl/code-page-identifiers) |
| ENC-1054 | ISO-IR-111 | candidate | yes | `implemented` | [wikipedia:pageid 56434581](https://en.wikipedia.org/wiki/ISO-IR-111) | — |
| ENC-1055 | ISO-IR-153 | candidate | yes | `implemented` | [wikipedia:pageid 54493559](https://en.wikipedia.org/wiki/ISO-IR-153) | — |
| ENC-1057 | ISO-IR-169 | candidate | yes | `implemented` | [wikipedia:pageid 60022560](https://en.wikipedia.org/wiki/ISO-IR-169) | — |
| ENC-1058 | ISO-IR-182 | candidate | yes | `implemented` | [wikipedia:pageid 56924101](https://en.wikipedia.org/wiki/ISO-IR-182) | — |
| ENC-1059 | ISO-IR-197 | high | yes | `implemented` | [wikipedia:pageid 56924413](https://en.wikipedia.org/wiki/ISO-IR-197) | [source 1](https://sourceware.org/glibc/manual/latest/html_node/Generic-Charset-Conversion.html) |
| ENC-1085 | ISO_2033 | high | yes | `implemented` | [wikipedia:pageid 54345183](https://en.wikipedia.org/wiki/ISO_2033) | [source 1](https://sourceware.org/glibc/manual/latest/html_node/Generic-Charset-Conversion.html) |
| ENC-1087 | ISO_5427 | high | yes | `implemented` | [wikipedia:pageid 57100801](https://en.wikipedia.org/wiki/ISO_5427) | [source 1](https://www.iana.org/assignments/character-sets/character-sets.xhtml) [source 2](https://sourceware.org/glibc/manual/latest/html_node/Generic-Charset-Conversion.html) [source 3](https://www.rfc-editor.org/rfc/rfc1345.html) |
| ENC-1090 | ISO_5428 | high | yes | `implemented` | [wikipedia:pageid 44418500](https://en.wikipedia.org/wiki/ISO_5428) | [source 1](https://sourceware.org/glibc/manual/latest/html_node/Generic-Charset-Conversion.html) [source 2](https://www.wikidata.org/wiki/Q19572241) |
| ENC-1094 | ISO_6937 | high | yes | `implemented` | [wikipedia:pageid 2756880](https://en.wikipedia.org/wiki/T.51/ISO/IEC_6937) [wikipedia:pageid 50893710](https://en.wikipedia.org/wiki/ITU_T.51) | [source 1](https://sourceware.org/glibc/manual/latest/html_node/Generic-Charset-Conversion.html) |
| ENC-1100 | ITA1 | candidate | yes | `implemented` | [wikipedia:pageid 35393511](https://en.wikipedia.org/wiki/ITA1) | — |
| ENC-1101 | ITA2 | high | yes | `implemented` | [wikipedia:pageid 53847806](https://en.wikipedia.org/wiki/CCIT_2) [wikipedia:pageid 584483](https://en.wikipedia.org/wiki/ITA2) | [source 1](https://en.wikipedia.org/wiki/List_of_information_system_character_sets) [source 2](https://www.itu.int/rec/T-REC-S.1/en) |
| ENC-1103 | ITA3 | candidate | yes | `implemented` | [wikipedia:pageid 53554955](https://en.wikipedia.org/wiki/ITA3) | — |
| ENC-1139 | JIS_Encoding | high | yes | `implemented` | [wikipedia:pageid 489295](https://en.wikipedia.org/wiki/JIS_encoding) | [source 1](https://www.iana.org/assignments/character-sets/character-sets.xhtml) |
| ENC-1146 | JUS_I.B1.002 | high | yes | `implemented` | [wikipedia:pageid 50735764](https://en.wikipedia.org/wiki/JUS_I.B1.002) | [source 1](https://www.iana.org/assignments/character-sets/character-sets.xhtml) [source 2](https://sourceware.org/glibc/manual/latest/html_node/Generic-Charset-Conversion.html) [source 3](https://www.rfc-editor.org/rfc/rfc1345.html) |
| ENC-1149 | Kamenický encoding | high | yes | `implemented` | [wikipedia:pageid 1430689](https://en.wikipedia.org/wiki/Kamenick%C3%BD_encoding) | [source 1](https://www.wikidata.org/wiki/Q3490491) [source 2](https://ftp.fi.muni.cz/pub/localization/charsets/cs-encodings-faq) |
| ENC-1155 | KOI-8 | high | yes | `implemented` | [wikipedia:pageid 1386538](https://en.wikipedia.org/wiki/KOI-8) | [source 1](https://sourceware.org/glibc/manual/latest/html_node/Generic-Charset-Conversion.html) [source 2](https://www.kermitproject.org/k95charsets.html) [source 3](https://www.wikidata.org/wiki/Q2512796) |
| ENC-1158 | KOI8-F | high | yes | `implemented` | [wikipedia:pageid 54497728](https://en.wikipedia.org/wiki/KOI8-F) | [source 1](https://www.wikidata.org/wiki/Q39087334) [source 2](https://web.archive.org/web/20200712005106id_/http://sofia.nmsu.edu/~mleisher/Software/csets/KOI8UNI.TXT) |
| ENC-1165 | KPS9566 | high | yes | `implemented` | [wikipedia:pageid 20481393](https://en.wikipedia.org/wiki/KPS_9566) | [source 1](https://www.unicode.org/Public/MAPPINGS/VENDORS/MISC/KPS9566.TXT) [source 2](https://www.wikidata.org/wiki/Q712676) [source 3](https://en.wikipedia.org/wiki/List_of_information_system_character_sets) |
| ENC-1171 | KSX1001 | high | yes | `implemented` | [wikipedia:pageid 23738382](https://en.wikipedia.org/wiki/KS_X_1001) | [source 1](https://www.unicode.org/Public/MAPPINGS/OBSOLETE/EASTASIA/KSC/KSX1001.TXT) [source 2](https://www.wikidata.org/wiki/Q489423) |
| ENC-1193 | Lotus International Character Set | high | yes | `implemented` | [wikipedia:pageid 52433665](https://en.wikipedia.org/wiki/Lotus_International_Character_Set) | [source 1](https://www.wikidata.org/wiki/Q28454447) [source 2](https://www.retroisle.com/others/hp95lx/OriginalDocs/95LX_UsersGuide_F1000-90001_826pages_Jun91.pdf) |
| ENC-1195 | LST 1564 | high | yes | `implemented` | [wikipedia:pageid 64278714](https://en.wikipedia.org/wiki/LST_1564) | [source 1](https://github.com/lietuvybe/standards/tree/52a97895aad2ba40e93a1da28a63c964ad63b9eb) |
| ENC-1197 | LST 1590-4 | high | yes | `implemented` | [wikipedia:pageid 64278890](https://en.wikipedia.org/wiki/LST_1590-4) | [source 1](https://www.wikidata.org/wiki/Q96386571) [source 2](https://github.com/lietuvybe/standards/tree/52a97895aad2ba40e93a1da28a63c964ad63b9eb) |
| ENC-1198 | LY1 encoding | high | yes | `implemented` | [wikipedia:pageid 54561103](https://en.wikipedia.org/wiki/LY1_encoding) | [source 1](https://mirrors.ctan.org/fonts/psfonts/ly1.zip) |
| ENC-1199 | Mac OS Armenian | high | yes | `implemented` | [wikipedia:pageid 57121512](https://en.wikipedia.org/wiki/Mac_OS_Armenian) | [source 1](https://www.evertype.com/standards/mappings/mac/ARMENIAN.TXT) |
| ENC-1200 | Mac OS Barents Cyrillic | high | yes | `implemented` | [wikipedia:pageid 57114428](https://en.wikipedia.org/wiki/Mac_OS_Barents_Cyrillic) | [source 1](https://www.evertype.com/standards/mappings/mac/BARENCYR.TXT) |
| ENC-1201 | Mac OS Celtic | high | yes | `implemented` | [wikipedia:pageid 50447142](https://en.wikipedia.org/wiki/Mac_OS_Celtic) | [source 1](https://www.unicode.org/Public/MAPPINGS/VENDORS/APPLE/CELTIC.TXT) [source 2](https://www.wikidata.org/wiki/Q25025172) |
| ENC-1203 | Mac OS Chinsimp | high | yes | `implemented` | [wikipedia:pageid 66154582](https://en.wikipedia.org/wiki/Mac_OS_Chinese_Simplified) | [source 1](https://www.unicode.org/Public/MAPPINGS/VENDORS/APPLE/CHINSIMP.TXT) |
| ENC-1207 | Mac OS Devanagari encoding | high | yes | `implemented` | [wikipedia:pageid 54554505](https://en.wikipedia.org/wiki/Mac_OS_Devanagari_encoding) | [source 1](https://www.wikidata.org/wiki/Q40887846) [source 2](https://www.unicode.org/Public/MAPPINGS/VENDORS/APPLE/DEVANAGA.TXT) |
| ENC-1210 | Mac OS Gaelic | high | yes | `implemented` | [wikipedia:pageid 53170849](https://en.wikipedia.org/wiki/Mac_OS_Gaelic) | [source 1](https://www.unicode.org/Public/MAPPINGS/VENDORS/APPLE/GAELIC.TXT) [source 2](https://www.wikidata.org/wiki/Q30591617) |
| ENC-1211 | Mac OS Georgian | high | yes | `implemented` | [wikipedia:pageid 57121892](https://en.wikipedia.org/wiki/Mac_OS_Georgian) | [source 1](https://www.evertype.com/standards/mappings/mac/GEORGIAN.TXT) |
| ENC-1212 | Mac OS Gujarati | high | yes | `implemented` | [wikipedia:pageid 63384990](https://en.wikipedia.org/wiki/Mac_OS_Gujarati) | [source 1](https://www.unicode.org/Public/MAPPINGS/VENDORS/APPLE/GUJARATI.TXT) |
| ENC-1213 | Mac OS Gurmukhi | high | yes | `implemented` | [wikipedia:pageid 63385148](https://en.wikipedia.org/wiki/Mac_OS_Gurmukhi) | [source 1](https://www.unicode.org/Public/MAPPINGS/VENDORS/APPLE/GURMUKHI.TXT) [source 2](https://www.wikidata.org/wiki/Q96418859) |
| ENC-1214 | Mac OS Inuit | high | yes | `implemented` | [wikipedia:pageid 57113711](https://en.wikipedia.org/wiki/Mac_OS_Inuit) | [source 1](https://www.unicode.org/Public/MAPPINGS/VENDORS/APPLE/INUIT.TXT) |
| ENC-1217 | Mac OS Keyboard encoding | high | yes | `implemented` | [wikipedia:pageid 59556947](https://en.wikipedia.org/wiki/Mac_OS_Keyboard_encoding) | [source 1](https://www.wikidata.org/wiki/Q60768047) [source 2](https://www.unicode.org/Public/MAPPINGS/VENDORS/APPLE/KEYBOARD.TXT) |
| ENC-1219 | Mac OS Maltese/Esperanto encoding | high | yes | `implemented` | [wikipedia:pageid 53226506](https://en.wikipedia.org/wiki/Mac_OS_Maltese/Esperanto_encoding) | [source 1](https://www.evertype.com/standards/mappings/mac/MALTESE.TXT) |
| ENC-1220 | Mac OS Ogham | high | yes | `implemented` | [wikipedia:pageid 57114522](https://en.wikipedia.org/wiki/Mac_OS_Ogham) | [source 1](https://www.evertype.com/standards/mappings/mac/OGHAM.TXT) |
| ENC-1221 | Mac OS Romanian | high | yes | `implemented` | [wikipedia:pageid 43717830](https://en.wikipedia.org/wiki/Mac_OS_Romanian_encoding) | [source 1](https://www.unicode.org/Public/MAPPINGS/VENDORS/APPLE/ROMANIAN.TXT) [source 2](https://www.wikidata.org/wiki/Q18154584) |
| ENC-1223 | Mac OS Sámi | high | yes | `implemented` | [wikipedia:pageid 53205070](https://en.wikipedia.org/wiki/Mac_OS_S%C3%A1mi) | [source 1](https://www.wikidata.org/wiki/Q30591942) [source 2](https://sourceware.org/git/?p=glibc.git;a=blob;f=localedata/charmaps/MAC-SAMI) |
| ENC-1224 | Mac OS Turkic Cyrillic | high | yes | `implemented` | [wikipedia:pageid 57114157](https://en.wikipedia.org/wiki/Mac_OS_Turkic_Cyrillic) | [source 1](https://www.evertype.com/standards/mappings/mac/TURKCYR.TXT) |
| ENC-1239 | MACINTOSH-LATIN | medium | yes | `implemented` | [wikipedia:pageid 53256237](https://en.wikipedia.org/wiki/Macintosh_Latin_encoding) | [source 1](https://www.kermitproject.org/k95charsets.html) [source 2](https://www.wikidata.org/wiki/Q30592409) |
| ENC-1240 | MacJapanese | medium | yes | `implemented` | [wikipedia:pageid 24941690](https://en.wikipedia.org/wiki/MacJapanese) | [source 1](https://www.wikidata.org/wiki/Q11232611) |
| ENC-1241 | MacKorean | candidate | yes | `implemented` | [wikipedia:pageid 66154563](https://en.wikipedia.org/wiki/MacKorean) | — |
| ENC-1252 | MARC-8 | high | yes | `implemented` | [wikipedia:pageid 24870820](https://en.wikipedia.org/wiki/MARC-8) | [source 1](https://en.wikipedia.org/wiki/List_of_information_system_character_sets) [source 2](https://www.loc.gov/marc/specifications/speccharmarc8.html) |
| ENC-1257 | MAZOVIA | medium | yes | `implemented` | [wikipedia:pageid 1451189](https://en.wikipedia.org/wiki/Mazovia_encoding) | [source 1](https://www.kermitproject.org/k95charsets.html) [source 2](https://www.wikidata.org/wiki/Q6798643) |
| ENC-1262 | MIK (character set) | candidate | yes | `implemented` | [wikipedia:pageid 4144007](https://en.wikipedia.org/wiki/MIK_%28character_set%29) | — |
| ENC-1266 | Modified UTF-8 | medium | yes | `implemented` | [wikipedia:pageid 27643973](https://en.wikipedia.org/wiki/Modified_UTF-8) | [source 1](https://docs.oracle.com/javase/8/docs/api/java/io/DataInput.html#modified-utf-8) |
| ENC-1272 | MSX character set | medium | yes | `implemented` | [wikipedia:pageid 54622638](https://en.wikipedia.org/wiki/MSX_character_set) | [source 1](https://www.wikidata.org/wiki/Q37823351) |
| ENC-1276 | MUTF-8 | candidate | yes | `implemented` | [wikipedia:pageid 50866213](https://en.wikipedia.org/wiki/MUTF-8) | — |
| ENC-1298 | OML encoding | high | yes | `implemented` | [wikipedia:pageid 54377384](https://en.wikipedia.org/wiki/OML_encoding) | [source 1](https://www.wikidata.org/wiki/Q30694484) [source 2](https://raw.githubusercontent.com/latex3/latex2e/7c8574ae28a5b257f7b92cc1e5e317255644e40d/required/latex-lab/testfiles-math/mathcapture-tag-001.tpf) |
| ENC-1299 | OMS encoding | high | yes | `implemented` | [wikipedia:pageid 54374854](https://en.wikipedia.org/wiki/OMS_encoding) | [source 1](https://www.wikidata.org/wiki/Q30676155) [source 2](https://raw.githubusercontent.com/latex3/latex2e/7c8574ae28a5b257f7b92cc1e5e317255644e40d/required/latex-lab/testfiles-math/mathcapture-tag-001.tpf) |
| ENC-1303 | OT1 encoding | high | yes | `implemented` | [wikipedia:pageid 54560666](https://en.wikipedia.org/wiki/OT1_encoding) | [source 1](https://tug.ctan.org/macros/latex/contrib/cmap.zip) |
| ENC-1308 | Perso-Arabic Script Code for Information Interchange | high | yes | `implemented` | [wikipedia:pageid 8014193](https://en.wikipedia.org/wiki/Perso-Arabic_Script_Code_for_Information_Interchange) | [source 1](https://www.wikidata.org/wiki/Q3900173) [source 2](https://www.cs.cmu.edu/afs/cs.cmu.edu/project/cmt-40/Nice/Urdu-MT/code/Tools/Encoding_Conversion/EncodingInfo/PASCIIStandard.pdf) |
| ENC-1309 | PETSCII | medium | yes | `implemented` | [wikipedia:pageid 469047](https://en.wikipedia.org/wiki/PETSCII) | [source 1](https://www.wikidata.org/wiki/Q1022979) |
| ENC-1314 | PostScript Latin 1 Encoding | high | yes | `implemented` | [wikipedia:pageid 56933980](https://en.wikipedia.org/wiki/PostScript_Latin_1_Encoding) | [source 1](https://www.adobe.com/jp/print/postscript/pdfs/PLRM.pdf) |
| ENC-1320 | Punycode | high | yes | `implemented` | [wikipedia:pageid 380586](https://en.wikipedia.org/wiki/Punycode) | [source 1](https://www.rfc-editor.org/rfc/rfc3492.html) |
| ENC-1342 | SCSU | high | yes | `implemented` | [wikipedia:pageid 653715](https://en.wikipedia.org/wiki/Standard_Compression_Scheme_for_Unicode) | [source 1](https://www.iana.org/assignments/character-sets/character-sets.xhtml) [source 2](https://raw.githubusercontent.com/unicode-org/icu/main/icu4c/source/data/mappings/convrtrs.txt) |
| ENC-1343 | SCSU (Unicode) | candidate | yes | `implemented` | [wikipedia:pageid 50625262](https://en.wikipedia.org/wiki/SCSU_%28Unicode%29) | — |
| ENC-1357 | SHORT-KOI | medium | yes | `implemented` | [wikipedia:pageid 1618676](https://en.wikipedia.org/wiki/KOI-7) | [source 1](https://www.kermitproject.org/k95charsets.html) [source 2](https://www.wikidata.org/wiki/Q441844) |
| ENC-1361 | Sinclair QL character set | candidate | yes | `implemented` | [wikipedia:pageid 58618477](https://en.wikipedia.org/wiki/Sinclair_QL_character_set) | — |
| ENC-1373 | Stanford Extended ASCII | high | yes | `implemented` | [wikipedia:pageid 53257205](https://en.wikipedia.org/wiki/Stanford_Extended_ASCII) | [source 1](https://www.rfc-editor.org/rfc/rfc698.txt) |
| ENC-1394 | Tamil All Character Encoding | high | yes | `implemented` | [wikipedia:pageid 41675931](https://en.wikipedia.org/wiki/TACE16) [wikipedia:pageid 41675869](https://en.wikipedia.org/wiki/Tamil_All_Character_Encoding) | [source 1](https://www.wikidata.org/wiki/Q15631296) [source 2](https://www.tamilvu.org/coresite/download/final_report.pdf) |
| ENC-1395 | Tamil Script Code for Information Interchange | high | yes | `implemented` | [wikipedia:pageid 794086](https://en.wikipedia.org/wiki/Tamil_Script_Code_for_Information_Interchange) | [source 1](https://www.wikidata.org/wiki/Q1414579) [source 2](https://sourceware.org/git/?p=glibc.git;a=blob;f=localedata/charmaps/TSCII) |
| ENC-1418 | TRS-80 character set | medium | yes | `implemented` | [wikipedia:pageid 54679235](https://en.wikipedia.org/wiki/TRS-80_character_set) | [source 1](https://www.wikidata.org/wiki/Q39088123) |
| ENC-1453 | UTF-1 | medium | yes | `implemented` | [wikipedia:pageid 2535122](https://en.wikipedia.org/wiki/UTF-1) | [source 1](https://www.wikidata.org/wiki/Q7875999) |
| ENC-1465 | UTF-5 | high | yes | `implemented` | [wikipedia:pageid 50618129](https://en.wikipedia.org/wiki/UTF-5) | [source 1](https://www.ietf.org/archive/id/draft-jseng-utf5-01.txt) |
| ENC-1466 | UTF-6 | high | yes | `implemented` | [wikipedia:pageid 50618133](https://en.wikipedia.org/wiki/UTF-6) | [source 1](https://www.ietf.org/archive/id/draft-ietf-idn-utf6-00.txt) |
| ENC-1478 | UTF-EBCDIC | medium | yes | `implemented` | [wikipedia:pageid 1328586](https://en.wikipedia.org/wiki/UTF-EBCDIC) | [source 1](https://www.wikidata.org/wiki/Q718092) |
| ENC-1486 | Ventura-International | high | yes | `implemented` | [wikipedia:pageid 54313265](https://en.wikipedia.org/wiki/Ventura_International) | [source 1](https://www.iana.org/assignments/character-sets/character-sets.xhtml) |
| ENC-1498 | VSCII | high | yes | `implemented` | [wikipedia:pageid 57558691](https://en.wikipedia.org/wiki/VSCII) | [source 1](https://www.wikidata.org/wiki/Q54810388) [source 2](https://itscj.ipsj.or.jp/ir/180.pdf) |
| ENC-1521 | Windows Polytonic Greek | high | yes | `implemented` | [wikipedia:pageid 64456013](https://en.wikipedia.org/wiki/Windows_Polytonic_Greek) | [source 1](https://www.wikidata.org/wiki/Q97182804) [source 2](https://en.wikipedia.org/w/index.php?oldid=1354794598) |
| ENC-1531 | Windows-1270 | high | yes | `implemented` | [wikipedia:pageid 53204999](https://en.wikipedia.org/wiki/Windows-1270) | [source 1](https://en.wikipedia.org/w/index.php?oldid=1340817319) |
| ENC-1541 | WTF-8 | medium | yes | `implemented` | [wikipedia:pageid 50628408](https://en.wikipedia.org/wiki/Wobbly_Transformation_Format) [wikipedia:pageid 50628399](https://en.wikipedia.org/wiki/WTF-8) | [source 1](https://simonsapin.github.io/wtf-8/) |
| ENC-1623 | ZX Spectrum +3 character set | high | yes | `implemented` | [wikipedia:pageid 54560151](https://en.wikipedia.org/wiki/ZX_Spectrum_%2B3_character_set) | [source 1](https://www.wikidata.org/wiki/Q30675535) [source 2](https://www.unicode.org/wg2/docs/n5028-19025-terminals-prop.pdf) |
| ENC-1624 | ZX Spectrum character set | medium | yes | `implemented` | [wikipedia:pageid 30871665](https://en.wikipedia.org/wiki/ZX_Spectrum_character_set) | [source 1](https://www.wikidata.org/wiki/Q3500910) |
| ENC-1625 | ZX80 character set | medium | yes | `implemented` | [wikipedia:pageid 44037965](https://en.wikipedia.org/wiki/ZX80_character_set) | [source 1](https://www.wikidata.org/wiki/Q22909911) |
| ENC-1626 | ZX81 character set | medium | yes | `implemented` | [wikipedia:pageid 49682604](https://en.wikipedia.org/wiki/ZX81_character_set) | [source 1](https://www.wikidata.org/wiki/Q24993618) |
