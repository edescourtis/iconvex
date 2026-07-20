defmodule Iconvex.Specs.VIQR do
  @moduledoc "VIQR 1.1 Vietnamese quoted-readable charset from RFC 1456."

  use Iconvex.Codec

  @path Path.expand("../../../priv/viqr_manifest.etf", __DIR__)
  @external_resource @path
  @manifest @path |> File.read!() |> :erlang.binary_to_term()
  @decode Map.new(@manifest.mappings, &{&1.token, &1.codepoint})
  @encode Map.new(@manifest.mappings, &{&1.codepoint, &1.token})
  @tokens @decode |> Map.keys() |> Enum.sort_by(&byte_size/1, :desc)

  def canonical_name, do: "VIQR"
  def aliases, do: ["csVIQR", "VIQR-1.1"]
  def codec_id, do: :viqr
  def stateful?, do: true
  def mappings, do: @manifest.mappings
  def source, do: @manifest.source

  def decode(input) when is_binary(input), do: decode_all(input, 0, [])
  def decode_discard(input) when is_binary(input), do: decode_discard_all(input, [])
  def encode(codepoints) when is_list(codepoints), do: encode_all(codepoints, [])

  def encode_discard(codepoints) when is_list(codepoints) do
    codepoints
    |> Enum.filter(&representable?/1)
    |> encode_all([])
  end

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
    Iconvex.Specs.CodecSupport.encode_utf8(input, &encode/1)
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

  defp decode_one(<<?\\>> = input), do: {:error, :incomplete_sequence, input}
  defp decode_one(<<?\\, escaped, rest::binary>>) when escaped < 0x80, do: {:ok, escaped, rest}

  defp decode_one(input) do
    case Enum.find(@tokens, &String.starts_with?(input, &1)) do
      nil ->
        case input do
          <<byte, rest::binary>> when byte < 0x80 -> {:ok, byte, rest}
          <<byte, _::binary>> -> {:error, :invalid_sequence, <<byte>>}
          <<>> -> {:error, :incomplete_sequence, <<>>}
        end

      token ->
        <<_::binary-size(byte_size(token)), rest::binary>> = input
        {:ok, Map.fetch!(@decode, token), rest}
    end
  end

  defp encode_all([], acc), do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_all([current, next | rest], acc) do
    with {:ok, current_token, current_mapped?} <- raw_token(current),
         {:ok, next_token, next_mapped?} <- raw_token(next) do
      cond do
        current == ?\\ ->
          encode_all([next | rest], ["\\\\" | acc])

        extends_token?(current_token, next_token) and not current_mapped? and next_mapped? ->
          encode_all([next | rest], [["\\", current_token] | acc])

        extends_token?(current_token, next_token) and not next_mapped? ->
          encode_all(rest, [[current_token, "\\", next_token] | acc])

        true ->
          encode_all([next | rest], [current_token | acc])
      end
    else
      :error -> {:error, :unrepresentable_character, first_unrepresentable(current, next)}
    end
  end

  defp encode_all([?\\], acc), do: encode_all([], ["\\\\" | acc])

  defp encode_all([codepoint], acc) do
    case raw_token(codepoint) do
      {:ok, token, _mapped?} -> encode_all([], [token | acc])
      :error -> {:error, :unrepresentable_character, codepoint}
    end
  end

  defp raw_token(codepoint) when is_integer(codepoint) and codepoint in 0..0x7F,
    do: {:ok, <<codepoint>>, false}

  defp raw_token(codepoint) when is_integer(codepoint) do
    case Map.fetch(@encode, codepoint) do
      {:ok, token} -> {:ok, token, true}
      :error -> :error
    end
  end

  defp raw_token(_codepoint), do: :error

  defp extends_token?(current, next) do
    combined = current <> next

    Enum.any?(@tokens, fn token ->
      byte_size(token) > byte_size(current) and String.starts_with?(combined, token)
    end)
  end

  defp first_unrepresentable(current, next) do
    if raw_token(current) == :error, do: current, else: next
  end

  defp representable?(codepoint),
    do: is_integer(codepoint) and (codepoint in 0..0x7F or Map.has_key?(@encode, codepoint))

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
end
