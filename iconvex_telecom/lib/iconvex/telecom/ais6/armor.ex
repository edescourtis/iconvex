defmodule Iconvex.Telecom.AIS6.Armor do
  @moduledoc """
  IEC 61162 AIVDM/AIVDO printable payload armoring for AIS six-bit values.

  This transport alphabet is distinct from the ITU-R M.1371-6 Table 45 text
  alphabet. `encode_bits/1` and `decode_bits/2` also handle the sentence's
  declared zero fill bits.
  """

  alias Iconvex.Telecom.AIS6.Packing

  @doc "Armors one-six-bit-value-per-octet data as printable payload bytes."
  def encode(units) when is_binary(units), do: encode_loop(units, 0, [])

  @doc "Decodes printable payload bytes into one six-bit value per octet."
  def decode(payload) when is_binary(payload), do: decode_loop(payload, 0, [])

  @doc "Pads an arbitrary bitstring with zero bits and returns payload plus fill count."
  def encode_bits(bits) when is_bitstring(bits) do
    fill_bits = rem(6 - rem(bit_size(bits), 6), 6)
    padded = <<bits::bitstring, 0::size(fill_bits)>>
    units = for <<unit::6 <- padded>>, into: <<>>, do: <<unit>>

    case encode(units) do
      {:ok, payload} -> {:ok, payload, fill_bits}
      error -> error
    end
  end

  @doc "Decodes payload armoring and removes the declared trailing zero fill bits."
  def decode_bits(payload, fill_bits)
      when is_binary(payload) and is_integer(fill_bits) and fill_bits in 0..5 do
    with {:ok, units} <- decode(payload),
         {:ok, packed} <- Packing.pack(units) do
      remove_fill_bits(packed, fill_bits)
    end
  end

  def decode_bits(payload, _fill_bits) when is_binary(payload),
    do: {:error, :invalid_fill_bits}

  defp encode_loop(<<>>, _offset, acc),
    do: {:ok, acc |> :lists.reverse() |> :erlang.list_to_binary()}

  defp encode_loop(<<unit, _rest::binary>>, offset, _acc) when unit > 63,
    do: {:error, :invalid_sequence, offset, <<unit>>}

  defp encode_loop(<<unit, rest::binary>>, offset, acc) do
    byte = if unit <= 39, do: unit + 48, else: unit + 56
    encode_loop(rest, offset + 1, [byte | acc])
  end

  defp decode_loop(<<>>, _offset, acc),
    do: {:ok, acc |> :lists.reverse() |> :erlang.list_to_binary()}

  defp decode_loop(<<byte, rest::binary>>, offset, acc) when byte in 48..87,
    do: decode_loop(rest, offset + 1, [byte - 48 | acc])

  defp decode_loop(<<byte, rest::binary>>, offset, acc) when byte in 96..119,
    do: decode_loop(rest, offset + 1, [byte - 56 | acc])

  defp decode_loop(<<byte, _rest::binary>>, offset, _acc),
    do: {:error, :invalid_sequence, offset, <<byte>>}

  defp remove_fill_bits(packed, 0), do: {:ok, packed}

  defp remove_fill_bits(packed, fill_bits) when bit_size(packed) < fill_bits,
    do: {:error, :invalid_fill_bits}

  defp remove_fill_bits(packed, fill_bits) do
    payload_size = bit_size(packed) - fill_bits
    <<payload::bitstring-size(payload_size), padding::size(fill_bits)>> = packed

    if padding == 0, do: {:ok, payload}, else: {:error, :nonzero_fill_bits}
  end
end
