defmodule Iconvex.Specs.UTF1 do
  @moduledoc "Historical UCS Transformation Format One from ISO-IR-178."

  use Iconvex.Codec

  @path Path.expand("../../../priv/utf1_manifest.etf", __DIR__)
  @external_resource @path
  @manifest @path |> File.read!() |> :erlang.binary_to_term()
  @base 0xBE
  @base2 @base * @base
  @base3 @base2 * @base
  @base4 @base3 * @base

  def canonical_name, do: "UTF-1"
  def aliases, do: ["UTF1", "ISO-IR-178", "ISO-10646-UTF-1", "csISO10646UTF1"]
  def codec_id, do: :utf1
  def source, do: @manifest.source
  def registration, do: @manifest.registration

  def decode(input) when is_binary(input), do: decode_all(input, 0, [])
  def decode_discard(input) when is_binary(input), do: decode_discard_all(input, [])
  def encode(codepoints) when is_list(codepoints), do: encode_all(codepoints, [])
  def encode_discard(codepoints) when is_list(codepoints), do: encode_discard_all(codepoints, [])

  def encode_substitute(codepoints, replacer),
    do:
      Iconvex.Specs.CodecSupport.encode_substitute_transform(
        codepoints,
        &encode/1,
        replacer
      )

  def decode_to_utf8(input) do
    with {:ok, codepoints} <- decode(input), do: {:ok, List.to_string(codepoints)}
  end

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

      {:error, reason, sequence} ->
        {:error, reason, offset, sequence}
    end
  end

  defp decode_one(<<byte, rest::binary>>) when byte <= 0x9F, do: {:ok, byte, rest}

  defp decode_one(<<0xA0, second, rest::binary>>) when second in 0xA0..0xFF,
    do: {:ok, second, rest}

  defp decode_one(<<0xA0, second, _::binary>>),
    do: {:error, :invalid_sequence, <<0xA0, second>>}

  defp decode_one(<<lead, second, rest::binary>>)
       when lead in 0xA1..0xF5 do
    sequence = <<lead, second>>

    with {:ok, digit} <- inverse_transform(second),
         codepoint = 0x100 + (lead - 0xA1) * @base + digit,
         true <- valid_scalar?(codepoint) do
      {:ok, codepoint, rest}
    else
      _ -> {:error, :invalid_sequence, sequence}
    end
  end

  defp decode_one(<<lead, second, third, rest::binary>>)
       when lead in 0xF6..0xFB do
    sequence = <<lead, second, third>>

    with {:ok, high} <- inverse_transform(second),
         {:ok, low} <- inverse_transform(third),
         codepoint = 0x4016 + (lead - 0xF6) * @base2 + high * @base + low,
         true <- valid_scalar?(codepoint) do
      {:ok, codepoint, rest}
    else
      _ -> {:error, :invalid_sequence, sequence}
    end
  end

  defp decode_one(<<lead, first, second, third, fourth, rest::binary>>)
       when lead in 0xFC..0xFF do
    sequence = <<lead, first, second, third, fourth>>

    with {:ok, d1} <- inverse_transform(first),
         {:ok, d2} <- inverse_transform(second),
         {:ok, d3} <- inverse_transform(third),
         {:ok, d4} <- inverse_transform(fourth),
         codepoint =
           0x38E2E + (lead - 0xFC) * @base4 + d1 * @base3 + d2 * @base2 +
             d3 * @base + d4,
         true <- valid_scalar?(codepoint) do
      {:ok, codepoint, rest}
    else
      _ -> {:error, :invalid_sequence, sequence}
    end
  end

  defp decode_one(input) do
    case input do
      <<0xA0, _::binary>> -> {:error, :incomplete_sequence, input}
      <<lead, _::binary>> when lead in 0xA1..0xF5 -> {:error, :incomplete_sequence, input}
      <<lead, _::binary>> when lead in 0xF6..0xFB -> {:error, :incomplete_sequence, input}
      <<lead, _::binary>> when lead in 0xFC..0xFF -> {:error, :incomplete_sequence, input}
      <<>> -> {:error, :incomplete_sequence, <<>>}
    end
  end

  defp encode_all([], acc), do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_all([codepoint | rest], acc) do
    case encode_one(codepoint) do
      {:ok, bytes} -> encode_all(rest, [bytes | acc])
      :error -> {:error, :unrepresentable_character, codepoint}
    end
  end

  defp encode_one(codepoint) when is_integer(codepoint) and codepoint in 0..0x9F,
    do: {:ok, <<codepoint>>}

  defp encode_one(codepoint) when is_integer(codepoint) and codepoint in 0xA0..0xFF,
    do: {:ok, <<0xA0, codepoint>>}

  defp encode_one(codepoint) when is_integer(codepoint) and codepoint in 0x100..0x4015 do
    value = codepoint - 0x100
    {:ok, <<0xA1 + div(value, @base), transform(rem(value, @base))>>}
  end

  defp encode_one(codepoint)
       when is_integer(codepoint) and codepoint in 0x4016..0x38E2D and
              codepoint not in 0xD800..0xDFFF do
    value = codepoint - 0x4016

    {:ok,
     <<0xF6 + div(value, @base2), transform(div(value, @base) |> rem(@base)),
       transform(rem(value, @base))>>}
  end

  defp encode_one(codepoint)
       when is_integer(codepoint) and codepoint in 0x38E2E..0x10FFFF and
              codepoint not in 0xD800..0xDFFF do
    value = codepoint - 0x38E2E

    {:ok,
     <<0xFC + div(value, @base4), transform(div(value, @base3) |> rem(@base)),
       transform(div(value, @base2) |> rem(@base)), transform(div(value, @base) |> rem(@base)),
       transform(rem(value, @base))>>}
  end

  defp encode_one(_codepoint), do: :error

  defp transform(value) when value in 0..0x5D, do: value + 0x21
  defp transform(value) when value in 0x5E..0xBD, do: value + 0x42

  defp inverse_transform(byte) when byte in 0x21..0x7E, do: {:ok, byte - 0x21}
  defp inverse_transform(byte) when byte in 0xA0..0xFF, do: {:ok, byte - 0x42}
  defp inverse_transform(_byte), do: :error

  defp valid_scalar?(codepoint),
    do: codepoint in 0..0x10FFFF and codepoint not in 0xD800..0xDFFF

  defp decode_discard_all(<<>>, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_discard_all(input, acc) do
    case decode_one(input) do
      {:ok, codepoint, rest} ->
        decode_discard_all(rest, [codepoint | acc])

      {:error, _reason, _sequence} ->
        <<_byte, rest::binary>> = input
        decode_discard_all(rest, acc)
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
end
