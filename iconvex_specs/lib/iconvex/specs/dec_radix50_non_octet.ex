defmodule Iconvex.Specs.DECRadix50Base40 do
  @moduledoc false
  import Bitwise
  @chunk_words 1_024

  def pack_value(codepoints, size, encode)
      when is_list(codepoints) and length(codepoints) <= size do
    with {:ok, digits} <- encode_digits(codepoints, encode, []) do
      value = Enum.reduce(digits ++ List.duplicate(0, size - length(digits)), 0, &(&2 * 40 + &1))
      {:ok, value}
    end
  end

  def pack_value(codepoints, _size, _encode) when is_list(codepoints),
    do: {:error, :too_many_characters}

  def unpack_value(value, size, decode, maximum)
      when is_integer(value) and value >= 0 and value <= maximum do
    {:ok, unpack_digits(value, size, decode, [])}
  end

  def unpack_value(_value, _size, _decode, _maximum), do: {:error, :invalid_word}

  def encode_packed(codepoints, size, payload_bits, class_bits, encode)
      when is_list(codepoints) do
    encode_packed_all(codepoints, size, payload_bits + class_bits, encode, [])
  end

  def decode_packed(input, size, payload_bits, class_bits, decode, maximum)
      when is_bitstring(input) do
    decode_packed_all(input, size, payload_bits, class_bits, decode, maximum, 0, [])
  end

  def encode_words(codepoints, size, bytes, endian, encode, discard? \\ false)
      when is_list(codepoints) and endian in [:big, :little] do
    codepoints =
      if discard?, do: Enum.filter(codepoints, &Map.has_key?(encode, &1)), else: codepoints

    encode_words_all(codepoints, size, bytes, endian, encode, [])
  end

  def decode_words(input, size, bytes, payload_bits, decode, maximum, endian, discard? \\ false)
      when is_binary(input) and endian in [:big, :little] do
    decode_words_all(
      input,
      size,
      bytes,
      payload_bits,
      decode,
      maximum,
      endian,
      discard?,
      0,
      []
    )
  end

  def decode_words_to_utf8(input, size, bytes, payload_bits, decode, maximum, endian) do
    decode_utf8_all(input, size, bytes, payload_bits, decode, maximum, endian, 0, [], 0, [])
  end

  def encode_words_from_utf8(input, size, bytes, endian, encode) when is_binary(input) do
    case :unicode.characters_to_list(input, :utf8) do
      codepoints when is_list(codepoints) ->
        encode_utf8_all(input, size, bytes, endian, encode, [], 0, [])

      {:incomplete, converted, rest} ->
        encode_prefix_or_utf8_error(
          converted,
          size,
          bytes,
          endian,
          encode,
          :incomplete_sequence,
          byte_size(input) - byte_size(rest),
          rest
        )

      {:error, converted, rest} ->
        encode_prefix_or_utf8_error(
          converted,
          size,
          bytes,
          endian,
          encode,
          :invalid_sequence,
          byte_size(input) - byte_size(rest),
          rest
        )
    end
  end

  defp encode_prefix_or_utf8_error(converted, size, bytes, endian, encode, kind, offset, rest) do
    case encode_words(converted, size, bytes, endian, encode) do
      {:error, _, _} = error -> error
      {:ok, _encoded_prefix} -> {:decode_error, kind, offset, rest}
    end
  end

  defp decode_utf8_all(
         <<>>,
         _size,
         _bytes,
         _payload_bits,
         _decode,
         _maximum,
         _endian,
         _offset,
         byte_acc,
         _count,
         chunks
       ),
       do: {:ok, finish_binary(byte_acc, chunks)}

  defp decode_utf8_all(
         input,
         _size,
         bytes,
         _payload_bits,
         _decode,
         _maximum,
         _endian,
         offset,
         _byte_acc,
         _count,
         _chunks
       )
       when byte_size(input) < bytes,
       do: {:error, :incomplete_sequence, offset, input}

  defp decode_utf8_all(
         input,
         size,
         bytes,
         payload_bits,
         decode,
         maximum,
         endian,
         offset,
         byte_acc,
         count,
         chunks
       ) do
    <<raw::binary-size(bytes), rest::binary>> = input
    word = :binary.decode_unsigned(raw, endian)
    class = div(word, 1 <<< payload_bits)
    value = rem(word, 1 <<< payload_bits)

    if class == 0 and value <= maximum do
      next_bytes = prepend_reverse_digits(value, size, decode, byte_acc)

      if count == @chunk_words - 1 do
        chunk = next_bytes |> :lists.reverse() |> :erlang.list_to_binary()

        decode_utf8_all(
          rest,
          size,
          bytes,
          payload_bits,
          decode,
          maximum,
          endian,
          offset + bytes,
          [],
          0,
          [chunk | chunks]
        )
      else
        decode_utf8_all(
          rest,
          size,
          bytes,
          payload_bits,
          decode,
          maximum,
          endian,
          offset + bytes,
          next_bytes,
          count + 1,
          chunks
        )
      end
    else
      {:error, :invalid_sequence, offset, raw}
    end
  end

  defp encode_utf8_all(<<>>, _size, _bytes, _endian, _encode, byte_acc, _count, chunks),
    do: {:ok, finish_binary(byte_acc, chunks)}

  defp encode_utf8_all(input, size, bytes, endian, encode, byte_acc, count, chunks) do
    case take_utf8_value(input, size, encode, 0) do
      {:ok, value, rest} ->
        next_bytes = prepend_reverse_word(value, bytes, endian, byte_acc)

        if count == @chunk_words - 1 do
          chunk = next_bytes |> :lists.reverse() |> :erlang.list_to_binary()
          encode_utf8_all(rest, size, bytes, endian, encode, [], 0, [chunk | chunks])
        else
          encode_utf8_all(rest, size, bytes, endian, encode, next_bytes, count + 1, chunks)
        end

      error ->
        error
    end
  end

  defp take_utf8_value(input, 0, _encode, value), do: {:ok, value, input}

  defp take_utf8_value(<<>>, remaining, _encode, value),
    do: {:ok, value * power40(remaining), <<>>}

  defp take_utf8_value(<<codepoint, rest::binary>>, remaining, encode, value)
       when codepoint < 0x80 do
    case encode do
      %{^codepoint => digit} -> take_utf8_value(rest, remaining - 1, encode, value * 40 + digit)
      _ -> {:error, :unrepresentable_character, codepoint}
    end
  end

  defp take_utf8_value(<<codepoint::utf8, _rest::binary>>, _remaining, _encode, _value),
    do: {:error, :unrepresentable_character, codepoint}

  defp finish_binary([], chunks),
    do: chunks |> :lists.reverse() |> IO.iodata_to_binary()

  defp finish_binary(bytes, chunks) do
    chunk = bytes |> :lists.reverse() |> :erlang.list_to_binary()
    [chunk | chunks] |> :lists.reverse() |> IO.iodata_to_binary()
  end

  defp prepend_reverse_word(value, 5, :big, acc) do
    [
      value &&& 0xFF,
      value >>> 8 &&& 0xFF,
      value >>> 16 &&& 0xFF,
      value >>> 24 &&& 0xFF,
      0
      | acc
    ]
  end

  defp prepend_reverse_word(value, 5, :little, acc) do
    [
      0,
      value >>> 24 &&& 0xFF,
      value >>> 16 &&& 0xFF,
      value >>> 8 &&& 0xFF,
      value &&& 0xFF
      | acc
    ]
  end

  defp prepend_reverse_word(value, 3, :big, acc) do
    [value &&& 0xFF, value >>> 8 &&& 0xFF, 0 | acc]
  end

  defp prepend_reverse_word(value, 3, :little, acc) do
    [0, value >>> 8 &&& 0xFF, value &&& 0xFF | acc]
  end

  defp encode_packed_all([], _size, _word_bits, _encode, chunks),
    do: {:ok, chunks |> :lists.reverse() |> :erlang.list_to_bitstring()}

  defp encode_packed_all(codepoints, size, word_bits, encode, chunks) do
    {group, rest} = Enum.split(codepoints, size)

    case pack_value(group, size, encode) do
      {:ok, value} ->
        encode_packed_all(rest, size, word_bits, encode, [<<value::size(word_bits)>> | chunks])

      error ->
        error
    end
  end

  defp decode_packed_all(
         <<>>,
         _size,
         _payload_bits,
         _class_bits,
         _decode,
         _maximum,
         _offset,
         acc
       ),
       do: {:ok, :lists.reverse(acc)}

  defp decode_packed_all(
         input,
         _size,
         payload_bits,
         class_bits,
         _decode,
         _maximum,
         offset,
         _acc
       )
       when bit_size(input) < payload_bits + class_bits,
       do: {:error, :incomplete_sequence, offset, input}

  defp decode_packed_all(input, size, payload_bits, class_bits, decode, maximum, offset, acc) do
    word_bits = payload_bits + class_bits
    <<class::size(class_bits), value::size(payload_bits), rest::bitstring>> = input
    raw = <<class::size(class_bits), value::size(payload_bits)>>

    if class == 0 and value <= maximum do
      {:ok, codepoints} = unpack_value(value, size, decode, maximum)

      decode_packed_all(
        rest,
        size,
        payload_bits,
        class_bits,
        decode,
        maximum,
        offset + word_bits,
        :lists.reverse(codepoints, acc)
      )
    else
      {:error, :invalid_sequence, offset, raw}
    end
  end

  defp encode_words_all([], _size, _bytes, _endian, _encode, chunks),
    do: {:ok, chunks |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_words_all(codepoints, size, bytes, endian, encode, chunks) do
    {group, rest} = Enum.split(codepoints, size)

    case pack_value(group, size, encode) do
      {:ok, value} ->
        raw = encode_unsigned(value, bytes, endian)
        encode_words_all(rest, size, bytes, endian, encode, [raw | chunks])

      error ->
        error
    end
  end

  defp decode_words_all(
         <<>>,
         _size,
         _bytes,
         _payload_bits,
         _decode,
         _maximum,
         _endian,
         _discard?,
         _offset,
         acc
       ),
       do: {:ok, :lists.reverse(acc)}

  defp decode_words_all(
         input,
         _size,
         bytes,
         _payload_bits,
         _decode,
         _maximum,
         _endian,
         true,
         _offset,
         acc
       )
       when byte_size(input) < bytes,
       do: {:ok, :lists.reverse(acc)}

  defp decode_words_all(
         input,
         _size,
         bytes,
         _payload_bits,
         _decode,
         _maximum,
         _endian,
         false,
         offset,
         _acc
       )
       when byte_size(input) < bytes,
       do: {:error, :incomplete_sequence, offset, input}

  defp decode_words_all(
         input,
         size,
         bytes,
         payload_bits,
         decode,
         maximum,
         endian,
         discard?,
         offset,
         acc
       ) do
    <<raw::binary-size(bytes), rest::binary>> = input
    word = :binary.decode_unsigned(raw, endian)
    class = div(word, 1 <<< payload_bits)
    value = rem(word, 1 <<< payload_bits)

    cond do
      class == 0 and value <= maximum ->
        {:ok, codepoints} = unpack_value(value, size, decode, maximum)

        decode_words_all(
          rest,
          size,
          bytes,
          payload_bits,
          decode,
          maximum,
          endian,
          discard?,
          offset + bytes,
          :lists.reverse(codepoints, acc)
        )

      discard? ->
        decode_words_all(
          rest,
          size,
          bytes,
          payload_bits,
          decode,
          maximum,
          endian,
          true,
          offset + bytes,
          acc
        )

      true ->
        {:error, :invalid_sequence, offset, raw}
    end
  end

  defp encode_digits([], _encode, acc), do: {:ok, :lists.reverse(acc)}

  defp encode_digits([codepoint | rest], encode, acc) do
    case encode do
      %{^codepoint => digit} -> encode_digits(rest, encode, [digit | acc])
      _ -> {:error, :unrepresentable_character, codepoint}
    end
  end

  defp unpack_digits(_value, 0, _decode, acc), do: :lists.reverse(acc)

  defp unpack_digits(value, remaining, decode, acc) do
    divisor = power40(remaining - 1)
    digit = div(value, divisor)
    unpack_digits(rem(value, divisor), remaining - 1, decode, [elem(decode, digit) | acc])
  end

  defp prepend_reverse_digits(_value, 0, _decode, acc), do: acc

  defp prepend_reverse_digits(value, remaining, decode, acc) do
    divisor = power40(remaining - 1)
    digit = div(value, divisor)

    prepend_reverse_digits(
      rem(value, divisor),
      remaining - 1,
      decode,
      [elem(decode, digit) | acc]
    )
  end

  defp power40(0), do: 1
  defp power40(1), do: 40
  defp power40(2), do: 1_600
  defp power40(3), do: 64_000
  defp power40(4), do: 2_560_000
  defp power40(5), do: 102_400_000

  defp encode_unsigned(value, bytes, :big),
    do: <<value::unsigned-big-size(bytes * 8)>>

  defp encode_unsigned(value, bytes, :little),
    do: <<value::unsigned-little-size(bytes * 8)>>
end

defmodule Iconvex.Specs.DECRadix50PDP10 do
  @moduledoc "DEC PDP-6/10 36-bit RADIX50/SQUOZE with six base-40 digits and four tag bits."

  alias Iconvex.Specs.DECRadix50Base40, as: Base40

  @source_path Path.expand(
                 "../../../priv/sources/dec-radix-50/AA-C780C-TB_Macro_Assembler_Reference_Manual_Apr78.pdf",
                 __DIR__
               )
  @external_resource @source_path
  @alphabet String.to_charlist(" 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ.$%")
  @decode List.to_tuple(@alphabet)
  @encode @alphabet |> Enum.with_index() |> Map.new()
  @maximum 4_095_999_999

  def canonical_name, do: "DEC-RADIX-50-36BIT"
  def unit_bits, do: 36
  def payload_bits, do: 32
  def characters_per_word, do: 6
  def source_pages, do: [86, 165, 166, 167]
  def printed_source_pages, do: ["3-56", "A-1", "A-2", "A-3"]

  def source_url,
    do:
      "https://bitsavers.org/pdf/dec/pdp10/TOPS10_softwareNotebooks/vol13/AA-C780C-TB_Macro_Assembler_Reference_Manual_Apr78.pdf"

  def transport_codecs,
    do: [Iconvex.Specs.DECRadix50PDP10BE40, Iconvex.Specs.DECRadix50PDP10LE40]

  def pack_value(codepoints), do: Base40.pack_value(codepoints, 6, @encode)
  def unpack_value(value), do: Base40.unpack_value(value, 6, @decode, @maximum)

  def pack_word(codepoints, tag \\ 0) when tag in 0..15 do
    with {:ok, value} <- pack_value(codepoints), do: {:ok, tag * 0x1_0000_0000 + value}
  end

  def unpack_word(word) when is_integer(word) and word in 0..0xF_FFFF_FFFF do
    tag = div(word, 0x1_0000_0000)
    value = rem(word, 0x1_0000_0000)

    with {:ok, codepoints} <- unpack_value(value), do: {:ok, tag, codepoints}
  end

  def unpack_word(_word), do: {:error, :invalid_word}
  def encode_packed(codepoints), do: Base40.encode_packed(codepoints, 6, 32, 4, @encode)
  def decode_packed(input), do: Base40.decode_packed(input, 6, 32, 4, @decode, @maximum)

  def encode_words(codepoints, endian, discard? \\ false),
    do: Base40.encode_words(codepoints, 6, 5, endian, @encode, discard?)

  def decode_words(input, endian, discard? \\ false),
    do: Base40.decode_words(input, 6, 5, 32, @decode, @maximum, endian, discard?)

  def decode_words_to_utf8(input, endian),
    do: Base40.decode_words_to_utf8(input, 6, 5, 32, @decode, @maximum, endian)

  def encode_words_from_utf8(input, endian),
    do: Base40.encode_words_from_utf8(input, 6, 5, endian, @encode)
end

defmodule Iconvex.Specs.DECRadix50PDP9 do
  @moduledoc "DEC PDP-9/15 RADIX 50 base-40 words with three digits and two classification bits."

  alias Iconvex.Specs.DECRadix50Base40, as: Base40

  @source_path Path.expand(
                 "../../../priv/sources/dec-radix-50/DEC-9A-GUAB-D_UTILITIES.pdf",
                 __DIR__
               )
  @external_resource @source_path
  @alphabet [0x20] ++ Enum.to_list(?A..?Z) ++ [?%, ?.] ++ Enum.to_list(?0..?9) ++ [?#]
  @decode List.to_tuple(@alphabet)
  @encode @alphabet |> Enum.with_index() |> Map.new()
  @maximum 63_999

  def canonical_name, do: "DEC-RADIX-50-18BIT"
  def unit_bits, do: 18
  def payload_bits, do: 16
  def characters_per_word, do: 3
  def source_page, do: 133
  def printed_source_page, do: "A1-1"

  def source_url,
    do: "https://www.bitsavers.org/pdf/dec/pdp9/DEC-9A-GUAB-D_UTILITIES.pdf"

  def transport_codecs,
    do: [Iconvex.Specs.DECRadix50PDP9BE24, Iconvex.Specs.DECRadix50PDP9LE24]

  def pack_value(codepoints), do: Base40.pack_value(codepoints, 3, @encode)
  def unpack_value(value), do: Base40.unpack_value(value, 3, @decode, @maximum)

  def pack_word(codepoints, class \\ 0) when class in 0..3 do
    with {:ok, value} <- pack_value(codepoints), do: {:ok, class * 65_536 + value}
  end

  def unpack_word(word) when is_integer(word) and word in 0..0x3FFFF do
    class = div(word, 65_536)
    value = rem(word, 65_536)

    with {:ok, codepoints} <- unpack_value(value), do: {:ok, class, codepoints}
  end

  def unpack_word(_word), do: {:error, :invalid_word}

  def pack_symbol(codepoints) when is_list(codepoints) and length(codepoints) in 1..6 do
    {first, second} = Enum.split(codepoints, 3)

    with {:ok, first_value} <- pack_value(first) do
      if second == [] do
        {:ok, <<0::2, first_value::16>>}
      else
        with {:ok, second_value} <- pack_value(second),
             do: {:ok, <<2::2, first_value::16, 0::2, second_value::16>>}
      end
    end
  end

  def pack_symbol(codepoints) when is_list(codepoints), do: {:error, :invalid_symbol_length}
  def encode_packed(codepoints), do: Base40.encode_packed(codepoints, 3, 16, 2, @encode)
  def decode_packed(input), do: Base40.decode_packed(input, 3, 16, 2, @decode, @maximum)

  def encode_words(codepoints, endian, discard? \\ false),
    do: Base40.encode_words(codepoints, 3, 3, endian, @encode, discard?)

  def decode_words(input, endian, discard? \\ false),
    do: Base40.decode_words(input, 3, 3, 16, @decode, @maximum, endian, discard?)

  def decode_words_to_utf8(input, endian),
    do: Base40.decode_words_to_utf8(input, 3, 3, 16, @decode, @maximum, endian)

  def encode_words_from_utf8(input, endian),
    do: Base40.encode_words_from_utf8(input, 3, 3, endian, @encode)
end

defmodule Iconvex.Specs.DECRadix50PDP10BE40 do
  @moduledoc "DEC PDP-10 RADIX50 36-bit words in zero-padded 40-bit big-endian storage."
  use Iconvex.Codec
  alias Iconvex.Specs.DECRadix50PDP10, as: Codec
  def canonical_name, do: "DEC-RADIX-50-36BIT-40BE"

  def aliases,
    do: ["DEC-RADIX-50-PDP10-40BE", "DEC-SQUOZE", "PDP-10-RADIX-50", "PDP-10-RADIX50", "SQUOZE"]

  def codec_id, do: :dec_radix50_pdp10_40be
  def decode(input), do: Codec.decode_words(input, :big)
  def decode_discard(input), do: Codec.decode_words(input, :big, true)
  def decode_to_utf8(input), do: Codec.decode_words_to_utf8(input, :big)
  def encode(codepoints), do: Codec.encode_words(codepoints, :big)
  def encode_discard(codepoints), do: Codec.encode_words(codepoints, :big, true)

  def encode_substitute(codepoints, replacer),
    do:
      Iconvex.Specs.CodecSupport.encode_substitute_transform(
        codepoints,
        &encode/1,
        replacer
      )

  def encode_from_utf8(input), do: Codec.encode_words_from_utf8(input, :big)
end

defmodule Iconvex.Specs.DECRadix50PDP10LE40 do
  @moduledoc "DEC PDP-10 RADIX50 36-bit words in zero-padded 40-bit little-endian storage."
  use Iconvex.Codec
  alias Iconvex.Specs.DECRadix50PDP10, as: Codec
  def canonical_name, do: "DEC-RADIX-50-36BIT-40LE"
  def aliases, do: ["DEC-RADIX-50-PDP10-40LE", "PDP-10-RADIX-50-LE", "PDP-10-RADIX50-LE"]
  def codec_id, do: :dec_radix50_pdp10_40le
  def decode(input), do: Codec.decode_words(input, :little)
  def decode_discard(input), do: Codec.decode_words(input, :little, true)
  def decode_to_utf8(input), do: Codec.decode_words_to_utf8(input, :little)
  def encode(codepoints), do: Codec.encode_words(codepoints, :little)
  def encode_discard(codepoints), do: Codec.encode_words(codepoints, :little, true)

  def encode_substitute(codepoints, replacer),
    do:
      Iconvex.Specs.CodecSupport.encode_substitute_transform(
        codepoints,
        &encode/1,
        replacer
      )

  def encode_from_utf8(input), do: Codec.encode_words_from_utf8(input, :little)
end

defmodule Iconvex.Specs.DECRadix50PDP9BE24 do
  @moduledoc "DEC PDP-9/15 RADIX50 18-bit words in zero-padded 24-bit big-endian storage."
  use Iconvex.Codec
  alias Iconvex.Specs.DECRadix50PDP9, as: Codec
  def canonical_name, do: "DEC-RADIX-50-18BIT-24BE"

  def aliases,
    do: ["PDP-9-RADIX-50", "PDP-15-RADIX-50", "RADIX-50-18BIT", "DEC-RADIX-50-PDP9-24BE"]

  def codec_id, do: :dec_radix50_pdp9_24be
  def decode(input), do: Codec.decode_words(input, :big)
  def decode_discard(input), do: Codec.decode_words(input, :big, true)
  def decode_to_utf8(input), do: Codec.decode_words_to_utf8(input, :big)
  def encode(codepoints), do: Codec.encode_words(codepoints, :big)
  def encode_discard(codepoints), do: Codec.encode_words(codepoints, :big, true)

  def encode_substitute(codepoints, replacer),
    do:
      Iconvex.Specs.CodecSupport.encode_substitute_transform(
        codepoints,
        &encode/1,
        replacer
      )

  def encode_from_utf8(input), do: Codec.encode_words_from_utf8(input, :big)
end

defmodule Iconvex.Specs.DECRadix50PDP9LE24 do
  @moduledoc "DEC PDP-9/15 RADIX50 18-bit words in zero-padded 24-bit little-endian storage."
  use Iconvex.Codec
  alias Iconvex.Specs.DECRadix50PDP9, as: Codec
  def canonical_name, do: "DEC-RADIX-50-18BIT-24LE"
  def aliases, do: ["PDP-9-RADIX-50-LE", "PDP-15-RADIX-50-LE", "DEC-RADIX-50-PDP9-24LE"]
  def codec_id, do: :dec_radix50_pdp9_24le
  def decode(input), do: Codec.decode_words(input, :little)
  def decode_discard(input), do: Codec.decode_words(input, :little, true)
  def decode_to_utf8(input), do: Codec.decode_words_to_utf8(input, :little)
  def encode(codepoints), do: Codec.encode_words(codepoints, :little)
  def encode_discard(codepoints), do: Codec.encode_words(codepoints, :little, true)

  def encode_substitute(codepoints, replacer),
    do:
      Iconvex.Specs.CodecSupport.encode_substitute_transform(
        codepoints,
        &encode/1,
        replacer
      )

  def encode_from_utf8(input), do: Codec.encode_words_from_utf8(input, :little)
end
