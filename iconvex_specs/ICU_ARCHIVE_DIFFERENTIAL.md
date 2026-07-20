# ICU historical archive differential

ICU 78.3 `makeconv` independently compiled 977 of the 1,050 pinned UCM
sources. All 7075555 strict mappings from the accepted sources matched ICU's C
runtime oracle. The remaining 73 legacy files are retained and
exhaustively tested from source, but modern `makeconv` rejects their old metadata.

Oracle transcript SHA-256: `dd1a8e76aa2c14dc3d53bf0452a6b37a1d59cf2f406bcdd313a2b36dd8742e4d`.

## Modern makeconv rejections

| Canonical archive codec | Normalized diagnostic |
|---|---|
| `ICU-ARCHIVE-aix-CNS11643.1986_1-4.3.6` | ucm error: missing conversion type (<uconv_class>); Error creating converter for "aix-CNS11643.1986_1-4.3.6.cnv" file for "aix-CNS11643.1986_1-4.3.6.ucm" (U_INVALID_TABLE_FORMAT) |
| `ICU-ARCHIVE-aix-CNS11643.1986_2-4.3.6` | ucm error: missing conversion type (<uconv_class>); Error creating converter for "aix-CNS11643.1986_2-4.3.6.cnv" file for "aix-CNS11643.1986_2-4.3.6.ucm" (U_INVALID_TABLE_FORMAT) |
| `ICU-ARCHIVE-aix-IBM_932-4.3.6` | ucm error: missing conversion type (<uconv_class>); Error creating converter for "aix-IBM_932-4.3.6.cnv" file for "aix-IBM_932-4.3.6.ucm" (U_INVALID_TABLE_FORMAT) |
| `ICU-ARCHIVE-aix-IBM_943-4.3.6` | ucm error: missing conversion type (<uconv_class>); Error creating converter for "aix-IBM_943-4.3.6.cnv" file for "aix-IBM_943-4.3.6.ucm" (U_INVALID_TABLE_FORMAT) |
| `ICU-ARCHIVE-aix-IBM_eucJP-4.3.6` | ucm error: missing conversion type (<uconv_class>); Error creating converter for "aix-IBM_eucJP-4.3.6.cnv" file for "aix-IBM_eucJP-4.3.6.ucm" (U_INVALID_TABLE_FORMAT) |
| `ICU-ARCHIVE-aix-IBM_eucKR-4.3.6` | ucm error: missing conversion type (<uconv_class>); Error creating converter for "aix-IBM_eucKR-4.3.6.cnv" file for "aix-IBM_eucKR-4.3.6.ucm" (U_INVALID_TABLE_FORMAT) |
| `ICU-ARCHIVE-aix-IBM_eucTW-4.3.6` | ucm error: missing conversion type (<uconv_class>); Error creating converter for "aix-IBM_eucTW-4.3.6.cnv" file for "aix-IBM_eucTW-4.3.6.ucm" (U_INVALID_TABLE_FORMAT) |
| `ICU-ARCHIVE-aix-IBM_udcJP_GR-4.3.6` | ucm error: missing conversion type (<uconv_class>); Error creating converter for "aix-IBM_udcJP_GR-4.3.6.cnv" file for "aix-IBM_udcJP_GR-4.3.6.ucm" (U_INVALID_TABLE_FORMAT) |
| `ICU-ARCHIVE-aix-JISX0208.1983_0-4.3.6` | ucm error: missing conversion type (<uconv_class>); Error creating converter for "aix-JISX0208.1983_0-4.3.6.cnv" file for "aix-JISX0208.1983_0-4.3.6.ucm" (U_INVALID_TABLE_FORMAT) |
| `ICU-ARCHIVE-aix-JISX0208.1983_GR-4.3.6` | ucm error: missing conversion type (<uconv_class>); Error creating converter for "aix-JISX0208.1983_GR-4.3.6.cnv" file for "aix-JISX0208.1983_GR-4.3.6.ucm" (U_INVALID_TABLE_FORMAT) |
| `ICU-ARCHIVE-aix-KSC5601.1987_0-4.3.6` | ucm error: missing conversion type (<uconv_class>); Error creating converter for "aix-KSC5601.1987_0-4.3.6.cnv" file for "aix-KSC5601.1987_0-4.3.6.ucm" (U_INVALID_TABLE_FORMAT) |
| `ICU-ARCHIVE-aix-big5-4.3.6` | ucm error: missing conversion type (<uconv_class>); Error creating converter for "aix-big5-4.3.6.cnv" file for "aix-big5-4.3.6.ucm" (U_INVALID_TABLE_FORMAT) |
| `ICU-ARCHIVE-glibc-ANSI_X3.110-2.1.2` | ucm error: missing conversion type (<uconv_class>); Error creating converter for "glibc-ANSI_X3.110-2.1.2.cnv" file for "glibc-ANSI_X3.110-2.1.2.ucm" (U_INVALID_TABLE_FORMAT) |
| `ICU-ARCHIVE-glibc-ANSI_X3.110-2.3.3` | ucm error: missing state table information (<icu:state>) for MBCS |
| `ICU-ARCHIVE-glibc-BIG5-2.1.2` | ucm error: missing conversion type (<uconv_class>); Error creating converter for "glibc-BIG5-2.1.2.cnv" file for "glibc-BIG5-2.1.2.ucm" (U_INVALID_TABLE_FORMAT) |
| `ICU-ARCHIVE-glibc-BIG5-2.3.3` | ucm error: missing state table information (<icu:state>) for MBCS |
| `ICU-ARCHIVE-glibc-BIG5HKSCS-2.3.3` | ucm error: missing state table information (<icu:state>) for MBCS |
| `ICU-ARCHIVE-glibc-CP932-2.3.3` | ucm error: missing state table information (<icu:state>) for MBCS |
| `ICU-ARCHIVE-glibc-EUC_CN-2.1.2` | ucm error: missing conversion type (<uconv_class>); Error creating converter for "glibc-EUC_CN-2.1.2.cnv" file for "glibc-EUC_CN-2.1.2.ucm" (U_INVALID_TABLE_FORMAT) |
| `ICU-ARCHIVE-glibc-EUC_CN-2.3.3` | ucm error: missing state table information (<icu:state>) for MBCS |
| `ICU-ARCHIVE-glibc-EUC_JP-2.1.2` | ucm error: missing conversion type (<uconv_class>); Error creating converter for "glibc-EUC_JP-2.1.2.cnv" file for "glibc-EUC_JP-2.1.2.ucm" (U_INVALID_TABLE_FORMAT) |
| `ICU-ARCHIVE-glibc-EUC_JP-2.3.3` | ucm error: missing state table information (<icu:state>) for MBCS |
| `ICU-ARCHIVE-glibc-EUC_JP_MS-2.3.3` | ucm error: missing state table information (<icu:state>) for MBCS |
| `ICU-ARCHIVE-glibc-EUC_KR-2.1.2` | ucm error: missing conversion type (<uconv_class>); Error creating converter for "glibc-EUC_KR-2.1.2.cnv" file for "glibc-EUC_KR-2.1.2.ucm" (U_INVALID_TABLE_FORMAT) |
| `ICU-ARCHIVE-glibc-EUC_KR-2.3.3` | ucm error: missing state table information (<icu:state>) for MBCS |
| `ICU-ARCHIVE-glibc-EUC_TW-2.1.2` | ucm error: missing conversion type (<uconv_class>); Error creating converter for "glibc-EUC_TW-2.1.2.cnv" file for "glibc-EUC_TW-2.1.2.ucm" (U_INVALID_TABLE_FORMAT) |
| `ICU-ARCHIVE-glibc-GBK-2.3.3` | ucm error: missing state table information (<icu:state>) for MBCS |
| `ICU-ARCHIVE-glibc-IBM943-2.3.3` | ucm error: missing state table information (<icu:state>) for MBCS |
| `ICU-ARCHIVE-glibc-ISO_6937-2.3.3` | ucm error: missing state table information (<icu:state>) for MBCS |
| `ICU-ARCHIVE-glibc-JOHAB-2.3.3` | ucm error: missing state table information (<icu:state>) for MBCS |
| `ICU-ARCHIVE-glibc-SJIS-2.1.2` | ucm error: missing conversion type (<uconv_class>); Error creating converter for "glibc-SJIS-2.1.2.cnv" file for "glibc-SJIS-2.1.2.ucm" (U_INVALID_TABLE_FORMAT) |
| `ICU-ARCHIVE-glibc-SJIS-2.3.3` | ucm error: missing state table information (<icu:state>) for MBCS |
| `ICU-ARCHIVE-glibc-T.61_8BIT-2.3.3` | ucm error: missing state table information (<icu:state>) for MBCS |
| `ICU-ARCHIVE-glibc-UHC-2.1.2` | ucm error: missing conversion type (<uconv_class>); Error creating converter for "glibc-UHC-2.1.2.cnv" file for "glibc-UHC-2.1.2.ucm" (U_INVALID_TABLE_FORMAT) |
| `ICU-ARCHIVE-glibc-UHC-2.3.3` | ucm error: missing state table information (<icu:state>) for MBCS |
| `ICU-ARCHIVE-hpux-big5-11.11` | ucm error: missing state table information (<icu:state>) for MBCS |
| `ICU-ARCHIVE-hpux-eucJP-11.11` | ucm error: missing state table information (<icu:state>) for MBCS |
| `ICU-ARCHIVE-hpux-eucJP0201-11.11` | ucm error: missing state table information (<icu:state>) for MBCS |
| `ICU-ARCHIVE-hpux-eucJPMS-11.11` | ucm error: missing state table information (<icu:state>) for MBCS |
| `ICU-ARCHIVE-hpux-eucKR-11.11` | ucm error: missing state table information (<icu:state>) for MBCS |
| `ICU-ARCHIVE-hpux-eucTW-11.11` | ucm error: missing state table information (<icu:state>) for MBCS |
| `ICU-ARCHIVE-hpux-hkbig5-11.11` | ucm error: missing state table information (<icu:state>) for MBCS |
| `ICU-ARCHIVE-hpux-hp15CN-11.11` | ucm error: missing state table information (<icu:state>) for MBCS |
| `ICU-ARCHIVE-hpux-roc15-11.11` | ucm error: missing state table information (<icu:state>) for MBCS |
| `ICU-ARCHIVE-hpux-sjis-11.11` | ucm error: missing state table information (<icu:state>) for MBCS |
| `ICU-ARCHIVE-hpux-sjis0201-11.11` | ucm error: missing state table information (<icu:state>) for MBCS |
| `ICU-ARCHIVE-hpux-sjisMS-11.11` | ucm error: missing state table information (<icu:state>) for MBCS |
| `ICU-ARCHIVE-java-Cp930-1.3_P` | error: DBCS codepage with min B/char!=1 or max B/char!=2 |
| `ICU-ARCHIVE-java-Cp933-1.3_P` | error: DBCS codepage with min B/char!=1 or max B/char!=2 |
| `ICU-ARCHIVE-java-Cp935-1.3_P` | error: DBCS codepage with min B/char!=1 or max B/char!=2 |
| `ICU-ARCHIVE-java-Cp937-1.3_P` | error: DBCS codepage with min B/char!=1 or max B/char!=2 |
| `ICU-ARCHIVE-java-Cp939-1.3_P` | error: DBCS codepage with min B/char!=1 or max B/char!=2 |
| `ICU-ARCHIVE-java-Cp942C-1.3_P` | ucm error: missing state table information (<icu:state>) for MBCS |
| `ICU-ARCHIVE-java-Cp943-1.2.2` | ucm error: byte sequence ends in illegal state; <U005C> \xFE \|0; <U007E> \xFF \|0 (+3 more unique diagnostics) |
| `ICU-ARCHIVE-java-Cp943C-1.3_P` | ucm error: byte sequence too short, ends in non-final state 1; <U00A7> \x81\x98 \|0; ucm error: byte sequence ends in illegal state (+1637 more unique diagnostics) |
| `ICU-ARCHIVE-java-Cp948-1.3_P` | ucm error: missing state table information (<icu:state>) for MBCS |
| `ICU-ARCHIVE-java-EUC_JP-1.3_P` | error: byte sequence ends in unassigned state at U+00c0<->0x8faaa2; error: byte sequence ends in unassigned state at U+00c1<->0x8faaa1; error: byte sequence ends in unassigned state at U+00c2<->0x8faaa4 (+686 more unique diagnostics) |
| `ICU-ARCHIVE-java-EUC_TW-1.3_P` | error: byte sequence ends in unassigned state at U+4e04<->0x8ea3a1a6; error: byte sequence ends in unassigned state at U+4e05<->0x8ea3a1a5; error: byte sequence ends in unassigned state at U+4e20<->0x8ea3a2e2 (+4195 more unique diagnostics) |
| `ICU-ARCHIVE-java-ISO2022JP-1.3_P` | ucm error: illegal <mb_cur_max> 8 |
| `ICU-ARCHIVE-java-ISO2022KR-1.3_P` | ucm error: illegal <mb_cur_max> 8 |
| `ICU-ARCHIVE-java-Johab-1.3_P` | ucm error: byte sequence ends in illegal state; <U00A8> \xD9\x37 \|0; <U00AD> \xD9\x39 \|0 (+1538 more unique diagnostics) |
| `ICU-ARCHIVE-java-MS949-1.3_P` | ucm error: byte sequence ends in illegal state; <UAC5B> \x81\x85 \|0; <UAC5D> \x81\x86 \|0 (+2264 more unique diagnostics) |
| `ICU-ARCHIVE-solaris-5601-2.7` | ucm error: missing conversion type (<uconv_class>); Error creating converter for "solaris-5601-2.7.cnv" file for "solaris-5601-2.7.ucm" (U_INVALID_TABLE_FORMAT) |
| `ICU-ARCHIVE-solaris-EUC_KR-2.7` | ucm error: missing conversion type (<uconv_class>); Error creating converter for "solaris-EUC_KR-2.7.cnv" file for "solaris-EUC_KR-2.7.ucm" (U_INVALID_TABLE_FORMAT) |
| `ICU-ARCHIVE-solaris-PCK-2.7` | ucm error: missing conversion type (<uconv_class>); Error creating converter for "solaris-PCK-2.7.cnv" file for "solaris-PCK-2.7.ucm" (U_INVALID_TABLE_FORMAT) |
| `ICU-ARCHIVE-solaris-eucJP-2.7` | ucm error: missing conversion type (<uconv_class>); Error creating converter for "solaris-eucJP-2.7.cnv" file for "solaris-eucJP-2.7.ucm" (U_INVALID_TABLE_FORMAT) |
| `ICU-ARCHIVE-solaris-zh_CN.euc-2.7` | ucm error: missing conversion type (<uconv_class>); Error creating converter for "solaris-zh_CN.euc-2.7.cnv" file for "solaris-zh_CN.euc-2.7.ucm" (U_INVALID_TABLE_FORMAT) |
| `ICU-ARCHIVE-solaris-zh_CN.gbk-2.7` | ucm error: missing conversion type (<uconv_class>); Error creating converter for "solaris-zh_CN.gbk-2.7.cnv" file for "solaris-zh_CN.gbk-2.7.ucm" (U_INVALID_TABLE_FORMAT) |
| `ICU-ARCHIVE-solaris-zh_CN_cp935-2.7` | ucm error: missing conversion type (<uconv_class>); Error creating converter for "solaris-zh_CN_cp935-2.7.cnv" file for "solaris-zh_CN_cp935-2.7.ucm" (U_INVALID_TABLE_FORMAT) |
| `ICU-ARCHIVE-solaris-zh_HK.hkscs-5.9` | ucm error: missing state table information (<icu:state>) for MBCS |
| `ICU-ARCHIVE-solaris-zh_TW_cp937-2.7` | ucm error: missing conversion type (<uconv_class>); Error creating converter for "solaris-zh_TW_cp937-2.7.cnv" file for "solaris-zh_TW_cp937-2.7.ucm" (U_INVALID_TABLE_FORMAT) |
| `ICU-ARCHIVE-solaris-zh_TW_euc-2.7` | ucm error: missing conversion type (<uconv_class>); Error creating converter for "solaris-zh_TW_euc-2.7.cnv" file for "solaris-zh_TW_euc-2.7.ucm" (U_INVALID_TABLE_FORMAT) |
| `ICU-ARCHIVE-windows-20261-2000` | ucm error: missing state table information (<icu:state>) for MBCS |
