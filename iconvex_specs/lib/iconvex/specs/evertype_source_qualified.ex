defmodule Iconvex.Specs.Evertype.Codecs do
  @moduledoc "Exact source-qualified codecs built from pinned Evertype mapping tables."

  require Iconvex.Specs.SourceQualifiedSingleByte

  alias Iconvex.Specs.SourceQualifiedSingleByte, as: SourceQualifiedSingleByte

  def modules do
    [
      Iconvex.Specs.Evertype.Latin8Extended2001,
      Iconvex.Specs.Evertype.MacArmenian2001,
      Iconvex.Specs.Evertype.MacBarentsCyrillic2001,
      Iconvex.Specs.Evertype.MacGeorgian2002,
      Iconvex.Specs.Evertype.MacMalteseEsperanto2001,
      Iconvex.Specs.Evertype.MacOgham2001,
      Iconvex.Specs.Evertype.MacTurkicCyrillic2002
    ]
  end

  SourceQualifiedSingleByte.defcodec(
    Iconvex.Specs.Evertype.Latin8Extended2001,
    canonical: "EVERTYPE-2001-LATIN-8-EXTENDED",
    codec_id: :evertype_2001_latin8_extended,
    mapping_path:
      Path.expand("../../../priv/sources/evertype-source-qualified/latin8_extended.csv", __DIR__),
    mapping_sha256: "53750c83e4958e7f530f7eaa59163689caa12c3916cb4103ff066952ab61a13b",
    metadata_path:
      Path.expand("../../../priv/sources/evertype-source-qualified/SOURCE_METADATA.md", __DIR__),
    mapped_byte_count: 249,
    source_url: "https://www.evertype.com/standards/mappings/pc/LATIN8EX.TXT",
    source_version: "1.00",
    source_date: "2001-11-10",
    source_size: 10_813,
    source_sha256: "bf737b4ade62c97acd5969f75916142748fcde041e8c97fd6663863ccc96a975"
  )

  SourceQualifiedSingleByte.defcodec(
    Iconvex.Specs.Evertype.MacArmenian2001,
    canonical: "EVERTYPE-2001-MAC-ARMENIAN",
    codec_id: :evertype_2001_mac_armenian,
    mapping_path:
      Path.expand("../../../priv/sources/evertype-source-qualified/mac_armenian.csv", __DIR__),
    mapping_sha256: "696a5f6cd8145857990cf5e0c762c4f91ebb48f07f1744eff84ef0a56f7faba5",
    metadata_path:
      Path.expand("../../../priv/sources/evertype-source-qualified/SOURCE_METADATA.md", __DIR__),
    mapped_byte_count: 256,
    source_url: "https://www.evertype.com/standards/mappings/mac/ARMENIAN.TXT",
    source_version: "1.00",
    source_date: "2001-11-10",
    source_size: 10_137,
    source_sha256: "c194770439215b4fb2c9b3a5f232a9ae35371ccf8fbf26f9c13e03afe61a8536"
  )

  SourceQualifiedSingleByte.defcodec(
    Iconvex.Specs.Evertype.MacBarentsCyrillic2001,
    canonical: "EVERTYPE-2001-MAC-BARENTS-CYRILLIC",
    codec_id: :evertype_2001_mac_barents_cyrillic,
    mapping_path:
      Path.expand(
        "../../../priv/sources/evertype-source-qualified/mac_barents_cyrillic.csv",
        __DIR__
      ),
    mapping_sha256: "f95ab935a572d1ee82b44228b610156bc2a75d07a3a85cd1d5988a587a751cfd",
    metadata_path:
      Path.expand("../../../priv/sources/evertype-source-qualified/SOURCE_METADATA.md", __DIR__),
    mapped_byte_count: 254,
    source_url: "https://www.evertype.com/standards/mappings/mac/BARENCYR.TXT",
    source_version: "1.00",
    source_date: "2001-11-10",
    source_size: 11_171,
    source_sha256: "c8b84a870ff5344965a1874ca0001735e3e403c22a4f50c71979d90bd6a1fe31"
  )

  SourceQualifiedSingleByte.defcodec(
    Iconvex.Specs.Evertype.MacGeorgian2002,
    canonical: "EVERTYPE-2002-MAC-GEORGIAN",
    codec_id: :evertype_2002_mac_georgian,
    mapping_path:
      Path.expand("../../../priv/sources/evertype-source-qualified/mac_georgian.csv", __DIR__),
    mapping_sha256: "2d668f14a934f457495dc86a698f03845525cc9ff43f837fb0f3f98f41819897",
    metadata_path:
      Path.expand("../../../priv/sources/evertype-source-qualified/SOURCE_METADATA.md", __DIR__),
    mapped_byte_count: 256,
    source_url: "https://www.evertype.com/standards/mappings/mac/GEORGIAN.TXT",
    source_version: "1.01",
    source_date: "2002-02-20",
    source_size: 9_763,
    source_sha256: "fcd491dbb7916fe477a2bab79872cef498d3a418594eba307ccbd14d095ce8cf"
  )

  SourceQualifiedSingleByte.defcodec(
    Iconvex.Specs.Evertype.MacMalteseEsperanto2001,
    canonical: "EVERTYPE-2001-MAC-MALTESE-ESPERANTO",
    codec_id: :evertype_2001_mac_maltese_esperanto,
    mapping_path:
      Path.expand(
        "../../../priv/sources/evertype-source-qualified/mac_maltese_esperanto.csv",
        __DIR__
      ),
    mapping_sha256: "ed4516ebd16e1d715c2c271becf11cfcca8a57c0cf4e4f173d142393c8a88ffe",
    metadata_path:
      Path.expand("../../../priv/sources/evertype-source-qualified/SOURCE_METADATA.md", __DIR__),
    mapped_byte_count: 256,
    source_url: "https://www.evertype.com/standards/mappings/mac/MALTESE.TXT",
    source_version: "1.00",
    source_date: "2001-11-10",
    source_size: 11_671,
    source_sha256: "a902a920790704905a9aa7d5ea03d19996c4bfe6e46501f53878f9b27107ef41"
  )

  SourceQualifiedSingleByte.defcodec(
    Iconvex.Specs.Evertype.MacOgham2001,
    canonical: "EVERTYPE-2001-MAC-OGHAM",
    codec_id: :evertype_2001_mac_ogham,
    mapping_path:
      Path.expand("../../../priv/sources/evertype-source-qualified/mac_ogham.csv", __DIR__),
    mapping_sha256: "77a027e95f55949aa22756f45f14b7fb03253ff87d67311252d21910fccee3bf",
    metadata_path:
      Path.expand("../../../priv/sources/evertype-source-qualified/SOURCE_METADATA.md", __DIR__),
    mapped_byte_count: 167,
    source_url: "https://www.evertype.com/standards/mappings/mac/OGHAM.TXT",
    source_version: "1.00",
    source_date: "2001-11-10",
    source_size: 6_422,
    source_sha256: "d95239fc60b38ef80488cbc55b342a9d695953802ecce869077212256e50a13a"
  )

  SourceQualifiedSingleByte.defcodec(
    Iconvex.Specs.Evertype.MacTurkicCyrillic2002,
    canonical: "EVERTYPE-2002-MAC-TURKIC-CYRILLIC",
    codec_id: :evertype_2002_mac_turkic_cyrillic,
    mapping_path:
      Path.expand(
        "../../../priv/sources/evertype-source-qualified/mac_turkic_cyrillic.csv",
        __DIR__
      ),
    mapping_sha256: "228b19300e6baefda3e6aa9d4e89343f42a660bd3d5989cbd52f9dae585a6277",
    metadata_path:
      Path.expand("../../../priv/sources/evertype-source-qualified/SOURCE_METADATA.md", __DIR__),
    mapped_byte_count: 256,
    source_url: "https://www.evertype.com/standards/mappings/mac/TURKCYR.TXT",
    source_version: "1.01",
    source_date: "2002-02-20",
    source_size: 11_974,
    source_sha256: "26175fa84c20db0cab9c11ec532c622490796c6de1561b58313ed090a644e968"
  )
end
