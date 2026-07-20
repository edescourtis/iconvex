defmodule Iconvex.Telecom.IA5 do
  @moduledoc """
  ITU-T T.50 International Reference Alphabet (formerly IA5/ITA5).

  T.50 defines a seven-bit code. The codec representation stores one complete
  seven-bit unit in each octet and requires the high bit to be zero. Use
  `Iconvex.Telecom.IA5.Packing` when consecutive seven-bit fields are needed.
  The in-force IRV is bit-for-bit ASCII, including C0 controls and DELETE;
  this separate registration preserves the telecom-standard names and framing
  contract.
  """

  use Iconvex.Telecom.SubstitutionCodec

  @source_manifest %{
    recommendation: "ITU-T T.50 (09/1992)",
    source_sha256: "849a6848640618846f4688c9f65884af1c54d51c9228141d9c13eec33f2a9c88",
    source_url:
      "https://www.itu.int/rec/dologin_pub.asp?id=T-REC-T.50-199209-I!!PDF-E&lang=e&type=items"
  }

  @impl true
  def canonical_name, do: "ITU-T-T.50-IRV"

  @impl true
  def aliases,
    do: [
      "ITU-T-T.50",
      "T.50-IRV",
      "T50-IRV",
      "IRA",
      "IA5",
      "ITA5",
      "ITA-5",
      "CCITT-5",
      "CCITT5",
      "CCITT-NO-5",
      "INTERNATIONAL-ALPHABET-NO-5",
      "INTERNATIONAL-TELEGRAPH-ALPHABET-NO-5",
      "RECOMMENDATION-V.3-IA5",
      "ISO-646-IRV:1991"
    ]

  @impl true
  def stateful?, do: false

  @doc "Returns the pinned in-force ITU-T source identity."
  def source_manifest, do: @source_manifest

  @doc "Returns all 128 IRV code positions."
  def table, do: Map.new(0..127, &{&1, &1})

  @impl true
  def decode(input) when is_binary(input), do: decode_loop(input, 0, [])

  @impl true
  def decode_discard(input) when is_binary(input), do: decode_discard_loop(input, [])

  @impl true
  def decode_to_utf8(input) when is_binary(input) do
    with {:ok, codepoints} <- decode(input), do: {:ok, List.to_string(codepoints)}
  end

  @impl true
  def encode(codepoints) when is_list(codepoints), do: encode_loop(codepoints, [])

  @impl true
  def encode_discard(codepoints) when is_list(codepoints),
    do: encode_discard_loop(codepoints, [])

  @impl true
  def encode_from_utf8(input) when is_binary(input) do
    case :unicode.characters_to_list(input, :utf8) do
      codepoints when is_list(codepoints) ->
        encode_utf8_codepoints(codepoints)

      {:incomplete, converted, rest} ->
        utf8_error(converted, :incomplete_sequence, input, rest)

      {:error, converted, rest} ->
        utf8_error(converted, :invalid_sequence, input, rest)
    end
  end

  defp decode_loop(<<>>, _offset, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_loop(<<byte, _rest::binary>>, offset, _acc) when byte > 127,
    do: {:error, :invalid_sequence, offset, <<byte>>}

  defp decode_loop(<<byte, rest::binary>>, offset, acc),
    do: decode_loop(rest, offset + 1, [byte | acc])

  defp decode_discard_loop(<<>>, acc), do: {:ok, :lists.reverse(acc)}

  defp decode_discard_loop(<<byte, rest::binary>>, acc) when byte > 127,
    do: decode_discard_loop(rest, acc)

  defp decode_discard_loop(<<byte, rest::binary>>, acc),
    do: decode_discard_loop(rest, [byte | acc])

  defp encode_loop([], acc), do: {:ok, binary_result(acc)}

  defp encode_loop([codepoint | rest], acc) when codepoint in 0..127,
    do: encode_loop(rest, [codepoint | acc])

  defp encode_loop([codepoint | _rest], _acc),
    do: {:error, :unrepresentable_character, codepoint}

  defp encode_discard_loop([], acc), do: {:ok, binary_result(acc)}

  defp encode_discard_loop([codepoint | rest], acc) when codepoint in 0..127,
    do: encode_discard_loop(rest, [codepoint | acc])

  defp encode_discard_loop([_codepoint | rest], acc),
    do: encode_discard_loop(rest, acc)

  defp encode_utf8_codepoints(codepoints) do
    case encode(codepoints) do
      {:error, kind, codepoint} -> {:encode_error, kind, codepoint}
      result -> result
    end
  end

  defp utf8_error(converted, kind, input, rest) do
    case encode(converted) do
      {:error, encode_kind, codepoint} -> {:encode_error, encode_kind, codepoint}
      {:ok, _prefix} -> {:decode_error, kind, byte_size(input) - byte_size(rest), rest}
    end
  end

  defp binary_result(acc), do: acc |> :lists.reverse() |> :erlang.list_to_binary()
end
