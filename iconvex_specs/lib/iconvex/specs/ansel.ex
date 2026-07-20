defmodule Iconvex.Specs.ANSEL do
  @moduledoc "ANSI/NISO Z39.47 ANSEL in its ASCII plus Extended Latin environment."

  use Iconvex.Codec

  alias Iconvex.Specs.MARC8

  @impl true
  def canonical_name, do: "ANSEL"

  @impl true
  def aliases, do: ["Z39.47", "ANSI-Z39.47", "csANSEL"]

  @impl true
  def codec_id, do: :ansel

  @impl true
  def decode(input) when is_binary(input), do: MARC8.decode_mode(input, :ansel)

  @impl true
  def decode_discard(input) when is_binary(input), do: MARC8.decode_discard_mode(input, :ansel)

  @impl true
  def encode(codepoints) when is_list(codepoints), do: MARC8.encode_mode(codepoints, :ansel)

  @impl true
  def encode_discard(codepoints) when is_list(codepoints),
    do: MARC8.encode_discard_mode(codepoints, :ansel)

  @impl true
  def encode_substitute(codepoints, replacer) when is_list(codepoints),
    do: MARC8.encode_substitute_mode(codepoints, :ansel, replacer)

  @impl true
  def decode_to_utf8(input) do
    with {:ok, codepoints} <- decode(input), do: {:ok, List.to_string(codepoints)}
  end

  @impl true
  def encode_from_utf8(input) when is_binary(input),
    do: Iconvex.Specs.CodecSupport.encode_utf8(input, &encode/1)
end
