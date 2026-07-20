defmodule Iconvex.Specs.Punycode do
  @moduledoc """
  Native Punycode (the RFC 3492 Bootstring profile).

  This is the complete-string Punycode transform. It deliberately does not
  add the IDNA `xn--` prefix or perform IDNA mapping and normalization.
  """

  use Iconvex.Codec

  @external_resource Path.expand("../../../priv/sources/rfc3492/rfc3492.txt", __DIR__)
  @external_resource Path.expand(
                       "../../../priv/sources/rfc3492/cpython-3.14.6-punycode.py",
                       __DIR__
                     )
  @external_resource Path.expand("../../../priv/sources/rfc3492/CPYTHON-LICENSE.txt", __DIR__)
  @external_resource Path.expand("../../../priv/sources/rfc3492/SOURCE_METADATA.md", __DIR__)

  @base 36
  @tmin 1
  @tmax 26
  @skew 38
  @damp 700
  @initial_bias 72
  @initial_n 0x80
  @max_scalar 0x10FFFF
  @delimiter ?-

  @impl true
  def canonical_name, do: "PUNYCODE"

  @impl true
  def aliases, do: ["RFC3492", "RFC-3492", "BOOTSTRING-PUNYCODE"]

  @impl true
  def codec_id, do: :punycode

  @impl true
  def decode_error_recovery, do: :stop

  @impl true
  def decode(input) when is_binary(input), do: decode_all(input, :strict)

  @impl true
  def decode_discard(input) when is_binary(input), do: decode_all(input, :discard)

  @impl true
  def encode(codepoints) when is_list(codepoints) do
    case segregate(codepoints, [], MapSet.new(), 0) do
      {:ok, basic, extended, basic_count} ->
        encode_valid(codepoints, basic, extended, basic_count)

      {:error, codepoint} ->
        {:error, :unrepresentable_character, codepoint}
    end
  end

  @impl true
  def encode_discard(codepoints) when is_list(codepoints) do
    codepoints
    |> discard_invalid([], [], MapSet.new(), 0)
    |> then(fn {valid, basic, extended, basic_count} ->
      encode_valid(valid, basic, extended, basic_count)
    end)
  end

  @impl true
  def encode_substitute(codepoints, replacer)
      when is_list(codepoints) and is_function(replacer, 1) do
    case substitute_invalid(codepoints, replacer, []) do
      {:ok, transformed} -> encode(:lists.reverse(transformed))
      {:error, codepoint} -> {:error, :unrepresentable_character, codepoint}
    end
  end

  @impl true
  def decode_to_utf8(input) when is_binary(input) do
    with {:ok, codepoints} <- decode(input), do: {:ok, List.to_string(codepoints)}
  end

  @impl true
  def encode_from_utf8(input) when is_binary(input) do
    if String.valid?(input) do
      encode(String.to_charlist(input))
    else
      Iconvex.Specs.CodecSupport.malformed_utf8(input)
    end
  end

  defp segregate([], basic, extended, basic_count),
    do: {:ok, basic, extended, basic_count}

  defp segregate([codepoint | rest], basic, extended, basic_count)
       when codepoint in 0..0x7F,
       do: segregate(rest, [codepoint | basic], extended, basic_count + 1)

  defp segregate([codepoint | rest], basic, extended, basic_count)
       when codepoint in 0x80..0x10FFFF and codepoint not in 0xD800..0xDFFF,
       do: segregate(rest, basic, MapSet.put(extended, codepoint), basic_count)

  defp segregate([codepoint | _rest], _basic, _extended, _basic_count),
    do: {:error, codepoint}

  defp discard_invalid([], valid, basic, extended, basic_count),
    do: {:lists.reverse(valid), basic, extended, basic_count}

  defp discard_invalid([codepoint | rest], valid, basic, extended, basic_count)
       when codepoint in 0..0x7F,
       do:
         discard_invalid(
           rest,
           [codepoint | valid],
           [codepoint | basic],
           extended,
           basic_count + 1
         )

  defp discard_invalid([codepoint | rest], valid, basic, extended, basic_count)
       when codepoint in 0x80..0x10FFFF and codepoint not in 0xD800..0xDFFF,
       do:
         discard_invalid(
           rest,
           [codepoint | valid],
           basic,
           MapSet.put(extended, codepoint),
           basic_count
         )

  defp discard_invalid([_codepoint | rest], valid, basic, extended, basic_count),
    do: discard_invalid(rest, valid, basic, extended, basic_count)

  defp substitute_invalid([], _replacer, acc), do: {:ok, acc}

  defp substitute_invalid([codepoint | rest], replacer, acc)
       when codepoint in 0..0x10FFFF and codepoint not in 0xD800..0xDFFF,
       do: substitute_invalid(rest, replacer, [codepoint | acc])

  defp substitute_invalid([codepoint | rest], replacer, acc) do
    case prepend_replacement(replacer.(codepoint), acc) do
      {:ok, acc} -> substitute_invalid(rest, replacer, acc)
      error -> error
    end
  end

  defp prepend_replacement([], acc), do: {:ok, acc}

  defp prepend_replacement([codepoint | rest], acc)
       when codepoint in 0..0x10FFFF and codepoint not in 0xD800..0xDFFF,
       do: prepend_replacement(rest, [codepoint | acc])

  defp prepend_replacement([codepoint | _rest], _acc), do: {:error, codepoint}
  defp prepend_replacement(other, _acc), do: {:error, other}

  defp encode_valid(codepoints, basic, extended, basic_count) do
    prefix =
      case basic_count do
        0 -> <<>>
        _ -> basic |> :lists.reverse() |> :erlang.list_to_binary() |> Kernel.<>("-")
      end

    cond do
      MapSet.size(extended) == 0 ->
        {:ok, prefix}

      nondecreasing?(codepoints) ->
        codepoints
        |> drop_items(basic_count)
        |> encode_monotonic_groups(
          @initial_n,
          0,
          basic_count,
          basic_count,
          @initial_bias,
          [prefix]
        )

      true ->
        codepoints
        |> Enum.with_index()
        |> Enum.map(fn {codepoint, position} -> {codepoint, position, 0} end)
        |> rank_smaller_before(length(codepoints))
        |> Enum.chunk_by(&elem(&1, 0))
        |> Enum.reject(fn [{codepoint, _position, _less_before} | _rest] ->
          codepoint < @initial_n
        end)
        |> Enum.map(&Enum.sort_by(&1, fn {_codepoint, position, _less_before} -> position end))
        |> encode_ranked_groups(
          @initial_n,
          0,
          basic_count,
          basic_count,
          @initial_bias,
          [prefix]
        )
    end
  end

  defp nondecreasing?([]), do: true
  defp nondecreasing?([head | tail]), do: nondecreasing?(tail, head)
  defp nondecreasing?([], _previous), do: true

  defp nondecreasing?([head | tail], previous) when head >= previous,
    do: nondecreasing?(tail, head)

  defp nondecreasing?(_rest, _previous), do: false

  defp drop_items(items, 0), do: items
  defp drop_items([_head | tail], count), do: drop_items(tail, count - 1)

  defp encode_monotonic_groups([], _n, _delta, _handled, _basic_count, _bias, acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_monotonic_groups(
         [next | rest],
         n,
         delta,
         handled,
         basic_count,
         bias,
         acc
       ) do
    {occurrences, rest} = count_same(rest, next, 1)
    value = delta + (next - n) * (handled + 1) + handled

    {handled, bias, acc} =
      encode_monotonic_occurrences(occurrences, value, handled, basic_count, bias, acc)

    encode_monotonic_groups(rest, next + 1, 1, handled, basic_count, bias, acc)
  end

  defp count_same([value | rest], value, count), do: count_same(rest, value, count + 1)
  defp count_same(rest, _value, count), do: {count, rest}

  defp encode_monotonic_occurrences(0, _value, handled, _basic_count, bias, acc),
    do: {handled, bias, acc}

  defp encode_monotonic_occurrences(count, value, handled, basic_count, bias, acc) do
    encoded = encode_integer(value, bias, @base, [])
    next_bias = adapt(value, handled + 1, handled == basic_count)

    encode_monotonic_occurrences(
      count - 1,
      0,
      handled + 1,
      basic_count,
      next_bias,
      [encoded | acc]
    )
  end

  defp encode_ranked_groups([], _n, _delta, _handled, _basic_count, _bias, acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_ranked_groups(
         [[{next, _position, _less_before} | _group_rest] = group | rest],
         n,
         delta,
         handled,
         basic_count,
         bias,
         acc
       ) do
    delta = delta + (next - n) * (handled + 1)
    less_count = handled

    {last_less_before, handled, bias, acc} =
      encode_ranked_occurrences(group, delta, handled, basic_count, bias, acc)

    encode_ranked_groups(
      rest,
      next + 1,
      less_count - last_less_before + 1,
      handled,
      basic_count,
      bias,
      acc
    )
  end

  defp encode_ranked_occurrences(
         [{_codepoint, _position, less_before} | rest],
         delta,
         handled,
         basic_count,
         bias,
         acc
       ) do
    value = delta + less_before
    encoded = encode_integer(value, bias, @base, [])
    next_bias = adapt(value, handled + 1, handled == basic_count)

    encode_following_occurrences(
      rest,
      less_before,
      handled + 1,
      basic_count,
      next_bias,
      [encoded | acc]
    )
  end

  defp encode_following_occurrences([], last_less_before, handled, _basic_count, bias, acc),
    do: {last_less_before, handled, bias, acc}

  defp encode_following_occurrences(
         [{_codepoint, _position, less_before} | rest],
         previous_less_before,
         handled,
         basic_count,
         bias,
         acc
       ) do
    value = less_before - previous_less_before
    encoded = encode_integer(value, bias, @base, [])
    next_bias = adapt(value, handled + 1, handled == basic_count)

    encode_following_occurrences(
      rest,
      less_before,
      handled + 1,
      basic_count,
      next_bias,
      [encoded | acc]
    )
  end

  defp rank_smaller_before([], 0), do: []
  defp rank_smaller_before([item], 1), do: [item]

  defp rank_smaller_before(items, length) when length > 1 do
    left_length = div(length, 2)
    {left, right} = :lists.split(left_length, items)

    merge_ranked(
      rank_smaller_before(left, left_length),
      rank_smaller_before(right, length - left_length),
      0,
      []
    )
  end

  defp merge_ranked([], right, left_seen, acc),
    do: :lists.reverse(acc, add_cross_count(right, left_seen, []))

  defp merge_ranked(left, [], _left_seen, acc), do: :lists.reverse(acc, left)

  defp merge_ranked(
         [{left_value, _left_position, _left_count} = left_item | left_rest] = left,
         [{right_value, right_position, right_count} | right_rest] = right,
         left_seen,
         acc
       ) do
    if left_value < right_value do
      merge_ranked(left_rest, right, left_seen + 1, [left_item | acc])
    else
      merge_ranked(
        left,
        right_rest,
        left_seen,
        [{right_value, right_position, right_count + left_seen} | acc]
      )
    end
  end

  defp add_cross_count([], _count, acc), do: :lists.reverse(acc)

  defp add_cross_count([{value, position, count} | rest], cross_count, acc),
    do: add_cross_count(rest, cross_count, [{value, position, count + cross_count} | acc])

  defp encode_integer(value, bias, k, acc) do
    threshold = threshold(k, bias)

    if value < threshold do
      [digit(value) | acc] |> :lists.reverse() |> :erlang.list_to_binary()
    else
      encoded_digit = threshold + rem(value - threshold, @base - threshold)
      next = div(value - threshold, @base - threshold)
      encode_integer(next, bias, k + @base, [digit(encoded_digit) | acc])
    end
  end

  defp digit(value) when value < 26, do: ?a + value
  defp digit(value), do: ?0 + value - 26

  defp decode_all(input, policy) do
    {base_end, extended_start} = split_at_last_delimiter(input)

    with {:ok, base, base_count} <- decode_basic(input, base_end, policy, 0, [], 0) do
      decode_extended(
        input,
        extended_start,
        policy,
        {:append, base, []},
        base_count,
        @initial_n,
        0,
        @initial_bias
      )
    end
  end

  defp split_at_last_delimiter(input) do
    case :binary.matches(input, <<@delimiter>>) do
      [] ->
        {0, 0}

      matches ->
        {offset, 1} = List.last(matches)
        {offset, offset + 1}
    end
  end

  defp decode_basic(_input, end_offset, _policy, end_offset, acc, count),
    do: {:ok, :lists.reverse(acc), count}

  defp decode_basic(input, end_offset, policy, offset, acc, count) do
    byte = :binary.at(input, offset)

    cond do
      byte < 0x80 ->
        decode_basic(input, end_offset, policy, offset + 1, [byte | acc], count + 1)

      policy == :discard ->
        decode_basic(input, end_offset, policy, offset + 1, acc, count)

      true ->
        {:error, :invalid_sequence, offset, <<byte>>}
    end
  end

  defp decode_extended(input, offset, _policy, output, length, _n, _i, _bias)
       when offset == byte_size(input),
       do: {:ok, finish_output(output, length)}

  defp decode_extended(input, offset, policy, output, length, n, i, bias) do
    old_i = i
    insertion_length = length + 1
    integer_limit = (@max_scalar - n + 1) * insertion_length - i - 1

    case decode_integer(input, offset, bias, integer_limit) do
      {:ok, delta, next_offset} ->
        i = i + delta
        n = n + div(i, insertion_length)
        insertion_offset = rem(i, insertion_length)

        cond do
          valid_scalar?(n) ->
            output = record_output(output, insertion_offset, length, n)
            bias = adapt(i - old_i, insertion_length, old_i == 0)

            decode_extended(
              input,
              next_offset,
              policy,
              output,
              insertion_length,
              n,
              insertion_offset + 1,
              bias
            )

          policy == :discard ->
            {:ok, finish_output(output, length)}

          true ->
            sequence = binary_part(input, offset, next_offset - offset)
            {:error, :invalid_sequence, offset, sequence}
        end

      {:overflow, _next_offset} when policy == :discard ->
        {:ok, finish_output(output, length)}

      {:overflow, next_offset} ->
        sequence = binary_part(input, offset, next_offset - offset)
        {:error, :invalid_sequence, offset, sequence}

      {:error, _kind, _error_offset, _sequence} when policy == :discard ->
        {:ok, finish_output(output, length)}

      error ->
        error
    end
  end

  defp decode_integer(input, offset, bias, limit),
    do: decode_integer(input, offset, offset, bias, @base, 0, 1, limit, false)

  defp decode_integer(input, offset, start, bias, k, result, weight, limit, overflow?) do
    if offset == byte_size(input) do
      {:error, :incomplete_sequence, start, binary_part(input, start, offset - start)}
    else
      byte = :binary.at(input, offset)

      case digit_value(byte) do
        :error ->
          {:error, :invalid_sequence, offset, <<byte>>}

        value ->
          {result, overflow?} = add_weighted_digit(result, value, weight, limit, overflow?)
          threshold = threshold(k, bias)

          if value < threshold do
            if overflow?, do: {:overflow, offset + 1}, else: {:ok, result, offset + 1}
          else
            decode_integer(
              input,
              offset + 1,
              start,
              bias,
              k + @base,
              result,
              next_weight(weight, @base - threshold, limit),
              limit,
              overflow?
            )
          end
      end
    end
  end

  defp add_weighted_digit(result, _value, _weight, _limit, true), do: {result, true}
  defp add_weighted_digit(result, 0, _weight, _limit, false), do: {result, false}

  defp add_weighted_digit(result, value, weight, limit, false) do
    if weight > div(limit - result, value),
      do: {result, true},
      else: {result + value * weight, false}
  end

  defp next_weight(weight, factor, limit) do
    if weight > div(limit, factor), do: limit + 1, else: weight * factor
  end

  defp digit_value(byte) when byte in ?a..?z, do: byte - ?a
  defp digit_value(byte) when byte in ?A..?Z, do: byte - ?A
  defp digit_value(byte) when byte in ?0..?9, do: byte - ?0 + 26
  defp digit_value(_byte), do: :error

  defp threshold(k, bias) when k <= bias + @tmin, do: @tmin
  defp threshold(k, bias) when k >= bias + @tmax, do: @tmax
  defp threshold(k, bias), do: k - bias

  defp adapt(delta, points, first?) do
    delta = if first?, do: div(delta, @damp), else: div(delta, 2)
    adapt_loop(delta + div(delta, points), 0)
  end

  defp adapt_loop(delta, k) when delta > div((@base - @tmin) * @tmax, 2),
    do: adapt_loop(div(delta, @base - @tmin), k + @base)

  defp adapt_loop(delta, k),
    do: k + div((@base - @tmin + 1) * delta, delta + @skew)

  defp base_events(base) do
    base
    |> Enum.with_index()
    |> Enum.map(fn {codepoint, offset} -> {offset, codepoint} end)
    |> :lists.reverse()
  end

  defp record_output({:append, base, appended}, length, length, codepoint),
    do: {:append, base, [codepoint | appended]}

  defp record_output({:append, base, appended}, offset, _length, codepoint) do
    current = base ++ :lists.reverse(appended)
    {:events, [{offset, codepoint} | base_events(current)]}
  end

  defp record_output({:events, events}, offset, _length, codepoint),
    do: {:events, [{offset, codepoint} | events]}

  defp finish_output({:append, base, []}, _length), do: base

  defp finish_output({:append, base, appended}, _length),
    do: base ++ :lists.reverse(appended)

  defp finish_output({:events, _events}, 0), do: []

  defp finish_output({:events, events}, length) do
    {placements, _tree} =
      Enum.reduce(events, {[], nil}, fn {offset, codepoint}, {placements, tree} ->
        {position, tree} = occupy_kth_free(tree, 0, length - 1, offset + 1)
        {[{position, codepoint} | placements], tree}
      end)

    placements
    |> Enum.sort_by(&elem(&1, 0))
    |> Enum.map(&elem(&1, 1))
  end

  defp occupy_kth_free(tree, low, high, 1) when low == high do
    1 = free_count(tree, 1)
    {low, {0, nil, nil}}
  end

  defp occupy_kth_free(tree, low, high, rank) do
    midpoint = div(low + high, 2)
    {free, left, right} = tree_parts(tree, high - low + 1)
    left_size = midpoint - low + 1
    left_free = free_count(left, left_size)

    if rank <= left_free do
      {position, left} = occupy_kth_free(left, low, midpoint, rank)
      {position, {free - 1, left, right}}
    else
      {position, right} = occupy_kth_free(right, midpoint + 1, high, rank - left_free)
      {position, {free - 1, left, right}}
    end
  end

  defp tree_parts(nil, size), do: {size, nil, nil}
  defp tree_parts({free, left, right}, _size), do: {free, left, right}

  defp free_count(nil, size), do: size
  defp free_count({free, _left, _right}, _size), do: free

  defp valid_scalar?(codepoint),
    do: codepoint in 0..0x10FFFF and codepoint not in 0xD800..0xDFFF
end
