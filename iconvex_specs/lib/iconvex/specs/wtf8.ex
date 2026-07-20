defmodule Iconvex.Specs.WTF8 do
  @moduledoc """
  Wobbly Transformation Format 8 (WTF-8).

  WTF-8 is canonical UTF-8 extended with three-byte encodings for isolated
  UTF-16 surrogate code points. An adjacent high/low surrogate pair is always
  represented by the ordinary four-byte UTF-8 encoding of the corresponding
  supplementary scalar; its six-byte generalized-UTF-8 spelling is invalid.
  """

  use Iconvex.Codec
  import Bitwise

  @impl true
  def canonical_name, do: "WTF-8"

  @impl true
  def aliases, do: ["WTF8", "WOBBLY-TRANSFORMATION-FORMAT-8"]

  @impl true
  def codec_id, do: :wtf8

  @impl true
  def decode(input) when is_binary(input), do: decode_all(input, 0, [])

  @impl true
  def decode_discard(input) when is_binary(input), do: decode_discard_all(input, [])

  @impl true
  def encode(codepoints) when is_list(codepoints), do: encode_all(codepoints, [])

  @impl true
  def encode_discard(codepoints) when is_list(codepoints), do: encode_discard_all(codepoints, [])

  @impl true
  def encode_substitute(codepoints, replacer),
    do:
      Iconvex.Specs.CodecSupport.encode_substitute_transform(
        codepoints,
        &encode/1,
        replacer
      )

  # Every well-formed UTF-8 string is already its canonical WTF-8 encoding.
  @impl true
  def encode_from_utf8(input) when is_binary(input) do
    case Iconvex.UnicodeCodec.decode(%{id: :utf8}, input) do
      {:ok, _codepoints} -> {:ok, input}
      {:error, kind, offset, sequence} -> {:decode_error, kind, offset, sequence}
    end
  end

  defp decode_all(<<>>, _offset, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_all(input, offset, acc) do
    case decode_one(input) do
      {:ok, codepoint, rest} ->
        consumed = byte_size(input) - byte_size(rest)
        decode_all(rest, offset + consumed, [codepoint | acc])

      {:error, kind, sequence} ->
        {:error, kind, offset, sequence}
    end
  end

  defp decode_one(<<byte, rest::binary>>) when byte <= 0x7F, do: {:ok, byte, rest}

  defp decode_one(<<first, rest::binary>> = input) when first in 0xC2..0xDF do
    case rest do
      <<second, tail::binary>> when second in 0x80..0xBF ->
        {:ok, (first &&& 0x1F) <<< 6 ||| (second &&& 0x3F), tail}

      <<>> ->
        {:error, :incomplete_sequence, input}

      <<second, _tail::binary>> ->
        {:error, :invalid_sequence, <<first, second>>}
    end
  end

  defp decode_one(<<first, rest::binary>> = input) when first in 0xE0..0xEF do
    case rest do
      <<>> ->
        {:error, :incomplete_sequence, input}

      <<second>> ->
        if valid_second_of_three?(first, second),
          do: {:error, :incomplete_sequence, input},
          else: {:error, :invalid_sequence, input}

      <<second, third, tail::binary>> ->
        if valid_second_of_three?(first, second) and continuation?(third) do
          codepoint =
            (first &&& 0x0F) <<< 12 ||| (second &&& 0x3F) <<< 6 ||| (third &&& 0x3F)

          reject_surrogate_pair(codepoint, <<first, second, third>>, tail)
        else
          {:error, :invalid_sequence, <<first, second, third>>}
        end
    end
  end

  defp decode_one(<<first, rest::binary>> = input) when first in 0xF0..0xF4 do
    case rest do
      <<>> ->
        {:error, :incomplete_sequence, input}

      <<second>> ->
        if valid_second_of_four?(first, second),
          do: {:error, :incomplete_sequence, input},
          else: {:error, :invalid_sequence, input}

      <<second, third>> ->
        cond do
          not valid_second_of_four?(first, second) -> {:error, :invalid_sequence, input}
          not continuation?(third) -> {:error, :invalid_sequence, input}
          true -> {:error, :incomplete_sequence, input}
        end

      <<second, third, fourth, tail::binary>> ->
        if valid_second_of_four?(first, second) and continuation?(third) and
             continuation?(fourth) do
          codepoint =
            (first &&& 0x07) <<< 18 ||| (second &&& 0x3F) <<< 12 |||
              (third &&& 0x3F) <<< 6 ||| (fourth &&& 0x3F)

          {:ok, codepoint, tail}
        else
          {:error, :invalid_sequence, <<first, second, third, fourth>>}
        end
    end
  end

  defp decode_one(<<first, _rest::binary>>), do: {:error, :invalid_sequence, <<first>>}
  defp decode_one(<<>>), do: {:error, :incomplete_sequence, <<>>}

  defp reject_surrogate_pair(
         high,
         high_bytes,
         <<0xED, low_second, low_third, _tail::binary>>
       )
       when high in 0xD800..0xDBFF and low_second in 0xB0..0xBF and
              low_third in 0x80..0xBF do
    {:error, :invalid_sequence, high_bytes <> <<0xED, low_second, low_third>>}
  end

  defp reject_surrogate_pair(codepoint, _bytes, rest), do: {:ok, codepoint, rest}

  defp valid_second_of_three?(0xE0, second), do: second in 0xA0..0xBF
  defp valid_second_of_three?(_first, second), do: continuation?(second)

  defp valid_second_of_four?(0xF0, second), do: second in 0x90..0xBF
  defp valid_second_of_four?(0xF4, second), do: second in 0x80..0x8F
  defp valid_second_of_four?(_first, second), do: continuation?(second)

  defp continuation?(byte), do: byte in 0x80..0xBF

  defp encode_all([], acc), do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_all([high, low | rest], acc)
       when high in 0xD800..0xDBFF and low in 0xDC00..0xDFFF do
    scalar = 0x10000 + ((high - 0xD800) <<< 10) + low - 0xDC00
    encode_all(rest, [encode_scalar(scalar) | acc])
  end

  defp encode_all([codepoint | rest], acc) do
    case encode_codepoint(codepoint) do
      {:ok, bytes} -> encode_all(rest, [bytes | acc])
      :error -> {:error, :unrepresentable_character, codepoint}
    end
  end

  defp encode_discard_all([], acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_discard_all([high, low | rest], acc)
       when high in 0xD800..0xDBFF and low in 0xDC00..0xDFFF do
    scalar = 0x10000 + ((high - 0xD800) <<< 10) + low - 0xDC00
    encode_discard_all(rest, [encode_scalar(scalar) | acc])
  end

  defp encode_discard_all([codepoint | rest], acc) do
    case encode_codepoint(codepoint) do
      {:ok, bytes} -> encode_discard_all(rest, [bytes | acc])
      :error -> encode_discard_all(rest, acc)
    end
  end

  defp encode_codepoint(codepoint) when codepoint in 0..0x10FFFF,
    do: {:ok, encode_scalar(codepoint)}

  defp encode_codepoint(_codepoint), do: :error

  defp encode_scalar(codepoint) when codepoint <= 0x7F, do: <<codepoint>>

  defp encode_scalar(codepoint) when codepoint <= 0x7FF,
    do: <<0xC0 ||| codepoint >>> 6, 0x80 ||| (codepoint &&& 0x3F)>>

  defp encode_scalar(codepoint) when codepoint <= 0xFFFF,
    do:
      <<0xE0 ||| codepoint >>> 12, 0x80 ||| (codepoint >>> 6 &&& 0x3F),
        0x80 ||| (codepoint &&& 0x3F)>>

  defp encode_scalar(codepoint),
    do:
      <<0xF0 ||| codepoint >>> 18, 0x80 ||| (codepoint >>> 12 &&& 0x3F),
        0x80 ||| (codepoint >>> 6 &&& 0x3F), 0x80 ||| (codepoint &&& 0x3F)>>

  defp decode_discard_all(<<>>, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_discard_all(input, acc) do
    case decode_one(input) do
      {:ok, codepoint, rest} ->
        decode_discard_all(rest, [codepoint | acc])

      {:error, :invalid_sequence, sequence}
      when byte_size(sequence) == 6 and binary_part(sequence, 0, 1) == <<0xED>> ->
        # Preserve the low surrogate as an isolated code point after discarding
        # the high half that made the adjacent pair non-canonical.
        <<_high::binary-size(3), rest::binary>> = input
        decode_discard_all(rest, acc)

      {:error, _kind, _sequence} ->
        <<_byte, rest::binary>> = input
        decode_discard_all(rest, acc)
    end
  end
end
