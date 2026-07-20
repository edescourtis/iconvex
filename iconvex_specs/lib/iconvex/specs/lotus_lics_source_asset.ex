defmodule Iconvex.Specs.LotusLICS.SourceAsset do
  @moduledoc false

  @source_dir Path.expand("../../../priv/sources/lotus-lics", __DIR__)
  @mapping_path Path.join(@source_dir, "lotus_lics_hp_1991.csv")
  @metadata_path Path.join(@source_dir, "SOURCE_METADATA.md")
  @external_resource @mapping_path
  @external_resource @metadata_path

  @header "byte_hex,unicode_hex,status,provenance"
  @mapping_sha256 "2eedf12805e1aee25e37044ddf58c8fcdcb9e754f3c3776aeb8a0447674a5239"
  @metadata_sha256 "328bb0a6b703742a8b882adcb079d5413ae9a4d6cb514dcd0ae4b6b83fe6cfe2"

  @source_sha256 %{
    hp_manual: "358d8b5b06cc196034fcb54af77388cc0d75f58513f7ea4dd4cc6488e04ef621",
    xerox_manual: "dd588f6a90c38ce9ae612a25439310f7a374581facbdf2325f2b05dd8863e72c",
    lotus_release_2_files: "3fd743be6e67450d889a1bc4164e12f7edb6dbe106b6915768eabff545e35beb"
  }

  @source_urls %{
    hp_manual:
      "https://www.retroisle.com/others/hp95lx/OriginalDocs/" <>
        "95LX_UsersGuide_F1000-90001_826pages_Jun91.pdf",
    xerox_manual:
      "https://bitsavers.org/pdf/xerox/viewpoint/VP_2.0/" <>
        "610E12320_File_Conversion_Reference_Volume_10_May88.pdf",
    lotus_release_2_files: "https://archive.org/download/Lotus1-2-3Release2/files_extracted.zip"
  }

  @source_sizes %{
    hp_manual: 7_575_631,
    xerox_manual: 11_527_427,
    lotus_release_2_files: 728_366
  }

  @gnu_fixture_sha256 %{
    encodings_def: "156cc484a53109241e3c4d23e0ac1d75c0e199eac48f3de8e9d9e87ecc1ce5f1",
    encodings_extra_def: "0747ecd7a6311ea3fab734d666e49b17e39750a4ba5d498fee267132461e3303",
    iconv_l_default: "f747cadfad9e17ecfa455937b2f95e8bef5c747dcd989d66e52e4681e49b3da1"
  }

  @expected_high_hex """
  0000030000000301000003020000030800000303FFFFFFFFFFFFFFFFFFFFFFFF
  FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
  00000300000003010000030200000308000003030000013100000331000025B2
  000025BCFFFFFFFF000000A000002190FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
  00000192000000A1000000A2000000A30000201C000000A5000020A7000000A7
  000000A4000000A9000000AA000000AB00000394000003C000002265000000F7
  000000B0000000B1000000B2000000B30000201E000000B5000000B6000000B7
  00002122000000B9000000BA000000BB000000BC000000BD00002264000000BF
  000000C0000000C1000000C2000000C3000000C4000000C5000000C6000000C7
  000000C8000000C9000000CA000000CB000000CC000000CD000000CE000000CF
  000000D0000000D1000000D2000000D3000000D4000000D5000000D600000152
  000000D8000000D9000000DA000000DB000000DC00000178000000DE000000DF
  000000E0000000E1000000E2000000E3000000E4000000E5000000E6000000E7
  000000E8000000E9000000EA000000EB000000EC000000ED000000EE000000EF
  000000F0000000F1000000F2000000F3000000F4000000F5000000F600000153
  000000F8000000F9000000FA000000FB000000FC000000FF000000FEFFFFFFFF
  """

  @expected_high @expected_high_hex
                 |> String.replace(~r/\s+/, "")
                 |> Base.decode16!()
                 |> then(fn binary ->
                   for <<codepoint::unsigned-big-32 <- binary>> do
                     if codepoint == 0xFFFFFFFF, do: nil, else: codepoint
                   end
                 end)

  @undefined Enum.to_list(0x85..0x8F) ++
               [0x99] ++ Enum.to_list(0x9C..0x9F) ++ [0xFF]

  @extension [0x97, 0x98, 0x9A, 0x9B]

  @required_metadata [
    "HP 95LX User's Guide",
    "June 1991",
    "Appendix F",
    "Xerox ViewPoint File Conversions Reference",
    "May 1988",
    "Lotus 1-2-3 Release 2",
    "0x97, 0x98, 0x9A, and 0x9B",
    "lowest-byte canonical encoder",
    "LGPL-2.1-or-later",
    "GNU libiconv 1.19 does not expose LICS",
    @mapping_sha256,
    Map.fetch!(@source_sha256, :hp_manual),
    Map.fetch!(@source_sha256, :xerox_manual),
    Map.fetch!(@source_sha256, :lotus_release_2_files)
  ]

  @doc false
  def validate!(mapping_bytes, metadata_bytes, options)
      when is_binary(mapping_bytes) and is_binary(metadata_bytes) and is_list(options) do
    verify_sha!(:mapping, mapping_bytes, Keyword.fetch!(options, :mapping_sha256))
    verify_sha!(:metadata, metadata_bytes, Keyword.fetch!(options, :metadata_sha256))
    validate_metadata!(metadata_bytes)

    rows = parse_rows!(mapping_bytes)
    validate_invariants!(rows)
    rows
  end

  @doc false
  defmacro high_hex do
    @mapping_path
    |> File.read!()
    |> then(
      &validate!(
        &1,
        File.read!(@metadata_path),
        mapping_sha256: @mapping_sha256,
        metadata_sha256: @metadata_sha256
      )
    )
    |> Enum.drop(0x80)
    |> Enum.map(fn
      %{unicode: nil} -> <<0xFFFFFFFF::unsigned-big-32>>
      %{unicode: codepoint} -> <<codepoint::unsigned-big-32>>
    end)
    |> IO.iodata_to_binary()
    |> Base.encode16()
  end

  def mapping_sha256, do: @mapping_sha256
  def metadata_sha256, do: @metadata_sha256
  def source_sha256(source), do: Map.fetch!(@source_sha256, source)
  def source_url(source), do: Map.fetch!(@source_urls, source)
  def source_size(source), do: Map.fetch!(@source_sizes, source)
  def gnu_fixture_sha256(fixture), do: Map.fetch!(@gnu_fixture_sha256, fixture)

  def source_pages(:hp_manual),
    do: %{physical_pdf: 792..798, printed: "F-1..F-7"}

  def source_pages(:xerox_manual),
    do: %{physical_pdf: 166..179, printed: "6-19..6-32"}

  def source_license(source)
      when source in [:hp_manual, :xerox_manual, :lotus_release_2_files],
      do: :copyrighted_reference_only

  def profile_counts,
    do: %{defined: 239, undefined: 17, unique_scalars: 234, unicode_duplicates: 5}

  def unit_bits, do: 8
  def control_policy, do: :unicode_identity_including_ascii_delete
  def reverse_policy, do: :lowest_byte_canonical_for_duplicates
  def packed_applicability, do: :not_applicable_octet_codec
  def gnu_libiconv_support, do: :unsupported

  def earlier_profile_differences,
    do: %{xerox_1988_unlisted_hp_1991_assigned: @extension}

  defp verify_sha!(label, bytes, expected) do
    actual = :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)

    unless actual == expected do
      raise ArgumentError,
            "LICS #{label} SHA-256 mismatch: expected #{expected}, got #{actual}"
    end
  end

  defp validate_metadata!(metadata) do
    unless Enum.all?(@required_metadata, &String.contains?(metadata, &1)) do
      raise ArgumentError, "LICS metadata omits a required provenance or policy statement"
    end
  end

  defp parse_rows!(mapping_bytes) do
    if String.contains?(mapping_bytes, "\r") do
      raise ArgumentError, "LICS mapping must use LF line endings"
    end

    lines = String.split(mapping_bytes, "\n", trim: false)

    unless List.last(lines) == "" and Enum.at(lines, -2) != "" do
      raise ArgumentError, "LICS mapping must end with exactly one LF"
    end

    case Enum.drop(lines, -1) do
      [@header | source_rows] when length(source_rows) == 256 ->
        source_rows
        |> Enum.with_index()
        |> Enum.map(fn {row, byte} -> parse_row!(row, byte) end)

      [@header | source_rows] ->
        raise ArgumentError,
              "LICS mapping must contain 256 data rows, got #{length(source_rows)}"

      [header | _rows] ->
        raise ArgumentError, "unexpected LICS mapping header: #{inspect(header)}"

      [] ->
        raise ArgumentError, "unexpected LICS mapping header: missing"
    end
  end

  defp parse_row!(row, expected_byte) do
    expected_hex = Base.encode16(<<expected_byte>>)

    case String.split(row, ",", parts: 4) do
      [^expected_hex, unicode_hex, "mapped", provenance] ->
        %{
          byte: expected_byte,
          unicode: parse_unicode!(unicode_hex, expected_hex),
          status: "mapped",
          provenance: provenance
        }

      [^expected_hex, "", "undefined", provenance] ->
        %{
          byte: expected_byte,
          unicode: nil,
          status: "undefined",
          provenance: provenance
        }

      [byte_hex, _unicode_hex, _status, _provenance] when byte_hex != expected_hex ->
        raise ArgumentError,
              "LICS mapping must contain ordered row #{expected_hex}; got #{inspect(byte_hex)}"

      _ ->
        raise ArgumentError,
              "LICS row #{expected_hex} must be mapped to one scalar or explicitly undefined"
    end
  end

  defp parse_unicode!(unicode_hex, byte_hex) do
    unless Regex.match?(~r/\A[0-9A-F]{4,6}\z/, unicode_hex) do
      raise ArgumentError,
            "LICS row #{byte_hex} has invalid Unicode scalar #{inspect(unicode_hex)}"
    end

    codepoint = String.to_integer(unicode_hex, 16)

    unless codepoint in 0x0000..0x10FFFF and codepoint not in 0xD800..0xDFFF do
      raise ArgumentError, "LICS row #{byte_hex} contains a non-scalar Unicode value"
    end

    codepoint
  end

  defp validate_invariants!(rows) do
    table = Enum.map(rows, & &1.unicode)
    provenance = Enum.map(rows, & &1.provenance)

    unless Enum.take(table, 0x80) == Enum.to_list(0x00..0x7F) and
             Enum.drop(table, 0x80) == @expected_high do
      raise ArgumentError, "LICS mappings differ from the HP 1991 profile"
    end

    expected_provenance =
      Enum.map(0..255, fn byte ->
        cond do
          byte < 0x20 -> "hp_1991_control"
          byte <= 0x7F -> "hp_1991_ascii"
          byte in @undefined -> "hp_1991_undefined"
          byte in @extension -> "hp_1991_extension"
          true -> "xerox_1988_hp_1991"
        end
      end)

    unless provenance == expected_provenance do
      raise ArgumentError,
            "LICS provenance must distinguish the HP extension and Xerox-shared rows"
    end

    defined = Enum.reject(table, &is_nil/1)

    unless length(defined) == 239 and length(Enum.uniq(defined)) == 234 do
      raise ArgumentError, "LICS profile cardinality or Unicode duplicate count is invalid"
    end

    duplicate_groups =
      table
      |> Enum.with_index()
      |> Enum.reject(fn {codepoint, _byte} -> is_nil(codepoint) end)
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
      |> Enum.filter(fn {_codepoint, bytes} -> length(bytes) > 1 end)
      |> Map.new()

    expected_duplicates = %{
      0x0300 => [0x80, 0x90],
      0x0301 => [0x81, 0x91],
      0x0302 => [0x82, 0x92],
      0x0308 => [0x83, 0x93],
      0x0303 => [0x84, 0x94]
    }

    unless duplicate_groups == expected_duplicates do
      raise ArgumentError, "LICS Unicode duplicate pairs are not the audited five accent pairs"
    end
  end
end
