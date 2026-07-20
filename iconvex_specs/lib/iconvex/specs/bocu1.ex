defmodule Iconvex.Specs.BOCU1 do
  @moduledoc "BOCU-1 as specified by Unicode Technical Note #6."

  use Iconvex.Codec
  import Bitwise

  @ascii_prev 0x40
  @middle 0x90
  @reset 0xFF
  @trail_count 243
  @reach_pos_1 63
  @reach_neg_1 -64
  @reach_pos_2 10_512
  @reach_neg_2 -10_513
  @reach_pos_3 187_659
  @reach_neg_3 -187_660
  @start_pos_2 0xD0
  @start_pos_3 0xFB
  @start_pos_4 0xFE
  @start_neg_2 0x50
  @start_neg_3 0x25
  @start_neg_4 0x22
  @initial_state {@ascii_prev, 0, 0, 0, <<>>}

  @impl true
  def canonical_name, do: "BOCU-1"

  @impl true
  def aliases, do: ["BOCU1", "csBOCU-1"]

  @impl true
  def codec_id, do: :bocu1

  @impl true
  def stateful?, do: true

  @impl true
  def decode(input) when is_binary(input), do: decode_all(input, 0, @initial_state, [])

  @impl true
  def decode_discard(input) when is_binary(input),
    do: decode_discard_all(input, 0, @initial_state, [])

  @impl true
  def decode_error_consumption(_kind, sequence) when is_binary(sequence),
    do: max(byte_size(sequence), 1)

  @impl true
  def encode(codepoints) when is_list(codepoints),
    do: encode_all(codepoints, @ascii_prev, [])

  @impl true
  def encode_discard(codepoints) when is_list(codepoints),
    do: encode_discard_all(codepoints, @ascii_prev, [])

  @impl true
  def encode_substitute(codepoints, replacer),
    do:
      Iconvex.Specs.CodecSupport.encode_substitute_transform(
        codepoints,
        &encode/1,
        replacer
      )

  @impl true
  def decode_to_utf8(input) do
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

  defp decode_all(<<>>, _offset, {_prev, 0, _diff, _start, _sequence}, acc),
    do: {:ok, :lists.reverse(acc)}

  defp decode_all(<<>>, _offset, {_prev, _count, _diff, start, sequence}, _acc),
    do: {:error, :incomplete_sequence, start, sequence}

  defp decode_all(<<byte, rest::binary>>, offset, state, acc) do
    case decode_byte(state, byte, offset) do
      {:emit, codepoint, next_state} ->
        decode_all(rest, offset + 1, next_state, [codepoint | acc])

      {:state, next_state} ->
        decode_all(rest, offset + 1, next_state, acc)

      {:error, start, sequence} ->
        {:error, :invalid_sequence, start, sequence}
    end
  end

  defp decode_discard_all(<<>>, _offset, _state, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_discard_all(<<byte, rest::binary>>, offset, state, acc) do
    case decode_byte(state, byte, offset) do
      {:emit, codepoint, next_state} ->
        decode_discard_all(rest, offset + 1, next_state, [codepoint | acc])

      {:state, next_state} ->
        decode_discard_all(rest, offset + 1, next_state, acc)

      {:error, _start, _sequence} ->
        decode_discard_all(rest, offset + 1, @initial_state, acc)
    end
  end

  defp decode_byte({prev, 0, _diff, _start, _sequence}, byte, _offset) when byte <= 0x20 do
    next = if byte == 0x20, do: prev, else: @ascii_prev
    {:emit, byte, {next, 0, 0, 0, <<>>}}
  end

  defp decode_byte({prev, 0, _diff, _start, _sequence}, byte, offset)
       when byte >= @start_neg_2 and byte < @start_pos_2 do
    codepoint = prev + byte - @middle

    if valid_scalar?(codepoint),
      do: {:emit, codepoint, {next_prev(codepoint), 0, 0, 0, <<>>}},
      else: {:error, offset, <<byte>>}
  end

  defp decode_byte({_prev, 0, _diff, _start, _sequence}, @reset, _offset),
    do: {:state, @initial_state}

  defp decode_byte({prev, 0, _diff, _start, _sequence}, byte, offset) do
    {count, diff} = lead_state(byte)
    {:state, {prev, count, diff, offset, <<byte>>}}
  end

  defp decode_byte({prev, count, diff, start, sequence}, byte, _offset) do
    sequence = sequence <> <<byte>>

    case byte_to_trail(byte) do
      :error ->
        {:error, start, sequence}

      trail when count == 1 ->
        codepoint = prev + diff + trail

        if valid_scalar?(codepoint),
          do: {:emit, codepoint, {next_prev(codepoint), 0, 0, 0, <<>>}},
          else: {:error, start, sequence}

      trail when count == 2 ->
        {:state, {prev, 1, diff + trail * @trail_count, start, sequence}}

      trail when count == 3 ->
        {:state, {prev, 2, diff + trail * @trail_count * @trail_count, start, sequence}}
    end
  end

  defp lead_state(byte) when byte >= @start_pos_2 and byte < @start_pos_3,
    do: {1, (byte - @start_pos_2) * @trail_count + @reach_pos_1 + 1}

  defp lead_state(byte) when byte >= @start_pos_3 and byte < @start_pos_4,
    do: {2, (byte - @start_pos_3) * @trail_count * @trail_count + @reach_pos_2 + 1}

  defp lead_state(byte) when byte >= @start_pos_4,
    do: {3, @reach_pos_3 + 1}

  defp lead_state(byte) when byte >= @start_neg_3,
    do: {1, (byte - @start_neg_2) * @trail_count + @reach_neg_1}

  defp lead_state(byte) when byte > 0x21,
    do: {2, (byte - @start_neg_3) * @trail_count * @trail_count + @reach_neg_2}

  defp lead_state(_byte),
    do: {3, -@trail_count * @trail_count * @trail_count + @reach_neg_3}

  defp byte_to_trail(byte) when byte in 0x01..0x06, do: byte - 1
  defp byte_to_trail(byte) when byte in 0x10..0x19, do: byte - 10
  defp byte_to_trail(byte) when byte in 0x1C..0x1F, do: byte - 12
  defp byte_to_trail(byte) when byte > 0x20, do: byte - 13
  defp byte_to_trail(_byte), do: :error

  defp encode_all([], _prev, acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_all([codepoint | rest], prev, acc) do
    case encode_one(codepoint, prev) do
      {:ok, bytes, next} -> encode_all(rest, next, [bytes | acc])
      :error -> {:error, :unrepresentable_character, codepoint}
    end
  end

  defp encode_discard_all([], _prev, acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_discard_all([codepoint | rest], prev, acc) do
    case encode_one(codepoint, prev) do
      {:ok, bytes, next} -> encode_discard_all(rest, next, [bytes | acc])
      :error -> encode_discard_all(rest, prev, acc)
    end
  end

  defp encode_one(codepoint, prev) when codepoint in 0..0x20 do
    next = if codepoint == 0x20, do: prev, else: @ascii_prev
    {:ok, <<codepoint>>, next}
  end

  defp encode_one(codepoint, prev)
       when codepoint in 0x21..0x10FFFF and codepoint not in 0xD800..0xDFFF,
       do: {:ok, pack_diff(codepoint - prev), next_prev(codepoint)}

  defp encode_one(_codepoint, _prev), do: :error

  defp pack_diff(diff) when diff in @reach_neg_1..@reach_pos_1,
    do: <<@middle + diff>>

  defp pack_diff(diff) when diff > @reach_pos_1 and diff <= @reach_pos_2,
    do: pack_multi(diff - @reach_pos_1 - 1, @start_pos_2, 1)

  defp pack_diff(diff) when diff > @reach_pos_2 and diff <= @reach_pos_3,
    do: pack_multi(diff - @reach_pos_2 - 1, @start_pos_3, 2)

  defp pack_diff(diff) when diff > @reach_pos_3,
    do: pack_multi(diff - @reach_pos_3 - 1, @start_pos_4, 3)

  defp pack_diff(diff) when diff >= @reach_neg_2,
    do: pack_multi(diff - @reach_neg_1, @start_neg_2, 1)

  defp pack_diff(diff) when diff >= @reach_neg_3,
    do: pack_multi(diff - @reach_neg_2, @start_neg_3, 2)

  defp pack_diff(diff), do: pack_multi(diff - @reach_neg_3, @start_neg_4, 3)

  defp pack_multi(value, lead_start, count) do
    {lead_delta, trails} = split_trails(value, count, [])
    [<<lead_start + lead_delta>>, trails]
  end

  defp split_trails(value, 0, acc), do: {value, acc}

  defp split_trails(value, count, acc) do
    trail = Integer.mod(value, @trail_count)
    quotient = Integer.floor_div(value, @trail_count)
    split_trails(quotient, count - 1, [trail_to_byte(trail) | acc])
  end

  defp trail_to_byte(trail) when trail < 6, do: trail + 1
  defp trail_to_byte(trail) when trail < 16, do: trail + 10
  defp trail_to_byte(trail) when trail < 20, do: trail + 12
  defp trail_to_byte(trail), do: trail + 13

  defp next_prev(codepoint) when codepoint in 0x3040..0x309F, do: 0x3070
  defp next_prev(codepoint) when codepoint in 0x4E00..0x9FA5, do: 0x4E00 - @reach_neg_2
  defp next_prev(codepoint) when codepoint in 0xAC00..0xD7A3, do: div(0xD7A3 + 0xAC00, 2)
  defp next_prev(codepoint), do: (codepoint &&& -0x80) + @ascii_prev

  defp valid_scalar?(codepoint),
    do: codepoint in 0..0x10FFFF and codepoint not in 0xD800..0xDFFF
end
