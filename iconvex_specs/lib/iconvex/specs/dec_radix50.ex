defmodule Iconvex.Specs.DECRadix50 do
  @moduledoc """
  DEC PDP-11 RADIX-50 (also called MOD40) word packing.

  Three characters are base-40 digits in one 16-bit word. The logical word
  value is `((i * 40) + j) * 40 + k`; byte codecs expose both endian orders.
  Short final groups are right-padded with spaces.
  """

  @source_path Path.expand(
                 "../../../priv/sources/dec-radix-50/DEC-11-LFLRA_FORTRAN_Language_Reference_Manual_Jun77.pdf",
                 __DIR__
               )
  @external_resource @source_path

  @decode List.to_tuple([0x20] ++ Enum.to_list(?A..?Z) ++ [?$, ?., nil] ++ Enum.to_list(?0..?9))
  @chunk_words 1_024

  def source_page, do: 145
  def printed_source_page, do: "A-3"

  def source_url,
    do:
      "https://www.bitsavers.org/pdf/dec/pdp11/rt11/v4.0_Mar80/4_fortran/DEC-11-LFLRA_FORTRAN_Language_Reference_Manual_Jun77.pdf"

  def word_bits, do: 16
  def radix, do: 40
  def characters_per_word, do: 3
  def transport_codecs, do: [Iconvex.Specs.DECRadix50BE16, Iconvex.Specs.DECRadix50LE16]

  def pack_digits([i, j, k])
      when i in 0..39 and j in 0..39 and k in 0..39,
      do: (i * 40 + j) * 40 + k

  def unpack_word(word) when is_integer(word) and word in 0..63_999 do
    case word_characters(word) do
      {:ok, first, second, third} -> {:ok, [first, second, third]}
      :error -> {:error, :unassigned_digit}
    end
  end

  def unpack_word(_word), do: {:error, :invalid_word}

  def pack_codepoints(codepoints) when is_list(codepoints) and length(codepoints) <= 3 do
    case encode_digits(codepoints, []) do
      {:ok, digits} -> {:ok, digits |> pad_digits() |> pack_digits()}
      error -> error
    end
  end

  def pack_codepoints(codepoints) when is_list(codepoints),
    do: {:error, :too_many_characters}

  def decode_words(input, endian, discard? \\ false)
      when is_binary(input) and endian in [:big, :little],
      do: decode_all(input, endian, discard?, 0, [])

  def encode_words(codepoints, endian, discard? \\ false)
      when is_list(codepoints) and endian in [:big, :little],
      do: encode_all(codepoints, endian, discard?, [])

  def decode_words_to_utf8(input, :big), do: decode_utf8_big(input, 0, [], 0, [])
  def decode_words_to_utf8(input, :little), do: decode_utf8_little(input, 0, [], 0, [])

  def encode_words_from_utf8(input, endian) when is_binary(input) do
    Iconvex.Specs.CodecSupport.encode_utf8(
      input,
      &encode_utf8_all(&1, endian, [], 0, []),
      &encode_words(&1, endian)
    )
  end

  defp decode_utf8_big(<<>>, _offset, bytes, _count, chunks),
    do: {:ok, finish_binary(bytes, chunks)}

  defp decode_utf8_big(input, offset, _bytes, _count, _chunks) when byte_size(input) < 2,
    do: {:error, :incomplete_sequence, offset, input}

  defp decode_utf8_big(<<word::16-big, rest::binary>>, offset, bytes, count, chunks) do
    decode_utf8_word(word, <<word::16-big>>, rest, :big, offset, bytes, count, chunks)
  end

  defp decode_utf8_little(<<>>, _offset, bytes, _count, chunks),
    do: {:ok, finish_binary(bytes, chunks)}

  defp decode_utf8_little(input, offset, _bytes, _count, _chunks) when byte_size(input) < 2,
    do: {:error, :incomplete_sequence, offset, input}

  defp decode_utf8_little(<<low, high, rest::binary>>, offset, bytes, count, chunks) do
    decode_utf8_word(low + high * 256, <<low, high>>, rest, :little, offset, bytes, count, chunks)
  end

  defp decode_utf8_word(word, raw, rest, endian, offset, bytes, count, chunks) do
    case word_characters(word) do
      {:ok, first, second, third} ->
        next_bytes = [third, second, first | bytes]

        if count == @chunk_words - 1 do
          chunk = next_bytes |> :lists.reverse() |> :erlang.list_to_binary()
          decode_utf8_next(rest, endian, offset + 2, [], 0, [chunk | chunks])
        else
          decode_utf8_next(rest, endian, offset + 2, next_bytes, count + 1, chunks)
        end

      :error ->
        {:error, :invalid_sequence, offset, raw}
    end
  end

  defp decode_utf8_next(input, :big, offset, bytes, count, chunks),
    do: decode_utf8_big(input, offset, bytes, count, chunks)

  defp decode_utf8_next(input, :little, offset, bytes, count, chunks),
    do: decode_utf8_little(input, offset, bytes, count, chunks)

  defp encode_utf8_all(<<>>, _endian, bytes, _count, chunks),
    do: {:ok, finish_binary(bytes, chunks)}

  defp encode_utf8_all(<<first>>, endian, bytes, count, chunks) when first < 0x80,
    do: encode_utf8_group(first, 0x20, 0x20, <<>>, endian, bytes, count, chunks)

  defp encode_utf8_all(<<first, second>>, endian, bytes, count, chunks)
       when first < 0x80 and second < 0x80,
       do: encode_utf8_group(first, second, 0x20, <<>>, endian, bytes, count, chunks)

  defp encode_utf8_all(
         <<first, second, third, rest::binary>>,
         endian,
         bytes,
         count,
         chunks
       )
       when first < 0x80 and second < 0x80 and third < 0x80,
       do: encode_utf8_group(first, second, third, rest, endian, bytes, count, chunks)

  defp encode_utf8_all(input, _endian, _bytes, _count, _chunks) do
    {:error, :unrepresentable_character, first_unrepresentable_utf8(input)}
  end

  defp encode_utf8_group(first, second, third, rest, endian, bytes, count, chunks) do
    i = digit_value(first)
    j = digit_value(second)
    k = digit_value(third)

    cond do
      i < 0 ->
        {:error, :unrepresentable_character, first}

      j < 0 ->
        {:error, :unrepresentable_character, second}

      k < 0 ->
        {:error, :unrepresentable_character, third}

      true ->
        word = (i * 40 + j) * 40 + k
        next_bytes = reverse_word_bytes(word, endian, bytes)

        if count == @chunk_words - 1 do
          chunk = next_bytes |> :lists.reverse() |> :erlang.list_to_binary()
          encode_utf8_all(rest, endian, [], 0, [chunk | chunks])
        else
          encode_utf8_all(rest, endian, next_bytes, count + 1, chunks)
        end
    end
  end

  defp decode_all(<<>>, _endian, _discard?, _offset, acc),
    do: {:ok, :lists.reverse(acc)}

  defp decode_all(input, _endian, true, _offset, acc) when byte_size(input) < 2,
    do: {:ok, :lists.reverse(acc)}

  defp decode_all(input, _endian, false, offset, _acc) when byte_size(input) < 2,
    do: {:error, :incomplete_sequence, offset, input}

  defp decode_all(input, endian, discard?, offset, acc) do
    {word, raw, rest} = next_word(input, endian)

    case unpack_word(word) do
      {:ok, [first, second, third]} ->
        decode_all(rest, endian, discard?, offset + 2, [third, second, first | acc])

      {:error, _reason} when discard? ->
        decode_all(rest, endian, true, offset + 2, acc)

      {:error, _reason} ->
        {:error, :invalid_sequence, offset, raw}
    end
  end

  defp encode_all([], _endian, _discard?, acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_all(codepoints, endian, discard?, acc) do
    {group, rest} = take_group(codepoints, discard?, [])

    case group do
      {:error, codepoint} ->
        {:error, :unrepresentable_character, codepoint}

      [] ->
        {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

      digits ->
        word = digits |> :lists.reverse() |> pad_digits() |> pack_digits()
        encode_all(rest, endian, discard?, [word_bytes(word, endian) | acc])
    end
  end

  defp take_group(rest, _discard?, acc) when length(acc) == 3, do: {acc, rest}
  defp take_group([], _discard?, acc), do: {acc, []}

  defp take_group([codepoint | rest], discard?, acc) do
    case digit(codepoint) do
      {:ok, value} -> take_group(rest, discard?, [value | acc])
      :error when discard? -> take_group(rest, true, acc)
      :error -> {{:error, codepoint}, rest}
    end
  end

  defp encode_digits([], acc), do: {:ok, :lists.reverse(acc)}

  defp encode_digits([codepoint | rest], acc) do
    case digit(codepoint) do
      {:ok, value} -> encode_digits(rest, [value | acc])
      :error -> {:error, :unrepresentable_character, codepoint}
    end
  end

  defp pad_digits(digits), do: digits ++ List.duplicate(0, 3 - length(digits))

  defp digit(codepoint) do
    case digit_value(codepoint) do
      -1 -> :error
      value -> {:ok, value}
    end
  end

  defp digit_value(0x20), do: 0
  defp digit_value(codepoint) when codepoint in ?A..?Z, do: codepoint - ?A + 1
  defp digit_value(?$), do: 27
  defp digit_value(?.), do: 28
  defp digit_value(codepoint) when codepoint in ?0..?9, do: codepoint - ?0 + 30
  defp digit_value(_codepoint), do: -1

  defp word_characters(word) when word in 0..63_999 do
    i = div(word, 1_600)
    remainder = rem(word, 1_600)
    j = div(remainder, 40)
    k = rem(remainder, 40)

    case {elem(@decode, i), elem(@decode, j), elem(@decode, k)} do
      {nil, _, _} -> :error
      {_, nil, _} -> :error
      {_, _, nil} -> :error
      {first, second, third} -> {:ok, first, second, third}
    end
  end

  defp word_characters(_word), do: :error

  defp next_word(<<word::16-big, rest::binary>>, :big), do: {word, <<word::16-big>>, rest}

  defp next_word(<<low, high, rest::binary>>, :little),
    do: {low + high * 256, <<low, high>>, rest}

  defp word_bytes(word, :big), do: <<word::16-big>>
  defp word_bytes(word, :little), do: <<word::16-little>>

  defp reverse_word_bytes(word, :big, bytes),
    do: [rem(word, 256), div(word, 256) | bytes]

  defp reverse_word_bytes(word, :little, bytes),
    do: [div(word, 256), rem(word, 256) | bytes]

  defp finish_binary([], chunks),
    do: chunks |> :lists.reverse() |> IO.iodata_to_binary()

  defp finish_binary(bytes, chunks) do
    chunk = bytes |> :lists.reverse() |> :erlang.list_to_binary()
    [chunk | chunks] |> :lists.reverse() |> IO.iodata_to_binary()
  end

  defp first_unrepresentable_utf8(<<codepoint::utf8, rest::binary>>) do
    case digit(codepoint) do
      {:ok, _value} -> first_unrepresentable_utf8(rest)
      :error -> codepoint
    end
  end
end

defmodule Iconvex.Specs.DECRadix50BE16 do
  @moduledoc "DEC PDP-11 RADIX-50 words serialized in explicit big-endian byte order."
  use Iconvex.Codec
  alias Iconvex.Specs.DECRadix50

  @impl true
  def canonical_name, do: "DEC-RADIX-50-16BE"
  @impl true
  def aliases, do: ["DEC-RADIX-50-BE", "DEC-RADIX50-BE", "PDP-11-RADIX-50-BE"]
  @impl true
  def codec_id, do: :dec_radix50_16be
  @impl true
  def decode(input), do: DECRadix50.decode_words(input, :big)
  @impl true
  def decode_discard(input), do: DECRadix50.decode_words(input, :big, true)
  @impl true
  def decode_to_utf8(input), do: DECRadix50.decode_words_to_utf8(input, :big)
  @impl true
  def encode(codepoints), do: DECRadix50.encode_words(codepoints, :big)
  @impl true
  def encode_discard(codepoints), do: DECRadix50.encode_words(codepoints, :big, true)
  @impl true
  def encode_substitute(codepoints, replacer),
    do:
      Iconvex.Specs.CodecSupport.encode_substitute_transform(
        codepoints,
        &encode/1,
        replacer
      )

  @impl true
  def encode_from_utf8(input), do: DECRadix50.encode_words_from_utf8(input, :big)
end

defmodule Iconvex.Specs.DECRadix50LE16 do
  @moduledoc "DEC PDP-11 RADIX-50 words serialized in native PDP-11 little-endian byte order."
  use Iconvex.Codec
  alias Iconvex.Specs.DECRadix50

  @impl true
  def canonical_name, do: "DEC-RADIX-50-16LE"
  @impl true
  def aliases,
    do: [
      "DEC-RADIX-50",
      "DEC-RADIX50",
      "DEC-RADIX-50-LE",
      "MOD40",
      "PDP-11-RAD50",
      "PDP-11-RADIX-50",
      "RAD50",
      "RADIX-50"
    ]

  @impl true
  def codec_id, do: :dec_radix50_16le
  @impl true
  def decode(input), do: DECRadix50.decode_words(input, :little)
  @impl true
  def decode_discard(input), do: DECRadix50.decode_words(input, :little, true)
  @impl true
  def decode_to_utf8(input), do: DECRadix50.decode_words_to_utf8(input, :little)
  @impl true
  def encode(codepoints), do: DECRadix50.encode_words(codepoints, :little)
  @impl true
  def encode_discard(codepoints), do: DECRadix50.encode_words(codepoints, :little, true)
  @impl true
  def encode_substitute(codepoints, replacer),
    do:
      Iconvex.Specs.CodecSupport.encode_substitute_transform(
        codepoints,
        &encode/1,
        replacer
      )

  @impl true
  def encode_from_utf8(input), do: DECRadix50.encode_words_from_utf8(input, :little)
end
