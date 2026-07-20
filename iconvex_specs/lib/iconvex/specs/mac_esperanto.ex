require Iconvex.Specs.KermitVersionedSingleByte

Iconvex.Specs.KermitVersionedSingleByte.defcodec(
  Iconvex.Specs.MacEsperanto.Native,
  "MACOS_ESPERANTO-NATIVE-INTERNAL",
  [],
  :macos_esperanto_0_3,
  0x80,
  Iconvex.Specs.MacEsperanto.SourceAsset.high_hex(),
  [
    Path.expand("../../../priv/sources/mac-esperanto/macos_esperanto_0_3.csv", __DIR__),
    Path.expand("../../../priv/sources/mac-esperanto/SOURCE_METADATA.md", __DIR__)
  ]
)

defmodule Iconvex.Specs.MacEsperanto do
  @moduledoc """
  MacOS Esperanto table version 0.3, a bijective Macintosh single-byte codec.

  The 223 graphic positions are pinned to Michael Everson's 15 August 1997
  `MacOS_Esperanto` to-Unicode table. The source omits C0 and DEL; this codec
  declares an explicit Unicode-identity transport for those 33 byte positions.
  """

  use Iconvex.Codec

  alias Iconvex.Specs.MacEsperanto.Native
  alias Iconvex.Specs.MacEsperanto.SourceAsset

  @impl true
  def canonical_name, do: "MACOS_ESPERANTO"

  @impl true
  def aliases, do: ["MACESPERANTO", "MAC-ESPERANTO", "MACOS-ESPERANTO"]

  @impl true
  def codec_id, do: :macos_esperanto_0_3

  def unit_bits, do: 8
  def mapping_sha256, do: SourceAsset.mapping_sha256()
  def metadata_sha256, do: SourceAsset.metadata_sha256()
  def upstream_sha256, do: SourceAsset.upstream_sha256()
  def source_size, do: SourceAsset.source_size()
  def source_version, do: SourceAsset.source_version()
  def source_date, do: SourceAsset.source_date()
  def source_author, do: SourceAsset.source_author()
  def source_url, do: SourceAsset.source_url()
  def gnu_fixture_sha256(fixture), do: SourceAsset.gnu_fixture_sha256(fixture)
  def gnu_libiconv_support, do: :unsupported
  def packed_applicability, do: :not_applicable_octet_codec

  def transport_policy do
    %{
      ascii_graphics: :source_identity,
      c0_controls: :unicode_identity,
      delete: :unicode_identity,
      high_half: :source_mapping_0_3
    }
  end

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
