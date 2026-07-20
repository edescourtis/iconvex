defmodule Iconvex.Specs.ISOIR42 do
  @moduledoc """
  JIS C 6226-1978 as the raw 94-by-94 graphic set registered by ISO-IR 42.

  This is deliberately not an EUC or ISO-2022 transport. Each character is
  represented by two bytes in `0x21..0x7E`, exactly as registered.
  """

  use Iconvex.Codec

  @registration_path Path.expand("../../../priv/sources/iso-ir-42/042.pdf", __DIR__)
  @mapping_path Path.expand(
                  "../../../priv/sources/icu-data-archive/ibm-955_P110-1997.ucm",
                  __DIR__
                )
  @external_resource @registration_path
  @external_resource @mapping_path

  @metadata %{
    mapping_sha256: "06bd629e1967a5fb9bcb75b5cd964efb60036ca5b5d78bb0ce5b1301ffcfc7f7",
    mapping_url:
      "https://github.com/unicode-org/icu-data/blob/main/charset/data/ucm/ibm-955_P110-1997.ucm",
    pike_revision: "4bf9adbd874894d2484de1664969de43e4206492",
    pike_sha256: "28f856d12347859c9cb7f10361c813c4a4f3f7c9d33911544b50c7897748d860",
    registration: 42,
    registration_sha256: "f3ef6fd4f2c126b3477e0763a713dcff14373fc7d3ee121c397b3283380ff2d3",
    registration_url: "https://itscj.ipsj.or.jp/ir/042.pdf",
    roundtrip_mappings: 6_879,
    unicode_fallbacks: 12
  }

  @impl true
  def canonical_name, do: "ISO-IR-42"

  @impl true
  def aliases do
    [
      "ISOIR42",
      "ISO_42",
      "JIS-C6226-1978",
      "JIS_C6226-1978",
      "JISC6226-1978",
      "CSISO42JISC62261978"
    ]
  end

  @impl true
  def codec_id, do: :iso_ir_42

  @impl true
  def decode(input), do: Iconvex.Specs.CodecSupport.decode_provider(:icu_archive_726, input)

  @impl true
  def decode_discard(input),
    do: Iconvex.Specs.CodecSupport.decode_discard_provider(:icu_archive_726, input)

  @impl true
  def decode_to_utf8(input),
    do: Iconvex.Specs.CodecSupport.decode_to_utf8_provider(:icu_archive_726, input)

  @impl true
  def encode(codepoints),
    do: Iconvex.Specs.CodecSupport.encode_provider(:icu_archive_726, codepoints)

  @impl true
  def encode_discard(codepoints),
    do: Iconvex.Specs.CodecSupport.encode_discard_provider(:icu_archive_726, codepoints)

  @impl true
  def encode_substitute(codepoints, replacer),
    do:
      Iconvex.Specs.CodecSupport.encode_substitute_provider(
        :icu_archive_726,
        codepoints,
        replacer
      )

  @impl true
  def encode_from_utf8(input),
    do: Iconvex.Specs.CodecSupport.encode_from_utf8_provider(:icu_archive_726, input)

  def metadata, do: @metadata
end
