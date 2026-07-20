require Iconvex.Specs.VSCII2.SourceAsset
require Iconvex.Specs.KermitVersionedSingleByte

Iconvex.Specs.KermitVersionedSingleByte.defcodec(
  Iconvex.Specs.VSCII2.Native,
  "VSCII-2-NATIVE-INTERNAL",
  [],
  :vscii_2,
  0x80,
  Iconvex.Specs.VSCII2.SourceAsset.high_hex(),
  [
    Path.expand("../../../priv/sources/vscii-2/vscii2.csv", __DIR__),
    Path.expand("../../../priv/sources/vscii-2/SOURCE_METADATA.md", __DIR__)
  ]
)

defmodule Iconvex.Specs.VSCII2 do
  @moduledoc """
  VSCII-2, the VN2 profile of TCVN 5712:1993 registered as ISO-IR-180.

  This octet codec preserves ASCII, C0 controls, and DEL at `00..7F`, rejects
  the undefined C1 range `80..9F`, and maps the complete 96-character
  ISO-IR-180 right-hand set at `A0..FF`. Combining-mark positions are exposed
  as raw Unicode scalars; conversion never performs implicit normalization.

  VSCII-2 is distinct from RFC 1456 VISCII and from TCVN 5712 VN1 (`TCVN`).
  """

  use Iconvex.Codec

  alias Iconvex.Specs.VSCII2.Native

  @impl true
  def canonical_name, do: "VSCII-2"

  @impl true
  def aliases do
    [
      "VSCII",
      "TCVN-5712-2",
      "TCVN5712-2",
      "TCVN5712-2:1993",
      "TCVN-VN2",
      "VN2",
      "ISO-IR-180"
    ]
  end

  @impl true
  def codec_id, do: :vscii_2

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
