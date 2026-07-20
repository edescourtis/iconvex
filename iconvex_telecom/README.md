# Iconvex Telecom

Pure Elixir telecom encodings for [Iconvex](https://hex.pm/packages/iconvex), supplied through its
external-codec API. Its 54 named codecs include GSM 03.38 / 3GPP TS 23.038
with every national locking and single-shift table; ITA1, ITA2, ITA2-S2,
US-TTY, MTK-2, ITA3, ITA4, IA5/T.50, International Morse, CCIR 476, AIS6, and
two source-qualified IBM Six-Bit Transcode tables; plus 3GPP TBCD and SIM/USIM
alpha identifiers. A unified packed facade covers all 51 fixed-width 5-, 6-,
and 7-bit profiles in both MSB and LSB order;
family helpers retain CCIR FEC polarity and AIS AIVDM/AIVDO payload armoring.

The registered codecs use the unpacked representation used by SMPP: every GSM
septet occupies one octet and its high bit must be zero. TPDU bit-packing is a
separate explicit API because decoding needs a septet count and UDH alignment.

## Installation

Add both packages to `mix.exs`:

```elixir
def deps do
  [
    {:iconvex, "~> 0.1.0"},
    {:iconvex_telecom, "~> 0.1.0"}
  ]
end
```

Starting `:iconvex_telecom` registers all 54 named codecs automatically.
They are installed as one atomic managed set whose cleanup token survives a
supervised Iconvex registry-worker restart. Telecom, Extras, and all Specs
codecs can start in any order; the complete registry has 2,093 unique canonical
names.

The generated full-stack codec comparison at `../ICONVEX_FULL_STACK_SUPPORT.md`
is workspace-level integration evidence for all 2,093 canonical names and GNU
libiconv 1.19. It is intentionally not included in this package artifact; use
the workspace-relative path only from the sibling-package source checkout.

```elixir
Iconvex.convert("€Ğ", "UTF-8", "GSM0338-TURKISH")
# => {:ok, <<0x04, 0x1B, 0x47>>}

Iconvex.convert(<<0x04, 0x1B, 0x47>>, "GSM0338-TURKISH", "UTF-8")
# => {:ok, "€Ğ"}

Iconvex.convert("HELLO 123", "UTF-8", "ITA2")
# => {:ok, <<20, 1, 18, 18, 24, 4, 27, 23, 19, 1>>}

Iconvex.convert("HELLO 123", "UTF-8", "CCIR476")
# => {:ok, <<0x4B, 0x35, 0x53, 0x53, 0x47, 0x1D, 0x36, 0x3A, 0x72, 0x35>>}

Iconvex.convert("AIS 123?", "UTF-8", "AIS6")
# => {:ok, <<1, 9, 19, 32, 49, 50, 51, 63>>}

Iconvex.convert("ABCd", "UTF-8", "ITA2-S2")
# => {:ok, <<27, 31, 3, 25, 14, 31, 9>>}

Iconvex.convert("ABCD", "UTF-8", "IBM-2780-SIX-BIT-TRANSCODE-GA27-3005-3")
# => {:ok, <<1, 2, 3, 4>>}

Iconvex.convert("12345", "UTF-8", "TBCD")
# => {:ok, <<0x21, 0x43, 0xF5>>}

Iconvex.convert(<<0x81, 2, 0x08, 0x41, 0x90>>, "SIM-ALPHA", "UTF-8")
# => {:ok, "AА"}
```

SIM alpha identifiers use a framing-aware incremental decoder. An invalid
UCS-2 unit can be discarded or replaced without losing the leading `0x80`,
`0x81`, or `0x82` mode, reinterpreting the suffix as GSM, or changing callback
position. Conversely, once an invalid first default-alphabet octet is consumed,
recovery commits to GSM mode and never reinterprets later `0x80`/`0x81`/`0x82`
data as a framing header. The same result is guaranteed for one-shot conversion
and every lazy Stream split. Earlier invalid UCS-2 units take precedence over a
later odd tail. A short `0x81`/`0x82` payload reports its empty sequence at physical EOF;
plain discard retains any valid payload prefix without inventing a callback for
the absent byte. Physically present compressed payload errors take precedence
over that later EOF, and a trailing GSM escape reports its own byte when more
payload was declared. In accordance with the 255-octet linear-fixed-record
limit in ETSI TS 102 221 section 8.2, both helper and codec APIs reject a 256th
physical record byte. Streaming state counts consumed octets separately from
pending bytes and guarantees that their sum never exceeds 255; target state is
likewise capped. `SIMAlphaIdentifier.max_bytes/0` and
`SIMAlphaIdentifierCodec.max_bytes/0` expose the limit.

## Independent national tables

3GPP permits the locking and single-shift tables to name different languages.
The low-level API exposes every one of the 182 valid pairings:

```elixir
alias Iconvex.Telecom.GSM0338

options = [locking: :portuguese, single_shift: :bengali]

GSM0338.decode(<<0x04, 0x1B, 0x19>>, options)
# => {:ok, [0x00EA, 0x09E6]}

GSM0338.encode([0x00EA, 0x09E6], options)
# => {:ok, <<0x04, 0x1B, 0x19>>}

GSM0338.valid_pairs() |> length()
# => 182
```

Locking choices are `:default`, `:turkish`, `:portuguese`, `:bengali`,
`:gujarati`, `:hindi`, `:kannada`, `:malayalam`, `:oriya`, `:punjabi`,
`:tamil`, `:telugu`, and `:urdu`.

Single-shift choices contain the same set plus `:spanish`. Spanish has no
locking table in 3GPP, so `GSM0338-SPANISH` combines the default locking table
with the Spanish single-shift table.

`decode_utf8/2` and `encode_utf8/2` are the fastest direct paths. Ordinary
`Iconvex.convert/4` calls equivalent codec fast paths automatically.

See [SUPPORTED_ENCODINGS.md](SUPPORTED_ENCODINGS.md),
[SUPPORTED_CODEC_INVENTORY.csv](SUPPORTED_CODEC_INVENTORY.csv),
[CONFORMANCE.md](CONFORMANCE.md), and [BENCHMARKS.md](BENCHMARKS.md).

## Telecom transports

```elixir
alias Iconvex.Telecom.{AIS6, GSM0338.Packing, ITA2, SIMAlphaIdentifier, TBCD}

Packing.pack("hellohello")
# => {:ok, <<0xE8, 0x32, 0x9B, 0xFD, 0x46, 0x97, 0xD9, 0xEC, 0x37>>}

TBCD.encode("12345")
# => {:ok, <<0x21, 0x43, 0xF5>>}

SIMAlphaIdentifier.encode("AА")
# => {:ok, <<0x81, 2, 0x08, 0x41, 0x90>>}

{:ok, ita2_units} = ITA2.encode(~c"HELLO")
ITA2.Packing.pack(ita2_units)
# => {:ok, <<20::5, 1::5, 18::5, 18::5, 24::5>>}

{:ok, ais_units} = AIS6.encode(~c"AIS 123?")
AIS6.Armor.encode(ais_units)
# => {:ok, "19CPijkw"}

{:ok, gsm_packed} =
  Iconvex.Telecom.Packed.encode_from_utf8("hellohello", "GSM0338")

Base.encode16(gsm_packed.data)
# => "E8329BFD4697D9EC37"

Iconvex.Telecom.Packed.decode_to_utf8(gsm_packed, "GSM0338")
# => {:ok, "hellohello"}
```

`Iconvex.Telecom.Packed.profiles/0` is the exact runtime list. Every profile
accepts `:standard`, `:msb`, or `:lsb`; the standard order is explicit in
`SUPPORTED_PACKED_CODEC_INVENTORY.csv`. The facade caches immutable metadata in
`persistent_term`, so hot calls do not rebuild the 51-profile catalog. IBM
Transcode defaults to its documented low-order-first packed transport; callers
can request the explicitly named MSB form through the same facade. Canonical and
alias names ending in `-PACKED-MSB` or `-PACKED-LSB` select that order when the
order argument is omitted; an explicitly conflicting order returns
`{:error, :bit_order_mismatch}`. LSB transports with a non-LSB `bit_order` tag
are rejected with the same typed error. Semantic decode failures from packed
input report physical bit offsets, not offsets in the temporary unpacked byte
buffer. MSB fragments retain their exact bit width; LSB fragments use the
failing unit integer, matching the core packed transport contracts.

## License

Original library code: `LGPL-2.1-or-later`, matching GNU libiconv libraries.
Imported Android/Apache and Unicode fixtures retain upstream licenses; see
`LICENSE.APACHE-2.0`, `LICENSE.UNICODE`, and `NOTICE`.
