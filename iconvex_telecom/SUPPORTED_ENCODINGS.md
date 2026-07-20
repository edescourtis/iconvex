# Supported encodings

GNU libiconv 1.19 supports none of this telecom family. Iconvex Telecom adds 54
external codecs: 39 GSM 03.38 profiles and 15 telegraph, radio, alphabet, and
field codecs. Signal alphabets use an unpacked representation with one complete
signal element per octet; Morse uses the explicit textual envelope documented
below, and the two field codecs use their normative packed wire form.

[`SUPPORTED_CODEC_INVENTORY.csv`](SUPPORTED_CODEC_INVENTORY.csv) is generated
from the runtime modules by `tools/generate_codec_inventory.exs`. The package
contract proves that its 54 canonical names, every alias, module, ordering, and
statefulness flag exactly match the running application.

## Packed profile inventory

[`SUPPORTED_PACKED_CODEC_INVENTORY.csv`](SUPPORTED_PACKED_CODEC_INVENTORY.csv)
is generated from `Iconvex.Telecom.Packed.profiles/0`. It contains exactly
**51** fixed-width codecs: **5** five-bit, **4** six-bit, and **42** seven-bit
profiles. Each has explicit `-PACKED-MSB` and `-PACKED-LSB` transport names and
a declared standard order. Tests round-trip representative text for every
profile in both orders. The facade accepts those names and packed forms of every
codec alias; a suffix selects its named order, while an explicitly conflicting
order returns `{:error, :bit_order_mismatch}`.

The only three registered codecs outside this inventory are intentional:
Morse has variable-length dot/dash signals, while TBCD and SIM alpha identifiers
already define their own normative packed byte fields. The generic core
`Iconvex.Packed` API remains available for any other fixed-width external codec.

| Encoding | Standard | Unpacked unit |
|---|---|---|
| `ITA1` | 1958 ITU Telegraph Regulations, Art. 16 / CCITT No. 1 | one 5-bit unit per octet |
| `ITA2` | ITU-T S.1 / CCITT No. 2 | one 5-bit unit per octet |
| `ITA2-S2` | ITU-T S.2 case-preserving ITA2 | one 5-bit unit per octet |
| `ITA2-US-TTY` | American Teletypewriter national ITA2 variant | one 5-bit unit per octet |
| `MTK-2` | Russian Ministry of Communications Order No. 15 (2009) | one 5-bit unit per octet |
| `ITA3` | ITU-T S.13 three-of-seven ARQ alphabet | one 7-bit signal per octet |
| `ITA4` | ITU-T R.44 synchronous-multiplex alphabet | one 6-bit signal per octet |
| `ITU-T-T.50-IRV` | ITU-T T.50 International Reference Alphabet / IA5 | one 7-bit unit per octet |
| `MORSE-ITU-M1677` | ITU-R M.1677-1 International Morse | ASCII dot/dash tokens separated by spaces; `/` is a text space |
| `CCIR476` | ITU-R M.476-5 / SITOR / NAVTEX | one 7-bit four-of-seven signal per octet |
| `AIS6` | ITU-R M.1371-6 Table 45 | one 6-bit character value per octet |
| `IBM-2780-SIX-BIT-TRANSCODE-GA27-3005-3` | IBM 2780 Component Description GA27-3005-3 (1971) | one 6-bit unit per octet; standard packed order LSB-first |
| `IBM-BSC-SIX-BIT-TRANSCODE-GA27-3004-2` | IBM General Information — BSC GA27-3004-2 (1970) | one 6-bit unit per octet; standard packed order LSB-first |
| `TBCD` | 3GPP TS 29.002 Telephony BCD | two low-nibble-first digits per octet |
| `SIM-ALPHA-IDENTIFIER` | 3GPP TS 11.11 / TS 31.101; ETSI TS 102 221 §8.2 record bound | GSM default or UCS2 `0x80`/`0x81`/`0x82` field, at most 255 octets |

`ITA1` aliases include `ITA-1`, `CCITT-1`, `CCITT1`, `CCITT-NO-1`,
`BAUDOT-ORIGINAL`, `BAUDOT-CODE-ITA1`, and
`INTERNATIONAL-TELEGRAPH-ALPHABET-NO-1`. Its packing helper converts
one-octet units to consecutive five-bit signals. National-use and non-text
signal rows remain explicit and are not assigned invented Unicode characters.

The ITA2 aliases are `ITA-2`, `CCITT-2`, `CCITT2`, `BAUDOT`, `BAUDOT-CODE`,
`CCITT-NO-2`, and `INTERNATIONAL-TELEGRAPH-ALPHABET-NO-2`.
`Iconvex.Telecom.ITA2.Packing` converts the unpacked octets to or from
consecutive five-bit units without adding padding.

`ITA2-S2` aliases are `ITA2-S.2`, `ITA-2-S2`, `CCITT-S.2`, `ITU-T-S.2`, and
`CASE-PRESERVING-ITA2`. It uses the same five-bit packing as ITA2 but assigns
normative mode semantics to contiguous FS/LS sequences so case survives.

`ITA2-US-TTY` aliases are `US-TTY`, `USTTY`, `US-BAUDOT`, and
`AMERICAN-TELETYPEWRITER-CODE`. It ports all United States figures positions.
`MTK-2` aliases are `MKT-2`, `RUSSIAN-BAUDOT`, `CYRILLIC-ITA2`, and
`RUSSIAN-ITA2`; its Latin, Russian, and figures registers are independently
selectable.

`ITA3` aliases include `ITA-3`, `CCITT-3`, `CCITT-NO-3`, `ITU-T-S.13`, and
`INTERNATIONAL-TELEGRAPH-ALPHABET-NO-3`. `ITA4` has the corresponding
`ITA-4`, `CCITT-4`, `CCITT-NO-4`, `ITU-T-R.44`, and full alphabet name.
Both expose all 32 ITA2 traffic conversions and keep protocol service signals
outside Unicode text. Their packing helpers emit exact consecutive fields.

`ITU-T-T.50-IRV` aliases include `ITU-T-T.50`, `T.50-IRV`, `T50-IRV`, `IRA`,
`IA5`, `ITA5`, `ITA-5`, `CCITT-5`, `CCITT5`, `CCITT-NO-5`, and
`ISO-646-IRV:1991`, plus the full International Alphabet No. 5 and historical
Recommendation V.3 names. It is the in-force 128-position IRV with a separate
exact seven-bit packing helper.

`MORSE-ITU-M1677` aliases are `INTERNATIONAL-MORSE`,
`INTERNATIONAL-MORSE-CODE`, `ITU-R-M.1677-1`, `ITU-R-M.1677`, and
`MORSE-CODE`. M.1677 specifies signals and timing rather than octets, so this
codec defines a lossless ASCII envelope: dots and dashes form a signal, one
space separates characters, and the standalone `/` token represents a text
space. Procedural signals are exposed separately rather than mapped to
invented Unicode characters.

`CCIR476` aliases are `CCIR-476`, `CCIR_476`, `SITOR`, `SITOR-B`, `NAVTEX`,
and `ITU-R-M.476-5`. Its packing API emits consecutive seven-bit units; the
codec also exposes the six service signals and the collective-FEC polarity
inversion defined by M.476-5.

`AIS6` aliases are `AIS-6BIT`, `AIS-6-BIT`, `AIS-6BIT-ASCII`,
`ITU-R-M.1371-6`, and `ITU-R-M.1371`. `Iconvex.Telecom.AIS6.Packing` handles
consecutive six-bit fields. `Iconvex.Telecom.AIS6.Armor` separately handles
the printable AIVDM/AIVDO payload alphabet and its zero fill-bit count.

The IBM tables expose all 64 six-bit units and reject every octet with either
high bit set. They are separate because unit `0x0C` is U+2311 in GA27-3005-3
and U+003C in GA27-3004-2. Only publication-qualified aliases are registered;
generic `TRANSCODE`, `SIX-BIT-TRANSCODE`, and `IBM-TRANSCODE` names remain
unclaimed. The standard packed order follows the 2780 manual's `543210`
low-order-first wire statement. Explicit `-PACKED-LSB` and `-PACKED-MSB`
inventory names keep both transports discoverable.

The 2780 profile aliases are `IBM-2780-SIX-BIT-TRANSCODE-1971`,
`IBM-2780-TRANSCODE-1971`, and `IBM-GA27-3005-3-TRANSCODE`. The BSC profile
aliases are `IBM-BSC-SIX-BIT-TRANSCODE-1970` and
`IBM-GA27-3004-2-TRANSCODE`.

`TBCD` aliases are `TELEPHONY-BCD`, `3GPP-TBCD`, and `GSM-TBCD`.
`SIM-ALPHA-IDENTIFIER` aliases are `SIM-ALPHA`, `USIM-ALPHA`,
`USIM-ALPHA-IDENTIFIER`, and `SIM-UCS2-80-81-82`. Both remain available through
their field-oriented helper modules as well as ordinary `Iconvex.convert/4`.
SIM helper, one-shot codec, and Stream paths all enforce the complete 255-octet
record boundary and preserve an earlier in-record diagnostic over later excess
bytes.

## GSM 03.38

All GSM codecs use the one-septet-per-octet representation commonly used by
SMPP.

| Encoding | Locking table | Single-shift table |
|---|---|---|
| `GSM0338` | default | default |
| `GSM0338-TURKISH` | Turkish | Turkish |
| `GSM0338-SPANISH` | default | Spanish |
| `GSM0338-PORTUGUESE` | Portuguese | Portuguese |
| `GSM0338-BENGALI` | Bengali | Bengali |
| `GSM0338-GUJARATI` | Gujarati | Gujarati |
| `GSM0338-HINDI` | Hindi | Hindi |
| `GSM0338-KANNADA` | Kannada | Kannada |
| `GSM0338-MALAYALAM` | Malayalam | Malayalam |
| `GSM0338-ORIYA` | Oriya | Oriya |
| `GSM0338-PUNJABI` | Punjabi | Punjabi |
| `GSM0338-TAMIL` | Tamil | Tamil |
| `GSM0338-TELUGU` | Telugu | Telugu |
| `GSM0338-URDU` | Urdu | Urdu |
| `GSM0338-LOCKING-TURKISH` | Turkish | default |
| `GSM0338-LOCKING-PORTUGUESE` | Portuguese | default |
| `GSM0338-LOCKING-BENGALI` | Bengali | default |
| `GSM0338-LOCKING-GUJARATI` | Gujarati | default |
| `GSM0338-LOCKING-HINDI` | Hindi | default |
| `GSM0338-LOCKING-KANNADA` | Kannada | default |
| `GSM0338-LOCKING-MALAYALAM` | Malayalam | default |
| `GSM0338-LOCKING-ORIYA` | Oriya | default |
| `GSM0338-LOCKING-PUNJABI` | Punjabi | default |
| `GSM0338-LOCKING-TAMIL` | Tamil | default |
| `GSM0338-LOCKING-TELUGU` | Telugu | default |
| `GSM0338-LOCKING-URDU` | Urdu | default |
| `GSM0338-SINGLE-TURKISH` | default | Turkish |
| `GSM0338-SINGLE-SPANISH` | default | Spanish |
| `GSM0338-SINGLE-PORTUGUESE` | default | Portuguese |
| `GSM0338-SINGLE-BENGALI` | default | Bengali |
| `GSM0338-SINGLE-GUJARATI` | default | Gujarati |
| `GSM0338-SINGLE-HINDI` | default | Hindi |
| `GSM0338-SINGLE-KANNADA` | default | Kannada |
| `GSM0338-SINGLE-MALAYALAM` | default | Malayalam |
| `GSM0338-SINGLE-ORIYA` | default | Oriya |
| `GSM0338-SINGLE-PUNJABI` | default | Punjabi |
| `GSM0338-SINGLE-TAMIL` | default | Tamil |
| `GSM0338-SINGLE-TELUGU` | default | Telugu |
| `GSM0338-SINGLE-URDU` | default | Urdu |

`GSM0338` aliases: `GSM-03.38`, `GSM-03.38-2009`, `GSM7`, `GSM-7`, and
`SMPP-GSM7`. Each other codec also accepts the equivalent `GSM-03.38-...`
spelling.

The 39 names cover the base encoding, 13 convenient same-language profiles,
12 locking-only tables, and 13 single-shift-only tables. For all other
locking/single combinations use `Iconvex.Telecom.GSM0338` with options; all 182
valid combinations are supported.
