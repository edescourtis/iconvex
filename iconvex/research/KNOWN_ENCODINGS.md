# Known text encodings: public-source catalog

Generated: `2026-07-18T09:26:59+00:00`.

Best-effort exhaustive catalog of publicly documented text encodings, coded character
sets, code pages, Unicode transfer formats, historical terminal/telegraph sets, and
closely adjacent glyph or data syntaxes. Exact aliases remain preserved in CSV.

## Scope limits

Literal completeness is impossible: private and undocumented encodings exist; vendor
registries evolve; identical names can denote different mappings; different names can
denote the same mapping; and historical sources often specify a repertoire or component
set rather than a standalone byte-stream codec. `candidate` rows come from broad
encyclopedic category membership and require mapping-level validation before implementation.

Binary-to-text formats, compression, encryption, markup entities, natural-language writing
systems, and font files are excluded unless a cited source classifies their character-to-code
mapping as an encoding or coded character set.

## Summary

- Merged catalog entries: **1626**.
- High confidence: **1125**; medium: **283**; candidate: **218**.
- GNU libiconv 1.19-supported clusters: **200**; unsupported clusters: **1426**.
- High-confidence GNU libiconv-unsupported clusters: **925**.
- Iconvex-supported codec clusters: **1331**; unsupported codec/non-codec clusters: **295**.
- Implemented property-token mappings: **4**; property-token mapping gaps: **0**.
- Actionable codec gaps: **79**; research candidates: **121**; other audited non-codec/deferred records: **91**.
- GNU/Iconvex support uses conservative direct alias matching against GNU codec anchors.
  Iconvex-only external package codecs are matched by explicit audited keys.
  Ambiguous aliases and transitive alias bridges stay separate.
  Audited non-codecs are explained in `NON_CODEC_DISPOSITIONS.md`;
  `codec_gap` rows are codec targets and `property_token_mapping_gap` rows
  are property-token mapping targets.

## Focused comparisons

- [Direct Wikipedia character-set clusters absent from GNU libiconv 1.19](WIKIPEDIA_MISSING_FROM_GNU.md)
  ([machine-readable CSV](WIKIPEDIA_MISSING_FROM_GNU.csv)).

## Sources

| Source | Raw records | Description |
|---|---:|---|
| `iana` | 258 | IANA Character Sets registry |
| `whatwg` | 40 | WHATWG Encoding Standard |
| `gnu_libiconv` | 200 | GNU libiconv 1.19 fixed definitions and locale adapters |
| `glibc` | 272 | GNU C Library gconv module registry |
| `icu` | 365 | ICU converter aliases |
| `openjdk` | 175 | OpenJDK charset mapping registry |
| `microsoft` | 152 | Microsoft code-page identifiers |
| `ibm_i` | 236 | IBM i defined CCSIDs |
| `iso_ir` | 152 | ISO International Register of coded character sets |
| `rfc1345` | 145 | RFC 1345 charset tables |
| `unicode_mappings` | 110 | Unicode vendor and obsolete mapping archives |
| `python` | 113 | Python standard codecs |
| `kermit` | 91 | Kermit 95 legacy/terminal character sets |
| `wikidata` | 362 | Wikidata instances of character-encoding subclasses |
| `wikipedia_historical` | 23 | Wikipedia historical information-system charset inventory |
| `punched_cards` | 14 | University of Iowa historical punched-card code inventory |
| `wikipedia` | 468 | English Wikipedia Character sets category tree |
| `supplement` | 134 | Named gaps from vendor specifications and RFCs |

## Complete merged catalog

| ID | Name | Kind(s) | Confidence | GNU 1.19 | Iconvex | Disposition | Sources |
|---|---|---|:---:|:---:|:---:|---|---|
| ENC-0001 | `7-bit Arabic Code for Information Interchange, Arab standard ASMO-449, ISO 9036` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-0002 | `ABC 800` | source_qualified_seven_bit_character_encoding, wikipedia_character_set_page | high | no | yes | implemented | wikipedia, supplement |
| ENC-0003 | `ABICOMP character set` | single_byte_character_encoding, wikidata_characterencoding, wikipedia_character_set_page | high | no | yes | implemented | wikidata, wikipedia, supplement |
| ENC-0004 | `Adobe-Japan1` | wikidata_codedcharacterset | medium | no | no | repertoire_profile | wikidata |
| ENC-0005 | `Adobe-Standard-Encoding` | iana_registered_charset, unicode_mapping_table, wikidata_characterencoding | high | no | yes | implemented | iana, unicode_mappings, wikidata |
| ENC-0006 | `Adobe-Symbol-Encoding` | iana_registered_charset, unicode_mapping_table | high | no | yes | implemented | iana, unicode_mappings |
| ENC-0007 | `Advanced Video Attribute Terminal Assembler and Recreator` | wikidata_characterencoding | medium | no | no | terminal_protocol | wikidata |
| ENC-0008 | `AIS6` | maritime_telecom_character_encoding | high | no | yes | implemented | supplement |
| ENC-0009 | `aix-IBM_udcJP-4.3.6` | icu_converter | high | no | yes | implemented | icu |
| ENC-0010 | `ALCOR` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0011 | `alphanumeric` | wikidata_characterencoding | medium | no | no | repertoire_abstraction | wikidata |
| ENC-0012 | `Alternate Primary Graphic Set No. 1 CSA Standard Z 243.4-1985` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-0013 | `Alternate Primary Graphic Set No.2 CSA Standard Z 243.4-1985` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-0014 | `American National Standard Extended Latin Alphabet Coded Character Set for Bibliographic Use (ANSEL)` | bibliographic_character_set, iso_ir_coded_character_set, wikidata_codedcharacterset, wikipedia_character_set_page | high | no | yes | implemented | iso_ir, wikidata, wikipedia, supplement |
| ENC-0015 | `Amiga-1251` | iana_registered_charset | high | no | yes | implemented | iana |
| ENC-0016 | `Amstrad CP/M Plus character set` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-0017 | `Amstrad CPC character set` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-0018 | `ANSI_X3.110` | glibc_gconv_codec | high | no | yes | implemented | glibc |
| ENC-0019 | `ANSI_X3.110-1983` | iana_registered_charset, rfc1345_charset | high | no | yes | implemented | iana, rfc1345 |
| ENC-0020 | `APL Character Set, Canadian APL Working Group` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-0021 | `APL-ISO-IR-68` | unicode_mapping_table | high | no | yes | implemented | unicode_mappings |
| ENC-0022 | `APL-ISO-IR-68-2004` | unicode_mapping_table | high | no | yes | implemented | unicode_mappings |
| ENC-0023 | `Apple I character set` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0024 | `Apple II character set` | wikidata_characterencoding, wikipedia_character_set_page | medium | no | yes | implemented | wikidata, wikipedia |
| ENC-0025 | `Arabic Character Set CODAR-U IERA (Morocco)` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-0026 | `Arabic/French/German Set` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-0027 | `ARIB STD B24 character set` | wikidata_characterencoding, wikipedia_character_set_page | medium | no | no | codec_gap | wikidata, wikipedia |
| ENC-0028 | `ArmSCII` | wikipedia_character_set_page | candidate | no | no | encoding_family | wikipedia |
| ENC-0029 | `ARMSCII-8` | glibc_gconv_codec, gnu_fixed_codec | high | yes | yes | implemented | gnu_libiconv, glibc |
| ENC-0030 | `ASMO_449` | glibc_gconv_codec, iana_registered_charset, rfc1345_charset, wikidata_codepage, wikipedia_character_set_page | high | no | yes | implemented | iana, glibc, rfc1345, wikidata, wikipedia |
| ENC-0031 | `Atari ST character set` | wikidata_characterencoding, wikipedia_character_set_page | medium | no | yes | implemented | wikidata, wikipedia |
| ENC-0032 | `ATARIST` | gnu_fixed_codec, unicode_mapping_table | high | yes | yes | implemented | gnu_libiconv, unicode_mappings |
| ENC-0033 | `ATASCII` | legacy_computer_encoding, wikipedia_character_set_page | medium | no | yes | implemented | wikipedia, supplement |
| ENC-0034 | `Audio Data Syntax of CCITT Rec. T.101` | iso_ir_coding_system | high | no | no | non_text_coding_system | iso_ir |
| ENC-0035 | `Bangladesh Standard Code for Information Interchange` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0036 | `base 45` | wikidata_characterencoding | medium | no | no | binary_transform | wikidata |
| ENC-0037 | `base64-codec` | python_codec | medium | no | no | binary_transform | python |
| ENC-0038 | `Basic Box Drawings Set` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-0039 | `Basic Cyrillic Character Set for 8-bit Codes` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-0040 | `Basic Cyrillic Character Set, ECMA (Cii Honeywell-Bull) and ISO 5427` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-0041 | `Baudot code` | telegraph_code, wikipedia_character_set_page | medium | no | yes | implemented | wikipedia, supplement |
| ENC-0042 | `Baudot code / ITA1` | historical_information_system_encoding | medium | no | yes | implemented | wikipedia_historical |
| ENC-0043 | `BCD (character encoding)` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0044 | `BCDIC` | historical_information_system_encoding | medium | no | no | encoding_family | wikipedia_historical |
| ENC-0045 | `bestfit1250` | unicode_mapping_table | high | no | yes | implemented | unicode_mappings |
| ENC-0046 | `bestfit1251` | unicode_mapping_table | high | no | yes | implemented | unicode_mappings |
| ENC-0047 | `bestfit1252` | unicode_mapping_table | high | no | yes | implemented | unicode_mappings |
| ENC-0048 | `bestfit1253` | unicode_mapping_table | high | no | yes | implemented | unicode_mappings |
| ENC-0049 | `bestfit1254` | unicode_mapping_table | high | no | yes | implemented | unicode_mappings |
| ENC-0050 | `bestfit1255` | unicode_mapping_table | high | no | yes | implemented | unicode_mappings |
| ENC-0051 | `bestfit1256` | unicode_mapping_table | high | no | yes | implemented | unicode_mappings |
| ENC-0052 | `bestfit1257` | unicode_mapping_table | high | no | yes | implemented | unicode_mappings |
| ENC-0053 | `bestfit1258` | unicode_mapping_table | high | no | yes | implemented | unicode_mappings |
| ENC-0054 | `bestfit1361` | unicode_mapping_table | high | no | yes | implemented | unicode_mappings |
| ENC-0055 | `bestfit874` | unicode_mapping_table | high | no | yes | implemented | unicode_mappings |
| ENC-0056 | `bestfit932` | unicode_mapping_table | high | no | yes | implemented | unicode_mappings |
| ENC-0057 | `bestfit936` | unicode_mapping_table | high | no | yes | implemented | unicode_mappings |
| ENC-0058 | `bestfit949` | unicode_mapping_table | high | no | yes | implemented | unicode_mappings |
| ENC-0059 | `bestfit950` | unicode_mapping_table | high | no | yes | implemented | unicode_mappings |
| ENC-0060 | `Big5` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, icu_converter, microsoft_code_page, openjdk_charset, python_codec, unicode_mapping_table, web_encoding, wikidata_variablewidthcharacterencoding, wikipedia_character_set_page | high | yes | yes | implemented | iana, whatwg, gnu_libiconv, glibc, icu, openjdk, microsoft, unicode_mappings, python, wikidata, wikipedia |
| ENC-0061 | `BIG5-2003` | gnu_fixed_codec | high | yes | yes | implemented | gnu_libiconv |
| ENC-0062 | `Big5-HKSCS` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, icu_converter, openjdk_charset, python_codec, wikipedia_character_set_page | high | yes | yes | implemented | iana, gnu_libiconv, glibc, icu, openjdk, python, wikipedia |
| ENC-0063 | `BIG5-HKSCS:1999` | gnu_fixed_codec, wikipedia_character_set_page | high | yes | yes | implemented | gnu_libiconv, wikipedia |
| ENC-0064 | `BIG5-HKSCS:2001` | gnu_fixed_codec, openjdk_charset, wikipedia_character_set_page | high | yes | yes | implemented | gnu_libiconv, openjdk, wikipedia |
| ENC-0065 | `BIG5-HKSCS:2004` | gnu_fixed_codec, wikipedia_character_set_page | high | yes | yes | implemented | gnu_libiconv, wikipedia |
| ENC-0066 | `Big5hk` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-0067 | `Bitstream International Character Set` | wikidata_characterencoding, wikipedia_character_set_page | medium | no | no | codec_gap | wikidata, wikipedia |
| ENC-0068 | `Blissymbol Graphic Character Set` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-0069 | `BOCU-1` | iana_registered_charset, icu_converter, wikipedia_character_set_page | high | no | yes | implemented | iana, icu, wikipedia |
| ENC-0070 | `Bookshelf Symbol 7` | wikidata_dingbattypeface | medium | no | no | font_identity | wikidata |
| ENC-0071 | `Box-drawing characters` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0072 | `Braille` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0073 | `Braille ASCII` | braille_encoding, historical_information_system_encoding | medium | no | yes | implemented | wikipedia_historical, supplement |
| ENC-0074 | `Braille code` | tactile_character_code | medium | no | no | writing_system | supplement |
| ENC-0075 | `BraSCII` | single_byte_character_encoding, wikidata_characterencoding, wikipedia_character_set_page | high | no | yes | implemented | wikidata, wikipedia, supplement |
| ENC-0076 | `BRF` | glibc_gconv_codec, iana_registered_charset | high | no | yes | implemented | iana, glibc |
| ENC-0077 | `BRITISH` | national_replacement_set | medium | no | yes | implemented | kermit |
| ENC-0078 | `BS_4730` | glibc_gconv_codec, iana_registered_charset, rfc1345_charset | high | no | yes | implemented | iana, glibc, rfc1345 |
| ENC-0079 | `BS_viewdata` | iana_registered_charset, rfc1345_charset | high | no | yes | implemented | iana, rfc1345 |
| ENC-0080 | `BSCII` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0081 | `BULGARIA-PC` | pc_code_page | medium | no | yes | implemented | kermit |
| ENC-0082 | `bz2-codec` | python_codec | medium | no | no | compression_transform | python |
| ENC-0083 | `C99` | gnu_fixed_codec | high | yes | yes | implemented | gnu_libiconv |
| ENC-0084 | `Caret notation` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0085 | `Cariadings` | wikidata_dingbattypeface | medium | no | no | font_identity | wikidata |
| ENC-0086 | `Casio calculator character sets` | wikidata_characterencoding, wikipedia_character_set_page | medium | no | no | encoding_family | wikidata, wikipedia |
| ENC-0087 | `CCIR 476` | maritime_telegraph_code, wikidata_characterencoding, wikipedia_character_set_page | high | no | yes | implemented | wikidata, wikipedia, supplement |
| ENC-0088 | `CCITT 2` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-0089 | `CCITT Hebrew Supplementary Set` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-0090 | `CDC display code` | historical_information_system_encoding, six_bit_character_code, wikidata_characterencoding, wikipedia_character_set_page | high | no | yes | implemented | wikidata, wikipedia_historical, wikipedia, supplement |
| ENC-0091 | `CDC punched-card BCD` | historical_punched_card_encoding | medium | no | no | codec_gap | punched_cards |
| ENC-0092 | `CDC punched-card BCD (Iowa reconstruction)` | source_qualified_punched_card_encoding | medium | no | yes | implemented | supplement |
| ENC-0093 | `CDC-167-BCD-HOLLERITH-1965` | punched_card_encoding | high | no | yes | implemented | supplement |
| ENC-0094 | `CDC-6000-STANDARD-HOLLERITH-1970` | punched_card_encoding | high | no | yes | implemented | supplement |
| ENC-0095 | `CER-GS` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0096 | `CESU-8` | iana_registered_charset, icu_converter, openjdk_charset, wikidata_unicodeencoding, wikipedia_character_set_page | high | no | yes | implemented | iana, icu, openjdk, wikidata, wikipedia |
| ENC-0097 | `CHAR` | locale_abi_adapter | high | yes | no | platform_adapter | gnu_libiconv |
| ENC-0098 | `Character Set for African Languages, DIN 31625 and ISO 6438` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-0099 | `Character Set for Greek, ECMA (Olivetti)` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-0100 | `Character Set for Viewdata and Teletext (UK)` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-0101 | `Character Set of Cuba` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-0102 | `Chinese Character Code for Information Interchange` | wikidata_codedcharacterset, wikipedia_character_set_page | medium | no | no | codec_gap | wikidata, wikipedia |
| ENC-0103 | `Chinese character encoding` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-0104 | `Chinese Standard Interchange Code - Set 1, CNS 11643-1992` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-0105 | `Chinese Standard Interchange Code - Set 2, CNS 11643-1992` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-0106 | `Chinese Standard Interchange Code - Set 3, CNS 11643-1992` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-0107 | `Chinese Standard Interchange Code - Set 4, CNS 11643-1992` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-0108 | `Chinese Standard Interchange Code - Set 5, CNS 11643-1992` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-0109 | `Chinese Standard Interchange Code - Set 6, CNS 11643-1992` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-0110 | `Chinese Standard Interchange Code - Set 7, CNS 11643-1992` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-0111 | `Chinese telegraph code` | historical_information_system_encoding, telegraph_code, wikidata_characterencoding | medium | no | no | codec_gap | wikidata, wikipedia_historical, supplement |
| ENC-0112 | `CJK characters` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0113 | `CJK Unified Ideographs` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0114 | `Cluff–Foster–Idelson code` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0115 | `Code page 0` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0116 | `Code page 10000` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-0117 | `Code page 10004` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-0118 | `Code page 10006` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-0119 | `Code page 10007` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-0120 | `Code page 10017` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-0121 | `Code page 10029` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-0122 | `Code page 1004` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-0123 | `Code page 1006` | wikidata_codepage, wikipedia_character_set_page | medium | no | yes | implemented | wikidata, wikipedia |
| ENC-0124 | `Code page 10079` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-0125 | `Code page 1008` | wikidata_codepage, wikipedia_character_set_page | medium | no | yes | implemented | wikidata, wikipedia |
| ENC-0126 | `Code page 10081` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-0127 | `Code page 10082` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-0128 | `Code page 1009` | wikidata_codepage, wikipedia_character_set_page | medium | no | yes | implemented | wikidata, wikipedia |
| ENC-0129 | `Code page 1010` | wikidata_codepage, wikipedia_character_set_page | medium | no | yes | implemented | wikidata, wikipedia |
| ENC-0130 | `Code page 1012` | wikidata_codepage, wikipedia_character_set_page | medium | no | yes | implemented | wikidata, wikipedia |
| ENC-0131 | `Code page 1013` | wikidata_codepage, wikipedia_character_set_page | medium | no | yes | implemented | wikidata, wikipedia |
| ENC-0132 | `Code page 1014` | wikidata_codepage, wikipedia_character_set_page | medium | no | yes | implemented | wikidata, wikipedia |
| ENC-0133 | `Code page 1015` | wikidata_codepage, wikipedia_character_set_page | medium | no | yes | implemented | wikidata, wikipedia |
| ENC-0134 | `Code page 1016` | wikidata_codepage, wikipedia_character_set_page | medium | no | yes | implemented | wikidata, wikipedia |
| ENC-0135 | `Code page 1017` | wikidata_codepage, wikipedia_character_set_page | medium | no | yes | implemented | wikidata, wikipedia |
| ENC-0136 | `Code page 1018` | wikidata_codepage, wikipedia_character_set_page | medium | no | yes | implemented | wikidata, wikipedia |
| ENC-0137 | `Code page 1019` | wikidata_codepage, wikipedia_character_set_page | medium | no | yes | implemented | wikidata, wikipedia |
| ENC-0138 | `Code page 1020` | wikidata_codepage, wikipedia_character_set_page | medium | no | yes | implemented | wikidata, wikipedia |
| ENC-0139 | `Code page 1021` | wikidata_codepage, wikipedia_character_set_page | medium | no | yes | implemented | wikidata, wikipedia |
| ENC-0140 | `Code page 1023` | wikidata_codepage, wikipedia_character_set_page | medium | no | yes | implemented | wikidata, wikipedia |
| ENC-0141 | `Code page 1036` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0142 | `Code page 1038` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0143 | `Code page 1040` | wikidata_codepage, wikipedia_character_set_page | medium | no | yes | implemented | wikidata, wikipedia |
| ENC-0144 | `Code page 1042` | wikidata_codepage | medium | no | yes | implemented | wikidata |
| ENC-0145 | `Code page 1043` | wikidata_codepage, wikipedia_character_set_page | medium | no | yes | implemented | wikidata, wikipedia |
| ENC-0146 | `Code page 1046` | wikidata_codepage, wikipedia_character_set_page | medium | no | yes | implemented | wikidata, wikipedia |
| ENC-0147 | `Code page 1050` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0148 | `Code page 1051` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-0149 | `Code page 1058` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0150 | `Code page 1089` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-0151 | `Code page 1090` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0152 | `Code page 1093` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0153 | `Code page 1098` | wikidata_doscodepage, wikipedia_character_set_page | medium | no | yes | implemented | wikidata, wikipedia |
| ENC-0154 | `Code page 1100` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-0155 | `Code page 1101` | wikidata_codepage, wikipedia_character_set_page | medium | no | yes | implemented | wikidata, wikipedia |
| ENC-0156 | `Code page 1102` | wikidata_codepage, wikipedia_character_set_page | medium | no | yes | implemented | wikidata, wikipedia |
| ENC-0157 | `Code page 1103` | wikidata_codepage, wikipedia_character_set_page | medium | no | yes | implemented | wikidata, wikipedia |
| ENC-0158 | `Code page 1104` | wikidata_codepage, wikipedia_character_set_page | medium | no | yes | implemented | wikidata, wikipedia |
| ENC-0159 | `Code page 1105` | wikidata_codepage, wikipedia_character_set_page | medium | no | yes | implemented | wikidata, wikipedia |
| ENC-0160 | `Code page 1106` | wikidata_codepage, wikipedia_character_set_page | medium | no | yes | implemented | wikidata, wikipedia |
| ENC-0161 | `Code page 1107` | wikidata_codepage, wikipedia_character_set_page | medium | no | yes | implemented | wikidata, wikipedia |
| ENC-0162 | `Code page 1111` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0163 | `Code page 1114` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-0164 | `Code page 1115` | wikidata_codepage, wikipedia_character_set_page | medium | no | yes | implemented | wikidata, wikipedia |
| ENC-0165 | `Code page 1116` | wikidata_doscodepage, wikipedia_character_set_page | medium | no | no | codec_gap | wikidata, wikipedia |
| ENC-0166 | `Code page 1117` | wikidata_doscodepage, wikipedia_character_set_page | medium | no | no | codec_gap | wikidata, wikipedia |
| ENC-0167 | `Code page 1118` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0168 | `Code page 1124` | wikidata_codepage, wikipedia_character_set_page | medium | no | yes | implemented | wikidata, wikipedia |
| ENC-0169 | `Code page 1127` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-0170 | `Code page 1129` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-0171 | `Code page 1133` | wikidata_codepage, wikipedia_character_set_page | medium | no | yes | implemented | wikidata, wikipedia |
| ENC-0172 | `Code page 1163` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-0173 | `Code page 1167` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-0174 | `Code page 1168` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-0175 | `Code page 1200` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0176 | `Code page 12000` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0177 | `Code page 1201` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-0178 | `Code page 1275` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-0179 | `Code page 1276` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-0180 | `Code page 1287` | wikidata_codepage, wikipedia_character_set_page | medium | no | yes | implemented | wikidata, wikipedia |
| ENC-0181 | `Code page 1288` | wikidata_codepage, wikipedia_character_set_page | medium | no | yes | implemented | wikidata, wikipedia |
| ENC-0182 | `Code page 165` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0183 | `Code page 17248` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-0184 | `Code page 20105` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-0185 | `Code page 20106` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-0186 | `Code page 20127` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-0187 | `Code page 20261` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-0188 | `Code page 20269` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-0189 | `Code page 20866` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-0190 | `Code page 21866` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-0191 | `Code page 259` | wikidata_codepage | medium | no | yes | implemented | wikidata |
| ENC-0192 | `Code page 28591` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-0193 | `Code page 28592` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-0194 | `Code page 28593` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-0195 | `Code page 28594` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-0196 | `Code page 28595` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-0197 | `Code page 28596` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-0198 | `Code page 28597` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-0199 | `Code page 28598` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-0200 | `Code page 28599` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-0201 | `Code page 28600` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0202 | `Code page 28601` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0203 | `Code page 28602` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0204 | `Code page 28603` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-0205 | `Code page 28604` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0206 | `Code page 28605` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-0207 | `Code page 28606` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0208 | `Code page 293` | wikidata_aplcodepage, wikidata_ebcdiccodepage, wikipedia_character_set_page | medium | no | yes | implemented | wikidata, wikipedia |
| ENC-0209 | `Code page 310` | wikidata_aplcodepage, wikidata_ebcdiccodepage, wikipedia_character_set_page | medium | no | no | codec_gap | wikidata, wikipedia |
| ENC-0210 | `Code page 351` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0211 | `Code page 353` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0212 | `Code page 354` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0213 | `Code page 355` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0214 | `Code page 357` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0215 | `Code page 358` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0216 | `Code page 359` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0217 | `Code page 360` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0218 | `Code page 367` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-0219 | `Code page 38596` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0220 | `Code page 38598` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-0221 | `Code page 437` | wikidata_doscodepage, wikipedia_character_set_page | medium | no | yes | implemented | wikidata, wikipedia |
| ENC-0222 | `Code page 57344` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0223 | `Code page 61439` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0224 | `Code page 65280` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0225 | `Code page 65533` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0226 | `Code page 65534` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0227 | `Code page 65535` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0228 | `Code page 667` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-0229 | `Code page 708` | wikidata_doscodepage | medium | no | yes | implemented | wikidata |
| ENC-0230 | `Code page 720` | wikidata_codepage | medium | no | yes | implemented | wikidata |
| ENC-0231 | `Code page 737` | wikidata_doscodepage, wikipedia_character_set_page | medium | no | yes | implemented | wikidata, wikipedia |
| ENC-0232 | `Code page 771` | wikidata_doscodepage, wikipedia_character_set_page | medium | no | yes | implemented | wikidata, wikipedia |
| ENC-0233 | `Code page 772` | wikidata_doscodepage, wikipedia_character_set_page | medium | no | yes | implemented | wikidata, wikipedia |
| ENC-0234 | `Code page 773` | wikidata_doscodepage | medium | no | yes | implemented | wikidata |
| ENC-0235 | `Code page 774` | wikidata_doscodepage, wikipedia_character_set_page | medium | no | yes | implemented | wikidata, wikipedia |
| ENC-0236 | `Code page 775` | wikidata_doscodepage | medium | no | yes | implemented | wikidata |
| ENC-0237 | `Code page 790` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0238 | `Code page 806` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-0239 | `Code page 808` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-0240 | `Code page 813` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-0241 | `Code page 819` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-0242 | `code page 850` | wikidata_doscodepage, wikipedia_character_set_page | medium | no | yes | implemented | wikidata, wikipedia |
| ENC-0243 | `Code page 851` | wikidata_doscodepage | medium | no | yes | implemented | wikidata |
| ENC-0244 | `Code page 852` | wikidata_doscodepage | medium | no | yes | implemented | wikidata |
| ENC-0245 | `Code page 853` | wikidata_doscodepage | medium | no | yes | implemented | wikidata |
| ENC-0246 | `Code page 855` | wikidata_doscodepage | medium | no | yes | implemented | wikidata |
| ENC-0247 | `Code page 856` | wikidata_doscodepage | medium | no | yes | implemented | wikidata |
| ENC-0248 | `Code page 857` | wikidata_doscodepage | medium | no | yes | implemented | wikidata |
| ENC-0249 | `Code page 858` | wikidata_doscodepage | medium | no | yes | implemented | wikidata |
| ENC-0250 | `Code page 859` | wikidata_doscodepage | medium | no | yes | implemented | wikidata |
| ENC-0251 | `Code page 860` | wikidata_doscodepage | medium | no | yes | implemented | wikidata |
| ENC-0252 | `Code page 861` | wikidata_doscodepage, wikipedia_character_set_page | medium | no | yes | implemented | wikidata, wikipedia |
| ENC-0253 | `Code page 862` | wikidata_doscodepage, wikipedia_character_set_page | medium | no | yes | implemented | wikidata, wikipedia |
| ENC-0254 | `Code page 863` | wikidata_doscodepage, wikipedia_character_set_page | medium | no | yes | implemented | wikidata, wikipedia |
| ENC-0255 | `Code page 864` | wikidata_doscodepage, wikipedia_character_set_page | medium | no | yes | implemented | wikidata, wikipedia |
| ENC-0256 | `Code page 865` | wikidata_doscodepage, wikipedia_character_set_page | medium | no | yes | implemented | wikidata, wikipedia |
| ENC-0257 | `code page 866` | wikidata_doscodepage, wikipedia_character_set_page | medium | no | yes | implemented | wikidata, wikipedia |
| ENC-0258 | `Code page 867` | wikidata_doscodepage, wikipedia_character_set_page | medium | no | yes | implemented | wikidata, wikipedia |
| ENC-0259 | `Code page 868` | wikidata_doscodepage, wikipedia_character_set_page | medium | no | yes | implemented | wikidata, wikipedia |
| ENC-0260 | `Code page 869` | wikidata_doscodepage, wikipedia_character_set_page | medium | no | yes | implemented | wikidata, wikipedia |
| ENC-0261 | `Code page 874` | wikidata_doscodepage, wikidata_windowscodepage | medium | no | yes | implemented | wikidata |
| ENC-0262 | `Code page 878` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-0263 | `Code page 895` | wikidata_codepage, wikipedia_character_set_page | medium | no | yes | implemented | wikidata, wikipedia |
| ENC-0264 | `Code page 896` | wikidata_codepage, wikipedia_character_set_page | medium | no | yes | implemented | wikidata, wikipedia |
| ENC-0265 | `Code page 897` | wikidata_doscodepage | medium | no | yes | implemented | wikidata |
| ENC-0266 | `Code page 899` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0267 | `Code page 900` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0268 | `Code page 901` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-0269 | `Code page 902` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-0270 | `Code page 903` | wikidata_codepage | medium | no | yes | implemented | wikidata |
| ENC-0271 | `Code page 904` | wikidata_codepage, wikipedia_character_set_page | medium | no | yes | implemented | wikidata, wikipedia |
| ENC-0272 | `Code page 907` | wikidata_aplcodepage, wikidata_doscodepage, wikipedia_character_set_page | medium | no | no | codec_gap | wikidata, wikipedia |
| ENC-0273 | `Code page 912` | wikidata_codepage, wikipedia_character_set_page | medium | no | yes | implemented | wikidata, wikipedia |
| ENC-0274 | `Code page 913` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-0275 | `Code page 914` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-0276 | `Code page 915` | wikidata_codepage, wikipedia_character_set_page | medium | no | yes | implemented | wikidata, wikipedia |
| ENC-0277 | `Code page 916` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-0278 | `Code page 919` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0279 | `Code page 920` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-0280 | `Code page 921` | wikidata_codepage, wikipedia_character_set_page | medium | no | yes | implemented | wikidata, wikipedia |
| ENC-0281 | `Code page 922` | wikidata_codepage, wikipedia_character_set_page | medium | no | yes | implemented | wikidata, wikipedia |
| ENC-0282 | `Code page 923` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-0283 | `Code page 932` | wikidata_dbcs, wikidata_doscodepage, wikidata_variablewidthcharacterencoding, wikidata_windowscodepage | medium | no | yes | implemented | wikidata |
| ENC-0284 | `Code page 932 (Microsoft Windows)` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0285 | `Code page 936` | wikidata_dbcs, wikidata_doscodepage, wikidata_variablewidthcharacterencoding, wikidata_windowscodepage | medium | no | yes | implemented | wikidata |
| ENC-0286 | `Code page 936 (IBM)` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0287 | `Code page 936 (Microsoft Windows)` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0288 | `Code page 942` | wikidata_codepage, wikipedia_character_set_page | medium | no | yes | implemented | wikidata, wikipedia |
| ENC-0289 | `Code page 949` | wikidata_dbcs, wikidata_doscodepage, wikidata_variablewidthcharacterencoding, wikidata_windowscodepage | medium | no | yes | implemented | wikidata |
| ENC-0290 | `Code page 950` | wikidata_dbcs, wikidata_doscodepage, wikidata_variablewidthcharacterencoding, wikidata_windowscodepage, wikipedia_character_set_page | medium | no | yes | implemented | wikidata, wikipedia |
| ENC-0291 | `Code page 951` | wikidata_codepage, wikipedia_character_set_page | medium | no | yes | implemented | wikidata, wikipedia |
| ENC-0292 | `Code page 952` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-0293 | `Code page 953` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-0294 | `Code page 954` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-0295 | `Code page 955` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-0296 | `Code page 970` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-0297 | `Code page 971` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-0298 | `Code page 991` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0299 | `Code page 999` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0300 | `Commodore Amiga` | wikidata_characterencoding, wikidata_codedcharacterset | medium | no | no | codec_gap | wikidata |
| ENC-0301 | `Compatibility Encoding Scheme for UTF-16` | wikipedia_character_set_page | candidate | no | no | encoding_family | wikipedia |
| ENC-0302 | `Compucolor II character set` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0303 | `Cork encoding` | font_glyph_encoding, wikidata_characterencoding, wikipedia_character_set_page | high | no | yes | implemented | wikidata, wikipedia, supplement |
| ENC-0304 | `CP037` | unicode_mapping_table | high | no | yes | implemented | unicode_mappings |
| ENC-0305 | `CP10000` | vendor_8bit_set | medium | no | yes | implemented | kermit |
| ENC-0306 | `CP10007` | glibc_gconv_codec | high | no | yes | implemented | glibc |
| ENC-0307 | `CP1006` | unicode_mapping_table | high | no | yes | implemented | unicode_mappings |
| ENC-0308 | `cp1006` | python_codec | medium | no | yes | implemented | python |
| ENC-0309 | `cp1025` | microsoft_code_page | high | no | yes | implemented | microsoft |
| ENC-0310 | `CP1026` | unicode_mapping_table | high | no | yes | implemented | unicode_mappings |
| ENC-0311 | `CP1046` | glibc_gconv_codec, gnu_fixed_codec, ibm_ccsid, icu_converter, openjdk_charset | high | yes | yes | implemented | gnu_libiconv, glibc, icu, openjdk, ibm_i |
| ENC-0312 | `CP1051` | windows_code_page | medium | no | yes | implemented | kermit |
| ENC-0313 | `CP1089` | windows_code_page | medium | no | yes | implemented | kermit |
| ENC-0314 | `CP1124` | glibc_gconv_codec, gnu_fixed_codec, ibm_ccsid, icu_converter, openjdk_charset | high | yes | yes | implemented | gnu_libiconv, glibc, icu, openjdk, ibm_i |
| ENC-0315 | `CP1125` | gnu_fixed_codec, ibm_ccsid, icu_converter, python_codec | high | yes | yes | implemented | gnu_libiconv, icu, ibm_i, python |
| ENC-0316 | `CP1125` | glibc_gconv_codec | high | no | yes | implemented | glibc |
| ENC-0317 | `CP1129` | glibc_gconv_codec, gnu_fixed_codec, ibm_ccsid, icu_converter, openjdk_charset | high | yes | yes | implemented | gnu_libiconv, glibc, icu, openjdk, ibm_i |
| ENC-0318 | `CP1131` | gnu_fixed_codec, ibm_ccsid, icu_converter | high | yes | yes | implemented | gnu_libiconv, icu, ibm_i |
| ENC-0319 | `CP1133` | gnu_fixed_codec | high | yes | yes | implemented | gnu_libiconv |
| ENC-0320 | `CP1161` | glibc_gconv_codec, gnu_fixed_codec, icu_converter | high | yes | yes | implemented | gnu_libiconv, glibc, icu |
| ENC-0321 | `CP1162` | glibc_gconv_codec, gnu_fixed_codec, icu_converter | high | yes | yes | implemented | gnu_libiconv, glibc, icu |
| ENC-0322 | `CP1163` | glibc_gconv_codec, gnu_fixed_codec, icu_converter | high | yes | yes | implemented | gnu_libiconv, glibc, icu |
| ENC-0323 | `CP1250` | unicode_mapping_table | high | no | yes | implemented | unicode_mappings |
| ENC-0324 | `CP1250` | windows_code_page | medium | no | yes | implemented | kermit |
| ENC-0325 | `CP1251` | unicode_mapping_table | high | no | yes | implemented | unicode_mappings |
| ENC-0326 | `CP1251` | windows_code_page | medium | no | yes | implemented | kermit |
| ENC-0327 | `CP1252` | unicode_mapping_table | high | no | yes | implemented | unicode_mappings |
| ENC-0328 | `CP1252` | windows_code_page | medium | no | yes | implemented | kermit |
| ENC-0329 | `CP1253` | unicode_mapping_table | high | no | yes | implemented | unicode_mappings |
| ENC-0330 | `CP1253` | windows_code_page | medium | no | yes | implemented | kermit |
| ENC-0331 | `CP1254` | unicode_mapping_table | high | no | yes | implemented | unicode_mappings |
| ENC-0332 | `CP1254` | windows_code_page | medium | no | yes | implemented | kermit |
| ENC-0333 | `CP1255` | unicode_mapping_table | high | no | yes | implemented | unicode_mappings |
| ENC-0334 | `CP1255` | windows_code_page | medium | no | yes | implemented | kermit |
| ENC-0335 | `CP1256` | unicode_mapping_table | high | no | yes | implemented | unicode_mappings |
| ENC-0336 | `CP1256` | windows_code_page | medium | no | yes | implemented | kermit |
| ENC-0337 | `CP1257` | unicode_mapping_table | high | no | yes | implemented | unicode_mappings |
| ENC-0338 | `CP1257` | windows_code_page | medium | no | yes | implemented | kermit |
| ENC-0339 | `CP1258` | unicode_mapping_table | high | no | yes | implemented | unicode_mappings |
| ENC-0340 | `CP1258` | windows_code_page | medium | no | yes | implemented | kermit |
| ENC-0341 | `CP424` | unicode_mapping_table | high | no | yes | implemented | unicode_mappings |
| ENC-0342 | `CP437` | unicode_mapping_table | high | no | yes | implemented | unicode_mappings |
| ENC-0343 | `CP437` | pc_code_page | medium | no | yes | implemented | kermit |
| ENC-0344 | `CP500` | unicode_mapping_table | high | no | yes | implemented | unicode_mappings |
| ENC-0345 | `CP50220` | iana_registered_charset | high | no | no | codec_gap | iana |
| ENC-0346 | `CP51932` | iana_registered_charset | high | no | yes | implemented | iana |
| ENC-0347 | `cp720` | python_codec | medium | no | yes | implemented | python |
| ENC-0348 | `CP737` | gnu_fixed_codec | high | yes | yes | implemented | gnu_libiconv |
| ENC-0349 | `CP737` | glibc_gconv_codec | high | no | yes | implemented | glibc |
| ENC-0350 | `CP737` | unicode_mapping_table | high | no | yes | implemented | unicode_mappings |
| ENC-0351 | `cp737` | python_codec | medium | no | yes | implemented | python |
| ENC-0352 | `CP770` | glibc_gconv_codec | high | no | yes | implemented | glibc |
| ENC-0353 | `CP771` | glibc_gconv_codec | high | no | yes | implemented | glibc |
| ENC-0354 | `CP772` | glibc_gconv_codec | high | no | yes | implemented | glibc |
| ENC-0355 | `CP773` | glibc_gconv_codec | high | no | yes | implemented | glibc |
| ENC-0356 | `CP774` | glibc_gconv_codec | high | no | yes | implemented | glibc |
| ENC-0357 | `CP775` | unicode_mapping_table | high | no | yes | implemented | unicode_mappings |
| ENC-0358 | `CP813` | standard_8bit_set | medium | no | yes | implemented | kermit |
| ENC-0359 | `CP819` | standard_8bit_set | medium | no | yes | implemented | kermit |
| ENC-0360 | `CP850` | unicode_mapping_table | high | no | yes | implemented | unicode_mappings |
| ENC-0361 | `CP850` | pc_code_page | medium | no | yes | implemented | kermit |
| ENC-0362 | `CP852` | unicode_mapping_table | high | no | yes | implemented | unicode_mappings |
| ENC-0363 | `CP852` | pc_code_page | medium | no | yes | implemented | kermit |
| ENC-0364 | `CP853` | gnu_fixed_codec | high | yes | yes | implemented | gnu_libiconv |
| ENC-0365 | `CP855` | unicode_mapping_table | high | no | yes | implemented | unicode_mappings |
| ENC-0366 | `CP855` | pc_code_page | medium | no | yes | implemented | kermit |
| ENC-0367 | `CP856` | glibc_gconv_codec, gnu_fixed_codec, icu_converter, openjdk_charset | high | yes | yes | implemented | gnu_libiconv, glibc, icu, openjdk |
| ENC-0368 | `CP856` | unicode_mapping_table | high | no | yes | implemented | unicode_mappings |
| ENC-0369 | `cp856` | python_codec | medium | no | yes | implemented | python |
| ENC-0370 | `CP857` | unicode_mapping_table | high | no | yes | implemented | unicode_mappings |
| ENC-0371 | `CP857` | pc_code_page | medium | no | yes | implemented | kermit |
| ENC-0372 | `CP858` | gnu_fixed_codec | high | yes | yes | implemented | gnu_libiconv |
| ENC-0373 | `CP858` | pc_code_page | medium | no | yes | implemented | kermit |
| ENC-0374 | `cp858` | python_codec | medium | no | yes | implemented | python |
| ENC-0375 | `CP860` | unicode_mapping_table | high | no | yes | implemented | unicode_mappings |
| ENC-0376 | `CP861` | unicode_mapping_table | high | no | yes | implemented | unicode_mappings |
| ENC-0377 | `CP862` | unicode_mapping_table | high | no | yes | implemented | unicode_mappings |
| ENC-0378 | `CP862` | pc_code_page | medium | no | yes | implemented | kermit |
| ENC-0379 | `CP863` | unicode_mapping_table | high | no | yes | implemented | unicode_mappings |
| ENC-0380 | `CP864` | unicode_mapping_table | high | no | yes | implemented | unicode_mappings |
| ENC-0381 | `CP864` | pc_code_page | medium | no | yes | implemented | kermit |
| ENC-0382 | `CP865` | unicode_mapping_table | high | no | yes | implemented | unicode_mappings |
| ENC-0383 | `CP866` | unicode_mapping_table | high | no | yes | implemented | unicode_mappings |
| ENC-0384 | `CP866` | pc_code_page | medium | no | yes | implemented | kermit |
| ENC-0385 | `cp866` | microsoft_code_page | high | no | yes | implemented | microsoft |
| ENC-0386 | `CP869` | unicode_mapping_table | high | no | yes | implemented | unicode_mappings |
| ENC-0387 | `CP869` | pc_code_page | medium | no | yes | implemented | kermit |
| ENC-0388 | `CP874` | unicode_mapping_table | high | no | yes | implemented | unicode_mappings |
| ENC-0389 | `CP874` | unicode_mapping_table | high | no | yes | implemented | unicode_mappings |
| ENC-0390 | `CP875` | unicode_mapping_table | high | no | yes | implemented | unicode_mappings |
| ENC-0391 | `cp875` | microsoft_code_page | high | no | yes | implemented | microsoft |
| ENC-0392 | `cp875` | python_codec | medium | no | yes | implemented | python |
| ENC-0393 | `CP912` | standard_8bit_set | medium | no | yes | implemented | kermit |
| ENC-0394 | `CP913` | standard_8bit_set | medium | no | yes | implemented | kermit |
| ENC-0395 | `CP914` | standard_8bit_set | medium | no | yes | implemented | kermit |
| ENC-0396 | `CP915` | standard_8bit_set | medium | no | yes | implemented | kermit |
| ENC-0397 | `CP916` | standard_8bit_set | medium | no | yes | implemented | kermit |
| ENC-0398 | `CP920` | standard_8bit_set | medium | no | yes | implemented | kermit |
| ENC-0399 | `CP922` | glibc_gconv_codec, gnu_fixed_codec, ibm_ccsid, icu_converter, openjdk_charset | high | yes | yes | implemented | gnu_libiconv, glibc, icu, openjdk, ibm_i |
| ENC-0400 | `CP923` | standard_8bit_set | medium | no | yes | implemented | kermit |
| ENC-0401 | `CP932` | glibc_gconv_codec, gnu_fixed_codec, ibm_ccsid, icu_converter, openjdk_charset, wikidata_codepage, wikipedia_character_set_page | high | yes | yes | implemented | gnu_libiconv, glibc, icu, openjdk, ibm_i, wikidata, wikipedia |
| ENC-0402 | `CP932` | glibc_gconv_codec | high | no | yes | implemented | glibc |
| ENC-0403 | `CP932` | unicode_mapping_table | high | no | yes | implemented | unicode_mappings |
| ENC-0404 | `CP936` | gnu_fixed_codec, openjdk_charset, wikipedia_character_set_page | high | yes | yes | implemented | gnu_libiconv, openjdk, wikipedia |
| ENC-0405 | `CP936` | unicode_mapping_table | high | no | yes | implemented | unicode_mappings |
| ENC-0406 | `CP943` | glibc_gconv_codec, gnu_fixed_codec, ibm_ccsid, openjdk_charset | high | yes | yes | implemented | gnu_libiconv, glibc, openjdk, ibm_i |
| ENC-0407 | `CP949` | glibc_gconv_codec, gnu_fixed_codec, ibm_ccsid, icu_converter, openjdk_charset, wikidata_codepage, wikidata_dbcs, wikidata_variablewidthcharacterencoding, wikipedia_character_set_page | high | yes | yes | implemented | gnu_libiconv, glibc, icu, openjdk, ibm_i, wikidata, wikipedia |
| ENC-0408 | `CP949` | unicode_mapping_table | high | no | yes | implemented | unicode_mappings |
| ENC-0409 | `cp949` | python_codec | medium | no | yes | implemented | python |
| ENC-0410 | `CP950` | gnu_fixed_codec, ibm_ccsid, icu_converter, openjdk_charset | high | yes | yes | implemented | gnu_libiconv, icu, openjdk, ibm_i |
| ENC-0411 | `CP950` | unicode_mapping_table | high | no | yes | implemented | unicode_mappings |
| ENC-0412 | `cp950` | python_codec | medium | no | yes | implemented | python |
| ENC-0413 | `CROSCII` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0414 | `CS Indic character set` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0415 | `CSA_Z243.4-1985-1` | glibc_gconv_codec, iana_registered_charset, national_replacement_set, rfc1345_charset | high | no | yes | implemented | iana, glibc, rfc1345, kermit |
| ENC-0416 | `CSA_Z243.4-1985-2` | glibc_gconv_codec, iana_registered_charset, rfc1345_charset | high | no | yes | implemented | iana, glibc, rfc1345 |
| ENC-0417 | `CSA_Z243.4-1985-gr` | iana_registered_charset, rfc1345_charset | high | no | yes | implemented | iana, rfc1345 |
| ENC-0418 | `CSN_369103` | glibc_gconv_codec, iana_registered_charset, rfc1345_charset | high | no | yes | implemented | iana, glibc, rfc1345 |
| ENC-0419 | `CSX Indic character set` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0420 | `CWI` | glibc_gconv_codec | high | no | yes | implemented | glibc |
| ENC-0421 | `CWI-2` | wikidata_characterencoding | medium | no | yes | implemented | wikidata |
| ENC-0422 | `CYRILLIC` | unicode_mapping_table | high | no | yes | implemented | unicode_mappings |
| ENC-0423 | `Data Syntax I of CCITT Rec.T.101` | iso_ir_coding_system | high | no | no | non_text_coding_system | iso_ir |
| ENC-0424 | `Data Syntax II of CCITT Rec. T.101` | iso_ir_coding_system | high | no | no | non_text_coding_system | iso_ir |
| ENC-0425 | `DEC 026 card code` | historical_punched_card_encoding, source_qualified_punched_card_encoding | high | no | yes | implemented | punched_cards, supplement |
| ENC-0426 | `DEC 029 card code` | historical_punched_card_encoding, source_qualified_punched_card_encoding | high | no | yes | implemented | punched_cards, supplement |
| ENC-0427 | `DEC Hebrew` | eight_bit_character_encoding, wikidata_codepage, wikipedia_character_set_page | high | no | yes | implemented | wikidata, wikipedia, supplement |
| ENC-0428 | `DEC Radix-50` | packed_legacy_character_code, wikidata_characterencoding, wikipedia_character_set_page | high | no | yes | implemented | wikidata, wikipedia, supplement |
| ENC-0429 | `DEC SIXBIT/ECMA-1` | historical_information_system_encoding, six_bit_character_code | high | no | yes | implemented | wikipedia_historical, supplement |
| ENC-0430 | `DEC-GREEK-8-1994` | versioned_single_byte_character_encoding | high | no | yes | implemented | supplement |
| ENC-0431 | `DEC-HANYU` | gnu_fixed_codec | high | yes | yes | implemented | gnu_libiconv |
| ENC-0432 | `DEC-KANJI` | gnu_fixed_codec, multibyte_encoding | high | yes | yes | implemented | gnu_libiconv, kermit |
| ENC-0433 | `DEC-MCS` | glibc_gconv_codec, iana_registered_charset, rfc1345_charset, vendor_8bit_set, wikidata_characterencoding, wikipedia_character_set_page | high | no | yes | implemented | iana, glibc, rfc1345, kermit, wikidata, wikipedia |
| ENC-0434 | `DEC-SPECIAL` | terminal_glyph_set, wikidata_characterencoding, wikipedia_character_set_page | high | no | yes | implemented | kermit, wikidata, wikipedia, supplement |
| ENC-0435 | `DEC-TECHNICAL` | terminal_glyph_set, wikidata_characterencoding, wikipedia_character_set_page | high | no | yes | implemented | kermit, wikidata, wikipedia, supplement |
| ENC-0436 | `DEC-TURKISH-8-1994` | versioned_single_byte_character_encoding | high | no | yes | implemented | supplement |
| ENC-0437 | `DEX MUTF-8` | unicode_compatibility_encoding | medium | no | yes | implemented | supplement |
| ENC-0438 | `DG-INTERNATIONAL` | vendor_8bit_set, wikidata_characterencoding, wikipedia_character_set_page | medium | no | yes | implemented | kermit, wikidata, wikipedia |
| ENC-0439 | `DG-LINEDRAWING` | terminal_glyph_set | medium | no | yes | implemented | kermit |
| ENC-0440 | `DG-SPECIALGRAPHICS` | terminal_glyph_set | medium | no | no | codec_gap | kermit |
| ENC-0441 | `DG-WORDPROCESSING` | terminal_glyph_set | medium | no | yes | implemented | kermit |
| ENC-0442 | `Digital encoding of APL symbols` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0443 | `DIN 66303` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0444 | `DIN 91379` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0445 | `DIN_66003` | glibc_gconv_codec, iana_registered_charset, national_replacement_set, rfc1345_charset, wikidata_codepage, wikipedia_character_set_page | high | no | yes | implemented | iana, glibc, rfc1345, kermit, wikidata, wikipedia |
| ENC-0446 | `dk-us` | iana_registered_charset, rfc1345_charset | high | no | yes | implemented | iana, rfc1345 |
| ENC-0447 | `DKOI` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0448 | `DOS-720` | microsoft_code_page | high | no | yes | implemented | microsoft |
| ENC-0449 | `DOS-862` | microsoft_code_page | high | no | yes | implemented | microsoft |
| ENC-0450 | `DPRK Standard Korean Graphic Character Set for Information Interchange` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-0451 | `DS_2089` | glibc_gconv_codec, iana_registered_charset, national_replacement_set, rfc1345_charset | high | no | yes | implemented | iana, glibc, rfc1345, kermit |
| ENC-0452 | `DUTCH` | national_replacement_set | medium | no | yes | implemented | kermit |
| ENC-0453 | `E13B Graphic Character Set Japanese National Committee for ISO/TC97/SC2` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-0454 | `EBCD card character set` | historical_punched_card_encoding, source_qualified_punched_card_encoding | high | no | yes | implemented | punched_cards, supplement |
| ENC-0455 | `EBCDIC` | historical_information_system_encoding, wikidata_characterencoding, wikipedia_character_set_page | medium | no | no | encoding_family | wikidata, wikipedia_historical, wikipedia |
| ENC-0456 | `EBCDIC 001` | wikidata_ebcdiccodepage | medium | no | no | codec_gap | wikidata |
| ENC-0457 | `EBCDIC 8859` | wikidata_codepage | medium | no | no | codec_gap | wikidata |
| ENC-0458 | `EBCDIC-AT-DE` | glibc_gconv_codec, iana_registered_charset, rfc1345_charset | high | no | yes | implemented | iana, glibc, rfc1345 |
| ENC-0459 | `EBCDIC-AT-DE-A` | glibc_gconv_codec, iana_registered_charset, rfc1345_charset | high | no | yes | implemented | iana, glibc, rfc1345 |
| ENC-0460 | `EBCDIC-CA-FR` | glibc_gconv_codec, iana_registered_charset, rfc1345_charset | high | no | yes | implemented | iana, glibc, rfc1345 |
| ENC-0461 | `EBCDIC-DK-NO` | glibc_gconv_codec, iana_registered_charset, rfc1345_charset | high | no | yes | implemented | iana, glibc, rfc1345 |
| ENC-0462 | `EBCDIC-DK-NO-A` | glibc_gconv_codec, iana_registered_charset, rfc1345_charset | high | no | yes | implemented | iana, glibc, rfc1345 |
| ENC-0463 | `EBCDIC-ES` | glibc_gconv_codec, iana_registered_charset, rfc1345_charset | high | no | yes | implemented | iana, glibc, rfc1345 |
| ENC-0464 | `EBCDIC-ES-A` | glibc_gconv_codec, iana_registered_charset, rfc1345_charset | high | no | yes | implemented | iana, glibc, rfc1345 |
| ENC-0465 | `EBCDIC-ES-S` | glibc_gconv_codec, iana_registered_charset, rfc1345_charset | high | no | yes | implemented | iana, glibc, rfc1345 |
| ENC-0466 | `EBCDIC-FI-SE` | glibc_gconv_codec, iana_registered_charset, rfc1345_charset | high | no | yes | implemented | iana, glibc, rfc1345 |
| ENC-0467 | `EBCDIC-FI-SE-A` | glibc_gconv_codec, iana_registered_charset, rfc1345_charset | high | no | yes | implemented | iana, glibc, rfc1345 |
| ENC-0468 | `EBCDIC-FR` | glibc_gconv_codec, iana_registered_charset, rfc1345_charset | high | no | yes | implemented | iana, glibc, rfc1345 |
| ENC-0469 | `EBCDIC-IS-FRISS` | glibc_gconv_codec | high | no | yes | implemented | glibc |
| ENC-0470 | `EBCDIC-IT` | glibc_gconv_codec, iana_registered_charset, rfc1345_charset | high | no | yes | implemented | iana, glibc, rfc1345 |
| ENC-0471 | `EBCDIC-PT` | glibc_gconv_codec, iana_registered_charset, rfc1345_charset | high | no | yes | implemented | iana, glibc, rfc1345 |
| ENC-0472 | `EBCDIC-UK` | glibc_gconv_codec, iana_registered_charset, rfc1345_charset | high | no | yes | implemented | iana, glibc, rfc1345 |
| ENC-0473 | `EBCDIC-US` | glibc_gconv_codec, iana_registered_charset, rfc1345_charset | high | no | yes | implemented | iana, glibc, rfc1345 |
| ENC-0474 | `ebcdic-xml-us` | icu_converter | high | no | yes | implemented | icu |
| ENC-0475 | `EBU Latin` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0476 | `ECMA-1` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-0477 | `ECMA-121` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0478 | `ECMA-44 punched-card representation` | punched_card_encoding | medium | no | yes | implemented | supplement |
| ENC-0479 | `ECMA-48` | historical_information_system_encoding | medium | no | no | control_standard | wikipedia_historical |
| ENC-0480 | `ECMA-6` | historical_information_system_encoding, wikipedia_character_set_page | medium | no | no | encoding_family | wikipedia_historical, wikipedia |
| ENC-0481 | `ECMA-94` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0482 | `ECMA-cyrillic` | glibc_gconv_codec, iana_registered_charset, rfc1345_charset, wikidata_characterencoding | high | no | yes | implemented | iana, glibc, rfc1345, wikidata |
| ENC-0483 | `ELOT927-GREEK` | national_replacement_set | medium | no | yes | implemented | kermit |
| ENC-0484 | `ES` | glibc_gconv_codec, iana_registered_charset, national_replacement_set, rfc1345_charset | high | no | yes | implemented | iana, glibc, rfc1345, kermit |
| ENC-0485 | `ES2` | glibc_gconv_codec, iana_registered_charset, rfc1345_charset | high | no | yes | implemented | iana, glibc, rfc1345 |
| ENC-0486 | `EUC-JISX0213` | glibc_gconv_codec, gnu_fixed_codec, python_codec, wikidata_characterencoding, wikidata_extendedunixcode | high | yes | yes | implemented | gnu_libiconv, glibc, python, wikidata |
| ENC-0487 | `EUC-JP` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, ibm_ccsid, icu_converter, microsoft_code_page, multibyte_encoding, openjdk_charset, python_codec, web_encoding, wikidata_extendedunixcode | high | yes | yes | implemented | iana, whatwg, gnu_libiconv, glibc, icu, openjdk, microsoft, ibm_i, python, kermit, wikidata |
| ENC-0488 | `EUC-JP-MS` | glibc_gconv_codec | high | no | yes | implemented | glibc |
| ENC-0489 | `EUC-KR` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, ibm_ccsid, microsoft_code_page, openjdk_charset, python_codec, web_encoding, wikidata_extendedunixcode | high | yes | yes | implemented | iana, whatwg, gnu_libiconv, glibc, openjdk, microsoft, ibm_i, python, wikidata |
| ENC-0490 | `EUC-TW` | glibc_gconv_codec, gnu_fixed_codec, ibm_ccsid, icu_converter, openjdk_charset, unicode_mapping_table, wikidata_codedcharacterset, wikipedia_character_set_page | high | yes | yes | implemented | gnu_libiconv, glibc, icu, openjdk, ibm_i, unicode_mappings, wikidata, wikipedia |
| ENC-0491 | `Extended ASCII` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0492 | `Extended Graphic Character Set for Bibliography ISO 5426-1980` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-0493 | `Extended Graphic Character Set for Bibliography, DIN 31624` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-0494 | `Extended Latin-8` | source_qualified_single_byte_character_encoding, wikipedia_character_set_page | high | no | yes | implemented | wikipedia, supplement |
| ENC-0495 | `Extended Unix Code` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0496 | `Extended_UNIX_Code_Fixed_Width_for_Japanese` | iana_registered_charset | high | no | yes | implemented | iana |
| ENC-0497 | `Extension of the Cyrillic Character Set of Reg. 37, ISO 5427-1981` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-0498 | `EZweb emoji` | wikidata_codedcharacterset | medium | no | no | codec_gap | wikidata |
| ENC-0499 | `Fieldata` | historical_information_system_encoding, wikidata_characterencoding, wikipedia_character_set_page | medium | no | no | encoding_family | wikidata, wikipedia_historical, wikipedia |
| ENC-0500 | `File System Safe UCS Transformation Format` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0501 | `FINNISH` | national_replacement_set | medium | no | yes | implemented | kermit |
| ENC-0502 | `FOCAL character set` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0503 | `Formal SignWriting` | signwriting_ascii_encoding, wikidata_characterencoding | high | no | yes | implemented | wikidata, supplement |
| ENC-0504 | `FSS-UTF` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0505 | `GB 12052` | wikidata_characterencoding, wikidata_codedcharacterset, wikipedia_character_set_page | medium | no | no | codec_gap | wikidata, wikipedia |
| ENC-0506 | `GB 12345` | wikidata_codedcharacterset, wikipedia_character_set_page | medium | no | no | codec_gap | wikidata, wikipedia |
| ENC-0507 | `GB 13131–91` | wikidata_codedcharacterset | medium | no | no | codec_gap | wikidata |
| ENC-0508 | `GB 13132‐91` | wikidata_codedcharacterset | medium | no | no | codec_gap | wikidata |
| ENC-0509 | `GB/T 16500–1998` | wikidata_codedcharacterset | medium | no | no | codec_gap | wikidata |
| ENC-0510 | `GB/T 7589–87` | wikidata_codedcharacterset | medium | no | no | codec_gap | wikidata |
| ENC-0511 | `GB/T 7590–87` | wikidata_codedcharacterset | medium | no | no | codec_gap | wikidata |
| ENC-0512 | `GB/T 8565.2–88` | wikidata_codedcharacterset | medium | no | no | codec_gap | wikidata |
| ENC-0513 | `GB18030` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, microsoft_code_page, openjdk_charset, python_codec, web_encoding, wikidata_characterencoding, wikidata_codedcharacterset, wikidata_unicodeencoding, wikipedia_character_set_page | high | yes | yes | implemented | iana, whatwg, gnu_libiconv, glibc, openjdk, microsoft, python, wikidata, wikipedia |
| ENC-0514 | `GB18030:2022` | gnu_fixed_codec, icu_converter | high | yes | yes | implemented | gnu_libiconv, icu |
| ENC-0515 | `GB2312` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, ibm_ccsid, icu_converter, microsoft_code_page, openjdk_charset, python_codec, wikidata_characterencoding, wikidata_codedcharacterset, wikipedia_character_set_page | high | yes | yes | implemented | iana, gnu_libiconv, glibc, icu, openjdk, microsoft, ibm_i, python, wikidata, wikipedia |
| ENC-0516 | `GB_1988-80` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, iso_ir_coded_character_set, rfc1345_charset | high | yes | yes | implemented | iana, gnu_libiconv, glibc, iso_ir, rfc1345 |
| ENC-0517 | `GB_2312-80` | gnu_fixed_codec, iana_registered_charset, icu_converter, iso_ir_coded_character_set, rfc1345_charset | high | yes | yes | implemented | iana, gnu_libiconv, icu, iso_ir, rfc1345 |
| ENC-0518 | `GBK` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, ibm_ccsid, python_codec, web_encoding, wikidata_characterencoding, wikidata_codedcharacterset, wikipedia_character_set_page | high | yes | yes | implemented | iana, whatwg, gnu_libiconv, glibc, ibm_i, python, wikidata, wikipedia |
| ENC-0519 | `GCCS (character set)` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0520 | `GE 600 punched-card code` | historical_punched_card_encoding, source_qualified_punched_card_encoding | high | no | yes | implemented | punched_cards, supplement |
| ENC-0521 | `GEM character set` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0522 | `General Purpose Supplementary Graphic Set CSA Standard Z 243.4-1985` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-0523 | `GEORGIAN-ACADEMY` | glibc_gconv_codec, gnu_fixed_codec | high | yes | yes | implemented | gnu_libiconv, glibc |
| ENC-0524 | `GEORGIAN-PS` | glibc_gconv_codec, gnu_fixed_codec | high | yes | yes | implemented | gnu_libiconv, glibc |
| ENC-0525 | `GOST 10859` | historical_information_system_encoding, wikipedia_character_set_page | medium | no | no | encoding_family | wikipedia_historical, wikipedia |
| ENC-0526 | `GOST_19768-74` | glibc_gconv_codec, iana_registered_charset, rfc1345_charset | high | no | yes | implemented | iana, glibc, rfc1345 |
| ENC-0527 | `Government Chinese Character Set` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0528 | `GREEK` | unicode_mapping_table | high | no | yes | implemented | unicode_mappings |
| ENC-0529 | `Greek Character Set ELOT, Hellenic Organization for Standardization (Withdrawn in November 1986)` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-0530 | `Greek Character Set for Bibliography, ISO 5428` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-0531 | `Greek Character Set for Bibliography, ISO 5428-1980` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-0532 | `Greek Primary Set of CCITT` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-0533 | `greek-ccitt` | glibc_gconv_codec, iana_registered_charset, rfc1345_charset | high | no | yes | implemented | iana, glibc, rfc1345 |
| ENC-0534 | `GREEK-ISO` | standard_8bit_set | medium | no | yes | implemented | kermit |
| ENC-0535 | `greek7` | glibc_gconv_codec, iana_registered_charset, rfc1345_charset, wikidata_characterencoding, wikipedia_character_set_page | high | no | yes | implemented | iana, glibc, rfc1345, wikidata, wikipedia |
| ENC-0536 | `greek7-old` | glibc_gconv_codec, iana_registered_charset, rfc1345_charset | high | no | yes | implemented | iana, glibc, rfc1345 |
| ENC-0537 | `GSM 03.38` | telecom_character_encoding, wikidata_characterencoding, wikipedia_character_set_page | high | no | yes | implemented | wikidata, wikipedia, supplement |
| ENC-0538 | `gsm-03.38-2009` | icu_converter | high | no | yes | implemented | icu |
| ENC-0539 | `HANGUL` | unicode_mapping_table | high | no | yes | implemented | unicode_mappings |
| ENC-0540 | `Hardware code page` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0541 | `HEBREW-7` | national_replacement_set, seven_bit_character_encoding, wikidata_characterencoding, wikipedia_character_set_page | high | no | yes | implemented | kermit, wikidata, wikipedia, supplement |
| ENC-0542 | `HEBREW-ISO` | standard_8bit_set | medium | no | yes | implemented | kermit |
| ENC-0543 | `hex-codec` | python_codec | medium | no | no | binary_transform | python |
| ENC-0544 | `HKSCS` | wikidata_characterencoding | medium | no | no | repertoire_profile | wikidata |
| ENC-0545 | `HKSCS IDS` | wikidata_characterencoding | medium | no | no | mapping_notation | wikidata |
| ENC-0546 | `Hollerith consensus punched-card code` | historical_punched_card_encoding | medium | no | no | codec_gap | punched_cards |
| ENC-0547 | `Hong Kong Supplementary Character Set` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0548 | `HP calculator character sets` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0549 | `HP Roman` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0550 | `HP Roman Extension` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0551 | `HP-DeskTop` | iana_registered_charset | high | no | yes | implemented | iana |
| ENC-0552 | `HP-GREEK8` | glibc_gconv_codec | high | no | yes | implemented | glibc |
| ENC-0553 | `HP-Legal` | iana_registered_charset | high | no | yes | implemented | iana |
| ENC-0554 | `HP-LINE-DRAWING` | terminal_glyph_set | medium | no | no | codec_gap | kermit |
| ENC-0555 | `HP-MATH-TECHNICAL` | terminal_glyph_set | medium | no | yes | implemented | kermit |
| ENC-0556 | `HP-Math8` | iana_registered_charset | high | no | yes | implemented | iana |
| ENC-0557 | `HP-Pi-font` | iana_registered_charset | high | no | yes | implemented | iana |
| ENC-0558 | `hp-roman8` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, icu_converter, python_codec, rfc1345_charset, vendor_8bit_set, wikidata_characterencoding, wikipedia_character_set_page | high | yes | yes | implemented | iana, gnu_libiconv, glibc, icu, rfc1345, python, kermit, wikidata, wikipedia |
| ENC-0559 | `HP-ROMAN9` | glibc_gconv_codec, wikipedia_character_set_page | high | no | yes | implemented | glibc, wikipedia |
| ENC-0560 | `HP-THAI8` | glibc_gconv_codec | high | no | yes | implemented | glibc |
| ENC-0561 | `HP-TURKISH8` | glibc_gconv_codec | high | no | yes | implemented | glibc |
| ENC-0562 | `HUNGARIAN` | national_replacement_set | medium | no | yes | implemented | kermit |
| ENC-0563 | `HZ-GB-2312` | gnu_fixed_codec, iana_registered_charset, icu_converter, microsoft_code_page, python_codec, wikipedia_character_set_page | high | yes | yes | implemented | iana, gnu_libiconv, icu, microsoft, python, wikipedia |
| ENC-0564 | `i-mode emoji` | wikidata_codedcharacterset | medium | no | no | codec_gap | wikidata |
| ENC-0565 | `IA5 (character encoding)` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-0566 | `IBM 026 Commercial card code` | historical_punched_card_encoding, punched_card_encoding | high | no | yes | implemented | punched_cards, supplement |
| ENC-0567 | `IBM 026 FORTRAN card code` | historical_punched_card_encoding, punched_card_encoding | high | no | yes | implemented | punched_cards, supplement |
| ENC-0568 | `IBM 029 card code` | historical_punched_card_encoding, source_qualified_punched_card_encoding | high | no | yes | implemented | punched_cards, supplement |
| ENC-0569 | `IBM 1401 card code` | historical_punched_card_encoding, punched_card_encoding | high | no | yes | implemented | punched_cards, supplement |
| ENC-0570 | `IBM H code (programming)` | historical_punched_card_encoding, punched_card_encoding | high | no | yes | implemented | punched_cards, supplement |
| ENC-0571 | `IBM H code (report-writing)` | historical_punched_card_encoding, punched_card_encoding | high | no | yes | implemented | punched_cards, supplement |
| ENC-0572 | `ibm-1006_P100-1995` | icu_converter | high | no | yes | implemented | icu |
| ENC-0573 | `ibm-1008_P100-1995` | icu_converter | high | no | yes | implemented | icu |
| ENC-0574 | `IBM-1009` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0575 | `ibm-1009_P100-1995` | icu_converter | high | no | yes | implemented | icu |
| ENC-0576 | `IBM-1010` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0577 | `ibm-1010_P100-1995` | icu_converter | high | no | yes | implemented | icu |
| ENC-0578 | `IBM-1011` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0579 | `ibm-1011_P100-1995` | icu_converter | high | no | yes | implemented | icu |
| ENC-0580 | `IBM-1012` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0581 | `ibm-1012_P100-1995` | icu_converter | high | no | yes | implemented | icu |
| ENC-0582 | `IBM-1013` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0583 | `ibm-1013_P100-1995` | icu_converter | high | no | yes | implemented | icu |
| ENC-0584 | `IBM-1014` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0585 | `ibm-1014_P100-1995` | icu_converter | high | no | yes | implemented | icu |
| ENC-0586 | `IBM-1015` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0587 | `ibm-1015_P100-1995` | icu_converter | high | no | yes | implemented | icu |
| ENC-0588 | `IBM-1016` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0589 | `ibm-1016_P100-1995` | icu_converter | high | no | yes | implemented | icu |
| ENC-0590 | `IBM-1017` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0591 | `ibm-1017_P100-1995` | icu_converter | high | no | yes | implemented | icu |
| ENC-0592 | `IBM-1018` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0593 | `ibm-1018_P100-1995` | icu_converter | high | no | yes | implemented | icu |
| ENC-0594 | `IBM-1019` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0595 | `ibm-1019_P100-1995` | icu_converter | high | no | yes | implemented | icu |
| ENC-0596 | `ibm-1020_P100-2003` | icu_converter | high | no | yes | implemented | icu |
| ENC-0597 | `ibm-1021_P100-2003` | icu_converter | high | no | yes | implemented | icu |
| ENC-0598 | `ibm-1023_P100-2003` | icu_converter | high | no | yes | implemented | icu |
| ENC-0599 | `IBM-1025` | glibc_gconv_codec, gnu_fixed_codec, ibm_ccsid, icu_converter, openjdk_charset, wikidata_ebcdiccodepage | high | yes | yes | implemented | gnu_libiconv, glibc, icu, openjdk, ibm_i, wikidata |
| ENC-0600 | `IBM-1027` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0601 | `ibm-1027_P100-1995` | icu_converter | high | no | yes | implemented | icu |
| ENC-0602 | `IBM-1040` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0603 | `IBM-1041` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0604 | `ibm-1041_P100-1995` | icu_converter | high | no | yes | implemented | icu |
| ENC-0605 | `IBM-1042` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0606 | `IBM-1043` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0607 | `ibm-1043_P100-1995` | icu_converter | high | no | yes | implemented | icu |
| ENC-0608 | `ibm-1047_P100-1995,swaplfnl` | icu_converter | high | no | yes | implemented | icu |
| ENC-0609 | `IBM-1051` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0610 | `IBM-1088` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0611 | `ibm-1088_P100-1995` | icu_converter | high | no | yes | implemented | icu |
| ENC-0612 | `IBM-1097` | glibc_gconv_codec, gnu_fixed_codec, ibm_ccsid, icu_converter, openjdk_charset | high | yes | yes | implemented | gnu_libiconv, glibc, icu, openjdk, ibm_i |
| ENC-0613 | `IBM-1098` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0614 | `ibm-1098_P100-1995` | icu_converter | high | no | yes | implemented | icu |
| ENC-0615 | `ibm-1100_P100-2003` | icu_converter | high | no | yes | implemented | icu |
| ENC-0616 | `ibm-1101_P100-2003` | icu_converter | high | no | yes | implemented | icu |
| ENC-0617 | `ibm-1102_P100-2003` | icu_converter | high | no | yes | implemented | icu |
| ENC-0618 | `ibm-1103_P100-2003` | icu_converter | high | no | yes | implemented | icu |
| ENC-0619 | `ibm-1104_P100-2003` | icu_converter | high | no | yes | implemented | icu |
| ENC-0620 | `ibm-1105_P100-2003` | icu_converter | high | no | yes | implemented | icu |
| ENC-0621 | `ibm-1106_P100-2003` | icu_converter | high | no | yes | implemented | icu |
| ENC-0622 | `ibm-1107_P100-2003` | icu_converter | high | no | yes | implemented | icu |
| ENC-0623 | `IBM-1112` | glibc_gconv_codec, gnu_fixed_codec, ibm_ccsid, icu_converter, openjdk_charset | high | yes | yes | implemented | gnu_libiconv, glibc, icu, openjdk, ibm_i |
| ENC-0624 | `IBM-1114` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0625 | `ibm-1114_P100-2001` | icu_converter | high | no | yes | implemented | icu |
| ENC-0626 | `IBM-1115` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0627 | `ibm-1115_P100-1995` | icu_converter | high | no | yes | implemented | icu |
| ENC-0628 | `IBM-1116-850-P100-COMPOSITE` | versioned_single_byte_composite_profile | high | no | yes | implemented | supplement |
| ENC-0629 | `IBM-1117-437-P100-COMPOSITE` | versioned_single_byte_composite_profile | high | no | yes | implemented | supplement |
| ENC-0630 | `IBM-1122` | glibc_gconv_codec, gnu_fixed_codec, ibm_ccsid, icu_converter, openjdk_charset | high | yes | yes | implemented | gnu_libiconv, glibc, icu, openjdk, ibm_i |
| ENC-0631 | `IBM-1123` | glibc_gconv_codec, gnu_fixed_codec, ibm_ccsid, icu_converter, openjdk_charset | high | yes | yes | implemented | gnu_libiconv, glibc, icu, openjdk, ibm_i |
| ENC-0632 | `IBM-1126` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0633 | `ibm-1127_P100-2004` | icu_converter | high | no | yes | implemented | icu |
| ENC-0634 | `IBM-1130` | glibc_gconv_codec, gnu_fixed_codec, ibm_ccsid, icu_converter | high | yes | yes | implemented | gnu_libiconv, glibc, icu, ibm_i |
| ENC-0635 | `IBM-1132` | glibc_gconv_codec, gnu_fixed_codec, ibm_ccsid, icu_converter | high | yes | yes | implemented | gnu_libiconv, glibc, icu, ibm_i |
| ENC-0636 | `ibm-1133_P100-1997` | icu_converter | high | no | yes | implemented | icu |
| ENC-0637 | `IBM-1137` | glibc_gconv_codec, gnu_fixed_codec, ibm_ccsid, icu_converter | high | yes | yes | implemented | gnu_libiconv, glibc, icu, ibm_i |
| ENC-0638 | `ibm-1140_P100-1997,swaplfnl` | icu_converter | high | no | yes | implemented | icu |
| ENC-0639 | `ibm-1141_P100-1997,swaplfnl` | icu_converter | high | no | yes | implemented | icu |
| ENC-0640 | `ibm-1142_P100-1997,swaplfnl` | icu_converter | high | no | yes | implemented | icu |
| ENC-0641 | `ibm-1143_P100-1997,swaplfnl` | icu_converter | high | no | yes | implemented | icu |
| ENC-0642 | `ibm-1144_P100-1997,swaplfnl` | icu_converter | high | no | yes | implemented | icu |
| ENC-0643 | `ibm-1145_P100-1997,swaplfnl` | icu_converter | high | no | yes | implemented | icu |
| ENC-0644 | `ibm-1146_P100-1997,swaplfnl` | icu_converter | high | no | yes | implemented | icu |
| ENC-0645 | `ibm-1147_P100-1997,swaplfnl` | icu_converter | high | no | yes | implemented | icu |
| ENC-0646 | `ibm-1148_P100-1997,swaplfnl` | icu_converter | high | no | yes | implemented | icu |
| ENC-0647 | `ibm-1149_P100-1997,swaplfnl` | icu_converter | high | no | yes | implemented | icu |
| ENC-0648 | `IBM-1153` | glibc_gconv_codec, gnu_fixed_codec, ibm_ccsid, icu_converter | high | yes | yes | implemented | gnu_libiconv, glibc, icu, ibm_i |
| ENC-0649 | `ibm-1153_P100-1999,swaplfnl` | icu_converter | high | no | yes | implemented | icu |
| ENC-0650 | `IBM-1154` | glibc_gconv_codec, gnu_fixed_codec, ibm_ccsid, icu_converter | high | yes | yes | implemented | gnu_libiconv, glibc, icu, ibm_i |
| ENC-0651 | `IBM-1155` | glibc_gconv_codec, gnu_fixed_codec, ibm_ccsid, icu_converter | high | yes | yes | implemented | gnu_libiconv, glibc, icu, ibm_i |
| ENC-0652 | `IBM-1156` | glibc_gconv_codec, gnu_fixed_codec, ibm_ccsid, icu_converter | high | yes | yes | implemented | gnu_libiconv, glibc, icu, ibm_i |
| ENC-0653 | `IBM-1157` | glibc_gconv_codec, gnu_fixed_codec, ibm_ccsid, icu_converter | high | yes | yes | implemented | gnu_libiconv, glibc, icu, ibm_i |
| ENC-0654 | `IBM-1158` | glibc_gconv_codec, gnu_fixed_codec, ibm_ccsid, icu_converter | high | yes | yes | implemented | gnu_libiconv, glibc, icu, ibm_i |
| ENC-0655 | `IBM-1160` | glibc_gconv_codec, gnu_fixed_codec, ibm_ccsid, icu_converter | high | yes | yes | implemented | gnu_libiconv, glibc, icu, ibm_i |
| ENC-0656 | `IBM-1164` | glibc_gconv_codec, gnu_fixed_codec, ibm_ccsid, icu_converter | high | yes | yes | implemented | gnu_libiconv, glibc, icu, ibm_i |
| ENC-0657 | `IBM-1165` | gnu_fixed_codec, icu_converter | high | yes | yes | implemented | gnu_libiconv, icu |
| ENC-0658 | `IBM-1166` | glibc_gconv_codec, gnu_fixed_codec, ibm_ccsid, icu_converter, openjdk_charset | high | yes | yes | implemented | gnu_libiconv, glibc, icu, openjdk, ibm_i |
| ENC-0659 | `IBM-1175` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0660 | `IBM-1200` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0661 | `IBM-1258` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0662 | `IBM-12708` | ibm_ccsid | high | no | no | codec_gap | ibm_i |
| ENC-0663 | `IBM-12712` | glibc_gconv_codec, gnu_fixed_codec, icu_converter | high | yes | yes | implemented | gnu_libiconv, glibc, icu |
| ENC-0664 | `ibm-12712_P100-1998,swaplfnl` | icu_converter | high | no | yes | implemented | icu |
| ENC-0665 | `IBM-1275` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0666 | `ibm-1276_P100-1995` | icu_converter | high | no | yes | implemented | icu |
| ENC-0667 | `ibm-1277_P100-1995` | icu_converter | high | no | yes | implemented | icu |
| ENC-0668 | `IBM-1280` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0669 | `IBM-1281` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0670 | `IBM-1282` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0671 | `IBM-1283` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0672 | `IBM-13121` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0673 | `IBM-13124` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0674 | `ibm-13125_P100-1997` | icu_converter | high | no | yes | implemented | icu |
| ENC-0675 | `ibm-13140_P101-2000` | icu_converter | high | no | yes | implemented | icu |
| ENC-0676 | `ibm-13218_P100-1996` | icu_converter | high | no | yes | implemented | icu |
| ENC-0677 | `IBM-13488` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0678 | `ibm-1350_P110-1997` | icu_converter | high | no | yes | implemented | icu |
| ENC-0679 | `ibm-1351_P110-1997` | icu_converter | high | no | yes | implemented | icu |
| ENC-0680 | `IBM-1362` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0681 | `ibm-1362_P110-1999` | icu_converter | high | no | yes | implemented | icu |
| ENC-0682 | `IBM-1363` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0683 | `ibm-1363_P110-1997` | icu_converter | high | no | yes | implemented | icu |
| ENC-0684 | `ibm-1363_P11B-1998` | icu_converter | high | no | yes | implemented | icu |
| ENC-0685 | `ibm-1364_P110-2007` | icu_converter | high | no | yes | implemented | icu |
| ENC-0686 | `ibm-13676_P102-2001` | icu_converter | high | no | yes | implemented | icu |
| ENC-0687 | `ibm-1370_P100-1999` | icu_converter | high | no | yes | implemented | icu |
| ENC-0688 | `ibm-1371_P100-1999` | icu_converter | high | no | yes | implemented | icu |
| ENC-0689 | `ibm-1373_P100-2002` | icu_converter | high | no | yes | implemented | icu |
| ENC-0690 | `IBM-1377` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0691 | `IBM-1380` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0692 | `ibm-1380_P100-1995` | icu_converter | high | no | yes | implemented | icu |
| ENC-0693 | `IBM-1382` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0694 | `ibm-1382_P100-1995` | icu_converter | high | no | yes | implemented | icu |
| ENC-0695 | `IBM-1385` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0696 | `ibm-1386_P100-2001` | icu_converter | high | no | yes | implemented | icu |
| ENC-0697 | `ibm-1388_P100-2024` | icu_converter | high | no | yes | implemented | icu |
| ENC-0698 | `ibm-1390_P110-2003` | icu_converter | high | no | yes | implemented | icu |
| ENC-0699 | `ibm-1399_P110-2003` | icu_converter | high | no | yes | implemented | icu |
| ENC-0700 | `IBM-16684` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0701 | `ibm-16684_P110-2003` | icu_converter | high | no | yes | implemented | icu |
| ENC-0702 | `IBM-16804` | glibc_gconv_codec, gnu_fixed_codec, icu_converter | high | yes | yes | implemented | gnu_libiconv, glibc, icu |
| ENC-0703 | `ibm-16804_X110-1999,swaplfnl` | icu_converter | high | no | yes | implemented | icu |
| ENC-0704 | `ibm-17221_P100-2001` | icu_converter | high | no | yes | implemented | icu |
| ENC-0705 | `ibm-17248_X110-1999` | icu_converter | high | no | yes | implemented | icu |
| ENC-0706 | `IBM-17354` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0707 | `ibm-21344_P101-2000` | icu_converter | high | no | yes | implemented | icu |
| ENC-0708 | `ibm-21427_P100-1999` | icu_converter | high | no | yes | implemented | icu |
| ENC-0709 | `IBM-24-26-SPECIAL-CHARACTER-ARRANGEMENT-B` | punched_card_encoding | high | no | yes | implemented | supplement |
| ENC-0710 | `IBM-24-26-SPECIAL-CHARACTER-ARRANGEMENT-C` | punched_card_encoding | high | no | yes | implemented | supplement |
| ENC-0711 | `IBM-24-26-SPECIAL-CHARACTER-ARRANGEMENT-D` | punched_card_encoding | high | no | yes | implemented | supplement |
| ENC-0712 | `IBM-24-26-SPECIAL-CHARACTER-ARRANGEMENT-E` | punched_card_encoding | high | no | yes | implemented | supplement |
| ENC-0713 | `IBM-24-26-SPECIAL-CHARACTER-ARRANGEMENT-F` | punched_card_encoding | high | no | yes | implemented | supplement |
| ENC-0714 | `IBM-24-26-SPECIAL-CHARACTER-ARRANGEMENT-G` | punched_card_encoding | high | no | yes | implemented | supplement |
| ENC-0715 | `IBM-24-26-SPECIAL-CHARACTER-ARRANGEMENT-J` | punched_card_encoding | high | no | yes | implemented | supplement |
| ENC-0716 | `IBM-24-26-SPECIAL-CHARACTER-ARRANGEMENT-K` | punched_card_encoding | high | no | yes | implemented | supplement |
| ENC-0717 | `IBM-25546` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0718 | `ibm-256_P100-1995` | icu_converter | high | no | yes | implemented | icu |
| ENC-0719 | `ibm-259_P100-1995` | icu_converter | high | no | yes | implemented | icu |
| ENC-0720 | `ibm-274_P100-2000` | icu_converter | high | no | yes | implemented | icu |
| ENC-0721 | `ibm-275_P100-1995` | icu_converter | high | no | yes | implemented | icu |
| ENC-0722 | `IBM-282` | gnu_fixed_codec | high | yes | yes | implemented | gnu_libiconv |
| ENC-0723 | `ibm-286_P100-2003` | icu_converter | high | no | yes | implemented | icu |
| ENC-0724 | `IBM-28709` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0725 | `ibm-290_P100-1995` | icu_converter | high | no | yes | implemented | icu |
| ENC-0726 | `ibm-293_P100-1995` | icu_converter | high | no | yes | implemented | icu |
| ENC-0727 | `IBM-300` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0728 | `ibm-300_P120-2006` | icu_converter | high | no | yes | implemented | icu |
| ENC-0729 | `IBM-301` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0730 | `ibm-301_P110-1997` | icu_converter | high | no | yes | implemented | icu |
| ENC-0731 | `IBM-310-293-P100-COMPOSITE-VPUA` | versioned_single_byte_composite_profile | high | no | yes | implemented | supplement |
| ENC-0732 | `ibm-33058_P100-2000` | icu_converter | high | no | yes | implemented | icu |
| ENC-0733 | `IBM-37` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0734 | `ibm-37_P100-1995,swaplfnl` | icu_converter | high | no | yes | implemented | icu |
| ENC-0735 | `ibm-420_X120-1999` | icu_converter | high | no | yes | implemented | icu |
| ENC-0736 | `IBM-425` | gnu_fixed_codec, ibm_ccsid, icu_converter | high | yes | yes | implemented | gnu_libiconv, icu, ibm_i |
| ENC-0737 | `IBM-4396` | ibm_ccsid | high | no | no | codec_gap | ibm_i |
| ENC-0738 | `ibm-4517_P100-2005` | icu_converter | high | no | yes | implemented | icu |
| ENC-0739 | `ibm-4899_P100-1998` | icu_converter | high | no | yes | implemented | icu |
| ENC-0740 | `ibm-4909_P100-1999` | icu_converter | high | no | yes | implemented | icu |
| ENC-0741 | `IBM-4930` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0742 | `ibm-4930_P110-1999` | icu_converter | high | no | yes | implemented | icu |
| ENC-0743 | `IBM-4933` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0744 | `ibm-4933_P100-2002` | icu_converter | high | no | yes | implemented | icu |
| ENC-0745 | `IBM-4948` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0746 | `ibm-4948_P100-1995` | icu_converter | high | no | yes | implemented | icu |
| ENC-0747 | `IBM-4951` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0748 | `ibm-4951_P100-1995` | icu_converter | high | no | yes | implemented | icu |
| ENC-0749 | `IBM-4952` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0750 | `ibm-4952_P100-1995` | icu_converter | high | no | yes | implemented | icu |
| ENC-0751 | `IBM-4953` | ibm_ccsid | high | no | no | codec_gap | ibm_i |
| ENC-0752 | `IBM-4960` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0753 | `ibm-4960_P100-1995` | icu_converter | high | no | yes | implemented | icu |
| ENC-0754 | `IBM-4965` | ibm_ccsid | high | no | no | codec_gap | ibm_i |
| ENC-0755 | `IBM-4970` | ibm_ccsid | high | no | no | codec_gap | ibm_i |
| ENC-0756 | `IBM-4971` | glibc_gconv_codec, gnu_fixed_codec, ibm_ccsid, icu_converter | high | yes | yes | implemented | gnu_libiconv, glibc, icu, ibm_i |
| ENC-0757 | `IBM-5026` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0758 | `IBM-5035` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0759 | `ibm-5039_P11A-1998` | icu_converter | high | no | yes | implemented | icu |
| ENC-0760 | `ibm-5048_P100-1995` | icu_converter | high | no | yes | implemented | icu |
| ENC-0761 | `ibm-5049_P100-1995` | icu_converter | high | no | yes | implemented | icu |
| ENC-0762 | `IBM-5050` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0763 | `IBM-5052` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0764 | `IBM-5053` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0765 | `IBM-5054` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0766 | `IBM-5055` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0767 | `ibm-5067_P100-1995` | icu_converter | high | no | yes | implemented | icu |
| ENC-0768 | `ibm-5104_X110-1999` | icu_converter | high | no | yes | implemented | icu |
| ENC-0769 | `IBM-5123` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0770 | `ibm-5123_P100-1999` | icu_converter | high | no | yes | implemented | icu |
| ENC-0771 | `IBM-5210` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0772 | `ibm-5233_P100-2011` | icu_converter | high | no | yes | implemented | icu |
| ENC-0773 | `IBM-5348` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0774 | `IBM-57345` | ibm_ccsid | high | no | no | codec_gap | ibm_i |
| ENC-0775 | `IBM-61175` | ibm_ccsid | high | no | no | codec_gap | ibm_i |
| ENC-0776 | `IBM-61952` | ibm_ccsid | high | no | no | retired_invalid | ibm_i |
| ENC-0777 | `IBM-62210` | ibm_ccsid | high | no | no | codec_gap | ibm_i |
| ENC-0778 | `IBM-62211` | ibm_ccsid | high | no | no | codec_gap | ibm_i |
| ENC-0779 | `IBM-62215` | ibm_ccsid | high | no | no | codec_gap | ibm_i |
| ENC-0780 | `IBM-62218` | ibm_ccsid | high | no | no | codec_gap | ibm_i |
| ENC-0781 | `IBM-62222` | ibm_ccsid | high | no | no | codec_gap | ibm_i |
| ENC-0782 | `IBM-62223` | ibm_ccsid | high | no | no | codec_gap | ibm_i |
| ENC-0783 | `IBM-62224` | ibm_ccsid | high | no | no | codec_gap | ibm_i |
| ENC-0784 | `IBM-62228` | ibm_ccsid | high | no | no | codec_gap | ibm_i |
| ENC-0785 | `IBM-62235` | ibm_ccsid | high | no | no | codec_gap | ibm_i |
| ENC-0786 | `IBM-62238` | ibm_ccsid | high | no | no | codec_gap | ibm_i |
| ENC-0787 | `IBM-62239` | ibm_ccsid | high | no | no | codec_gap | ibm_i |
| ENC-0788 | `IBM-62245` | ibm_ccsid | high | no | no | codec_gap | ibm_i |
| ENC-0789 | `IBM-65534` | ibm_ccsid | high | no | no | control_value | ibm_i |
| ENC-0790 | `IBM-65535` | ibm_ccsid | high | no | no | control_value | ibm_i |
| ENC-0791 | `IBM-720` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0792 | `ibm-720_P100-1997` | icu_converter | high | no | yes | implemented | icu |
| ENC-0793 | `ibm-737_P100-1997` | icu_converter | high | no | yes | implemented | icu |
| ENC-0794 | `ibm-803_P100-1999` | icu_converter | high | no | yes | implemented | icu |
| ENC-0795 | `ibm-806_P100-1998` | icu_converter | high | no | yes | implemented | icu |
| ENC-0796 | `ibm-808_P100-1999` | icu_converter | high | no | yes | implemented | icu |
| ENC-0797 | `IBM-833` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0798 | `ibm-833_P100-1995` | icu_converter | high | no | yes | implemented | icu |
| ENC-0799 | `IBM-834` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0800 | `ibm-834_P100-1995` | icu_converter | high | no | yes | implemented | icu |
| ENC-0801 | `IBM-835` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0802 | `ibm-835_P100-1995` | icu_converter | high | no | yes | implemented | icu |
| ENC-0803 | `IBM-836` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0804 | `ibm-836_P100-1995` | icu_converter | high | no | yes | implemented | icu |
| ENC-0805 | `IBM-837` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0806 | `ibm-837_P100-2011` | icu_converter | high | no | yes | implemented | icu |
| ENC-0807 | `ibm-8482_P100-1999` | icu_converter | high | no | yes | implemented | icu |
| ENC-0808 | `ibm-848_P100-1999` | icu_converter | high | no | yes | implemented | icu |
| ENC-0809 | `ibm-849_P100-1999` | icu_converter | high | no | yes | implemented | icu |
| ENC-0810 | `ibm-851_P100-1995` | icu_converter | high | no | yes | implemented | icu |
| ENC-0811 | `ibm-858_P100-1997` | icu_converter | high | no | yes | implemented | icu |
| ENC-0812 | `ibm-859_P100-1999` | icu_converter | high | no | yes | implemented | icu |
| ENC-0813 | `IBM-8612` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0814 | `ibm-8612_P100-1995` | icu_converter | high | no | yes | implemented | icu |
| ENC-0815 | `ibm-867_P100-1998` | icu_converter | high | no | yes | implemented | icu |
| ENC-0816 | `ibm-868_P100-1995` | icu_converter | high | no | yes | implemented | icu |
| ENC-0817 | `ibm-872_P100-1999` | icu_converter | high | no | yes | implemented | icu |
| ENC-0818 | `ibm-874_P100-1995` | icu_converter | high | no | yes | implemented | icu |
| ENC-0819 | `IBM-875` | glibc_gconv_codec, gnu_fixed_codec, ibm_ccsid, icu_converter, openjdk_charset, wikidata_ebcdiccodepage | high | yes | yes | implemented | gnu_libiconv, glibc, icu, openjdk, ibm_i, wikidata |
| ENC-0820 | `ibm-896_P100-1995` | icu_converter | high | no | yes | implemented | icu |
| ENC-0821 | `IBM-897` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0822 | `ibm-901_P100-1999` | icu_converter | high | no | yes | implemented | icu |
| ENC-0823 | `ibm-9027_P100-1999` | icu_converter | high | no | yes | implemented | icu |
| ENC-0824 | `ibm-902_P100-1999` | icu_converter | high | no | yes | implemented | icu |
| ENC-0825 | `ibm-9048_P100-1998` | icu_converter | high | no | yes | implemented | icu |
| ENC-0826 | `IBM-9056` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0827 | `ibm-9056_P100-1995` | icu_converter | high | no | yes | implemented | icu |
| ENC-0828 | `ibm-9061_P100-1999` | icu_converter | high | no | yes | implemented | icu |
| ENC-0829 | `ibm-9067_X100-2005` | icu_converter | high | no | yes | implemented | icu |
| ENC-0830 | `IBM-907-CDRA-P100-VPUA-COMPOSITE` | versioned_single_byte_composite_profile | high | no | yes | implemented | supplement |
| ENC-0831 | `ibm-9145_P110-1997` | icu_converter | high | no | yes | implemented | icu |
| ENC-0832 | `ibm-918_P100-1995` | icu_converter | high | no | yes | implemented | icu |
| ENC-0833 | `ibm-9238_X110-1999` | icu_converter | high | no | yes | implemented | icu |
| ENC-0834 | `ibm-924_P100-1998,swaplfnl` | icu_converter | high | no | yes | implemented | icu |
| ENC-0835 | `IBM-926` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0836 | `ibm-926_P100-2000` | icu_converter | high | no | yes | implemented | icu |
| ENC-0837 | `IBM-927` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0838 | `ibm-927_P100-1995` | icu_converter | high | no | yes | implemented | icu |
| ENC-0839 | `IBM-928` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0840 | `ibm-928_P100-1995` | icu_converter | high | no | yes | implemented | icu |
| ENC-0841 | `ibm-930_P120-1999` | icu_converter | high | no | yes | implemented | icu |
| ENC-0842 | `ibm-933_P110-1995` | icu_converter | high | no | yes | implemented | icu |
| ENC-0843 | `IBM-934` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0844 | `ibm-935_P110-1999` | icu_converter | high | no | yes | implemented | icu |
| ENC-0845 | `IBM-936` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0846 | `ibm-937_P110-1999` | icu_converter | high | no | yes | implemented | icu |
| ENC-0847 | `IBM-938` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0848 | `ibm-939_P120-1999` | icu_converter | high | no | yes | implemented | icu |
| ENC-0849 | `IBM-941` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0850 | `ibm-941_P13A-2001` | icu_converter | high | no | yes | implemented | icu |
| ENC-0851 | `IBM-942` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0852 | `ibm-943_P130-1999` | icu_converter | high | no | yes | implemented | icu |
| ENC-0853 | `ibm-943_P15A-2003` | icu_converter | high | no | yes | implemented | icu |
| ENC-0854 | `IBM-944` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0855 | `ibm-944_P100-1995` | icu_converter | high | no | yes | implemented | icu |
| ENC-0856 | `IBM-946` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0857 | `ibm-946_P100-1995` | icu_converter | high | no | yes | implemented | icu |
| ENC-0858 | `IBM-947` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0859 | `ibm-947_P100-1995` | icu_converter | high | no | yes | implemented | icu |
| ENC-0860 | `IBM-948` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0861 | `ibm-948_P110-1999` | icu_converter | high | no | yes | implemented | icu |
| ENC-0862 | `IBM-951` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0863 | `ibm-951_P100-1995` | icu_converter | high | no | yes | implemented | icu |
| ENC-0864 | `ibm-952_P110-1997` | icu_converter | high | no | yes | implemented | icu |
| ENC-0865 | `ibm-955_P110-1997` | icu_converter | high | no | yes | implemented | icu |
| ENC-0866 | `IBM-956` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0867 | `IBM-957` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0868 | `ibm-9577_P100-2001` | icu_converter | high | no | yes | implemented | icu |
| ENC-0869 | `IBM-958` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0870 | `IBM-959` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0871 | `IBM-965` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0872 | `ibm-970_P110_P110-2006_U2` | icu_converter | high | no | yes | implemented | icu |
| ENC-0873 | `IBM-971` | ibm_ccsid | high | no | yes | implemented | ibm_i |
| ENC-0874 | `ibm-971_P100-1995` | icu_converter | high | no | yes | implemented | icu |
| ENC-0875 | `IBM-Symbols` | iana_registered_charset | high | no | yes | implemented | iana |
| ENC-0876 | `IBM-Thai` | gnu_fixed_codec, iana_registered_charset, ibm_ccsid, icu_converter, microsoft_code_page, openjdk_charset | high | yes | yes | implemented | iana, gnu_libiconv, icu, openjdk, microsoft, ibm_i |
| ENC-0877 | `IBM-TNZ-CP310-B1EAE3C` | versioned_single_byte_vendor_profile | high | no | yes | implemented | supplement |
| ENC-0878 | `IBM00858` | iana_registered_charset, microsoft_code_page, openjdk_charset | high | no | yes | implemented | iana, openjdk, microsoft |
| ENC-0879 | `IBM00924` | gnu_fixed_codec, iana_registered_charset, ibm_ccsid, icu_converter, microsoft_code_page, wikidata_ebcdiccodepage | high | yes | yes | implemented | iana, gnu_libiconv, icu, microsoft, ibm_i, wikidata |
| ENC-0880 | `IBM01047` | microsoft_code_page | high | no | yes | implemented | microsoft |
| ENC-0881 | `IBM01140` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, ibm_ccsid, icu_converter, microsoft_code_page, openjdk_charset, python_codec | high | yes | yes | implemented | iana, gnu_libiconv, glibc, icu, openjdk, microsoft, ibm_i, python |
| ENC-0882 | `IBM01141` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, ibm_ccsid, icu_converter, microsoft_code_page, openjdk_charset | high | yes | yes | implemented | iana, gnu_libiconv, glibc, icu, openjdk, microsoft, ibm_i |
| ENC-0883 | `IBM01142` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, ibm_ccsid, icu_converter, microsoft_code_page, openjdk_charset | high | yes | yes | implemented | iana, gnu_libiconv, glibc, icu, openjdk, microsoft, ibm_i |
| ENC-0884 | `IBM01143` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, ibm_ccsid, icu_converter, microsoft_code_page, openjdk_charset | high | yes | yes | implemented | iana, gnu_libiconv, glibc, icu, openjdk, microsoft, ibm_i |
| ENC-0885 | `IBM01144` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, ibm_ccsid, icu_converter, microsoft_code_page, openjdk_charset | high | yes | yes | implemented | iana, gnu_libiconv, glibc, icu, openjdk, microsoft, ibm_i |
| ENC-0886 | `IBM01145` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, ibm_ccsid, icu_converter, microsoft_code_page, openjdk_charset | high | yes | yes | implemented | iana, gnu_libiconv, glibc, icu, openjdk, microsoft, ibm_i |
| ENC-0887 | `IBM01146` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, ibm_ccsid, icu_converter, microsoft_code_page, openjdk_charset | high | yes | yes | implemented | iana, gnu_libiconv, glibc, icu, openjdk, microsoft, ibm_i |
| ENC-0888 | `IBM01147` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, ibm_ccsid, icu_converter, microsoft_code_page, openjdk_charset | high | yes | yes | implemented | iana, gnu_libiconv, glibc, icu, openjdk, microsoft, ibm_i |
| ENC-0889 | `IBM01148` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, ibm_ccsid, icu_converter, microsoft_code_page, openjdk_charset | high | yes | yes | implemented | iana, gnu_libiconv, glibc, icu, openjdk, microsoft, ibm_i |
| ENC-0890 | `IBM01149` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, ibm_ccsid, icu_converter, microsoft_code_page, openjdk_charset | high | yes | yes | implemented | iana, gnu_libiconv, glibc, icu, openjdk, microsoft, ibm_i |
| ENC-0891 | `IBM037` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, icu_converter, microsoft_code_page, openjdk_charset, python_codec, rfc1345_charset, wikidata_ebcdiccodepage | high | yes | yes | implemented | iana, gnu_libiconv, glibc, icu, openjdk, microsoft, rfc1345, python, wikidata |
| ENC-0892 | `IBM038` | glibc_gconv_codec, iana_registered_charset, rfc1345_charset | high | no | yes | implemented | iana, glibc, rfc1345 |
| ENC-0893 | `IBM1008` | glibc_gconv_codec, ibm_ccsid | high | no | yes | implemented | glibc, ibm_i |
| ENC-0894 | `IBM1026` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, ibm_ccsid, icu_converter, microsoft_code_page, openjdk_charset, python_codec, rfc1345_charset, wikidata_ebcdiccodepage | high | yes | yes | implemented | iana, gnu_libiconv, glibc, icu, openjdk, microsoft, ibm_i, rfc1345, python, wikidata |
| ENC-0895 | `IBM1047` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, icu_converter, openjdk_charset, wikidata_ebcdiccodepage | high | yes | yes | implemented | iana, gnu_libiconv, glibc, icu, openjdk, wikidata |
| ENC-0896 | `IBM1133` | glibc_gconv_codec, ibm_ccsid | high | no | yes | implemented | glibc, ibm_i |
| ENC-0897 | `IBM1167` | glibc_gconv_codec | high | no | yes | implemented | glibc |
| ENC-0898 | `IBM1364` | glibc_gconv_codec, ibm_ccsid | high | no | yes | implemented | glibc, ibm_i |
| ENC-0899 | `IBM1371` | glibc_gconv_codec, ibm_ccsid | high | no | yes | implemented | glibc, ibm_i |
| ENC-0900 | `IBM1388` | glibc_gconv_codec, ibm_ccsid | high | no | yes | implemented | glibc, ibm_i |
| ENC-0901 | `IBM1390` | glibc_gconv_codec | high | no | yes | implemented | glibc |
| ENC-0902 | `IBM1399` | glibc_gconv_codec, ibm_ccsid | high | no | yes | implemented | glibc, ibm_i |
| ENC-0903 | `IBM256` | glibc_gconv_codec, ibm_ccsid | high | no | yes | implemented | glibc, ibm_i |
| ENC-0904 | `IBM273` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, ibm_ccsid, icu_converter, microsoft_code_page, openjdk_charset, python_codec, rfc1345_charset, wikidata_ebcdiccodepage | high | yes | yes | implemented | iana, gnu_libiconv, glibc, icu, openjdk, microsoft, ibm_i, rfc1345, python, wikidata |
| ENC-0905 | `IBM274` | glibc_gconv_codec, iana_registered_charset, rfc1345_charset | high | no | yes | implemented | iana, glibc, rfc1345 |
| ENC-0906 | `IBM275` | glibc_gconv_codec, iana_registered_charset, rfc1345_charset | high | no | yes | implemented | iana, glibc, rfc1345 |
| ENC-0907 | `IBM277` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, ibm_ccsid, icu_converter, microsoft_code_page, openjdk_charset, rfc1345_charset, wikidata_ebcdiccodepage | high | yes | yes | implemented | iana, gnu_libiconv, glibc, icu, openjdk, microsoft, ibm_i, rfc1345, wikidata |
| ENC-0908 | `IBM278` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, ibm_ccsid, icu_converter, microsoft_code_page, openjdk_charset, rfc1345_charset, wikidata_ebcdiccodepage | high | yes | yes | implemented | iana, gnu_libiconv, glibc, icu, openjdk, microsoft, ibm_i, rfc1345, wikidata |
| ENC-0909 | `IBM280` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, ibm_ccsid, icu_converter, microsoft_code_page, openjdk_charset, rfc1345_charset, wikidata_ebcdiccodepage | high | yes | yes | implemented | iana, gnu_libiconv, glibc, icu, openjdk, microsoft, ibm_i, rfc1345, wikidata |
| ENC-0910 | `IBM281` | glibc_gconv_codec, iana_registered_charset, rfc1345_charset | high | no | yes | implemented | iana, glibc, rfc1345 |
| ENC-0911 | `IBM284` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, ibm_ccsid, icu_converter, microsoft_code_page, openjdk_charset, rfc1345_charset, wikidata_ebcdiccodepage | high | yes | yes | implemented | iana, gnu_libiconv, glibc, icu, openjdk, microsoft, ibm_i, rfc1345, wikidata |
| ENC-0912 | `IBM285` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, ibm_ccsid, icu_converter, microsoft_code_page, openjdk_charset, rfc1345_charset, wikidata_codepage | high | yes | yes | implemented | iana, gnu_libiconv, glibc, icu, openjdk, microsoft, ibm_i, rfc1345, wikidata |
| ENC-0913 | `IBM290` | glibc_gconv_codec, iana_registered_charset, ibm_ccsid, microsoft_code_page, openjdk_charset, rfc1345_charset | high | no | yes | implemented | iana, glibc, openjdk, microsoft, ibm_i, rfc1345 |
| ENC-0914 | `IBM297` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, ibm_ccsid, icu_converter, microsoft_code_page, openjdk_charset, rfc1345_charset, wikidata_ebcdiccodepage | high | yes | yes | implemented | iana, gnu_libiconv, glibc, icu, openjdk, microsoft, ibm_i, rfc1345, wikidata |
| ENC-0915 | `IBM420` | glibc_gconv_codec, iana_registered_charset, ibm_ccsid, microsoft_code_page, openjdk_charset, rfc1345_charset | high | no | yes | implemented | iana, glibc, openjdk, microsoft, ibm_i, rfc1345 |
| ENC-0916 | `IBM423` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, ibm_ccsid, microsoft_code_page, rfc1345_charset, wikidata_ebcdiccodepage | high | yes | yes | implemented | iana, gnu_libiconv, glibc, microsoft, ibm_i, rfc1345, wikidata |
| ENC-0917 | `IBM424` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, ibm_ccsid, icu_converter, microsoft_code_page, openjdk_charset, python_codec, rfc1345_charset, wikidata_ebcdiccodepage | high | yes | yes | implemented | iana, gnu_libiconv, glibc, icu, openjdk, microsoft, ibm_i, rfc1345, python, wikidata |
| ENC-0918 | `IBM437` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, ibm_ccsid, icu_converter, microsoft_code_page, openjdk_charset, python_codec, rfc1345_charset | high | yes | yes | implemented | iana, gnu_libiconv, glibc, icu, openjdk, microsoft, ibm_i, rfc1345, python |
| ENC-0919 | `IBM4517` | glibc_gconv_codec | high | no | yes | implemented | glibc |
| ENC-0920 | `IBM4899` | glibc_gconv_codec | high | no | yes | implemented | glibc |
| ENC-0921 | `IBM4909` | glibc_gconv_codec | high | no | yes | implemented | glibc |
| ENC-0922 | `IBM500` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, ibm_ccsid, icu_converter, microsoft_code_page, openjdk_charset, python_codec, rfc1345_charset, wikidata_ebcdiccodepage | high | yes | yes | implemented | iana, gnu_libiconv, glibc, icu, openjdk, microsoft, ibm_i, rfc1345, python, wikidata |
| ENC-0923 | `IBM5347` | glibc_gconv_codec | high | no | yes | implemented | glibc |
| ENC-0924 | `ibm737` | ibm_ccsid, microsoft_code_page | high | no | yes | implemented | microsoft, ibm_i |
| ENC-0925 | `IBM775` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, ibm_ccsid, icu_converter, microsoft_code_page, openjdk_charset, python_codec | high | yes | yes | implemented | iana, gnu_libiconv, glibc, icu, openjdk, microsoft, ibm_i, python |
| ENC-0926 | `IBM803` | glibc_gconv_codec | high | no | yes | implemented | glibc |
| ENC-0927 | `IBM850` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, ibm_ccsid, icu_converter, microsoft_code_page, openjdk_charset, python_codec, rfc1345_charset | high | yes | yes | implemented | iana, gnu_libiconv, glibc, icu, openjdk, microsoft, ibm_i, rfc1345, python |
| ENC-0928 | `IBM851` | glibc_gconv_codec, iana_registered_charset, ibm_ccsid, rfc1345_charset | high | no | yes | implemented | iana, glibc, ibm_i, rfc1345 |
| ENC-0929 | `IBM852` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, ibm_ccsid, icu_converter, microsoft_code_page, openjdk_charset, python_codec, rfc1345_charset | high | yes | yes | implemented | iana, gnu_libiconv, glibc, icu, openjdk, microsoft, ibm_i, rfc1345, python |
| ENC-0930 | `IBM855` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, ibm_ccsid, icu_converter, microsoft_code_page, openjdk_charset, python_codec, rfc1345_charset | high | yes | yes | implemented | iana, gnu_libiconv, glibc, icu, openjdk, microsoft, ibm_i, rfc1345, python |
| ENC-0931 | `IBM857` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, ibm_ccsid, icu_converter, microsoft_code_page, openjdk_charset, python_codec, rfc1345_charset | high | yes | yes | implemented | iana, gnu_libiconv, glibc, icu, openjdk, microsoft, ibm_i, rfc1345, python |
| ENC-0932 | `IBM858` | glibc_gconv_codec, ibm_ccsid | high | no | yes | implemented | glibc, ibm_i |
| ENC-0933 | `IBM860` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, ibm_ccsid, icu_converter, microsoft_code_page, openjdk_charset, python_codec, rfc1345_charset | high | yes | yes | implemented | iana, gnu_libiconv, glibc, icu, openjdk, microsoft, ibm_i, rfc1345, python |
| ENC-0934 | `IBM861` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, ibm_ccsid, icu_converter, microsoft_code_page, openjdk_charset, python_codec, rfc1345_charset | high | yes | yes | implemented | iana, gnu_libiconv, glibc, icu, openjdk, microsoft, ibm_i, rfc1345, python |
| ENC-0935 | `IBM862` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, ibm_ccsid, icu_converter, openjdk_charset, python_codec, rfc1345_charset | high | yes | yes | implemented | iana, gnu_libiconv, glibc, icu, openjdk, ibm_i, rfc1345, python |
| ENC-0936 | `IBM863` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, ibm_ccsid, icu_converter, microsoft_code_page, openjdk_charset, python_codec, rfc1345_charset | high | yes | yes | implemented | iana, gnu_libiconv, glibc, icu, openjdk, microsoft, ibm_i, rfc1345, python |
| ENC-0937 | `IBM864` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, ibm_ccsid, icu_converter, microsoft_code_page, openjdk_charset, python_codec, rfc1345_charset | high | yes | yes | implemented | iana, gnu_libiconv, glibc, icu, openjdk, microsoft, ibm_i, rfc1345, python |
| ENC-0938 | `IBM865` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, ibm_ccsid, icu_converter, microsoft_code_page, openjdk_charset, python_codec, rfc1345_charset | high | yes | yes | implemented | iana, gnu_libiconv, glibc, icu, openjdk, microsoft, ibm_i, rfc1345, python |
| ENC-0939 | `IBM866` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, ibm_ccsid, icu_converter, openjdk_charset, python_codec, web_encoding | high | yes | yes | implemented | iana, whatwg, gnu_libiconv, glibc, icu, openjdk, ibm_i, python |
| ENC-0940 | `IBM866NAV` | glibc_gconv_codec | high | no | yes | implemented | glibc |
| ENC-0941 | `IBM868` | glibc_gconv_codec, iana_registered_charset, ibm_ccsid, openjdk_charset, rfc1345_charset | high | no | yes | implemented | iana, glibc, openjdk, ibm_i, rfc1345 |
| ENC-0942 | `IBM869` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, ibm_ccsid, icu_converter, microsoft_code_page, openjdk_charset, python_codec, rfc1345_charset | high | yes | yes | implemented | iana, gnu_libiconv, glibc, icu, openjdk, microsoft, ibm_i, rfc1345, python |
| ENC-0943 | `IBM870` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, ibm_ccsid, icu_converter, microsoft_code_page, openjdk_charset, rfc1345_charset, wikidata_ebcdiccodepage | high | yes | yes | implemented | iana, gnu_libiconv, glibc, icu, openjdk, microsoft, ibm_i, rfc1345, wikidata |
| ENC-0944 | `IBM871` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, ibm_ccsid, icu_converter, microsoft_code_page, openjdk_charset, rfc1345_charset, wikidata_ebcdiccodepage | high | yes | yes | implemented | iana, gnu_libiconv, glibc, icu, openjdk, microsoft, ibm_i, rfc1345, wikidata |
| ENC-0945 | `IBM880` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, ibm_ccsid, icu_converter, microsoft_code_page, rfc1345_charset, wikidata_ebcdiccodepage | high | yes | yes | implemented | iana, gnu_libiconv, glibc, icu, microsoft, ibm_i, rfc1345, wikidata |
| ENC-0946 | `IBM891` | glibc_gconv_codec, iana_registered_charset, ibm_ccsid, rfc1345_charset | high | no | yes | implemented | iana, glibc, ibm_i, rfc1345 |
| ENC-0947 | `IBM901` | glibc_gconv_codec | high | no | yes | implemented | glibc |
| ENC-0948 | `IBM902` | glibc_gconv_codec | high | no | yes | implemented | glibc |
| ENC-0949 | `IBM903` | glibc_gconv_codec, iana_registered_charset, ibm_ccsid, rfc1345_charset | high | no | yes | implemented | iana, glibc, ibm_i, rfc1345 |
| ENC-0950 | `IBM9030` | glibc_gconv_codec, ibm_ccsid | high | no | yes | implemented | glibc, ibm_i |
| ENC-0951 | `IBM904` | glibc_gconv_codec, iana_registered_charset, ibm_ccsid, rfc1345_charset | high | no | yes | implemented | iana, glibc, ibm_i, rfc1345 |
| ENC-0952 | `IBM905` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, ibm_ccsid, icu_converter, microsoft_code_page, rfc1345_charset, wikidata_ebcdiccodepage | high | yes | yes | implemented | iana, gnu_libiconv, glibc, icu, microsoft, ibm_i, rfc1345, wikidata |
| ENC-0953 | `IBM9066` | glibc_gconv_codec, ibm_ccsid | high | no | yes | implemented | glibc, ibm_i |
| ENC-0954 | `IBM918` | glibc_gconv_codec, iana_registered_charset, ibm_ccsid, openjdk_charset, rfc1345_charset | high | no | yes | implemented | iana, glibc, openjdk, ibm_i, rfc1345 |
| ENC-0955 | `IBM930` | glibc_gconv_codec, ibm_ccsid | high | no | yes | implemented | glibc, ibm_i |
| ENC-0956 | `IBM933` | glibc_gconv_codec, ibm_ccsid | high | no | yes | implemented | glibc, ibm_i |
| ENC-0957 | `IBM935` | glibc_gconv_codec, ibm_ccsid | high | no | yes | implemented | glibc, ibm_i |
| ENC-0958 | `IBM937` | glibc_gconv_codec, ibm_ccsid | high | no | yes | implemented | glibc, ibm_i |
| ENC-0959 | `IBM939` | glibc_gconv_codec, ibm_ccsid | high | no | yes | implemented | glibc, ibm_i |
| ENC-0960 | `IBM9448` | glibc_gconv_codec | high | no | yes | implemented | glibc |
| ENC-0961 | `IBMEL card character set` | historical_punched_card_encoding | medium | no | no | codec_gap | punched_cards |
| ENC-0962 | `IBMGRAPH` | unicode_mapping_table | high | no | yes | implemented | unicode_mappings |
| ENC-0963 | `ICELAND` | unicode_mapping_table | high | no | yes | implemented | unicode_mappings |
| ENC-0964 | `Ideographic Research Group` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0965 | `IEC_P27-1` | glibc_gconv_codec, iana_registered_charset, rfc1345_charset, wikipedia_character_set_page | high | no | yes | implemented | iana, glibc, rfc1345, wikipedia |
| ENC-0966 | `IMAP-mailbox-name` | icu_converter | high | no | yes | implemented | icu |
| ENC-0967 | `Indian Script Code for Information Interchange` | legacy_indic_encoding, wikidata_characterencoding, wikipedia_character_set_page | medium | no | yes | implemented | wikidata, wikipedia, supplement |
| ENC-0968 | `INIS` | glibc_gconv_codec, iana_registered_charset, rfc1345_charset | high | no | yes | implemented | iana, glibc, rfc1345 |
| ENC-0969 | `INIS character set` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-0970 | `INIS, Cyrillic Extension of Reg. 49` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-0971 | `INIS, Non-standard Extension of Reg. 49` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-0972 | `INIS, Sub-set of the IRV` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-0973 | `INIS-8` | glibc_gconv_codec, iana_registered_charset, rfc1345_charset, wikipedia_character_set_page | high | no | yes | implemented | iana, glibc, rfc1345, wikipedia |
| ENC-0974 | `INIS-cyrillic` | glibc_gconv_codec, iana_registered_charset, rfc1345_charset | high | no | yes | implemented | iana, glibc, rfc1345 |
| ENC-0975 | `International Alphabet No. 5` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-0976 | `International maritime signal flags` | visual_character_code | medium | no | no | visual_signaling_system | supplement |
| ENC-0977 | `International Reference Alphabet` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0978 | `International Telegraph Alphabet No. 1` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-0979 | `International Telegraph Alphabet No. 2` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-0980 | `International Telegraph Alphabet No. 3` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-0981 | `INVARIANT` | iana_registered_charset, rfc1345_charset | high | no | yes | implemented | iana, rfc1345 |
| ENC-0982 | `Invariant characters (82) of ISO/IEC 646` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-0983 | `IRA (character encoding)` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-0984 | `Iran System encoding` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0985 | `Iran System encoding standard` | wikidata_characterencoding | medium | no | no | codec_gap | wikidata |
| ENC-0986 | `IRV of ISO 646 : 1983` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-0987 | `ISCII,version=0` | icu_converter | high | no | yes | implemented | icu |
| ENC-0988 | `ISCII,version=1` | icu_converter | high | no | yes | implemented | icu |
| ENC-0989 | `ISCII,version=2` | icu_converter | high | no | yes | implemented | icu |
| ENC-0990 | `ISCII,version=3` | icu_converter | high | no | yes | implemented | icu |
| ENC-0991 | `ISCII,version=4` | icu_converter | high | no | yes | implemented | icu |
| ENC-0992 | `ISCII,version=5` | icu_converter | high | no | yes | implemented | icu |
| ENC-0993 | `ISCII,version=6` | icu_converter | high | no | yes | implemented | icu |
| ENC-0994 | `ISCII,version=7` | icu_converter | high | no | yes | implemented | icu |
| ENC-0995 | `ISCII,version=8` | icu_converter | high | no | yes | implemented | icu |
| ENC-0996 | `ISIRI-3342` | glibc_gconv_codec | high | no | yes | implemented | glibc |
| ENC-0997 | `ISO 10585` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-0998 | `ISO 5426` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-0999 | `ISO 6438` | wikidata_characterencoding, wikipedia_character_set_page | medium | no | yes | implemented | wikidata, wikipedia |
| ENC-1000 | `ISO 646` | historical_information_system_encoding | medium | no | no | encoding_family | wikipedia_historical |
| ENC-1001 | `ISO 646, British Version BSI 4730` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-1002 | `ISO 646, French Version NF Z 62010-1982` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-1003 | `ISO 646, French Version, NF Z 62010-1973 (Withdrawn in April 1985)` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-1004 | `ISO 646, German Version DIN 66083` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-1005 | `ISO 646, Hungarian Version Hungarian standard 7795/3` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-1006 | `ISO 646, Norwegian Version NS 4551` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-1007 | `ISO 646, Swedish Version for Names, (SEN 850200 Ann. C)` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-1008 | `ISO 646, Swedish Version SEN 850200 (Ann. B)` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-1009 | `ISO 646, Version for Italian, ECMA (Olivetti)` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-1010 | `ISO 646, Version for Portuguese, ECMA (IBM)` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-1011 | `ISO 646, Version for Portuguese, ECMA (Olivetti)` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-1012 | `ISO 646, Version for Spanish, ECMA (Olivetti)` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-1013 | `ISO 646, Version for the Spanish languages, ECMA (IBM)` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-1014 | `ISO IR-68` | wikidata_aplcodepage, wikipedia_character_set_page | medium | no | yes | implemented | wikidata, wikipedia |
| ENC-1015 | `ISO-10646-J-1` | iana_registered_charset | high | no | yes | implemented | iana |
| ENC-1016 | `ISO-10646-UCS-2` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, unicode_encoding | high | yes | yes | implemented | iana, gnu_libiconv, glibc, kermit |
| ENC-1017 | `ISO-10646-UCS-4` | gnu_fixed_codec, iana_registered_charset | high | yes | yes | implemented | iana, gnu_libiconv |
| ENC-1018 | `ISO-10646-UCS-Basic` | iana_registered_charset | high | no | yes | implemented | iana |
| ENC-1019 | `ISO-10646-Unicode-Latin1` | iana_registered_charset | high | no | yes | implemented | iana |
| ENC-1020 | `ISO-10646-UTF-1` | iana_registered_charset | high | no | yes | implemented | iana |
| ENC-1021 | `ISO-11548-1` | glibc_gconv_codec, iana_registered_charset | high | no | yes | implemented | iana, glibc |
| ENC-1022 | `ISO-2022-CN` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, icu_converter, openjdk_charset | high | yes | yes | implemented | iana, gnu_libiconv, glibc, icu, openjdk |
| ENC-1023 | `ISO-2022-CN-EXT` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, icu_converter | high | yes | yes | implemented | iana, gnu_libiconv, glibc, icu |
| ENC-1024 | `ISO-2022-JP` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, icu_converter, microsoft_code_page, multibyte_encoding, openjdk_charset, python_codec, web_encoding, wikidata_variablewidthcharacterencoding | high | yes | yes | implemented | iana, whatwg, gnu_libiconv, glibc, icu, openjdk, microsoft, python, kermit, wikidata |
| ENC-1025 | `ISO-2022-JP-1` | gnu_fixed_codec, icu_converter, python_codec | high | yes | yes | implemented | gnu_libiconv, icu, python |
| ENC-1026 | `ISO-2022-JP-2` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, icu_converter, openjdk_charset, python_codec | high | yes | yes | implemented | iana, gnu_libiconv, glibc, icu, openjdk, python |
| ENC-1027 | `ISO-2022-JP-3` | glibc_gconv_codec, gnu_fixed_codec, python_codec, wikidata_variablewidthcharacterencoding | high | yes | yes | implemented | gnu_libiconv, glibc, python, wikidata |
| ENC-1028 | `ISO-2022-JP-MS` | gnu_fixed_codec | high | yes | yes | implemented | gnu_libiconv |
| ENC-1029 | `ISO-2022-KR` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, icu_converter, microsoft_code_page, openjdk_charset, python_codec | high | yes | yes | implemented | iana, gnu_libiconv, glibc, icu, openjdk, microsoft, python |
| ENC-1030 | `ISO-8859-1` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, ibm_ccsid, icu_converter, iso_ir_coded_character_set, microsoft_code_page, openjdk_charset, python_codec, rfc1345_charset, standard_8bit_set, wikidata_extendedascii, wikipedia_character_set_page | high | yes | yes | implemented | iana, gnu_libiconv, glibc, icu, openjdk, microsoft, ibm_i, iso_ir, rfc1345, python, kermit, wikidata, wikipedia |
| ENC-1031 | `ISO-8859-1-Windows-3.0-Latin-1` | iana_registered_charset | high | no | yes | implemented | iana |
| ENC-1032 | `ISO-8859-1-Windows-3.1-Latin-1` | iana_registered_charset | high | no | yes | implemented | iana |
| ENC-1033 | `ISO-8859-10` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, icu_converter, iso_ir_coded_character_set, python_codec, rfc1345_charset, web_encoding, wikidata_extendedascii, wikipedia_character_set_page | high | yes | yes | implemented | iana, whatwg, gnu_libiconv, glibc, icu, iso_ir, rfc1345, python, wikidata, wikipedia |
| ENC-1034 | `ISO-8859-11` | glibc_gconv_codec, gnu_fixed_codec, icu_converter, openjdk_charset, python_codec, wikidata_extendedascii, wikipedia_character_set_page | high | yes | yes | implemented | gnu_libiconv, glibc, icu, openjdk, python, wikidata, wikipedia |
| ENC-1035 | `ISO-8859-13` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, ibm_ccsid, icu_converter, iso_ir_coded_character_set, microsoft_code_page, openjdk_charset, python_codec, web_encoding, wikidata_extendedascii, wikipedia_character_set_page | high | yes | yes | implemented | iana, whatwg, gnu_libiconv, glibc, icu, openjdk, microsoft, ibm_i, iso_ir, python, wikidata, wikipedia |
| ENC-1036 | `ISO-8859-14` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, icu_converter, iso_ir_coded_character_set, python_codec, web_encoding, wikidata_extendedascii, wikipedia_character_set_page | high | yes | yes | implemented | iana, whatwg, gnu_libiconv, glibc, icu, iso_ir, python, wikidata, wikipedia |
| ENC-1037 | `ISO-8859-15` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, ibm_ccsid, icu_converter, iso_ir_coded_character_set, microsoft_code_page, openjdk_charset, python_codec, standard_8bit_set, web_encoding, wikidata_extendedascii, wikipedia_character_set_page | high | yes | yes | implemented | iana, whatwg, gnu_libiconv, glibc, icu, openjdk, microsoft, ibm_i, iso_ir, python, kermit, wikidata, wikipedia |
| ENC-1038 | `ISO-8859-16` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, icu_converter, iso_ir_coded_character_set, openjdk_charset, python_codec, web_encoding, wikidata_extendedascii, wikipedia_character_set_page | high | yes | yes | implemented | iana, whatwg, gnu_libiconv, glibc, icu, openjdk, iso_ir, python, wikidata, wikipedia |
| ENC-1039 | `ISO-8859-2` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, ibm_ccsid, icu_converter, iso_ir_coded_character_set, microsoft_code_page, openjdk_charset, python_codec, rfc1345_charset, standard_8bit_set, unicode_mapping_table, web_encoding, wikidata_extendedascii, wikipedia_character_set_page | high | yes | yes | implemented | iana, whatwg, gnu_libiconv, glibc, icu, openjdk, microsoft, ibm_i, iso_ir, rfc1345, unicode_mappings, python, kermit, wikidata, wikipedia |
| ENC-1040 | `ISO-8859-2-Windows-Latin-2` | iana_registered_charset | high | no | yes | implemented | iana |
| ENC-1041 | `ISO-8859-3` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, icu_converter, iso_ir_coded_character_set, microsoft_code_page, openjdk_charset, python_codec, rfc1345_charset, standard_8bit_set, web_encoding, wikidata_extendedascii, wikipedia_character_set_page | high | yes | yes | implemented | iana, whatwg, gnu_libiconv, glibc, icu, openjdk, microsoft, iso_ir, rfc1345, python, kermit, wikidata, wikipedia |
| ENC-1042 | `ISO-8859-4` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, ibm_ccsid, icu_converter, iso_ir_coded_character_set, microsoft_code_page, openjdk_charset, python_codec, rfc1345_charset, standard_8bit_set, web_encoding, wikidata_extendedascii, wikipedia_character_set_page | high | yes | yes | implemented | iana, whatwg, gnu_libiconv, glibc, icu, openjdk, microsoft, ibm_i, iso_ir, rfc1345, python, kermit, wikidata, wikipedia |
| ENC-1043 | `ISO-8859-5` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, ibm_ccsid, icu_converter, iso_ir_coded_character_set, microsoft_code_page, openjdk_charset, python_codec, rfc1345_charset, standard_8bit_set, web_encoding, wikidata_extendedascii, wikipedia_character_set_page | high | yes | yes | implemented | iana, whatwg, gnu_libiconv, glibc, icu, openjdk, microsoft, ibm_i, iso_ir, rfc1345, python, kermit, wikidata, wikipedia |
| ENC-1044 | `ISO-8859-6` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, ibm_ccsid, icu_converter, iso_ir_coded_character_set, microsoft_code_page, openjdk_charset, python_codec, rfc1345_charset, standard_8bit_set, web_encoding, wikidata_extendedascii, wikipedia_character_set_page | high | yes | yes | implemented | iana, whatwg, gnu_libiconv, glibc, icu, openjdk, microsoft, ibm_i, iso_ir, rfc1345, python, kermit, wikidata, wikipedia |
| ENC-1045 | `ISO-8859-6-E` | iana_registered_charset | high | no | yes | implemented | iana |
| ENC-1046 | `ISO-8859-6-I` | iana_registered_charset | high | no | yes | implemented | iana |
| ENC-1047 | `ISO-8859-7` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, ibm_ccsid, icu_converter, iso_ir_coded_character_set, microsoft_code_page, openjdk_charset, python_codec, rfc1345_charset, web_encoding, wikidata_extendedascii, wikipedia_character_set_page | high | yes | yes | implemented | iana, whatwg, gnu_libiconv, glibc, icu, openjdk, microsoft, ibm_i, iso_ir, rfc1345, python, wikidata, wikipedia |
| ENC-1048 | `ISO-8859-8` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, ibm_ccsid, icu_converter, iso_ir_coded_character_set, microsoft_code_page, openjdk_charset, python_codec, rfc1345_charset, web_encoding, wikidata_extendedascii, wikipedia_character_set_page | high | yes | yes | implemented | iana, whatwg, gnu_libiconv, glibc, icu, openjdk, microsoft, ibm_i, iso_ir, rfc1345, python, wikidata, wikipedia |
| ENC-1049 | `ISO-8859-8-E` | iana_registered_charset | high | no | yes | implemented | iana |
| ENC-1050 | `ISO-8859-8-I` | iana_registered_charset, microsoft_code_page, web_encoding, wikipedia_character_set_page | high | no | yes | implemented | iana, whatwg, microsoft, wikipedia |
| ENC-1051 | `ISO-8859-9` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, ibm_ccsid, icu_converter, iso_ir_coded_character_set, microsoft_code_page, openjdk_charset, python_codec, rfc1345_charset, standard_8bit_set, wikidata_extendedascii, wikipedia_character_set_page | high | yes | yes | implemented | iana, gnu_libiconv, glibc, icu, openjdk, microsoft, ibm_i, iso_ir, rfc1345, python, kermit, wikidata, wikipedia |
| ENC-1052 | `ISO-8859-9-Windows-Latin-5` | iana_registered_charset | high | no | yes | implemented | iana |
| ENC-1053 | `ISO-8859-9E` | glibc_gconv_codec | high | no | yes | implemented | glibc |
| ENC-1054 | `ISO-IR-111` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-1055 | `ISO-IR-153` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-1056 | `ISO-IR-165` | gnu_fixed_codec, iso_ir_coded_character_set, wikipedia_character_set_page | high | yes | yes | implemented | gnu_libiconv, iso_ir, wikipedia |
| ENC-1057 | `ISO-IR-169` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-1058 | `ISO-IR-182` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-1059 | `ISO-IR-197` | glibc_gconv_codec, wikipedia_character_set_page | high | no | yes | implemented | glibc, wikipedia |
| ENC-1060 | `ISO-IR-209` | glibc_gconv_codec | high | no | yes | implemented | glibc |
| ENC-1061 | `iso-ir-90` | iana_registered_charset, rfc1345_charset | high | no | yes | implemented | iana, rfc1345 |
| ENC-1062 | `ISO-Unicode-IBM-1261` | iana_registered_charset | high | no | no | repertoire_profile | iana |
| ENC-1063 | `ISO-Unicode-IBM-1264` | iana_registered_charset | high | no | no | repertoire_profile | iana |
| ENC-1064 | `ISO-Unicode-IBM-1265` | iana_registered_charset | high | no | no | repertoire_profile | iana |
| ENC-1065 | `ISO-Unicode-IBM-1268` | iana_registered_charset | high | no | no | repertoire_profile | iana |
| ENC-1066 | `ISO-Unicode-IBM-1276` | iana_registered_charset | high | no | no | repertoire_profile | iana |
| ENC-1067 | `ISO/IEC 10367` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-1068 | `ISO/IEC 10646 (Unicode)` | historical_information_system_encoding | medium | no | no | encoding_family | wikipedia_historical |
| ENC-1069 | `ISO/IEC 10646:1993, UCS-2, Level 1` | iso_ir_coding_system | high | no | yes | implemented | iso_ir |
| ENC-1070 | `ISO/IEC 10646:1993, UCS-2, Level 2` | iso_ir_coding_system | high | no | yes | implemented | iso_ir |
| ENC-1071 | `ISO/IEC 10646:1993, UCS-2, Level 3` | iso_ir_coding_system | high | no | yes | implemented | iso_ir |
| ENC-1072 | `ISO/IEC 10646:1993, UCS-4, Level 1` | iso_ir_coding_system | high | no | yes | implemented | iso_ir |
| ENC-1073 | `ISO/IEC 10646:1993, UCS-4, Level 2` | iso_ir_coding_system | high | no | yes | implemented | iso_ir |
| ENC-1074 | `ISO/IEC 10646:1993, UCS-4, Level 3` | iso_ir_coding_system | high | no | yes | implemented | iso_ir |
| ENC-1075 | `ISO/IEC 2022` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-1076 | `ISO/IEC 646` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-1077 | `ISO/IEC 8859` | historical_information_system_encoding, wikipedia_character_set_page | medium | no | no | encoding_family | wikipedia_historical, wikipedia |
| ENC-1078 | `ISO/IEC 8859-12` | wikidata_extendedascii, wikipedia_character_set_page | medium | no | no | withdrawn_unassigned_part | wikidata, wikipedia |
| ENC-1079 | `iso2022-jp-ext` | python_codec | medium | no | yes | implemented | python |
| ENC-1080 | `ISO_10367-box` | glibc_gconv_codec, iana_registered_charset, rfc1345_charset | high | no | yes | implemented | iana, glibc, rfc1345 |
| ENC-1081 | `ISO_2022,locale=ja,version=3` | icu_converter | high | no | yes | implemented | icu |
| ENC-1082 | `ISO_2022,locale=ja,version=4` | icu_converter | high | no | yes | implemented | icu |
| ENC-1083 | `ISO_2022,locale=ko,version=1` | icu_converter | high | no | yes | implemented | icu |
| ENC-1084 | `ISO_2022,locale=zh,version=2` | icu_converter | high | no | no | codec_gap | icu |
| ENC-1085 | `ISO_2033` | glibc_gconv_codec, wikipedia_character_set_page | high | no | yes | implemented | glibc, wikipedia |
| ENC-1086 | `ISO_2033-1983` | iana_registered_charset, rfc1345_charset | high | no | yes | implemented | iana, rfc1345 |
| ENC-1087 | `ISO_5427` | glibc_gconv_codec, iana_registered_charset, rfc1345_charset, wikipedia_character_set_page | high | no | yes | implemented | iana, glibc, rfc1345, wikipedia |
| ENC-1088 | `ISO_5427-EXT` | glibc_gconv_codec | high | no | yes | implemented | glibc |
| ENC-1089 | `ISO_5427:1981` | iana_registered_charset, rfc1345_charset | high | no | yes | implemented | iana, rfc1345 |
| ENC-1090 | `ISO_5428` | glibc_gconv_codec, wikidata_characterencoding, wikipedia_character_set_page | high | no | yes | implemented | glibc, wikidata, wikipedia |
| ENC-1091 | `ISO_5428:1980` | iana_registered_charset, rfc1345_charset | high | no | yes | implemented | iana, rfc1345 |
| ENC-1092 | `ISO_646.basic:1983` | iana_registered_charset, rfc1345_charset | high | no | yes | implemented | iana, rfc1345 |
| ENC-1093 | `ISO_646.irv:1983` | iana_registered_charset, rfc1345_charset | high | no | yes | implemented | iana, rfc1345 |
| ENC-1094 | `ISO_6937` | glibc_gconv_codec, wikipedia_character_set_page | high | no | yes | implemented | glibc, wikipedia |
| ENC-1095 | `ISO_6937-2` | glibc_gconv_codec | high | no | yes | implemented | glibc |
| ENC-1096 | `ISO_6937-2-25` | iana_registered_charset, rfc1345_charset | high | no | yes | implemented | iana, rfc1345 |
| ENC-1097 | `ISO_6937-2-add` | iana_registered_charset, rfc1345_charset | high | no | yes | implemented | iana, rfc1345 |
| ENC-1098 | `ISO_8859-supp` | iana_registered_charset, rfc1345_charset | high | no | yes | implemented | iana, rfc1345 |
| ENC-1099 | `IT` | glibc_gconv_codec, iana_registered_charset, national_replacement_set, rfc1345_charset | high | no | yes | implemented | iana, glibc, rfc1345, kermit |
| ENC-1100 | `ITA1` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-1101 | `ITA2` | historical_information_system_encoding, telegraph_code, wikipedia_character_set_page | high | no | yes | implemented | wikipedia_historical, wikipedia, supplement |
| ENC-1102 | `ITA2-S2` | telegraph_coding_scheme | high | no | yes | implemented | supplement |
| ENC-1103 | `ITA3` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-1104 | `ITU T.61` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-1105 | `Japanese Additional Handprinted Graphic Character Set for OCR JIS C6229- 1984` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-1106 | `Japanese Basic Hand-printed Graphic Set for OCR JIS C6229-1984` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-1107 | `Japanese Character Set JISC C 6226-1978` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-1108 | `Japanese Graphic Character Set for Information Interchange --- Plane 1` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-1109 | `Japanese Graphic Character Set for Information Interchange --- Plane 2` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-1110 | `Japanese Graphic Character Set for Information Interchange, Plane 1 (Update of ISO-IR 228)` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-1111 | `Japanese language in EBCDIC` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-1112 | `Japanese OCR-A graphic set JIS C6229-1984` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-1113 | `Japanese OCR-B Graphic Set JIS C6229-1984` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-1114 | `Japanese OCR-B, Additional Graphic Set, JIS C6229-1984` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-1115 | `JAVA` | gnu_fixed_codec | high | yes | yes | implemented | gnu_libiconv |
| ENC-1116 | `java-Cp1390A-1.6_P` | icu_converter | high | no | yes | implemented | icu |
| ENC-1117 | `java-Cp1399A-1.6_P` | icu_converter | high | no | yes | implemented | icu |
| ENC-1118 | `java-Cp420s-1.6_P` | icu_converter | high | no | yes | implemented | icu |
| ENC-1119 | `java-euc_jp_linux-1.6_P` | icu_converter | high | no | yes | implemented | icu |
| ENC-1120 | `java-sjis_0213-1.6_P` | icu_converter | high | no | yes | implemented | icu |
| ENC-1121 | `JEF codepage` | wikidata_ebcdiccodepage | medium | no | no | codec_gap | wikidata |
| ENC-1122 | `JIS kanji codes` | wikidata_codedcharacterset | medium | no | no | encoding_family | wikidata |
| ENC-1123 | `JIS X 0211` | wikidata_characterencoding | medium | no | no | control_standard | wikidata |
| ENC-1124 | `JIS X 0213` | wikidata_codedcharacterset | medium | no | no | repertoire_profile | wikidata |
| ENC-1125 | `JIS X 0221` | wikidata_codedcharacterset | medium | no | no | encoding_family | wikidata |
| ENC-1126 | `JIS0201` | unicode_mapping_table | high | no | yes | implemented | unicode_mappings |
| ENC-1127 | `JIS0212` | unicode_mapping_table | high | no | yes | implemented | unicode_mappings |
| ENC-1128 | `JIS7-KANJI` | multibyte_encoding, stateful_multibyte_encoding | high | no | yes | implemented | kermit, supplement |
| ENC-1129 | `JIS_C6220-1969-jp` | iana_registered_charset, rfc1345_charset | high | no | yes | implemented | iana, rfc1345 |
| ENC-1130 | `JIS_C6220-1969-ro` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, iso_ir_coded_character_set, national_replacement_set, rfc1345_charset | high | yes | yes | implemented | iana, gnu_libiconv, glibc, iso_ir, rfc1345, kermit |
| ENC-1131 | `JIS_C6226-1978` | iana_registered_charset, rfc1345_charset | high | no | yes | implemented | iana, rfc1345 |
| ENC-1132 | `JIS_C6226-1983` | gnu_fixed_codec, iana_registered_charset, iso_ir_coded_character_set, openjdk_charset, rfc1345_charset, unicode_mapping_table, wikidata_codedcharacterset, wikipedia_character_set_page | high | yes | yes | implemented | iana, gnu_libiconv, openjdk, iso_ir, rfc1345, unicode_mappings, wikidata, wikipedia |
| ENC-1133 | `JIS_C6229-1984-a` | iana_registered_charset, rfc1345_charset | high | no | yes | implemented | iana, rfc1345 |
| ENC-1134 | `JIS_C6229-1984-b` | glibc_gconv_codec, iana_registered_charset, rfc1345_charset | high | no | yes | implemented | iana, glibc, rfc1345 |
| ENC-1135 | `JIS_C6229-1984-b-add` | iana_registered_charset, rfc1345_charset | high | no | yes | implemented | iana, rfc1345 |
| ENC-1136 | `JIS_C6229-1984-hand` | iana_registered_charset, rfc1345_charset | high | no | yes | implemented | iana, rfc1345 |
| ENC-1137 | `JIS_C6229-1984-hand-add` | iana_registered_charset, rfc1345_charset | high | no | yes | implemented | iana, rfc1345 |
| ENC-1138 | `JIS_C6229-1984-kana` | iana_registered_charset, rfc1345_charset | high | no | yes | implemented | iana, rfc1345 |
| ENC-1139 | `JIS_Encoding` | iana_registered_charset, wikipedia_character_set_page | high | no | yes | implemented | iana, wikipedia |
| ENC-1140 | `JIS_X0201` | gnu_fixed_codec, historical_information_system_encoding, iana_registered_charset, icu_converter, openjdk_charset, rfc1345_charset, wikidata_codedcharacterset | high | yes | yes | implemented | iana, gnu_libiconv, icu, openjdk, rfc1345, wikidata, wikipedia_historical |
| ENC-1141 | `JIS_X0212-1990` | gnu_fixed_codec, iana_registered_charset, icu_converter, iso_ir_coded_character_set, openjdk_charset, rfc1345_charset, wikidata_codedcharacterset | high | yes | yes | implemented | iana, gnu_libiconv, icu, openjdk, iso_ir, rfc1345, wikidata |
| ENC-1142 | `JOHAB` | glibc_gconv_codec, gnu_fixed_codec, icu_converter, microsoft_code_page, openjdk_charset, python_codec, unicode_mapping_table, wikidata_characterencoding | high | yes | yes | implemented | gnu_libiconv, glibc, icu, openjdk, microsoft, unicode_mappings, python, wikidata |
| ENC-1143 | `Juki Toitsu Moji` | wikidata_codedcharacterset | medium | no | no | repertoire_profile | wikidata |
| ENC-1144 | `JUS I.B1.003` | wikipedia_character_set_page | candidate | no | no | encoding_family | wikipedia |
| ENC-1145 | `JUS I.B1.004` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-1146 | `JUS_I.B1.002` | glibc_gconv_codec, iana_registered_charset, rfc1345_charset, wikipedia_character_set_page | high | no | yes | implemented | iana, glibc, rfc1345, wikipedia |
| ENC-1147 | `JUS_I.B1.003-mac` | iana_registered_charset, rfc1345_charset | high | no | yes | implemented | iana, rfc1345 |
| ENC-1148 | `JUS_I.B1.003-serb` | iana_registered_charset, rfc1345_charset | high | no | yes | implemented | iana, rfc1345 |
| ENC-1149 | `Kamenický encoding` | single_byte_character_encoding, wikidata_characterencoding, wikipedia_character_set_page | high | no | yes | implemented | wikidata, wikipedia, supplement |
| ENC-1150 | `KanjiTalk` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-1151 | `KATAKANA` | national_replacement_set | medium | no | yes | implemented | kermit |
| ENC-1152 | `Katakana Character Set JIS C6220-1969` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-1153 | `Katakana hand-printed Graphic Character Set for OCR JIS C6229-1984` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-1154 | `KOI character encodings` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-1155 | `KOI-8` | glibc_gconv_codec, vendor_8bit_set, wikidata_characterencoding, wikipedia_character_set_page | high | no | yes | implemented | glibc, kermit, wikidata, wikipedia |
| ENC-1156 | `KOI7-switched` | iana_registered_charset | high | no | yes | implemented | iana |
| ENC-1157 | `KOI8-B` | wikidata_characterencoding, wikipedia_character_set_page | medium | no | no | repertoire_profile | wikidata, wikipedia |
| ENC-1158 | `KOI8-F` | legacy_cyrillic_encoding, wikidata_characterencoding, wikipedia_character_set_page | high | no | yes | implemented | wikidata, wikipedia, supplement |
| ENC-1159 | `KOI8-O` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-1160 | `KOI8-R` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, ibm_ccsid, icu_converter, microsoft_code_page, openjdk_charset, python_codec, unicode_mapping_table, vendor_8bit_set, web_encoding, wikidata_codedcharacterset, wikipedia_character_set_page | high | yes | yes | implemented | iana, whatwg, gnu_libiconv, glibc, icu, openjdk, microsoft, ibm_i, unicode_mappings, python, kermit, wikidata, wikipedia |
| ENC-1161 | `KOI8-RU` | glibc_gconv_codec, gnu_fixed_codec, icu_converter, wikidata_characterencoding, wikipedia_character_set_page | high | yes | yes | implemented | gnu_libiconv, glibc, icu, wikidata, wikipedia |
| ENC-1162 | `KOI8-T` | glibc_gconv_codec, gnu_fixed_codec, python_codec, wikidata_characterencoding, wikipedia_character_set_page | high | yes | yes | implemented | gnu_libiconv, glibc, python, wikidata, wikipedia |
| ENC-1163 | `KOI8-U` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, icu_converter, microsoft_code_page, openjdk_charset, python_codec, unicode_mapping_table, vendor_8bit_set, web_encoding, wikidata_codedcharacterset, wikipedia_character_set_page | high | yes | yes | implemented | iana, whatwg, gnu_libiconv, glibc, icu, openjdk, microsoft, unicode_mappings, python, kermit, wikidata, wikipedia |
| ENC-1164 | `KPS 10721` | wikidata_characterencoding, wikidata_codedcharacterset | medium | no | no | codec_gap | wikidata |
| ENC-1165 | `KPS9566` | historical_information_system_encoding, unicode_mapping_table, wikidata_characterencoding, wikipedia_character_set_page | high | no | yes | implemented | unicode_mappings, wikidata, wikipedia_historical, wikipedia |
| ENC-1166 | `KS X 1002` | wikidata_characterencoding, wikidata_codedcharacterset, wikipedia_character_set_page | medium | no | no | codec_gap | wikidata, wikipedia |
| ENC-1167 | `KS X 1003` | wikidata_codedcharacterset | medium | no | no | codec_gap | wikidata |
| ENC-1168 | `KS X 1005` | wikidata_characterencoding | medium | no | no | codec_gap | wikidata |
| ENC-1169 | `KS_C_5601-1987` | gnu_fixed_codec, iana_registered_charset, icu_converter, iso_ir_coded_character_set, microsoft_code_page, rfc1345_charset, unicode_mapping_table | high | yes | yes | implemented | iana, gnu_libiconv, icu, microsoft, iso_ir, rfc1345, unicode_mappings |
| ENC-1170 | `KSC5636` | glibc_gconv_codec, iana_registered_charset, rfc1345_charset | high | no | yes | implemented | iana, glibc, rfc1345 |
| ENC-1171 | `KSX1001` | unicode_mapping_table, wikidata_characterencoding, wikidata_codedcharacterset, wikipedia_character_set_page | high | no | yes | implemented | unicode_mappings, wikidata, wikipedia |
| ENC-1172 | `KZ-1048` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, icu_converter, python_codec, unicode_mapping_table | high | yes | yes | implemented | iana, gnu_libiconv, glibc, icu, unicode_mappings, python |
| ENC-1173 | `latin-greek` | glibc_gconv_codec, iana_registered_charset, rfc1345_charset | high | no | yes | implemented | iana, glibc, rfc1345 |
| ENC-1174 | `Latin-Greek Character Set, ECMA (Honeywell-Bull)` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-1175 | `Latin-Greek Character Set, ECMA (Olivetti)` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-1176 | `Latin-greek-1` | glibc_gconv_codec, iana_registered_charset, rfc1345_charset | high | no | yes | implemented | iana, glibc, rfc1345 |
| ENC-1177 | `latin-lap` | iana_registered_charset, rfc1345_charset | high | no | yes | implemented | iana, rfc1345 |
| ENC-1178 | `Latin/Hebrew Alphabet` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-1179 | `Latin/Hebrew character set for 8-bit codes` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-1180 | `LATIN6-ISO` | standard_8bit_set | medium | no | yes | implemented | kermit |
| ENC-1181 | `LMBCS-1` | icu_converter, stateful_character_encoding | high | no | yes | implemented | icu, supplement |
| ENC-1182 | `LMBCS-11` | stateful_character_encoding | high | no | yes | implemented | supplement |
| ENC-1183 | `LMBCS-16` | stateful_character_encoding | high | no | yes | implemented | supplement |
| ENC-1184 | `LMBCS-17` | stateful_character_encoding | high | no | yes | implemented | supplement |
| ENC-1185 | `LMBCS-18` | stateful_character_encoding | high | no | yes | implemented | supplement |
| ENC-1186 | `LMBCS-19` | stateful_character_encoding | high | no | yes | implemented | supplement |
| ENC-1187 | `LMBCS-2` | stateful_character_encoding | high | no | yes | implemented | supplement |
| ENC-1188 | `LMBCS-3` | stateful_character_encoding | high | no | yes | implemented | supplement |
| ENC-1189 | `LMBCS-4` | stateful_character_encoding | high | no | yes | implemented | supplement |
| ENC-1190 | `LMBCS-5` | stateful_character_encoding | high | no | yes | implemented | supplement |
| ENC-1191 | `LMBCS-6` | stateful_character_encoding | high | no | yes | implemented | supplement |
| ENC-1192 | `LMBCS-8` | stateful_character_encoding | high | no | yes | implemented | supplement |
| ENC-1193 | `Lotus International Character Set` | single_byte_character_encoding, wikidata_characterencoding, wikipedia_character_set_page | high | no | yes | implemented | wikidata, wikipedia, supplement |
| ENC-1194 | `Lotus Multi-Byte Character Set` | wikidata_characterencoding, wikipedia_character_set_page | medium | no | no | encoding_family | wikidata, wikipedia |
| ENC-1195 | `LST 1564` | source_qualified_sequence_single_byte_encoding, wikipedia_character_set_page | high | no | yes | implemented | wikipedia, supplement |
| ENC-1196 | `LST 1590-2` | source_qualified_sequence_single_byte_encoding, wikidata_characterencoding | high | no | yes | implemented | wikidata, supplement |
| ENC-1197 | `LST 1590-4` | source_qualified_sequence_single_byte_encoding, wikidata_characterencoding, wikipedia_character_set_page | high | no | yes | implemented | wikidata, wikipedia, supplement |
| ENC-1198 | `LY1 encoding` | source_qualified_glyph_vector_unicode_encoding, wikipedia_character_set_page | high | no | yes | implemented | wikipedia, supplement |
| ENC-1199 | `Mac OS Armenian` | source_qualified_single_byte_character_encoding, wikipedia_character_set_page | high | no | yes | implemented | wikipedia, supplement |
| ENC-1200 | `Mac OS Barents Cyrillic` | source_qualified_single_byte_character_encoding, wikipedia_character_set_page | high | no | yes | implemented | wikipedia, supplement |
| ENC-1201 | `Mac OS Celtic` | unicode_mapping_table, wikidata_codedcharacterset, wikidata_extendedascii, wikipedia_character_set_page | high | no | yes | implemented | unicode_mappings, wikidata, wikipedia |
| ENC-1202 | `Mac OS Centeuro` | unicode_mapping_table | high | no | yes | implemented | unicode_mappings |
| ENC-1203 | `Mac OS Chinsimp` | unicode_mapping_table, wikipedia_character_set_page | high | no | yes | implemented | unicode_mappings, wikipedia |
| ENC-1204 | `Mac OS Chintrad` | unicode_mapping_table | high | no | yes | implemented | unicode_mappings |
| ENC-1205 | `Mac OS Corpchar` | unicode_character_registry_component | high | no | no | registry_component | unicode_mappings |
| ENC-1206 | `Mac OS Devanaga` | unicode_mapping_table | high | no | yes | implemented | unicode_mappings |
| ENC-1207 | `Mac OS Devanagari encoding` | legacy_macintosh_encoding, wikidata_codedcharacterset, wikidata_extendedascii, wikipedia_character_set_page | high | no | yes | implemented | wikidata, wikipedia, supplement |
| ENC-1208 | `Mac OS Dingbats` | unicode_mapping_table | high | no | yes | implemented | unicode_mappings |
| ENC-1209 | `Mac OS Farsi` | unicode_mapping_table | high | no | yes | implemented | unicode_mappings |
| ENC-1210 | `Mac OS Gaelic` | unicode_mapping_table, wikidata_codedcharacterset, wikidata_extendedascii, wikipedia_character_set_page | high | no | yes | implemented | unicode_mappings, wikidata, wikipedia |
| ENC-1211 | `Mac OS Georgian` | source_qualified_single_byte_character_encoding, wikipedia_character_set_page | high | no | yes | implemented | wikipedia, supplement |
| ENC-1212 | `Mac OS Gujarati` | unicode_mapping_table, wikipedia_character_set_page | high | no | yes | implemented | unicode_mappings, wikipedia |
| ENC-1213 | `Mac OS Gurmukhi` | unicode_mapping_table, wikidata_extendedascii, wikipedia_character_set_page | high | no | yes | implemented | unicode_mappings, wikidata, wikipedia |
| ENC-1214 | `Mac OS Inuit` | unicode_mapping_table, wikipedia_character_set_page | high | no | yes | implemented | unicode_mappings, wikipedia |
| ENC-1215 | `Mac OS Japanese` | unicode_mapping_table | high | no | yes | implemented | unicode_mappings |
| ENC-1216 | `Mac OS Keyboard` | unicode_mapping_table | high | no | yes | implemented | unicode_mappings |
| ENC-1217 | `Mac OS Keyboard encoding` | legacy_macintosh_encoding, wikidata_characterencoding, wikipedia_character_set_page | high | no | yes | implemented | wikidata, wikipedia, supplement |
| ENC-1218 | `Mac OS Korean` | unicode_mapping_table | high | no | yes | implemented | unicode_mappings |
| ENC-1219 | `Mac OS Maltese/Esperanto encoding` | source_qualified_single_byte_character_encoding, wikipedia_character_set_page | high | no | yes | implemented | wikipedia, supplement |
| ENC-1220 | `Mac OS Ogham` | source_qualified_single_byte_character_encoding, wikipedia_character_set_page | high | no | yes | implemented | wikipedia, supplement |
| ENC-1221 | `Mac OS Romanian` | unicode_mapping_table, wikidata_codedcharacterset, wikidata_extendedascii, wikipedia_character_set_page | high | no | yes | implemented | unicode_mappings, wikidata, wikipedia |
| ENC-1222 | `Mac OS Symbol` | unicode_mapping_table | high | no | yes | implemented | unicode_mappings |
| ENC-1223 | `Mac OS Sámi` | legacy_macintosh_encoding, wikidata_extendedascii, wikipedia_character_set_page | high | no | yes | implemented | wikidata, wikipedia, supplement |
| ENC-1224 | `Mac OS Turkic Cyrillic` | source_qualified_single_byte_character_encoding, wikipedia_character_set_page | high | no | yes | implemented | wikipedia, supplement |
| ENC-1225 | `mac-farsi` | python_codec | medium | no | yes | implemented | python |
| ENC-1226 | `MAC-IS` | glibc_gconv_codec | high | no | yes | implemented | glibc |
| ENC-1227 | `mac-romanian` | python_codec | medium | no | yes | implemented | python |
| ENC-1228 | `MAC-SAMI` | glibc_gconv_codec | high | no | yes | implemented | glibc |
| ENC-1229 | `MacArabic` | gnu_fixed_codec, icu_converter, legacy_macintosh_encoding, microsoft_code_page, openjdk_charset, python_codec, unicode_mapping_table, wikidata_codedcharacterset, wikidata_extendedascii, wikipedia_character_set_page | high | yes | yes | implemented | gnu_libiconv, icu, openjdk, microsoft, unicode_mappings, python, wikidata, wikipedia, supplement |
| ENC-1230 | `MacCentralEurope` | glibc_gconv_codec, gnu_fixed_codec, icu_converter, openjdk_charset, python_codec, wikidata_codedcharacterset, wikidata_extendedascii, wikipedia_character_set_page | high | yes | yes | implemented | gnu_libiconv, glibc, icu, openjdk, python, wikidata, wikipedia |
| ENC-1231 | `MacCroatian` | gnu_fixed_codec, icu_converter, microsoft_code_page, openjdk_charset, python_codec, unicode_mapping_table, wikidata_codedcharacterset, wikidata_extendedascii, wikipedia_character_set_page | high | yes | yes | implemented | gnu_libiconv, icu, openjdk, microsoft, unicode_mappings, python, wikidata, wikipedia |
| ENC-1232 | `Macedonian Cyrillic Alphabet 7/13 3.459` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-1233 | `MacEsperanto encoding` | single_byte_character_encoding, wikidata_codedcharacterset, wikidata_extendedascii | high | no | yes | implemented | wikidata, supplement |
| ENC-1234 | `MacGreek` | gnu_fixed_codec, microsoft_code_page, openjdk_charset, python_codec, unicode_mapping_table, wikipedia_character_set_page | high | yes | yes | implemented | gnu_libiconv, openjdk, microsoft, unicode_mappings, python, wikipedia |
| ENC-1235 | `MacHebrew` | gnu_fixed_codec, icu_converter, microsoft_code_page, openjdk_charset, unicode_mapping_table, wikidata_extendedascii, wikipedia_character_set_page | high | yes | yes | implemented | gnu_libiconv, icu, openjdk, microsoft, unicode_mappings, wikidata, wikipedia |
| ENC-1236 | `MacIceland` | gnu_fixed_codec, icu_converter, openjdk_charset, python_codec, unicode_mapping_table, wikipedia_character_set_page | high | yes | yes | implemented | gnu_libiconv, icu, openjdk, unicode_mappings, python, wikipedia |
| ENC-1237 | `macintosh` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, icu_converter, microsoft_code_page, openjdk_charset, python_codec, rfc1345_charset, unicode_mapping_table, web_encoding, wikidata_codedcharacterset, wikidata_extendedascii, wikipedia_character_set_page | high | yes | yes | implemented | iana, whatwg, gnu_libiconv, glibc, icu, openjdk, microsoft, rfc1345, unicode_mappings, python, wikidata, wikipedia |
| ENC-1238 | `Macintosh Font X encoding` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-1239 | `MACINTOSH-LATIN` | vendor_8bit_set, wikidata_characterencoding, wikipedia_character_set_page | medium | no | yes | implemented | kermit, wikidata, wikipedia |
| ENC-1240 | `MacJapanese` | wikidata_extendedascii, wikidata_variablewidthcharacterencoding, wikipedia_character_set_page | medium | no | yes | implemented | wikidata, wikipedia |
| ENC-1241 | `MacKorean` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-1242 | `macos-33-10.5` | icu_converter | high | no | yes | implemented | icu |
| ENC-1243 | `macos-34-10.2` | icu_converter | high | no | yes | implemented | icu |
| ENC-1244 | `macos-35-10.2` | icu_converter | high | no | yes | implemented | icu |
| ENC-1245 | `macos-6_2-10.4` | icu_converter | high | no | yes | implemented | icu |
| ENC-1246 | `MacRomania` | gnu_fixed_codec, icu_converter, openjdk_charset | high | yes | yes | implemented | gnu_libiconv, icu, openjdk |
| ENC-1247 | `MacThai` | gnu_fixed_codec, icu_converter, microsoft_code_page, openjdk_charset, unicode_mapping_table, wikipedia_character_set_page | high | yes | yes | implemented | gnu_libiconv, icu, openjdk, microsoft, unicode_mappings, wikipedia |
| ENC-1248 | `MacTurkish` | gnu_fixed_codec, microsoft_code_page, openjdk_charset, python_codec, unicode_mapping_table, wikidata_codedcharacterset, wikidata_extendedascii, wikipedia_character_set_page | high | yes | yes | implemented | gnu_libiconv, openjdk, microsoft, unicode_mappings, python, wikidata, wikipedia |
| ENC-1249 | `MacUkraine` | gnu_fixed_codec, openjdk_charset, unicode_mapping_table, wikidata_codedcharacterset, wikidata_extendedascii, wikipedia_character_set_page | high | yes | yes | implemented | gnu_libiconv, openjdk, unicode_mappings, wikidata, wikipedia |
| ENC-1250 | `Main code page (Russian)` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-1251 | `MAKSCII` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-1252 | `MARC-8` | historical_information_system_encoding, library_bibliographic_encoding, wikipedia_character_set_page | high | no | yes | implemented | wikipedia_historical, wikipedia, supplement |
| ENC-1253 | `Marlett` | wikidata_dingbattypeface | medium | no | no | font_identity | wikidata |
| ENC-1254 | `Matsushita JR series` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-1255 | `Mattel Aquarius` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-1256 | `Mattel Aquarius character set` | wikidata_characterencoding | medium | no | no | codec_gap | wikidata |
| ENC-1257 | `MAZOVIA` | vendor_8bit_set, wikidata_characterencoding, wikipedia_character_set_page | medium | no | yes | implemented | kermit, wikidata, wikipedia |
| ENC-1258 | `mbcs` | python_codec | medium | no | no | platform_adapter | python |
| ENC-1259 | `Microsoft Standard Japanese Character Set` | wikidata_codedcharacterset | medium | no | no | repertoire_profile | wikidata |
| ENC-1260 | `Microsoft-Publishing` | iana_registered_charset | high | no | yes | implemented | iana |
| ENC-1261 | `MIK` | glibc_gconv_codec, wikidata_codepage | high | no | yes | implemented | glibc, wikidata |
| ENC-1262 | `MIK (character set)` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-1263 | `MNEM` | iana_registered_charset | high | no | yes | implemented | iana |
| ENC-1264 | `MNEMONIC` | iana_registered_charset | high | no | yes | implemented | iana |
| ENC-1265 | `Modified HP Roman-8` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-1266 | `Modified UTF-8` | unicode_compatibility_encoding, wikipedia_character_set_page | medium | no | yes | implemented | wikipedia, supplement |
| ENC-1267 | `Moji Joho Kiban Ideographs` | wikidata_codedcharacterset | medium | no | no | repertoire_profile | wikidata |
| ENC-1268 | `Mojikyō` | wikidata_characterencoding, wikipedia_character_set_page | medium | no | no | codec_gap | wikidata, wikipedia |
| ENC-1269 | `Morse code` | historical_information_system_encoding, wikidata_characterencoding | medium | no | yes | implemented | wikidata, wikipedia_historical |
| ENC-1270 | `Mosaic-1 Set of Data Syntax I of CCITT Rec. T.101` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-1271 | `MouseText` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-1272 | `MSX character set` | wikidata_characterencoding, wikipedia_character_set_page | medium | no | yes | implemented | wikidata, wikipedia |
| ENC-1273 | `MSZ_7795.3` | glibc_gconv_codec, iana_registered_charset, rfc1345_charset | high | no | yes | implemented | iana, glibc, rfc1345 |
| ENC-1274 | `MULELAO-1` | gnu_fixed_codec | high | yes | yes | implemented | gnu_libiconv |
| ENC-1275 | `Murray code` | historical_information_system_encoding, telegraph_code | medium | no | no | codec_gap | wikipedia_historical, supplement |
| ENC-1276 | `MUTF-8` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-1277 | `National Replacement Character Set` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-1278 | `NATS, Primary Set for Denmark and Norway` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-1279 | `NATS, Primary Set for Finland and Sweden` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-1280 | `NATS, Secondary Set for Denmark and Norway` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-1281 | `NATS, Secondary Set for Finland and Sweden` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-1282 | `NATS-DANO` | glibc_gconv_codec, iana_registered_charset, rfc1345_charset | high | no | yes | implemented | iana, glibc, rfc1345 |
| ENC-1283 | `NATS-DANO-ADD` | iana_registered_charset, rfc1345_charset | high | no | yes | implemented | iana, rfc1345 |
| ENC-1284 | `NATS-SEFI` | glibc_gconv_codec, iana_registered_charset, rfc1345_charset | high | no | yes | implemented | iana, glibc, rfc1345 |
| ENC-1285 | `NATS-SEFI-ADD` | iana_registered_charset, rfc1345_charset | high | no | yes | implemented | iana, rfc1345 |
| ENC-1286 | `NC_NC00-10` | glibc_gconv_codec | high | no | yes | implemented | glibc |
| ENC-1287 | `NC_NC00-10:81` | iana_registered_charset, rfc1345_charset | high | no | yes | implemented | iana, rfc1345 |
| ENC-1288 | `NEC APC character set` | wikidata_characterencoding, wikipedia_character_set_page | medium | no | no | codec_gap | wikidata, wikipedia |
| ENC-1289 | `NEXTSTEP` | gnu_fixed_codec, unicode_mapping_table, vendor_8bit_set, wikidata_codepage, wikipedia_character_set_page | high | yes | yes | implemented | gnu_libiconv, unicode_mappings, kermit, wikidata, wikipedia |
| ENC-1290 | `NF_Z_62-010` | glibc_gconv_codec, iana_registered_charset, rfc1345_charset | high | no | yes | implemented | iana, glibc, rfc1345 |
| ENC-1291 | `NF_Z_62-010_(1973)` | glibc_gconv_codec, iana_registered_charset, national_replacement_set, rfc1345_charset | high | no | yes | implemented | iana, glibc, rfc1345, kermit |
| ENC-1292 | `Norwegian Character Set, Version 2, NS 4551 (Withdrawn in June 1987)` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-1293 | `NS_4551-1` | glibc_gconv_codec, iana_registered_charset, rfc1345_charset | high | no | yes | implemented | iana, glibc, rfc1345 |
| ENC-1294 | `NS_4551-2` | glibc_gconv_codec, iana_registered_charset, rfc1345_charset | high | no | yes | implemented | iana, glibc, rfc1345 |
| ENC-1295 | `NSCII` | wikidata_characterencoding | medium | no | no | codec_gap | wikidata |
| ENC-1296 | `Ogham coded character set for information interchange` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-1297 | `OLD5601` | unicode_mapping_table | high | no | yes | implemented | unicode_mappings |
| ENC-1298 | `OML encoding` | tex_math_font_encoding, wikidata_characterencoding, wikipedia_character_set_page | high | no | yes | implemented | wikidata, wikipedia, supplement |
| ENC-1299 | `OMS encoding` | tex_math_font_encoding, wikidata_characterencoding, wikipedia_character_set_page | high | no | yes | implemented | wikidata, wikipedia, supplement |
| ENC-1300 | `OSD_EBCDIC_DF03_IRV` | iana_registered_charset | high | no | yes | implemented | iana |
| ENC-1301 | `OSD_EBCDIC_DF04_1` | iana_registered_charset | high | no | yes | implemented | iana |
| ENC-1302 | `OSD_EBCDIC_DF04_15` | iana_registered_charset | high | no | yes | implemented | iana |
| ENC-1303 | `OT1 encoding` | source_qualified_font_unicode_extraction_profiles, wikipedia_character_set_page | high | no | yes | implemented | wikipedia, supplement |
| ENC-1304 | `PC8-Danish-Norwegian` | iana_registered_charset | high | no | yes | implemented | iana |
| ENC-1305 | `PC8-Turkish` | iana_registered_charset | high | no | yes | implemented | iana |
| ENC-1306 | `PCW character set` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-1307 | `PDP-1 alphanumeric codes` | early_computer_stateful_encoding, wikidata_codedcharacterset | high | no | yes | implemented | wikidata, supplement |
| ENC-1308 | `Perso-Arabic Script Code for Information Interchange` | source_qualified_legacy_octet_encoding_profiles, wikidata_characterencoding, wikipedia_character_set_page | high | no | yes | implemented | wikidata, wikipedia, supplement |
| ENC-1309 | `PETSCII` | wikidata_characterencoding, wikipedia_character_set_page | medium | no | yes | implemented | wikidata, wikipedia |
| ENC-1310 | `Photo-Videotex Data Syntax of CCITT Rec. T.101` | iso_ir_coding_system | high | no | no | non_text_coding_system | iso_ir |
| ENC-1311 | `Popularity of text encodings` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-1312 | `Portable character set` | wikidata_characterencoding, wikipedia_character_set_page | medium | no | no | repertoire_abstraction | wikidata, wikipedia |
| ENC-1313 | `PORTUGUESE` | national_replacement_set | medium | no | yes | implemented | kermit |
| ENC-1314 | `PostScript Latin 1 Encoding` | source_qualified_glyph_vector_unicode_encoding, wikipedia_character_set_page | high | no | yes | implemented | wikipedia, supplement |
| ENC-1315 | `PostScript Standard Encoding` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-1316 | `PrintableString` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-1317 | `PT` | glibc_gconv_codec, iana_registered_charset, rfc1345_charset | high | no | yes | implemented | iana, glibc, rfc1345 |
| ENC-1318 | `PT2` | glibc_gconv_codec, iana_registered_charset, rfc1345_charset | high | no | yes | implemented | iana, glibc, rfc1345 |
| ENC-1319 | `PTCP154` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, icu_converter, python_codec | high | yes | yes | implemented | iana, gnu_libiconv, glibc, icu, python |
| ENC-1320 | `Punycode` | unicode_ascii_transform, wikipedia_character_set_page | high | no | yes | implemented | wikipedia, supplement |
| ENC-1321 | `Q11496598` | wikidata_codedcharacterset | medium | no | no | repertoire_profile | wikidata |
| ENC-1322 | `Q65228706` | wikidata_codedcharacterset | medium | no | no | repertoire_profile | wikidata |
| ENC-1323 | `Q65274238` | wikidata_codedcharacterset | medium | no | no | repertoire_profile | wikidata |
| ENC-1324 | `QNX-CONSOLE` | standard_8bit_set | medium | no | yes | implemented | kermit |
| ENC-1325 | `quopri-codec` | python_codec | medium | no | no | binary_transform | python |
| ENC-1326 | `Recommendation V.3 IA5` | historical_information_system_encoding | medium | no | yes | implemented | wikipedia_historical |
| ENC-1327 | `replacement` | web_pseudo_encoding | high | no | yes | implemented | whatwg |
| ENC-1328 | `Residual Characters from ISO 6937-2 : 1983` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-1329 | `Right-hand Part for Czechoslovak Standard CSN 369103` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-1330 | `Right-hand part of Latin/Greek alphabet` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-1331 | `Right-hand Part of the Latin/Cyrillic Alphabet ECMA-113 (Version of June 1986)` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-1332 | `RISC OS character set` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-1333 | `RISCOS-LATIN1` | gnu_fixed_codec | high | yes | yes | implemented | gnu_libiconv |
| ENC-1334 | `ROMAN` | unicode_mapping_table | high | no | yes | implemented | unicode_mappings |
| ENC-1335 | `rot-13` | python_codec | medium | no | no | text_transform | python |
| ENC-1336 | `RPL character set` | wikidata_characterencoding, wikipedia_character_set_page | medium | no | no | codec_gap | wikidata, wikipedia |
| ENC-1337 | `SAM Coupé character set` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-1338 | `Sami (Lappish) Supplementary Set` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-1339 | `Sami supplementary Latin set` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-1340 | `Sami supplementary Latin set no 2` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-1341 | `Sanyo PHC-25` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-1342 | `SCSU` | iana_registered_charset, icu_converter, wikipedia_character_set_page | high | no | yes | implemented | iana, icu, wikipedia |
| ENC-1343 | `SCSU (Unicode)` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-1344 | `SEASCII` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-1345 | `Second Supplementary Set for Videotex (Mosaic), CCITT` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-1346 | `Sega SC-3000 character set` | wikidata_characterencoding, wikipedia_character_set_page | medium | no | no | codec_gap | wikidata, wikipedia |
| ENC-1347 | `Semigraphics` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-1348 | `SEN_850200_B` | glibc_gconv_codec, iana_registered_charset, rfc1345_charset | high | no | yes | implemented | iana, glibc, rfc1345 |
| ENC-1349 | `SEN_850200_C` | glibc_gconv_codec, iana_registered_charset, rfc1345_charset | high | no | yes | implemented | iana, glibc, rfc1345 |
| ENC-1350 | `Serbocroatian and Slovenian Latin Alphabet` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-1351 | `Serbocroatian Cyrillic Alphabet` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-1352 | `SGML` | sgml_entity_mapping | high | no | no | entity_mapping | unicode_mappings |
| ENC-1353 | `Sharp MZ character set` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-1354 | `Sharp pocket computer character sets` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-1355 | `Shift_JIS` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, microsoft_code_page, openjdk_charset, python_codec, unicode_mapping_table, web_encoding, wikidata_characterencoding, wikidata_variablewidthcharacterencoding | high | yes | yes | implemented | iana, whatwg, gnu_libiconv, glibc, openjdk, microsoft, unicode_mappings, python, wikidata |
| ENC-1356 | `SHIFT_JISX0213` | glibc_gconv_codec, gnu_fixed_codec, openjdk_charset, python_codec, wikidata_variablewidthcharacterencoding | high | yes | yes | implemented | gnu_libiconv, glibc, openjdk, python, wikidata |
| ENC-1357 | `SHORT-KOI` | national_replacement_set, wikidata_characterencoding, wikipedia_character_set_page | medium | no | yes | implemented | kermit, wikidata, wikipedia |
| ENC-1358 | `SignWriting in Unicode` | wikidata_characterencoding | medium | no | no | unicode_representation_profile | wikidata |
| ENC-1359 | `SIM alpha identifier` | telecom_text_field_encoding | high | no | yes | implemented | supplement |
| ENC-1360 | `SimpleEUCEncoder` | openjdk_internal_component | candidate | no | no | internal_component | openjdk |
| ENC-1361 | `Sinclair QL character set` | wikipedia_character_set_page | candidate | no | yes | implemented | wikipedia |
| ENC-1362 | `Sinhala input methods` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-1363 | `Six-bit character code` | early_computer_encoding_family | medium | no | no | encoding_family | supplement |
| ENC-1364 | `SJ/T 11239–2001` | wikidata_codedcharacterset | medium | no | no | codec_gap | wikidata |
| ENC-1365 | `SLOSCII` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-1366 | `SNI-BRACKETS` | terminal_glyph_set | medium | no | yes | implemented | kermit |
| ENC-1367 | `SNI-EURO` | vendor_8bit_set | medium | no | yes | implemented | kermit |
| ENC-1368 | `SNI-FACET` | terminal_glyph_set | medium | no | yes | implemented | kermit |
| ENC-1369 | `SNI-IBM` | terminal_glyph_set | medium | no | yes | implemented | kermit |
| ENC-1370 | `SoftBank emoji` | wikidata_codedcharacterset | medium | no | no | codec_gap | wikidata |
| ENC-1371 | `solaris-zh_TW_big5-2.7` | icu_converter | high | no | yes | implemented | icu |
| ENC-1372 | `SRPSCII` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-1373 | `Stanford Extended ASCII` | source_qualified_seven_bit_graphic_profiles, wikipedia_character_set_page | high | no | yes | implemented | wikipedia, supplement |
| ENC-1374 | `Supplementary set for Latin Alphabets No.1, No.2 and No.5` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-1375 | `Supplementary set for Latin-1 alternative with EURO SIGN` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-1376 | `Supplementary set for Latin-4 alternative with EURO SIGN` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-1377 | `Supplementary set for Latin-7 alternative with EURO SIGN` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-1378 | `Supplementary Set for Use with Registration No.2` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-1379 | `Supplementary Set for Videotex, CCITT` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-1380 | `Supplementary Set ISO/IEC 6937 : 1992` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-1381 | `Supplementary Set of graphic Characters for CCITT Rec. T.101, Data Syntax III` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-1382 | `Supplementary Set of Graphic Characters for Videotex and Teletext ANSI and Teletext ANSI and CSA (Withdrawn in November 1986)` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-1383 | `Supplementary Set of Latin Alphabetic and non-Alphabetic Graphic Characters` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-1384 | `Supplementary Set of Mosaic Characters for CCITT Rec. 101, Data Syntax III` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-1385 | `SWEDISH` | national_replacement_set | medium | no | yes | implemented | kermit |
| ENC-1386 | `Swedish ASCII` | wikidata_characterencoding | medium | no | no | encoding_family | wikidata |
| ENC-1387 | `SWISS` | national_replacement_set | medium | no | yes | implemented | kermit |
| ENC-1388 | `Symbol` | wikidata_characterencoding | medium | no | no | font_identity | wikidata |
| ENC-1389 | `Syntax of the North American Videotex/Teletex Presentation Level Protocol (NAPLPS), CSA T 500-1983` | iso_ir_coding_system | high | no | no | non_text_coding_system | iso_ir |
| ENC-1390 | `T.101-G2` | iana_registered_charset, rfc1345_charset | high | no | yes | implemented | iana, rfc1345 |
| ENC-1391 | `T.50 (standard)` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-1392 | `T.61-7bit` | iana_registered_charset, rfc1345_charset | high | no | yes | implemented | iana, rfc1345 |
| ENC-1393 | `T.61-8bit` | glibc_gconv_codec, iana_registered_charset, rfc1345_charset | high | no | yes | implemented | iana, glibc, rfc1345 |
| ENC-1394 | `Tamil All Character Encoding` | source_qualified_sixteen_bit_sequence_encoding, wikidata_characterencoding, wikipedia_character_set_page | high | no | yes | implemented | wikidata, wikipedia, supplement |
| ENC-1395 | `Tamil Script Code for Information Interchange` | legacy_tamil_encoding, wikidata_characterencoding, wikipedia_character_set_page | high | no | yes | implemented | wikidata, wikipedia, supplement |
| ENC-1396 | `tap code` | human_signaling_pair_value_encoding, wikidata_characterencoding | high | no | yes | implemented | wikidata, supplement |
| ENC-1397 | `TCVN` | glibc_gconv_codec, gnu_fixed_codec | high | yes | yes | implemented | gnu_libiconv, glibc |
| ENC-1398 | `TDS565` | gnu_fixed_codec, iso_ir_coded_character_set | high | yes | yes | implemented | gnu_libiconv, iso_ir |
| ENC-1399 | `Technical Character Set No.1: IEC Publication 1289` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-1400 | `Technical Set` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-1401 | `Telephony BCD` | telecom_digit_encoding | high | no | yes | implemented | supplement |
| ENC-1402 | `Teletex Primary Set of Graphic Characters CCITT Rec. T.61` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-1403 | `Teletex Supplementary Set of Graphic characters CCITT Rec. T.61` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-1404 | `Teletext` | wikidata_characterencoding | medium | no | no | encoding_family | wikidata |
| ENC-1405 | `Teletext character set` | wikipedia_character_set_page | candidate | no | no | encoding_family | wikipedia |
| ENC-1406 | `The Unicode® Standard` | wikidata_characterencoding, wikidata_codedcharacterset | medium | no | no | encoding_family | wikidata |
| ENC-1407 | `Third supplementary set of Mosaic Characters/ Videotex and Facsimile` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-1408 | `Thomson EF9345` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-1409 | `TI calculator character sets` | wikidata_codedcharacterset, wikipedia_character_set_page | medium | no | no | encoding_family | wikidata, wikipedia |
| ENC-1410 | `TI-83 Plus character set` | calculator_character_encoding | high | no | yes | implemented | supplement |
| ENC-1411 | `TI-89 / TI-92 Plus character set` | calculator_character_encoding | high | no | yes | implemented | supplement |
| ENC-1412 | `TIS-620` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, iso_ir_coded_character_set, openjdk_charset, python_codec | high | yes | yes | implemented | iana, gnu_libiconv, glibc, openjdk, iso_ir, python |
| ENC-1413 | `Transcode` | ambiguous_source_profile_family, historical_information_system_encoding | high | no | no | codec_gap | wikipedia_historical, supplement |
| ENC-1414 | `Transcode (IBM 2780 GA27-3005-3)` | source_qualified_six_bit_telecom_encoding | high | no | yes | implemented | supplement |
| ENC-1415 | `Transcode (IBM BSC GA27-3004-2)` | source_qualified_six_bit_telecom_encoding | high | no | yes | implemented | supplement |
| ENC-1416 | `TRON` | wikidata_variablewidthcharacterencoding | medium | no | no | codec_gap | wikidata |
| ENC-1417 | `TRON (encoding)` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-1418 | `TRS-80 character set` | wikidata_characterencoding, wikipedia_character_set_page | medium | no | yes | implemented | wikidata, wikipedia |
| ENC-1419 | `TSCII` | glibc_gconv_codec, iana_registered_charset | high | no | yes | implemented | iana, glibc |
| ENC-1420 | `TURKISH` | unicode_mapping_table | high | no | yes | implemented | unicode_mappings |
| ENC-1421 | `Turkmen character set for 8-bit codes` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-1422 | `U-PRESS` | wikidata_characterencoding | medium | no | no | codec_gap | wikidata |
| ENC-1423 | `UCS Transformation Format One (UTF-1)` | iso_ir_coding_system | high | no | yes | implemented | iso_ir |
| ENC-1424 | `UCS-2-INTERNAL` | gnu_fixed_codec | high | yes | yes | implemented | gnu_libiconv |
| ENC-1425 | `UCS-2-SWAPPED` | gnu_fixed_codec | high | yes | yes | implemented | gnu_libiconv |
| ENC-1426 | `UCS-2LE` | gnu_fixed_codec, icu_converter, openjdk_charset | high | yes | yes | implemented | gnu_libiconv, icu, openjdk |
| ENC-1427 | `UCS-4-INTERNAL` | gnu_fixed_codec | high | yes | yes | implemented | gnu_libiconv |
| ENC-1428 | `UCS-4-SWAPPED` | gnu_fixed_codec | high | yes | yes | implemented | gnu_libiconv |
| ENC-1429 | `UCS-4BE` | gnu_fixed_codec | high | yes | yes | implemented | gnu_libiconv |
| ENC-1430 | `UCS-4LE` | gnu_fixed_codec | high | yes | yes | implemented | gnu_libiconv |
| ENC-1431 | `Unicode emoji variation sequence` | wikidata_characterencoding | medium | no | no | unicode_sequence_profile | wikidata |
| ENC-1432 | `Unicode variation sequence` | wikidata_characterencoding | medium | no | no | unicode_sequence_mechanism | wikidata |
| ENC-1433 | `UNICODE-1-1` | gnu_fixed_codec, iana_registered_charset, icu_converter | high | yes | yes | implemented | iana, gnu_libiconv, icu |
| ENC-1434 | `unicodeFFFE` | microsoft_code_page | high | no | yes | implemented | microsoft |
| ENC-1435 | `Unified Hangul Code` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-1436 | `UNIHAN-17.0.0-KGB3-ROW-CELL-DECIMAL-TOKEN` | unicode_property_token_mapping | high | no | no | implemented_property_token_mapping | supplement |
| ENC-1437 | `UNIHAN-17.0.0-KGB3-ROW-CELL-GL` | unicode_property_row_cell_codec | high | no | yes | implemented | supplement |
| ENC-1438 | `UNIHAN-17.0.0-KMAINLANDTELEGRAPH-DECIMAL-TOKEN` | unicode_property_token_mapping | high | no | no | implemented_property_token_mapping | supplement |
| ENC-1439 | `UNIHAN-17.0.0-KTAIWANTELEGRAPH-DECIMAL-TOKEN-LOSSLESS-VPUA-1` | unicode_property_token_mapping | high | no | no | implemented_property_token_mapping | supplement |
| ENC-1440 | `UNIHAN-17.0.0-KTAIWANTELEGRAPH-DECIMAL-TOKEN-READABLE` | unicode_property_token_mapping | high | no | no | implemented_property_token_mapping | supplement |
| ENC-1441 | `UNIVAC 1100 Series FIELDATA` | early_computer_encoding | high | no | yes | implemented | supplement |
| ENC-1442 | `UNIVAC 1108 punched-card code` | historical_punched_card_encoding | medium | no | no | codec_gap | punched_cards |
| ENC-1443 | `UNIVAC 4009 FIELDATA` | early_computer_encoding | high | no | yes | implemented | supplement |
| ENC-1444 | `UNIVAC-I-EXPANDED-1959` | early_computer_encoding | high | no | yes | implemented | supplement |
| ENC-1445 | `Universal Coded Character Set` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-1446 | `UNKNOWN-8BIT` | iana_registered_charset | high | no | no | placeholder | iana |
| ENC-1447 | `Update Registration 87 Japanese Graphic Character Set for Information Interchange` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-1448 | `Uralic Supplementary Cyrllic Set` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-1449 | `URW Dingbats` | wikidata_dingbattypeface | medium | no | no | font_identity | wikidata |
| ENC-1450 | `US-ASCII` | ascii, ascii_standard, gnu_fixed_codec, historical_information_system_encoding, iana_registered_charset, ibm_ccsid, icu_converter, iso_ir_coded_character_set, microsoft_code_page, openjdk_charset, python_codec, rfc1345_charset, wikidata_characterencoding, wikidata_codedcharacterset, wikipedia_character_set_page | high | yes | yes | implemented | iana, gnu_libiconv, icu, openjdk, microsoft, ibm_i, iso_ir, rfc1345, python, kermit, wikidata, wikipedia_historical, wikipedia, supplement |
| ENC-1451 | `US-ASCII-QUOTES` | unicode_mapping_table | high | no | yes | implemented | unicode_mappings |
| ENC-1452 | `us-dk` | iana_registered_charset, rfc1345_charset | high | no | yes | implemented | iana, rfc1345 |
| ENC-1453 | `UTF-1` | wikidata_unicodetransformationformat, wikipedia_character_set_page | medium | no | yes | implemented | wikidata, wikipedia |
| ENC-1454 | `UTF-16` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, icu_converter, microsoft_code_page, openjdk_charset, python_codec, wikidata_unicodetransformationformat, wikipedia_character_set_page | high | yes | yes | implemented | iana, gnu_libiconv, glibc, icu, openjdk, microsoft, python, wikidata, wikipedia |
| ENC-1455 | `UTF-16 Level 1` | iso_ir_coding_system | high | no | yes | implemented | iso_ir |
| ENC-1456 | `UTF-16 Level 2` | iso_ir_coding_system | high | no | yes | implemented | iso_ir |
| ENC-1457 | `UTF-16 Level 3` | iso_ir_coding_system | high | no | yes | implemented | iso_ir |
| ENC-1458 | `UTF-16,version=1` | icu_converter | high | no | yes | implemented | icu |
| ENC-1459 | `UTF-16,version=2` | icu_converter | high | no | yes | implemented | icu |
| ENC-1460 | `UTF-16BE` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, icu_converter, openjdk_charset, python_codec, web_encoding, wikipedia_character_set_page | high | yes | yes | implemented | iana, whatwg, gnu_libiconv, glibc, icu, openjdk, python, wikipedia |
| ENC-1461 | `UTF-16LE` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, icu_converter, openjdk_charset, python_codec, web_encoding, wikipedia_character_set_page | high | yes | yes | implemented | iana, whatwg, gnu_libiconv, glibc, icu, openjdk, python, wikipedia |
| ENC-1462 | `UTF-32` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, icu_converter, microsoft_code_page, openjdk_charset, python_codec, wikidata_unicodetransformationformat, wikipedia_character_set_page | high | yes | yes | implemented | iana, gnu_libiconv, glibc, icu, openjdk, microsoft, python, wikidata, wikipedia |
| ENC-1463 | `UTF-32BE` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, icu_converter, microsoft_code_page, openjdk_charset, python_codec, wikipedia_character_set_page | high | yes | yes | implemented | iana, gnu_libiconv, glibc, icu, openjdk, microsoft, python, wikipedia |
| ENC-1464 | `UTF-32LE` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, icu_converter, openjdk_charset, python_codec, wikipedia_character_set_page | high | yes | yes | implemented | iana, gnu_libiconv, glibc, icu, openjdk, python, wikipedia |
| ENC-1465 | `UTF-5` | unicode_alphanumeric_transform, wikipedia_character_set_page | high | no | yes | implemented | wikipedia, supplement |
| ENC-1466 | `UTF-6` | unicode_ascii_compatible_hostname_transform, wikipedia_character_set_page | high | no | yes | implemented | wikipedia, supplement |
| ENC-1467 | `UTF-7` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, icu_converter, microsoft_code_page, python_codec, wikidata_unicodetransformationformat, wikipedia_character_set_page | high | yes | yes | implemented | iana, gnu_libiconv, glibc, icu, microsoft, python, wikidata, wikipedia |
| ENC-1468 | `UTF-7-IMAP` | glibc_gconv_codec, iana_registered_charset, python_codec | high | no | yes | implemented | iana, glibc, python |
| ENC-1469 | `UTF-8` | gnu_fixed_codec, iana_registered_charset, ibm_ccsid, icu_converter, microsoft_code_page, openjdk_charset, python_codec, unicode_encoding, web_encoding, wikidata_extendedascii, wikidata_unicodetransformationformat, wikidata_variablewidthcharacterencoding, wikipedia_character_set_page | high | yes | yes | implemented | iana, whatwg, gnu_libiconv, icu, openjdk, microsoft, ibm_i, python, kermit, wikidata, wikipedia |
| ENC-1470 | `UTF-8 Level 1` | iso_ir_coding_system | high | no | yes | implemented | iso_ir |
| ENC-1471 | `UTF-8 Level 2` | iso_ir_coding_system | high | no | yes | implemented | iso_ir |
| ENC-1472 | `UTF-8 Level 3` | iso_ir_coding_system | high | no | yes | implemented | iso_ir |
| ENC-1473 | `UTF-8 without implementation level` | iso_ir_coding_system | high | no | yes | implemented | iso_ir |
| ENC-1474 | `UTF-8-MAC` | filesystem_normalization_variant | medium | no | yes | implemented | supplement |
| ENC-1475 | `utf-8-sig` | python_codec | medium | no | yes | implemented | python |
| ENC-1476 | `UTF-9` | joke_unicode_encoding | medium | no | yes | implemented | supplement |
| ENC-1477 | `UTF-9 and UTF-18` | wikidata_unicodetransformationformat | medium | no | no | encoding_family | wikidata |
| ENC-1478 | `UTF-EBCDIC` | wikidata_unicodeencoding, wikipedia_character_set_page | medium | no | yes | implemented | wikidata, wikipedia |
| ENC-1479 | `UTF16_OppositeEndian` | icu_converter | high | no | yes | implemented | icu |
| ENC-1480 | `UTF16_PlatformEndian` | icu_converter | high | no | yes | implemented | icu |
| ENC-1481 | `UTF32_OppositeEndian` | icu_converter | high | no | yes | implemented | icu |
| ENC-1482 | `UTF32_PlatformEndian` | icu_converter | high | no | yes | implemented | icu |
| ENC-1483 | `uu-codec` | python_codec | medium | no | no | binary_transform | python |
| ENC-1484 | `variable-length code` | wikidata_characterencoding | medium | no | no | coding_technique | wikidata |
| ENC-1485 | `Variant of the ISO 7-bit coded character set for the Irish Gaelic language` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-1486 | `Ventura-International` | iana_registered_charset, wikipedia_character_set_page | high | no | yes | implemented | iana, wikipedia |
| ENC-1487 | `Ventura-Math` | iana_registered_charset | high | no | yes | implemented | iana |
| ENC-1488 | `Ventura-US` | iana_registered_charset | high | no | yes | implemented | iana |
| ENC-1489 | `Videotex character set` | wikidata_characterencoding, wikipedia_character_set_page | medium | no | no | encoding_family | wikidata, wikipedia |
| ENC-1490 | `Videotex Enhanced Man Machine Interface (VEMMI) Data Syntax of ITU-T Rec. T.107` | iso_ir_coding_system | high | no | no | non_text_coding_system | iso_ir |
| ENC-1491 | `videotex-suppl` | iana_registered_charset, rfc1345_charset | high | no | yes | implemented | iana, rfc1345 |
| ENC-1492 | `Vietnamese Standard Code for Information Interchange` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-1493 | `VIQR` | iana_registered_charset | high | no | yes | implemented | iana |
| ENC-1494 | `Virtual Terminal service Transparent Set` | iso_ir_coding_system | high | no | no | non_text_coding_system | iso_ir |
| ENC-1495 | `VISCII` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, wikidata_characterencoding, wikidata_codedcharacterset, wikidata_extendedascii, wikipedia_character_set_page | high | yes | yes | implemented | iana, gnu_libiconv, glibc, wikidata, wikipedia |
| ENC-1496 | `VNI Character Set` | source_qualified_variable_length_vietnamese_profiles, wikidata_characterencoding | high | no | yes | implemented | wikidata, supplement |
| ENC-1497 | `Volgaic Supplementary Cyrllic Set` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-1498 | `VSCII` | single_byte_character_encoding, wikidata_characterencoding, wikidata_codedcharacterset, wikipedia_character_set_page | high | no | yes | implemented | wikidata, wikipedia, supplement |
| ENC-1499 | `Wang International Standard Code for Information Interchange` | source_qualified_single_byte_character_encoding, wikidata_characterencoding | high | no | yes | implemented | wikidata, supplement |
| ENC-1500 | `WCHAR_T` | locale_abi_adapter | high | yes | no | platform_adapter | gnu_libiconv |
| ENC-1501 | `Webdings` | wikidata_dingbattypeface | medium | no | no | font_identity | wikidata |
| ENC-1502 | `Welsh variant of Latin Alphabet No. 1 5/12` | iso_ir_coded_character_set | high | no | yes | implemented | iso_ir |
| ENC-1503 | `Western Latin character sets` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-1504 | `Wheatstone punched-tape code` | telegraph_tape_code | medium | no | no | codec_gap | supplement |
| ENC-1505 | `WIN-SAMI-2` | glibc_gconv_codec | high | no | yes | implemented | glibc |
| ENC-1506 | `Windows code page` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-1507 | `Windows code page 21027` | microsoft_code_page | high | no | yes | implemented | microsoft |
| ENC-1508 | `Windows code page 50229` | microsoft_code_page | high | no | no | codec_gap | microsoft |
| ENC-1509 | `Windows code page 50930` | microsoft_code_page | high | no | yes | implemented | microsoft |
| ENC-1510 | `Windows code page 50931` | microsoft_code_page | high | no | yes | implemented | microsoft |
| ENC-1511 | `Windows code page 50933` | microsoft_code_page | high | no | yes | implemented | microsoft |
| ENC-1512 | `Windows code page 50935` | microsoft_code_page | high | no | yes | implemented | microsoft |
| ENC-1513 | `Windows code page 50936` | microsoft_code_page | high | no | no | codec_gap | microsoft |
| ENC-1514 | `Windows code page 50937` | microsoft_code_page | high | no | yes | implemented | microsoft |
| ENC-1515 | `Windows code page 50939` | microsoft_code_page | high | no | yes | implemented | microsoft |
| ENC-1516 | `Windows code page 51950` | microsoft_code_page | high | no | yes | implemented | microsoft |
| ENC-1517 | `Windows code page 709` | microsoft_code_page | high | no | no | codec_gap | microsoft |
| ENC-1518 | `Windows code page 710` | microsoft_code_page | high | no | no | codec_gap | microsoft |
| ENC-1519 | `Windows Cyrillic + French` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-1520 | `Windows Cyrillic + German` | wikipedia_character_set_page | candidate | no | no | research_candidate | wikipedia |
| ENC-1521 | `Windows Polytonic Greek` | source_qualified_single_byte_character_encoding, wikidata_characterencoding, wikipedia_character_set_page | high | no | yes | implemented | wikidata, wikipedia, supplement |
| ENC-1522 | `windows-1250` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, ibm_ccsid, icu_converter, microsoft_code_page, openjdk_charset, python_codec, web_encoding, wikidata_windowscodepage, wikipedia_character_set_page | high | yes | yes | implemented | iana, whatwg, gnu_libiconv, glibc, icu, openjdk, microsoft, ibm_i, python, wikidata, wikipedia |
| ENC-1523 | `windows-1251` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, ibm_ccsid, icu_converter, microsoft_code_page, openjdk_charset, python_codec, web_encoding, wikidata_windowscodepage, wikipedia_character_set_page | high | yes | yes | implemented | iana, whatwg, gnu_libiconv, glibc, icu, openjdk, microsoft, ibm_i, python, wikidata, wikipedia |
| ENC-1524 | `windows-1252` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, ibm_ccsid, icu_converter, microsoft_code_page, openjdk_charset, python_codec, web_encoding, wikidata_windowscodepage, wikipedia_character_set_page | high | yes | yes | implemented | iana, whatwg, gnu_libiconv, glibc, icu, openjdk, microsoft, ibm_i, python, wikidata, wikipedia |
| ENC-1525 | `windows-1253` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, ibm_ccsid, icu_converter, microsoft_code_page, openjdk_charset, python_codec, web_encoding, wikidata_windowscodepage, wikipedia_character_set_page | high | yes | yes | implemented | iana, whatwg, gnu_libiconv, glibc, icu, openjdk, microsoft, ibm_i, python, wikidata, wikipedia |
| ENC-1526 | `windows-1254` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, ibm_ccsid, icu_converter, microsoft_code_page, openjdk_charset, python_codec, web_encoding, wikidata_windowscodepage, wikipedia_character_set_page | high | yes | yes | implemented | iana, whatwg, gnu_libiconv, glibc, icu, openjdk, microsoft, ibm_i, python, wikidata, wikipedia |
| ENC-1527 | `windows-1255` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, ibm_ccsid, icu_converter, microsoft_code_page, openjdk_charset, python_codec, web_encoding, wikidata_windowscodepage, wikipedia_character_set_page | high | yes | yes | implemented | iana, whatwg, gnu_libiconv, glibc, icu, openjdk, microsoft, ibm_i, python, wikidata, wikipedia |
| ENC-1528 | `windows-1256` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, ibm_ccsid, icu_converter, microsoft_code_page, openjdk_charset, python_codec, web_encoding, wikidata_windowscodepage, wikipedia_character_set_page | high | yes | yes | implemented | iana, whatwg, gnu_libiconv, glibc, icu, openjdk, microsoft, ibm_i, python, wikidata, wikipedia |
| ENC-1529 | `windows-1257` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, ibm_ccsid, icu_converter, microsoft_code_page, openjdk_charset, python_codec, web_encoding, wikidata_windowscodepage, wikipedia_character_set_page | high | yes | yes | implemented | iana, whatwg, gnu_libiconv, glibc, icu, openjdk, microsoft, ibm_i, python, wikidata, wikipedia |
| ENC-1530 | `windows-1258` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, icu_converter, microsoft_code_page, openjdk_charset, python_codec, web_encoding, wikidata_windowscodepage, wikipedia_character_set_page | high | yes | yes | implemented | iana, whatwg, gnu_libiconv, glibc, icu, openjdk, microsoft, python, wikidata, wikipedia |
| ENC-1531 | `Windows-1270` | source_qualified_single_byte_character_encoding, wikipedia_character_set_page | high | no | yes | implemented | wikipedia, supplement |
| ENC-1532 | `Windows-31J` | iana_registered_charset, openjdk_charset | high | no | yes | implemented | iana, openjdk |
| ENC-1533 | `windows-51932-2006` | icu_converter | high | no | yes | implemented | icu |
| ENC-1534 | `windows-864-2000` | icu_converter | high | no | yes | implemented | icu |
| ENC-1535 | `windows-874` | glibc_gconv_codec, gnu_fixed_codec, iana_registered_charset, ibm_ccsid, microsoft_code_page, openjdk_charset, python_codec, web_encoding, wikipedia_character_set_page | high | yes | yes | implemented | iana, whatwg, gnu_libiconv, glibc, openjdk, microsoft, ibm_i, python, wikipedia |
| ENC-1536 | `windows-874-2000` | icu_converter | high | no | yes | implemented | icu |
| ENC-1537 | `windows-936-2000` | icu_converter | high | no | yes | implemented | icu |
| ENC-1538 | `Wingdings` | wikidata_dingbattypeface | medium | no | no | font_identity | wikidata |
| ENC-1539 | `Wingdings 2` | wikidata_dingbattypeface | medium | no | no | font_identity | wikidata |
| ENC-1540 | `Wingdings 3` | wikidata_dingbattypeface | medium | no | no | font_identity | wikidata |
| ENC-1541 | `WTF-8` | unicode_compatibility_encoding, wikipedia_character_set_page | medium | no | yes | implemented | wikipedia, supplement |
| ENC-1542 | `x-Chinese_CNS` | microsoft_code_page | high | no | yes | implemented | microsoft |
| ENC-1543 | `x-cp20001` | microsoft_code_page | high | no | yes | implemented | microsoft |
| ENC-1544 | `x-cp20003` | microsoft_code_page | high | no | yes | implemented | microsoft |
| ENC-1545 | `x-cp20004` | microsoft_code_page | high | no | yes | implemented | microsoft |
| ENC-1546 | `x-cp20005` | microsoft_code_page | high | no | yes | implemented | microsoft |
| ENC-1547 | `x-cp20261` | microsoft_code_page | high | no | yes | implemented | microsoft |
| ENC-1548 | `x-cp20269` | microsoft_code_page | high | no | yes | implemented | microsoft |
| ENC-1549 | `x-cp20936` | microsoft_code_page | high | no | yes | implemented | microsoft |
| ENC-1550 | `x-cp20949` | microsoft_code_page | high | no | yes | implemented | microsoft |
| ENC-1551 | `x-cp50227` | microsoft_code_page | high | no | yes | implemented | microsoft |
| ENC-1552 | `x-EBCDIC-KoreanExtended` | microsoft_code_page | high | no | yes | implemented | microsoft |
| ENC-1553 | `x-euc-jp-linux` | openjdk_charset | high | no | yes | implemented | openjdk |
| ENC-1554 | `x-eucJP-Open` | openjdk_charset | high | no | no | codec_gap | openjdk |
| ENC-1555 | `x-Europa` | microsoft_code_page | high | no | yes | implemented | microsoft |
| ENC-1556 | `x-IA5` | microsoft_code_page | high | no | yes | implemented | microsoft |
| ENC-1557 | `x-IA5-German` | microsoft_code_page | high | no | yes | implemented | microsoft |
| ENC-1558 | `x-IA5-Norwegian` | microsoft_code_page | high | no | yes | implemented | microsoft |
| ENC-1559 | `x-IA5-Swedish` | microsoft_code_page | high | no | yes | implemented | microsoft |
| ENC-1560 | `x-IBM1006` | openjdk_charset | high | no | yes | implemented | openjdk |
| ENC-1561 | `x-IBM1098` | openjdk_charset | high | no | yes | implemented | openjdk |
| ENC-1562 | `x-IBM1364` | openjdk_charset | high | no | yes | implemented | openjdk |
| ENC-1563 | `x-IBM300` | openjdk_charset | high | no | yes | implemented | openjdk |
| ENC-1564 | `x-IBM737` | openjdk_charset | high | no | yes | implemented | openjdk |
| ENC-1565 | `x-IBM833` | openjdk_charset | high | no | yes | implemented | openjdk |
| ENC-1566 | `x-IBM930` | openjdk_charset | high | no | yes | implemented | openjdk |
| ENC-1567 | `x-IBM933` | openjdk_charset | high | no | yes | implemented | openjdk |
| ENC-1568 | `x-IBM935` | openjdk_charset | high | no | yes | implemented | openjdk |
| ENC-1569 | `x-IBM937` | openjdk_charset | high | no | yes | implemented | openjdk |
| ENC-1570 | `x-IBM939` | openjdk_charset | high | no | yes | implemented | openjdk |
| ENC-1571 | `x-IBM943C` | openjdk_charset | high | no | yes | implemented | openjdk |
| ENC-1572 | `x-IBM948` | openjdk_charset | high | no | yes | implemented | openjdk |
| ENC-1573 | `x-IBM949C` | openjdk_charset | high | no | yes | implemented | openjdk |
| ENC-1574 | `x-iscii-as` | microsoft_code_page | high | no | yes | implemented | microsoft |
| ENC-1575 | `x-iscii-be` | microsoft_code_page | high | no | yes | implemented | microsoft |
| ENC-1576 | `x-iscii-de` | microsoft_code_page | high | no | yes | implemented | microsoft |
| ENC-1577 | `x-iscii-gu` | microsoft_code_page | high | no | yes | implemented | microsoft |
| ENC-1578 | `x-iscii-ka` | microsoft_code_page | high | no | yes | implemented | microsoft |
| ENC-1579 | `x-iscii-ma` | microsoft_code_page | high | no | yes | implemented | microsoft |
| ENC-1580 | `x-iscii-or` | microsoft_code_page | high | no | yes | implemented | microsoft |
| ENC-1581 | `x-iscii-pa` | microsoft_code_page | high | no | yes | implemented | microsoft |
| ENC-1582 | `x-iscii-ta` | microsoft_code_page | high | no | yes | implemented | microsoft |
| ENC-1583 | `x-iscii-te` | microsoft_code_page | high | no | yes | implemented | microsoft |
| ENC-1584 | `x-ISCII91` | openjdk_charset | high | no | yes | implemented | openjdk |
| ENC-1585 | `x-ISO-2022-CN-CNS` | openjdk_charset | high | no | no | codec_gap | openjdk |
| ENC-1586 | `x-ISO-2022-CN-GB` | openjdk_charset | high | no | no | codec_gap | openjdk |
| ENC-1587 | `x-JIS0208_MS5022X` | openjdk_internal_component | candidate | no | no | internal_component | openjdk |
| ENC-1588 | `x-JIS0208_MS932` | openjdk_internal_component | candidate | no | no | internal_component | openjdk |
| ENC-1589 | `x-JIS0208_Solaris` | openjdk_internal_component | candidate | no | no | internal_component | openjdk |
| ENC-1590 | `x-JIS0212_MS5022X` | openjdk_internal_component | candidate | no | no | internal_component | openjdk |
| ENC-1591 | `x-JIS0212_Solaris` | openjdk_internal_component | candidate | no | no | internal_component | openjdk |
| ENC-1592 | `x-JISAutoDetect` | openjdk_charset | high | no | yes | implemented | openjdk |
| ENC-1593 | `x-mac-ce` | microsoft_code_page | high | no | yes | implemented | microsoft |
| ENC-1594 | `x-mac-chinesesimp` | microsoft_code_page | high | no | yes | implemented | microsoft |
| ENC-1595 | `x-mac-chinesetrad` | microsoft_code_page | high | no | yes | implemented | microsoft |
| ENC-1596 | `x-mac-cyrillic` | glibc_gconv_codec, gnu_fixed_codec, icu_converter, microsoft_code_page, openjdk_charset, python_codec, unicode_mapping_table, web_encoding, wikidata_codedcharacterset, wikidata_extendedascii, wikipedia_character_set_page | high | yes | yes | implemented | whatwg, gnu_libiconv, glibc, icu, openjdk, microsoft, unicode_mappings, python, wikidata, wikipedia |
| ENC-1597 | `x-mac-icelandic` | microsoft_code_page | high | no | yes | implemented | microsoft |
| ENC-1598 | `x-mac-japanese` | microsoft_code_page | high | no | yes | implemented | microsoft |
| ENC-1599 | `x-mac-korean` | microsoft_code_page | high | no | yes | implemented | microsoft |
| ENC-1600 | `x-mac-romanian` | microsoft_code_page | high | no | yes | implemented | microsoft |
| ENC-1601 | `x-mac-ukrainian` | microsoft_code_page | high | no | yes | implemented | microsoft |
| ENC-1602 | `x-MacDingbat` | openjdk_charset | high | no | yes | implemented | openjdk |
| ENC-1603 | `x-MacSymbol` | openjdk_charset | high | no | yes | implemented | openjdk |
| ENC-1604 | `x-MS932_0213` | openjdk_charset | high | no | yes | implemented | openjdk |
| ENC-1605 | `x-MS950-HKSCS` | openjdk_charset | high | no | yes | implemented | openjdk |
| ENC-1606 | `x-MS950-HKSCS-XP` | openjdk_charset | high | no | no | codec_gap | openjdk |
| ENC-1607 | `x-user-defined` | web_encoding | high | no | yes | implemented | whatwg |
| ENC-1608 | `X-UTF-32BE-BOM` | openjdk_charset | high | no | yes | implemented | openjdk |
| ENC-1609 | `X-UTF-32LE-BOM` | openjdk_charset | high | no | yes | implemented | openjdk |
| ENC-1610 | `x-windows-50220` | openjdk_charset | high | no | no | codec_gap | openjdk |
| ENC-1611 | `x-windows-50221` | openjdk_charset | high | no | no | codec_gap | openjdk |
| ENC-1612 | `x-windows-949` | openjdk_charset | high | no | yes | implemented | openjdk |
| ENC-1613 | `x-windows-950` | openjdk_charset | high | no | yes | implemented | openjdk |
| ENC-1614 | `x-windows-iso2022jp` | openjdk_charset | high | no | no | codec_gap | openjdk |
| ENC-1615 | `x11-compound-text` | icu_converter | high | no | yes | implemented | icu |
| ENC-1616 | `x_Chinese-Eten` | microsoft_code_page | high | no | yes | implemented | microsoft |
| ENC-1617 | `Xerox Character Code Standard` | wikidata_variablewidthcharacterencoding, wikipedia_character_set_page | medium | no | no | codec_gap | wikidata, wikipedia |
| ENC-1618 | `XJP` | wikidata_codepage | medium | no | yes | implemented | wikidata |
| ENC-1619 | `YUSCII` | wikidata_characterencoding, wikipedia_character_set_page | medium | no | no | encoding_family | wikidata, wikipedia |
| ENC-1620 | `Zapf Dingbats` | wikidata_dingbattypeface | medium | no | yes | implemented | wikidata |
| ENC-1621 | `Zapf Dingbats Encoding` | unicode_mapping_table | high | no | yes | implemented | unicode_mappings |
| ENC-1622 | `zlib-codec` | python_codec | medium | no | no | compression_transform | python |
| ENC-1623 | `ZX Spectrum +3 character set` | legacy_computer_encoding, wikidata_characterencoding, wikipedia_character_set_page | high | no | yes | implemented | wikidata, wikipedia, supplement |
| ENC-1624 | `ZX Spectrum character set` | wikidata_characterencoding, wikipedia_character_set_page | medium | no | yes | implemented | wikidata, wikipedia |
| ENC-1625 | `ZX80 character set` | wikidata_characterencoding, wikipedia_character_set_page | medium | no | yes | implemented | wikidata, wikipedia |
| ENC-1626 | `ZX81 character set` | wikidata_characterencoding, wikipedia_character_set_page | medium | no | yes | implemented | wikidata, wikipedia |
