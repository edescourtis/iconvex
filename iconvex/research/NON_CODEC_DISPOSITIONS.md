# Audited non-codec dispositions

The public-source catalog intentionally discovers adjacent artifacts as well as
byte-stream encodings. `implementation_disposition` prevents those records from
being counted as missing codecs without deleting the evidence that found them.

| Disposition | Records | Why no codec is implemented |
|---|---|---|
| `platform_adapter` | GNU `CHAR`, `WCHAR_T`; Python `mbcs` | Locale/ABI-dependent adapters, not stable encodings with portable byte semantics. `mbcs` delegates to the active Windows ANSI code page. |
| `non_text_coding_system` | Seven ISO-IR data-syntax registrations | Audio, videotex, presentation, or transparent data syntaxes rather than character-to-byte mappings. |
| `registry_component` | Unicode `VENDORS/APPLE/CORPCHAR.TXT` | The file identifies itself as Apple's registry of Unicode corporate-zone characters; it defines PUA assignments and hints, not a serialized charset. |
| `entity_mapping` | Unicode `VENDORS/MISC/SGML.TXT` | The file maps SGML entity names and public entity sets to Unicode and explicitly says the relation is non-reversible; it is not an octet codec. |
| `internal_component` | Six OpenJDK helper tables | Implementation components used by public Java charsets, not independently registered `Charset` implementations. |
| `placeholder` | IANA `UNKNOWN-8BIT` | An unknown-charset label has no deterministic mapping to implement. |
| `retired_invalid` | IBM-61952 | ICU says this Unicode 1.1 number is not a valid CCSID; IBM i calls it old and recommends 13488. |
| `control_value` | IBM-65534, IBM-65535 | IBM defines 65534 as “look at lower level CCSID” and 65535 as hexadecimal data for which no conversion is done. |
| `repertoire_profile` | ISO-Unicode-IBM-1261/-1264/-1265/-1268/-1276; Adobe-Japan1; JIS X 0213; Juki Toitsu Moji; Microsoft Standard Japanese Character Set; Moji Joho Kiban, Koseki, IBM Extended, and Registry Unified character lists | Character/glyph collections or coded repertoires. A CMap, encoding form, or other serialization is required before any of these becomes a byte codec. |
| `encoding_family` | EBCDIC, BCDIC, ECMA-6, FIELDATA, ISO 646, ISO/IEC 10646, ISO/IEC 8859, JIS kanji codes, JIS X 0221, LMBCS, six-bit code, Swedish ASCII, TI/Casio calculator sets, Unicode, Videotex, YUSCII | Umbrella names with incompatible child tables or serializations. Their disposition never counts any child as implemented. |
| `control_standard` | ECMA-48, JIS X 0211 | Control functions and escape-sequence architecture layered on coded character sets, not one standalone character-to-byte mapping. |
| `withdrawn_unassigned_part` | ISO/IEC 8859-12 | The proposed Devanagari part was abandoned and never published as an assigned 8859 codec. |
| `repertoire_abstraction` | Portable character set, “alphanumeric” | Abstract source/execution repertoires, not serialized byte encodings. |
| `binary_transform` | Base45; Python base64, hex, quoted-printable, and uu codecs | Reversible binary-to-printable transforms. Python classifies its variants as bytes-to-bytes; RFC 9285 likewise defines Base45 over arbitrary octets, outside character-set conversion. |
| `compression_transform` | Python bz2 and zlib codecs | Compression transforms over arbitrary bytes, not mappings from a character repertoire. |
| `text_transform` | Python ROT13 | A Unicode string-to-string transform, not a byte charset. |
| `terminal_protocol` | AVATAR | A BBS terminal escape/control protocol layered on terminal text. |
| `font_identity` | Bookshelf Symbol 7, Cariadings, Marlett, Symbol, URW Dingbats, Webdings, Wingdings 1/2/3 | Typeface names are not stable byte mappings. A separately versioned font cmap may still become an actionable mapping record. |
| `writing_system` | Generic Braille code | A tactile writing-system family with language and grade conventions. Concrete BRF/Braille ASCII remains a separately implemented codec. |
| `visual_signaling_system` | International maritime signal flags | Visual flag signals governed by the International Code of Signals, not serialized text bytes. |
| `coding_technique` | Variable-length code | A general information-theory technique rather than one deterministic format. |
| `unicode_representation_profile` | SignWriting in Unicode | A Unicode code-point and spatial-layout representation whose bytes come from a normal Unicode encoding form. |
| `unicode_sequence_profile` | Unicode emoji variation sequences | Unicode scalar sequences selecting text/emoji presentation; UTF forms provide the bytes. |
| `unicode_sequence_mechanism` | Unicode variation sequences | A glyph-selection mechanism within Unicode text, not an independent byte codec. |

## Non-coverage rule and child audit

An `encoding_family`, `font_identity`, or `repertoire_profile` row is only a
classification of that exact umbrella title. It must never make a concrete
child disappear from `codec_gap` or `research_candidate`.

- LMBCS-1 is implemented. ICU 78.3 also contains executable, unadvertised
  converters for optimization groups 2, 3, 4, 5, 6, 8, 11, 16, 17, 18, and
  19. Each is separately inventoried; ICU defines no converter open for groups
  7, 9, 10, 12, 13, 14, 15, or 20.
- Swedish ASCII resolves to the distinct implemented ISO-IR-10 and ISO-IR-11
  variants. YUSCII resolves to `JUS_I.B1.002`, `JUS_I.B1.003-serb`, and
  `JUS_I.B1.003-mac`. Neither umbrella is itself a codec alias.
- JIS X 0213's raw planes and standard serializations are independently
  inventoried. JIS X 0221 and the Unicode Standard likewise rely on the
  separately listed UCS/UTF encoding forms.
- Concrete BCDIC, Casio, additional source-qualified FIELDATA, and six-bit
  tables remain separate work. Candidate child rows are added only when the
  cited model/revision can be named; an umbrella disposition is not evidence
  of completion. The exact UNIVAC 1100 and 4009 FIELDATA children are
  implemented while the ambiguous `Fieldata` umbrella remains a family.
- TI-83 Plus, TI-89/TI-92 Plus, and source-qualified JIS7-KANJI profiles are implemented.
  Their exact primary tables, profile boundaries, aliases, and transports are
  independently inventoried. The broader TI/Casio and JIS-family umbrella rows
  remain non-codec families and do not claim coverage for unnamed children.
- Mojikyō and Wikidata U-PRESS (Q17190477) remain `codec_gap` records pending
  public, versioned byte-level codebooks. They are intentionally not swept
  into a repertoire disposition.

Primary evidence:

- Wikidata U-PRESS entity data: <https://www.wikidata.org/wiki/Special:EntityData/Q17190477.json>
- Unicode Apple registry: <https://www.unicode.org/Public/MAPPINGS/VENDORS/APPLE/CORPCHAR.TXT>
- Unicode SGML entity map: <https://www.unicode.org/Public/MAPPINGS/VENDORS/MISC/SGML.TXT>
- IANA Character Sets registry: <https://www.iana.org/assignments/character-sets/character-sets.xhtml>
- IANA/IETF charset archive disposition: <https://data.iana.org/archive/ietf-charsets/msg01193.html>
- IBM i CCSID definitions: <https://www.ibm.com/docs/en/i/7.4.0?topic=information-ccsid-values-defined-i>
- ICU converter aliases: <https://raw.githubusercontent.com/unicode-org/icu/release-78-3/icu4c/source/data/mappings/convrtrs.txt>
- ECMA-48: <https://ecma-international.org/publications-and-standards/standards/ecma-48/>
- POSIX portable character set: <https://pubs.opengroup.org/onlinepubs/9799919799/basedefs/V1_chap06.html>
- RFC 9285 Base45: <https://www.rfc-editor.org/rfc/rfc9285.html>
- Python binary/text transforms and `mbcs`: <https://docs.python.org/3/library/codecs.html>
- ICU LMBCS engine: <https://github.com/unicode-org/icu/blob/release-78-3/icu4c/source/common/ucnv_lmb.cpp>
- Adobe CJK CID collections: <https://partners.adobe.com/public/developer/en/font/5094.CJK_CID.pdf>
- Unicode variation sequences: <https://www.unicode.org/faq/vs.html>
- International Code of Signals: <https://www.imo.org/en/publications/pages/international-code-of-signals.aspx>

`codec_gap` is therefore the actionable queue; `research_candidate` still
needs a mapping-level source. Neither category is silently treated as covered.
