defmodule Iconvex.Telecom.IA5.Packing do
  @moduledoc "Packs and unpacks consecutive ITU-T T.50 seven-bit code units."

  @doc "Packs one-seven-bit-unit-per-octet input into consecutive fields."
  def pack(units) when is_binary(units), do: pack_loop(units, 0, [])

  @doc "Unpacks a bitstring whose size is an exact multiple of seven."
  def unpack(packed) when is_bitstring(packed) do
    if rem(bit_size(packed), 7) == 0 do
      {:ok, for(<<unit::7 <- packed>>, into: <<>>, do: <<unit>>)}
    else
      {:error, :incomplete_sequence, div(bit_size(packed), 7), packed}
    end
  end

  defp pack_loop(<<>>, _offset, acc),
    do: {:ok, acc |> :lists.reverse() |> :erlang.list_to_bitstring()}

  defp pack_loop(<<unit, _rest::binary>>, offset, _acc) when unit > 127,
    do: {:error, :invalid_sequence, offset, <<unit>>}

  defp pack_loop(<<unit, rest::binary>>, offset, acc),
    do: pack_loop(rest, offset + 1, [<<unit::7>> | acc])
end
