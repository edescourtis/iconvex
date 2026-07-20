defmodule Iconvex.Telecom.FiveUnitShift do
  @moduledoc false

  def decode(input, config) when is_binary(input) do
    mode = config.initial
    decode_loop(input, mode, Map.fetch!(config.decode, mode), config.decode, config.shifts, 0, [])
  end

  def decode_discard(input, config) when is_binary(input) do
    mode = config.initial

    decode_discard_loop(
      input,
      mode,
      Map.fetch!(config.decode, mode),
      config.decode,
      config.shifts,
      []
    )
  end

  def decode_to_utf8(input, config) when is_binary(input) do
    with {:ok, codepoints} <- decode(input, config), do: {:ok, List.to_string(codepoints)}
  end

  def encode(codepoints, config) when is_list(codepoints) do
    mode = config.initial
    encode_loop(codepoints, mode, Map.fetch!(config.encode, mode), config, [], false)
  end

  def encode_discard(codepoints, config) when is_list(codepoints) do
    mode = config.initial
    encode_loop(codepoints, mode, Map.fetch!(config.encode, mode), config, [], true)
  end

  def encode_from_utf8(input, config) when is_binary(input) do
    case :unicode.characters_to_list(input, :utf8) do
      codepoints when is_list(codepoints) ->
        case encode(codepoints, config) do
          {:error, kind, codepoint} -> {:encode_error, kind, codepoint}
          result -> result
        end

      {:incomplete, converted, rest} ->
        utf8_error(converted, :incomplete_sequence, input, rest, config)

      {:error, converted, rest} ->
        utf8_error(converted, :invalid_sequence, input, rest, config)
    end
  end

  defp decode_loop(<<>>, _mode, _table, _tables, _shifts, _offset, acc),
    do: {:ok, :lists.reverse(acc)}

  defp decode_loop(<<byte, _rest::binary>>, _mode, _table, _tables, _shifts, offset, _acc)
       when byte > 31,
       do: {:error, :invalid_sequence, offset, <<byte>>}

  defp decode_loop(<<byte, rest::binary>>, mode, table, tables, shifts, offset, acc) do
    case shifts do
      %{^byte => next_mode} ->
        decode_loop(
          rest,
          next_mode,
          Map.fetch!(tables, next_mode),
          tables,
          shifts,
          offset + 1,
          acc
        )

      _ ->
        case elem(table, byte) do
          nil ->
            {:error, :invalid_sequence, offset, <<byte>>}

          codepoint ->
            decode_loop(rest, mode, table, tables, shifts, offset + 1, [codepoint | acc])
        end
    end
  end

  defp decode_discard_loop(<<>>, _mode, _table, _tables, _shifts, acc),
    do: {:ok, :lists.reverse(acc)}

  defp decode_discard_loop(<<byte, rest::binary>>, mode, table, tables, shifts, acc)
       when byte > 31,
       do: decode_discard_loop(rest, mode, table, tables, shifts, acc)

  defp decode_discard_loop(<<byte, rest::binary>>, mode, table, tables, shifts, acc) do
    case shifts do
      %{^byte => next_mode} ->
        decode_discard_loop(
          rest,
          next_mode,
          Map.fetch!(tables, next_mode),
          tables,
          shifts,
          acc
        )

      _ ->
        case elem(table, byte) do
          nil ->
            decode_discard_loop(rest, mode, table, tables, shifts, acc)

          codepoint ->
            decode_discard_loop(rest, mode, table, tables, shifts, [codepoint | acc])
        end
    end
  end

  defp encode_loop([], _mode, _table, _config, acc, _discard?),
    do: {:ok, binary_result(acc)}

  defp encode_loop([codepoint | rest], mode, table, config, acc, discard?) do
    case encoded(codepoint, mode, table, config) do
      {:ok, bytes, next_mode, next_table} ->
        encode_loop(rest, next_mode, next_table, config, [bytes | acc], discard?)

      :error when discard? ->
        encode_loop(rest, mode, table, config, acc, true)

      :error ->
        {:error, :unrepresentable_character, codepoint}
    end
  end

  defp encoded(codepoint, mode, table, config) do
    case table do
      %{^codepoint => code} ->
        {:ok, code, mode, table}

      _ ->
        encoded_in_another_mode(codepoint, config)
    end
  end

  defp encoded_in_another_mode(codepoint, config) do
    case config.search do
      %{^codepoint => {mode, code}} ->
        table = Map.fetch!(config.encode, mode)
        {:ok, <<Map.fetch!(config.shift_codes, mode), code>>, mode, table}

      _ ->
        encoded_alias(codepoint, config)
    end
  end

  defp encoded_alias(codepoint, config) do
    case config.aliases do
      %{^codepoint => {mode, code}} ->
        table = Map.fetch!(config.encode, mode)
        {:ok, <<Map.fetch!(config.shift_codes, mode), code>>, mode, table}

      _ ->
        :error
    end
  end

  defp utf8_error(converted, kind, input, rest, config) do
    case encode(converted, config) do
      {:error, encode_kind, codepoint} -> {:encode_error, encode_kind, codepoint}
      {:ok, _prefix} -> {:decode_error, kind, byte_size(input) - byte_size(rest), rest}
    end
  end

  defp binary_result(acc), do: acc |> :lists.reverse() |> IO.iodata_to_binary()
end
