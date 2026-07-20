defmodule Iconvex.Specs.ISCII do
  @moduledoc "ISCII-91 with all Microsoft/ICU initial-script variants."

  alias Iconvex.Specs.ISCII.Data

  @selector_versions %{
    0x42 => 0,
    0x43 => 1,
    0x46 => 1,
    0x4B => 2,
    0x4A => 3,
    0x47 => 4,
    0x44 => 5,
    0x45 => 6,
    0x48 => 7,
    0x49 => 8
  }

  def encodings, do: Enum.map(Data.fetch().encodings, & &1.name)
  def oracle_vectors, do: Data.fetch().oracle_vectors
  def fixture_source, do: Data.fetch().fixture_source

  def resolve(name) when is_binary(name) do
    normalized = String.upcase(name, :ascii)

    case Enum.find(Data.fetch().encodings, fn entry ->
           Enum.any?([entry.name | entry.aliases], &(String.upcase(&1, :ascii) == normalized))
         end) do
      nil -> :error
      entry -> {:ok, entry}
    end
  end

  def resolve(_name), do: :error

  def decode(name, input) when is_binary(input) do
    with {:ok, entry} <- resolve(name) do
      decode_loop(input, entry.version, entry.version, 0, [], Data.fetch())
    end
  end

  def encode(name, codepoints) when is_list(codepoints) do
    with {:ok, entry} <- resolve(name) do
      encode_loop(codepoints, entry.version, nil, [], merged_encode(Data.fetch()), Data.fetch())
    end
  end

  def encode_substitute(name, codepoints, replacer)
      when is_list(codepoints) and is_function(replacer, 1) do
    with {:ok, entry} <- resolve(name) do
      data = Data.fetch()

      encode_substitute_loop(
        codepoints,
        [],
        false,
        entry.version,
        nil,
        [],
        merged_encode(data),
        data,
        replacer
      )
    end
  end

  def decode_discard(name, input) do
    case decode(name, input) do
      {:ok, _values} = ok ->
        ok

      {:error, _kind, offset, sequence} ->
        prefix = binary_part(input, 0, offset)

        prefix_values =
          case decode(name, prefix) do
            {:ok, values} -> values
            _ -> []
          end

        skip = max(byte_size(sequence), 1)
        start = min(offset + skip, byte_size(input))
        rest = binary_part(input, start, byte_size(input) - start)

        with {:ok, rest_values} <- decode_discard(name, rest),
             do: {:ok, prefix_values ++ rest_values}
    end
  end

  def encode_discard(name, codepoints) do
    case encode(name, codepoints) do
      {:ok, _bytes} = ok ->
        ok

      {:error, :unrepresentable_character, codepoint} ->
        {before, tail} = Enum.split_while(codepoints, &(&1 != codepoint))
        encode_discard(name, before ++ Enum.drop(tail, 1))
    end
  end

  defp decode_loop(<<>>, _version, _default, _offset, acc, _data),
    do: {:ok, acc |> Enum.reverse() |> List.flatten()}

  defp decode_loop(<<0xEF>>, _version, _default, offset, _acc, _data),
    do: {:error, :incomplete_sequence, offset, <<0xEF>>}

  defp decode_loop(<<0xEF, selector, rest::binary>>, version, default, offset, acc, data) do
    cond do
      selector == 0x40 ->
        decode_loop(rest, default, default, offset + 2, acc, data)

      selector == 0x41 ->
        decode_loop(rest, :roman, default, offset + 2, acc, data)

      selector in 0x21..0x3F ->
        decode_loop(rest, version, default, offset + 2, acc, data)

      next = @selector_versions[selector] ->
        decode_loop(rest, next, default, offset + 2, acc, data)

      true ->
        {:error, :invalid_sequence, offset, <<0xEF, selector>>}
    end
  end

  defp decode_loop(<<byte, rest::binary>>, :roman, default, offset, acc, data)
       when byte <= 0xA0 do
    next = if byte == 0x0A, do: default, else: :roman
    decode_loop(rest, next, default, offset + 1, [[byte] | acc], data)
  end

  defp decode_loop(<<byte, _::binary>>, :roman, _default, offset, _acc, _data),
    do: {:error, :invalid_sequence, offset, <<byte>>}

  defp decode_loop(input, version, default, offset, acc, data) do
    table = data.versions[version]

    case longest_bytes(input, table.decode, min(byte_size(input), table.max_bytes)) do
      {codepoints, consumed, rest} ->
        next = if input == <<0x0A, rest::binary>>, do: default, else: version

        decode_loop(
          rest,
          next,
          default,
          offset + consumed,
          [Tuple.to_list(codepoints) | acc],
          data
        )

      nil ->
        sequence = binary_part(input, 0, min(byte_size(input), table.max_bytes))

        kind =
          if MapSet.member?(table.prefixes, input),
            do: :incomplete_sequence,
            else: :invalid_sequence

        {:error, kind, offset, sequence}
    end
  end

  defp longest_bytes(_input, _map, 0), do: nil

  defp longest_bytes(input, map, size) do
    bytes = binary_part(input, 0, size)

    case Map.fetch(map, bytes) do
      {:ok, value} -> {value, size, binary_part(input, size, byte_size(input) - size)}
      :error -> longest_bytes(input, map, size - 1)
    end
  end

  defp encode_loop([], _default, _selector, acc, _encode, _data),
    do: {:ok, acc |> Enum.reverse() |> IO.iodata_to_binary()}

  defp encode_loop(codepoints, default, selector, acc, encode, data) do
    case longest_codepoints(codepoints, encode, 3) do
      {bytes, count} ->
        {output, next_selector} = normalize_announcement(bytes, selector)
        consumed = Enum.take(codepoints, count)
        next_selector = if consumed == [0x0A], do: nil, else: next_selector

        encode_loop(
          Enum.drop(codepoints, count),
          default,
          next_selector,
          [output | acc],
          encode,
          data
        )

      nil ->
        {:error, :unrepresentable_character, hd(codepoints)}
    end
  end

  defp encode_substitute_loop(
         [],
         resume,
         true,
         default,
         selector,
         acc,
         encode,
         data,
         replacer
       ),
       do:
         encode_substitute_loop(
           resume,
           [],
           false,
           default,
           selector,
           acc,
           encode,
           data,
           replacer
         )

  defp encode_substitute_loop(
         [],
         [],
         false,
         _default,
         _selector,
         acc,
         _encode,
         _data,
         _replacer
       ),
       do: {:ok, acc |> Enum.reverse() |> IO.iodata_to_binary()}

  defp encode_substitute_loop(
         codepoints,
         resume,
         replacement?,
         default,
         selector,
         acc,
         encode,
         data,
         replacer
       ) do
    case longest_codepoints(codepoints, encode, 3) do
      {bytes, count} ->
        {output, next_selector} = normalize_announcement(bytes, selector)
        consumed = Enum.take(codepoints, count)
        next_selector = if consumed == [0x0A], do: nil, else: next_selector

        encode_substitute_loop(
          Enum.drop(codepoints, count),
          resume,
          replacement?,
          default,
          next_selector,
          [output | acc],
          encode,
          data,
          replacer
        )

      nil when replacement? ->
        {:error, :unrepresentable_character, hd(codepoints)}

      nil ->
        [codepoint | rest] = codepoints

        encode_substitute_loop(
          replacer.(codepoint),
          rest,
          true,
          default,
          selector,
          acc,
          encode,
          data,
          replacer
        )
    end
  end

  defp longest_codepoints(_codepoints, _map, 0), do: nil

  defp longest_codepoints(codepoints, map, count) do
    key = codepoints |> Enum.take(count) |> List.to_tuple()
    available = tuple_size(key)

    case Map.fetch(map, key) do
      {:ok, bytes} -> {bytes, available}
      :error -> longest_codepoints(codepoints, map, available - 1)
    end
  end

  defp normalize_announcement(<<0xEF, selector, rest::binary>>, selector), do: {rest, selector}

  defp normalize_announcement(<<0xEF, selector, _::binary>> = bytes, _current),
    do: {bytes, selector}

  defp normalize_announcement(bytes, selector), do: {bytes, selector}

  defp merged_encode(data) do
    Enum.reduce(0..8, %{}, fn version, acc -> Map.merge(data.versions[version].encode, acc) end)
  end
end
