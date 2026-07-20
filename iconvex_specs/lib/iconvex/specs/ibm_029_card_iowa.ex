defmodule Iconvex.Specs.IBM029CardIowa824E61A9 do
  @moduledoc """
  Content-addressed logical 12-bit reconstruction of the IBM 029 table in
  Douglas W. Jones's University of Iowa punched-card survey.

  The Iowa diagram renders both no-punch and `0-8-2` as blank. Encoding uses
  no-punch canonically; strict decoding also accepts `0-8-2` as a decode-only
  blank alias. The digest prefix in every public name prevents this secondary
  reconstruction from claiming an unqualified IBM 029 identity.
  """

  @external_resource Path.expand(
                       "../../../priv/sources/punched-card-codes/ibm_029_card_iowa_824e61a9.csv",
                       __DIR__
                     )

  use Iconvex.Specs.PunchedCard.Profile,
    canonical: "IBM-029-CARD-IOWA-824E61A9",
    aliases: ["IBM-029-PUNCHED-CARD-IOWA-824E61A9"],
    mappings: [
      {0x20, 0x000},
      {0x26, 0x800},
      {0x2D, 0x400},
      {0x30, 0x200},
      {0x31, 0x100},
      {0x32, 0x080},
      {0x33, 0x040},
      {0x34, 0x020},
      {0x35, 0x010},
      {0x36, 0x008},
      {0x37, 0x004},
      {0x38, 0x002},
      {0x39, 0x001},
      {0x41, 0x900},
      {0x42, 0x880},
      {0x43, 0x840},
      {0x44, 0x820},
      {0x45, 0x810},
      {0x46, 0x808},
      {0x47, 0x804},
      {0x48, 0x802},
      {0x49, 0x801},
      {0x4A, 0x500},
      {0x4B, 0x480},
      {0x4C, 0x440},
      {0x4D, 0x420},
      {0x4E, 0x410},
      {0x4F, 0x408},
      {0x50, 0x404},
      {0x51, 0x402},
      {0x52, 0x401},
      {0x2F, 0x300},
      {0x53, 0x280},
      {0x54, 0x240},
      {0x55, 0x220},
      {0x56, 0x210},
      {0x57, 0x208},
      {0x58, 0x204},
      {0x59, 0x202},
      {0x5A, 0x201},
      {0x3A, 0x082},
      {0x23, 0x042},
      {0x40, 0x022},
      {0x27, 0x012},
      {0x3D, 0x00A},
      {0x22, 0x006},
      {0xA2, 0x882},
      {0x2E, 0x842},
      {0x3C, 0x822},
      {0x28, 0x812},
      {0x2B, 0x80A},
      {0x7C, 0x806},
      {0x21, 0x482},
      {0x24, 0x442},
      {0x2A, 0x422},
      {0x29, 0x412},
      {0x3B, 0x40A},
      {0xAC, 0x406},
      {0x2C, 0x242},
      {0x25, 0x222},
      {0x5F, 0x212},
      {0x3E, 0x20A},
      {0x3F, 0x206}
    ],
    decode_aliases: [{0x20, 0x282}],
    transports: [
      Iconvex.Specs.IBM029CardIowa824E61A9_16BE,
      Iconvex.Specs.IBM029CardIowa824E61A9_16LE
    ],
    source_sha256: "824e61a9687f7fa0b9c9dd3c966ca02020bf8af1ab6671e9bd2e131f22f47b18",
    source_url: "https://homepage.cs.uiowa.edu/~jones/cards/codes.html",
    source_pages: ["IBM model 029 keypunch section"],
    printed_source_pages: []

  def normalized_mapping_sha256,
    do: "c7a394f8ed6b025b6058a10e23c35036b6b50c8fc70db6da07c9724967c45373"
end

defmodule Iconvex.Specs.IBM029CardIowa824E61A9_16BE do
  @moduledoc """
  `IBM-029-CARD-IOWA-824E61A9` in zero-padded 16-bit big-endian words.
  """

  use Iconvex.Specs.PunchedCard.Transport,
    profile: Iconvex.Specs.IBM029CardIowa824E61A9,
    endian: :big,
    canonical: "IBM-029-CARD-IOWA-824E61A9-16BE",
    aliases: ["IBM-029-PUNCHED-CARD-IOWA-824E61A9-16BE"],
    codec_id: :ibm_029_card_iowa_824e61a9_16be
end

defmodule Iconvex.Specs.IBM029CardIowa824E61A9_16LE do
  @moduledoc """
  `IBM-029-CARD-IOWA-824E61A9` in zero-padded 16-bit little-endian words.
  """

  use Iconvex.Specs.PunchedCard.Transport,
    profile: Iconvex.Specs.IBM029CardIowa824E61A9,
    endian: :little,
    canonical: "IBM-029-CARD-IOWA-824E61A9-16LE",
    aliases: ["IBM-029-PUNCHED-CARD-IOWA-824E61A9-16LE"],
    codec_id: :ibm_029_card_iowa_824e61a9_16le
end
