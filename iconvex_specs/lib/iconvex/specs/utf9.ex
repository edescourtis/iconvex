defmodule Iconvex.Specs.UTF9 do
  @moduledoc """
  RFC 4042 UTF-9 over native 9-bit nonets.

  Packed values are Elixir bitstrings in network bit order. Byte-oriented
  callers should use the explicit `UTF-9-16BE` or `UTF-9-16LE` transports.
  """

  import Bitwise

  def canonical_name, do: "UTF-9"
  def unit_bits, do: 9
  def transport_codecs, do: [Iconvex.Specs.UTF9BE16, Iconvex.Specs.UTF9LE16]

  def encode_packed(codepoints) do
    case encode_packed_all(codepoints, []) do
      {:ok, chunks} -> {:ok, chunks |> :lists.reverse() |> :erlang.list_to_bitstring()}
      error -> error
    end
  end

  def decode_packed(input) when is_bitstring(input), do: decode_packed_all(input, 0, [])

  def encode_words(codepoints, endian, discard? \\ false) when endian in [:big, :little] do
    case encode_words_all(codepoints, endian, discard?, []) do
      {:ok, chunks} -> {:ok, chunks |> :lists.reverse() |> IO.iodata_to_binary()}
      error -> error
    end
  end

  def decode_words(input, endian, discard? \\ false)
      when is_binary(input) and endian in [:big, :little],
      do: decode_words_all(input, endian, discard?, 0, nil, [])

  def decode_words_to_utf8(input, endian) do
    case decode_words(input, endian) do
      {:ok, codepoints} -> {:ok, List.to_string(codepoints)}
      error -> error
    end
  end

  def encode_words_from_utf8(input, endian) do
    case :unicode.characters_to_list(input, :utf8) do
      codepoints when is_list(codepoints) ->
        case encode_words(codepoints, endian) do
          {:error, :unrepresentable_character, codepoint} ->
            {:encode_error, :unrepresentable_character, codepoint}

          result ->
            result
        end

      {:incomplete, _converted, rest} ->
        {:decode_error, :incomplete_sequence, byte_size(input) - byte_size(rest), rest}

      {:error, _converted, rest} ->
        {:decode_error, :invalid_sequence, byte_size(input) - byte_size(rest), rest}
    end
  end

  defp encode_packed_all([], acc), do: {:ok, acc}

  defp encode_packed_all([codepoint | rest], acc) do
    case packed_scalar(codepoint) do
      {:ok, encoded} -> encode_packed_all(rest, [encoded | acc])
      :error -> {:error, :unrepresentable_character, codepoint}
    end
  end

  defp packed_scalar(codepoint) when codepoint in 0..0xFF,
    do: {:ok, <<codepoint::9>>}

  defp packed_scalar(codepoint)
       when codepoint in 0x100..0xFFFF and codepoint not in 0xD800..0xDFFF,
       do: {:ok, <<0x100 ||| codepoint >>> 8::9, codepoint &&& 0xFF::9>>}

  defp packed_scalar(codepoint) when codepoint in 0x10000..0x10FFFF,
    do:
      {:ok,
       <<0x100 ||| codepoint >>> 16::9, 0x100 ||| (codepoint >>> 8 &&& 0xFF)::9,
         codepoint &&& 0xFF::9>>}

  defp packed_scalar(_codepoint), do: :error

  defp decode_packed_all(<<>>, _offset, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_packed_all(input, offset, _acc) when bit_size(input) < 9,
    do: {:error, :incomplete_sequence, offset, input}

  defp decode_packed_all(<<nonet::9, rest::bitstring>>, offset, acc) do
    sequence = <<nonet::9>>

    cond do
      nonet == 0x100 ->
        packed_error(:invalid_sequence, offset, sequence, rest)

      nonet < 0x100 ->
        decode_packed_all(rest, offset + 9, [nonet | acc])

      true ->
        decode_packed_cont(rest, offset, nonet &&& 0xFF, 1, sequence, acc)
    end
  end

  defp decode_packed_cont(<<>>, offset, _value, _count, sequence, _acc),
    do: {:error, :incomplete_sequence, offset, sequence}

  defp decode_packed_cont(input, offset, _value, _count, sequence, _acc)
       when bit_size(input) < 9,
       do: {:error, :incomplete_sequence, offset, <<sequence::bitstring, input::bitstring>>}

  defp decode_packed_cont(<<nonet::9, rest::bitstring>>, offset, value, count, sequence, acc) do
    next_sequence = <<sequence::bitstring, nonet::9>>
    next_value = value <<< 8 ||| (nonet &&& 0xFF)

    cond do
      nonet >= 0x100 and count >= 2 ->
        packed_error(:invalid_sequence, offset, next_sequence, rest)

      nonet >= 0x100 ->
        decode_packed_cont(rest, offset, next_value, count + 1, next_sequence, acc)

      valid_scalar?(next_value) ->
        decode_packed_all(rest, offset + bit_size(next_sequence), [next_value | acc])

      true ->
        packed_error(:invalid_sequence, offset, next_sequence, rest)
    end
  end

  defp packed_error(kind, offset, sequence, _rest), do: {:error, kind, offset, sequence}

  defp encode_words_all([], _endian, _discard?, acc), do: {:ok, acc}

  defp encode_words_all([codepoint | rest], endian, discard?, acc) do
    case scalar_nonets(codepoint) do
      {:ok, nonets} ->
        bytes = Enum.map(nonets, &word(&1, endian))
        encode_words_all(rest, endian, discard?, [bytes | acc])

      :error when discard? ->
        encode_words_all(rest, endian, discard?, acc)

      :error ->
        {:error, :unrepresentable_character, codepoint}
    end
  end

  defp scalar_nonets(codepoint) when codepoint in 0..0xFF,
    do: {:ok, [codepoint]}

  defp scalar_nonets(codepoint)
       when codepoint in 0x100..0xFFFF and codepoint not in 0xD800..0xDFFF,
       do: {:ok, [0x100 ||| codepoint >>> 8, codepoint &&& 0xFF]}

  defp scalar_nonets(codepoint) when codepoint in 0x10000..0x10FFFF,
    do:
      {:ok,
       [
         0x100 ||| codepoint >>> 16,
         0x100 ||| (codepoint >>> 8 &&& 0xFF),
         codepoint &&& 0xFF
       ]}

  defp scalar_nonets(_codepoint), do: :error

  defp decode_words_all(<<>>, _endian, true, _offset, _pending, acc),
    do: {:ok, :lists.reverse(acc)}

  defp decode_words_all(<<>>, _endian, false, _offset, nil, acc),
    do: {:ok, :lists.reverse(acc)}

  defp decode_words_all(<<>>, _endian, false, _offset, {_, start, raw, _count}, _acc),
    do: {:error, :incomplete_sequence, start, raw}

  defp decode_words_all(input, _endian, true, _offset, _pending, acc) when byte_size(input) < 2,
    do: {:ok, :lists.reverse(acc)}

  defp decode_words_all(input, _endian, false, offset, nil, _acc) when byte_size(input) < 2,
    do: {:error, :incomplete_sequence, offset, input}

  defp decode_words_all(input, _endian, false, _offset, {_, start, raw, _count}, _acc)
       when byte_size(input) < 2,
       do: {:error, :incomplete_sequence, start, raw <> input}

  defp decode_words_all(input, endian, discard?, offset, pending, acc) do
    {nonet, raw_word, rest} = next_word(input, endian)

    cond do
      nonet > 0x1FF ->
        word_error_or_discard(
          :invalid_sequence,
          nonet,
          raw_word,
          rest,
          endian,
          discard?,
          offset,
          pending,
          acc
        )

      is_nil(pending) and nonet == 0x100 ->
        word_error_or_discard(
          :invalid_sequence,
          nonet,
          raw_word,
          rest,
          endian,
          discard?,
          offset,
          pending,
          acc
        )

      is_nil(pending) and nonet < 0x100 ->
        decode_words_all(rest, endian, discard?, offset + 2, nil, [nonet | acc])

      is_nil(pending) ->
        decode_words_all(
          rest,
          endian,
          discard?,
          offset + 2,
          {nonet &&& 0xFF, offset, raw_word, 1},
          acc
        )

      true ->
        continue_words(nonet, raw_word, rest, endian, discard?, offset, pending, acc)
    end
  end

  defp continue_words(
         nonet,
         raw_word,
         rest,
         endian,
         discard?,
         offset,
         {value, start, raw, count},
         acc
       ) do
    next_value = value <<< 8 ||| (nonet &&& 0xFF)
    next_raw = raw <> raw_word

    cond do
      nonet >= 0x100 and count >= 2 ->
        pending_error_or_discard(rest, endian, discard?, offset, start, next_raw, acc)

      nonet >= 0x100 ->
        decode_words_all(
          rest,
          endian,
          discard?,
          offset + 2,
          {next_value, start, next_raw, count + 1},
          acc
        )

      valid_scalar?(next_value) ->
        decode_words_all(rest, endian, discard?, offset + 2, nil, [next_value | acc])

      true ->
        pending_error_or_discard(rest, endian, discard?, offset, start, next_raw, acc)
    end
  end

  defp word_error_or_discard(
         _kind,
         _nonet,
         _raw_word,
         rest,
         endian,
         true,
         offset,
         _pending,
         acc
       ),
       do: decode_words_all(rest, endian, true, offset + 2, nil, acc)

  defp word_error_or_discard(kind, _nonet, raw_word, _rest, _endian, false, offset, nil, _acc),
    do: {:error, kind, offset, raw_word}

  defp word_error_or_discard(
         kind,
         _nonet,
         raw_word,
         _rest,
         _endian,
         false,
         _offset,
         {_, start, raw, _},
         _acc
       ),
       do: {:error, kind, start, raw <> raw_word}

  defp pending_error_or_discard(rest, endian, true, offset, _start, _raw, acc),
    do: decode_words_all(rest, endian, true, offset + 2, nil, acc)

  defp pending_error_or_discard(_rest, _endian, false, _offset, start, raw, _acc),
    do: {:error, :invalid_sequence, start, raw}

  defp next_word(<<nonet::16-big, rest::binary>>, :big), do: {nonet, <<nonet::16-big>>, rest}

  defp next_word(<<nonet::16-little, rest::binary>>, :little),
    do: {nonet, <<nonet::16-little>>, rest}

  defp word(nonet, :big), do: <<nonet::16-big>>
  defp word(nonet, :little), do: <<nonet::16-little>>

  defp valid_scalar?(codepoint),
    do: codepoint in 0..0x10FFFF and codepoint not in 0xD800..0xDFFF
end

defmodule Iconvex.Specs.UTF9BE16 do
  @moduledoc "RFC 4042 UTF-9 nonets stored in low 9 bits of 16-bit big-endian words."
  use Iconvex.Codec
  alias Iconvex.Specs.UTF9

  def canonical_name, do: "UTF-9-16BE"
  def aliases, do: ["UTF9-16BE", "UTF-9-16-BE"]
  def codec_id, do: :utf9_16be
  def decode(input), do: UTF9.decode_words(input, :big)
  def decode_discard(input), do: UTF9.decode_words(input, :big, true)
  def decode_to_utf8(input), do: UTF9.decode_words_to_utf8(input, :big)
  def encode(codepoints), do: UTF9.encode_words(codepoints, :big)
  def encode_discard(codepoints), do: UTF9.encode_words(codepoints, :big, true)

  def encode_substitute(codepoints, replacer),
    do: Iconvex.Specs.CodecSupport.encode_substitute_each(codepoints, &encode/1, replacer)

  def encode_from_utf8(input), do: UTF9.encode_words_from_utf8(input, :big)
end

defmodule Iconvex.Specs.UTF9LE16 do
  @moduledoc "RFC 4042 UTF-9 nonets stored in low 9 bits of 16-bit little-endian words."
  use Iconvex.Codec
  alias Iconvex.Specs.UTF9

  def canonical_name, do: "UTF-9-16LE"
  def aliases, do: ["UTF9-16LE", "UTF-9-16-LE"]
  def codec_id, do: :utf9_16le
  def decode(input), do: UTF9.decode_words(input, :little)
  def decode_discard(input), do: UTF9.decode_words(input, :little, true)
  def decode_to_utf8(input), do: UTF9.decode_words_to_utf8(input, :little)
  def encode(codepoints), do: UTF9.encode_words(codepoints, :little)
  def encode_discard(codepoints), do: UTF9.encode_words(codepoints, :little, true)

  def encode_substitute(codepoints, replacer),
    do: Iconvex.Specs.CodecSupport.encode_substitute_each(codepoints, &encode/1, replacer)

  def encode_from_utf8(input), do: UTF9.encode_words_from_utf8(input, :little)
end
