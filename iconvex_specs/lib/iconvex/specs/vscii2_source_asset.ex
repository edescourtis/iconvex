defmodule Iconvex.Specs.VSCII2.SourceAsset do
  @moduledoc false

  @source_dir Path.expand("../../../priv/sources/vscii-2", __DIR__)
  @mapping_path Path.join(@source_dir, "vscii2.csv")
  @metadata_path Path.join(@source_dir, "SOURCE_METADATA.md")
  @external_resource @mapping_path
  @external_resource @metadata_path

  @header "byte_hex,unicode_hex,status"
  @mapping_sha256 "719bd06c76a258e414f422093b49a7687da111e9cbf2fab14194ff57e2d6f127"
  @metadata_sha256 "9a0b0fa992eea3858d72a22697a19252aebeb426038029b3ae7a3a0517fea6a3"

  @source_sha256 %{
    iso_ir_180: "a02cf84237d0344f2ef1d09f125a4fa5ea5464bdf1d90bd8e537bac04c9090a0",
    vsqi_catalog: "5b5a8909bb9b7ca9e6dbe6f390466657f341d182e7c11afcf94242df4fa980b1",
    python_charmap: "4b2385eed17f8aa30b3299ddc924b83bff6479f43befbb7619d81a97b04b920b",
    unicode_data_17: "2e1efc1dcb59c575eedf5ccae60f95229f706ee6d031835247d843c11d96470c"
  }

  @source_urls %{
    iso_ir_180: "https://itscj.ipsj.or.jp/ir/180.pdf",
    vsqi_catalog: "https://tieuchuan.vsqi.gov.vn/tieuchuan/view?sohieu=TCVN+5712%3A1993",
    python_charmap: "https://bugs.python.org/file37055/TCVN5712-2.TXT",
    unicode_data_17: "https://www.unicode.org/Public/17.0.0/ucd/UnicodeData.txt"
  }

  @source_sizes %{
    iso_ir_180: 998_754,
    vsqi_catalog: 32_280,
    unicode_data_17: 2_198_209
  }

  @gnu_fixture_sha256 %{
    encodings_def: "156cc484a53109241e3c4d23e0ac1d75c0e199eac48f3de8e9d9e87ecc1ce5f1",
    encodings_extra_def: "0747ecd7a6311ea3fab734d666e49b17e39750a4ba5d498fee267132461e3303",
    iconv_l_default: "f747cadfad9e17ecfa455937b2f95e8bef5c747dcd989d66e52e4681e49b3da1"
  }

  @required_metadata [
    "LGPL-2.1-or-later",
    "Right-hand Part of the VSCII-2 Code Table",
    "TCVN 5712:1993 VN2",
    "ISO-IR-180",
    "All six pages were rendered",
    "UnicodeData 17.0",
    "zero name mismatches",
    "TCVN5712-2.TXT",
    "no normalization",
    "Packed-bit transport is not applicable",
    "GNU libiconv 1.19 does not expose VSCII-2",
    "`VISCII`",
    "`x-viet-tcvn5712`",
    "core misalias has been removed",
    "external `:vscii_2` codec"
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
  def source_size(source), do: Map.fetch!(@source_sizes, source)
  def source_page_count(:iso_ir_180), do: 6
  def gnu_fixture_sha256(fixture), do: Map.fetch!(@gnu_fixture_sha256, fixture)

  def source_license(source) when source in [:iso_ir_180, :vsqi_catalog],
    do: :copyrighted_reference_only

  def source_license(:python_charmap), do: :psf_contribution_reference_only
  def source_license(:unicode_data_17), do: :unicode_data_license_reference_only

  def standard_profile, do: {:tcvn_5712_1993, :vn2}
  def profile_counts, do: %{defined: 224, undefined: 32, non_ascii: 96}
  def unit_bits, do: 8
  def control_policy, do: :ascii_identity_including_c0_and_del
  def undefined_policy, do: :c1_80_9f_undefined
  def reverse_policy, do: :exact_bijective_inverse
  def normalization_policy, do: :none_raw_graphic_mappings
  def packed_applicability, do: :not_applicable_octet_codec
  def gnu_libiconv_support, do: :unsupported

  def excluded_variants do
    [
      "VISCII",
      "VSCII-1",
      "VSCII-3",
      "TCVN",
      "TCVN-5712",
      "TCVN5712-1",
      "TCVN5712-1:1993",
      "TCVN3",
      "VN1",
      "VN3",
      "x-viet-tcvn5712"
    ]
  end

  def core_registry_audit do
    %{
      path: "../iconvex/lib/iconvex/registry.ex",
      alias: "ISO-IR-180",
      formerly_incorrect_target: :viscii,
      current_builtin_target: :unregistered,
      required_external_target: :vscii_2,
      status: :core_misalias_removed_pending_specs_registration
    }
  end

  defp verify_sha!(label, bytes, expected) do
    actual = :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)

    unless actual == expected do
      raise ArgumentError,
            "VSCII-2 #{label} SHA-256 mismatch: expected #{expected}, got #{actual}"
    end
  end

  defp validate_metadata!(metadata) do
    unless Enum.all?(@required_metadata, &String.contains?(metadata, &1)) do
      raise ArgumentError, "VSCII-2 metadata omits a required provenance or policy statement"
    end
  end

  defp parse_rows!(mapping_bytes) do
    if String.contains?(mapping_bytes, "\r") do
      raise ArgumentError, "VSCII-2 mapping must use LF line endings"
    end

    lines = String.split(mapping_bytes, "\n", trim: false)

    unless List.last(lines) == "" and Enum.at(lines, -2) != "" do
      raise ArgumentError, "VSCII-2 mapping must end with exactly one LF"
    end

    case Enum.drop(lines, -1) do
      [@header | source_rows] when length(source_rows) == 256 ->
        source_rows
        |> Enum.with_index()
        |> Enum.map(fn {row, byte} -> parse_row!(row, byte) end)

      [@header | source_rows] ->
        raise ArgumentError,
              "VSCII-2 mapping must contain 256 data rows, got #{length(source_rows)}"

      [header | _rows] ->
        raise ArgumentError, "unexpected VSCII-2 mapping header: #{inspect(header)}"

      [] ->
        raise ArgumentError, "unexpected VSCII-2 mapping header: missing"
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
              "VSCII-2 mapping must contain ordered row #{expected_hex}; got #{inspect(byte_hex)}"

      _ ->
        raise ArgumentError,
              "VSCII-2 row #{expected_hex} must map one scalar or be explicitly undefined"
    end
  end

  defp parse_unicode!(unicode_hex, byte_hex) do
    unless Regex.match?(~r/\A[0-9A-F]{4,6}\z/, unicode_hex) do
      raise ArgumentError,
            "VSCII-2 row #{byte_hex} has invalid Unicode scalar #{inspect(unicode_hex)}"
    end

    codepoint = String.to_integer(unicode_hex, 16)

    unless unicode_scalar?(codepoint) do
      raise ArgumentError, "VSCII-2 row #{byte_hex} contains a non-scalar Unicode value"
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

    unless Enum.take(table, 0x80) == Enum.to_list(0x00..0x7F) do
      raise ArgumentError, "VSCII-2 bytes 00..7F must be exact ASCII/control identity"
    end

    unless undefined_bytes == Enum.to_list(0x80..0x9F) do
      raise ArgumentError, "VSCII-2 undefined-byte range must be exactly 80..9F"
    end

    unless Enum.all?(Enum.slice(table, 0xA0, 0x60), &is_integer/1) and
             length(defined) == 224 and length(Enum.uniq(defined)) == 224 do
      raise ArgumentError, "VSCII-2 must define 224 unique scalar mappings"
    end

    sentinels = %{
      0xA0 => 0x00A0,
      0xA1 => 0x0102,
      0xAF => 0x1EB0,
      0xB0 => 0x0300,
      0xB4 => 0x0323,
      0xC0 => 0x1EAE,
      0xFF => 0x1ED0
    }

    unless Enum.all?(sentinels, fn {byte, codepoint} -> Enum.at(table, byte) == codepoint end) do
      raise ArgumentError, "VSCII-2 high-half sentinel mappings are not canonical"
    end

    unless Enum.slice(table, 0xB0, 5) == [0x0300, 0x0309, 0x0303, 0x0301, 0x0323] do
      raise ArgumentError, "VSCII-2 combining-mark positions B0..B4 are not canonical"
    end
  end

  defp unicode_scalar?(codepoint),
    do: codepoint in 0x0000..0x10FFFF and codepoint not in 0xD800..0xDFFF
end
