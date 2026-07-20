defmodule Iconvex.Specs.USArmyTapCodePairValues.SourceParser do
  @moduledoc false

  @header "row,column,unicode_hex,letter"
  @expected_letters ~c"ABCDEFGHIJLMNOPQRSTUVWXYZ"

  @required_metadata [
    "LGPL-2.1-or-later",
    "Prisoner of War Tap Code",
    "GTA 31-70-001",
    "first, tap down",
    "second, tap across",
    "use `C` in place of `K`",
    "No Unicode space is encoded",
    "separate timing and gesture mode",
    "numeric octet",
    "U.S. Army wire-byte format",
    "scrambled matrices",
    "Approved for public release",
    "65,511",
    "GNU libiconv 1.19 does not expose Tap Code",
    "`TAP-CODE-SCRAMBLED-MATRIX`"
  ]

  def validate!(mapping_bytes, metadata_bytes, options)
      when is_binary(mapping_bytes) and is_binary(metadata_bytes) and is_list(options) do
    verify_sha!(:mapping, mapping_bytes, Keyword.fetch!(options, :mapping_sha256))
    verify_sha!(:metadata, metadata_bytes, Keyword.fetch!(options, :metadata_sha256))
    validate_metadata!(metadata_bytes)

    rows = parse_rows!(mapping_bytes)
    validate_invariants!(rows)
    rows
  end

  defp verify_sha!(label, bytes, expected) do
    actual = :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)

    unless actual == expected do
      raise ArgumentError,
            "Army Tap Code #{label} SHA-256 mismatch: expected #{expected}, got #{actual}"
    end
  end

  defp validate_metadata!(metadata) do
    unless Enum.all?(@required_metadata, &String.contains?(metadata, &1)) do
      raise ArgumentError,
            "Army Tap Code metadata omits a required provenance or policy statement"
    end
  end

  defp parse_rows!(mapping_bytes) do
    if String.contains?(mapping_bytes, "\r") do
      raise ArgumentError, "Army Tap Code mapping must use LF line endings"
    end

    lines = String.split(mapping_bytes, "\n", trim: false)

    unless List.last(lines) == "" and Enum.at(lines, -2) != "" do
      raise ArgumentError, "Army Tap Code mapping must end with exactly one LF"
    end

    case Enum.drop(lines, -1) do
      [@header | source_rows] when length(source_rows) == 25 ->
        source_rows
        |> Enum.with_index()
        |> Enum.map(fn {source_row, index} -> parse_row!(source_row, index) end)

      [@header | source_rows] ->
        raise ArgumentError,
              "Army Tap Code mapping must contain 25 data rows, got #{length(source_rows)}"

      [header | _rows] ->
        raise ArgumentError, "unexpected Army Tap Code mapping header: #{inspect(header)}"

      [] ->
        raise ArgumentError, "unexpected Army Tap Code mapping header: missing"
    end
  end

  defp parse_row!(source_row, index) do
    expected_row = div(index, 5) + 1
    expected_column = rem(index, 5) + 1
    expected_pair = "#{expected_row},#{expected_column}"
    expected_row_text = Integer.to_string(expected_row)
    expected_column_text = Integer.to_string(expected_column)

    case String.split(source_row, ",", parts: 4) do
      [^expected_row_text, ^expected_column_text, unicode_hex, letter] ->
        codepoint = parse_unicode!(unicode_hex, expected_pair)
        validate_letter!(letter, codepoint, expected_pair)

        %{
          row: expected_row,
          column: expected_column,
          unicode: codepoint,
          letter: letter
        }

      [row_text, column_text, _unicode_hex, _letter] ->
        raise ArgumentError,
              "Army Tap Code mapping must contain ordered pair #{expected_pair}; " <>
                "got #{row_text},#{column_text}"

      _ ->
        raise ArgumentError, "Army Tap Code pair #{expected_pair} has an invalid row schema"
    end
  end

  defp parse_unicode!(unicode_hex, pair) do
    unless Regex.match?(~r/\A[0-9A-F]{4,6}\z/, unicode_hex) do
      raise ArgumentError,
            "Army Tap Code pair #{pair} has invalid Unicode scalar #{inspect(unicode_hex)}"
    end

    codepoint = String.to_integer(unicode_hex, 16)

    unless codepoint in 0x0000..0x10FFFF and codepoint not in 0xD800..0xDFFF do
      raise ArgumentError, "Army Tap Code pair #{pair} contains a non-scalar Unicode value"
    end

    codepoint
  end

  defp validate_letter!(<<letter>>, letter, _pair) when letter in ?A..?Z, do: :ok

  defp validate_letter!(letter, codepoint, pair) do
    raise ArgumentError,
          "Army Tap Code pair #{pair} letter #{inspect(letter)} does not match U+" <>
            Integer.to_string(codepoint, 16)
  end

  defp validate_invariants!(rows) do
    decoded = Enum.map(rows, & &1.unicode)
    c_row = Enum.at(rows, 2)

    unless c_row.row == 1 and c_row.column == 3 and c_row.unicode == ?C and
             ?K not in decoded do
      raise ArgumentError, "Army Tap Code must decode C at pair 1,3 and omit K"
    end

    unless decoded == @expected_letters and length(Enum.uniq(decoded)) == 25 do
      raise ArgumentError, "Army Tap Code must contain 25 unique decoded letters"
    end
  end
end

defmodule Iconvex.Specs.USArmyTapCodePairValues.SourceAsset do
  @moduledoc false

  alias Iconvex.Specs.USArmyTapCodePairValues.SourceParser

  @source_dir Path.expand("../../../priv/sources/us-army-tap-code", __DIR__)
  @mapping_path Path.join(@source_dir, "pairs.csv")
  @metadata_path Path.join(@source_dir, "SOURCE_METADATA.md")
  @external_resource @mapping_path
  @external_resource @metadata_path

  @mapping_sha256 "b9289530db75d795b65768b8be1add61a9d6ee20e6fb780a7b5bda853637e4cb"
  @metadata_sha256 "27885c0d5edf80e27e06a732aab183369eed8c45d82380efbd680b9f06a1237e"

  @rows SourceParser.validate!(File.read!(@mapping_path), File.read!(@metadata_path),
          mapping_sha256: @mapping_sha256,
          metadata_sha256: @metadata_sha256
        )

  @source_urls %{
    army_official:
      "https://rdl.train.army.mil/catalog-ws/view/100.ATSC/" <>
        "B18B36F6-2596-43BA-B50A-EFC562032BA9-1300757028781/" <>
        "gta31_70_001.pdf",
    army_2015_artifact: "https://asktop.net/wp/download/GTA/GTAx31-70-001xv2015x.pdf",
    naval_history_official:
      "https://www.history.navy.mil/content/dam/nhhc/research/publications/" <>
        "Publication-PDF/BattleBehindBars.pdf",
    naval_history_artifact: "https://md.teyit.org/file/battlebehindbars2.pdf"
  }

  @source_sha256 %{
    army_2015_artifact: "b1ba006ff9150582a6a40dc759ce3d4b21a8aa72f71b678ca80baff13bd75e3d",
    naval_history_artifact: "bfae22e1f86c310ce67eb12006b70eafea0fa89514c0c88f1212c739e5572735"
  }

  @source_sizes %{
    army_2015_artifact: 5_069_379,
    naval_history_artifact: 1_986_013
  }

  @gnu_fixture_sha256 %{
    encodings_def: "156cc484a53109241e3c4d23e0ac1d75c0e199eac48f3de8e9d9e87ecc1ce5f1",
    encodings_extra_def: "0747ecd7a6311ea3fab734d666e49b17e39750a4ba5d498fee267132461e3303",
    iconv_l_default: "f747cadfad9e17ecfa455937b2f95e8bef5c747dcd989d66e52e4681e49b3da1"
  }

  def validate!(mapping_bytes, metadata_bytes, options),
    do: SourceParser.validate!(mapping_bytes, metadata_bytes, options)

  def rows, do: @rows
  def mapping_sha256, do: @mapping_sha256
  def metadata_sha256, do: @metadata_sha256
  def source_url(source), do: Map.fetch!(@source_urls, source)
  def source_sha256(source), do: Map.fetch!(@source_sha256, source)
  def source_size(source), do: Map.fetch!(@source_sizes, source)
  def gnu_fixture_sha256(fixture), do: Map.fetch!(@gnu_fixture_sha256, fixture)

  def source_page(:army_2015_artifact), do: %{physical_pdf: 1, panel: :interior}
  def source_page(:naval_history_artifact), do: %{physical_pdf: 33, printed: 27}

  def source_license(:army_2015_artifact), do: :us_government_public_release

  def source_license(:naval_history_artifact),
    do: :us_government_publication_reference_only

  def profile_counts do
    %{
      decoded_letters: 25,
      encode_inputs: 26,
      valid_pairs: 25,
      invalid_octet_pairs: 65_511
    }
  end

  def logical_unit, do: {:ordered_pair, :tap_counts, 1..5}
  def storage_unit_bits, do: 8
  def transport_policy, do: :project_defined_numeric_count_octets
  def k_policy, do: :encode_k_as_c_decode_c
  def case_policy, do: :uppercase_basic_latin_only
  def word_boundary_policy, do: :not_defined_not_encoded
  def number_policy, do: :excluded_separate_timing_mode
  def matrix_policy, do: :fixed_gta_31_70_001_january_2015
  def packed_applicability, do: :not_a_fixed_width_bit_code
  def gnu_libiconv_support, do: :unsupported

  def excluded_names do
    [
      "TAP-CODE",
      "KNOCK-CODE",
      "POLYBIUS-SQUARE",
      "TAP-CODE-NUMBERS",
      "TAP-CODE-HAND-LANGUAGE",
      "TAP-CODE-SCRAMBLED-MATRIX"
    ]
  end
end
