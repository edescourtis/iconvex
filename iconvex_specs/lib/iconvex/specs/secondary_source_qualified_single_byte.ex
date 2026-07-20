defmodule Iconvex.Specs.SecondarySourceQualifiedSingleByte do
  @moduledoc false

  @header "byte_hex,unicode_sequence,status"
  @mapping_pattern ~r/\A[0-9A-F]{4,6}(?:\+[0-9A-F]{4,6}){0,2}\z/

  defmacro defcodec(module_ast, options_ast) do
    module = Macro.expand(module_ast, __CALLER__)
    {options, []} = Code.eval_quoted(options_ast, [], __CALLER__)
    definition = build_definition!(module, options)

    quote bind_quoted: [module: module, definition: Macro.escape(definition)] do
      defmodule module do
        use Iconvex.Codec

        alias Iconvex.Specs.SourceQualifiedSequenceSingleByte.Engine

        @external_resource definition.mapping_path
        @external_resource definition.metadata_path
        @decode definition.decode
        @decode_utf8 definition.decode_utf8
        @encoder definition.encoder
        @canonical definition.canonical
        @codec_id definition.codec_id
        @mapping_sha256 definition.mapping_sha256
        @mapped_byte_count definition.mapped_byte_count
        @invalid_byte_count definition.invalid_byte_count
        @source_url definition.source_url
        @source_identity definition.source_identity
        @source_sha256 definition.source_sha256
        @source_size definition.source_size
        @source_license definition.source_license
        @provenance definition.provenance

        @impl true
        def canonical_name, do: @canonical

        @impl true
        def codec_id, do: @codec_id

        @impl true
        def decode(input) when is_binary(input), do: Engine.decode(input, @decode)

        @impl true
        def decode_discard(input) when is_binary(input),
          do: Engine.decode_discard(input, @decode)

        @impl true
        def decode_to_utf8(input) when is_binary(input),
          do: Engine.decode_to_utf8(input, @decode_utf8)

        @impl true
        def decode_chunk(input, _final?) when is_binary(input),
          do: Engine.decode_chunk(input, @decode)

        @impl true
        def encode(codepoints) when is_list(codepoints), do: Engine.encode(codepoints, @encoder)

        @impl true
        def encode_discard(codepoints) when is_list(codepoints),
          do: Engine.encode_discard(codepoints, @encoder)

        @impl true
        def encode_substitute(codepoints, replacer)
            when is_list(codepoints) and is_function(replacer, 1),
            do: Engine.encode_substitute(codepoints, @encoder, replacer)

        @impl true
        def encode_from_utf8(input) when is_binary(input),
          do: Engine.encode_from_utf8(input, @encoder)

        @impl true
        def encode_chunk(codepoints, final?, policy)
            when is_list(codepoints) and is_boolean(final?),
            do: Engine.encode_chunk(codepoints, @encoder, final?, policy)

        def __secondary_source_qualified_single_byte__, do: true
        def unit_bits, do: 8
        def inverse_policy, do: :lowest_byte_longest_sequence
        def blank_slot_policy, do: :strict_undefined
        def provenance_qualification, do: :content_qualified_no_endorsement
        def mapping_sha256, do: @mapping_sha256
        def mapped_byte_count, do: @mapped_byte_count
        def invalid_byte_count, do: @invalid_byte_count
        def source_url, do: @source_url
        def source_identity, do: @source_identity
        def source_sha256, do: @source_sha256
        def source_size, do: @source_size
        def source_license, do: @source_license
        def provenance, do: @provenance
      end
    end
  end

  defp build_definition!(module, options) do
    required = [
      :canonical,
      :codec_id,
      :mapping_path,
      :mapping_sha256,
      :metadata_path,
      :mapped_byte_count,
      :invalid_byte_count,
      :source_url,
      :source_identity,
      :source_sha256,
      :source_size,
      :source_license
    ]

    for key <- required do
      Keyword.has_key?(options, key) ||
        raise ArgumentError, "#{inspect(module)} is missing required #{inspect(key)}"
    end

    canonical = Keyword.fetch!(options, :canonical)
    codec_id = Keyword.fetch!(options, :codec_id)
    mapping_path = Keyword.fetch!(options, :mapping_path)
    expected_mapping_sha256 = Keyword.fetch!(options, :mapping_sha256)
    metadata_path = Keyword.fetch!(options, :metadata_path)
    expected_mapped = Keyword.fetch!(options, :mapped_byte_count)
    expected_invalid = Keyword.fetch!(options, :invalid_byte_count)
    source_url = Keyword.fetch!(options, :source_url)
    source_identity = Keyword.fetch!(options, :source_identity)
    source_sha256 = Keyword.fetch!(options, :source_sha256)
    source_size = Keyword.fetch!(options, :source_size)
    source_license = Keyword.fetch!(options, :source_license)

    provenance =
      Keyword.get_lazy(options, :provenance, fn ->
        %{
          normalized_mapping: %{
            license: "LGPL-2.1-or-later",
            sha256: expected_mapping_sha256
          },
          source: %{
            identity: source_identity,
            license: source_license,
            sha256: source_sha256,
            size: source_size,
            url: source_url
          }
        }
      end)

    unless is_binary(canonical) and
             Regex.match?(
               ~r/\A(?:WANG-1983-[A-Z0-9-]*WIKIPEDIA-REV\d+|WIKIPEDIA-REV\d+-[A-Z0-9-]+)\z/,
               canonical
             ) do
      raise ArgumentError, "canonical name must contain an exact source/content qualifier"
    end

    unless is_atom(codec_id), do: raise(ArgumentError, "codec_id must be an atom")

    for {label, digest} <- [mapping: expected_mapping_sha256, source: source_sha256] do
      unless is_binary(digest) and Regex.match?(~r/\A[0-9a-f]{64}\z/, digest),
        do: raise(ArgumentError, "invalid #{label} SHA-256 for #{canonical}")
    end

    unless is_binary(source_url) and String.starts_with?(source_url, "https://"),
      do: raise(ArgumentError, "source URL must use HTTPS for #{canonical}")

    unless is_binary(source_identity) and source_identity != "" and is_integer(source_size) and
             source_size > 0 and is_binary(source_license) and source_license != "",
           do: raise(ArgumentError, "invalid source metadata for #{canonical}")

    unless is_map(provenance) and
             get_in(provenance, [:normalized_mapping, :license]) == "LGPL-2.1-or-later" and
             get_in(provenance, [:normalized_mapping, :sha256]) == expected_mapping_sha256,
           do: raise(ArgumentError, "invalid structured provenance for #{canonical}")

    unless is_integer(expected_mapped) and is_integer(expected_invalid) and
             expected_mapped + expected_invalid == 256,
           do:
             raise(ArgumentError, "mapping cardinality must cover all 256 bytes for #{canonical}")

    csv = File.read!(mapping_path)
    actual_mapping_sha256 = sha256(csv)

    unless actual_mapping_sha256 == expected_mapping_sha256 do
      raise ArgumentError,
            "mapping SHA-256 mismatch for #{canonical}: expected #{expected_mapping_sha256}, got #{actual_mapping_sha256}"
    end

    rows = parse_rows!(csv, canonical)
    mapped = Enum.count(rows, &(&1.mapping != nil))
    invalid = 256 - mapped

    unless {mapped, invalid} == {expected_mapped, expected_invalid},
      do: raise(ArgumentError, "mapping cardinality mismatch for #{canonical}")

    metadata = File.read!(metadata_path)

    for pin <- [
          canonical,
          source_identity,
          source_sha256,
          Integer.to_string(source_size),
          source_license,
          expected_mapping_sha256,
          "LGPL-2.1-or-later",
          "CC BY-SA 4.0",
          "does not imply vendor authorship, affiliation, approval, or endorsement",
          "strictly undefined"
        ] do
      unless String.contains?(metadata, pin),
        do: raise(ArgumentError, "metadata is missing #{inspect(pin)} for #{canonical}")
    end

    decode = rows |> Enum.map(& &1.mapping) |> List.to_tuple()

    decode_utf8 =
      rows
      |> Enum.map(fn
        %{mapping: nil} -> nil
        %{mapping: codepoint} when is_integer(codepoint) -> <<codepoint::utf8>>
        %{mapping: sequence} -> sequence |> Tuple.to_list() |> List.to_string()
      end)
      |> List.to_tuple()

    %{
      canonical: canonical,
      codec_id: codec_id,
      mapping_path: mapping_path,
      metadata_path: metadata_path,
      mapping_sha256: expected_mapping_sha256,
      mapped_byte_count: expected_mapped,
      invalid_byte_count: expected_invalid,
      source_url: source_url,
      source_identity: source_identity,
      source_sha256: source_sha256,
      source_size: source_size,
      source_license: source_license,
      provenance: provenance,
      decode: decode,
      decode_utf8: decode_utf8,
      encoder: build_encoder(rows)
    }
  end

  defp parse_rows!(csv, canonical) do
    lines = String.split(csv, "\n", trim: false)

    unless List.last(lines) == "" and Enum.at(lines, -2) != "",
      do: raise(ArgumentError, "mapping must end in exactly one LF for #{canonical}")

    case Enum.drop(lines, -1) do
      [@header | source_rows] when length(source_rows) == 256 ->
        source_rows
        |> Enum.with_index()
        |> Enum.map(fn {row, byte} -> parse_row!(row, byte, canonical) end)

      [@header | source_rows] ->
        raise ArgumentError,
              "mapping must contain 256 data rows for #{canonical}, got #{length(source_rows)}"

      [header | _rows] ->
        raise ArgumentError, "unexpected mapping header #{inspect(header)} for #{canonical}"

      [] ->
        raise ArgumentError, "missing mapping header for #{canonical}"
    end
  end

  defp parse_row!(row, expected_byte, canonical) do
    expected_hex =
      expected_byte |> Integer.to_string(16) |> String.upcase() |> String.pad_leading(2, "0")

    case String.split(row, ",", parts: 3) do
      [^expected_hex, "", "undefined"] ->
        %{byte: expected_byte, mapping: nil}

      [^expected_hex, sequence, "assigned"] ->
        unless Regex.match?(@mapping_pattern, sequence),
          do: raise(ArgumentError, "invalid Unicode sequence at #{expected_hex} for #{canonical}")

        codepoints = sequence |> String.split("+") |> Enum.map(&String.to_integer(&1, 16))

        unless Enum.all?(codepoints, &unicode_scalar?/1),
          do: raise(ArgumentError, "non-scalar Unicode value at #{expected_hex} for #{canonical}")

        mapping =
          case codepoints do
            [codepoint] -> codepoint
            [first, second] -> {first, second}
            [first, second, third] -> {first, second, third}
          end

        %{byte: expected_byte, mapping: mapping}

      [actual_hex, _sequence, _status] when actual_hex != expected_hex ->
        raise ArgumentError,
              "mapping row order mismatch for #{canonical}: expected #{expected_hex}, got #{actual_hex}"

      _ ->
        raise ArgumentError, "invalid mapping row #{expected_hex} for #{canonical}"
    end
  end

  defp build_encoder(rows) do
    Enum.reduce(
      rows,
      %{singles: %{}, sequence2: %{}, sequence3: %{}, prefix1: %{}, prefix2: %{}},
      fn
        %{mapping: nil}, encoder ->
          encoder

        %{byte: byte, mapping: codepoint}, encoder when is_integer(codepoint) ->
          %{encoder | singles: Map.put_new(encoder.singles, codepoint, byte)}

        %{byte: byte, mapping: {first, _second} = sequence}, encoder ->
          %{
            encoder
            | sequence2: Map.put_new(encoder.sequence2, sequence, byte),
              prefix1: Map.put(encoder.prefix1, first, true)
          }

        %{byte: byte, mapping: {first, second, _third} = sequence}, encoder ->
          %{
            encoder
            | sequence3: Map.put_new(encoder.sequence3, sequence, byte),
              prefix1: Map.put(encoder.prefix1, first, true),
              prefix2: Map.put(encoder.prefix2, {first, second}, true)
          }
      end
    )
  end

  defp sha256(bytes), do: :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)

  defp unicode_scalar?(codepoint),
    do: codepoint in 0..0x10FFFF and codepoint not in 0xD800..0xDFFF
end

defmodule Iconvex.Specs.SecondarySourceQualifiedSingleByte.Codecs do
  @moduledoc "Content-qualified codecs for exact secondary single-byte mapping evidence."

  require Iconvex.Specs.SecondarySourceQualifiedSingleByte

  alias Iconvex.Specs.SecondarySourceQualifiedSingleByte, as: SecondarySingleByte

  def modules do
    [
      Iconvex.Specs.Secondary.WangWiscii1983WikipediaRev1352856854,
      Iconvex.Specs.Secondary.WikipediaWindowsPolytonicGreekRev1354794598,
      Iconvex.Specs.Secondary.WikipediaEkiSamiWinCp1270Rev1340817319
    ]
  end

  def blocked_rows do
    [
      %{id: "ENC-0067", disposition: :blocked_exact_evidence},
      %{id: "ENC-0985", disposition: :blocked_license_and_semantics},
      %{id: "ENC-1265", disposition: :blocked_ambiguous_profiles}
    ]
  end

  SecondarySingleByte.defcodec(
    Iconvex.Specs.Secondary.WangWiscii1983WikipediaRev1352856854,
    canonical: "WANG-1983-WISCII-PDF-F4043449-WIKIPEDIA-REV1352856854",
    codec_id: :wang_1983_wiscii_pdf_f4043449_wikipedia_rev1352856854,
    mapping_path:
      Path.expand(
        "../../../priv/sources/secondary-source-qualified-single-byte/wang_wiscii.csv",
        __DIR__
      ),
    mapping_sha256: "f40f80a592676f36f782481d9826996528471589795f969fe817fc3ac2c50bb7",
    metadata_path:
      Path.expand(
        "../../../priv/sources/secondary-source-qualified-single-byte/SOURCE_METADATA.md",
        __DIR__
      ),
    mapped_byte_count: 221,
    invalid_byte_count: 35,
    source_url:
      "https://bitsavers.org/pdf/wang/vs/800-1149-01_VS_Multi-Station_Users_Ref_198312.pdf",
    source_identity:
      "Wang Laboratories, VS Multi-Station User's Reference, document 800-1149-01, " <>
        "December 1983, Appendix D page D-1",
    source_sha256: "f4043449df7ca900a8d2aef137b82ade74f6dcff46aed8b7d49f57af927b7dfe",
    source_size: 7_151_974,
    source_license: "NOASSERTION",
    provenance: %{
      normalized_mapping: %{
        license: "LGPL-2.1-or-later",
        sha256: "f40f80a592676f36f782481d9826996528471589795f969fe817fc3ac2c50bb7"
      },
      primary_chart: %{
        bundled: false,
        identity:
          "Wang Laboratories, VS Multi-Station User's Reference, document 800-1149-01, " <>
            "December 1983, Appendix D page D-1",
        rights: :copyrighted_documentation_no_redistribution_license_identified,
        sha256: "f4043449df7ca900a8d2aef137b82ade74f6dcff46aed8b7d49f57af927b7dfe",
        size: 7_151_974,
        url: "https://bitsavers.org/pdf/wang/vs/800-1149-01_VS_Multi-Station_Users_Ref_198312.pdf"
      },
      unicode_binding: %{
        bundled: false,
        identity: "Wikipedia revision 1352856854",
        license: "CC-BY-SA-4.0",
        mediawiki_sha1: "8a2bed93cde9e5a4ac2983bbb0ce52369c5dcfc0",
        sha256: "1a9fceddcf9c4c647c88d750cdd60d9d14aecb339d727d3f7d781a826d85367f",
        size: 16_842,
        url: "https://en.wikipedia.org/w/index.php?oldid=1352856854"
      }
    }
  )

  SecondarySingleByte.defcodec(
    Iconvex.Specs.Secondary.WikipediaWindowsPolytonicGreekRev1354794598,
    canonical: "WIKIPEDIA-REV1354794598-PARATYPE-WINDOWS-POLYTONIC-GREEK",
    codec_id: :wikipedia_rev1354794598_paratype_windows_polytonic_greek,
    mapping_path:
      Path.expand(
        "../../../priv/sources/secondary-source-qualified-single-byte/windows_polytonic_greek.csv",
        __DIR__
      ),
    mapping_sha256: "12774c7a072e9976b6903f8388130891833a24d10086e59d6878ebf45d99d324",
    metadata_path:
      Path.expand(
        "../../../priv/sources/secondary-source-qualified-single-byte/SOURCE_METADATA.md",
        __DIR__
      ),
    mapped_byte_count: 256,
    invalid_byte_count: 0,
    source_url: "https://en.wikipedia.org/w/index.php?oldid=1354794598",
    source_identity: "Wikipedia revision 1354794598 (current B5/FF ordering)",
    source_sha256: "5e7b59478b825549f63553c06e0e19a3cc2e6de1c334507a9797f605eec10a0f",
    source_size: 22_122,
    source_license: "CC-BY-SA-4.0"
  )

  SecondarySingleByte.defcodec(
    Iconvex.Specs.Secondary.WikipediaEkiSamiWinCp1270Rev1340817319,
    canonical: "WIKIPEDIA-REV1340817319-EKI-SAMI-WIN-CP1270",
    codec_id: :wikipedia_rev1340817319_eki_sami_win_cp1270,
    mapping_path:
      Path.expand(
        "../../../priv/sources/secondary-source-qualified-single-byte/eki_sami_win_cp1270.csv",
        __DIR__
      ),
    mapping_sha256: "9fdf47f7766938ab266cd5b9776d00329cf4083c1ce68af4fc4ce0a439ea32e4",
    metadata_path:
      Path.expand(
        "../../../priv/sources/secondary-source-qualified-single-byte/SOURCE_METADATA.md",
        __DIR__
      ),
    mapped_byte_count: 249,
    invalid_byte_count: 7,
    source_url: "https://en.wikipedia.org/w/index.php?oldid=1340817319",
    source_identity: "Wikipedia revision 1340817319 corroborated by EKI HTML SHA-256 f25f60fa",
    source_sha256: "2dc0a6b1da5d1d279f4334cd1f8d95a9c878d022c02f6a27bd25eaf80d84ec57",
    source_size: 16_887,
    source_license: "CC-BY-SA-4.0"
  )
end
