defmodule Iconvex.Specs.IBMUnicodeCCSIDs do
  @moduledoc "IBM CCSIDs that ICU classifies as byte-identical UTF-16BE."

  @ibm_source_sha256 "d0682e71d66de77bd518cda1e82377474bdb78cd6dd87b0c17cbccdc25c67dfb"

  def ibm_source_sha256, do: @ibm_source_sha256

  def decode(input), do: Iconvex.UnicodeCodec.decode(%{id: :utf16be}, input)

  def decode_discard(input) when is_binary(input), do: decode_discard(input, [])

  def decode_to_utf8(input) do
    case decode(input) do
      {:ok, codepoints} -> {:ok, List.to_string(codepoints)}
      error -> error
    end
  end

  def encode(codepoints), do: Iconvex.UnicodeCodec.encode(%{id: :utf16be}, codepoints)

  def encode_discard(codepoints),
    do: Iconvex.UnicodeCodec.encode_discard(%{id: :utf16be}, codepoints)

  def encode_substitute(codepoints, replacer),
    do: Iconvex.UnicodeCodec.encode_substitute(%{id: :utf16be}, codepoints, replacer)

  def encode_from_utf8(input) when is_binary(input) do
    case :unicode.characters_to_list(input, :utf8) do
      codepoints when is_list(codepoints) ->
        case encode(codepoints) do
          {:error, :unrepresentable_character, codepoint} ->
            {:encode_error, :unrepresentable_character, codepoint}

          result ->
            result
        end

      {:incomplete, _converted, rest} ->
        {:decode_error, :incomplete_sequence, byte_size(input) - byte_size(rest), rest}

      {:error, _converted, rest} ->
        {:decode_error, :invalid_sequence, byte_size(input) - byte_size(rest), rest}
    end
  end

  defp decode_discard(<<>>, acc), do: {:ok, :lists.reverse(acc)}
  defp decode_discard(<<_byte>>, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_discard(<<high::16-big, low::16-big, rest::binary>>, acc)
       when high in 0xD800..0xDBFF and low in 0xDC00..0xDFFF do
    codepoint = 0x10000 + Bitwise.bsl(high - 0xD800, 10) + low - 0xDC00
    decode_discard(rest, [codepoint | acc])
  end

  defp decode_discard(<<unit::16-big, rest::binary>>, acc) when unit in 0xD800..0xDFFF,
    do: decode_discard(rest, acc)

  defp decode_discard(<<unit::16-big, rest::binary>>, acc),
    do: decode_discard(rest, [unit | acc])
end

defmodule Iconvex.Specs.IBMUnicodeCCSIDs.Codec do
  use Iconvex.Codec

  alias Iconvex.Specs.IBMUnicodeCCSIDs, as: Engine

  @ccsids [
    1200,
    1201,
    13488,
    13489,
    17584,
    17585,
    21680,
    21681,
    25776,
    25777,
    29872,
    29873,
    61955,
    61956
  ]
  @aliases Enum.flat_map(@ccsids, fn ccsid ->
             ["IBM-#{ccsid}", "IBM#{ccsid}", "CCSID#{ccsid}"]
           end) -- ["IBM-1200"]

  @impl true
  def canonical_name, do: "IBM-1200"

  @impl true
  def aliases, do: @aliases

  @impl true
  def codec_id, do: :ibm_utf16be_ccsids

  @impl true
  def decode(input), do: Engine.decode(input)

  @impl true
  def decode_discard(input), do: Engine.decode_discard(input)

  @impl true
  def decode_to_utf8(input), do: Engine.decode_to_utf8(input)

  @impl true
  def encode(codepoints), do: Engine.encode(codepoints)

  @impl true
  def encode_discard(codepoints), do: Engine.encode_discard(codepoints)

  @impl true
  def encode_substitute(codepoints, replacer), do: Engine.encode_substitute(codepoints, replacer)

  @impl true
  def encode_from_utf8(input), do: Engine.encode_from_utf8(input)
end
