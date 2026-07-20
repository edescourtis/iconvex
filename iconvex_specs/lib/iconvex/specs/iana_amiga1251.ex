defmodule Iconvex.Specs.IANAAmiga1251 do
  @moduledoc "Official IANA Amiga-1251 registration table."

  use Iconvex.Codec

  @table_path Path.expand("../../../priv/iana_amiga1251.etf", __DIR__)
  @manifest_path Path.expand("../../../priv/iana_amiga1251_manifest.etf", __DIR__)
  @external_resource @table_path
  @external_resource @manifest_path
  @table @table_path |> File.read!() |> :erlang.binary_to_term()
  @manifest @manifest_path |> File.read!() |> :erlang.binary_to_term()
  @decode @table.decode
  @encode @table.encode

  @impl true
  def canonical_name, do: "Amiga-1251"

  @impl true
  def aliases, do: ["Ami1251", "Amiga1251", "Ami-1251", "csAmiga1251"]

  @impl true
  def codec_id, do: :iana_amiga1251

  @impl true
  def decode(input) when is_binary(input), do: {:ok, decode_bytes(input, [])}

  @impl true
  def decode_discard(input) when is_binary(input), do: decode(input)

  @impl true
  def decode_to_utf8(input) when is_binary(input) do
    {:ok, input |> decode_bytes([]) |> List.to_string()}
  end

  @impl true
  def encode(codepoints) when is_list(codepoints), do: encode_all(codepoints, [])

  @impl true
  def encode_discard(codepoints) when is_list(codepoints) do
    {:ok, codepoints |> encode_discard_all([]) |> :lists.reverse() |> :binary.list_to_bin()}
  end

  @impl true
  def encode_substitute(codepoints, replacer),
    do: Iconvex.Specs.CodecSupport.encode_substitute_each(codepoints, &encode/1, replacer)

  @impl true
  def encode_from_utf8(input) when is_binary(input),
    do: Iconvex.Specs.CodecSupport.encode_utf8(input, &encode/1)

  def source_url, do: @manifest.source_url
  def source_sha256, do: @manifest.source_sha256

  defp decode_bytes(<<>>, result), do: :lists.reverse(result)

  defp decode_bytes(<<byte, rest::binary>>, result),
    do: decode_bytes(rest, [elem(@decode, byte) | result])

  defp encode_all([], result), do: {:ok, result |> :lists.reverse() |> :binary.list_to_bin()}

  defp encode_all([codepoint | rest], result) do
    case Map.fetch(@encode, codepoint) do
      {:ok, byte} -> encode_all(rest, [byte | result])
      :error -> {:error, :unrepresentable_character, codepoint}
    end
  end

  defp encode_discard_all([], result), do: result

  defp encode_discard_all([codepoint | rest], result) do
    case Map.fetch(@encode, codepoint) do
      {:ok, byte} -> encode_discard_all(rest, [byte | result])
      :error -> encode_discard_all(rest, result)
    end
  end
end
