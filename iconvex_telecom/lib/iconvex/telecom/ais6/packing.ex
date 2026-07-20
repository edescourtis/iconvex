defmodule Iconvex.Telecom.AIS6.Packing do
  @moduledoc "Packs and unpacks consecutive ITU-R M.1371 six-bit character values."

  @doc "Packs one-six-bit-value-per-octet input into consecutive fields."
  def pack(units) when is_binary(units), do: pack_loop(units, 0, [])

  @doc "Unpacks a bitstring whose size is an exact multiple of six."
  def unpack(packed) when is_bitstring(packed) do
    if rem(bit_size(packed), 6) == 0 do
      {:ok, for(<<unit::6 <- packed>>, into: <<>>, do: <<unit>>)}
    else
      {:error, :incomplete_sequence, div(bit_size(packed), 6), packed}
    end
  end

  defp pack_loop(<<>>, _offset, acc),
    do: {:ok, acc |> :lists.reverse() |> :erlang.list_to_bitstring()}

  defp pack_loop(<<unit, _rest::binary>>, offset, _acc) when unit > 63,
    do: {:error, :invalid_sequence, offset, <<unit>>}

  defp pack_loop(<<unit, rest::binary>>, offset, acc),
    do: pack_loop(rest, offset + 1, [<<unit::6>> | acc])
end
