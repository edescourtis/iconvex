# Supported encodings: Iconvex vs GNU libiconv 1.19

Machine-generated from GNU libiconv 1.19's six fixed-codec definition files.
`test/codec_parity_test.exs` independently parses byte-exact upstream snapshots
and requires exact set and alias parity.

## Parity result

- Iconvex core fixed codecs: **112/112**.
- `iconvex_extras` fixed codecs: **86/86**.
- Full Iconvex stack: **112 core + 86 extras = 198/198**.
- GNU fixed-codec union: **198/198**.
- Common fixed codecs: **198**.
- GNU-only fixed codecs: **0**.
- Iconvex-only fixed codecs: **0**.
- GNU source spellings/aliases resolved by Iconvex: **758**.
  Core owns **416**; extras adds **342**.
- Additional audited specification/ICU aliases: **25**.
- Total resolved fixed-codec spellings: **783**.
- Default GNU build `iconv -l`: **112/112**, all supported by Iconvex.

## Packed transport surface

Packing is orthogonal to the GNU codec registry. `Iconvex.Packed` can pack the
one-unit-per-octet output of any built-in or external codec at every width from
1 through 8 bits, in exact MSB-first or byte-backed LSB-first order. It is not
counted as a second character encoding because the Unicode mapping is unchanged;
the transport preserves its exact unit width and meaningful bit length.

`iconvex_telecom` publishes an exact 51-codec packed-profile inventory for its
5-, 6-, and 7-bit families. `iconvex_specs` separately implements the wider
RFC 4042 UTF-9 and UTF-18 formats.

`SUPPORTED_NAME_INVENTORY.csv` is generated from the compiled core registry.
The parity suite requires its 441 normalized names and canonical targets to be
an exact runtime snapshot; research consumes this file directly.

GNU union means all fixed codecs implemented across `encodings.def`,
`encodings_extra.def`, `encodings_aix.def`, `encodings_dos.def`,
`encodings_osf1.def`, and `encodings_zos.def`. Default `iconv -l` exposes the
112 core codecs on this build; extra/platform definitions raise the source
union to 198. The `iconvex` package intentionally contains exactly the GNU
default set. Adding the separate `iconvex_extras` package exposes the complete
union on every BEAM platform. A dash means that codec is intentionally owned
by the other package.

## Locale/ABI adapters

GNU also accepts `CHAR` and `WCHAR_T` through `encodings_local.def`. These are
environment/ABI adapters, not fixed codecs, and GNU omits them from `iconv -l`.
`CHAR` delegates to process locale encoding. `WCHAR_T` delegates to platform C
`wchar_t` width/endian/layout. Iconvex intentionally excludes both: pure BEAM
conversion has no libc locale or C `wchar_t` ABI. Use explicit fixed names such
as `UTF-8`, `UCS-4-INTERNAL`, `UTF-16LE`, or `UTF-32LE`.

## Complete fixed-codec list

| Codec | Core `iconvex` | `iconvex_extras` | GNU 1.19 union | GNU definition | Default `iconv -l` |
|---|:---:|:---:|:---:|---|:---:|
| `ARMSCII-8` | Yes | — | Yes | Core/default | Yes |
| `ATARIST` | — | Yes | Yes | Extra | No |
| `BIG5` | Yes | — | Yes | Core/default | Yes |
| `BIG5-2003` | — | Yes | Yes | Extra | No |
| `BIG5-HKSCS` | Yes | — | Yes | Core/default | Yes |
| `BIG5-HKSCS:1999` | Yes | — | Yes | Core/default | Yes |
| `BIG5-HKSCS:2001` | Yes | — | Yes | Core/default | Yes |
| `BIG5-HKSCS:2004` | Yes | — | Yes | Core/default | Yes |
| `C99` | Yes | — | Yes | Core/default | Yes |
| `CP1046` | — | Yes | Yes | AIX | No |
| `CP1124` | — | Yes | Yes | AIX | No |
| `CP1125` | — | Yes | Yes | DOS | No |
| `CP1129` | — | Yes | Yes | AIX | No |
| `CP1131` | Yes | — | Yes | Core/default | Yes |
| `CP1133` | Yes | — | Yes | Core/default | Yes |
| `CP1161` | — | Yes | Yes | AIX | No |
| `CP1162` | — | Yes | Yes | AIX | No |
| `CP1163` | — | Yes | Yes | AIX | No |
| `CP1250` | Yes | — | Yes | Core/default | Yes |
| `CP1251` | Yes | — | Yes | Core/default | Yes |
| `CP1252` | Yes | — | Yes | Core/default | Yes |
| `CP1253` | Yes | — | Yes | Core/default | Yes |
| `CP1254` | Yes | — | Yes | Core/default | Yes |
| `CP1255` | Yes | — | Yes | Core/default | Yes |
| `CP1256` | Yes | — | Yes | Core/default | Yes |
| `CP1257` | Yes | — | Yes | Core/default | Yes |
| `CP1258` | Yes | — | Yes | Core/default | Yes |
| `CP437` | — | Yes | Yes | DOS | No |
| `CP737` | — | Yes | Yes | DOS | No |
| `CP775` | — | Yes | Yes | DOS | No |
| `CP850` | Yes | — | Yes | Core/default | Yes |
| `CP852` | — | Yes | Yes | DOS | No |
| `CP853` | — | Yes | Yes | DOS | No |
| `CP855` | — | Yes | Yes | DOS | No |
| `CP856` | — | Yes | Yes | AIX | No |
| `CP857` | — | Yes | Yes | DOS | No |
| `CP858` | — | Yes | Yes | DOS | No |
| `CP860` | — | Yes | Yes | DOS | No |
| `CP861` | — | Yes | Yes | DOS | No |
| `CP862` | Yes | — | Yes | Core/default | Yes |
| `CP863` | — | Yes | Yes | DOS | No |
| `CP864` | — | Yes | Yes | DOS | No |
| `CP865` | — | Yes | Yes | DOS | No |
| `CP866` | Yes | — | Yes | Core/default | Yes |
| `CP869` | — | Yes | Yes | DOS | No |
| `CP874` | Yes | — | Yes | Core/default | Yes |
| `CP922` | — | Yes | Yes | AIX | No |
| `CP932` | Yes | — | Yes | Core/default | Yes |
| `CP936` | Yes | — | Yes | Core/default | Yes |
| `CP943` | — | Yes | Yes | AIX | No |
| `CP949` | Yes | — | Yes | Core/default | Yes |
| `CP950` | Yes | — | Yes | Core/default | Yes |
| `DEC-HANYU` | — | Yes | Yes | OSF/1 | No |
| `DEC-KANJI` | — | Yes | Yes | OSF/1 | No |
| `EUC-CN` | Yes | — | Yes | Core/default | Yes |
| `EUC-JISX0213` | — | Yes | Yes | Extra | No |
| `EUC-JP` | Yes | — | Yes | Core/default | Yes |
| `EUC-KR` | Yes | — | Yes | Core/default | Yes |
| `EUC-TW` | Yes | — | Yes | Core/default | Yes |
| `GB18030` | Yes | — | Yes | Core/default | Yes |
| `GB18030:2022` | Yes | — | Yes | Core/default | Yes |
| `GBK` | Yes | — | Yes | Core/default | Yes |
| `GB_1988-80` | Yes | — | Yes | Core/default | Yes |
| `GB_2312-80` | Yes | — | Yes | Core/default | Yes |
| `GEORGIAN-ACADEMY` | Yes | — | Yes | Core/default | Yes |
| `GEORGIAN-PS` | Yes | — | Yes | Core/default | Yes |
| `HP-ROMAN8` | Yes | — | Yes | Core/default | Yes |
| `HZ` | Yes | — | Yes | Core/default | Yes |
| `IBM-037` | — | Yes | Yes | z/OS | No |
| `IBM-1025` | — | Yes | Yes | z/OS | No |
| `IBM-1026` | — | Yes | Yes | z/OS | No |
| `IBM-1047` | — | Yes | Yes | z/OS | No |
| `IBM-1097` | — | Yes | Yes | z/OS | No |
| `IBM-1112` | — | Yes | Yes | z/OS | No |
| `IBM-1122` | — | Yes | Yes | z/OS | No |
| `IBM-1123` | — | Yes | Yes | z/OS | No |
| `IBM-1130` | — | Yes | Yes | z/OS | No |
| `IBM-1132` | — | Yes | Yes | z/OS | No |
| `IBM-1137` | — | Yes | Yes | z/OS | No |
| `IBM-1140` | — | Yes | Yes | z/OS | No |
| `IBM-1141` | — | Yes | Yes | z/OS | No |
| `IBM-1142` | — | Yes | Yes | z/OS | No |
| `IBM-1143` | — | Yes | Yes | z/OS | No |
| `IBM-1144` | — | Yes | Yes | z/OS | No |
| `IBM-1145` | — | Yes | Yes | z/OS | No |
| `IBM-1146` | — | Yes | Yes | z/OS | No |
| `IBM-1147` | — | Yes | Yes | z/OS | No |
| `IBM-1148` | — | Yes | Yes | z/OS | No |
| `IBM-1149` | — | Yes | Yes | z/OS | No |
| `IBM-1153` | — | Yes | Yes | z/OS | No |
| `IBM-1154` | — | Yes | Yes | z/OS | No |
| `IBM-1155` | — | Yes | Yes | z/OS | No |
| `IBM-1156` | — | Yes | Yes | z/OS | No |
| `IBM-1157` | — | Yes | Yes | z/OS | No |
| `IBM-1158` | — | Yes | Yes | z/OS | No |
| `IBM-1160` | — | Yes | Yes | z/OS | No |
| `IBM-1164` | — | Yes | Yes | z/OS | No |
| `IBM-1165` | — | Yes | Yes | z/OS | No |
| `IBM-1166` | — | Yes | Yes | z/OS | No |
| `IBM-12712` | — | Yes | Yes | z/OS | No |
| `IBM-16804` | — | Yes | Yes | z/OS | No |
| `IBM-273` | — | Yes | Yes | z/OS | No |
| `IBM-277` | — | Yes | Yes | z/OS | No |
| `IBM-278` | — | Yes | Yes | z/OS | No |
| `IBM-280` | — | Yes | Yes | z/OS | No |
| `IBM-282` | — | Yes | Yes | z/OS | No |
| `IBM-284` | — | Yes | Yes | z/OS | No |
| `IBM-285` | — | Yes | Yes | z/OS | No |
| `IBM-297` | — | Yes | Yes | z/OS | No |
| `IBM-423` | — | Yes | Yes | z/OS | No |
| `IBM-424` | — | Yes | Yes | z/OS | No |
| `IBM-425` | — | Yes | Yes | z/OS | No |
| `IBM-4971` | — | Yes | Yes | z/OS | No |
| `IBM-500` | — | Yes | Yes | z/OS | No |
| `IBM-838` | — | Yes | Yes | z/OS | No |
| `IBM-870` | — | Yes | Yes | z/OS | No |
| `IBM-871` | — | Yes | Yes | z/OS | No |
| `IBM-875` | — | Yes | Yes | z/OS | No |
| `IBM-880` | — | Yes | Yes | z/OS | No |
| `IBM-905` | — | Yes | Yes | z/OS | No |
| `IBM-924` | — | Yes | Yes | z/OS | No |
| `ISO-2022-CN` | Yes | — | Yes | Core/default | Yes |
| `ISO-2022-CN-EXT` | Yes | — | Yes | Core/default | Yes |
| `ISO-2022-JP` | Yes | — | Yes | Core/default | Yes |
| `ISO-2022-JP-1` | Yes | — | Yes | Core/default | Yes |
| `ISO-2022-JP-2` | Yes | — | Yes | Core/default | Yes |
| `ISO-2022-JP-3` | — | Yes | Yes | Extra | No |
| `ISO-2022-JP-MS` | Yes | — | Yes | Core/default | Yes |
| `ISO-2022-KR` | Yes | — | Yes | Core/default | Yes |
| `ISO-8859-1` | Yes | — | Yes | Core/default | Yes |
| `ISO-8859-10` | Yes | — | Yes | Core/default | Yes |
| `ISO-8859-11` | Yes | — | Yes | Core/default | Yes |
| `ISO-8859-13` | Yes | — | Yes | Core/default | Yes |
| `ISO-8859-14` | Yes | — | Yes | Core/default | Yes |
| `ISO-8859-15` | Yes | — | Yes | Core/default | Yes |
| `ISO-8859-16` | Yes | — | Yes | Core/default | Yes |
| `ISO-8859-2` | Yes | — | Yes | Core/default | Yes |
| `ISO-8859-3` | Yes | — | Yes | Core/default | Yes |
| `ISO-8859-4` | Yes | — | Yes | Core/default | Yes |
| `ISO-8859-5` | Yes | — | Yes | Core/default | Yes |
| `ISO-8859-6` | Yes | — | Yes | Core/default | Yes |
| `ISO-8859-7` | Yes | — | Yes | Core/default | Yes |
| `ISO-8859-8` | Yes | — | Yes | Core/default | Yes |
| `ISO-8859-9` | Yes | — | Yes | Core/default | Yes |
| `ISO-IR-165` | Yes | — | Yes | Core/default | Yes |
| `JAVA` | Yes | — | Yes | Core/default | Yes |
| `JIS_C6220-1969-RO` | Yes | — | Yes | Core/default | Yes |
| `JIS_X0201` | Yes | — | Yes | Core/default | Yes |
| `JIS_X0208` | Yes | — | Yes | Core/default | Yes |
| `JIS_X0212` | Yes | — | Yes | Core/default | Yes |
| `JOHAB` | Yes | — | Yes | Core/default | Yes |
| `KOI8-R` | Yes | — | Yes | Core/default | Yes |
| `KOI8-RU` | Yes | — | Yes | Core/default | Yes |
| `KOI8-T` | Yes | — | Yes | Core/default | Yes |
| `KOI8-U` | Yes | — | Yes | Core/default | Yes |
| `KSC_5601` | Yes | — | Yes | Core/default | Yes |
| `MULELAO-1` | Yes | — | Yes | Core/default | Yes |
| `MacArabic` | Yes | — | Yes | Core/default | Yes |
| `MacCentralEurope` | Yes | — | Yes | Core/default | Yes |
| `MacCroatian` | Yes | — | Yes | Core/default | Yes |
| `MacCyrillic` | Yes | — | Yes | Core/default | Yes |
| `MacGreek` | Yes | — | Yes | Core/default | Yes |
| `MacHebrew` | Yes | — | Yes | Core/default | Yes |
| `MacIceland` | Yes | — | Yes | Core/default | Yes |
| `MacRoman` | Yes | — | Yes | Core/default | Yes |
| `MacRomania` | Yes | — | Yes | Core/default | Yes |
| `MacThai` | Yes | — | Yes | Core/default | Yes |
| `MacTurkish` | Yes | — | Yes | Core/default | Yes |
| `MacUkraine` | Yes | — | Yes | Core/default | Yes |
| `NEXTSTEP` | Yes | — | Yes | Core/default | Yes |
| `PT154` | Yes | — | Yes | Core/default | Yes |
| `RISCOS-LATIN1` | — | Yes | Yes | Extra | No |
| `RK1048` | Yes | — | Yes | Core/default | Yes |
| `SHIFT_JIS` | Yes | — | Yes | Core/default | Yes |
| `SHIFT_JISX0213` | — | Yes | Yes | Extra | No |
| `TCVN` | Yes | — | Yes | Core/default | Yes |
| `TDS565` | — | Yes | Yes | Extra | No |
| `TIS-620` | Yes | — | Yes | Core/default | Yes |
| `UCS-2` | Yes | — | Yes | Core/default | Yes |
| `UCS-2-INTERNAL` | Yes | — | Yes | Core/default | Yes |
| `UCS-2-SWAPPED` | Yes | — | Yes | Core/default | Yes |
| `UCS-2BE` | Yes | — | Yes | Core/default | Yes |
| `UCS-2LE` | Yes | — | Yes | Core/default | Yes |
| `UCS-4` | Yes | — | Yes | Core/default | Yes |
| `UCS-4-INTERNAL` | Yes | — | Yes | Core/default | Yes |
| `UCS-4-SWAPPED` | Yes | — | Yes | Core/default | Yes |
| `UCS-4BE` | Yes | — | Yes | Core/default | Yes |
| `UCS-4LE` | Yes | — | Yes | Core/default | Yes |
| `US-ASCII` | Yes | — | Yes | Core/default | Yes |
| `UTF-16` | Yes | — | Yes | Core/default | Yes |
| `UTF-16BE` | Yes | — | Yes | Core/default | Yes |
| `UTF-16LE` | Yes | — | Yes | Core/default | Yes |
| `UTF-32` | Yes | — | Yes | Core/default | Yes |
| `UTF-32BE` | Yes | — | Yes | Core/default | Yes |
| `UTF-32LE` | Yes | — | Yes | Core/default | Yes |
| `UTF-7` | Yes | — | Yes | Core/default | Yes |
| `UTF-8` | Yes | — | Yes | Core/default | Yes |
| `VISCII` | Yes | — | Yes | Core/default | Yes |
