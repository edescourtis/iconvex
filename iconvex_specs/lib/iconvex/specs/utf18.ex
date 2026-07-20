defmodule Iconvex.Specs.UTF18 do
  @moduledoc """
  RFC 4042 UTF-18 over native 18-bit values.

  Packed values are exact MSB-first Elixir bitstrings. Byte-oriented callers
  should use the explicit `UTF-18-24BE` or `UTF-18-24LE` transports.
  """

  def canonical_name, do: "UTF-18"
  def unit_bits, do: 18
  def transport_codecs, do: [Iconvex.Specs.UTF18BE24, Iconvex.Specs.UTF18LE24]

  def encode_packed(codepoints), do: encode_packed(codepoints, false, [])
  def encode_packed_discard(codepoints), do: encode_packed(codepoints, true, [])

  def decode_packed(input) when is_bitstring(input), do: decode_packed(input, false, 0, [])
  def decode_packed_discard(input) when is_bitstring(input), do: decode_packed(input, true, 0, [])

  def encode_words(codepoints, endian, discard? \\ false) when endian in [:big, :little],
    do: encode_words(codepoints, endian, discard?, [])

  def decode_words(input, endian, discard? \\ false)
      when is_binary(input) and endian in [:big, :little],
      do: decode_words(input, endian, discard?, 0, [])

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

      {:incomplete, converted, rest} ->
        encode_prefix_or_utf8_error(
          converted,
          endian,
          :incomplete_sequence,
          byte_size(input) - byte_size(rest),
          rest
        )

      {:error, converted, rest} ->
        encode_prefix_or_utf8_error(
          converted,
          endian,
          :invalid_sequence,
          byte_size(input) - byte_size(rest),
          rest
        )
    end
  end

  defp encode_prefix_or_utf8_error(converted, endian, kind, offset, rest) do
    case encode_words(converted, endian) do
      {:error, encode_kind, codepoint} -> {:encode_error, encode_kind, codepoint}
      {:ok, _encoded_prefix} -> {:decode_error, kind, offset, rest}
    end
  end

  defp encode_packed([], _discard?, acc),
    do: {:ok, acc |> :lists.reverse() |> :erlang.list_to_bitstring()}

  defp encode_packed([codepoint | rest], discard?, acc) do
    case encode_value(codepoint) do
      {:ok, value} -> encode_packed(rest, discard?, [<<value::18>> | acc])
      :error when discard? -> encode_packed(rest, discard?, acc)
      :error -> {:error, :unrepresentable_character, codepoint}
    end
  end

  defp decode_packed(<<>>, _discard?, _offset, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_packed(input, true, _offset, acc) when bit_size(input) < 18,
    do: {:ok, :lists.reverse(acc)}

  defp decode_packed(input, false, offset, _acc) when bit_size(input) < 18,
    do: {:error, :incomplete_sequence, offset, input}

  defp decode_packed(<<value::18, rest::bitstring>>, discard?, offset, acc) do
    case decode_value(value) do
      {:ok, codepoint} -> decode_packed(rest, discard?, offset + 18, [codepoint | acc])
      :error when discard? -> decode_packed(rest, discard?, offset + 18, acc)
      :error -> {:error, :invalid_sequence, offset, <<value::18>>}
    end
  end

  defp encode_words([], _endian, _discard?, acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_words([codepoint | rest], endian, discard?, acc) do
    case encode_value(codepoint) do
      {:ok, value} -> encode_words(rest, endian, discard?, [word(value, endian) | acc])
      :error when discard? -> encode_words(rest, endian, discard?, acc)
      :error -> {:error, :unrepresentable_character, codepoint}
    end
  end

  defp decode_words(<<>>, _endian, _discard?, _offset, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_words(input, _endian, true, _offset, acc) when byte_size(input) < 3,
    do: {:ok, :lists.reverse(acc)}

  defp decode_words(input, _endian, false, offset, _acc) when byte_size(input) < 3,
    do: {:error, :incomplete_sequence, offset, input}

  defp decode_words(input, endian, discard?, offset, acc) do
    {value, raw, rest} = next_word(input, endian)

    case decode_value(value) do
      {:ok, codepoint} -> decode_words(rest, endian, discard?, offset + 3, [codepoint | acc])
      :error when discard? -> decode_words(rest, endian, discard?, offset + 3, acc)
      :error -> {:error, :invalid_sequence, offset, raw}
    end
  end

  defp encode_value(codepoint)
       when codepoint in 0..0x2FFFF and codepoint not in 0xD800..0xDFFF,
       do: {:ok, codepoint}

  defp encode_value(codepoint) when codepoint in 0xE0000..0xEFFFF,
    do: {:ok, codepoint - 0xB0000}

  defp encode_value(_codepoint), do: :error

  defp decode_value(value) when value in 0..0x2FFFF and value not in 0xD800..0xDFFF,
    do: {:ok, value}

  defp decode_value(value) when value in 0x30000..0x3FFFF, do: {:ok, value + 0xB0000}
  defp decode_value(_value), do: :error

  defp next_word(<<value::24-big, rest::binary>>, :big),
    do: {value, <<value::24-big>>, rest}

  defp next_word(<<value::24-little, rest::binary>>, :little),
    do: {value, <<value::24-little>>, rest}

  defp word(value, :big), do: <<value::24-big>>
  defp word(value, :little), do: <<value::24-little>>
end

defmodule Iconvex.Specs.UTF18BE24 do
  @moduledoc "RFC 4042 UTF-18 values stored in low 18 bits of 24-bit big-endian words."
  use Iconvex.Codec
  alias Iconvex.Specs.UTF18

  def canonical_name, do: "UTF-18-24BE"
  def aliases, do: ["UTF18-24BE", "UTF-18-24-BE"]
  def codec_id, do: :utf18_24be
  def decode(input), do: UTF18.decode_words(input, :big)
  def decode_discard(input), do: UTF18.decode_words(input, :big, true)
  def decode_to_utf8(input), do: UTF18.decode_words_to_utf8(input, :big)
  def encode(codepoints), do: UTF18.encode_words(codepoints, :big)
  def encode_discard(codepoints), do: UTF18.encode_words(codepoints, :big, true)

  def encode_substitute(codepoints, replacer),
    do: Iconvex.Specs.CodecSupport.encode_substitute_each(codepoints, &encode/1, replacer)

  def encode_from_utf8(input), do: UTF18.encode_words_from_utf8(input, :big)
end

defmodule Iconvex.Specs.UTF18LE24 do
  @moduledoc "RFC 4042 UTF-18 values stored in low 18 bits of 24-bit little-endian words."
  use Iconvex.Codec
  alias Iconvex.Specs.UTF18

  def canonical_name, do: "UTF-18-24LE"
  def aliases, do: ["UTF18-24LE", "UTF-18-24-LE"]
  def codec_id, do: :utf18_24le
  def decode(input), do: UTF18.decode_words(input, :little)
  def decode_discard(input), do: UTF18.decode_words(input, :little, true)
  def decode_to_utf8(input), do: UTF18.decode_words_to_utf8(input, :little)
  def encode(codepoints), do: UTF18.encode_words(codepoints, :little)
  def encode_discard(codepoints), do: UTF18.encode_words(codepoints, :little, true)

  def encode_substitute(codepoints, replacer),
    do: Iconvex.Specs.CodecSupport.encode_substitute_each(codepoints, &encode/1, replacer)

  def encode_from_utf8(input), do: UTF18.encode_words_from_utf8(input, :little)
end
