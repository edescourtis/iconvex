defmodule Iconvex.Specs.ICUEBCDICStateful.Engine do
  @moduledoc false

  alias Iconvex.Tables

  @shift_out 0x0E
  @shift_in 0x0F

  def decode(id, input) when is_binary(input),
    do: decode_loop(input, table(id), :sbcs, 0, [])

  def decode_discard(id, input) when is_binary(input),
    do: decode_discard_loop(input, table(id), :sbcs, [])

  def encode(id, codepoints) when is_list(codepoints),
    do: encode_loop(codepoints, table(id), :sbcs, [])

  def encode_discard(id, codepoints) when is_list(codepoints),
    do: encode_discard_loop(codepoints, table(id), :sbcs, [])

  def encode_substitute(id, codepoints, replacer)
      when is_list(codepoints) and is_function(replacer, 1),
      do: encode_substitute_loop(codepoints, [], false, table(id), :sbcs, [], replacer)

  def decode_to_utf8(id, input) do
    case decode(id, input) do
      {:ok, codepoints} -> {:ok, List.to_string(codepoints)}
      error -> error
    end
  end

  def encode_from_utf8(id, input) when is_binary(input) do
    case :unicode.characters_to_list(input, :utf8) do
      codepoints when is_list(codepoints) ->
        case encode(id, codepoints) do
          {:error, kind, codepoint} -> {:encode_error, kind, codepoint}
          result -> result
        end

      {:incomplete, converted, rest} ->
        utf8_error(id, converted, :incomplete_sequence, input, rest)

      {:error, converted, rest} ->
        utf8_error(id, converted, :invalid_sequence, input, rest)
    end
  end

  defp decode_loop(<<>>, _table, _mode, _offset, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_loop(<<@shift_out, rest::binary>>, table, _mode, offset, acc),
    do: decode_loop(rest, table, :dbcs, offset + 1, acc)

  defp decode_loop(<<@shift_in, rest::binary>>, table, _mode, offset, acc),
    do: decode_loop(rest, table, :sbcs, offset + 1, acc)

  defp decode_loop(<<byte, rest::binary>>, table, :sbcs, offset, acc) do
    case elem(table.sbcs_decode, byte) do
      nil -> {:error, :invalid_sequence, offset, <<byte>>}
      codepoints -> decode_loop(rest, table, :sbcs, offset + 1, prepend(codepoints, acc))
    end
  end

  defp decode_loop(<<byte>>, _table, :dbcs, offset, _acc),
    do: {:error, :incomplete_sequence, offset, <<byte>>}

  defp decode_loop(<<first, second, rest::binary>>, table, :dbcs, offset, acc) do
    bytes = <<first, second>>

    case Map.fetch(table.dbcs_decode, bytes) do
      {:ok, codepoints} -> decode_loop(rest, table, :dbcs, offset + 2, prepend(codepoints, acc))
      :error -> {:error, :invalid_sequence, offset, bytes}
    end
  end

  defp decode_discard_loop(<<>>, _table, _mode, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_discard_loop(<<@shift_out, rest::binary>>, table, _mode, acc),
    do: decode_discard_loop(rest, table, :dbcs, acc)

  defp decode_discard_loop(<<@shift_in, rest::binary>>, table, _mode, acc),
    do: decode_discard_loop(rest, table, :sbcs, acc)

  defp decode_discard_loop(<<byte, rest::binary>>, table, :sbcs, acc) do
    case elem(table.sbcs_decode, byte) do
      nil -> decode_discard_loop(rest, table, :sbcs, acc)
      codepoints -> decode_discard_loop(rest, table, :sbcs, prepend(codepoints, acc))
    end
  end

  defp decode_discard_loop(<<_byte>>, _table, :dbcs, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_discard_loop(<<first, second, rest::binary>>, table, :dbcs, acc) do
    case Map.fetch(table.dbcs_decode, <<first, second>>) do
      {:ok, codepoints} -> decode_discard_loop(rest, table, :dbcs, prepend(codepoints, acc))
      :error -> decode_discard_loop(rest, table, :dbcs, acc)
    end
  end

  defp encode_loop([], _table, mode, acc), do: {:ok, encoded_result(acc, mode)}

  defp encode_loop(codepoints, table, mode, acc) do
    case encoded(codepoints, table) do
      nil ->
        {:error, :unrepresentable_character, hd(codepoints)}

      {count, next_mode, bytes} ->
        encode_loop(Enum.drop(codepoints, count), table, next_mode, [
          shifted(mode, next_mode, bytes) | acc
        ])
    end
  end

  defp encode_discard_loop([], _table, mode, acc), do: {:ok, encoded_result(acc, mode)}

  defp encode_discard_loop(codepoints, table, mode, acc) do
    case encoded(codepoints, table) do
      nil ->
        encode_discard_loop(tl(codepoints), table, mode, acc)

      {count, next_mode, bytes} ->
        encode_discard_loop(
          Enum.drop(codepoints, count),
          table,
          next_mode,
          [shifted(mode, next_mode, bytes) | acc]
        )
    end
  end

  defp encode_substitute_loop([], [], false, _table, mode, acc, _replacer),
    do: {:ok, encoded_result(acc, mode)}

  defp encode_substitute_loop([], resume, true, table, mode, acc, replacer),
    do: encode_substitute_loop(resume, [], false, table, mode, acc, replacer)

  defp encode_substitute_loop(codepoints, resume, substituting?, table, mode, acc, replacer) do
    case encoded(codepoints, table) do
      nil when substituting? ->
        {:error, :unrepresentable_character, hd(codepoints)}

      nil ->
        [codepoint | rest] = codepoints

        encode_substitute_loop(
          replacer.(codepoint),
          rest,
          true,
          table,
          mode,
          acc,
          replacer
        )

      {count, next_mode, bytes} ->
        encode_substitute_loop(
          Enum.drop(codepoints, count),
          resume,
          substituting?,
          table,
          next_mode,
          [shifted(mode, next_mode, bytes) | acc],
          replacer
        )
    end
  end

  defp encoded(codepoints, table),
    do: longest(codepoints, table.encode, available(codepoints, table.max_codepoints))

  defp longest(_codepoints, _encode, 0), do: nil

  defp longest(codepoints, encode, count) do
    key = codepoints |> Enum.take(count) |> List.to_tuple()

    case Map.fetch(encode, key) do
      {:ok, {mode, bytes}} -> {count, mode, bytes}
      :error -> longest(codepoints, encode, count - 1)
    end
  end

  defp shifted(mode, mode, bytes), do: bytes
  defp shifted(:sbcs, :dbcs, bytes), do: <<@shift_out, bytes::binary>>
  defp shifted(:dbcs, :sbcs, bytes), do: <<@shift_in, bytes::binary>>

  defp encoded_result(acc, :sbcs), do: acc |> :lists.reverse() |> IO.iodata_to_binary()

  defp encoded_result(acc, :dbcs),
    do: [<<@shift_in>> | acc] |> :lists.reverse() |> IO.iodata_to_binary()

  defp available(_codepoints, 0), do: 0
  defp available([], _limit), do: 0
  defp available([_ | rest], limit), do: 1 + available(rest, limit - 1)

  defp prepend(tuple, acc), do: tuple |> Tuple.to_list() |> :lists.reverse(acc)
  defp table(id), do: Tables.fetch!(id)

  defp utf8_error(id, converted, kind, input, rest) do
    case encode(id, converted) do
      {:error, encode_kind, codepoint} -> {:encode_error, encode_kind, codepoint}
      {:ok, _prefix} -> {:decode_error, kind, byte_size(input) - byte_size(rest), rest}
    end
  end
end
