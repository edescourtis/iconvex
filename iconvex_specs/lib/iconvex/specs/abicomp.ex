require Iconvex.Specs.ABICOMP.SourceAsset
require Iconvex.Specs.KermitVersionedSingleByte

Iconvex.Specs.KermitVersionedSingleByte.defcodec(
  Iconvex.Specs.ABICOMP.Native,
  "ABICOMP-NATIVE-INTERNAL",
  [],
  :abicomp_cp3848,
  0x80,
  Iconvex.Specs.ABICOMP.SourceAsset.high_hex(),
  [
    Path.expand("../../../priv/sources/abicomp/abicomp.csv", __DIR__),
    Path.expand("../../../priv/sources/abicomp/SOURCE_METADATA.md", __DIR__)
  ]
)

defmodule Iconvex.Specs.ABICOMP do
  @moduledoc """
  Brazilian ABICOMP text encoding, also known as Brazil-ABICOMP / CP3848.

  The codec is an octet SBCS with ASCII/control identity at `00..7F`, 64
  assigned characters at `A0..DF`, and explicit undefined ranges `80..9F` and
  `E0..FF`. Every assigned mapping is unique, so encoding is the exact inverse.
  """

  use Iconvex.Codec

  alias Iconvex.Specs.ABICOMP.Native

  @impl true
  def canonical_name, do: "ABICOMP"

  @impl true
  def aliases,
    do: ["BRAZIL-ABICOMP", "CP3848", "CODE-PAGE-3848", "FREEDOS-CP3848"]

  @impl true
  def codec_id, do: :abicomp_cp3848

  @impl true
  defdelegate decode(input), to: Native

  @impl true
  defdelegate decode_discard(input), to: Native

  @impl true
  defdelegate encode(codepoints), to: Native

  @impl true
  defdelegate encode_discard(codepoints), to: Native

  @impl true
  defdelegate encode_substitute(codepoints, replacer), to: Native

  @impl true
  defdelegate decode_to_utf8(input), to: Native

  @impl true
  defdelegate encode_from_utf8(input), to: Native

  @impl true
  def decode_chunk(input, _final?) when is_binary(input) do
    case decode(input) do
      {:ok, codepoints} -> {:ok, codepoints, <<>>}
      error -> error
    end
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
end
