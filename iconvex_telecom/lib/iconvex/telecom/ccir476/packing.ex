defmodule Iconvex.Telecom.CCIR476.Packing do
  @moduledoc "Packs and unpacks consecutive CCIR 476 seven-unit signals."

  @doc "Packs one-signal-per-octet input into consecutive seven-bit units."
  def pack(signals) when is_binary(signals), do: pack_loop(signals, 0, [])

  @doc "Unpacks a bitstring whose size is an exact multiple of seven."
  def unpack(packed) when is_bitstring(packed) do
    if rem(bit_size(packed), 7) == 0 do
      {:ok, for(<<signal::7 <- packed>>, into: <<>>, do: <<signal>>)}
    else
      {:error, :incomplete_sequence, div(bit_size(packed), 7), packed}
    end
  end

  defp pack_loop(<<>>, _offset, acc),
    do: {:ok, acc |> :lists.reverse() |> :erlang.list_to_bitstring()}

  defp pack_loop(<<signal, _rest::binary>>, offset, _acc) when signal > 127,
    do: {:error, :invalid_sequence, offset, <<signal>>}

  defp pack_loop(<<signal, rest::binary>>, offset, acc),
    do: pack_loop(rest, offset + 1, [<<signal::7>> | acc])
end
