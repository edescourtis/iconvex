defmodule Iconvex.Telecom.GSM0338.Engine do
  @moduledoc false

  alias Iconvex.Telecom.GSM0338.Tables

  @escape 0x1B

  def decode(input, locking_id, single_id) do
    decode_loop(input, Tables.locking(locking_id), Tables.single_shift(single_id), 0, [])
  end

  def decode_discard(input, locking_id, single_id) do
    decode_discard_loop(input, Tables.locking(locking_id), Tables.single_shift(single_id), [])
  end

  def decode_to_utf8(input, locking_id, single_id) do
    case decode(input, locking_id, single_id) do
      {:ok, codepoints} -> {:ok, List.to_string(codepoints)}
      error -> error
    end
  end

  def encode(codepoints, locking_id, single_id) do
    encode_loop(
      codepoints,
      Tables.locking_encode(locking_id),
      Tables.single_encode(single_id),
      []
    )
  end

  def encode_discard(codepoints, locking_id, single_id) do
    encode_discard_loop(
      codepoints,
      Tables.locking_encode(locking_id),
      Tables.single_encode(single_id),
      []
    )
  end

  def encode_substitute(codepoints, locking_id, single_id, replacer)
      when is_function(replacer, 1) do
    encode_substitute_loop(
      codepoints,
      Tables.locking_encode(locking_id),
      Tables.single_encode(single_id),
      replacer,
      []
    )
  end

  def encode_from_utf8(input, locking_id, single_id) do
    locking = Tables.locking_encode(locking_id)
    single = Tables.single_encode(single_id)

    case :unicode.characters_to_list(input, :utf8) do
      codepoints when is_list(codepoints) ->
        encode_utf8_codepoints(codepoints, locking, single)

      {:incomplete, converted, rest} ->
        encode_prefix_or_utf8_error(
          converted,
          locking,
          single,
          :incomplete_sequence,
          byte_size(input) - byte_size(rest),
          rest
        )

      {:error, converted, rest} ->
        encode_prefix_or_utf8_error(
          converted,
          locking,
          single,
          :invalid_sequence,
          byte_size(input) - byte_size(rest),
          rest
        )
    end
  end

  defp decode_loop(<<>>, _locking, _single, _offset, acc),
    do: {:ok, :lists.reverse(acc)}

  defp decode_loop(<<@escape>>, _locking, _single, _offset, acc),
    do: {:ok, acc |> :lists.reverse([0x20])}

  defp decode_loop(<<@escape, byte, rest::binary>>, locking, single, offset, acc)
       when byte > 0x7F,
       do: decode_loop(<<byte, rest::binary>>, locking, single, offset + 1, [0x20 | acc])

  defp decode_loop(<<@escape, @escape, rest::binary>>, locking, single, offset, acc),
    do: decode_loop(rest, locking, single, offset + 2, [0x20 | acc])

  defp decode_loop(<<@escape, byte, rest::binary>>, locking, single, offset, acc) do
    case elem(single, byte) do
      nil -> decode_loop(<<byte, rest::binary>>, locking, single, offset + 1, [0x20 | acc])
      codepoint -> decode_loop(rest, locking, single, offset + 2, [codepoint | acc])
    end
  end

  defp decode_loop(<<byte, _rest::binary>>, _locking, _single, offset, _acc)
       when byte > 0x7F,
       do: {:error, :invalid_sequence, offset, <<byte>>}

  defp decode_loop(<<byte, rest::binary>>, locking, single, offset, acc),
    do: decode_loop(rest, locking, single, offset + 1, [elem(locking, byte) | acc])

  defp decode_discard_loop(<<>>, _locking, _single, acc),
    do: {:ok, :lists.reverse(acc)}

  defp decode_discard_loop(<<@escape>>, _locking, _single, acc),
    do: {:ok, acc |> :lists.reverse([0x20])}

  defp decode_discard_loop(<<@escape, byte, rest::binary>>, locking, single, acc)
       when byte > 0x7F,
       do: decode_discard_loop(<<byte, rest::binary>>, locking, single, [0x20 | acc])

  defp decode_discard_loop(<<@escape, @escape, rest::binary>>, locking, single, acc),
    do: decode_discard_loop(rest, locking, single, [0x20 | acc])

  defp decode_discard_loop(<<@escape, byte, rest::binary>>, locking, single, acc) do
    case elem(single, byte) do
      nil -> decode_discard_loop(<<byte, rest::binary>>, locking, single, [0x20 | acc])
      codepoint -> decode_discard_loop(rest, locking, single, [codepoint | acc])
    end
  end

  defp decode_discard_loop(<<byte, rest::binary>>, locking, single, acc) when byte > 0x7F,
    do: decode_discard_loop(rest, locking, single, acc)

  defp decode_discard_loop(<<byte, rest::binary>>, locking, single, acc),
    do: decode_discard_loop(rest, locking, single, [elem(locking, byte) | acc])

  defp encode_loop([], _locking, _single, acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_loop([codepoint | rest], locking, single, acc) do
    case encoded(codepoint, locking, single) do
      nil -> {:error, :unrepresentable_character, codepoint}
      bytes -> encode_loop(rest, locking, single, [bytes | acc])
    end
  end

  defp encode_discard_loop([], _locking, _single, acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_discard_loop([codepoint | rest], locking, single, acc) do
    case encoded(codepoint, locking, single) do
      nil -> encode_discard_loop(rest, locking, single, acc)
      bytes -> encode_discard_loop(rest, locking, single, [bytes | acc])
    end
  end

  defp encode_substitute_loop([], _locking, _single, _replacer, acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_substitute_loop([codepoint | rest], locking, single, replacer, acc) do
    case encoded(codepoint, locking, single) do
      nil ->
        case encode_loop(replacer.(codepoint), locking, single, []) do
          {:ok, replacement} ->
            encode_substitute_loop(rest, locking, single, replacer, [replacement | acc])

          {:error, :unrepresentable_character, replacement_codepoint} ->
            {:error, :unrepresentable_character, replacement_codepoint}
        end

      bytes ->
        encode_substitute_loop(rest, locking, single, replacer, [bytes | acc])
    end
  end

  defp encode_utf8_codepoints(codepoints, locking, single) do
    case encode_loop(codepoints, locking, single, []) do
      {:error, kind, codepoint} -> {:encode_error, kind, codepoint}
      result -> result
    end
  end

  defp encode_prefix_or_utf8_error(converted, locking, single, kind, offset, rest) do
    case encode_loop(converted, locking, single, []) do
      {:error, encode_kind, codepoint} -> {:encode_error, encode_kind, codepoint}
      {:ok, _encoded_prefix} -> {:decode_error, kind, offset, rest}
    end
  end

  defp encoded(codepoint, locking, single) do
    case locking do
      %{^codepoint => byte} -> byte
      _ -> Map.get(single, codepoint)
    end
  end
end
