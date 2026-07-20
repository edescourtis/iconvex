defmodule Iconvex.Specs.CPythonISO2022JPExt do
  @moduledoc """
  CPython 3.14.6 `iso2022_jp_ext` codec.

  Supports JIS X 0208 (1983 and 1978 designations), JIS X 0212, JIS X 0201
  Roman, and JIS X 0201 Kana using CPython's `NO_SHIFT | USE_JISX0208_EXT`
  configuration.
  """

  use Iconvex.Codec

  @entry %{id: :iso2022_jp_ext}
  @revision "c63aec69bd59c55314c06c23f4c22c03de76fe45"
  @source_dir Path.expand("../../../priv/sources/cpython-3.14.6-iso2022-jp-ext", __DIR__)
  @external_resource Path.join(@source_dir, "_codecs_iso2022.c")
  @external_resource Path.join(@source_dir, "mappings_jp.h")
  @external_resource Path.join(@source_dir, "iso2022_jp_ext.py")

  @impl true
  def canonical_name, do: "ISO-2022-JP-EXT"

  @impl true
  def aliases,
    do: ["ISO2022-JP-EXT", "ISO2022_JP_EXT", "PYTHON-ISO2022-JP-EXT"]

  @impl true
  def codec_id, do: :iso2022_jp_ext

  @impl true
  def stateful?, do: true

  def revision, do: @revision

  def sources do
    %{
      "_codecs_iso2022.c" => "1dec516ad16a9aa179770b5accdd20efa77e7265c0a2a06d8d8913e4524c4010",
      "mappings_jp.h" => "09012ff9eb963073d42a8bce375c05484219537caa0cc2aa74baa63d5f3f1658",
      "iso2022_jp_ext.py" => "f4c9ed8f3031995faa224bcb10153d2b6144944477d1f27d1a6cc4a879fac34c"
    }
  end

  @impl true
  def decode(input), do: Iconvex.ISO2022JPCodec.decode(@entry, input)

  @impl true
  def decode_discard(input), do: Iconvex.ISO2022JPCodec.decode_discard(@entry, input)

  @impl true
  def encode(codepoints), do: Iconvex.ISO2022JPCodec.encode(@entry, codepoints)

  @impl true
  def encode_discard(codepoints), do: Iconvex.ISO2022JPCodec.encode_discard(@entry, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: Iconvex.ISO2022JPCodec.encode_substitute(@entry, codepoints, replacer)

  @impl true
  def decode_to_utf8(input) do
    with {:ok, codepoints} <- decode(input), do: {:ok, List.to_string(codepoints)}
  end

  @impl true
  def encode_from_utf8(input) when is_binary(input),
    do: Iconvex.Specs.CodecSupport.encode_utf8(input, &encode/1)
end
