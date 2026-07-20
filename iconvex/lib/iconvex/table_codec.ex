defmodule Iconvex.TableCodec do
  @moduledoc false
  alias Iconvex.Tables

  @decode_cache_schema {:iconvex_table_decode_cache, 2}
  @dense_cache_kind {:dense_two_byte, 65_536, 1}
  @vietnamese_sparse_cache_kind {:vietnamese_sparse_two_byte, 256, 1}
  @trie_cache_kind {:variable_width_trie, 256, 1}
  @decode_cache_tags [
    :dense_two_byte_decode,
    :vietnamese_sparse_two_byte_decode,
    :variable_width_decode_trie
  ]

  @doc false
  def clear_decode_caches(app, id) when is_atom(app) and is_atom(id) do
    Enum.each(@decode_cache_tags, fn tag ->
      key = {__MODULE__, tag, app, id, 1}

      :global.trans({{{__MODULE__, :cache_build}, key}, self()}, fn ->
        :persistent_term.erase(key)
      end)
    end)

    :ok
  end

  def decode(%{id: id} = entry, input) when id in [:cp1258, :tcvn] do
    table = Tables.fetch!(entry)
    decode_vietnamese(input, table, table.vietnamese_base_bytes, 0, nil, [])
  end

  def decode(entry, input) do
    decode_loop(input, Tables.fetch!(entry), 0, [])
  end

  def decode_discard(entry, input) do
    decode_discard_loop(input, Tables.fetch!(entry), [])
  end

  def decode_chunk(%{id: id} = entry, input, false) when id in [:cp1258, :tcvn] do
    table = Tables.fetch!(entry)
    decode_vietnamese_chunk(input, table, table.vietnamese_base_bytes, 0, [])
  end

  def decode_chunk(entry, input, true) do
    case decode(entry, input) do
      {:ok, codepoints} -> {:ok, codepoints, <<>>}
      error -> error
    end
  end

  def decode_chunk(entry, input, false) do
    table = Tables.fetch!(entry)
    decode_chunk_loop(input, table, 0, [])
  end

  def decode_error_consumption(:incomplete_sequence, sequence) when is_binary(sequence),
    do: max(byte_size(sequence), 1)

  def decode_error_consumption(_kind, _sequence), do: 1

  def encode(entry, codepoints) do
    table = Tables.fetch!(entry)

    if table.max_codepoints == 1,
      do: encode_single_loop(codepoints, table.encode, []),
      else: encode_loop(codepoints, table, [])
  end

  def encode_discard(entry, codepoints) do
    table = Tables.fetch!(entry)

    if table.max_codepoints == 1,
      do: encode_single_discard_loop(codepoints, table.encode, []),
      else: encode_discard_loop(codepoints, table, [])
  end

  def encode_chunk(entry, codepoints, true, policy) do
    result =
      case policy do
        :error -> encode(entry, codepoints)
        :discard -> encode_discard(entry, codepoints)
        {:replace, replacer} -> encode_substitute(entry, codepoints, replacer)
      end

    case result do
      {:ok, output} -> {:ok, output, []}
      error -> error
    end
  end

  def encode_chunk(entry, codepoints, false, policy) do
    table = Tables.fetch!(entry)
    encode_chunk_loop(codepoints, length(codepoints), entry, table, policy, [])
  end

  def encode_substitute(entry, codepoints, replacer) when is_function(replacer, 1) do
    table = Tables.fetch!(entry)

    if table.max_codepoints == 1,
      do: encode_single_substitute_loop(codepoints, table, replacer, []),
      else: encode_substitute_loop(codepoints, table, replacer, [])
  end

  def decode_to_utf8(entry, input) do
    table = Tables.fetch!(entry)

    if table.max_input == 1,
      do: decode_single_to_utf8(input, table.one, 0, []),
      else: :miss
  end

  def encode_from_utf8(entry, input) do
    table = Tables.fetch!(entry)

    if table.max_codepoints == 1,
      do: encode_from_utf8_loop(input, table.encode, 0, []),
      else: :miss
  end

  @doc false
  def encode_from_explicit_ucs4_discard(entry, input, endian)
      when endian in [:big, :little] and rem(byte_size(input), 4) == 0 do
    table = Tables.fetch!(entry)

    case table.max_codepoints do
      1 -> encode_single_from_ucs4_discard(input, table.encode, endian, [])
      2 -> encode_pair_from_ucs4_discard(input, table.encode, endian, [])
      _other -> :miss
    end
  end

  def encode_from_explicit_ucs4_discard(_entry, _input, _endian), do: :miss

  @doc false
  def decode_single_to_explicit_ucs4_discard(%{id: id} = entry, input, endian)
      when id not in [:cp1258, :tcvn] and endian in [:big, :little] do
    table = Tables.fetch!(entry)

    if table.max_input == 1,
      do: decode_single_to_ucs4_discard(input, table.one, endian, <<>>),
      else: :miss
  end

  def decode_single_to_explicit_ucs4_discard(_entry, _input, _endian), do: :miss

  @doc false
  def decode_to_explicit_ucs4_discard(%{id: :ascii}, input, :big) do
    {:ok,
     for <<byte <- input>>, byte <= 0x7F, into: <<>> do
       <<byte::unsigned-big-32>>
     end}
  end

  def decode_to_explicit_ucs4_discard(%{id: :ascii}, input, :little) do
    {:ok,
     for <<byte <- input>>, byte <= 0x7F, into: <<>> do
       <<byte::unsigned-little-32>>
     end}
  end

  def decode_to_explicit_ucs4_discard(%{id: _id} = entry, input, endian)
      when endian in [:big, :little] do
    {table, table_identity} = Tables.fetch_with_identity!(entry)

    if table.max_input == 1 do
      decode_single_to_ucs4_discard(input, table.one, endian, <<>>)
    else
      case vietnamese_sparse_two_byte_decode(entry, table, table_identity) do
        root when is_tuple(root) ->
          decode_with_vietnamese_sparse_cache(
            input,
            entry,
            table,
            table_identity,
            root,
            endian
          )

        :unsupported ->
          decode_with_multibyte_cache(input, entry, table, table_identity, endian)
      end
    end
  end

  def decode_to_explicit_ucs4_discard(_entry, _input, _endian), do: :miss

  defp decode_loop(<<>>, _table, _offset, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_loop(input, table, offset, acc) do
    case longest_binary(input, table.many, min(byte_size(input), table.max_input)) do
      {bytes, codepoints} ->
        size = byte_size(bytes)
        <<_::binary-size(size), rest::binary>> = input
        decode_loop(rest, table, offset + size, prepend(codepoints, acc))

      nil ->
        <<byte, rest::binary>> = input

        case elem(table.one, byte) do
          nil ->
            kind =
              if MapSet.member?(table.prefixes, input),
                do: :incomplete_sequence,
                else: :invalid_sequence

            {:error, kind, offset, binary_part(input, 0, min(byte_size(input), table.max_input))}

          codepoints ->
            decode_loop(rest, table, offset + 1, prepend(codepoints, acc))
        end
    end
  end

  defp decode_chunk_loop(<<>>, _table, _offset, acc),
    do: {:ok, :lists.reverse(acc), <<>>}

  defp decode_chunk_loop(input, table, _offset, acc)
       when byte_size(input) < table.max_input,
       do: {:ok, :lists.reverse(acc), input}

  defp decode_chunk_loop(input, table, offset, acc) do
    case longest_binary(input, table.many, min(byte_size(input), table.max_input)) do
      {bytes, codepoints} ->
        size = byte_size(bytes)
        <<_::binary-size(size), rest::binary>> = input
        decode_chunk_loop(rest, table, offset + size, prepend(codepoints, acc))

      nil ->
        <<byte, rest::binary>> = input

        case elem(table.one, byte) do
          nil ->
            {:error, :invalid_sequence, offset,
             binary_part(input, 0, min(byte_size(input), table.max_input))}

          codepoints ->
            decode_chunk_loop(rest, table, offset + 1, prepend(codepoints, acc))
        end
    end
  end

  defp decode_discard_loop(<<>>, _table, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_discard_loop(input, table, acc) do
    case longest_binary(input, table.many, min(byte_size(input), table.max_input)) do
      {bytes, codepoints} ->
        size = byte_size(bytes)
        <<_::binary-size(size), rest::binary>> = input
        decode_discard_loop(rest, table, prepend(codepoints, acc))

      nil ->
        <<byte, rest::binary>> = input

        case elem(table.one, byte) do
          nil ->
            if MapSet.member?(table.prefixes, input),
              do: {:ok, :lists.reverse(acc)},
              else: decode_discard_loop(rest, table, acc)

          codepoints ->
            decode_discard_loop(rest, table, prepend(codepoints, acc))
        end
    end
  end

  defp decode_vietnamese(<<>>, _table, _bases, _offset, nil, acc),
    do: {:ok, :lists.reverse(acc)}

  defp decode_vietnamese(<<>>, _table, _bases, _offset, {_byte, codepoint}, acc),
    do: {:ok, :lists.reverse([codepoint | acc])}

  defp decode_vietnamese(
         <<byte, rest::binary>> = input,
         table,
         bases,
         offset,
         {base_byte, base_codepoint},
         acc
       ) do
    case Map.fetch(table.many, <<base_byte, byte>>) do
      {:ok, codepoints} when tuple_size(codepoints) == 1 ->
        decode_vietnamese(rest, table, bases, offset + 1, nil, [elem(codepoints, 0) | acc])

      _ ->
        decode_vietnamese(input, table, bases, offset, nil, [base_codepoint | acc])
    end
  end

  defp decode_vietnamese(<<byte, rest::binary>>, table, bases, offset, nil, acc) do
    case elem(table.one, byte) do
      nil ->
        {:error, :invalid_sequence, offset, <<byte>>}

      codepoints ->
        codepoint = elem(codepoints, 0)

        if MapSet.member?(bases, byte) do
          decode_vietnamese(rest, table, bases, offset + 1, {byte, codepoint}, acc)
        else
          decode_vietnamese(rest, table, bases, offset + 1, nil, [codepoint | acc])
        end
    end
  end

  defp decode_vietnamese_chunk(<<>>, _table, _bases, _offset, acc),
    do: {:ok, :lists.reverse(acc), <<>>}

  defp decode_vietnamese_chunk(<<byte>>, table, bases, offset, acc) do
    case elem(table.one, byte) do
      nil ->
        {:error, :invalid_sequence, offset, <<byte>>}

      codepoints ->
        if MapSet.member?(bases, byte) do
          {:ok, :lists.reverse(acc), <<byte>>}
        else
          {:ok, codepoints |> prepend(acc) |> :lists.reverse(), <<>>}
        end
    end
  end

  defp decode_vietnamese_chunk(
         <<byte, next, rest::binary>>,
         table,
         bases,
         offset,
         acc
       ) do
    case elem(table.one, byte) do
      nil ->
        {:error, :invalid_sequence, offset, <<byte>>}

      codepoints ->
        if MapSet.member?(bases, byte) do
          case Map.fetch(table.many, <<byte, next>>) do
            {:ok, composed} when tuple_size(composed) == 1 ->
              decode_vietnamese_chunk(
                rest,
                table,
                bases,
                offset + 2,
                prepend(composed, acc)
              )

            _not_a_composition ->
              decode_vietnamese_chunk(
                <<next, rest::binary>>,
                table,
                bases,
                offset + 1,
                prepend(codepoints, acc)
              )
          end
        else
          decode_vietnamese_chunk(
            <<next, rest::binary>>,
            table,
            bases,
            offset + 1,
            prepend(codepoints, acc)
          )
        end
    end
  end

  defp decode_single_to_utf8(<<>>, _one, _offset, acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp decode_single_to_utf8(<<byte, rest::binary>>, one, offset, acc) do
    case elem(one, byte) do
      nil -> {:error, :invalid_sequence, offset, <<byte>>}
      codepoints -> decode_single_to_utf8(rest, one, offset + 1, [tuple_utf8(codepoints) | acc])
    end
  end

  defp encode_loop([], _table, acc), do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_loop(codepoints, table, acc) do
    case longest_codepoints(
           codepoints,
           table.encode,
           available(codepoints, table.max_codepoints)
         ) do
      {count, bytes} -> encode_loop(Enum.drop(codepoints, count), table, [bytes | acc])
      nil -> {:error, :unrepresentable_character, hd(codepoints)}
    end
  end

  defp encode_chunk_loop([], _count, _entry, _table, _policy, acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary(), []}

  defp encode_chunk_loop(codepoints, count, _entry, table, _policy, acc)
       when count < table.max_codepoints,
       do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary(), codepoints}

  defp encode_chunk_loop(codepoints, count, entry, table, policy, acc) do
    case longest_codepoints(codepoints, table.encode, min(count, table.max_codepoints)) do
      {consumed, bytes} ->
        encode_chunk_loop(
          Enum.drop(codepoints, consumed),
          count - consumed,
          entry,
          table,
          policy,
          [bytes | acc]
        )

      nil ->
        [codepoint | rest] = codepoints

        case stream_replacement(entry, codepoint, policy) do
          {:ok, replacement} ->
            encode_chunk_loop(rest, count - 1, entry, table, policy, [replacement | acc])

          error ->
            error
        end
    end
  end

  defp stream_replacement(_entry, codepoint, :error),
    do: {:error, :unrepresentable_character, codepoint}

  defp stream_replacement(_entry, _codepoint, :discard), do: {:ok, <<>>}

  defp stream_replacement(entry, codepoint, {:replace, replacer}) do
    case encode(entry, replacer.(codepoint)) do
      {:ok, output} -> {:ok, output}
      error -> error
    end
  end

  defp encode_discard_loop([], _table, acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_discard_loop(codepoints, table, acc) do
    case longest_codepoints(
           codepoints,
           table.encode,
           available(codepoints, table.max_codepoints)
         ) do
      {count, bytes} -> encode_discard_loop(Enum.drop(codepoints, count), table, [bytes | acc])
      nil -> encode_discard_loop(tl(codepoints), table, acc)
    end
  end

  defp encode_substitute_loop([], _table, _replacer, acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_substitute_loop(codepoints, table, replacer, acc) do
    case longest_codepoints(
           codepoints,
           table.encode,
           available(codepoints, table.max_codepoints)
         ) do
      {count, bytes} ->
        encode_substitute_loop(Enum.drop(codepoints, count), table, replacer, [bytes | acc])

      nil ->
        [codepoint | rest] = codepoints

        case encode_loop(replacer.(codepoint), table, []) do
          {:ok, replacement} ->
            encode_substitute_loop(rest, table, replacer, [replacement | acc])

          error ->
            error
        end
    end
  end

  defp encode_single_loop([], _map, acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_single_loop([codepoint | rest], map, acc) do
    case Map.fetch(map, {codepoint}) do
      {:ok, bytes} -> encode_single_loop(rest, map, [bytes | acc])
      :error -> {:error, :unrepresentable_character, codepoint}
    end
  end

  defp encode_single_discard_loop([], _map, acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_single_discard_loop([codepoint | rest], map, acc) do
    case Map.fetch(map, {codepoint}) do
      {:ok, bytes} -> encode_single_discard_loop(rest, map, [bytes | acc])
      :error -> encode_single_discard_loop(rest, map, acc)
    end
  end

  defp encode_single_substitute_loop([], _table, _replacer, acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_single_substitute_loop([codepoint | rest], table, replacer, acc) do
    case Map.fetch(table.encode, {codepoint}) do
      {:ok, bytes} ->
        encode_single_substitute_loop(rest, table, replacer, [bytes | acc])

      :error ->
        case encode_single_loop(replacer.(codepoint), table.encode, []) do
          {:ok, replacement} ->
            encode_single_substitute_loop(rest, table, replacer, [replacement | acc])

          error ->
            error
        end
    end
  end

  defp encode_from_utf8_loop(<<>>, _map, _offset, acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_from_utf8_loop(<<codepoint::utf8, rest::binary>>, map, offset, acc) do
    case Map.fetch(map, {codepoint}) do
      {:ok, bytes} ->
        encode_from_utf8_loop(rest, map, offset + utf8_size(codepoint), [bytes | acc])

      :error ->
        {:encode_error, :unrepresentable_character, codepoint}
    end
  end

  defp encode_from_utf8_loop(input, _map, offset, _acc) do
    case :unicode.characters_to_list(input, :utf8) do
      {:incomplete, _converted, rest} ->
        {:decode_error, :incomplete_sequence, offset + byte_size(input) - byte_size(rest), rest}

      {:error, _converted, rest} ->
        {:decode_error, :invalid_sequence, offset + byte_size(input) - byte_size(rest), rest}
    end
  end

  defp encode_single_from_ucs4_discard(<<>>, _map, _endian, acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_single_from_ucs4_discard(
         <<codepoint::unsigned-big-32, rest::binary>>,
         map,
         :big,
         acc
       ) do
    case Map.fetch(map, {codepoint}) do
      {:ok, bytes} -> encode_single_from_ucs4_discard(rest, map, :big, [bytes | acc])
      :error -> encode_single_from_ucs4_discard(rest, map, :big, acc)
    end
  end

  defp encode_single_from_ucs4_discard(
         <<codepoint::unsigned-little-32, rest::binary>>,
         map,
         :little,
         acc
       ) do
    case Map.fetch(map, {codepoint}) do
      {:ok, bytes} -> encode_single_from_ucs4_discard(rest, map, :little, [bytes | acc])
      :error -> encode_single_from_ucs4_discard(rest, map, :little, acc)
    end
  end

  defp encode_pair_from_ucs4_discard(<<>>, _map, _endian, acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_pair_from_ucs4_discard(
         <<first::unsigned-big-32, tail::binary>>,
         map,
         :big,
         acc
       ) do
    case tail do
      <<second::unsigned-big-32, rest::binary>> ->
        case Map.fetch(map, {first, second}) do
          {:ok, bytes} ->
            encode_pair_from_ucs4_discard(rest, map, :big, [bytes | acc])

          :error ->
            encode_pair_single_from_ucs4_discard(first, tail, map, :big, acc)
        end

      <<>> ->
        encode_pair_single_from_ucs4_discard(first, tail, map, :big, acc)
    end
  end

  defp encode_pair_from_ucs4_discard(
         <<first::unsigned-little-32, tail::binary>>,
         map,
         :little,
         acc
       ) do
    case tail do
      <<second::unsigned-little-32, rest::binary>> ->
        case Map.fetch(map, {first, second}) do
          {:ok, bytes} ->
            encode_pair_from_ucs4_discard(rest, map, :little, [bytes | acc])

          :error ->
            encode_pair_single_from_ucs4_discard(first, tail, map, :little, acc)
        end

      <<>> ->
        encode_pair_single_from_ucs4_discard(first, tail, map, :little, acc)
    end
  end

  defp encode_pair_single_from_ucs4_discard(codepoint, rest, map, endian, acc) do
    case Map.fetch(map, {codepoint}) do
      {:ok, bytes} -> encode_pair_from_ucs4_discard(rest, map, endian, [bytes | acc])
      :error -> encode_pair_from_ucs4_discard(rest, map, endian, acc)
    end
  end

  defp decode_single_to_ucs4_discard(<<>>, _one, :big, acc), do: {:ok, acc}

  defp decode_single_to_ucs4_discard(<<byte, rest::binary>>, one, :big, acc) do
    case elem(one, byte) do
      nil ->
        decode_single_to_ucs4_discard(rest, one, :big, acc)

      {codepoint} ->
        decode_single_to_ucs4_discard(
          rest,
          one,
          :big,
          <<acc::binary, codepoint::unsigned-big-32>>
        )

      codepoints ->
        decode_single_to_ucs4_discard(
          rest,
          one,
          :big,
          append_codepoints_to_ucs4(acc, codepoints, :big)
        )
    end
  end

  defp decode_single_to_ucs4_discard(<<>>, _one, :little, acc), do: {:ok, acc}

  defp decode_single_to_ucs4_discard(<<byte, rest::binary>>, one, :little, acc) do
    case elem(one, byte) do
      nil ->
        decode_single_to_ucs4_discard(rest, one, :little, acc)

      {codepoint} ->
        decode_single_to_ucs4_discard(
          rest,
          one,
          :little,
          <<acc::binary, codepoint::unsigned-little-32>>
        )

      codepoints ->
        decode_single_to_ucs4_discard(
          rest,
          one,
          :little,
          append_codepoints_to_ucs4(acc, codepoints, :little)
        )
    end
  end

  defp decode_to_ucs4_discard_loop(<<>>, _table, _endian, acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp decode_to_ucs4_discard_loop(input, table, endian, acc) do
    case longest_binary(input, table.many, min(byte_size(input), table.max_input)) do
      {bytes, codepoints} ->
        size = byte_size(bytes)
        <<_::binary-size(size), rest::binary>> = input

        decode_to_ucs4_discard_loop(
          rest,
          table,
          endian,
          [codepoints_to_ucs4(codepoints, endian) | acc]
        )

      nil ->
        <<byte, rest::binary>> = input

        case elem(table.one, byte) do
          nil ->
            if MapSet.member?(table.prefixes, input) do
              {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}
            else
              decode_to_ucs4_discard_loop(rest, table, endian, acc)
            end

          codepoints ->
            decode_to_ucs4_discard_loop(
              rest,
              table,
              endian,
              [codepoints_to_ucs4(codepoints, endian) | acc]
            )
        end
    end
  end

  defp decode_with_multibyte_cache(input, entry, table, table_identity, endian) do
    case dense_two_byte_decode(entry, table, table_identity) do
      dense when is_tuple(dense) ->
        decode_with_dense_cache(input, entry, table, table_identity, dense, endian)

      :unsupported ->
        case variable_width_decode_trie(entry, table, table_identity) do
          trie when is_tuple(trie) ->
            decode_with_trie_cache(input, entry, table, table_identity, trie, endian)

          :unsupported ->
            decode_to_ucs4_discard_loop(input, table, endian, [])
        end
    end
  end

  # CP1258 and TCVN contain only sparse two-byte Vietnamese compositions. A
  # 256-way sparse root identifies the few bytes that can start a pair before
  # touching a second-level tuple. When neither byte can start a pair, the
  # decoder emits both single-byte mappings in one recursive step. This keeps
  # exact longest-match boundaries while avoiding the 65,536-entry dense
  # lookup and one recursive call per input byte on the small reverse corpus.
  defp decode_with_vietnamese_sparse_cache(
         input,
         entry,
         table,
         table_identity,
         root,
         endian
       ) do
    case decode_vietnamese_sparse_to_ucs4_discard(input, table.one, root, endian) do
      :invalid_cache ->
        repaired =
          repair_vietnamese_sparse_two_byte_decode(
            entry,
            table_identity,
            table,
            root
          )

        case repaired do
          tuple when is_tuple(tuple) ->
            case decode_vietnamese_sparse_to_ucs4_discard(input, table.one, tuple, endian) do
              :invalid_cache ->
                decode_with_multibyte_cache(input, entry, table, table_identity, endian)

              result ->
                result
            end

          :unsupported ->
            decode_with_multibyte_cache(input, entry, table, table_identity, endian)
        end

      result ->
        result
    end
  end

  defp decode_vietnamese_sparse_to_ucs4_discard(input, one, root, :big),
    do: decode_vietnamese_sparse_big(input, one, root, [])

  defp decode_vietnamese_sparse_to_ucs4_discard(input, one, root, :little),
    do: decode_vietnamese_sparse_little(input, one, root, [])

  defp decode_vietnamese_sparse_big(<<>>, _one, _root, acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp decode_vietnamese_sparse_big(<<byte>>, one, root, acc),
    do: decode_vietnamese_sparse_one_big(byte, <<>>, one, root, acc)

  defp decode_vietnamese_sparse_big(<<first, second, rest::binary>>, one, root, acc) do
    case elem(root, first) do
      nil ->
        decode_vietnamese_sparse_no_pair_big(first, second, rest, one, root, acc)

      row when is_tuple(row) and tuple_size(row) == 256 ->
        case elem(row, second) do
          0 ->
            decode_vietnamese_sparse_no_pair_big(first, second, rest, one, root, acc)

          stored when is_integer(stored) and stored in 1..0x1_0000_0000 ->
            decode_vietnamese_sparse_big(
              rest,
              one,
              root,
              [<<stored - 1::unsigned-big-32>> | acc]
            )

          _malformed_stored_value ->
            :invalid_cache
        end

      _malformed_row ->
        :invalid_cache
    end
  end

  defp decode_vietnamese_sparse_no_pair_big(first, second, rest, one, root, acc) do
    case elem(root, second) do
      nil ->
        decode_vietnamese_sparse_two_big(first, second, rest, one, root, acc)

      row when is_tuple(row) and tuple_size(row) == 256 ->
        decode_vietnamese_sparse_one_big(first, <<second, rest::binary>>, one, root, acc)

      _malformed_row ->
        :invalid_cache
    end
  end

  defp decode_vietnamese_sparse_one_big(byte, rest, one, root, acc) do
    case elem(one, byte) do
      nil ->
        decode_vietnamese_sparse_big(rest, one, root, acc)

      {codepoint} when is_integer(codepoint) and codepoint in 0..0xFFFF_FFFF ->
        decode_vietnamese_sparse_big(
          rest,
          one,
          root,
          [<<codepoint::unsigned-big-32>> | acc]
        )

      _unsupported_mapping ->
        :invalid_cache
    end
  end

  defp decode_vietnamese_sparse_two_big(first, second, rest, one, root, acc) do
    case {elem(one, first), elem(one, second)} do
      {nil, nil} ->
        decode_vietnamese_sparse_big(rest, one, root, acc)

      {{first_codepoint}, nil} ->
        decode_vietnamese_sparse_big(
          rest,
          one,
          root,
          [<<first_codepoint::unsigned-big-32>> | acc]
        )

      {nil, {second_codepoint}} ->
        decode_vietnamese_sparse_big(
          rest,
          one,
          root,
          [<<second_codepoint::unsigned-big-32>> | acc]
        )

      {{first_codepoint}, {second_codepoint}} ->
        decode_vietnamese_sparse_big(
          rest,
          one,
          root,
          [
            <<first_codepoint::unsigned-big-32, second_codepoint::unsigned-big-32>>
            | acc
          ]
        )

      _unsupported_mapping ->
        :invalid_cache
    end
  end

  defp decode_vietnamese_sparse_little(<<>>, _one, _root, acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp decode_vietnamese_sparse_little(<<byte>>, one, root, acc),
    do: decode_vietnamese_sparse_one_little(byte, <<>>, one, root, acc)

  defp decode_vietnamese_sparse_little(<<first, second, rest::binary>>, one, root, acc) do
    case elem(root, first) do
      nil ->
        decode_vietnamese_sparse_no_pair_little(first, second, rest, one, root, acc)

      row when is_tuple(row) and tuple_size(row) == 256 ->
        case elem(row, second) do
          0 ->
            decode_vietnamese_sparse_no_pair_little(first, second, rest, one, root, acc)

          stored when is_integer(stored) and stored in 1..0x1_0000_0000 ->
            decode_vietnamese_sparse_little(
              rest,
              one,
              root,
              [<<stored - 1::unsigned-little-32>> | acc]
            )

          _malformed_stored_value ->
            :invalid_cache
        end

      _malformed_row ->
        :invalid_cache
    end
  end

  defp decode_vietnamese_sparse_no_pair_little(first, second, rest, one, root, acc) do
    case elem(root, second) do
      nil ->
        decode_vietnamese_sparse_two_little(first, second, rest, one, root, acc)

      row when is_tuple(row) and tuple_size(row) == 256 ->
        decode_vietnamese_sparse_one_little(first, <<second, rest::binary>>, one, root, acc)

      _malformed_row ->
        :invalid_cache
    end
  end

  defp decode_vietnamese_sparse_one_little(byte, rest, one, root, acc) do
    case elem(one, byte) do
      nil ->
        decode_vietnamese_sparse_little(rest, one, root, acc)

      {codepoint} when is_integer(codepoint) and codepoint in 0..0xFFFF_FFFF ->
        decode_vietnamese_sparse_little(
          rest,
          one,
          root,
          [<<codepoint::unsigned-little-32>> | acc]
        )

      _unsupported_mapping ->
        :invalid_cache
    end
  end

  defp decode_vietnamese_sparse_two_little(first, second, rest, one, root, acc) do
    case {elem(one, first), elem(one, second)} do
      {nil, nil} ->
        decode_vietnamese_sparse_little(rest, one, root, acc)

      {{first_codepoint}, nil} ->
        decode_vietnamese_sparse_little(
          rest,
          one,
          root,
          [<<first_codepoint::unsigned-little-32>> | acc]
        )

      {nil, {second_codepoint}} ->
        decode_vietnamese_sparse_little(
          rest,
          one,
          root,
          [<<second_codepoint::unsigned-little-32>> | acc]
        )

      {{first_codepoint}, {second_codepoint}} ->
        decode_vietnamese_sparse_little(
          rest,
          one,
          root,
          [
            <<first_codepoint::unsigned-little-32, second_codepoint::unsigned-little-32>>
            | acc
          ]
        )

      _unsupported_mapping ->
        :invalid_cache
    end
  end

  # Cache records carry the table generation's O(1) identity and a versioned
  # artifact-kind sentinel, while these lookup checks fail closed if a
  # same-shape value is corrupted after publication. Validation stays
  # proportional to the one mapping being consumed rather than scanning the
  # 65,536-entry artifact on every warm conversion.
  defp decode_with_dense_cache(input, entry, table, table_identity, dense, endian) do
    case decode_dense_two_byte_to_ucs4_discard(input, table.one, dense, endian, <<>>) do
      :invalid_cache ->
        repaired = repair_dense_two_byte_decode(entry, table_identity, table.many, dense)

        case repaired do
          tuple when is_tuple(tuple) ->
            case decode_dense_two_byte_to_ucs4_discard(
                   input,
                   table.one,
                   tuple,
                   endian,
                   <<>>
                 ) do
              :invalid_cache -> decode_to_ucs4_discard_loop(input, table, endian, [])
              result -> result
            end

          :unsupported ->
            decode_to_ucs4_discard_loop(input, table, endian, [])
        end

      result ->
        result
    end
  end

  defp decode_dense_two_byte_to_ucs4_discard(<<>>, _one, _dense, _endian, acc),
    do: {:ok, acc}

  defp decode_dense_two_byte_to_ucs4_discard(
         <<first, second, rest::binary>>,
         one,
         dense,
         :big,
         acc
       ) do
    case elem(dense, first * 0x100 + second) do
      0 ->
        decode_dense_two_byte_one(first, <<second, rest::binary>>, one, dense, :big, acc)

      stored when is_integer(stored) and stored in 1..0x1_0000_0000 ->
        decode_dense_two_byte_to_ucs4_discard(
          rest,
          one,
          dense,
          :big,
          <<acc::binary, stored - 1::unsigned-big-32>>
        )

      stored when is_tuple(stored) ->
        case append_cached_codepoints_to_ucs4(acc, stored, :big) do
          {:ok, output} ->
            decode_dense_two_byte_to_ucs4_discard(rest, one, dense, :big, output)

          :error ->
            :invalid_cache
        end

      _malformed_stored_value ->
        :invalid_cache
    end
  end

  defp decode_dense_two_byte_to_ucs4_discard(
         <<first, second, rest::binary>>,
         one,
         dense,
         :little,
         acc
       ) do
    case elem(dense, first * 0x100 + second) do
      0 ->
        decode_dense_two_byte_one(first, <<second, rest::binary>>, one, dense, :little, acc)

      stored when is_integer(stored) and stored in 1..0x1_0000_0000 ->
        decode_dense_two_byte_to_ucs4_discard(
          rest,
          one,
          dense,
          :little,
          <<acc::binary, stored - 1::unsigned-little-32>>
        )

      stored when is_tuple(stored) ->
        case append_cached_codepoints_to_ucs4(acc, stored, :little) do
          {:ok, output} ->
            decode_dense_two_byte_to_ucs4_discard(rest, one, dense, :little, output)

          :error ->
            :invalid_cache
        end

      _malformed_stored_value ->
        :invalid_cache
    end
  end

  defp decode_dense_two_byte_to_ucs4_discard(<<byte>>, one, dense, endian, acc),
    do: decode_dense_two_byte_one(byte, <<>>, one, dense, endian, acc)

  defp decode_dense_two_byte_one(byte, rest, one, dense, :big, acc) do
    case elem(one, byte) do
      nil ->
        decode_dense_two_byte_to_ucs4_discard(rest, one, dense, :big, acc)

      {codepoint} ->
        decode_dense_two_byte_to_ucs4_discard(
          rest,
          one,
          dense,
          :big,
          <<acc::binary, codepoint::unsigned-big-32>>
        )

      codepoints ->
        decode_dense_two_byte_to_ucs4_discard(
          rest,
          one,
          dense,
          :big,
          append_codepoints_to_ucs4(acc, codepoints, :big)
        )
    end
  end

  defp decode_dense_two_byte_one(byte, rest, one, dense, :little, acc) do
    case elem(one, byte) do
      nil ->
        decode_dense_two_byte_to_ucs4_discard(rest, one, dense, :little, acc)

      {codepoint} ->
        decode_dense_two_byte_to_ucs4_discard(
          rest,
          one,
          dense,
          :little,
          <<acc::binary, codepoint::unsigned-little-32>>
        )

      codepoints ->
        decode_dense_two_byte_to_ucs4_discard(
          rest,
          one,
          dense,
          :little,
          append_codepoints_to_ucs4(acc, codepoints, :little)
        )
    end
  end

  defp decode_with_trie_cache(input, entry, table, table_identity, trie, endian) do
    case decode_with_selected_trie(input, entry, table, trie, endian) do
      :invalid_cache ->
        repaired =
          repair_variable_width_decode_trie(entry, table_identity, table.many, trie)

        case repaired do
          tuple when is_tuple(tuple) ->
            case decode_with_selected_trie(input, entry, table, tuple, endian) do
              :invalid_cache -> decode_to_ucs4_discard_loop(input, table, endian, [])
              result -> result
            end

          :unsupported ->
            decode_to_ucs4_discard_loop(input, table, endian, [])
        end

      result ->
        result
    end
  end

  # EUC-JP has 14,889 two- and three-byte mappings. Its exhaustive reverse
  # pass otherwise enters the recursive generic matcher once per mapping (and
  # once per trie level). The generated trie has a fixed maximum depth of
  # three, so an unrolled matcher preserves longest-match and malformed-prefix
  # recovery while removing tens of thousands of recursive calls. A provider
  # that supplies another valid trie shape falls back to the generic matcher;
  # malformed cached nodes still fail closed and trigger the normal repair.
  defp decode_with_selected_trie(
         input,
         %{id: :euc_jp},
         %{max_input: 3, one: one, prefixes: prefixes},
         trie,
         :big
       ),
       do: decode_euc_jp_trie_to_ucs4_big(input, one, prefixes, trie, [])

  defp decode_with_selected_trie(
         input,
         %{id: :euc_jp},
         %{max_input: 3, one: one, prefixes: prefixes},
         trie,
         :little
       ),
       do: decode_euc_jp_trie_to_ucs4_little(input, one, prefixes, trie, [])

  defp decode_with_selected_trie(input, _entry, table, trie, endian) do
    decode_trie_to_ucs4_discard(input, table.one, table.prefixes, trie, endian, [])
  end

  defp decode_euc_jp_trie_to_ucs4_big(<<>>, _one, _prefixes, _trie, acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp decode_euc_jp_trie_to_ucs4_big(input, one, prefixes, trie, acc) do
    case euc_jp_trie_match(input, trie) do
      {:match, stored, rest} ->
        decode_euc_jp_trie_to_ucs4_big(
          rest,
          one,
          prefixes,
          trie,
          [<<stored - 1::unsigned-big-32>> | acc]
        )

      :no_match ->
        <<byte, rest::binary>> = input

        case elem(one, byte) do
          nil ->
            if MapSet.member?(prefixes, input) do
              {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}
            else
              decode_euc_jp_trie_to_ucs4_big(rest, one, prefixes, trie, acc)
            end

          {codepoint} ->
            decode_euc_jp_trie_to_ucs4_big(
              rest,
              one,
              prefixes,
              trie,
              [<<codepoint::unsigned-big-32>> | acc]
            )

          codepoints ->
            decode_euc_jp_trie_to_ucs4_big(
              rest,
              one,
              prefixes,
              trie,
              [codepoints_to_ucs4(codepoints, :big) | acc]
            )
        end

      :generic ->
        decode_trie_to_ucs4_discard(input, one, prefixes, trie, :big, acc)

      :invalid_cache ->
        :invalid_cache
    end
  end

  defp decode_euc_jp_trie_to_ucs4_little(<<>>, _one, _prefixes, _trie, acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp decode_euc_jp_trie_to_ucs4_little(input, one, prefixes, trie, acc) do
    case euc_jp_trie_match(input, trie) do
      {:match, stored, rest} ->
        decode_euc_jp_trie_to_ucs4_little(
          rest,
          one,
          prefixes,
          trie,
          [<<stored - 1::unsigned-little-32>> | acc]
        )

      :no_match ->
        <<byte, rest::binary>> = input

        case elem(one, byte) do
          nil ->
            if MapSet.member?(prefixes, input) do
              {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}
            else
              decode_euc_jp_trie_to_ucs4_little(rest, one, prefixes, trie, acc)
            end

          {codepoint} ->
            decode_euc_jp_trie_to_ucs4_little(
              rest,
              one,
              prefixes,
              trie,
              [<<codepoint::unsigned-little-32>> | acc]
            )

          codepoints ->
            decode_euc_jp_trie_to_ucs4_little(
              rest,
              one,
              prefixes,
              trie,
              [codepoints_to_ucs4(codepoints, :little) | acc]
            )
        end

      :generic ->
        decode_trie_to_ucs4_discard(input, one, prefixes, trie, :little, acc)

      :invalid_cache ->
        :invalid_cache
    end
  end

  defp euc_jp_trie_match(<<_byte>>, _trie), do: :no_match

  defp euc_jp_trie_match(<<first, second, tail::binary>>, trie) do
    case elem(trie, first) do
      nil ->
        :no_match

      {0, second_level} when is_tuple(second_level) and tuple_size(second_level) == 256 ->
        case elem(second_level, second) do
          nil ->
            :no_match

          {0, nil} ->
            :no_match

          {stored, nil} when is_integer(stored) and stored in 1..0x1_0000_0000 ->
            {:match, stored, tail}

          {0, third_level} when is_tuple(third_level) and tuple_size(third_level) == 256 ->
            euc_jp_third_level_match(tail, third_level)

          {stored, next_level}
          when is_integer(stored) and stored in 0..0x1_0000_0000 and
                 (is_nil(next_level) or
                    (is_tuple(next_level) and tuple_size(next_level) == 256)) ->
            :generic

          _malformed_node ->
            :invalid_cache
        end

      {stored, next_level}
      when is_integer(stored) and stored in 0..0x1_0000_0000 and
             (is_nil(next_level) or
                (is_tuple(next_level) and tuple_size(next_level) == 256)) ->
        :generic

      _malformed_node ->
        :invalid_cache
    end
  end

  defp euc_jp_third_level_match(<<>>, _third_level), do: :no_match

  defp euc_jp_third_level_match(<<third, rest::binary>>, third_level) do
    case elem(third_level, third) do
      nil ->
        :no_match

      {0, nil} ->
        :no_match

      {stored, nil} when is_integer(stored) and stored in 1..0x1_0000_0000 ->
        {:match, stored, rest}

      {stored, next_level}
      when is_integer(stored) and stored in 0..0x1_0000_0000 and
             (is_nil(next_level) or
                (is_tuple(next_level) and tuple_size(next_level) == 256)) ->
        :generic

      _malformed_node ->
        :invalid_cache
    end
  end

  defp decode_trie_to_ucs4_discard(<<>>, _one, _prefixes, _trie, _endian, acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp decode_trie_to_ucs4_discard(
         <<byte, rest::binary>> = input,
         one,
         prefixes,
         trie,
         endian,
         acc
       )
       when elem(trie, byte) == nil do
    case elem(one, byte) do
      nil ->
        if MapSet.member?(prefixes, input) do
          {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}
        else
          decode_trie_to_ucs4_discard(rest, one, prefixes, trie, endian, acc)
        end

      codepoints ->
        decode_trie_to_ucs4_discard(
          rest,
          one,
          prefixes,
          trie,
          endian,
          [codepoints_to_ucs4(codepoints, endian) | acc]
        )
    end
  end

  defp decode_trie_to_ucs4_discard(input, one, prefixes, trie, endian, acc) do
    case longest_trie_match(input, trie, 0, nil) do
      :invalid_cache ->
        :invalid_cache

      {consumed, stored} ->
        rest = binary_part(input, consumed, byte_size(input) - consumed)

        decode_trie_to_ucs4_discard(
          rest,
          one,
          prefixes,
          trie,
          endian,
          [ucs4_word(stored - 1, endian) | acc]
        )

      nil ->
        <<byte, rest::binary>> = input

        case elem(one, byte) do
          nil ->
            if MapSet.member?(prefixes, input) do
              {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}
            else
              decode_trie_to_ucs4_discard(rest, one, prefixes, trie, endian, acc)
            end

          codepoints ->
            decode_trie_to_ucs4_discard(
              rest,
              one,
              prefixes,
              trie,
              endian,
              [codepoints_to_ucs4(codepoints, endian) | acc]
            )
        end
    end
  end

  defp longest_trie_match(<<>>, _children, _consumed, best), do: best

  defp longest_trie_match(<<byte, rest::binary>>, children, consumed, best) do
    case elem(children, byte) do
      nil ->
        best

      {stored, nil} when is_integer(stored) and stored in 0..0x1_0000_0000 ->
        if stored == 0, do: best, else: {consumed + 1, stored}

      {stored, next_children}
      when is_integer(stored) and stored in 0..0x1_0000_0000 and
             is_tuple(next_children) and tuple_size(next_children) == 256 ->
        best = if stored == 0, do: best, else: {consumed + 1, stored}
        longest_trie_match(rest, next_children, consumed + 1, best)

      _malformed_node ->
        :invalid_cache
    end
  end

  defp vietnamese_sparse_two_byte_decode(
         %{id: id} = entry,
         table,
         table_identity
       )
       when id in [:cp1258, :tcvn] do
    key = vietnamese_sparse_two_byte_cache_key(entry)

    case :persistent_term.get(key, :missing) do
      {@decode_cache_schema, @vietnamese_sparse_cache_kind, ^table_identity, root}
      when root == :unsupported or (is_tuple(root) and tuple_size(root) == 256) ->
        root

      _missing_or_stale ->
        rebuild_vietnamese_sparse_two_byte_decode(key, table_identity, table)
    end
  end

  defp vietnamese_sparse_two_byte_decode(_entry, _table, _table_identity),
    do: :unsupported

  defp rebuild_vietnamese_sparse_two_byte_decode(key, table_identity, table) do
    :global.trans({{{__MODULE__, :cache_build}, key}, self()}, fn ->
      case :persistent_term.get(key, :missing) do
        {@decode_cache_schema, @vietnamese_sparse_cache_kind, ^table_identity, root}
        when root == :unsupported or (is_tuple(root) and tuple_size(root) == 256) ->
          root

        _missing_stale_or_malformed ->
          root = build_vietnamese_sparse_two_byte_decode(table)

          :persistent_term.put(
            key,
            {@decode_cache_schema, @vietnamese_sparse_cache_kind, table_identity, root}
          )

          root
      end
    end)
  end

  defp repair_vietnamese_sparse_two_byte_decode(
         entry,
         table_identity,
         table,
         invalid_root
       ) do
    key = vietnamese_sparse_two_byte_cache_key(entry)

    :global.trans({{{__MODULE__, :cache_build}, key}, self()}, fn ->
      case :persistent_term.get(key, :missing) do
        {@decode_cache_schema, @vietnamese_sparse_cache_kind, ^table_identity, cached_root}
        when cached_root !== invalid_root and
               (cached_root == :unsupported or
                  (is_tuple(cached_root) and tuple_size(cached_root) == 256)) ->
          cached_root

        _missing_stale_or_malformed ->
          root = build_vietnamese_sparse_two_byte_decode(table)

          :persistent_term.put(
            key,
            {@decode_cache_schema, @vietnamese_sparse_cache_kind, table_identity, root}
          )

          root
      end
    end)
  end

  defp build_vietnamese_sparse_two_byte_decode(%{
         max_input: 2,
         max_codepoints: 1,
         one: one,
         many: many
       })
       when is_tuple(one) and tuple_size(one) == 256 and is_map(many) do
    if valid_single_codepoint_tuple?(one) and
         Enum.all?(many, fn
           {<<_first, _second>>, {codepoint}}
           when is_integer(codepoint) and codepoint in 0..0xFFFF_FFFF ->
             true

           _unsupported_mapping ->
             false
         end) do
      many
      |> Enum.reduce(%{}, fn {<<first, second>>, {codepoint}}, root ->
        Map.update(root, first, %{second => codepoint + 1}, &Map.put(&1, second, codepoint + 1))
      end)
      |> freeze_vietnamese_sparse_root()
    else
      :unsupported
    end
  end

  defp build_vietnamese_sparse_two_byte_decode(_unsupported_table), do: :unsupported

  defp valid_single_codepoint_tuple?(one),
    do: valid_single_codepoint_tuple?(one, 0)

  defp valid_single_codepoint_tuple?(_one, 256), do: true

  defp valid_single_codepoint_tuple?(one, index) do
    case elem(one, index) do
      nil ->
        valid_single_codepoint_tuple?(one, index + 1)

      {codepoint} when is_integer(codepoint) and codepoint in 0..0xFFFF_FFFF ->
        valid_single_codepoint_tuple?(one, index + 1)

      _unsupported_mapping ->
        false
    end
  end

  defp freeze_vietnamese_sparse_root(root) do
    0..0xFF
    |> Enum.map(fn first ->
      case Map.get(root, first) do
        nil ->
          nil

        row ->
          0..0xFF
          |> Enum.map(&Map.get(row, &1, 0))
          |> List.to_tuple()
      end
    end)
    |> List.to_tuple()
  end

  defp dense_two_byte_decode(_entry, %{max_input: max_input}, _table_identity)
       when max_input != 2,
       do: :unsupported

  defp dense_two_byte_decode(entry, table, table_identity) do
    key = dense_two_byte_cache_key(entry)

    case :persistent_term.get(key, :missing) do
      {@decode_cache_schema, @dense_cache_kind, ^table_identity, dense}
      when dense == :unsupported or (is_tuple(dense) and tuple_size(dense) == 65_536) ->
        dense

      _missing_or_stale ->
        rebuild_dense_two_byte_decode(key, table_identity, table.many)
    end
  end

  defp rebuild_dense_two_byte_decode(key, table_identity, many) do
    :global.trans({{{__MODULE__, :cache_build}, key}, self()}, fn ->
      case :persistent_term.get(key, :missing) do
        {@decode_cache_schema, @dense_cache_kind, ^table_identity, dense}
        when dense == :unsupported or
               (is_tuple(dense) and tuple_size(dense) == 65_536) ->
          dense

        _missing_stale_or_malformed ->
          dense = build_dense_two_byte_decode(many)

          :persistent_term.put(
            key,
            {@decode_cache_schema, @dense_cache_kind, table_identity, dense}
          )

          dense
      end
    end)
  end

  defp repair_dense_two_byte_decode(entry, table_identity, many, invalid_dense) do
    key = dense_two_byte_cache_key(entry)

    :global.trans({{{__MODULE__, :cache_build}, key}, self()}, fn ->
      case :persistent_term.get(key, :missing) do
        {@decode_cache_schema, @dense_cache_kind, ^table_identity, cached_dense}
        when cached_dense !== invalid_dense and
               (cached_dense == :unsupported or
                  (is_tuple(cached_dense) and tuple_size(cached_dense) == 65_536)) ->
          cached_dense

        _missing_stale_or_malformed ->
          dense = build_dense_two_byte_decode(many)

          :persistent_term.put(
            key,
            {@decode_cache_schema, @dense_cache_kind, table_identity, dense}
          )

          dense
      end
    end)
  end

  defp build_dense_two_byte_decode(many) do
    if Enum.all?(many, fn {_bytes, codepoints} -> is_tuple(codepoints) end) do
      0..0xFFFF
      |> Enum.map(fn index ->
        first = div(index, 0x100)
        second = rem(index, 0x100)

        case Map.get(many, <<first, second>>) do
          {codepoint} -> codepoint + 1
          codepoints when is_tuple(codepoints) -> codepoints
          nil -> 0
        end
      end)
      |> List.to_tuple()
    else
      :unsupported
    end
  end

  defp variable_width_decode_trie(_entry, %{max_input: max_input}, _table_identity)
       when max_input <= 2,
       do: :unsupported

  defp variable_width_decode_trie(entry, table, table_identity) do
    key = variable_width_decode_trie_cache_key(entry)

    case :persistent_term.get(key, :missing) do
      {@decode_cache_schema, @trie_cache_kind, ^table_identity, trie}
      when trie == :unsupported or (is_tuple(trie) and tuple_size(trie) == 256) ->
        trie

      _missing_or_stale ->
        rebuild_variable_width_decode_trie(key, table_identity, table.many)
    end
  end

  defp rebuild_variable_width_decode_trie(key, table_identity, many) do
    :global.trans({{{__MODULE__, :cache_build}, key}, self()}, fn ->
      case :persistent_term.get(key, :missing) do
        {@decode_cache_schema, @trie_cache_kind, ^table_identity, trie}
        when trie == :unsupported or (is_tuple(trie) and tuple_size(trie) == 256) ->
          trie

        _missing_stale_or_malformed ->
          trie = build_variable_width_decode_trie(many)

          :persistent_term.put(
            key,
            {@decode_cache_schema, @trie_cache_kind, table_identity, trie}
          )

          trie
      end
    end)
  end

  defp repair_variable_width_decode_trie(entry, table_identity, many, invalid_trie) do
    key = variable_width_decode_trie_cache_key(entry)

    :global.trans({{{__MODULE__, :cache_build}, key}, self()}, fn ->
      case :persistent_term.get(key, :missing) do
        {@decode_cache_schema, @trie_cache_kind, ^table_identity, cached_trie}
        when cached_trie !== invalid_trie and
               (cached_trie == :unsupported or
                  (is_tuple(cached_trie) and tuple_size(cached_trie) == 256)) ->
          cached_trie

        _missing_stale_or_malformed ->
          trie = build_variable_width_decode_trie(many)

          :persistent_term.put(
            key,
            {@decode_cache_schema, @trie_cache_kind, table_identity, trie}
          )

          trie
      end
    end)
  end

  defp dense_two_byte_cache_key(entry),
    do: {__MODULE__, :dense_two_byte_decode, table_app(entry), entry.id, 1}

  defp vietnamese_sparse_two_byte_cache_key(entry),
    do: {__MODULE__, :vietnamese_sparse_two_byte_decode, table_app(entry), entry.id, 1}

  defp variable_width_decode_trie_cache_key(entry),
    do: {__MODULE__, :variable_width_decode_trie, table_app(entry), entry.id, 1}

  defp build_variable_width_decode_trie(many) do
    if Enum.all?(many, fn {_bytes, codepoints} -> tuple_size(codepoints) == 1 end) do
      many
      |> Enum.reduce(%{}, fn {bytes, {codepoint}}, trie ->
        insert_decode_trie(trie, bytes, codepoint + 1)
      end)
      |> freeze_decode_trie_root()
    else
      :unsupported
    end
  end

  defp insert_decode_trie(node, <<byte>>, stored) do
    child = node |> Map.get(byte, %{}) |> Map.put(:leaf, stored)
    Map.put(node, byte, child)
  end

  defp insert_decode_trie(node, <<byte, rest::binary>>, stored) do
    child = insert_decode_trie(Map.get(node, byte, %{}), rest, stored)
    Map.put(node, byte, child)
  end

  defp freeze_decode_trie_root(root) do
    {_stored, children} = freeze_decode_trie_node(root)
    children
  end

  defp freeze_decode_trie_node(node) do
    stored = Map.get(node, :leaf, 0)

    children =
      if map_size(node) == if(stored == 0, do: 0, else: 1) do
        nil
      else
        0..0xFF
        |> Enum.map(fn byte ->
          case Map.get(node, byte) do
            nil -> nil
            child -> freeze_decode_trie_node(child)
          end
        end)
        |> List.to_tuple()
      end

    {stored, children}
  end

  defp table_app(%{table_app: app}), do: app
  defp table_app(_entry), do: :iconvex

  defp codepoints_to_ucs4({codepoint}, :big), do: <<codepoint::unsigned-big-32>>
  defp codepoints_to_ucs4({codepoint}, :little), do: <<codepoint::unsigned-little-32>>

  defp codepoints_to_ucs4(codepoints, endian) do
    codepoints
    |> Tuple.to_list()
    |> Enum.map(fn codepoint ->
      case endian do
        :big -> <<codepoint::unsigned-big-32>>
        :little -> <<codepoint::unsigned-little-32>>
      end
    end)
  end

  defp append_codepoints_to_ucs4(acc, {first, second}, :big),
    do: <<acc::binary, first::unsigned-big-32, second::unsigned-big-32>>

  defp append_codepoints_to_ucs4(acc, {first, second}, :little),
    do: <<acc::binary, first::unsigned-little-32, second::unsigned-little-32>>

  defp append_codepoints_to_ucs4(acc, codepoints, :big),
    do: append_tuple_to_ucs4_big(acc, codepoints, 0, tuple_size(codepoints))

  defp append_codepoints_to_ucs4(acc, codepoints, :little),
    do: append_tuple_to_ucs4_little(acc, codepoints, 0, tuple_size(codepoints))

  defp append_tuple_to_ucs4_big(acc, _codepoints, size, size), do: acc

  defp append_tuple_to_ucs4_big(acc, codepoints, index, size) do
    codepoint = elem(codepoints, index)

    append_tuple_to_ucs4_big(
      <<acc::binary, codepoint::unsigned-big-32>>,
      codepoints,
      index + 1,
      size
    )
  end

  defp append_tuple_to_ucs4_little(acc, _codepoints, size, size), do: acc

  defp append_tuple_to_ucs4_little(acc, codepoints, index, size) do
    codepoint = elem(codepoints, index)

    append_tuple_to_ucs4_little(
      <<acc::binary, codepoint::unsigned-little-32>>,
      codepoints,
      index + 1,
      size
    )
  end

  defp append_cached_codepoints_to_ucs4(acc, codepoints, :big)
       when tuple_size(codepoints) > 0,
       do: append_cached_tuple_big(acc, codepoints, 0, tuple_size(codepoints))

  defp append_cached_codepoints_to_ucs4(acc, codepoints, :little)
       when tuple_size(codepoints) > 0,
       do: append_cached_tuple_little(acc, codepoints, 0, tuple_size(codepoints))

  defp append_cached_codepoints_to_ucs4(_acc, _codepoints, _endian), do: :error

  defp append_cached_tuple_big(acc, _codepoints, size, size), do: {:ok, acc}

  defp append_cached_tuple_big(acc, codepoints, index, size) do
    case elem(codepoints, index) do
      codepoint when is_integer(codepoint) and codepoint in 0..0xFFFF_FFFF ->
        append_cached_tuple_big(
          <<acc::binary, codepoint::unsigned-big-32>>,
          codepoints,
          index + 1,
          size
        )

      _invalid_codepoint ->
        :error
    end
  end

  defp append_cached_tuple_little(acc, _codepoints, size, size), do: {:ok, acc}

  defp append_cached_tuple_little(acc, codepoints, index, size) do
    case elem(codepoints, index) do
      codepoint when is_integer(codepoint) and codepoint in 0..0xFFFF_FFFF ->
        append_cached_tuple_little(
          <<acc::binary, codepoint::unsigned-little-32>>,
          codepoints,
          index + 1,
          size
        )

      _invalid_codepoint ->
        :error
    end
  end

  defp ucs4_word(codepoint, :big), do: <<codepoint::unsigned-big-32>>
  defp ucs4_word(codepoint, :little), do: <<codepoint::unsigned-little-32>>

  defp available(_codepoints, 0), do: 0
  defp available([], _limit), do: 0
  defp available([_ | rest], limit), do: 1 + available(rest, limit - 1)

  defp longest_binary(_input, _map, size) when size < 2, do: nil

  defp longest_binary(input, map, size) do
    bytes = binary_part(input, 0, size)

    case Map.fetch(map, bytes) do
      {:ok, codepoints} -> {bytes, codepoints}
      :error -> longest_binary(input, map, size - 1)
    end
  end

  defp longest_codepoints(_codepoints, _map, 0), do: nil

  defp longest_codepoints(codepoints, map, count) do
    key = codepoints |> Enum.take(count) |> List.to_tuple()

    case Map.fetch(map, key) do
      {:ok, bytes} -> {count, bytes}
      :error -> longest_codepoints(codepoints, map, count - 1)
    end
  end

  defp prepend(tuple, acc) when tuple_size(tuple) == 1, do: [elem(tuple, 0) | acc]
  defp prepend(tuple, acc) when tuple_size(tuple) == 2, do: [elem(tuple, 1), elem(tuple, 0) | acc]
  defp prepend(tuple, acc), do: tuple |> Tuple.to_list() |> :lists.reverse(acc)

  defp tuple_utf8({first}), do: <<first::utf8>>
  defp tuple_utf8({first, second}), do: <<first::utf8, second::utf8>>

  defp tuple_utf8(codepoints),
    do: codepoints |> Tuple.to_list() |> :unicode.characters_to_binary(:unicode, :utf8)

  defp utf8_size(codepoint) when codepoint <= 0x7F, do: 1
  defp utf8_size(codepoint) when codepoint <= 0x7FF, do: 2
  defp utf8_size(codepoint) when codepoint <= 0xFFFF, do: 3
  defp utf8_size(_codepoint), do: 4
end
