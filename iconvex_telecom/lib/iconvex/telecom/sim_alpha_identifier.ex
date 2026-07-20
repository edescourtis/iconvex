defmodule Iconvex.Telecom.SIMAlphaIdentifier do
  @moduledoc """
  SIM/USIM alpha identifiers using GSM default, UCS2 `0x80`, and compressed
  UCS2 `0x81`/`0x82` forms.

  ETSI TS 102 221 section 8.2 limits a complete linear-fixed UICC record to
  255 octets. Both decoding and encoding enforce that record boundary; an
  earlier malformed unit inside the record takes precedence over excess bytes.

  The lossless default preserves complete trailing `0xFFFF` code units in a
  `0x80` field. Fixed-record callers that know trailing `0xFF` octets are
  unused field space can pass `padding: :trim`. This choice is explicit
  because an aligned `0xFFFF` at the end is byte-identical to two padding
  octets when field length is not supplied separately.
  """

  import Bitwise

  alias Iconvex.Telecom.GSM0338

  @max_bytes 255

  @doc "Maximum size, in octets, of one complete SIM/UICC alpha-identifier record."
  def max_bytes, do: @max_bytes

  def decode(input, options \\ [])

  def decode(input, options) when is_binary(input) and is_list(options) do
    with {:ok, padding} <- padding_policy(options) do
      decode_bounded(input, padding)
    end
  end

  def decode(_input, _options), do: {:error, :invalid_options}

  defp decode_bounded(input, padding) when byte_size(input) <= @max_bytes,
    do: decode_with_padding(input, padding)

  defp decode_bounded(input, padding) do
    record = binary_part(input, 0, @max_bytes)

    case decode_with_padding(record, padding) do
      {:ok, _decoded} -> {:error, {:alpha_identifier_too_long, byte_size(input)}}
      earlier_error -> earlier_error
    end
  end

  defp decode_with_padding(<<0x80, data::binary>>, padding),
    do: decode_ucs2(trim_ucs2_padding(data, padding))

  defp decode_with_padding(<<0x81, length, base, rest::binary>>, _padding),
    do: decode_compressed(rest, length, base <<< 7)

  defp decode_with_padding(<<0x82, length, base::16-big, rest::binary>>, _padding),
    do: decode_compressed(rest, length, base)

  defp decode_with_padding(<<prefix, _rest::binary>>, _padding) when prefix in [0x81, 0x82],
    do: {:error, :truncated_alpha_identifier}

  defp decode_with_padding(data, _padding), do: GSM0338.decode_utf8(trim_padding(data))

  def encode(utf8, options \\ [])

  def encode(utf8, options) when is_binary(utf8) and is_list(options) do
    with {:ok, mode} <- encoding_mode(options) do
      utf8
      |> encode_mode(mode)
      |> limit_encoded_record()
    end
  end

  def encode(_utf8, _options), do: {:error, :invalid_options}

  defp limit_encoded_record({:ok, encoded}) when byte_size(encoded) <= @max_bytes,
    do: {:ok, encoded}

  defp limit_encoded_record({:ok, encoded}),
    do: {:error, {:alpha_identifier_too_long, byte_size(encoded)}}

  defp limit_encoded_record(result), do: result

  defp encoding_mode(options) do
    cond do
      not Keyword.keyword?(options) ->
        {:error, :invalid_options}

      Keyword.keys(options) -- [:mode] != [] ->
        {:error, :invalid_options}

      Keyword.keys(options) |> Enum.frequencies() |> Map.get(:mode, 0) > 1 ->
        {:error, :invalid_options}

      true ->
        {:ok, Keyword.get(options, :mode, :auto)}
    end
  end

  defp encode_mode(utf8, :auto) do
    case GSM0338.encode_utf8(utf8) do
      {:ok, encoded} -> {:ok, encoded}
      _error -> encode_auto_compressed(utf8)
    end
  end

  defp encode_mode(utf8, :gsm), do: GSM0338.encode_utf8(utf8)
  defp encode_mode(utf8, :ucs2), do: encode_ucs2(utf8)
  defp encode_mode(utf8, :compressed_81), do: encode_compressed(utf8, :compressed_81)
  defp encode_mode(utf8, :compressed_82), do: encode_compressed(utf8, :compressed_82)
  defp encode_mode(_utf8, mode), do: {:error, {:unknown_mode, mode}}

  defp encode_auto_compressed(utf8) do
    case encode_compressed(utf8, :compressed_81) do
      {:ok, _encoded} = success ->
        success

      _error ->
        case encode_compressed(utf8, :compressed_82) do
          {:ok, _encoded} = success -> success
          _error -> encode_ucs2(utf8)
        end
    end
  end

  defp decode_ucs2(data) do
    case decode_ucs2_codepoints(data, []) do
      {:ok, codepoints} -> {:ok, List.to_string(codepoints)}
      error -> error
    end
  end

  defp decode_ucs2_codepoints(<<>>, acc), do: {:ok, Enum.reverse(acc)}

  defp decode_ucs2_codepoints(<<_trailing_byte>>, _acc), do: {:error, :truncated_ucs2}

  defp decode_ucs2_codepoints(<<codepoint::16-big, _rest::binary>>, _acc)
       when codepoint in 0xD800..0xDFFF,
       do: {:error, {:invalid_ucs2, codepoint}}

  defp decode_ucs2_codepoints(<<codepoint::16-big, rest::binary>>, acc),
    do: decode_ucs2_codepoints(rest, [codepoint | acc])

  defp encode_ucs2(utf8) do
    codepoints = String.to_charlist(utf8)

    case Enum.find(codepoints, &(&1 > 0xFFFF or &1 in 0xD800..0xDFFF)) do
      nil -> {:ok, [<<0x80>> | Enum.map(codepoints, &<<&1::16-big>>)] |> IO.iodata_to_binary()}
      codepoint -> {:error, {:not_representable_in_ucs2, codepoint}}
    end
  end

  defp decode_compressed(rest, length, base) do
    payload_size = min(length, byte_size(rest))
    <<payload::binary-size(payload_size), _padding::binary>> = rest

    case decode_compressed_payload(payload, base, []) do
      {:ok, _decoded} when payload_size < length -> {:error, :truncated_alpha_identifier}
      result -> result
    end
  end

  defp decode_compressed_payload(<<>>, _base, acc),
    do: {:ok, acc |> Enum.reverse() |> IO.iodata_to_binary()}

  defp decode_compressed_payload(<<byte, rest::binary>>, base, acc) when byte >= 0x80 do
    codepoint = base + (byte &&& 0x7F)

    if scalar_ucs2?(codepoint) do
      decode_compressed_payload(rest, base, [<<codepoint::utf8>> | acc])
    else
      {:error, {:invalid_ucs2, codepoint}}
    end
  end

  defp decode_compressed_payload(<<0x1B, extension, rest::binary>>, base, acc)
       when extension < 0x80 do
    with {:ok, utf8} <- GSM0338.decode_utf8(<<0x1B, extension>>) do
      decode_compressed_payload(rest, base, [utf8 | acc])
    end
  end

  defp decode_compressed_payload(<<byte, rest::binary>>, base, acc) do
    with {:ok, utf8} <- GSM0338.decode_utf8(<<byte>>) do
      decode_compressed_payload(rest, base, [utf8 | acc])
    end
  end

  defp encode_compressed(utf8, mode) do
    codepoints = String.to_charlist(utf8)
    parts = Enum.map(codepoints, &compressed_part/1)

    with {:ok, base} <- compressed_base(parts, mode),
         {:ok, payload} <- compressed_payload(parts, base) do
      encode_compressed_payload(payload, base, mode)
    else
      _ -> {:error, compressed_error(mode)}
    end
  end

  defp encode_compressed_payload(payload, _base, mode) when byte_size(payload) > 255 do
    header_size = if mode == :compressed_81, do: 3, else: 4
    {:error, {:alpha_identifier_too_long, header_size + byte_size(payload)}}
  end

  defp encode_compressed_payload(payload, base, :compressed_81),
    do: {:ok, <<0x81, byte_size(payload), base >>> 7>> <> payload}

  defp encode_compressed_payload(payload, base, :compressed_82),
    do: {:ok, <<0x82, byte_size(payload), base::16-big>> <> payload}

  defp compressed_part(codepoint) do
    case GSM0338.encode([codepoint]) do
      {:ok, bytes} -> {:gsm, bytes}
      _error -> {:ucs2, codepoint}
    end
  end

  defp compressed_base(parts, mode) do
    unicode = for {:ucs2, codepoint} <- parts, do: codepoint

    case unicode do
      [] -> {:ok, 0}
      values -> choose_base(Enum.min(values), Enum.max(values), mode)
    end
  end

  defp choose_base(minimum, maximum, :compressed_81) do
    base = minimum &&& 0xFF80

    if base <= 0x7F80 and maximum <= base + 127, do: {:ok, base}, else: :error
  end

  defp choose_base(minimum, maximum, :compressed_82) do
    if minimum <= 0xFFFF and maximum <= minimum + 127, do: {:ok, minimum}, else: :error
  end

  defp compressed_payload(parts, base) do
    parts
    |> Enum.reduce_while([], fn
      {:gsm, bytes}, acc ->
        {:cont, [bytes | acc]}

      {:ucs2, codepoint}, acc when codepoint >= base and codepoint <= base + 127 ->
        {:cont, [<<codepoint - base ||| 0x80>> | acc]}

      _part, _acc ->
        {:halt, :error}
    end)
    |> case do
      :error -> :error
      acc -> {:ok, acc |> Enum.reverse() |> IO.iodata_to_binary()}
    end
  end

  defp compressed_error(:compressed_81), do: :not_representable_in_compressed_81
  defp compressed_error(:compressed_82), do: :not_representable_in_compressed_82

  defp scalar_ucs2?(codepoint), do: codepoint <= 0xFFFF and codepoint not in 0xD800..0xDFFF

  defp padding_policy(options) do
    cond do
      not Keyword.keyword?(options) ->
        {:error, :invalid_options}

      Keyword.keys(options) -- [:padding] != [] ->
        {:error, :invalid_options}

      Keyword.keys(options) |> Enum.frequencies() |> Map.get(:padding, 0) > 1 ->
        {:error, :invalid_options}

      true ->
        padding = Keyword.get(options, :padding, :preserve)

        if padding in [:preserve, :trim],
          do: {:ok, padding},
          else: {:error, {:unknown_padding_policy, padding}}
    end
  end

  defp trim_ucs2_padding(data, padding) when rem(byte_size(data), 2) == 1 do
    case data do
      <<content::binary-size(byte_size(data) - 1), 0xFF>> ->
        trim_aligned_ucs2_padding(content, padding)

      _ ->
        data
    end
  end

  defp trim_ucs2_padding(data, padding), do: trim_aligned_ucs2_padding(data, padding)

  defp trim_aligned_ucs2_padding(data, :preserve), do: data

  defp trim_aligned_ucs2_padding(data, :trim) when byte_size(data) >= 2 do
    case data do
      <<content::binary-size(byte_size(data) - 2), 0xFF, 0xFF>> ->
        trim_aligned_ucs2_padding(content, :trim)

      _ ->
        data
    end
  end

  defp trim_aligned_ucs2_padding(data, :trim), do: data

  defp trim_padding(data), do: String.trim_trailing(data, <<0xFF>>)
end
