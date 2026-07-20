defmodule Iconvex.Specs.DECSIXBIT do
  @moduledoc """
  DECsystem-10 SIXBIT, the six-bit projection of ASCII columns 2 through 5.

  The byte API carries one six-bit unit in each octet. Lowercase input encodes
  to the corresponding uppercase unit, as specified by the source.
  """

  use Iconvex.Codec

  @source_path Path.expand(
                 "../../../priv/sources/ecma1-dec-sixbit/Sze_Introduction_to_DEC_System-10_1974.pdf",
                 __DIR__
               )
  @external_resource @source_path

  @impl true
  def canonical_name, do: "DEC-SIXBIT"

  @impl true
  def aliases, do: ["PDP-10-SIXBIT", "DECSIXBIT"]

  @impl true
  def codec_id, do: :dec_sixbit

  def unit_bits, do: 6
  def source_page, do: 20

  def source_url,
    do: "https://bitsavers.org/pdf/dec/pdp10/Sze_Introduction_to_DEC_System-10_1974.pdf"

  @impl true
  def decode(input) when is_binary(input), do: decode(input, 0, [])

  @impl true
  def decode_discard(input) when is_binary(input), do: decode_discard(input, [])

  @impl true
  def encode(codepoints) when is_list(codepoints), do: encode(codepoints, [])

  @impl true
  def encode_discard(codepoints) when is_list(codepoints), do: encode_discard(codepoints, [])

  @impl true
  def encode_substitute(codepoints, replacer),
    do: Iconvex.Specs.CodecSupport.encode_substitute_each(codepoints, &encode/1, replacer)

  @impl true
  def decode_to_utf8(input) when is_binary(input) do
    case decode(input) do
      {:ok, codepoints} -> {:ok, List.to_string(codepoints)}
      error -> error
    end
  end

  @impl true
  def encode_from_utf8(input) when is_binary(input),
    do: Iconvex.Specs.CodecSupport.encode_utf8(input, &encode/1)

  defp decode(<<>>, _offset, acc), do: {:ok, :lists.reverse(acc)}

  defp decode(<<unit, rest::binary>>, offset, acc) when unit < 64,
    do: decode(rest, offset + 1, [unit + 0x20 | acc])

  defp decode(<<unit, _rest::binary>>, offset, _acc),
    do: {:error, :invalid_sequence, offset, <<unit>>}

  defp decode_discard(<<>>, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_discard(<<unit, rest::binary>>, acc) when unit < 64,
    do: decode_discard(rest, [unit + 0x20 | acc])

  defp decode_discard(<<_unit, rest::binary>>, acc), do: decode_discard(rest, acc)

  defp encode([], acc), do: {:ok, acc |> :lists.reverse() |> :erlang.list_to_binary()}

  defp encode([codepoint | rest], acc) when codepoint in 0x20..0x5F,
    do: encode(rest, [codepoint - 0x20 | acc])

  defp encode([codepoint | rest], acc) when codepoint in ?a..?z,
    do: encode(rest, [codepoint - 0x40 | acc])

  defp encode([codepoint | _rest], _acc),
    do: {:error, :unrepresentable_character, codepoint}

  defp encode_discard([], acc),
    do: {:ok, acc |> :lists.reverse() |> :erlang.list_to_binary()}

  defp encode_discard([codepoint | rest], acc) when codepoint in 0x20..0x5F,
    do: encode_discard(rest, [codepoint - 0x20 | acc])

  defp encode_discard([codepoint | rest], acc) when codepoint in ?a..?z,
    do: encode_discard(rest, [codepoint - 0x40 | acc])

  defp encode_discard([_codepoint | rest], acc), do: encode_discard(rest, acc)
end
