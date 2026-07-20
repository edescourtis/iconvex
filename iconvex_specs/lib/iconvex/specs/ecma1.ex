defmodule Iconvex.Specs.ECMA1 do
  @moduledoc """
  ECMA-1's primary 1963 six-bit input/output character code.

  The byte API carries one six-bit unit in each octet. Use
  `Iconvex.Specs.Packed` for contiguous MSB- or LSB-first transport.
  At the standard's implementation-dependent choice positions this profile
  uses the first graphic shown in the normative table and `[`, `\\`, `]`.
  """

  use Iconvex.Codec

  @source_path Path.expand(
                 "../../../priv/sources/ecma1-dec-sixbit/ECMA-1_1st_edition_march_1963.pdf",
                 __DIR__
               )
  @external_resource @source_path

  @decode {
    0x20,
    0x09,
    0x0A,
    0x0B,
    0x0C,
    0x0D,
    0x0E,
    0x0F,
    ?(,
    ?),
    ?*,
    ?+,
    ?,,
    ?-,
    ?.,
    ?/,
    ?0,
    ?1,
    ?2,
    ?3,
    ?4,
    ?5,
    ?6,
    ?7,
    ?8,
    ?9,
    ?:,
    ?;,
    ?<,
    ?=,
    ?>,
    ??,
    0x00,
    ?A,
    ?B,
    ?C,
    ?D,
    ?E,
    ?F,
    ?G,
    ?H,
    ?I,
    ?J,
    ?K,
    ?L,
    ?M,
    ?N,
    ?O,
    ?P,
    ?Q,
    ?R,
    ?S,
    ?T,
    ?U,
    ?V,
    ?W,
    ?X,
    ?Y,
    ?Z,
    ?[,
    ?\\,
    ?],
    0x1B,
    0x7F
  }
  @encode @decode |> Tuple.to_list() |> Enum.with_index() |> Map.new()

  @impl true
  def canonical_name, do: "ECMA-1"

  @impl true
  def aliases, do: ["ECMA1", "ECMA-1-PRIMARY", "ECMA-1-6BIT"]

  @impl true
  def codec_id, do: :ecma1

  def unit_bits, do: 6
  def source_page, do: 6

  def source_url,
    do: "https://ecma-international.org/wp-content/uploads/ECMA-1_1st_edition_march_1963.pdf"

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
    with {:ok, codepoints} <- decode(input), do: {:ok, List.to_string(codepoints)}
  end

  @impl true
  def encode_from_utf8(input) when is_binary(input),
    do: Iconvex.Specs.CodecSupport.encode_utf8(input, &encode/1)

  defp decode(<<>>, _offset, acc), do: {:ok, :lists.reverse(acc)}

  defp decode(<<unit, rest::binary>>, offset, acc) when unit < 64,
    do: decode(rest, offset + 1, [elem(@decode, unit) | acc])

  defp decode(<<unit, _rest::binary>>, offset, _acc),
    do: {:error, :invalid_sequence, offset, <<unit>>}

  defp decode_discard(<<>>, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_discard(<<unit, rest::binary>>, acc) when unit < 64,
    do: decode_discard(rest, [elem(@decode, unit) | acc])

  defp decode_discard(<<_unit, rest::binary>>, acc), do: decode_discard(rest, acc)

  defp encode([], acc), do: {:ok, acc |> :lists.reverse() |> :erlang.list_to_binary()}

  defp encode([codepoint | rest], acc) do
    case @encode do
      %{^codepoint => unit} -> encode(rest, [unit | acc])
      _ -> {:error, :unrepresentable_character, codepoint}
    end
  end

  defp encode_discard([], acc),
    do: {:ok, acc |> :lists.reverse() |> :erlang.list_to_binary()}

  defp encode_discard([codepoint | rest], acc) do
    case @encode do
      %{^codepoint => unit} -> encode_discard(rest, [unit | acc])
      _ -> encode_discard(rest, acc)
    end
  end
end
