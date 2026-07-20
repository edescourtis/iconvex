defmodule Iconvex.UnicodeCodec do
  @moduledoc false
  import Bitwise

  @ucs2 ~w(ucs2 ucs2be ucs2le ucs2internal ucs2swapped)a
  @ucs4 ~w(ucs4 ucs4be ucs4le ucs4internal ucs4swapped)a
  @utf16 ~w(utf16 utf16be utf16le)a
  @utf32 ~w(utf32 utf32be utf32le)a
  @two_byte @ucs2 ++ @utf16
  @four_byte @ucs4 ++ @utf32
  @explicit_ucs4 ~w(ucs4be ucs4le ucs4internal ucs4swapped)a
  @explicit_utf32 ~w(utf32be utf32le)a
  @surrogate_lead_bytes for byte <- 0xD8..0xDF, do: <<byte>>
  @unicode16_markers [<<0xFE, 0xFF>>, <<0xFF, 0xFE>>]
  @unicode32_markers [<<0x00, 0x00, 0xFE, 0xFF>>, <<0xFF, 0xFE, 0x00, 0x00>>]

  def stream_init(%{id: id}) when id in [:ucs2, :utf16], do: {:unicode16, :big}
  def stream_init(%{id: id}) when id in [:ucs4, :utf32], do: {:unicode32, :big}

  def decode_chunk(entry, input, state, final?) do
    prefix = stream_prefix(state)
    prefix_size = byte_size(prefix)

    case decode(entry, prefix <> input) do
      {:ok, codepoints} ->
        {:ok, codepoints, scan_stream(input, state), <<>>}

      {:error, :incomplete_sequence, offset, _sequence} when not final? ->
        local_offset = max(offset - prefix_size, 0)
        stable = binary_part(input, 0, local_offset)
        pending = binary_part(input, local_offset, byte_size(input) - local_offset)

        case decode(entry, prefix <> stable) do
          {:ok, codepoints} ->
            {:ok, codepoints, scan_stream(stable, state), pending}

          {:error, kind, prefix_offset, prefix_sequence} ->
            {:error, kind, max(prefix_offset - prefix_size, 0), prefix_sequence}
        end

      {:error, kind, offset, sequence} ->
        {:error, kind, max(offset - prefix_size, 0), sequence}
    end
  end

  def decode(%{id: :utf8}, input) do
    case :unicode.characters_to_list(input, :utf8) do
      codepoints when is_list(codepoints) ->
        {:ok, codepoints}

      {:error, _converted, <<byte, _rest::binary>> = rest} ->
        {:error, :invalid_sequence, byte_size(input) - byte_size(rest), <<byte>>}

      {:incomplete, _converted, rest} ->
        {:error, :incomplete_sequence, byte_size(input) - byte_size(rest), rest}
    end
  end

  def decode(%{id: :utf16be} = entry, input),
    do: decode_unicode_fast(input, {:utf16, :big}, fn -> decode16_entry(entry, input) end)

  def decode(%{id: :utf16le} = entry, input),
    do: decode_unicode_fast(input, {:utf16, :little}, fn -> decode16_entry(entry, input) end)

  def decode(%{id: :utf32be} = entry, input),
    do: decode_unicode_fast(input, {:utf32, :big}, fn -> decode32_entry(entry, input) end)

  def decode(%{id: :utf32le} = entry, input),
    do: decode_unicode_fast(input, {:utf32, :little}, fn -> decode32_entry(entry, input) end)

  def decode(%{id: id} = entry, input) when id in @explicit_ucs4 do
    encoding = {:utf32, initial_endian(id)}

    case decode_explicit_ucs4_fast(input, encoding, initial_endian(id)) do
      {:ok, codepoints} -> {:ok, codepoints}
      :error -> decode32_entry(entry, input)
    end
  end

  def decode(%{id: id}, input) when id in @two_byte,
    do: decode16(input, id, initial_endian(id), 0, [])

  def decode(%{id: id}, input) when id in @four_byte,
    do: decode32(input, id, initial_endian(id), 0, [])

  def encode(%{id: :utf8}, codepoints), do: encode_utf8(codepoints)

  def encode(%{id: id}, codepoints) when id in @two_byte,
    do: encode16(codepoints, id)

  def encode(%{id: id}, codepoints) when id in @four_byte,
    do: encode32(codepoints, id)

  def encode_discard(%{id: :utf8}, codepoints),
    do: {:ok, :unicode.characters_to_binary(valid_scalars(codepoints), :unicode, :utf8)}

  def encode_discard(%{id: id}, codepoints) when id in @two_byte,
    do: encode16(codepoints, id, true)

  def encode_discard(%{id: id}, codepoints) when id in @four_byte,
    do: encode32(codepoints, id, true)

  def encode_substitute(%{id: :utf8}, codepoints, replacer) when is_function(replacer, 1),
    do: reduce_substitute(codepoints, <<>>, replacer, &encode_utf8_codepoint/1)

  def encode_substitute(%{id: id}, codepoints, replacer)
      when id in @two_byte and is_function(replacer, 1) do
    prefix = if id == :utf16 and codepoints != [], do: <<0xFE, 0xFF>>, else: <<>>
    endian = initial_endian(id)
    reduce_substitute(codepoints, prefix, replacer, &encode16_codepoint(&1, id, endian))
  end

  def encode_substitute(%{id: id}, codepoints, replacer)
      when id in @four_byte and is_function(replacer, 1) do
    prefix = if id == :utf32 and codepoints != [], do: <<0, 0, 0xFE, 0xFF>>, else: <<>>
    endian = initial_endian(id)
    reduce_substitute(codepoints, prefix, replacer, &encode32_codepoint(&1, id, endian))
  end

  def decode_discard(%{id: id}, input) when id in @two_byte,
    do: decode_replace16(input, id, initial_endian(id), fn _byte -> [] end, [])

  def decode_discard(%{id: id}, input) when id in @four_byte,
    do: decode_replace32(input, id, initial_endian(id), fn _byte -> [] end, [])

  def decode_substitute(%{id: id}, input, replacer)
      when id in @two_byte and is_function(replacer, 1),
      do: decode_replace16(input, id, initial_endian(id), replacer, [])

  def decode_substitute(%{id: id}, input, replacer)
      when id in @four_byte and is_function(replacer, 1),
      do: decode_replace32(input, id, initial_endian(id), replacer, [])

  @doc false
  def direct_convert(input, from_id, to_id, _invalid, _unrepresentable)
      when from_id in @explicit_ucs4 and to_id in @explicit_ucs4 do
    if rem(byte_size(input), 4) == 0 do
      {:ok, transcode_explicit_ucs4(input, initial_endian(from_id), initial_endian(to_id))}
    else
      :miss
    end
  end

  def direct_convert(input, from_id, :ucs4, _invalid, :discard)
      when from_id in @explicit_ucs4 do
    if rem(byte_size(input), 4) == 0 do
      {:ok, explicit_ucs4_to_generic(input, initial_endian(from_id))}
    else
      :miss
    end
  end

  def direct_convert(input, from_id, to_id, _invalid, :discard)
      when from_id in @explicit_ucs4 and to_id in @ucs2 do
    if rem(byte_size(input), 4) == 0 do
      {:ok,
       explicit_ucs4_to_ucs2(
         input,
         initial_endian(from_id),
         to_id,
         initial_endian(to_id),
         []
       )}
    else
      :miss
    end
  end

  def direct_convert(input, from_id, to_id, _invalid, :discard)
      when from_id in @explicit_ucs4 and to_id in @utf16 do
    if rem(byte_size(input), 4) == 0 do
      {:ok, explicit_ucs4_to_utf16(input, initial_endian(from_id), to_id)}
    else
      :miss
    end
  end

  def direct_convert(input, from_id, to_id, _invalid, :discard)
      when from_id in @explicit_ucs4 and to_id in @utf32 do
    if rem(byte_size(input), 4) == 0 do
      {:ok, explicit_ucs4_to_utf32(input, initial_endian(from_id), to_id)}
    else
      :miss
    end
  end

  def direct_convert(input, from_id, to_id, :discard, _unrepresentable)
      when from_id in [:ucs4, :utf32] and to_id in @explicit_ucs4,
      do: {:ok, generic_32_to_explicit(input, from_id, initial_endian(to_id), :big, [])}

  def direct_convert(input, from_id, to_id, :discard, _unrepresentable)
      when from_id in @explicit_utf32 and to_id in @explicit_ucs4,
      do: {:ok, explicit_utf32_to_ucs4(input, initial_endian(from_id), initial_endian(to_id))}

  def direct_convert(input, from_id, to_id, :discard, _unrepresentable)
      when from_id in @ucs2 and to_id in @explicit_ucs4,
      do: ucs2_to_explicit_ucs4(input, from_id, initial_endian(to_id))

  def direct_convert(_input, _from_id, _to_id, _invalid, _unrepresentable), do: :miss

  @doc false
  def explicit_ucs4_to_utf8_discard(input, endian)
      when endian in [:big, :little] and rem(byte_size(input), 4) == 0,
      do: explicit_ucs4_to_utf8_segments(input, {:utf32, endian}, endian, [])

  def explicit_ucs4_to_utf8_discard(_input, _endian), do: :miss

  defp decode16_entry(%{id: id}, input), do: decode16(input, id, initial_endian(id), 0, [])

  defp decode32_entry(%{id: id}, input), do: decode32(input, id, initial_endian(id), 0, [])

  defp transcode_explicit_ucs4(input, endian, endian), do: input

  defp transcode_explicit_ucs4(input, :big, :little),
    do: for(<<codepoint::unsigned-big-32 <- input>>, into: <<>>, do: <<codepoint::little-32>>)

  defp transcode_explicit_ucs4(input, :little, :big),
    do: for(<<codepoint::unsigned-little-32 <- input>>, into: <<>>, do: <<codepoint::big-32>>)

  defp explicit_ucs4_to_generic(input, from_endian) do
    for <<unit::binary-size(4) <- input>>,
        codepoint = read32(unit, from_endian),
        codepoint <= 0x7FFFFFFF,
        into: <<>>,
        do: write32(codepoint, :big)
  end

  defp explicit_ucs4_to_ucs2(<<>>, _from_endian, _id, _to_endian, acc),
    do: acc |> :lists.reverse() |> IO.iodata_to_binary()

  defp explicit_ucs4_to_ucs2(
         <<codepoint::unsigned-big-32, rest::binary>>,
         :big,
         id,
         to_endian,
         acc
       ) do
    acc =
      if ucs2_codepoint?(codepoint, id),
        do: [write16(codepoint, to_endian) | acc],
        else: acc

    explicit_ucs4_to_ucs2(rest, :big, id, to_endian, acc)
  end

  defp explicit_ucs4_to_ucs2(
         <<codepoint::unsigned-little-32, rest::binary>>,
         :little,
         id,
         to_endian,
         acc
       ) do
    acc =
      if ucs2_codepoint?(codepoint, id),
        do: [write16(codepoint, to_endian) | acc],
        else: acc

    explicit_ucs4_to_ucs2(rest, :little, id, to_endian, acc)
  end

  defp ucs2_codepoint?(codepoint, id),
    do:
      codepoint <= 0xFFFF and codepoint not in 0xD800..0xDFFF and
        (id != :ucs2 or codepoint != 0xFFFE)

  defp explicit_ucs4_to_utf16(input, from_endian, id) do
    to_endian = initial_endian(id)

    body =
      if id == :utf16 do
        explicit_ucs4_to_utf16_without_fffe(input, from_endian, to_endian, [])
      else
        explicit_ucs4_to_utf16_segments(input, from_endian, to_endian, [])
      end

    prefix = if id == :utf16, do: <<0xFE, 0xFF>>, else: <<>>
    prepend_if_output(prefix, body)
  end

  defp explicit_ucs4_to_utf16_without_fffe(input, from_endian, to_endian, segments) do
    pattern = write32(0xFFFE, from_endian)

    case find_aligned_pattern(input, pattern, 4, 0) do
      nil ->
        converted = explicit_ucs4_to_utf16_segments(input, from_endian, to_endian, [])
        segments |> :lists.reverse([converted]) |> IO.iodata_to_binary()

      offset ->
        prefix = binary_part(input, 0, offset)
        rest_offset = offset + 4
        rest = binary_part(input, rest_offset, byte_size(input) - rest_offset)
        converted = explicit_ucs4_to_utf16_segments(prefix, from_endian, to_endian, [])

        explicit_ucs4_to_utf16_without_fffe(
          rest,
          from_endian,
          to_endian,
          [converted | segments]
        )
    end
  end

  defp explicit_ucs4_to_utf16_segments(input, from_endian, to_endian, segments) do
    case :unicode.characters_to_binary(
           input,
           {:utf32, from_endian},
           {:utf16, to_endian}
         ) do
      binary when is_binary(binary) ->
        segments |> :lists.reverse([binary]) |> IO.iodata_to_binary()

      {:error, converted, rest}
      when is_binary(converted) and (is_binary(rest) or is_list(rest)) ->
        rest = if is_binary(rest), do: rest, else: IO.iodata_to_binary(rest)
        remaining = discard_non_scalars(rest, from_endian)

        explicit_ucs4_to_utf16_segments(
          remaining,
          from_endian,
          to_endian,
          [converted | segments]
        )
    end
  end

  defp ucs2_to_explicit_ucs4(input, id, to_endian) do
    aligned_size = byte_size(input) - rem(byte_size(input), 2)
    aligned = binary_part(input, 0, aligned_size)
    to_encoding = {:utf32, to_endian}

    if id == :ucs2 do
      generic_ucs2_to_explicit_segments(aligned, :big, to_encoding, [])
    else
      explicit_ucs2_to_explicit_segments(
        aligned,
        initial_endian(id),
        to_encoding,
        []
      )
    end
  end

  defp generic_ucs2_to_explicit_segments(<<>>, _endian, _to_encoding, segments),
    do: {:ok, segments |> :lists.reverse() |> IO.iodata_to_binary()}

  defp generic_ucs2_to_explicit_segments(input, endian, to_encoding, segments) do
    case find_aligned_marker(input, 0) do
      nil ->
        with {:ok, converted} <-
               explicit_ucs2_to_explicit_segments(input, endian, to_encoding, []) do
          {:ok, segments |> :lists.reverse([converted]) |> IO.iodata_to_binary()}
        end

      offset ->
        prefix = binary_part(input, 0, offset)
        marker = binary_part(input, offset, 2)
        rest_offset = offset + 2
        rest = binary_part(input, rest_offset, byte_size(input) - rest_offset)

        with {:ok, converted} <-
               explicit_ucs2_to_explicit_segments(prefix, endian, to_encoding, []) do
          next_endian = if read16(marker, endian) == 0xFFFE, do: swap(endian), else: endian

          generic_ucs2_to_explicit_segments(
            rest,
            next_endian,
            to_encoding,
            [converted | segments]
          )
        end
    end
  end

  defp explicit_ucs2_to_explicit_segments(input, endian, to_encoding, segments) do
    case :unicode.characters_to_binary(input, {:utf16, endian}, to_encoding) do
      binary when is_binary(binary) and byte_size(binary) == byte_size(input) * 2 ->
        {:ok, segments |> :lists.reverse([binary]) |> IO.iodata_to_binary()}

      _surrogate_pair_or_malformed ->
        offset = find_aligned_surrogate(input, endian, 0)

        if is_integer(offset) do
          prefix = binary_part(input, 0, offset)
          rest_offset = offset + 2
          rest = binary_part(input, rest_offset, byte_size(input) - rest_offset)

          case :unicode.characters_to_binary(prefix, {:utf16, endian}, to_encoding) do
            binary when is_binary(binary) ->
              explicit_ucs2_to_explicit_segments(
                rest,
                endian,
                to_encoding,
                [binary | segments]
              )

            _unexpected ->
              :miss
          end
        else
          :miss
        end
    end
  end

  defp find_aligned_marker(input, search_offset) when search_offset >= byte_size(input), do: nil

  defp find_aligned_marker(input, search_offset) do
    case :binary.match(input, @unicode16_markers,
           scope: {search_offset, byte_size(input) - search_offset}
         ) do
      :nomatch -> nil
      {offset, 2} when rem(offset, 2) == 0 -> offset
      {offset, 2} -> find_aligned_marker(input, offset + 1)
    end
  end

  defp find_aligned_32_marker(input, search_offset) when search_offset >= byte_size(input),
    do: nil

  defp find_aligned_32_marker(input, search_offset) do
    case :binary.match(input, @unicode32_markers,
           scope: {search_offset, byte_size(input) - search_offset}
         ) do
      :nomatch -> nil
      {offset, 4} when rem(offset, 4) == 0 -> offset
      {offset, 4} -> find_aligned_32_marker(input, offset + 1)
    end
  end

  defp find_aligned_surrogate(input, _endian, search_offset)
       when search_offset >= byte_size(input),
       do: nil

  defp find_aligned_surrogate(input, endian, search_offset) do
    case :binary.match(input, @surrogate_lead_bytes,
           scope: {search_offset, byte_size(input) - search_offset}
         ) do
      :nomatch ->
        nil

      {offset, 1} when endian == :big and rem(offset, 2) == 0 ->
        offset

      {offset, 1} when endian == :little and rem(offset, 2) == 1 ->
        offset - 1

      {offset, 1} ->
        find_aligned_surrogate(input, endian, offset + 1)
    end
  end

  defp find_aligned_pattern(input, _pattern, _alignment, search_offset)
       when search_offset >= byte_size(input),
       do: nil

  defp find_aligned_pattern(input, pattern, alignment, search_offset) do
    case :binary.match(input, pattern, scope: {search_offset, byte_size(input) - search_offset}) do
      :nomatch -> nil
      {offset, _size} when rem(offset, alignment) == 0 -> offset
      {offset, _size} -> find_aligned_pattern(input, pattern, alignment, offset + 1)
    end
  end

  defp explicit_ucs4_to_utf32(input, from_endian, id) do
    to_endian = initial_endian(id)

    body =
      for <<unit::binary-size(4) <- input>>,
          codepoint = read32(unit, from_endian),
          codepoint in 0..0x10FFFF,
          codepoint not in 0xD800..0xDFFF,
          into: <<>>,
          do: write32(codepoint, to_endian)

    prefix = if id == :utf32, do: <<0, 0, 0xFE, 0xFF>>, else: <<>>
    prepend_if_output(prefix, body)
  end

  defp explicit_utf32_to_ucs4(input, from_endian, to_endian) do
    aligned_size = byte_size(input) - rem(byte_size(input), 4)
    aligned = binary_part(input, 0, aligned_size)

    if valid_explicit_utf32?(aligned, from_endian) do
      transcode_explicit_ucs4(aligned, from_endian, to_endian)
    else
      for <<unit::binary-size(4) <- aligned>>,
          codepoint = read32(unit, from_endian),
          codepoint <= 0x10FFFF,
          codepoint not in 0xD800..0xDFFF,
          into: <<>>,
          do: write32(codepoint, to_endian)
    end
  end

  defp valid_explicit_utf32?(<<>>, _endian), do: true

  defp valid_explicit_utf32?(<<codepoint::unsigned-big-32, rest::binary>>, :big)
       when codepoint <= 0x10FFFF and codepoint not in 0xD800..0xDFFF,
       do: valid_explicit_utf32?(rest, :big)

  defp valid_explicit_utf32?(<<codepoint::unsigned-little-32, rest::binary>>, :little)
       when codepoint <= 0x10FFFF and codepoint not in 0xD800..0xDFFF,
       do: valid_explicit_utf32?(rest, :little)

  defp valid_explicit_utf32?(_invalid, _endian), do: false

  defp generic_32_to_explicit(input, id, to_endian, endian, segments) do
    aligned_size = byte_size(input) - rem(byte_size(input), 4)
    aligned = binary_part(input, 0, aligned_size)

    case find_aligned_32_marker(aligned, 0) do
      nil ->
        converted = generic_32_segment_to_explicit(aligned, id, endian, to_endian)
        segments |> :lists.reverse([converted]) |> IO.iodata_to_binary()

      offset ->
        prefix = binary_part(aligned, 0, offset)
        marker = binary_part(aligned, offset, 4)
        rest_offset = offset + 4
        rest = binary_part(aligned, rest_offset, byte_size(aligned) - rest_offset)
        converted = generic_32_segment_to_explicit(prefix, id, endian, to_endian)
        next_endian = if read32(marker, endian) == 0xFFFE0000, do: swap(endian), else: endian

        generic_32_to_explicit(rest, id, to_endian, next_endian, [converted | segments])
    end
  end

  defp generic_32_segment_to_explicit(input, id, from_endian, to_endian) do
    if valid_generic_32_segment?(input, id, from_endian) do
      transcode_explicit_ucs4(input, from_endian, to_endian)
    else
      for <<unit::binary-size(4) <- input>>,
          value = read32(unit, from_endian),
          direct_generic_32_value?(id, value),
          into: <<>>,
          do: write32(value, to_endian)
    end
  end

  defp valid_generic_32_segment?(<<>>, _id, _endian), do: true

  defp valid_generic_32_segment?(<<value::unsigned-big-32, rest::binary>>, id, :big)
       when (id == :ucs4 and value <= 0x7FFFFFFF) or
              (id == :utf32 and value <= 0x10FFFF and value not in 0xD800..0xDFFF),
       do: valid_generic_32_segment?(rest, id, :big)

  defp valid_generic_32_segment?(<<value::unsigned-little-32, rest::binary>>, id, :little)
       when (id == :ucs4 and value <= 0x7FFFFFFF) or
              (id == :utf32 and value <= 0x10FFFF and value not in 0xD800..0xDFFF),
       do: valid_generic_32_segment?(rest, id, :little)

  defp valid_generic_32_segment?(_invalid, _id, _endian), do: false

  defp direct_generic_32_value?(:ucs4, value), do: value <= 0x7FFFFFFF

  defp direct_generic_32_value?(:utf32, value),
    do: value <= 0x10FFFF and value not in 0xD800..0xDFFF

  defp stream_prefix({:unicode16, :big}), do: <<0xFE, 0xFF>>
  defp stream_prefix({:unicode16, :little}), do: <<0xFF, 0xFE>>
  defp stream_prefix({:unicode32, :big}), do: <<0, 0, 0xFE, 0xFF>>
  defp stream_prefix({:unicode32, :little}), do: <<0xFF, 0xFE, 0, 0>>

  defp scan_stream(<<>>, state), do: state

  defp scan_stream(<<unit::binary-size(2), rest::binary>>, {:unicode16, endian}) do
    next_endian = if read16(unit, endian) == 0xFFFE, do: swap(endian), else: endian
    scan_stream(rest, {:unicode16, next_endian})
  end

  defp scan_stream(<<unit::binary-size(4), rest::binary>>, {:unicode32, endian}) do
    next_endian = if read32(unit, endian) == 0xFFFE0000, do: swap(endian), else: endian
    scan_stream(rest, {:unicode32, next_endian})
  end

  defp decode_unicode_fast(input, encoding, fallback) do
    case :unicode.characters_to_list(input, encoding) do
      codepoints when is_list(codepoints) -> {:ok, codepoints}
      _error_or_incomplete -> fallback.()
    end
  end

  # Erlang's Unicode BIF is substantially faster than an Elixir word-by-word
  # traversal, but deliberately rejects isolated surrogate values. Explicit
  # UCS-4 accepts every 32-bit word. Preserve the BIF's fast scalar prefix and
  # suffix while decoding only each rejected, aligned binary segment directly.
  defp decode_explicit_ucs4_fast(input, encoding, endian) when rem(byte_size(input), 4) == 0,
    do: decode_explicit_ucs4_segments(input, encoding, endian)

  defp decode_explicit_ucs4_fast(_input, _encoding, _endian), do: :error

  defp decode_explicit_ucs4_segments(input, encoding, endian),
    do: decode_explicit_ucs4_segments(input, encoding, endian, [])

  defp decode_explicit_ucs4_segments(input, encoding, endian, segments) do
    case :unicode.characters_to_list(input, encoding) do
      codepoints when is_list(codepoints) ->
        {:ok, :lists.append(:lists.reverse([codepoints | segments]))}

      {:error, converted, [invalid_segment | rest]}
      when is_list(converted) and is_binary(invalid_segment) and
             rem(byte_size(invalid_segment), 4) == 0 ->
        invalid_codepoints = decode_explicit_ucs4_segment(invalid_segment, endian)

        decode_explicit_ucs4_segments(
          rest,
          encoding,
          endian,
          [invalid_codepoints, converted | segments]
        )

      _error_or_incomplete ->
        :error
    end
  end

  defp decode_explicit_ucs4_segment(binary, :big),
    do: for(<<codepoint::unsigned-big-32 <- binary>>, do: codepoint)

  defp decode_explicit_ucs4_segment(binary, :little),
    do: for(<<codepoint::unsigned-little-32 <- binary>>, do: codepoint)

  defp explicit_ucs4_to_utf8_segments(input, encoding, endian, segments) do
    case :unicode.characters_to_binary(input, encoding, :utf8) do
      binary when is_binary(binary) ->
        {:ok, segments |> :lists.reverse([binary]) |> IO.iodata_to_binary()}

      {:error, converted, rest}
      when is_binary(converted) and (is_binary(rest) or is_list(rest)) ->
        rest = if is_binary(rest), do: rest, else: IO.iodata_to_binary(rest)
        remaining = discard_non_scalars(rest, endian)

        if byte_size(remaining) < byte_size(rest) do
          explicit_ucs4_to_utf8_segments(remaining, encoding, endian, [converted | segments])
        else
          :miss
        end

      _error_or_incomplete ->
        :miss
    end
  end

  defp discard_non_scalars(<<codepoint::unsigned-big-32, rest::binary>>, :big)
       when codepoint > 0x10FFFF or codepoint in 0xD800..0xDFFF,
       do: discard_non_scalars(rest, :big)

  defp discard_non_scalars(<<codepoint::unsigned-little-32, rest::binary>>, :little)
       when codepoint > 0x10FFFF or codepoint in 0xD800..0xDFFF,
       do: discard_non_scalars(rest, :little)

  defp discard_non_scalars(input, _endian), do: input

  defp decode16(<<>>, _id, _endian, _offset, acc), do: {:ok, :lists.reverse(acc)}

  defp decode16(input, _id, _endian, offset, _acc) when byte_size(input) < 2,
    do: {:error, :incomplete_sequence, offset, input}

  defp decode16(input, id, endian, offset, acc) do
    <<unit::binary-size(2), rest::binary>> = input
    value = read16(unit, endian)

    cond do
      id in [:ucs2, :utf16] and value == 0xFEFF ->
        decode16(rest, id, endian, offset + 2, acc)

      id in [:ucs2, :utf16] and value == 0xFFFE ->
        decode16(rest, id, swap(endian), offset + 2, acc)

      id in @ucs2 and value in 0xD800..0xDFFF ->
        {:error, :invalid_sequence, offset, unit}

      id in @utf16 and value in 0xD800..0xDBFF ->
        decode_surrogate(input, id, endian, offset, acc, value)

      id in @utf16 and value in 0xDC00..0xDFFF ->
        {:error, :invalid_sequence, offset, unit}

      true ->
        decode16(rest, id, endian, offset + 2, [value | acc])
    end
  end

  defp decode_surrogate(input, _id, _endian, offset, _acc, _high) when byte_size(input) < 4,
    do: {:error, :incomplete_sequence, offset, input}

  defp decode_surrogate(input, id, endian, offset, acc, high) do
    <<high_bytes::binary-size(2), low_bytes::binary-size(2), rest::binary>> = input
    low = read16(low_bytes, endian)

    if low in 0xDC00..0xDFFF do
      codepoint = 0x10000 + ((high - 0xD800) <<< 10) + low - 0xDC00
      decode16(rest, id, endian, offset + 4, [codepoint | acc])
    else
      {:error, :invalid_sequence, offset, high_bytes}
    end
  end

  defp decode_replace16(<<>>, _id, _endian, _replacer, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_replace16(input, _id, _endian, replacer, acc) when byte_size(input) < 2,
    do: {:ok, acc |> replace_bytes(input, replacer) |> :lists.reverse()}

  defp decode_replace16(input, id, endian, replacer, acc) do
    <<unit::binary-size(2), rest::binary>> = input
    value = read16(unit, endian)

    cond do
      id in [:ucs2, :utf16] and value == 0xFEFF ->
        decode_replace16(rest, id, endian, replacer, acc)

      id in [:ucs2, :utf16] and value == 0xFFFE ->
        decode_replace16(rest, id, swap(endian), replacer, acc)

      id in @ucs2 and value in 0xD800..0xDFFF ->
        decode_replace16(rest, id, endian, replacer, replace_bytes(acc, unit, replacer))

      id in @utf16 and value in 0xD800..0xDBFF ->
        decode_replace_surrogate(input, id, endian, replacer, acc, value)

      id in @utf16 and value in 0xDC00..0xDFFF ->
        decode_replace16(rest, id, endian, replacer, replace_bytes(acc, unit, replacer))

      true ->
        decode_replace16(rest, id, endian, replacer, [value | acc])
    end
  end

  defp decode_replace_surrogate(input, _id, _endian, replacer, acc, _high)
       when byte_size(input) < 4 do
    {:ok, acc |> replace_bytes(input, replacer) |> :lists.reverse()}
  end

  defp decode_replace_surrogate(input, id, endian, replacer, acc, high) do
    <<high_bytes::binary-size(2), low_bytes::binary-size(2), rest::binary>> = input
    low = read16(low_bytes, endian)

    if low in 0xDC00..0xDFFF do
      codepoint = 0x10000 + ((high - 0xD800) <<< 10) + low - 0xDC00
      decode_replace16(rest, id, endian, replacer, [codepoint | acc])
    else
      decode_replace16(
        <<low_bytes::binary, rest::binary>>,
        id,
        endian,
        replacer,
        replace_bytes(acc, high_bytes, replacer)
      )
    end
  end

  defp decode32(<<>>, _id, _endian, _offset, acc), do: {:ok, :lists.reverse(acc)}

  defp decode32(input, _id, _endian, offset, _acc) when byte_size(input) < 4,
    do: {:error, :incomplete_sequence, offset, input}

  defp decode32(input, id, endian, offset, acc) do
    <<unit::binary-size(4), rest::binary>> = input
    value = read32(unit, endian)

    cond do
      id in [:ucs4, :utf32] and value == 0xFEFF ->
        decode32(rest, id, endian, offset + 4, acc)

      id in [:ucs4, :utf32] and value == 0xFFFE0000 ->
        decode32(rest, id, swap(endian), offset + 4, acc)

      (id == :ucs4 and value <= 0x7FFFFFFF) or id in @explicit_ucs4 ->
        decode32(rest, id, endian, offset + 4, [value | acc])

      id in @utf32 and value <= 0x10FFFF and value not in 0xD800..0xDFFF ->
        decode32(rest, id, endian, offset + 4, [value | acc])

      true ->
        {:error, :invalid_sequence, offset, unit}
    end
  end

  defp decode_replace32(<<>>, _id, _endian, _replacer, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_replace32(input, _id, _endian, replacer, acc) when byte_size(input) < 4,
    do: {:ok, acc |> replace_bytes(input, replacer) |> :lists.reverse()}

  defp decode_replace32(input, id, endian, replacer, acc) do
    <<unit::binary-size(4), rest::binary>> = input
    value = read32(unit, endian)

    cond do
      id in [:ucs4, :utf32] and value == 0xFEFF ->
        decode_replace32(rest, id, endian, replacer, acc)

      id in [:ucs4, :utf32] and value == 0xFFFE0000 ->
        decode_replace32(rest, id, swap(endian), replacer, acc)

      (id == :ucs4 and value <= 0x7FFFFFFF) or id in @explicit_ucs4 ->
        decode_replace32(rest, id, endian, replacer, [value | acc])

      id in @utf32 and value <= 0x10FFFF and value not in 0xD800..0xDFFF ->
        decode_replace32(rest, id, endian, replacer, [value | acc])

      true ->
        decode_replace32(rest, id, endian, replacer, replace_bytes(acc, unit, replacer))
    end
  end

  defp encode_utf8(codepoints) do
    case :unicode.characters_to_binary(codepoints, :unicode, :utf8) do
      binary when is_binary(binary) -> {:ok, binary}
      {:error, _converted, [codepoint | _]} -> {:error, :unrepresentable_character, codepoint}
    end
  end

  defp encode_utf8_codepoint(codepoint)
       when codepoint in 0..0x10FFFF and codepoint not in 0xD800..0xDFFF,
       do: {:ok, <<codepoint::utf8>>}

  defp encode_utf8_codepoint(_codepoint), do: :error

  defp encode16(codepoints, id), do: encode16(codepoints, id, false)

  defp encode16(codepoints, id, discard?) when id in @utf16 do
    prefix = if id == :utf16 and codepoints != [], do: <<0xFE, 0xFF>>, else: <<>>
    encoding = {:utf16, initial_endian(id)}

    cond do
      id == :utf16 and discard? ->
        codepoints
        |> filter_utf16_generic([])
        |> fast_encode(codepoints, id, discard?, prefix, encoding, &encode16_slow/3)

      id == :utf16 and :lists.member(0xFFFE, codepoints) ->
        encode16_slow(codepoints, id, discard?)

      true ->
        fast_encode(codepoints, codepoints, id, discard?, prefix, encoding, &encode16_slow/3)
    end
  end

  defp encode16(codepoints, id, discard?), do: encode16_slow(codepoints, id, discard?)

  defp encode16_slow(codepoints, id, discard?) do
    prefix = if id == :utf16 and codepoints != [], do: <<0xFE, 0xFF>>, else: <<>>
    endian = initial_endian(id)

    reduce_encode(codepoints, prefix, discard?, &encode16_codepoint(&1, id, endian))
  end

  defp encode16_codepoint(codepoint, id, endian) do
    cond do
      id in @ucs2 and codepoint in 0..0xFFFF and codepoint not in 0xD800..0xDFFF and
          (id != :ucs2 or codepoint != 0xFFFE) ->
        {:ok, write16(codepoint, endian)}

      id in @utf16 and codepoint in 0..0xFFFF and codepoint not in 0xD800..0xDFFF and
          (id != :utf16 or codepoint != 0xFFFE) ->
        {:ok, write16(codepoint, endian)}

      id in @utf16 and codepoint in 0x10000..0x10FFFF ->
        value = codepoint - 0x10000

        {:ok,
         write16(0xD800 + (value >>> 10), endian) <>
           write16(0xDC00 + (value &&& 0x3FF), endian)}

      true ->
        :error
    end
  end

  defp encode32(codepoints, id), do: encode32(codepoints, id, false)

  defp encode32(codepoints, id, discard?) when id in @explicit_ucs4 do
    encode_explicit_ucs4_native(codepoints, initial_endian(id), discard?, [])
  end

  defp encode32(codepoints, id, discard?) do
    prefix = if id == :utf32 and codepoints != [], do: <<0, 0, 0xFE, 0xFF>>, else: <<>>
    encoding = {:utf32, initial_endian(id)}

    fast_encode(codepoints, codepoints, id, discard?, prefix, encoding, &encode32_slow/3)
  end

  defp encode32_slow(codepoints, id, discard?) do
    prefix = if id == :utf32 and codepoints != [], do: <<0, 0, 0xFE, 0xFF>>, else: <<>>
    endian = initial_endian(id)

    reduce_encode(codepoints, prefix, discard?, &encode32_codepoint(&1, id, endian))
  end

  defp encode32_codepoint(codepoint, id, endian) do
    valid =
      cond do
        id == :ucs4 -> codepoint in 0..0x7FFFFFFF
        id in @explicit_ucs4 -> codepoint in 0..0xFFFFFFFF
        true -> codepoint in 0..0x10FFFF and codepoint not in 0xD800..0xDFFF
      end

    if valid, do: {:ok, write32(codepoint, endian)}, else: :error
  end

  defp encode_explicit_ucs4_native([], _endian, _discard?, acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_explicit_ucs4_native(
         [a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p | rest],
         :big,
         discard?,
         acc
       )
       when a in 0..0xFFFFFFFF and b in 0..0xFFFFFFFF and c in 0..0xFFFFFFFF and
              d in 0..0xFFFFFFFF and e in 0..0xFFFFFFFF and f in 0..0xFFFFFFFF and
              g in 0..0xFFFFFFFF and h in 0..0xFFFFFFFF and i in 0..0xFFFFFFFF and
              j in 0..0xFFFFFFFF and k in 0..0xFFFFFFFF and l in 0..0xFFFFFFFF and
              m in 0..0xFFFFFFFF and n in 0..0xFFFFFFFF and o in 0..0xFFFFFFFF and
              p in 0..0xFFFFFFFF do
    bytes =
      <<a::unsigned-big-32, b::unsigned-big-32, c::unsigned-big-32, d::unsigned-big-32,
        e::unsigned-big-32, f::unsigned-big-32, g::unsigned-big-32, h::unsigned-big-32,
        i::unsigned-big-32, j::unsigned-big-32, k::unsigned-big-32, l::unsigned-big-32,
        m::unsigned-big-32, n::unsigned-big-32, o::unsigned-big-32, p::unsigned-big-32>>

    encode_explicit_ucs4_native(rest, :big, discard?, [bytes | acc])
  end

  defp encode_explicit_ucs4_native(
         [a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p | rest],
         :little,
         discard?,
         acc
       )
       when a in 0..0xFFFFFFFF and b in 0..0xFFFFFFFF and c in 0..0xFFFFFFFF and
              d in 0..0xFFFFFFFF and e in 0..0xFFFFFFFF and f in 0..0xFFFFFFFF and
              g in 0..0xFFFFFFFF and h in 0..0xFFFFFFFF and i in 0..0xFFFFFFFF and
              j in 0..0xFFFFFFFF and k in 0..0xFFFFFFFF and l in 0..0xFFFFFFFF and
              m in 0..0xFFFFFFFF and n in 0..0xFFFFFFFF and o in 0..0xFFFFFFFF and
              p in 0..0xFFFFFFFF do
    bytes =
      <<a::unsigned-little-32, b::unsigned-little-32, c::unsigned-little-32,
        d::unsigned-little-32, e::unsigned-little-32, f::unsigned-little-32,
        g::unsigned-little-32, h::unsigned-little-32, i::unsigned-little-32,
        j::unsigned-little-32, k::unsigned-little-32, l::unsigned-little-32,
        m::unsigned-little-32, n::unsigned-little-32, o::unsigned-little-32,
        p::unsigned-little-32>>

    encode_explicit_ucs4_native(rest, :little, discard?, [bytes | acc])
  end

  defp encode_explicit_ucs4_native(
         [a, b, c, d, e, f, g, h | rest],
         :big,
         discard?,
         acc
       )
       when a in 0..0xFFFFFFFF and b in 0..0xFFFFFFFF and c in 0..0xFFFFFFFF and
              d in 0..0xFFFFFFFF and e in 0..0xFFFFFFFF and f in 0..0xFFFFFFFF and
              g in 0..0xFFFFFFFF and h in 0..0xFFFFFFFF do
    bytes =
      <<a::unsigned-big-32, b::unsigned-big-32, c::unsigned-big-32, d::unsigned-big-32,
        e::unsigned-big-32, f::unsigned-big-32, g::unsigned-big-32, h::unsigned-big-32>>

    encode_explicit_ucs4_native(rest, :big, discard?, [bytes | acc])
  end

  defp encode_explicit_ucs4_native(
         [a, b, c, d, e, f, g, h | rest],
         :little,
         discard?,
         acc
       )
       when a in 0..0xFFFFFFFF and b in 0..0xFFFFFFFF and c in 0..0xFFFFFFFF and
              d in 0..0xFFFFFFFF and e in 0..0xFFFFFFFF and f in 0..0xFFFFFFFF and
              g in 0..0xFFFFFFFF and h in 0..0xFFFFFFFF do
    bytes =
      <<a::unsigned-little-32, b::unsigned-little-32, c::unsigned-little-32,
        d::unsigned-little-32, e::unsigned-little-32, f::unsigned-little-32,
        g::unsigned-little-32, h::unsigned-little-32>>

    encode_explicit_ucs4_native(rest, :little, discard?, [bytes | acc])
  end

  defp encode_explicit_ucs4_native([codepoint | rest], endian, discard?, acc)
       when codepoint in 0..0xFFFFFFFF,
       do:
         encode_explicit_ucs4_native(
           rest,
           endian,
           discard?,
           [write32(codepoint, endian) | acc]
         )

  defp encode_explicit_ucs4_native([_invalid | rest], endian, true, acc),
    do: encode_explicit_ucs4_native(rest, endian, true, acc)

  defp encode_explicit_ucs4_native([invalid | _rest], _endian, false, _acc),
    do: {:error, :unrepresentable_character, invalid}

  defp fast_encode(fast_codepoints, original, id, discard?, prefix, encoding, fallback) do
    case :unicode.characters_to_binary(fast_codepoints, :unicode, encoding) do
      binary when is_binary(binary) -> {:ok, prepend_if_output(prefix, binary)}
      _error_or_incomplete -> fallback.(original, id, discard?)
    end
  end

  defp filter_utf16_generic([], acc), do: :lists.reverse(acc)

  defp filter_utf16_generic([codepoint | rest], acc)
       when codepoint in 0..0x10FFFF and codepoint not in 0xD800..0xDFFF and
              codepoint != 0xFFFE,
       do: filter_utf16_generic(rest, [codepoint | acc])

  defp filter_utf16_generic([_invalid | rest], acc), do: filter_utf16_generic(rest, acc)

  defp reduce_encode(codepoints, prefix, discard?, encoder) do
    Enum.reduce_while(codepoints, {:ok, []}, fn codepoint, {:ok, acc} ->
      case encoder.(codepoint) do
        {:ok, bytes} -> {:cont, {:ok, [bytes | acc]}}
        :error when discard? -> {:cont, {:ok, acc}}
        :error -> {:halt, {:error, :unrepresentable_character, codepoint}}
      end
    end)
    |> case do
      {:ok, acc} ->
        body = acc |> :lists.reverse() |> IO.iodata_to_binary()
        {:ok, prepend_if_output(prefix, body)}

      error ->
        error
    end
  end

  defp reduce_substitute(codepoints, prefix, replacer, encoder) do
    Enum.reduce_while(codepoints, {:ok, []}, fn codepoint, {:ok, acc} ->
      case encoder.(codepoint) do
        {:ok, bytes} ->
          {:cont, {:ok, [bytes | acc]}}

        :error ->
          case encode_replacement(replacer.(codepoint), encoder, []) do
            {:ok, replacement} -> {:cont, {:ok, [replacement | acc]}}
            error -> {:halt, error}
          end
      end
    end)
    |> case do
      {:ok, acc} ->
        body = acc |> :lists.reverse() |> IO.iodata_to_binary()
        {:ok, prepend_if_output(prefix, body)}

      error ->
        error
    end
  end

  defp prepend_if_output(_prefix, <<>>), do: <<>>
  defp prepend_if_output(prefix, output), do: prefix <> output

  defp encode_replacement([], _encoder, acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_replacement([codepoint | rest], encoder, acc) do
    case encoder.(codepoint) do
      {:ok, bytes} -> encode_replacement(rest, encoder, [bytes | acc])
      :error -> {:error, :unrepresentable_character, codepoint}
    end
  end

  defp valid_scalars(codepoints),
    do: Enum.filter(codepoints, &(&1 in 0..0x10FFFF and &1 not in 0xD800..0xDFFF))

  defp initial_endian(id) when id in [:ucs2le, :ucs4le, :utf16le, :utf32le], do: :little

  defp initial_endian(id) when id in [:ucs2internal, :ucs4internal],
    do: :erlang.system_info(:endian)

  defp initial_endian(id) when id in [:ucs2swapped, :ucs4swapped],
    do: swap(:erlang.system_info(:endian))

  defp initial_endian(_id), do: :big
  defp swap(:big), do: :little
  defp swap(:little), do: :big
  defp read16(<<value::unsigned-big-16>>, :big), do: value
  defp read16(<<value::unsigned-little-16>>, :little), do: value
  defp read32(<<value::unsigned-big-32>>, :big), do: value
  defp read32(<<value::unsigned-little-32>>, :little), do: value
  defp write16(value, :big), do: <<value::unsigned-big-16>>
  defp write16(value, :little), do: <<value::unsigned-little-16>>
  defp write32(value, :big), do: <<value::unsigned-big-32>>
  defp write32(value, :little), do: <<value::unsigned-little-32>>

  defp replace_bytes(acc, <<>>, _replacer), do: acc

  defp replace_bytes(acc, <<byte, rest::binary>>, replacer),
    do: replace_bytes(:lists.reverse(replacer.(byte), acc), rest, replacer)
end
