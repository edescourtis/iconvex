defmodule Iconvex.Specs.ICUCompoundText.Data do
  @moduledoc false

  @path Path.expand("../../../priv/icu_compound_text.etf", __DIR__)
  @external_resource @path

  def fetch, do: Iconvex.Specs.RuntimeAsset.fetch(__MODULE__, @path)
end

defmodule Iconvex.Specs.ICUCompoundText do
  @moduledoc """
  Pure Elixir port of ICU 78.3's X11 Compound Text converter.

  The converter includes all nineteen ICU mapping states, their X11 escape
  designators, exact preferred-state rules, and ICU's search order for the
  internal single-, double-, and triple-byte fallback tables.
  """

  use Iconvex.Codec
  alias Iconvex.Specs.ICUCompoundText.Data

  @manifest_path Path.expand("../../../priv/icu_compound_text_manifest.etf", __DIR__)
  @external_resource @manifest_path
  @manifest @manifest_path |> File.read!() |> :erlang.binary_to_term()
  # ICU 78.3's shipped converter searches states 1..10 for encoder fallbacks;
  # state 11 (the UTF-8-like triple table) remains decoder-only in practice.
  @search_states Enum.to_list(1..10)

  @impl true
  def canonical_name, do: @manifest.canonical_name

  def aliases, do: @manifest.aliases

  @impl true
  def codec_id, do: :icu_compound_text

  def aggregate_sha256, do: @manifest.aggregate_sha256
  def release, do: @manifest.release
  def revision, do: @manifest.revision
  def source_url, do: @manifest.source_url
  def sources, do: @manifest.sources

  @impl true
  def encode(codepoints) when is_list(codepoints) do
    encode_loop(codepoints, Data.fetch(), 0, [], false)
  end

  @impl true
  def encode_discard(codepoints) when is_list(codepoints) do
    encode_loop(codepoints, Data.fetch(), 0, [], true)
  end

  @impl true
  def encode_substitute(codepoints, replacer)
      when is_list(codepoints) and is_function(replacer, 1) do
    encode_substitute_loop(codepoints, [], false, Data.fetch(), 0, [], replacer)
  end

  @impl true
  def decode(input) when is_binary(input) do
    decode_loop(input, Data.fetch(), 0, 0, [], false)
  end

  @impl true
  def decode_discard(input) when is_binary(input) do
    decode_loop(input, Data.fetch(), 0, 0, [], true)
  end

  @impl true
  def decode_to_utf8(input) do
    with {:ok, codepoints} <- decode(input), do: {:ok, List.to_string(codepoints)}
  end

  @impl true
  def encode_from_utf8(input) when is_binary(input) do
    case :unicode.characters_to_list(input, :utf8) do
      codepoints when is_list(codepoints) ->
        encode(codepoints)

      {:error, converted, rest} ->
        {:decode_error, :invalid_sequence, utf8_size(converted), rest}

      {:incomplete, converted, rest} ->
        {:decode_error, :incomplete_sequence, utf8_size(converted), rest}
    end
  end

  defp encode_loop([], _data, _state, acc, _discard?) do
    {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}
  end

  defp encode_loop([codepoint | rest], data, state, acc, discard?)
       when codepoint in 0..0x10FFFF do
    preferred = if codepoint <= 0xFFFF, do: :binary.at(data.preferred, codepoint), else: 0xFF

    cond do
      preferred == 0xFF ->
        case find_mapping(@search_states, codepoint, data.states) do
          {:ok, next_state, bytes} ->
            prefix = if state == next_state, do: <<>>, else: data.escapes[next_state]
            encode_loop(rest, data, next_state, [[prefix, bytes] | acc], discard?)

          :error ->
            # ICU 78.3's implementation silently emits nothing in this branch.
            encode_loop(rest, data, state, acc, discard?)
        end

      preferred == 0 ->
        prefix = if state == 0, do: <<>>, else: data.escapes[0]
        encode_loop(rest, data, 0, [[prefix, <<Bitwise.band(codepoint, 0xFF)>>] | acc], discard?)

      true ->
        prefix = if state == preferred, do: <<>>, else: data.escapes[preferred]
        bytes = Map.get(data.states[preferred].encode, codepoint, <<>>)
        encode_loop(rest, data, preferred, [[prefix, bytes] | acc], discard?)
    end
  end

  defp encode_loop([_codepoint | rest], data, state, acc, true) do
    encode_loop(rest, data, state, acc, true)
  end

  defp encode_loop([codepoint | _rest], _data, _state, _acc, false) do
    {:error, :unrepresentable_character, codepoint}
  end

  defp encode_substitute_loop([], resume, true, data, state, acc, replacer),
    do: encode_substitute_loop(resume, [], false, data, state, acc, replacer)

  defp encode_substitute_loop([], [], false, _data, _state, acc, _replacer),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_substitute_loop(
         [codepoint | rest],
         resume,
         replacement?,
         data,
         state,
         acc,
         replacer
       )
       when codepoint in 0..0x10FFFF do
    preferred = if codepoint <= 0xFFFF, do: :binary.at(data.preferred, codepoint), else: 0xFF

    case preferred do
      0xFF ->
        case find_mapping(@search_states, codepoint, data.states) do
          {:ok, next_state, bytes} ->
            prefix = if state == next_state, do: <<>>, else: data.escapes[next_state]

            encode_substitute_loop(
              rest,
              resume,
              replacement?,
              data,
              next_state,
              [[prefix, bytes] | acc],
              replacer
            )

          :error ->
            encode_substitute_loop(rest, resume, replacement?, data, state, acc, replacer)
        end

      0 ->
        prefix = if state == 0, do: <<>>, else: data.escapes[0]

        encode_substitute_loop(
          rest,
          resume,
          replacement?,
          data,
          0,
          [[prefix, <<Bitwise.band(codepoint, 0xFF)>>] | acc],
          replacer
        )

      preferred ->
        prefix = if state == preferred, do: <<>>, else: data.escapes[preferred]
        bytes = Map.get(data.states[preferred].encode, codepoint, <<>>)

        encode_substitute_loop(
          rest,
          resume,
          replacement?,
          data,
          preferred,
          [[prefix, bytes] | acc],
          replacer
        )
    end
  end

  defp encode_substitute_loop(
         [codepoint | _rest],
         _resume,
         true,
         _data,
         _state,
         _acc,
         _replacer
       ),
       do: {:error, :unrepresentable_character, codepoint}

  defp encode_substitute_loop(
         [codepoint | rest],
         _resume,
         false,
         data,
         state,
         acc,
         replacer
       ),
       do: encode_substitute_loop(replacer.(codepoint), rest, true, data, state, acc, replacer)

  defp find_mapping([], _codepoint, _states), do: :error

  defp find_mapping([state | rest], codepoint, states) do
    case Map.fetch(states[state].encode, codepoint) do
      {:ok, bytes} -> {:ok, state, bytes}
      :error -> find_mapping(rest, codepoint, states)
    end
  end

  defp decode_loop(<<>>, _data, _state, _offset, acc, _discard?),
    do: {:ok, :lists.reverse(acc)}

  defp decode_loop(<<0x1B, _::binary>> = input, data, state, offset, acc, discard?) do
    case parse_escape(input, data.escapes) do
      {:ok, next_state, size} ->
        <<_::binary-size(size), rest::binary>> = input
        continue_after_escape(rest, data, next_state, offset + size, acc, discard?)

      :incomplete when discard? ->
        {:ok, :lists.reverse(acc)}

      :incomplete ->
        {:error, :incomplete_sequence, offset, input}

      {:invalid, size} when discard? ->
        size = min(max(size, 1), byte_size(input))
        <<_::binary-size(size), rest::binary>> = input
        decode_loop(rest, data, state, offset + size, acc, true)

      {:invalid, size} ->
        size = min(max(size, 1), byte_size(input))
        {:error, :invalid_sequence, offset, binary_part(input, 0, size)}
    end
  end

  defp decode_loop(<<byte, rest::binary>>, data, 0, offset, acc, discard?) do
    decode_loop(rest, data, 0, offset + 1, [byte | acc], discard?)
  end

  defp decode_loop(input, data, state, offset, acc, discard?) do
    table = data.states[state]

    case longest_mapping(input, table) do
      {bytes, codepoint} ->
        size = byte_size(bytes)
        <<_::binary-size(size), rest::binary>> = input
        decode_loop(rest, data, state, offset + size, [codepoint | acc], discard?)

      :incomplete when discard? ->
        {:ok, :lists.reverse(acc)}

      :incomplete ->
        {:error, :incomplete_sequence, offset, input}

      :invalid when discard? ->
        <<_byte, rest::binary>> = input
        decode_loop(rest, data, state, offset + 1, acc, true)

      :invalid ->
        size = min(segment_size(input), table.max_input)
        {:error, :invalid_sequence, offset, binary_part(input, 0, max(size, 1))}
    end
  end

  # ICU's loop immediately enters the selected subconverter after an escape.
  # If another escape follows with no intervening data, `findNextEsc()` starts
  # at index 1, so that first escape is consumed as data by the subconverter.
  # Preserve that observable behavior, including its replacement characters.
  defp continue_after_escape(<<0x1B, _::binary>> = input, data, state, offset, acc, discard?)
       when state != 0 do
    size = next_escape_after_first(input)
    <<segment::binary-size(size), rest::binary>> = input
    decoded = decode_segment_with_replacement(segment, data.states[state], [])
    decode_loop(rest, data, state, offset + size, :lists.reverse(decoded, acc), discard?)
  end

  defp continue_after_escape(input, data, state, offset, acc, discard?) do
    decode_loop(input, data, state, offset, acc, discard?)
  end

  defp next_escape_after_first(<<_escape>>), do: 1

  defp next_escape_after_first(input) do
    case :binary.match(input, <<0x1B>>, scope: {1, byte_size(input) - 1}) do
      {index, _size} -> index
      :nomatch -> byte_size(input)
    end
  end

  defp decode_segment_with_replacement(<<>>, _table, acc), do: :lists.reverse(acc)

  defp decode_segment_with_replacement(input, table, acc) do
    case longest_mapping(input, table) do
      {bytes, codepoint} ->
        size = byte_size(bytes)
        <<_::binary-size(size), rest::binary>> = input
        decode_segment_with_replacement(rest, table, [codepoint | acc])

      _invalid_or_incomplete ->
        <<_byte, rest::binary>> = input
        decode_segment_with_replacement(rest, table, [0xFFFD | acc])
    end
  end

  defp parse_escape(input, escapes) do
    case Enum.find(escapes, fn {_state, escape} -> starts_with?(input, escape) end) do
      {state, escape} ->
        {:ok, state, byte_size(escape)}

      nil ->
        if Enum.any?(escapes, fn {_state, escape} -> starts_with?(escape, input) end),
          do: :incomplete,
          else: {:invalid, invalid_escape_size(input)}
    end
  end

  defp invalid_escape_size(<<0x1B, ?$, ?), _::binary>>), do: 4
  defp invalid_escape_size(input), do: min(3, byte_size(input))

  defp longest_mapping(input, table) do
    segment = segment_size(input)
    maximum = min(segment, table.max_input)

    case find_longest(input, table.decode, maximum) do
      nil ->
        prefix_size = min(segment, byte_size(input))
        prefix = binary_part(input, 0, prefix_size)

        if segment == byte_size(input) and MapSet.member?(table.prefixes, prefix),
          do: :incomplete,
          else: :invalid

      found ->
        found
    end
  end

  defp find_longest(_input, _mapping, 0), do: nil

  defp find_longest(input, mapping, size) do
    bytes = binary_part(input, 0, size)

    case Map.fetch(mapping, bytes) do
      {:ok, codepoint} -> {bytes, codepoint}
      :error -> find_longest(input, mapping, size - 1)
    end
  end

  defp segment_size(input) do
    case :binary.match(input, <<0x1B>>) do
      {0, _size} -> 0
      {index, _size} -> index
      :nomatch -> byte_size(input)
    end
  end

  defp starts_with?(binary, prefix) when byte_size(binary) >= byte_size(prefix),
    do: binary_part(binary, 0, byte_size(prefix)) == prefix

  defp starts_with?(_binary, _prefix), do: false
  defp utf8_size(codepoints), do: codepoints |> List.to_string() |> byte_size()
end
