# Iconvex Specs

Pure Elixir codecs sourced from public character-set specifications and pinned
mapping archives. It is an external codec package for
[`iconvex`](https://hex.pm/packages/iconvex); runtime conversion does not call an OS `iconv`, NIF,
Port, or executable.

The final source-qualified research closure adds these exact public names:
`CTAN-LY1-TEXNANSI-1.1-AGL-4036A9CA`,
`ADOBE-POSTSCRIPT-3-ISOLATIN1-AGL-4036A9CA`,
`TAMILVU-TACE16-APPENDIX-D-2010-16BE`,
`TAMILVU-TACE16-APPENDIX-D-2010-16LE`,
`WANG-1983-WISCII-PDF-F4043449-WIKIPEDIA-REV1352856854`,
`WIKIPEDIA-REV1354794598-PARATYPE-WINDOWS-POLYTONIC-GREEK`, and
`WIKIPEDIA-REV1340817319-EKI-SAMI-WIN-CP1270`. Generic aliases are withheld
where the evidence selects a revision, composite mapping, or byte order.
For WISCII, the public `provenance/0` record keeps the external copyrighted
Wang chart (`NOASSERTION`; no redistribution license identified) separate from
the `CC-BY-SA-4.0` Wikipedia revision that supplies its Unicode binding.

The package imports all 145 coded character sets in RFC 1345, 28 Unicode-hosted
Adobe/Apple mappings, the complete LOC MARC-8 repertoire and ANSEL, ISCII-91
with all ten Microsoft initial-script names, all 29 glibc charmaps absent from
the co-installed Iconvex stack, all 135 standalone single-byte, 30 complete
table-driven multibyte/double-byte, and ten mixed-width stateful EBCDIC mapping
revisions shipped by ICU 78.3. It also preserves and exposes all 1,050 historical
vendor/platform UCM revisions in Unicode's ICU data repository under collision-free
`ICU-ARCHIVE-*` names. Its algorithmic public-specification families include
`BOCU-1`, RFC 3492 `PUNYCODE`, `CESU-8`, modified IMAP UTF-7, Java Modified UTF-8, `SCSU`,
`UTF-EBCDIC`, WHATWG `x-user-defined`, RFC 4042 UTF-9/UTF-18, and separately
audited Unicode/vendor formats. The native ICU-compatible LMBCS engine exposes
all twelve instantiated optimization profiles (`LMBCS-1`, `-2`, `-3`, `-4`,
`-5`, `-6`, `-8`, `-11`, `-16`, `-17`, `-18`, and `-19`) without inventing
names for unused groups. Unicode's published APL/ISO-IR-68 current and
2004 revisions and KPS 9566-2003 are also native table codecs. The generated
non-octet inventory additionally exposes six source-qualified 12-bit
punched-card profiles, with twelve registered zero-padded 16-bit transports. The
generated runtime inventory contains exactly 1,841 byte-pipeline codecs; the
audit catalog retains two additional quarantined RFC definitions (1,843 total). Of the RFC
sets, 143 are complete and automatically register with Iconvex. Two are kept
in the manifest but deliberately not registered:

- `JIS_C6226-1978`: RFC 1345 gives 6,349 synthetic grid identifiers but no
  Unicode mapping, and no public normative mapping was found.
- `IBM423`: RFC erratum 6067 still contains 272 cells for an 8-bit code page.

This distinction prevents a partial table from being advertised as a codec.
See [SUPPORTED_CODEC_INVENTORY.csv](SUPPORTED_CODEC_INVENTORY.csv) for every
registered canonical name and alias, its module, and statefulness flag.
[SUPPORTED_ENCODINGS.md](SUPPORTED_ENCODINGS.md) summarizes codec families and
exact mapping counts.

## PASCII C-DAC GIST 1.0

Four explicit PASCII Version 1.0 profiles implement the complete C-DAC GIST
byte chart: Urdu/Kashmiri and Sindhi Unicode 17 best-fit views, an exact
assigned-byte VPUA identity, and a forensic raw-byte identity. The standard
does not define a normative Unicode mapping, so Iconvex intentionally exports
no bare `PASCII`, Persian, or Arabic best-fit alias. This prevents a convenient
projection from being mistaken for a standard-defined national mapping.

```elixir
{:ok, text} =
  Iconvex.convert(
    <<0x8C, 0x9E, 0xCB>>,
    "PASCII-CDAC-GIST-1.0-2002-URDU-KASHMIRI-UNICODE17-BEST-FIT",
    "UTF-8"
  )

{:ok, original} =
  Iconvex.convert(
    text,
    "UTF-8",
    "PASCII-CDAC-GIST-1.0-2002-URDU-KASHMIRI-UNICODE17-BEST-FIT"
  )
```

Use `PASCII-CDAC-GIST-1.0-2002-LOSSLESS-VPUA-1` when exact assigned-byte
identity matters and `PASCII-CDAC-GIST-1.0-2002-RAW-VPUA-1` for forensic data
that may include unassigned or reserved values.

## Unicode 17 provisional kGB3 row/cell

`UNIHAN-17.0.0-KGB3-ROW-CELL-GL` is the exact 7,236-assignment Unicode 17
`kGB3` snapshot serialized as raw two-byte GL row/cell values. A separate
single-token property API exposes the original four-decimal-digit values. Both
surfaces are version- and property-qualified: bare GB 13131, GB/T 7589, KGB3,
EUC, GR, and ISO-2022 aliases are intentionally absent because Unicode 17 has
no assignment for coordinate 1893 and does not define those transports.

See [UNIHAN_GB3_ROW_CELL.md](UNIHAN_GB3_ROW_CELL.md) for the exact source
digests, conformance boundary, exhaustive tests, and regeneration command.

The algorithmic codecs have a separate exhaustive result in
[ALGORITHMIC_DIFFERENTIAL.md](ALGORITHMIC_DIFFERENTIAL.md). A pinned UTF-32BE
file contains every 1,112,064 Unicode scalar. Full-repertoire codecs encode and
decode it as one stateful stream; ICU 78.3 cross-decodes both directions where
it has an independent implementation. `x-user-defined` exhaustively covers its
entire 256-byte repertoire. All twelve LMBCS optimization profiles have a
separate byte-exact ICU report in
[ICU_LMBCS_DIFFERENTIAL.md](ICU_LMBCS_DIFFERENTIAL.md).

Seven additional source-qualified IBM/DEC profiles cover CP310, CP907, CP1116,
CP1117, DEC Greek/IBM-1287, and DEC Turkish/IBM-1288. The composite IBM pages
use names that state their exact GCGID/UCM join and never claim an ambiguous
generic identity. Their checked-in generator, 256-byte vectors, source digests,
all-scalar evidence, and package contract are documented in
`priv/sources/ibm-additional-code-pages/SOURCE_METADATA.md`.

## Unihan 17 Chinese telegraph property tokens

Three non-codec APIs cover the exact four-decimal-digit values of Unicode
17.0.0 `kMainlandTelegraph` and `kTaiwanTelegraph`: Mainland exact, Taiwan
readable, and Taiwan lossless. They validate and convert one property token,
not a byte stream. Unicode defines no multi-token framing here, so generic
names such as `CHINESE-TELEGRAPH` remain unregistered rather than silently
choosing a region, separator, packing, or error-recovery rule.

```elixir
alias Iconvex.Specs.Unihan17MainlandTelegraphDecimalToken, as: Telegraph

{:ok, "一"} = Telegraph.decode_token_to_utf8("0001")
{:ok, "0001"} = Telegraph.encode_utf8_to_token("一")
```

All 10,000 possible tokens are tested in each profile. The Taiwan lossless
mapping is bijective across its 9,026 assigned tokens and explicitly protects
two duplicate scalars plus two normalization collisions. See
[`UNIHAN_TELEGRAPH_PROPERTY_TOKENS.md`](UNIHAN_TELEGRAPH_PROPERTY_TOKENS.md)
and the machine-readable
[`SUPPORTED_PROPERTY_TOKEN_MAPPING_INVENTORY.csv`](SUPPORTED_PROPERTY_TOKEN_MAPPING_INVENTORY.csv).

## TI-89 / TI-92 Plus AMS 2.0

Four explicitly versioned codecs cover all 256 byte values from the official
AMS 2.0 character table. `TI-89-92-PLUS-AMS-2.0` is the audited source-glyph
profile, `-VISIBLE` renders the printed C0 mnemonics as control pictures,
`-LOSSLESS-VPUA` assigns source-qualified identities only to seven ambiguous
cells, and `-RAW-VPUA` maps every byte one-to-one to U+F8A00–U+F8AFF. The three
readable profiles preserve the multi-scalar forms at bytes 9A, 9B, and B4 and
use longest-match-first reverse conversion. None performs Unicode
normalization or compatibility folding.

```elixir
{:ok, text} =
  Iconvex.convert(<<0x9A, 0x9B, 0xB4>>, "TI-89-92-PLUS-AMS-2.0", "UTF-8")

{:ok, <<0x9A, 0x9B, 0xB4>>} =
  Iconvex.convert(text, "UTF-8", "TI-89-92-PLUS-AMS-2.0")
```

The independent 256-row transcription, both official guidebook hashes, exact
physical and printed pages, glyph dispositions, and the byte-0 inference
boundary are in
`priv/sources/ti-89-92-plus-ams-2.0/SOURCE_METADATA.md`. The release ships that
metadata and the mapping CSV, never either source PDF or GPL oracle code.

## TI-83 Plus 2002 large and small fonts

Six explicit codecs preserve the materially different large- and small-font
tables in the 2002 TI-83 Plus Developer Guide. Each font has a readable
profile, a mixed `-LOSSLESS-VPUA` profile, and a forensic `-RAW-VPUA` profile.
No bare `TI-83-PLUS` alias is registered because it would hide the font choice.
The readable profiles retain multi-scalar forms, canonical reverse ownership,
decode-only duplicates, exact invalid tails, and longest-match encoding.

```elixir
{:ok, superscript} =
  Iconvex.convert(<<0x11>>, "TI-83-PLUS-LARGE", "UTF-8")

{:ok, <<0x11>>} =
  Iconvex.convert(superscript, "UTF-8", "TI-83-PLUS-LARGE")
```

Compilation hashes both packaged assets before parsing and then validates the
exact header, 256 ordered uppercase byte tokens, scalar and reverse policies,
alias ownership, canonical reverse uniqueness, and lossless bijections. The
release contains only the independent compact numeric CSV and digest-bearing
metadata—not the guide PDF, renders, source symbol transcription, or third-party
implementation code. Plane-15 allocations for both TI families and earlier
source-qualified codecs are centralized in `VPUA_ALLOCATIONS.md`.

## Installation

```elixir
def deps do
  [
    {:iconvex, "~> 0.1.0"},
    {:iconvex_specs, "~> 0.1.0"}
  ]
end
```

The application registers every complete codec automatically. Thirty-three
source tables whose published names collide with core use stable
`RFC1345:*`, `UNICODE-APPLE:*`, or `ICU-MULTIBYTE:*` canonical identities.
Another 25 RFC 1345 identities that conflict semantically with GNU spellings
use `RFC1345:*` for both their canonical names and aliases, so all 758 GNU
libiconv 1.19 spellings retain GNU semantics. The direct RFC API remains
unchanged. Codec registrations, Specs table providers, and all three
archive-shard provider ownership tokens survive a supervised Iconvex
registry-worker restart.

Specs installs all 1,841 codecs as one atomic managed set and can run beside
Extras and Telecom in any start order. Its 227 overlapping names with Extras
remain live as ranked claims, and Extras' GNU codecs win all of them. The 25
displaced RFC 1345 tables remain reachable under source-qualified canonical and
alias names. Stopping either package exposes every remaining overlapping claim
without a transient lookup gap. The full four-package registry has 2,093 unique
canonical names. See `CHANGELOG.md` for the compatibility migration.

The generated full-stack codec comparison at `../ICONVEX_FULL_STACK_SUPPORT.md`
is workspace-level integration evidence for all 2,093 canonical names and GNU
libiconv 1.19. It is intentionally not included in this package artifact; use
the workspace-relative path only from the sibling-package source checkout.

The 1,050 historical ICU revision tables are delivered by three transparent
`iconvex_specs_icu_archive_*` runtime dependencies. This keeps every Hex
artifact within its size limits without changing the `Iconvex.Specs` API or
requiring users to select shards. The source checkout retains the complete
mapping corpus, importers, benchmarks, and tests; release artifacts contain the
generated runtime tables and evidence documents.

The workspace aggregate derives the archive count from `Iconvex.Specs.ICUArchive.encodings/0` and
verifies that the live three-shard provider union exactly owns those manifest IDs.

```elixir
Iconvex.Specs.RFC1345.decode("T.61-8bit", <<0xC2, ?e>>)
# => {:ok, [0x00E9]}

Iconvex.Specs.RFC1345.encode("EBCDIC-US", [?A, ?a, ?0])
# => {:ok, <<0xC1, 0x81, 0xF0>>}

Iconvex.convert("😀", "UTF-8", "SCSU")
# => {:ok, <<0x0B, 0xE1, 0xEC, 0x80>>}

Iconvex.convert("台北", "UTF-8", "IMAP-UTF-7")
# => {:ok, "&U,BTFw-"}

{:ok, nonets} = Iconvex.Specs.UTF9.encode_packed([?A, 0x0391])
18 = bit_size(nonets)

{:ok, utf18} = Iconvex.Specs.UTF18.encode_packed([?A, 0x10330])
36 = bit_size(utf18)

{:ok, sixbit} = Iconvex.Specs.Packed.encode_from_utf8("ABC", "DEC-SIXBIT", :msb)
18 = bit_size(sixbit)

{:ok, fieldata} =
  Iconvex.Specs.Packed.encode_from_utf8("ABC", "FIELDATA-UNIVAC-1100", :msb)

18 = bit_size(fieldata)

{:ok, dec_graphics} = Iconvex.convert(<<0x60, 0x71>>, "DEC-SPECIAL", "UTF-8")
"◆─" = dec_graphics

{:ok, dec7} = Iconvex.Specs.Packed.encode_from_utf8("◆─", "DEC-SPECIAL", :msb)
14 = bit_size(dec7)

{:ok, hebrew7} = Iconvex.Specs.Packed.encode_from_utf8("Aא", "SI-960", :msb)
14 = bit_size(hebrew7)

{:ok, short_koi} = Iconvex.Specs.Packed.encode_from_utf8("AЮА", "SHORT-KOI", :msb)
21 = bit_size(short_koi)

{:ok, card} =
  Iconvex.Specs.Packed.encode_from_utf8("ABC", "IBM-7040-H-REPORT", :msb)

36 = bit_size(card)

{:ok, "ABC"} =
  Iconvex.Specs.Packed.decode_to_utf8(card, "IBM-7040-H-REPORT", :msb)

{:ok, "Aא"} = Iconvex.convert(<<0x41, 0xE0>>, "DEC-HEBREW-8", "UTF-8")

{:ok, rad50} = Iconvex.convert("X2B", "UTF-8", "DEC-RADIX-50")
<<0o115402::16-little>> = rad50
```

WG2 N5028 PETSCII interchange mappings describe graphic characters, not every
editor, color, cursor, or reverse-video command in a Commodore sequential file.
Callers can give those unmapped bytes file-format semantics without changing
the standards codec:

```elixir
controls = fn
  %Iconvex.InvalidByte{byte: 0x0D} -> {:replace, "\n"}
  %Iconvex.InvalidByte{byte: 0x12} -> {:replace, "<reverse-on>"}
  %Iconvex.InvalidByte{} -> :discard
end

text =
  petscii_chunks
  |> Iconvex.stream!("PETSCII", "UTF-8", on_invalid_byte: controls)
  |> Enum.join()
```

The callback receives canonical encoding, error kind, absolute offset, byte,
and original error sequence. It decides whether a byte is a command, ignored
padding, corruption, or replacement text.

Bare `UTF-9` and `UTF-18` are exact non-octet Elixir bitstrings and therefore
are not registered in the binary-only `Iconvex.convert/4` pipeline. Explicit
byte transports `UTF-9-16BE`, `UTF-9-16LE`, `UTF-18-24BE`, and `UTF-18-24LE`
are registered. Their exact runtime metadata is in
`SUPPORTED_NON_OCTET_CODEC_INVENTORY.csv`.

`ECMA-1`, `DEC-SIXBIT`, the four CDC Display Code CDC/ASCII 63/64-character
profiles, both full-ASCII CDC 6/12 profiles, three source-qualified UNIVAC I
expanded-code views, and five source-qualified UNIVAC FIELDATA profiles use one
six-bit unit per octet in `Iconvex.convert/4`. The
6/12 codecs use one or two units per character and cover all 128 ASCII values,
including controls and lowercase. `FIELDATA-UNIVAC-1100` is the complete,
bijective 64-cell 1100 Series table. The 4009 Display Console instead has
separate `-INPUT` and `-OUTPUT` device views plus readable `-LOSSLESS-VPUA` and
strictly forensic `-RAW-VPUA` profiles; no profile claims the ambiguous bare
`FIELDATA` name. The 4009's proprietary diamond-enclosed wave glyph uses its
source-qualified U+F402F identity rather than the visually and semantically
different modern U+1F6D1 octagonal sign. The UNIVAC I semantic profile keeps
printer-ignore, space, carriage-return, and tabulator actions distinct; its
lossless and raw VPUA profiles preserve non-character identities. A separate
checked codec validates the manual's leading odd-parity bit, and the paper-tape
codec validates physical `1,2,3,4,S,5,6,7` track rows. Neither claims the
ambiguous bare `UNIVAC-I` name. `DEC-SPECIAL` and `DEC-TECHNICAL` are the manual's 7-bit GL
forms; explicit `-GR` codecs preserve the corresponding A1-FE invocation
instead of masking bit 8. The Technical set keeps its nine unassigned cells
invalid, and later standardized Unicode Technical characters replace
historical private-use approximations.
SI 960 is a separate 7-bit profile: octets 60–7A replace lowercase ASCII with
Hebrew letters U+05D0–U+05EA, while all high octets are invalid. `DEC-HEBREW-8`
instead starts with DEC MCS, makes C0–DF and FB–FF invalid, and places those
letters at E0–FA. `Iconvex.Specs.Packed` provides explicit contiguous MSB- and
LSB-first bitstream transports for the sixteen six-bit profiles plus nineteen
7-bit profiles. FIELDATA's MSB form is the historical continuous layout of six
characters per 36-bit word; the LSB form is an explicit Iconvex interchange
option, not a claim about a historical file format. `SHORT-KOI` is the stateless
KOI-7 N2 mapping, distinct from the
registered SI/SO `KOI7-switched` codec. Standard `ELOT-927` is the ISO-IR-88
`greek7` table; `KERMIT-ELOT927-GREEK` is a separately named uppercase-only
terminal table that differs at 54 positions. All twelve DEC National
Replacement Character Sets have native byte and packed paths; their simple
national names resolve to the manual-defined profiles. Their
exact metadata is generated in
`SUPPORTED_PACKED_CODEC_INVENTORY.csv`.

The punched-card API keeps physical card masks distinct from byte encodings.
`IBM-7040-H-REPORT`, `IBM-7040-H-PROGRAM`, `IBM-1401-CARD`,
`CDC-167-BCD-HOLLERITH-1965`, and
`CDC-6000-STANDARD-HOLLERITH-1970` are primary-source logical 12-bit profiles.
The exact secondary reconstruction is exposed only as `BCD-CDC-IOWA` (or its
`BCD-CDC-IOWA-RECONSTRUCTED` alias); generic `BCD-CDC` and CDC card names stay
unclaimed. All six profiles are available in
`Iconvex.Specs.Packed`. Their registered `-16BE` and `-16LE` transports require
a zero upper nibble in every word. MSB-first packing is the standard facade;
LSB-first packing is deliberately explicit and is not advertised as a
historical card-file format.

ECMA-44 is exposed separately as an opaque code-combination/card transport,
not as a Unicode codec. `Iconvex.Specs.ECMA44` maps either the lower 128 or all
256 raw combinations to the standard's complete 12-row hole patterns, then
offers exact 12-bit MSB bitstrings, explicit library LSB containers, and
zero-padded 16BE/16LE words. No ECMA-6 or national character meaning is
invented, and none of the raw names enter `Iconvex.convert/4`. See
[`ECMA44_RAW_TRANSPORT.md`](ECMA44_RAW_TRANSPORT.md) and the separate
[`SUPPORTED_RAW_TRANSPORT_INVENTORY.csv`](SUPPORTED_RAW_TRANSPORT_INVENTORY.csv).

Four source-versioned Kermit names use separately audited native single-byte
paths: `GREEK-ISO` and its byte-identical `ELOT928-GREEK` alias follow the
archived ISO 8859-7:1987/ELOT 928 table; `HEBREW-ISO` preserves the historical
ISO 8859-8:1988 overline and undefined bidi-control positions; `LATIN6-ISO`
uses GNU libiconv 1.19's current ISO-8859-10 table instead of Kermit's defective
near-match; and `MACINTOSH-LATIN` is byte-exact with the archived Mac Icelandic
Windows-10079 mapping, including U+F8FF. Exhaustive source parsers guard all
1,024 octets and every canonical inverse.

Eleven further Kermit vendor tables have distinct names because their mappings
are not interchangeable with similarly numbered PC code pages:
`BULGARIA-PC`, `MAZOVIA`, `QNX-CONSOLE`, `DG-INTERNATIONAL`, and seven
`KERMIT-DG-*`, `KERMIT-HP-*`, or `KERMIT-SNI-*` profiles. Their direct and
packed-independent byte paths execute every source cell and canonical inverse
from the pinned Kermit revision. The seven 94-position terminal sets retain an
identity C0/space prefix and reject all octets beyond their documented range.
`CP856` remains core's Hebrew code page; only the explicit
`CP856-BULGARIAN` alias selects the Kermit Bulgarian table.

`KOI8-F` implements the complete 256-octet KOI8 Unified Cyrillic 2.1 mapping
published by New Mexico State University in 2008 from Fingertip Software's
character set. The source-qualified aliases identify this exact revision; the
published duplicate NO-BREAK SPACE cells at `0x9A` and `0xA0` decode
identically, and `0x9A` is their canonical reverse. The mapping source, its
SHA-256 provenance, and its MIT permission notice are packaged under
`priv/sources/koi8-f`, with the
notice also reproduced in `LICENSE.MIT-NMSU`.

DEC PDP-11 RADIX-50 is exposed as explicit `DEC-RADIX-50-16BE` and
`DEC-RADIX-50-16LE` word transports. The unqualified `DEC-RADIX-50`, `RAD50`,
and `MOD40` aliases select native PDP-11 little-endian storage. Short final
groups are padded on the right with spaces, exactly three base-40 digits occupy
each word, and the unused digit is rejected.

The distinct PDP-9/15 and PDP-6/10 formats are not collapsed into that PDP-11
mapping. `Iconvex.Specs.DECRadix50PDP9` exposes exact 18-bit words and
`Iconvex.Specs.DECRadix50PDP10` exact 36-bit words; their registered,
zero-padded byte transports are `DEC-RADIX-50-18BIT-24BE`/`24LE` and
`DEC-RADIX-50-36BIT-40BE`/`40LE`. Classification/tag bits are preserved by
the word helpers and rejected by the text-codec transports rather than being
silently discarded.

Regenerate tables and the support matrix with:

```sh
ICONVEX_PATH=../iconvex mix run tools/import_rfc1345.exs
ICONVEX_PATH=../iconvex mix run tools/import_vendor_mappings.exs
ICONVEX_PATH=../iconvex mix run tools/import_marc8.exs
ICONVEX_PATH=../iconvex mix run tools/import_iscii.exs
ICONVEX_PATH=../iconvex mix run tools/import_glibc_charmaps.exs
ICU_SOURCE_DIR=/path/to/icu/icu4c/source/data/mappings \
  elixir tools/import_icu_sbcs.exs
ICU_SOURCE_DIR=/path/to/icu/icu4c/source/data/mappings \
  elixir tools/import_icu_multibyte.exs
ICU_SOURCE_DIR=/path/to/icu/icu4c/source/data/mappings \
  elixir tools/import_icu_ebcdic_stateful.exs
ICU_ARCHIVE_SOURCE_DIR=/path/to/icu-data/charset/data/ucm \
  elixir tools/import_icu_archive.exs
UNICODE_MISC_SOURCE_DIR=/path/to/downloaded/unicode-misc \
  elixir tools/import_unicode_misc.exs
elixir tools/generate_unicode_scalar_corpus.exs
ICU_UCONV=/path/to/uconv ICONVEX_PATH=../iconvex \
  mix run tools/exhaustive_algorithmic_differential.exs

PKG_CONFIG_PATH=/path/to/icu/lib/pkgconfig \
  clang -O3 tools/icu_ucm_oracle.c -o /tmp/iconvex_icu_ucm_oracle \
  $(pkg-config --cflags --libs icu-uc)
ICU_UCM_ORACLE=/tmp/iconvex_icu_ucm_oracle ICONVEX_PATH=../iconvex \
  mix run tools/icu_sbcs_differential.exs
ICU_UCM_ORACLE=/tmp/iconvex_icu_ucm_oracle ICONVEX_PATH=../iconvex \
  mix run tools/icu_multibyte_differential.exs
ICU_UCM_ORACLE=/tmp/iconvex_icu_ucm_oracle ICONVEX_PATH=../iconvex \
  mix run tools/icu_ebcdic_stateful_differential.exs
ICU_MAKECONV=/path/to/makeconv ICU_PKGDATA=/path/to/pkgdata \
ICU_UCM_ORACLE=/tmp/iconvex_icu_ucm_oracle ICONVEX_PATH=../iconvex \
  mix run tools/icu_archive_differential.exs
ICONVEX_PATH=../iconvex mix run tools/generate_codec_inventory.exs
ICONVEX_PATH=../iconvex mix run tools/generate_non_octet_codec_inventory.exs
ICONVEX_PATH=../iconvex mix run tools/generate_packed_codec_inventory.exs
ICONVEX_PATH=../iconvex mix run tools/generate_property_token_mapping_inventory.exs
ICONVEX_PATH=../iconvex mix run tools/generate_raw_transport_inventory.exs
```

## License

Original library code: `LGPL-2.1-or-later`, matching GNU libiconv libraries.
Imported Apache and Unicode material retains upstream licenses; see
`LICENSE.APACHE-2.0`, `LICENSE.UNICODE`, and `NOTICE`. The pinned Kermit
`ckcuni.c` mapping tables retain BSD-3-Clause terms. The Hex artifact includes
their exact license at
`priv/sources/dec-terminal-character-sets/kermit/COPYING` and the corresponding
digest-bearing `priv/sources/kermit-vendor-8bit/SOURCE_METADATA.md`. UTF-8-MAC's
generated runtime tables retain the Apple C source's BSD-2-Clause attribution
in `LICENSE.BSD-2-CLAUSE`.

The verbatim CTAN TeX'n'ANSI vector retains `LPPL-1.0-or-later`, and the
verbatim CTAN cmap 1.0j OT1/OT1tt files retain `LPPL-1.3c-or-later`. Their
complete upstream terms are shipped as `licenses/upstream/LPPL-1.0.txt` and
`licenses/upstream/LPPL-1.3c.txt`, respectively.

The OpenJDK quarantine removes all seven source-informed codecs, their
generators, and all generated runtime assets from the LGPL release.
`x-eucJP-Open`, `x-MS950-HKSCS-XP`, `x-windows-50220`,
`x-windows-50221`, `x-windows-iso2022jp`,
`x-ISO-2022-CN-GB`, and `x-ISO-2022-CN-CNS` are not registered or shipped.
The four exact GPL-2.0-only-with-Classpath source snapshots remain repository-only
research/provenance evidence and are excluded from Hex. See `NOTICE` and their
pinned source metadata. This records a factual licensing boundary, not legal
advice.

Three formerly vendor-attributed BOM runtimes were independently replaced by
the neutral `ICONVEX-UTF-16-SIGNATURE-LE-DEFAULT`,
`ICONVEX-UTF-32BE-SIGNATURE`, and `ICONVEX-UTF-32LE-SIGNATURE` profiles. Their
new wrapper composes the LGPL Core UTF engines with a documented
Iconvex-defined framing policy; no vendor implementation or table is shipped.
These custom profiles are not Unicode-standard encoding schemes. See
`ICONVEX_UNICODE_SIGNATURE_PROFILES.md` and its packaged source metadata. This
is a factual provenance and release boundary, not legal advice.
