defmodule Iconvex.Telecom.GSM0338.Packing do
  @moduledoc """
  Packs and unpacks GSM 7-bit septets for SMS TPDU user data.

  Input and output septets use the unpacked one-septet-per-octet representation.
  `fill_bits` aligns text that follows a user-data header.
  """

  import Bitwise

  def pack(septets, options \\ []) when is_binary(septets) do
    with {:ok, fill_bits} <- fill_bits(options),
         :ok <- validate_septets(septets, 0) do
      count = byte_size(septets)

      if count == 0 do
        {:ok, <<>>}
      else
        value = pack_integer(septets, fill_bits, 0)
        octets = div(fill_bits + count * 7 + 7, 8)
        {:ok, <<value::little-unsigned-integer-size(octets)-unit(8)>>}
      end
    end
  end

  def unpack(packed, septet_count, options \\ [])

  def unpack(packed, septet_count, options)
      when is_binary(packed) and is_integer(septet_count) and septet_count >= 0 do
    with {:ok, fill_bits} <- fill_bits(options),
         :ok <- ensure_bits(packed, septet_count, fill_bits) do
      if septet_count == 0 do
        {:ok, <<>>}
      else
        value = :binary.decode_unsigned(packed, :little) >>> fill_bits
        {:ok, unpack_integer(value, septet_count, [])}
      end
    end
  end

  def unpack(_packed, septet_count, _options),
    do: {:error, {:invalid_septet_count, septet_count}}

  # `udh_length` is the TP-UDHL value and therefore excludes its own octet.
  def fill_bits_for_udh(udh_length) when is_integer(udh_length) and udh_length in 0..255 do
    rem(7 - rem((udh_length + 1) * 8, 7), 7)
  end

  def fill_bits_for_udh(value), do: {:error, {:invalid_udh_octets, value}}

  defp fill_bits(options) when is_list(options) do
    value = Keyword.get(options, :fill_bits, 0)

    if Keyword.keyword?(options) and Keyword.keys(options) -- [:fill_bits] == [] and value in 0..6,
      do: {:ok, value},
      else: {:error, {:invalid_fill_bits, value}}
  end

  defp fill_bits(_options), do: {:error, :options_must_be_a_keyword_list}

  defp validate_septets(<<>>, _offset), do: :ok

  defp validate_septets(<<septet, rest::binary>>, offset) when septet < 128,
    do: validate_septets(rest, offset + 1)

  defp validate_septets(<<septet, _rest::binary>>, offset),
    do: {:error, {:invalid_septet, offset, septet}}

  defp pack_integer(<<>>, _shift, value), do: value

  defp pack_integer(<<septet, rest::binary>>, shift, value) do
    pack_integer(rest, shift + 7, value ||| septet <<< shift)
  end

  defp unpack_integer(_value, 0, acc), do: acc |> Enum.reverse() |> :erlang.list_to_binary()

  defp unpack_integer(value, count, acc) do
    unpack_integer(value >>> 7, count - 1, [value &&& 0x7F | acc])
  end

  defp ensure_bits(packed, count, fill_bits) do
    if count == 0 or bit_size(packed) >= fill_bits + count * 7,
      do: :ok,
      else: {:error, :insufficient_bits}
  end
end
