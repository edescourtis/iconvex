defmodule Iconvex.Specs.Lietuvybe.Codecs do
  @moduledoc "Exact commit-qualified codecs from the pinned lietuvybė.lt tables."

  require Iconvex.Specs.SourceQualifiedSequenceSingleByte

  alias Iconvex.Specs.SourceQualifiedSequenceSingleByte, as: SequenceSingleByte

  def modules do
    [
      Iconvex.Specs.Lietuvybe.LST1564Commit52A97895,
      Iconvex.Specs.Lietuvybe.LST1590Part2Commit52A97895,
      Iconvex.Specs.Lietuvybe.LST1590Part4Commit52A97895
    ]
  end

  SequenceSingleByte.defcodec(
    Iconvex.Specs.Lietuvybe.LST1564Commit52A97895,
    canonical: "LIETUVYBE-52A97895-LST-1564-2000-STRICT-BLANKS",
    codec_id: :lietuvybe_52a97895_lst1564_strict_blanks,
    mapping_path:
      Path.expand(
        "../../../priv/sources/lietuvybe-lst-source-qualified/lst1564.csv",
        __DIR__
      ),
    mapping_sha256: "fdc7ccd7e311b4530d58606ea47deb30186c143f84fbecb01062d45bd5326d04",
    metadata_path:
      Path.expand(
        "../../../priv/sources/lietuvybe-lst-source-qualified/SOURCE_METADATA.md",
        __DIR__
      ),
    mapped_byte_count: 224,
    invalid_byte_count: 32,
    reserved_control_count: 32,
    source_url:
      "https://raw.githubusercontent.com/lietuvybe-lt/lietuvybe.lt/52a97895aad2ba40e93a1da28a63c964ad63b9eb/content/standartai/ra%C5%A1men%C5%B3-koduot%C4%97s/index.md",
    source_commit: "52a97895aad2ba40e93a1da28a63c964ad63b9eb",
    source_blob_sha256: "ac4ae79efcf577157ed00972960711966c2375285128c07a6ad2485d983f8077",
    source_blob_size: 42_924
  )

  SequenceSingleByte.defcodec(
    Iconvex.Specs.Lietuvybe.LST1590Part2Commit52A97895,
    canonical: "LIETUVYBE-52A97895-LST-1590-2-2000-STRICT-BLANKS",
    codec_id: :lietuvybe_52a97895_lst1590_2_strict_blanks,
    mapping_path:
      Path.expand(
        "../../../priv/sources/lietuvybe-lst-source-qualified/lst1590_2.csv",
        __DIR__
      ),
    mapping_sha256: "defee7782bcba01ea7b3f6d85a0103813f6e72d2aaab728892b6bfbfa3fd4240",
    metadata_path:
      Path.expand(
        "../../../priv/sources/lietuvybe-lst-source-qualified/SOURCE_METADATA.md",
        __DIR__
      ),
    mapped_byte_count: 256,
    invalid_byte_count: 0,
    reserved_control_count: 0,
    source_url:
      "https://raw.githubusercontent.com/lietuvybe-lt/lietuvybe.lt/52a97895aad2ba40e93a1da28a63c964ad63b9eb/content/standartai/ra%C5%A1men%C5%B3-koduot%C4%97s/index.md",
    source_commit: "52a97895aad2ba40e93a1da28a63c964ad63b9eb",
    source_blob_sha256: "ac4ae79efcf577157ed00972960711966c2375285128c07a6ad2485d983f8077",
    source_blob_size: 42_924
  )

  SequenceSingleByte.defcodec(
    Iconvex.Specs.Lietuvybe.LST1590Part4Commit52A97895,
    canonical: "LIETUVYBE-52A97895-LST-1590-4-2000-STRICT-BLANKS",
    codec_id: :lietuvybe_52a97895_lst1590_4_strict_blanks,
    mapping_path:
      Path.expand(
        "../../../priv/sources/lietuvybe-lst-source-qualified/lst1590_4.csv",
        __DIR__
      ),
    mapping_sha256: "8d7325c6785dd6a18af90e576c827ed8386f1f6b14e1aed97618e650c3214b13",
    metadata_path:
      Path.expand(
        "../../../priv/sources/lietuvybe-lst-source-qualified/SOURCE_METADATA.md",
        __DIR__
      ),
    mapped_byte_count: 249,
    invalid_byte_count: 7,
    reserved_control_count: 0,
    source_url:
      "https://raw.githubusercontent.com/lietuvybe-lt/lietuvybe.lt/52a97895aad2ba40e93a1da28a63c964ad63b9eb/content/standartai/ra%C5%A1men%C5%B3-koduot%C4%97s/index.md",
    source_commit: "52a97895aad2ba40e93a1da28a63c964ad63b9eb",
    source_blob_sha256: "ac4ae79efcf577157ed00972960711966c2375285128c07a6ad2485d983f8077",
    source_blob_size: 42_924
  )
end
