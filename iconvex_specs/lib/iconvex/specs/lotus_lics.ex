require Iconvex.Specs.LotusLICS.SourceAsset
require Iconvex.Specs.KermitVersionedSingleByte

Iconvex.Specs.KermitVersionedSingleByte.defcodec(
  Iconvex.Specs.LotusLICS.Native,
  "LICS-NATIVE-INTERNAL",
  [],
  :lotus_lics_hp_1991,
  0x80,
  Iconvex.Specs.LotusLICS.SourceAsset.high_hex(),
  [
    Path.expand("../../../priv/sources/lotus-lics/lotus_lics_hp_1991.csv", __DIR__),
    Path.expand("../../../priv/sources/lotus-lics/SOURCE_METADATA.md", __DIR__)
  ]
)

defmodule Iconvex.Specs.LotusLICS do
  @moduledoc """
  Complete 1991 Lotus International Character Set (LICS) octet codec.

  The table follows the HP 95LX User's Guide Appendix F profile and records the
  four assignments added after the earlier Xerox Release 2/2.01 conversion
  table as an explicit profile distinction. Five accent pairs share Unicode
  combining scalars; encoding selects the lower byte of each pair.
  """

  use Iconvex.Codec

  alias Iconvex.Specs.LotusLICS.Native
  alias Iconvex.Specs.LotusLICS.SourceAsset

  @impl true
  def canonical_name, do: "LICS"

  @impl true
  def aliases, do: ["LOTUS-INTERNATIONAL-CHARACTER-SET"]

  @impl true
  def codec_id, do: :lotus_lics_hp_1991

  def unit_bits, do: 8
  def mapping_sha256, do: SourceAsset.mapping_sha256()
  def metadata_sha256, do: SourceAsset.metadata_sha256()
  def source_sha256(source), do: SourceAsset.source_sha256(source)
  def source_url(source), do: SourceAsset.source_url(source)
  def source_size(source), do: SourceAsset.source_size(source)
  def source_pages(source), do: SourceAsset.source_pages(source)
  def profile_counts, do: SourceAsset.profile_counts()
  def earlier_profile_differences, do: SourceAsset.earlier_profile_differences()
  def reverse_policy, do: SourceAsset.reverse_policy()
  def gnu_fixture_sha256(fixture), do: SourceAsset.gnu_fixture_sha256(fixture)
  def gnu_libiconv_support, do: :unsupported
  def packed_applicability, do: :not_applicable_octet_codec

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
