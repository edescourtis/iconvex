defmodule Iconvex.Specs.XUserDefined do
  @moduledoc "The single-byte x-user-defined encoding from the WHATWG Encoding Standard."

  use Iconvex.Codec

  @impl true
  def canonical_name, do: "X-USER-DEFINED"

  @impl true
  def aliases, do: ["x_user_defined"]

  @impl true
  def codec_id, do: :x_user_defined

  @impl true
  def decode(input) when is_binary(input) do
    {:ok, for(<<byte <- input>>, do: if(byte < 0x80, do: byte, else: byte + 0xF700))}
  end

  @impl true
  def decode_discard(input) when is_binary(input), do: decode(input)

  @impl true
  def encode(codepoints) when is_list(codepoints), do: encode_all(codepoints, [])

  @impl true
  def encode_discard(codepoints) when is_list(codepoints), do: encode_discard_all(codepoints, [])

  @impl true
  def encode_substitute(codepoints, replacer),
    do: Iconvex.Specs.CodecSupport.encode_substitute_each(codepoints, &encode/1, replacer)

  @impl true
  def decode_to_utf8(input) do
    with {:ok, codepoints} <- decode(input), do: {:ok, List.to_string(codepoints)}
  end

  @impl true
  def encode_from_utf8(input) when is_binary(input),
    do: Iconvex.Specs.CodecSupport.encode_utf8(input, &encode/1)

  defp encode_all([], acc), do: {:ok, acc |> :lists.reverse() |> :erlang.list_to_binary()}

  defp encode_all([codepoint | rest], acc) when codepoint in 0..0x7F,
    do: encode_all(rest, [codepoint | acc])

  defp encode_all([codepoint | rest], acc) when codepoint in 0xF780..0xF7FF,
    do: encode_all(rest, [codepoint - 0xF700 | acc])

  defp encode_all([codepoint | _rest], _acc),
    do: {:error, :unrepresentable_character, codepoint}

  defp encode_discard_all([], acc),
    do: {:ok, acc |> :lists.reverse() |> :erlang.list_to_binary()}

  defp encode_discard_all([codepoint | rest], acc) when codepoint in 0..0x7F,
    do: encode_discard_all(rest, [codepoint | acc])

  defp encode_discard_all([codepoint | rest], acc) when codepoint in 0xF780..0xF7FF,
    do: encode_discard_all(rest, [codepoint - 0xF700 | acc])

  defp encode_discard_all([_codepoint | rest], acc), do: encode_discard_all(rest, acc)
end
