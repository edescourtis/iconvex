defmodule Iconvex.Telecom.AIS6 do
  @moduledoc """
  AIS six-bit text from ITU-R M.1371-6 Table 45.

  The codec representation is one six-bit character value per octet, with
  the upper two bits required to be zero. Use `Iconvex.Telecom.AIS6.Packing`
  for consecutive six-bit fields and `Iconvex.Telecom.AIS6.Armor` for the
  printable payload representation used by IEC 61162 AIVDM/AIVDO sentences.
  """

  use Iconvex.Telecom.SubstitutionCodec

  @decode_tuple 0..63
                |> Enum.map(fn value -> if value < 32, do: value + 64, else: value end)
                |> List.to_tuple()
  @encode_map 0..63
              |> Map.new(fn value -> {elem(@decode_tuple, value), value} end)

  @impl true
  def canonical_name, do: "AIS6"

  @impl true
  def aliases,
    do: [
      "AIS-6BIT",
      "AIS-6-BIT",
      "AIS-6BIT-ASCII",
      "ITU-R-M.1371-6",
      "ITU-R-M.1371"
    ]

  @impl true
  def stateful?, do: false

  @doc "Returns ITU-R M.1371-6 Table 45 as a six-bit-value-to-codepoint map."
  def table, do: 0..63 |> Map.new(&{&1, elem(@decode_tuple, &1)})

  @impl true
  def decode(input) when is_binary(input), do: decode_loop(input, 0, [])

  @impl true
  def decode_discard(input) when is_binary(input), do: decode_discard_loop(input, [])

  @impl true
  def encode(codepoints) when is_list(codepoints), do: encode_loop(codepoints, [])

  @impl true
  def encode_discard(codepoints) when is_list(codepoints),
    do: encode_discard_loop(codepoints, [])

  @impl true
  def decode_to_utf8(input) when is_binary(input) do
    case decode(input) do
      {:ok, codepoints} -> {:ok, List.to_string(codepoints)}
      error -> error
    end
  end

  @impl true
  def encode_from_utf8(input) when is_binary(input) do
    case :unicode.characters_to_list(input, :utf8) do
      codepoints when is_list(codepoints) ->
        encode_utf8_codepoints(codepoints)

      {:incomplete, converted, rest} ->
        encode_prefix_or_utf8_error(
          converted,
          :incomplete_sequence,
          byte_size(input) - byte_size(rest),
          rest
        )

      {:error, converted, rest} ->
        encode_prefix_or_utf8_error(
          converted,
          :invalid_sequence,
          byte_size(input) - byte_size(rest),
          rest
        )
    end
  end

  defp decode_loop(<<>>, _offset, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_loop(<<byte, _rest::binary>>, offset, _acc) when byte > 63,
    do: {:error, :invalid_sequence, offset, <<byte>>}

  defp decode_loop(<<byte, rest::binary>>, offset, acc),
    do: decode_loop(rest, offset + 1, [elem(@decode_tuple, byte) | acc])

  defp decode_discard_loop(<<>>, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_discard_loop(<<byte, rest::binary>>, acc) when byte > 63,
    do: decode_discard_loop(rest, acc)

  defp decode_discard_loop(<<byte, rest::binary>>, acc),
    do: decode_discard_loop(rest, [elem(@decode_tuple, byte) | acc])

  defp encode_loop([], acc), do: {:ok, acc |> :lists.reverse() |> :erlang.list_to_binary()}

  defp encode_loop([codepoint | rest], acc) do
    case @encode_map do
      %{^codepoint => value} -> encode_loop(rest, [value | acc])
      _ -> {:error, :unrepresentable_character, codepoint}
    end
  end

  defp encode_discard_loop([], acc),
    do: {:ok, acc |> :lists.reverse() |> :erlang.list_to_binary()}

  defp encode_discard_loop([codepoint | rest], acc) do
    case @encode_map do
      %{^codepoint => value} -> encode_discard_loop(rest, [value | acc])
      _ -> encode_discard_loop(rest, acc)
    end
  end

  defp encode_utf8_codepoints(codepoints) do
    case encode(codepoints) do
      {:error, kind, codepoint} -> {:encode_error, kind, codepoint}
      result -> result
    end
  end

  defp encode_prefix_or_utf8_error(converted, kind, offset, rest) do
    case encode(converted) do
      {:error, encode_kind, codepoint} -> {:encode_error, encode_kind, codepoint}
      {:ok, _encoded_prefix} -> {:decode_error, kind, offset, rest}
    end
  end
end
