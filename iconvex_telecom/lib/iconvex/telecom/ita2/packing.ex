defmodule Iconvex.Telecom.ITA2.Packing do
  @moduledoc """
  Packs and unpacks ITA2 signal elements as consecutive five-bit units.

  Packed data is returned as a bitstring with exactly five bits per input
  octet. No implicit octet padding is added, so the original unit count is
  unambiguous.
  """

  @doc "Packs unpacked ITA2 octets into consecutive five-bit units."
  def pack(units) when is_binary(units), do: pack_units(units, 0, [])

  @doc "Unpacks consecutive five-bit units into one unit per octet."
  def unpack(packed) when is_bitstring(packed) do
    if rem(bit_size(packed), 5) == 0 do
      {:ok, for(<<unit::5 <- packed>>, into: <<>>, do: <<unit>>)}
    else
      {:error, :incomplete_sequence, div(bit_size(packed), 5), packed}
    end
  end

  defp pack_units(<<>>, _offset, acc),
    do: {:ok, acc |> :lists.reverse() |> :erlang.list_to_bitstring()}

  defp pack_units(<<unit, _rest::binary>>, offset, _acc) when unit > 31,
    do: {:error, :invalid_sequence, offset, <<unit>>}

  defp pack_units(<<unit, rest::binary>>, offset, acc),
    do: pack_units(rest, offset + 1, [<<unit::5>> | acc])
end
