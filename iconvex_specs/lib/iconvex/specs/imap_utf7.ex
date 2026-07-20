defmodule Iconvex.Specs.IMAPUTF7 do
  @moduledoc "Modified UTF-7 mailbox names as defined by RFC 3501 section 5.1.3."

  use Iconvex.Codec
  import Bitwise

  @impl true
  def canonical_name, do: "UTF-7-IMAP"

  @impl true
  def aliases, do: ["IMAP-UTF-7", "IMAP-MODIFIED-UTF-7", "MODIFIED-UTF-7"]

  @impl true
  def codec_id, do: :imap_utf7

  @impl true
  def stateful?, do: true

  @impl true
  def decode(input) when is_binary(input), do: decode_all(input, 0, [])

  @impl true
  def decode_discard(input) when is_binary(input), do: decode_discard_all(input, [])

  @impl true
  def encode(codepoints) when is_list(codepoints), do: encode_all(codepoints, [])

  @impl true
  def encode_discard(codepoints) when is_list(codepoints) do
    codepoints
    |> Enum.filter(&valid_scalar?/1)
    |> encode_all([])
  end

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

  @impl true
  def decode_error_consumption(_kind, sequence), do: max(byte_size(sequence), 1)

  @impl true
  def stream_decoder_init, do: nil

  @impl true
  def decode_chunk(input, state, final?) when is_binary(input) do
    case decode(input) do
      {:ok, codepoints} ->
        {:ok, codepoints, state, <<>>}

      {:error, :incomplete_sequence, offset, sequence}
      when not final? and offset + byte_size(sequence) == byte_size(input) ->
        prefix = binary_part(input, 0, offset)

        case decode(prefix) do
          {:ok, codepoints} -> {:ok, codepoints, state, sequence}
          error -> error
        end

      error ->
        error
    end
  end

  @impl true
  def stream_encoder_init, do: nil

  @impl true
  def encode_chunk(codepoints, state, false, _policy) when is_list(codepoints),
    do: {:ok, <<>>, state, codepoints}

  def encode_chunk(codepoints, state, true, policy) when is_list(codepoints) do
    case encode_with_policy(codepoints, policy) do
      {:ok, output} -> {:ok, output, state, []}
      error -> error
    end
  end

  defp decode_all(<<>>, _offset, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_all(input, offset, acc) do
    case decode_one(input) do
      {:ok, codepoints, rest} ->
        consumed = byte_size(input) - byte_size(rest)
        decode_all(rest, offset + consumed, :lists.reverse(codepoints, acc))

      {:error, kind, sequence} ->
        {:error, kind, offset, sequence}
    end
  end

  defp decode_one(<<"&-", rest::binary>>), do: {:ok, [?&], rest}

  defp decode_one(<<?&, rest::binary>> = input) do
    case :binary.match(rest, "-") do
      :nomatch ->
        {:error, :incomplete_sequence, input}

      {length, 1} ->
        token = binary_part(rest, 0, length)
        sequence = binary_part(input, 0, length + 2)
        tail = binary_part(rest, length + 1, byte_size(rest) - length - 1)

        case decode_shift(token) do
          {:ok, codepoints} -> {:ok, codepoints, tail}
          :error -> {:error, :invalid_sequence, sequence}
        end
    end
  end

  defp decode_one(<<byte, rest::binary>>) when byte in 0x20..0x7E,
    do: {:ok, [byte], rest}

  defp decode_one(<<byte, _::binary>>), do: {:error, :invalid_sequence, <<byte>>}
  defp decode_one(<<>>), do: {:error, :incomplete_sequence, <<>>}

  defp decode_shift(<<>>), do: :error

  defp decode_shift(token) do
    if valid_modified_base64?(token) do
      base64 = :binary.replace(token, ",", "/", [:global])

      with {:ok, bytes} <- Base.decode64(base64, padding: false),
           true <- Base.encode64(bytes, padding: false) == base64,
           {:ok, codepoints} <- decode_utf16be(bytes),
           false <- Enum.any?(codepoints, &direct?/1) do
        {:ok, codepoints}
      else
        _ -> :error
      end
    else
      :error
    end
  end

  defp encode_all([], acc), do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_all([?& | rest], acc), do: encode_all(rest, ["&-" | acc])

  defp encode_all([codepoint | rest], acc) when codepoint in 0x20..0x7E,
    do: encode_all(rest, [<<codepoint>> | acc])

  defp encode_all([codepoint | _rest], _acc) when not is_integer(codepoint),
    do: {:error, :unrepresentable_character, codepoint}

  defp encode_all([codepoint | rest], acc) do
    if valid_scalar?(codepoint) do
      {group, tail} =
        Enum.split_while([codepoint | rest], &(valid_scalar?(&1) and not direct?(&1)))

      utf16 = encode_utf16be(group, [])

      token =
        utf16
        |> Base.encode64(padding: false)
        |> :binary.replace("/", ",", [:global])

      encode_all(tail, [["&", token, "-"] | acc])
    else
      {:error, :unrepresentable_character, codepoint}
    end
  end

  defp decode_discard_all(<<>>, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_discard_all(input, acc) do
    case decode_one(input) do
      {:ok, codepoints, rest} ->
        decode_discard_all(rest, :lists.reverse(codepoints, acc))

      {:error, _kind, sequence} ->
        discard = max(byte_size(sequence), 1)

        rest =
          binary_part(input, min(discard, byte_size(input)), max(byte_size(input) - discard, 0))

        decode_discard_all(rest, acc)
    end
  end

  defp encode_utf16be([], acc), do: acc |> :lists.reverse() |> IO.iodata_to_binary()

  defp encode_utf16be([codepoint | rest], acc) when codepoint <= 0xFFFF,
    do: encode_utf16be(rest, [<<codepoint::16-big>> | acc])

  defp encode_utf16be([codepoint | rest], acc) do
    value = codepoint - 0x10000
    high = 0xD800 + (value >>> 10)
    low = 0xDC00 + (value &&& 0x3FF)
    encode_utf16be(rest, [<<high::16-big, low::16-big>> | acc])
  end

  defp decode_utf16be(input), do: decode_utf16be(input, [])
  defp decode_utf16be(<<>>, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_utf16be(<<high::16-big, low::16-big, rest::binary>>, acc)
       when high in 0xD800..0xDBFF and low in 0xDC00..0xDFFF do
    codepoint = 0x10000 + ((high - 0xD800) <<< 10) + low - 0xDC00
    decode_utf16be(rest, [codepoint | acc])
  end

  defp decode_utf16be(<<unit::16-big, rest::binary>>, acc)
       when unit not in 0xD800..0xDFFF,
       do: decode_utf16be(rest, [unit | acc])

  defp decode_utf16be(_input, _acc), do: :error

  defp direct?(codepoint), do: codepoint in 0x20..0x7E and codepoint != ?&

  defp valid_scalar?(codepoint),
    do: is_integer(codepoint) and codepoint in 0..0x10FFFF and codepoint not in 0xD800..0xDFFF

  defp valid_modified_base64?(token) do
    for <<byte <- token>>, reduce: true do
      valid -> valid and (byte in ?A..?Z or byte in ?a..?z or byte in ?0..?9 or byte in [?+, ?,])
    end
  end

  defp encode_with_policy(codepoints, :error), do: encode(codepoints)
  defp encode_with_policy(codepoints, :discard), do: encode_discard(codepoints)

  defp encode_with_policy(codepoints, {:replace, replacer}),
    do: encode_substitute(codepoints, replacer)
end
