defmodule Iconvex.Specs.UTF5 do
  @moduledoc """
  Native implementation of `draft-jseng-utf5-01`.

  UTF-5 is an octet stream whose uppercase alphanumeric octets carry five-bit
  quintets. Each Unicode scalar is its minimal uppercase hexadecimal form with
  the first nonzero nibble translated from `1..F` to `H..V`; zero is `G`.
  """

  use Iconvex.Codec

  import Bitwise

  @source_dir Path.expand("../../../priv/sources/draft-jseng-utf5-01", __DIR__)
  @draft Path.join(@source_dir, "draft-jseng-utf5-01.txt")
  @metadata Path.join(@source_dir, "SOURCE_METADATA.md")
  @external_resource @draft
  @external_resource @metadata
  @draft_sha256 "12ae18367c110b5dcef9cc3f06b6ae40e60c8fde489fdd161f1bb98e3e5f2375"
  @max_scalar 0x10FFFF

  @impl true
  def canonical_name, do: "UTF-5"

  @impl true
  def aliases, do: ["UTF5", "DRAFT-JSENG-UTF5-01"]

  @impl true
  def codec_id, do: :utf5_draft_jseng_01

  def draft_revision, do: "draft-jseng-utf5-01"
  def source_sha256, do: @draft_sha256

  @impl true
  def decode(input) when is_binary(input), do: decode_all(input, 0, [])

  @impl true
  def decode_discard(input) when is_binary(input), do: discard_all(input, nil, [])

  @impl true
  def encode(codepoints) when is_list(codepoints), do: encode_all(codepoints, [])

  @impl true
  def encode_discard(codepoints) when is_list(codepoints),
    do: encode_discard_all(codepoints, [])

  @impl true
  def encode_substitute(codepoints, replacer)
      when is_list(codepoints) and is_function(replacer, 1),
      do: encode_substitute_all(codepoints, replacer, [])

  @impl true
  def decode_to_utf8(input) when is_binary(input) do
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

  @impl true
  def decode_error_consumption(_kind, sequence) when is_binary(sequence),
    do: max(byte_size(sequence), 1)

  @impl true
  def decode_chunk(input, true) when is_binary(input) do
    case decode(input) do
      {:ok, codepoints} -> {:ok, codepoints, <<>>}
      error -> error
    end
  end

  def decode_chunk(input, false) when is_binary(input) do
    decode_chunk_nonfinal(input, 0, [])
  end

  @impl true
  def encode_chunk(codepoints, _final?, :error) when is_list(codepoints) do
    case encode(codepoints) do
      {:ok, output} -> {:ok, output, []}
      error -> error
    end
  end

  def encode_chunk(codepoints, _final?, :discard) when is_list(codepoints) do
    {:ok, output} = encode_discard(codepoints)
    {:ok, output, []}
  end

  def encode_chunk(codepoints, _final?, {:replace, replacer})
      when is_list(codepoints) and is_function(replacer, 1) do
    case encode_substitute(codepoints, replacer) do
      {:ok, output} -> {:ok, output, []}
      error -> error
    end
  end

  defp encode_all([], acc), do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_all([codepoint | rest], acc) do
    case encode_scalar(codepoint) do
      {:ok, encoded} -> encode_all(rest, [encoded | acc])
      :error -> {:error, :unrepresentable_character, codepoint}
    end
  end

  defp encode_discard_all([], acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_discard_all([codepoint | rest], acc) do
    case encode_scalar(codepoint) do
      {:ok, encoded} -> encode_discard_all(rest, [encoded | acc])
      :error -> encode_discard_all(rest, acc)
    end
  end

  defp encode_substitute_all([], _replacer, acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_substitute_all([codepoint | rest], replacer, acc) do
    case encode_scalar(codepoint) do
      {:ok, encoded} ->
        encode_substitute_all(rest, replacer, [encoded | acc])

      :error ->
        case encode_replacement(replacer.(codepoint), []) do
          {:ok, replacement} ->
            encode_substitute_all(rest, replacer, [replacement | acc])

          error ->
            error
        end
    end
  end

  defp encode_replacement([], acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_replacement([codepoint | rest], acc) do
    case encode_scalar(codepoint) do
      {:ok, encoded} -> encode_replacement(rest, [encoded | acc])
      :error -> {:error, :unrepresentable_character, codepoint}
    end
  end

  defp encode_replacement(other, _acc), do: {:error, :unrepresentable_character, other}

  defp encode_scalar(0), do: {:ok, "G"}

  defp encode_scalar(codepoint)
       when is_integer(codepoint) and codepoint in 1..0xF,
       do: {:ok, <<?G + codepoint>>}

  defp encode_scalar(codepoint)
       when is_integer(codepoint) and codepoint in 0x10..0xFF,
       do: {:ok, <<?G + (codepoint >>> 4), hex_digit(codepoint &&& 0xF)>>}

  defp encode_scalar(codepoint)
       when is_integer(codepoint) and codepoint in 0x100..0xFFF and
              codepoint not in 0xD800..0xDFFF,
       do:
         {:ok,
          <<?G + (codepoint >>> 8), hex_digit(codepoint >>> 4 &&& 0xF),
            hex_digit(codepoint &&& 0xF)>>}

  defp encode_scalar(codepoint)
       when is_integer(codepoint) and codepoint in 0x1000..0xFFFF and
              codepoint not in 0xD800..0xDFFF,
       do:
         {:ok,
          <<?G + (codepoint >>> 12), hex_digit(codepoint >>> 8 &&& 0xF),
            hex_digit(codepoint >>> 4 &&& 0xF), hex_digit(codepoint &&& 0xF)>>}

  defp encode_scalar(codepoint)
       when is_integer(codepoint) and codepoint in 0x1_0000..0xF_FFFF,
       do:
         {:ok,
          <<?G + (codepoint >>> 16), hex_digit(codepoint >>> 12 &&& 0xF),
            hex_digit(codepoint >>> 8 &&& 0xF), hex_digit(codepoint >>> 4 &&& 0xF),
            hex_digit(codepoint &&& 0xF)>>}

  defp encode_scalar(codepoint)
       when is_integer(codepoint) and codepoint in 0x10_0000..@max_scalar,
       do:
         {:ok,
          <<?G + (codepoint >>> 20), hex_digit(codepoint >>> 16 &&& 0xF),
            hex_digit(codepoint >>> 12 &&& 0xF), hex_digit(codepoint >>> 8 &&& 0xF),
            hex_digit(codepoint >>> 4 &&& 0xF), hex_digit(codepoint &&& 0xF)>>}

  defp encode_scalar(_codepoint), do: :error

  defp hex_digit(value) when value < 10, do: ?0 + value
  defp hex_digit(value), do: ?A + value - 10

  defp decode_all(<<>>, _offset, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_all(<<initial, rest::binary>>, offset, acc) when initial in ?G..?V do
    decode_cont(rest, initial - ?G, offset, <<initial>>, acc)
  end

  defp decode_all(<<byte, _rest::binary>>, offset, _acc),
    do: {:error, :invalid_sequence, offset, <<byte>>}

  defp decode_cont(<<>>, value, offset, raw, acc),
    do: finish_scalar(value, offset, raw, <<>>, acc)

  defp decode_cont(<<initial, _::binary>> = input, value, offset, raw, acc)
       when initial in ?G..?V,
       do: finish_scalar(value, offset, raw, input, acc)

  defp decode_cont(<<byte, rest::binary>>, value, offset, raw, acc) do
    case continuation_value(byte) do
      {:ok, _digit} when value == 0 ->
        {:error, :invalid_sequence, offset, raw <> <<byte>>}

      {:ok, digit} ->
        next_value = value <<< 4 ||| digit
        next_raw = raw <> <<byte>>

        if next_value <= @max_scalar do
          decode_cont(rest, next_value, offset, next_raw, acc)
        else
          {:error, :invalid_sequence, offset, next_raw}
        end

      :error ->
        {:error, :invalid_sequence, offset + byte_size(raw), <<byte>>}
    end
  end

  defp finish_scalar(value, offset, raw, rest, acc) do
    if valid_scalar?(value) do
      decode_all(rest, offset + byte_size(raw), [value | acc])
    else
      {:error, :invalid_sequence, offset, raw}
    end
  end

  defp continuation_value(byte) when byte in ?0..?9, do: {:ok, byte - ?0}
  defp continuation_value(byte) when byte in ?A..?F, do: {:ok, byte - ?A + 10}
  defp continuation_value(_byte), do: :error

  defp decode_chunk_nonfinal(<<>>, _offset, acc),
    do: {:ok, :lists.reverse(acc), <<>>}

  defp decode_chunk_nonfinal(<<initial, rest::binary>>, offset, acc)
       when initial in ?G..?V,
       do: decode_chunk_cont(rest, initial - ?G, offset, <<initial>>, acc)

  defp decode_chunk_nonfinal(<<byte, _rest::binary>>, offset, _acc),
    do: {:error, :invalid_sequence, offset, <<byte>>}

  defp decode_chunk_cont(<<>>, _value, _offset, raw, acc),
    do: {:ok, :lists.reverse(acc), raw}

  defp decode_chunk_cont(<<initial, _::binary>> = input, value, offset, raw, acc)
       when initial in ?G..?V do
    if valid_scalar?(value) do
      decode_chunk_nonfinal(input, offset + byte_size(raw), [value | acc])
    else
      {:error, :invalid_sequence, offset, raw}
    end
  end

  defp decode_chunk_cont(<<byte, rest::binary>>, value, offset, raw, acc) do
    case continuation_value(byte) do
      {:ok, _digit} when value == 0 ->
        {:error, :invalid_sequence, offset, raw <> <<byte>>}

      {:ok, digit} ->
        next_value = value <<< 4 ||| digit
        next_raw = raw <> <<byte>>

        if next_value <= @max_scalar do
          decode_chunk_cont(rest, next_value, offset, next_raw, acc)
        else
          {:error, :invalid_sequence, offset, next_raw}
        end

      :error ->
        {:error, :invalid_sequence, offset + byte_size(raw), <<byte>>}
    end
  end

  defp discard_all(<<>>, pending, acc),
    do: {:ok, pending |> discard_finish(acc) |> :lists.reverse()}

  defp discard_all(<<initial, rest::binary>>, pending, acc) when initial in ?G..?V do
    discard_all(rest, {initial - ?G, true}, discard_finish(pending, acc))
  end

  defp discard_all(<<byte, rest::binary>>, {value, true}, acc) do
    case continuation_value(byte) do
      {:ok, digit} when value != 0 ->
        next_value = value <<< 4 ||| digit
        discard_all(rest, {next_value, next_value <= @max_scalar}, acc)

      {:ok, _digit} ->
        discard_all(rest, nil, acc)

      _ ->
        discard_all(rest, nil, discard_finish({value, true}, acc))
    end
  end

  defp discard_all(<<_byte, rest::binary>>, _pending, acc),
    do: discard_all(rest, nil, acc)

  defp discard_finish({value, true}, acc) do
    if valid_scalar?(value), do: [value | acc], else: acc
  end

  defp discard_finish(_pending, acc), do: acc

  defp valid_scalar?(codepoint),
    do: codepoint in 0..@max_scalar and codepoint not in 0xD800..0xDFFF
end
