defmodule Iconvex.Specs.IowaCardProfile do
  @moduledoc false

  defmacro __using__(options) do
    canonical = Keyword.fetch!(options, :canonical)
    aliases = Keyword.fetch!(options, :aliases)
    mapping_file = Keyword.fetch!(options, :mapping_file)
    mapping_sha256 = Keyword.fetch!(options, :mapping_sha256)
    transports = Keyword.fetch!(options, :transports)
    source_pages = Keyword.fetch!(options, :source_pages)

    mapping_path =
      Path.expand(
        "../../../priv/sources/punched-card-codes/#{mapping_file}",
        __DIR__
      )

    mapping_bytes = File.read!(mapping_path)
    actual_mapping_sha256 = sha256(mapping_bytes)

    if actual_mapping_sha256 != mapping_sha256 do
      raise "Iowa punched-card mapping digest changed for #{mapping_file}: " <>
              "#{actual_mapping_sha256}"
    end

    mappings = parse_mappings!(mapping_bytes, mapping_file)

    quote do
      @external_resource unquote(mapping_path)

      use Iconvex.Specs.PunchedCard.Profile,
        canonical: unquote(canonical),
        aliases: unquote(aliases),
        mappings: unquote(Macro.escape(mappings)),
        transports: unquote(transports),
        source_sha256: "824e61a9687f7fa0b9c9dd3c966ca02020bf8af1ab6671e9bd2e131f22f47b18",
        source_url: "https://homepage.cs.uiowa.edu/~jones/cards/codes.html",
        source_pages: unquote(source_pages),
        printed_source_pages: []

      def normalized_mapping_sha256, do: unquote(mapping_sha256)
    end
  end

  defp parse_mappings!(bytes, filename) do
    [header | rows] = String.split(bytes, "\n", trim: true)

    if header != "source_column,codepoint,mask,disposition" or length(rows) != 64 do
      raise "invalid Iowa punched-card mapping shape: #{filename}"
    end

    mappings =
      rows
      |> Enum.with_index()
      |> Enum.map(fn {row, expected_column} ->
        [column, codepoint, mask, "canonical"] = String.split(row, ",")

        if String.to_integer(column) != expected_column do
          raise "non-contiguous Iowa punched-card source column in #{filename}: #{column}"
        end

        {
          codepoint |> String.trim_leading("U+") |> String.to_integer(16),
          mask |> String.trim_leading("0x") |> String.to_integer(16)
        }
      end)

    if mappings |> Enum.map(&elem(&1, 0)) |> Enum.uniq() |> length() != 64 or
         mappings |> Enum.map(&elem(&1, 1)) |> Enum.uniq() |> length() != 64 do
      raise "Iowa punched-card mapping is not one-to-one: #{filename}"
    end

    mappings
  end

  defp sha256(bytes), do: :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)
end

defmodule Iconvex.Specs.DEC026CardIowa824E61A9 do
  @moduledoc """
  Content-addressed logical 12-bit reconstruction of the `DEC6` row in
  Douglas W. Jones's University of Iowa punched-card survey.

  The page attributes the row to the 1972 DEC Small Computer Handbook but
  warns that the underlying handbook may contain typographical errors. The
  `IOWA-824E61A9` identity therefore names only this exact pinned secondary
  artifact, not a generic DEC 026 standard.
  """

  use Iconvex.Specs.IowaCardProfile,
    canonical: "DEC-026-CARD-IOWA-824E61A9",
    aliases: ["DEC-026-PUNCHED-CARD-IOWA-824E61A9"],
    mapping_file: "dec_026_card_iowa_824e61a9.csv",
    mapping_sha256: "b5e4bd965af2c72f2b643e2681792e2c39d5dc25819268181f74f2cac94cc5d4",
    transports: [
      Iconvex.Specs.DEC026CardIowa824E61A9_16BE,
      Iconvex.Specs.DEC026CardIowa824E61A9_16LE
    ],
    source_pages: ["Digital Equipment Corporation section; DEC6 table"]
end

defmodule Iconvex.Specs.DEC026CardIowa824E61A9_16BE do
  @moduledoc "DEC-026-CARD-IOWA-824E61A9 in zero-padded 16-bit big-endian words."

  use Iconvex.Specs.PunchedCard.Transport,
    profile: Iconvex.Specs.DEC026CardIowa824E61A9,
    endian: :big,
    canonical: "DEC-026-CARD-IOWA-824E61A9-16BE",
    aliases: ["DEC-026-PUNCHED-CARD-IOWA-824E61A9-16BE"],
    codec_id: :dec_026_card_iowa_824e61a9_16be
end

defmodule Iconvex.Specs.DEC026CardIowa824E61A9_16LE do
  @moduledoc "DEC-026-CARD-IOWA-824E61A9 in zero-padded 16-bit little-endian words."

  use Iconvex.Specs.PunchedCard.Transport,
    profile: Iconvex.Specs.DEC026CardIowa824E61A9,
    endian: :little,
    canonical: "DEC-026-CARD-IOWA-824E61A9-16LE",
    aliases: ["DEC-026-PUNCHED-CARD-IOWA-824E61A9-16LE"],
    codec_id: :dec_026_card_iowa_824e61a9_16le
end

defmodule Iconvex.Specs.DEC029CardIowa824E61A9 do
  @moduledoc """
  Content-addressed logical 12-bit reconstruction of the `DEC9` row in
  Douglas W. Jones's University of Iowa punched-card survey.

  The `IOWA-824E61A9` identity binds the complete row to the exact saved
  secondary artifact and does not claim an unqualified DEC 029 identity.
  """

  use Iconvex.Specs.IowaCardProfile,
    canonical: "DEC-029-CARD-IOWA-824E61A9",
    aliases: ["DEC-029-PUNCHED-CARD-IOWA-824E61A9"],
    mapping_file: "dec_029_card_iowa_824e61a9.csv",
    mapping_sha256: "810293f09cc61dc043f122465edb13a85d319f0c5c494882b7e9a715dc5222ba",
    transports: [
      Iconvex.Specs.DEC029CardIowa824E61A9_16BE,
      Iconvex.Specs.DEC029CardIowa824E61A9_16LE
    ],
    source_pages: ["Digital Equipment Corporation section; DEC9 table"]
end

defmodule Iconvex.Specs.DEC029CardIowa824E61A9_16BE do
  @moduledoc "DEC-029-CARD-IOWA-824E61A9 in zero-padded 16-bit big-endian words."

  use Iconvex.Specs.PunchedCard.Transport,
    profile: Iconvex.Specs.DEC029CardIowa824E61A9,
    endian: :big,
    canonical: "DEC-029-CARD-IOWA-824E61A9-16BE",
    aliases: ["DEC-029-PUNCHED-CARD-IOWA-824E61A9-16BE"],
    codec_id: :dec_029_card_iowa_824e61a9_16be
end

defmodule Iconvex.Specs.DEC029CardIowa824E61A9_16LE do
  @moduledoc "DEC-029-CARD-IOWA-824E61A9 in zero-padded 16-bit little-endian words."

  use Iconvex.Specs.PunchedCard.Transport,
    profile: Iconvex.Specs.DEC029CardIowa824E61A9,
    endian: :little,
    canonical: "DEC-029-CARD-IOWA-824E61A9-16LE",
    aliases: ["DEC-029-PUNCHED-CARD-IOWA-824E61A9-16LE"],
    codec_id: :dec_029_card_iowa_824e61a9_16le
end

defmodule Iconvex.Specs.EBCDCardIowa824E61A9 do
  @moduledoc """
  Content-addressed logical 12-bit reconstruction of the `EBCD` row in
  Douglas W. Jones's University of Iowa punched-card survey.

  The page attributes the table to Dik Winter's collection and Electrologica
  use. The public identity consequently names the exact Iowa snapshot rather
  than claiming a generic or vendor-primary EBCD profile.
  """

  use Iconvex.Specs.IowaCardProfile,
    canonical: "EBCD-CARD-IOWA-824E61A9",
    aliases: ["EBCD-PUNCHED-CARD-IOWA-824E61A9"],
    mapping_file: "ebcd_card_iowa_824e61a9.csv",
    mapping_sha256: "1a57f8721c556354d6b3dde76d62ab9fbe6d8e405d4d7bf93e053d989bc4f588",
    transports: [
      Iconvex.Specs.EBCDCardIowa824E61A9_16BE,
      Iconvex.Specs.EBCDCardIowa824E61A9_16LE
    ],
    source_pages: ["IBM model 029 keypunch section; EBCD table"]
end

defmodule Iconvex.Specs.EBCDCardIowa824E61A9_16BE do
  @moduledoc "EBCD-CARD-IOWA-824E61A9 in zero-padded 16-bit big-endian words."

  use Iconvex.Specs.PunchedCard.Transport,
    profile: Iconvex.Specs.EBCDCardIowa824E61A9,
    endian: :big,
    canonical: "EBCD-CARD-IOWA-824E61A9-16BE",
    aliases: ["EBCD-PUNCHED-CARD-IOWA-824E61A9-16BE"],
    codec_id: :ebcd_card_iowa_824e61a9_16be
end

defmodule Iconvex.Specs.EBCDCardIowa824E61A9_16LE do
  @moduledoc "EBCD-CARD-IOWA-824E61A9 in zero-padded 16-bit little-endian words."

  use Iconvex.Specs.PunchedCard.Transport,
    profile: Iconvex.Specs.EBCDCardIowa824E61A9,
    endian: :little,
    canonical: "EBCD-CARD-IOWA-824E61A9-16LE",
    aliases: ["EBCD-PUNCHED-CARD-IOWA-824E61A9-16LE"],
    codec_id: :ebcd_card_iowa_824e61a9_16le
end

defmodule Iconvex.Specs.GE600CardIowa824E61A9 do
  @moduledoc """
  Content-addressed logical 12-bit reconstruction of the GE 600 row in
  Douglas W. Jones's University of Iowa punched-card survey.

  The source explicitly corrects the printed caret at 11-8-2 to an up arrow
  (U+2191) and the printed underscore at 0-8-2 to an assignment/left arrow
  (U+2190). The identity is restricted to the pinned Iowa reconstruction.
  """

  use Iconvex.Specs.IowaCardProfile,
    canonical: "GE-600-CARD-IOWA-824E61A9",
    aliases: ["GE-600-PUNCHED-CARD-IOWA-824E61A9"],
    mapping_file: "ge_600_card_iowa_824e61a9.csv",
    mapping_sha256: "d2e0846ed24df4b20492191a781238fb9e507b0628173ca504091a0c38313c7d",
    transports: [
      Iconvex.Specs.GE600CardIowa824E61A9_16BE,
      Iconvex.Specs.GE600CardIowa824E61A9_16LE
    ],
    source_pages: ["General Electric section; GE table and arrow corrections"]
end

defmodule Iconvex.Specs.GE600CardIowa824E61A9_16BE do
  @moduledoc "GE-600-CARD-IOWA-824E61A9 in zero-padded 16-bit big-endian words."

  use Iconvex.Specs.PunchedCard.Transport,
    profile: Iconvex.Specs.GE600CardIowa824E61A9,
    endian: :big,
    canonical: "GE-600-CARD-IOWA-824E61A9-16BE",
    aliases: ["GE-600-PUNCHED-CARD-IOWA-824E61A9-16BE"],
    codec_id: :ge_600_card_iowa_824e61a9_16be
end

defmodule Iconvex.Specs.GE600CardIowa824E61A9_16LE do
  @moduledoc "GE-600-CARD-IOWA-824E61A9 in zero-padded 16-bit little-endian words."

  use Iconvex.Specs.PunchedCard.Transport,
    profile: Iconvex.Specs.GE600CardIowa824E61A9,
    endian: :little,
    canonical: "GE-600-CARD-IOWA-824E61A9-16LE",
    aliases: ["GE-600-PUNCHED-CARD-IOWA-824E61A9-16LE"],
    codec_id: :ge_600_card_iowa_824e61a9_16le
end
