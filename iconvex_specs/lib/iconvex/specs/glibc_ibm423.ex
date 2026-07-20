defmodule Iconvex.Specs.GlibcIBM423 do
  @moduledoc """
  IBM423 mapping at pinned glibc revision
  `e5145be467bed28bafde33a51df97840be37065e`.

  Kept under collision-free names because GNU libiconv's `IBM-423` table differs
  at six byte positions and remains available from `iconvex_extras`.
  """

  use Iconvex.Codec
  alias Iconvex.Specs.CodecSupport

  @revision "e5145be467bed28bafde33a51df97840be37065e"
  @source_dir Path.expand("../../../priv/sources/glibc-#{@revision}-ibm423", __DIR__)
  @external_resource Path.join(@source_dir, "IBM423")
  @external_resource Path.join(@source_dir, "ibm423.c")

  @impl true
  def canonical_name, do: "GLIBC-IBM423"

  @impl true
  def aliases, do: ["IBM423-GLIBC", "GLIBC-CP423", "GLIBC-EBCDIC-CP-GR"]

  @impl true
  def codec_id, do: :glibc_ibm423_e5145be

  def revision, do: @revision

  def sources do
    %{
      "ibm423.c" => "0d1f50f21a2b7ec6375e1ad8a35258b3993d0220b7d4089fb0408e229ae67067",
      "IBM423" => "8c5890f6c82ceef0231fd61f4bd661e1fd8cadd88e1944be2b31c967a9f1e02e"
    }
  end

  @impl true
  def decode(input), do: CodecSupport.decode(codec_id(), input)

  @impl true
  def decode_discard(input), do: CodecSupport.decode_discard(codec_id(), input)

  @impl true
  def encode(codepoints), do: CodecSupport.encode(codec_id(), codepoints)

  @impl true
  def encode_discard(codepoints), do: CodecSupport.encode_discard(codec_id(), codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

  @impl true
  def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(codec_id(), input)

  @impl true
  def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(codec_id(), input)
end
