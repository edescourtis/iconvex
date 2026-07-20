defmodule Iconvex.Specs.IBM17354 do
  @moduledoc """
  IBM CCSID 17354: ASCII CP367 in G0 and KSC X5601-1989 CP971 in G1,
  under IBM encoding scheme 5404 (ISO 2022 TCP/IP using ESC sequences).
  """

  use Iconvex.Codec

  @profile %{designation: <<0x1B, "$)C">>, table_id: :icu_archive_735}

  @impl true
  def canonical_name, do: "IBM-17354"

  @impl true
  def aliases, do: ["IBM17354", "CP17354", "CCSID17354"]

  @impl true
  def codec_id, do: :ibm_17354

  @impl true
  def stateful?, do: true

  @impl true
  def decode(input), do: Iconvex.Specs.ISO2022G1.decode(input, @profile, false)

  @impl true
  def decode_discard(input), do: Iconvex.Specs.ISO2022G1.decode(input, @profile, true)

  @impl true
  def decode_to_utf8(input), do: Iconvex.Specs.ISO2022G1.decode_to_utf8(input, @profile)

  @impl true
  def encode(codepoints), do: Iconvex.Specs.ISO2022G1.encode(codepoints, @profile, false)

  @impl true
  def encode_discard(codepoints), do: Iconvex.Specs.ISO2022G1.encode(codepoints, @profile, true)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: Iconvex.Specs.ISO2022G1.encode_substitute(codepoints, @profile, replacer)

  @impl true
  def encode_from_utf8(input), do: Iconvex.Specs.ISO2022G1.encode_from_utf8(input, @profile)
end
