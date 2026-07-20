defmodule Iconvex.Specs.UTFEBCDIC do
  @moduledoc "UTF-EBCDIC as defined by Unicode Technical Report #16, version 8."

  use Iconvex.Codec
  import Bitwise

  @i8_to_ebcdic List.to_tuple([
                  0x00,
                  0x01,
                  0x02,
                  0x03,
                  0x37,
                  0x2D,
                  0x2E,
                  0x2F,
                  0x16,
                  0x05,
                  0x15,
                  0x0B,
                  0x0C,
                  0x0D,
                  0x0E,
                  0x0F,
                  0x10,
                  0x11,
                  0x12,
                  0x13,
                  0x3C,
                  0x3D,
                  0x32,
                  0x26,
                  0x18,
                  0x19,
                  0x3F,
                  0x27,
                  0x1C,
                  0x1D,
                  0x1E,
                  0x1F,
                  0x40,
                  0x5A,
                  0x7F,
                  0x7B,
                  0x5B,
                  0x6C,
                  0x50,
                  0x7D,
                  0x4D,
                  0x5D,
                  0x5C,
                  0x4E,
                  0x6B,
                  0x60,
                  0x4B,
                  0x61,
                  0xF0,
                  0xF1,
                  0xF2,
                  0xF3,
                  0xF4,
                  0xF5,
                  0xF6,
                  0xF7,
                  0xF8,
                  0xF9,
                  0x7A,
                  0x5E,
                  0x4C,
                  0x7E,
                  0x6E,
                  0x6F,
                  0x7C,
                  0xC1,
                  0xC2,
                  0xC3,
                  0xC4,
                  0xC5,
                  0xC6,
                  0xC7,
                  0xC8,
                  0xC9,
                  0xD1,
                  0xD2,
                  0xD3,
                  0xD4,
                  0xD5,
                  0xD6,
                  0xD7,
                  0xD8,
                  0xD9,
                  0xE2,
                  0xE3,
                  0xE4,
                  0xE5,
                  0xE6,
                  0xE7,
                  0xE8,
                  0xE9,
                  0xAD,
                  0xE0,
                  0xBD,
                  0x5F,
                  0x6D,
                  0x79,
                  0x81,
                  0x82,
                  0x83,
                  0x84,
                  0x85,
                  0x86,
                  0x87,
                  0x88,
                  0x89,
                  0x91,
                  0x92,
                  0x93,
                  0x94,
                  0x95,
                  0x96,
                  0x97,
                  0x98,
                  0x99,
                  0xA2,
                  0xA3,
                  0xA4,
                  0xA5,
                  0xA6,
                  0xA7,
                  0xA8,
                  0xA9,
                  0xC0,
                  0x4F,
                  0xD0,
                  0xA1,
                  0x07,
                  0x20,
                  0x21,
                  0x22,
                  0x23,
                  0x24,
                  0x25,
                  0x06,
                  0x17,
                  0x28,
                  0x29,
                  0x2A,
                  0x2B,
                  0x2C,
                  0x09,
                  0x0A,
                  0x1B,
                  0x30,
                  0x31,
                  0x1A,
                  0x33,
                  0x34,
                  0x35,
                  0x36,
                  0x08,
                  0x38,
                  0x39,
                  0x3A,
                  0x3B,
                  0x04,
                  0x14,
                  0x3E,
                  0xFF,
                  0x41,
                  0x42,
                  0x43,
                  0x44,
                  0x45,
                  0x46,
                  0x47,
                  0x48,
                  0x49,
                  0x4A,
                  0x51,
                  0x52,
                  0x53,
                  0x54,
                  0x55,
                  0x56,
                  0x57,
                  0x58,
                  0x59,
                  0x62,
                  0x63,
                  0x64,
                  0x65,
                  0x66,
                  0x67,
                  0x68,
                  0x69,
                  0x6A,
                  0x70,
                  0x71,
                  0x72,
                  0x73,
                  0x74,
                  0x75,
                  0x76,
                  0x77,
                  0x78,
                  0x80,
                  0x8A,
                  0x8B,
                  0x8C,
                  0x8D,
                  0x8E,
                  0x8F,
                  0x90,
                  0x9A,
                  0x9B,
                  0x9C,
                  0x9D,
                  0x9E,
                  0x9F,
                  0xA0,
                  0xAA,
                  0xAB,
                  0xAC,
                  0xAE,
                  0xAF,
                  0xB0,
                  0xB1,
                  0xB2,
                  0xB3,
                  0xB4,
                  0xB5,
                  0xB6,
                  0xB7,
                  0xB8,
                  0xB9,
                  0xBA,
                  0xBB,
                  0xBC,
                  0xBE,
                  0xBF,
                  0xCA,
                  0xCB,
                  0xCC,
                  0xCD,
                  0xCE,
                  0xCF,
                  0xDA,
                  0xDB,
                  0xDC,
                  0xDD,
                  0xDE,
                  0xDF,
                  0xE1,
                  0xEA,
                  0xEB,
                  0xEC,
                  0xED,
                  0xEE,
                  0xEF,
                  0xFA,
                  0xFB,
                  0xFC,
                  0xFD,
                  0xFE
                ])

  @ebcdic_to_i8 @i8_to_ebcdic
                |> Tuple.to_list()
                |> Enum.with_index()
                |> Enum.sort_by(&elem(&1, 0))
                |> Enum.map(&elem(&1, 1))
                |> List.to_tuple()

  @impl true
  def canonical_name, do: "UTF-EBCDIC"

  @impl true
  def aliases, do: ["UTF_EBCDIC", "UTFEBCDIC"]

  @impl true
  def codec_id, do: :utf_ebcdic

  @impl true
  def decode(input) when is_binary(input) do
    i8 = for <<byte <- input>>, into: <<>>, do: <<elem(@ebcdic_to_i8, byte)>>
    decode_all(input, i8, 0, [])
  end

  @impl true
  def decode_discard(input) when is_binary(input) do
    i8 = for <<byte <- input>>, into: <<>>, do: <<elem(@ebcdic_to_i8, byte)>>
    decode_discard_all(input, i8, [])
  end

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

  defp decode_all(<<>>, <<>>, _offset, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_all(original, i8, offset, acc) do
    case decode_one(original, i8) do
      {:ok, codepoint, original_rest, i8_rest} ->
        consumed = byte_size(original) - byte_size(original_rest)
        decode_all(original_rest, i8_rest, offset + consumed, [codepoint | acc])

      {:error, kind, sequence} ->
        {:error, kind, offset, sequence}
    end
  end

  defp decode_one(<<_byte, original_rest::binary>>, <<i8, i8_rest::binary>>) when i8 <= 0x9F,
    do: {:ok, i8, original_rest, i8_rest}

  defp decode_one(original, <<lead, _rest::binary>> = i8) do
    case i8_length(lead) do
      :error ->
        {:error, :invalid_sequence, binary_part(original, 0, 1)}

      length when byte_size(i8) < length ->
        {:error, :incomplete_sequence, original}

      length ->
        sequence = binary_part(original, 0, length)
        i8_sequence = binary_part(i8, 0, length)

        case decode_i8(i8_sequence, length) do
          {:ok, codepoint} ->
            original_rest = binary_part(original, length, byte_size(original) - length)
            i8_rest = binary_part(i8, length, byte_size(i8) - length)
            {:ok, codepoint, original_rest, i8_rest}

          :error ->
            {:error, :invalid_sequence, sequence}
        end
    end
  end

  defp i8_length(lead) when lead in 0xC0..0xDF, do: 2
  defp i8_length(lead) when lead in 0xE0..0xEF, do: 3
  defp i8_length(lead) when lead in 0xF0..0xF7, do: 4
  defp i8_length(lead) when lead in 0xF8..0xF9, do: 5
  defp i8_length(_lead), do: :error

  defp decode_i8(sequence, length) do
    <<lead, trails::binary>> = sequence

    if Enum.all?(:binary.bin_to_list(trails), &(&1 in 0xA0..0xBF)) do
      lead_bits = lead &&& (1 <<< (7 - length)) - 1

      codepoint =
        for <<trail <- trails>>, reduce: lead_bits do
          value -> value <<< 5 ||| (trail &&& 0x1F)
        end

      minimum = elem({0, 0xA0, 0x400, 0x4000, 0x40000}, length - 1)

      if codepoint >= minimum and valid_scalar?(codepoint),
        do: {:ok, codepoint},
        else: :error
    else
      :error
    end
  end

  defp decode_discard_all(<<>>, <<>>, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_discard_all(original, i8, acc) do
    case decode_one(original, i8) do
      {:ok, codepoint, original_rest, i8_rest} ->
        decode_discard_all(original_rest, i8_rest, [codepoint | acc])

      {:error, _kind, sequence} ->
        discard = max(byte_size(sequence), 1)
        discard = min(discard, byte_size(original))
        original_rest = binary_part(original, discard, byte_size(original) - discard)
        i8_rest = binary_part(i8, discard, byte_size(i8) - discard)
        decode_discard_all(original_rest, i8_rest, acc)
    end
  end

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

  defp encode_one(codepoint)
       when codepoint in 0..0x10FFFF and codepoint not in 0xD800..0xDFFF do
    i8 = encode_i8(codepoint)
    {:ok, for(<<byte <- i8>>, into: <<>>, do: <<elem(@i8_to_ebcdic, byte)>>)}
  end

  defp encode_one(_codepoint), do: :error

  defp encode_i8(codepoint) when codepoint <= 0x9F, do: <<codepoint>>

  defp encode_i8(codepoint) when codepoint <= 0x3FF,
    do: <<0xC0 ||| codepoint >>> 5, 0xA0 ||| (codepoint &&& 0x1F)>>

  defp encode_i8(codepoint) when codepoint <= 0x3FFF,
    do:
      <<0xE0 ||| codepoint >>> 10, 0xA0 ||| (codepoint >>> 5 &&& 0x1F),
        0xA0 ||| (codepoint &&& 0x1F)>>

  defp encode_i8(codepoint) when codepoint <= 0x3FFFF,
    do:
      <<0xF0 ||| codepoint >>> 15, 0xA0 ||| (codepoint >>> 10 &&& 0x1F),
        0xA0 ||| (codepoint >>> 5 &&& 0x1F), 0xA0 ||| (codepoint &&& 0x1F)>>

  defp encode_i8(codepoint),
    do:
      <<0xF8 ||| codepoint >>> 20, 0xA0 ||| (codepoint >>> 15 &&& 0x1F),
        0xA0 ||| (codepoint >>> 10 &&& 0x1F), 0xA0 ||| (codepoint >>> 5 &&& 0x1F),
        0xA0 ||| (codepoint &&& 0x1F)>>

  defp valid_scalar?(codepoint),
    do: codepoint in 0..0x10FFFF and codepoint not in 0xD800..0xDFFF
end
