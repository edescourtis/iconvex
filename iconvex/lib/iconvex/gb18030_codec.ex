defmodule Iconvex.GB18030Codec do
  @moduledoc false
  alias Iconvex.Tables

  def decode(entry, input), do: decode_loop(input, Tables.fetch!(entry.id), 0, [])
  def encode(entry, codepoints), do: encode_loop(codepoints, Tables.fetch!(entry.id), [])

  def encode_discard(entry, codepoints),
    do: encode_discard_loop(codepoints, Tables.fetch!(entry.id), [])

  def encode_substitute(entry, codepoints, replacer) when is_function(replacer, 1),
    do: encode_substitute_loop(codepoints, Tables.fetch!(entry.id), replacer, [])

  @doc false
  def decode_to_explicit_ucs4_discard(entry, input, endian) when endian in [:big, :little] do
    {:ok, decode_to_ucs4_discard(input, Tables.fetch!(entry.id), endian, <<>>)}
  end

  defp decode_loop(<<>>, _table, _offset, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_loop(input, table, offset, acc) do
    case supplementary(input) do
      {:ok, codepoint} ->
        <<_::binary-size(4), rest::binary>> = input
        decode_loop(rest, table, offset + 4, [codepoint | acc])

      :incomplete ->
        {:error, :incomplete_sequence, offset, input}

      :no ->
        decode_table(input, table, offset, acc)
    end
  end

  defp decode_table(input, table, offset, acc) do
    case input do
      <<byte, rest::binary>> when byte < 0x80 ->
        decode_loop(rest, table, offset + 1, prepend(elem(table.one, byte), acc))

      <<first, second, third, fourth, rest::binary>>
      when (first in 0x81..0x84 or first in 0x90..0xE3) and second in 0x30..0x39 and
             third in 0x81..0xFE and fourth in 0x30..0x39 ->
        bytes = <<first, second, third, fourth>>
        decode_mapped(bytes, rest, table, offset, acc)

      <<first, second, third, fourth, _::binary>>
      when (first in 0x81..0x84 or first in 0x90..0xE3) and second in 0x30..0x39 and
             third in 0x81..0xFE ->
        {:error, :invalid_sequence, offset, <<first, second, third, fourth>>}

      <<first, second, third>>
      when (first in 0x81..0x84 or first in 0x90..0xE3) and second in 0x30..0x39 and
             third in 0x81..0xFE ->
        {:error, :incomplete_sequence, offset, input}

      <<first, second, third, _::binary>>
      when (first in 0x81..0x84 or first in 0x90..0xE3) and second in 0x30..0x39 ->
        {:error, :invalid_sequence, offset, <<first, second, third>>}

      <<first, second, _::binary>>
      when (first in 0x81..0x84 or first in 0x90..0xE3) and second in 0x30..0x39 and
             byte_size(input) < 4 ->
        {:error, :incomplete_sequence, offset, input}

      <<first, second, rest::binary>> when first in 0x81..0xFE ->
        decode_mapped(<<first, second>>, rest, table, offset, acc)

      <<first>> when first in 0x81..0xFE ->
        {:error, :incomplete_sequence, offset, input}

      <<first, _::binary>> ->
        {:error, :invalid_sequence, offset, <<first>>}
    end
  end

  defp decode_mapped(bytes, rest, table, offset, acc) do
    case Map.fetch(table.many, bytes) do
      {:ok, codepoints} ->
        decode_loop(rest, table, offset + byte_size(bytes), prepend(codepoints, acc))

      :error ->
        {:error, :invalid_sequence, offset, bytes}
    end
  end

  defp decode_to_ucs4_discard(<<>>, _table, _endian, acc), do: acc

  defp decode_to_ucs4_discard(input, table, endian, acc) do
    case supplementary(input) do
      {:ok, codepoint} ->
        <<_::binary-size(4), rest::binary>> = input
        decode_to_ucs4_discard(rest, table, endian, append_ucs4(acc, codepoint, endian))

      :incomplete ->
        acc

      :no ->
        decode_table_to_ucs4_discard(input, table, endian, acc)
    end
  end

  defp decode_table_to_ucs4_discard(<<byte, rest::binary>>, table, endian, acc)
       when byte < 0x80 do
    codepoint = table.one |> elem(byte) |> elem(0)
    decode_to_ucs4_discard(rest, table, endian, append_ucs4(acc, codepoint, endian))
  end

  defp decode_table_to_ucs4_discard(
         <<first, second, third, fourth, rest::binary>> = input,
         table,
         endian,
         acc
       )
       when (first in 0x81..0x84 or first in 0x90..0xE3) and second in 0x30..0x39 and
              third in 0x81..0xFE and fourth in 0x30..0x39 do
    decode_mapped_to_ucs4_discard(
      <<first, second, third, fourth>>,
      rest,
      input,
      table,
      endian,
      acc
    )
  end

  defp decode_table_to_ucs4_discard(
         <<first, second, third, _fourth, _::binary>> = input,
         table,
         endian,
         acc
       )
       when (first in 0x81..0x84 or first in 0x90..0xE3) and second in 0x30..0x39 and
              third in 0x81..0xFE do
    drop_invalid_first(input, table, endian, acc)
  end

  defp decode_table_to_ucs4_discard(
         <<first, second, third>>,
         _table,
         _endian,
         acc
       )
       when (first in 0x81..0x84 or first in 0x90..0xE3) and second in 0x30..0x39 and
              third in 0x81..0xFE,
       do: acc

  defp decode_table_to_ucs4_discard(
         <<first, second, _third, _::binary>> = input,
         table,
         endian,
         acc
       )
       when (first in 0x81..0x84 or first in 0x90..0xE3) and second in 0x30..0x39,
       do: drop_invalid_first(input, table, endian, acc)

  defp decode_table_to_ucs4_discard(<<first, second>>, _table, _endian, acc)
       when (first in 0x81..0x84 or first in 0x90..0xE3) and second in 0x30..0x39,
       do: acc

  defp decode_table_to_ucs4_discard(
         <<first, second, rest::binary>> = input,
         table,
         endian,
         acc
       )
       when first in 0x81..0xFE do
    decode_mapped_to_ucs4_discard(<<first, second>>, rest, input, table, endian, acc)
  end

  defp decode_table_to_ucs4_discard(<<first>>, _table, _endian, acc)
       when first in 0x81..0xFE,
       do: acc

  defp decode_table_to_ucs4_discard(input, table, endian, acc),
    do: drop_invalid_first(input, table, endian, acc)

  defp decode_mapped_to_ucs4_discard(bytes, rest, input, table, endian, acc) do
    case Map.fetch(table.many, bytes) do
      {:ok, {codepoint}} ->
        decode_to_ucs4_discard(rest, table, endian, append_ucs4(acc, codepoint, endian))

      :error ->
        drop_invalid_first(input, table, endian, acc)
    end
  end

  defp drop_invalid_first(<<_byte, rest::binary>>, table, endian, acc),
    do: decode_to_ucs4_discard(rest, table, endian, acc)

  defp append_ucs4(acc, codepoint, :big), do: <<acc::binary, codepoint::unsigned-big-32>>

  defp append_ucs4(acc, codepoint, :little),
    do: <<acc::binary, codepoint::unsigned-little-32>>

  defp encode_loop([], _table, acc), do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_loop([codepoint | rest], table, acc) do
    case Map.fetch(table.encode, {codepoint}) do
      {:ok, bytes} ->
        encode_loop(rest, table, [bytes | acc])

      :error when codepoint in 0x10000..0x10FFFF ->
        encode_loop(rest, table, [encode_supplementary(codepoint) | acc])

      :error ->
        {:error, :unrepresentable_character, codepoint}
    end
  end

  defp encode_discard_loop([], _table, acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_discard_loop([codepoint | rest], table, acc) do
    case Map.fetch(table.encode, {codepoint}) do
      {:ok, bytes} ->
        encode_discard_loop(rest, table, [bytes | acc])

      :error when codepoint in 0x10000..0x10FFFF ->
        encode_discard_loop(rest, table, [encode_supplementary(codepoint) | acc])

      :error ->
        encode_discard_loop(rest, table, acc)
    end
  end

  defp encode_substitute_loop([], _table, _replacer, acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_substitute_loop([codepoint | rest], table, replacer, acc) do
    case Map.fetch(table.encode, {codepoint}) do
      {:ok, bytes} ->
        encode_substitute_loop(rest, table, replacer, [bytes | acc])

      :error when codepoint in 0x10000..0x10FFFF ->
        encode_substitute_loop(rest, table, replacer, [encode_supplementary(codepoint) | acc])

      :error ->
        case encode_loop(replacer.(codepoint), table, []) do
          {:ok, replacement} ->
            encode_substitute_loop(rest, table, replacer, [replacement | acc])

          error ->
            error
        end
    end
  end

  defp supplementary(<<first, second, third, fourth, _::binary>>)
       when first in 0x90..0xE3 and second in 0x30..0x39 and third in 0x81..0xFE and
              fourth in 0x30..0x39 do
    index = (((first - 0x90) * 10 + second - 0x30) * 126 + third - 0x81) * 10 + fourth - 0x30
    if index < 0x100000, do: {:ok, 0x10000 + index}, else: :no
  end

  defp supplementary(<<first>>) when first in 0x90..0xE3, do: :incomplete

  defp supplementary(<<first, second>>) when first in 0x90..0xE3 and second in 0x30..0x39,
    do: :incomplete

  defp supplementary(<<first, second, third>>)
       when first in 0x90..0xE3 and second in 0x30..0x39 and third in 0x81..0xFE,
       do: :incomplete

  defp supplementary(_), do: :no

  defp encode_supplementary(codepoint) do
    index = codepoint - 0x10000
    fourth = rem(index, 10) + 0x30
    index = div(index, 10)
    third = rem(index, 126) + 0x81
    index = div(index, 126)
    second = rem(index, 10) + 0x30
    first = div(index, 10) + 0x90
    <<first, second, third, fourth>>
  end

  defp prepend(tuple, acc) when tuple_size(tuple) == 1, do: [elem(tuple, 0) | acc]
  defp prepend(tuple, acc) when tuple_size(tuple) == 2, do: [elem(tuple, 1), elem(tuple, 0) | acc]
  defp prepend(tuple, acc), do: tuple |> Tuple.to_list() |> :lists.reverse(acc)
end
