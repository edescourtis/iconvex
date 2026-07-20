defmodule Iconvex.Specs.JavaModifiedUTF8 do
  @moduledoc "Java's modified UTF-8 byte representation, without writeUTF's length prefix."

  use Iconvex.Codec
  import Bitwise

  @impl true
  def canonical_name, do: "JAVA-MODIFIED-UTF-8"

  @impl true
  def aliases,
    do: [
      "MUTF-8",
      "MODIFIED-UTF-8",
      "JAVA-MUTF-8",
      "DEX-MUTF-8",
      "DEX-MODIFIED-UTF-8",
      "ANDROID-DEX-MUTF-8"
    ]

  @impl true
  def codec_id, do: :java_modified_utf8

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

  defp decode_all(<<>>, _offset, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_all(input, offset, acc) do
    case decode_one(input) do
      {:ok, codepoint, rest} ->
        decode_all(rest, offset + byte_size(input) - byte_size(rest), [codepoint | acc])

      {:error, kind, sequence} ->
        {:error, kind, offset, sequence}
    end
  end

  defp decode_one(<<byte, rest::binary>>) when byte in 1..0x7F, do: {:ok, byte, rest}
  defp decode_one(<<0, _rest::binary>>), do: {:error, :invalid_sequence, <<0>>}
  defp decode_one(<<0xC0>>), do: {:error, :incomplete_sequence, <<0xC0>>}
  defp decode_one(<<0xC0, 0x80, rest::binary>>), do: {:ok, 0, rest}

  defp decode_one(<<0xC0, second, _rest::binary>>),
    do: {:error, :invalid_sequence, <<0xC0, second>>}

  defp decode_one(<<0xC1>>), do: {:error, :incomplete_sequence, <<0xC1>>}

  defp decode_one(<<0xC1, second, _rest::binary>>),
    do: {:error, :invalid_sequence, <<0xC1, second>>}

  defp decode_one(<<first, _rest::binary>> = input) when first in 0xC2..0xDF do
    if byte_size(input) < 2 do
      {:error, :incomplete_sequence, input}
    else
      <<_first, second, rest::binary>> = input

      if continuation?(second),
        do: {:ok, (first &&& 0x1F) <<< 6 ||| (second &&& 0x3F), rest},
        else: {:error, :invalid_sequence, <<first, second>>}
    end
  end

  defp decode_one(<<first, _rest::binary>> = input) when first in 0xE0..0xEF do
    if byte_size(input) < 3,
      do: {:error, :incomplete_sequence, input},
      else: decode_three(input)
  end

  defp decode_one(<<first, _rest::binary>>), do: {:error, :invalid_sequence, <<first>>}
  defp decode_one(<<>>), do: {:error, :incomplete_sequence, <<>>}

  defp decode_three(<<first, second, third, rest::binary>>) do
    valid_second = continuation?(second) and (first != 0xE0 or second >= 0xA0)

    cond do
      not valid_second or not continuation?(third) ->
        {:error, :invalid_sequence, <<first, second, third>>}

      first == 0xED and second in 0xA0..0xAF ->
        decode_surrogate_pair(first, second, third, rest)

      first == 0xED and second in 0xB0..0xBF ->
        {:error, :invalid_sequence, <<first, second, third>>}

      true ->
        codepoint =
          (first &&& 0x0F) <<< 12 ||| (second &&& 0x3F) <<< 6 ||| (third &&& 0x3F)

        {:ok, codepoint, rest}
    end
  end

  defp decode_surrogate_pair(first, second, third, rest) when byte_size(rest) < 3,
    do: {:error, :incomplete_sequence, <<first, second, third>> <> rest}

  defp decode_surrogate_pair(first, second, third, <<0xED, low2, low3, rest::binary>>)
       when low2 in 0xB0..0xBF and low3 in 0x80..0xBF do
    high = (first &&& 0x0F) <<< 12 ||| (second &&& 0x3F) <<< 6 ||| (third &&& 0x3F)
    low = 0xD000 ||| (low2 &&& 0x3F) <<< 6 ||| (low3 &&& 0x3F)
    codepoint = 0x10000 + ((high - 0xD800) <<< 10) + low - 0xDC00
    {:ok, codepoint, rest}
  end

  defp decode_surrogate_pair(first, second, third, _rest),
    do: {:error, :invalid_sequence, <<first, second, third>>}

  defp encode_all([], acc), do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_all([codepoint | rest], acc) do
    case encode_one(codepoint) do
      {:ok, bytes} -> encode_all(rest, [bytes | acc])
      :error -> {:error, :unrepresentable_character, codepoint}
    end
  end

  defp encode_discard_all([], acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_discard_all([codepoint | rest], acc) do
    case encode_one(codepoint) do
      {:ok, bytes} -> encode_discard_all(rest, [bytes | acc])
      :error -> encode_discard_all(rest, acc)
    end
  end

  defp encode_one(0), do: {:ok, <<0xC0, 0x80>>}
  defp encode_one(codepoint) when codepoint in 1..0x7F, do: {:ok, <<codepoint>>}

  defp encode_one(codepoint) when codepoint in 0x80..0x7FF,
    do: {:ok, <<0xC0 ||| codepoint >>> 6, 0x80 ||| (codepoint &&& 0x3F)>>}

  defp encode_one(codepoint)
       when codepoint in 0x800..0xFFFF and codepoint not in 0xD800..0xDFFF,
       do: {:ok, encode_unit(codepoint)}

  defp encode_one(codepoint) when codepoint in 0x10000..0x10FFFF do
    value = codepoint - 0x10000
    high = 0xD800 + (value >>> 10)
    low = 0xDC00 + (value &&& 0x3FF)
    {:ok, encode_unit(high) <> encode_unit(low)}
  end

  defp encode_one(_codepoint), do: :error

  defp encode_unit(unit),
    do: <<0xE0 ||| unit >>> 12, 0x80 ||| (unit >>> 6 &&& 0x3F), 0x80 ||| (unit &&& 0x3F)>>

  defp continuation?(byte), do: byte in 0x80..0xBF

  defp decode_discard_all(<<>>, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_discard_all(input, acc) do
    case decode_one(input) do
      {:ok, codepoint, rest} -> decode_discard_all(rest, [codepoint | acc])
      {:error, _kind, _sequence} -> discard_one(input, acc)
    end
  end

  defp discard_one(<<_byte, rest::binary>>, acc), do: decode_discard_all(rest, acc)
end
