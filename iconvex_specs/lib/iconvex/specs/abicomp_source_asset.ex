defmodule Iconvex.Specs.ABICOMP.SourceAsset do
  @moduledoc false

  @source_dir Path.expand("../../../priv/sources/abicomp", __DIR__)
  @mapping_path Path.join(@source_dir, "abicomp.csv")
  @metadata_path Path.join(@source_dir, "SOURCE_METADATA.md")
  @external_resource @mapping_path
  @external_resource @metadata_path

  @header "byte_hex,unicode_hex,status"
  @mapping_sha256 "2edd0ed4875ee8f62ad82c2cfde796842a05bbef82b9a3f1cd123ed3c9c03bfb"
  @metadata_sha256 "31ea0634ca8ad35b5c872419e53b7890da020b8d8ba9725471d454176b0ed9de"

  @source_sha256 %{
    star_manual: "c723b37df1b936606d960754713c23ed9ac11be1f0cb3365300fad1c9521724b",
    epson_manual: "9c957a73217d9e39cfa9ba5c3f4b40cdcfe205e8b988ee2bf69268d12d8c697d",
    freedos_archive: "5af7b1064c946810453034aa689870ecf6b2d8640f5daec9c45496808afd50bc",
    freedos_ega18_cpx: "11944b119a838656de3fc795521e90bbc610b000fe603f95f8c685ee21216b1f"
  }

  @source_urls %{
    star_manual: "https://archive.org/download/manuallib-id-2525457/2525457.pdf",
    epson_manual: "https://archive.org/download/manualzz-id-749516/749516.pdf",
    freedos_archive:
      "https://www.ibiblio.org/pub/micro/pc-stuff/freedos/files/dos/cpi/3.0/cpidos30.zip"
  }

  @gnu_fixture_sha256 %{
    encodings_def: "156cc484a53109241e3c4d23e0ac1d75c0e199eac48f3de8e9d9e87ecc1ce5f1",
    encodings_extra_def: "0747ecd7a6311ea3fab734d666e49b17e39750a4ba5d498fee267132461e3303",
    iconv_l_default: "f747cadfad9e17ecfa455937b2f95e8bef5c747dcd989d66e52e4681e49b3da1"
  }

  @required_metadata [
    "LGPL-2.1-or-later",
    "Code Page #3848 Brazil-ABICOMP",
    "3,261,185-byte Internet Archive artifact",
    "distinct 3,260,460-byte PDF 1.3 artifact",
    "Stylus Color 200 User's Guide",
    "FreeDOS CPIDOS 3.0",
    "Packed-bit transport",
    "GNU libiconv 1.19 does not expose ABICOMP or CP3848",
    "`PCL-13P`",
    "`PCL-14P`",
    "mapping oracle"
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
  def high_hex do
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
  def gnu_fixture_sha256(fixture), do: Map.fetch!(@gnu_fixture_sha256, fixture)

  def source_page(:star_manual), do: %{physical_pdf: 64, printed: 58}
  def source_page(:epson_manual), do: %{physical_pdf: 119, printed: "B-5"}
  def source_size(:star_manual), do: 3_261_185

  def alternate_artifact(:star_manual) do
    %{
      url:
        "https://minuszerodegrees.net/manuals/Star%20Micronics/dot_matrix/" <>
          "Star%20Micronics%20-%20LC-8021%20-%20Users%20Manual.pdf",
      sha256: "b47aa8daac993cdfa128f5036aa3cef8b5a05315b15c865cea509e3c88b80157",
      size: 3_260_460,
      page_64_semantics: :render_identical
    }
  end

  def source_license(source) when source in [:star_manual, :epson_manual],
    do: :copyrighted_reference_only

  def source_license(source) when source in [:freedos_archive, :freedos_ega18_cpx],
    do: :gpl_2_0_or_later_reference_only

  def profile_counts, do: %{defined: 192, undefined: 64, non_ascii: 64}
  def unit_bits, do: 8
  def control_policy, do: :ascii_identity_including_c0_and_del
  def reverse_policy, do: :exact_bijective_inverse
  def packed_applicability, do: :not_applicable_octet_codec
  def gnu_libiconv_support, do: :unsupported

  def excluded_variants,
    do: ["PCL-13P", "PCL-14P", "ABICOMP-INTERNATIONAL"]

  defp verify_sha!(label, bytes, expected) do
    actual = :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)

    unless actual == expected do
      raise ArgumentError,
            "ABICOMP #{label} SHA-256 mismatch: expected #{expected}, got #{actual}"
    end
  end

  defp validate_metadata!(metadata) do
    unless Enum.all?(@required_metadata, &String.contains?(metadata, &1)) do
      raise ArgumentError, "ABICOMP metadata omits a required provenance or policy statement"
    end
  end

  defp parse_rows!(mapping_bytes) do
    if String.contains?(mapping_bytes, "\r") do
      raise ArgumentError, "ABICOMP mapping must use LF line endings"
    end

    lines = String.split(mapping_bytes, "\n", trim: false)

    unless List.last(lines) == "" and Enum.at(lines, -2) != "" do
      raise ArgumentError, "ABICOMP mapping must end with exactly one LF"
    end

    case Enum.drop(lines, -1) do
      [@header | source_rows] when length(source_rows) == 256 ->
        source_rows
        |> Enum.with_index()
        |> Enum.map(fn {row, byte} -> parse_row!(row, byte) end)

      [@header | source_rows] ->
        raise ArgumentError,
              "ABICOMP mapping must contain 256 data rows, got #{length(source_rows)}"

      [header | _rows] ->
        raise ArgumentError, "unexpected ABICOMP mapping header: #{inspect(header)}"

      [] ->
        raise ArgumentError, "unexpected ABICOMP mapping header: missing"
    end
  end

  defp parse_row!(row, expected_byte) do
    expected_hex = Base.encode16(<<expected_byte>>)

    case String.split(row, ",", parts: 3) do
      [^expected_hex, unicode_hex, "mapped"] ->
        %{byte: expected_byte, unicode: parse_unicode!(unicode_hex, expected_hex)}

      [^expected_hex, "", "undefined"] ->
        %{byte: expected_byte, unicode: nil}

      [byte_hex, _unicode_hex, _status] when byte_hex != expected_hex ->
        raise ArgumentError,
              "ABICOMP mapping must contain ordered row #{expected_hex}; got #{inspect(byte_hex)}"

      _ ->
        raise ArgumentError,
              "ABICOMP row #{expected_hex} must be mapped to one scalar or explicitly undefined"
    end
  end

  defp parse_unicode!(unicode_hex, byte_hex) do
    unless Regex.match?(~r/\A[0-9A-F]{4,6}\z/, unicode_hex) do
      raise ArgumentError,
            "ABICOMP row #{byte_hex} has invalid Unicode scalar #{inspect(unicode_hex)}"
    end

    codepoint = String.to_integer(unicode_hex, 16)

    unless unicode_scalar?(codepoint) do
      raise ArgumentError, "ABICOMP row #{byte_hex} contains a non-scalar Unicode value"
    end

    codepoint
  end

  defp validate_invariants!(rows) do
    table = Enum.map(rows, & &1.unicode)
    defined = Enum.reject(table, &is_nil/1)

    undefined_bytes =
      rows
      |> Enum.filter(&is_nil(&1.unicode))
      |> Enum.map(& &1.byte)

    expected_undefined = Enum.to_list(0x80..0x9F) ++ Enum.to_list(0xE0..0xFF)

    unless Enum.take(table, 0x80) == Enum.to_list(0x00..0x7F) do
      raise ArgumentError, "ABICOMP bytes 00..7F must be exact ASCII/control identity"
    end

    unless undefined_bytes == expected_undefined do
      raise ArgumentError, "ABICOMP undefined-byte ranges must be exactly 80..9F and E0..FF"
    end

    unless Enum.all?(Enum.slice(table, 0xA0, 0x40), &is_integer/1) and
             length(defined) == 192 and length(Enum.uniq(defined)) == 192 do
      raise ArgumentError, "ABICOMP must define 192 unique scalar mappings"
    end

    sentinels = %{0xA0 => 0x00A0, 0xB5 => 0x0152, 0xBA => 0x0178, 0xD5 => 0x0153, 0xDF => 0x00B1}

    unless Enum.all?(sentinels, fn {byte, codepoint} -> Enum.at(table, byte) == codepoint end) do
      raise ArgumentError, "ABICOMP high-half sentinel mappings are not canonical"
    end
  end

  defp unicode_scalar?(codepoint),
    do: codepoint in 0x0000..0x10FFFF and codepoint not in 0xD800..0xDFFF
end
