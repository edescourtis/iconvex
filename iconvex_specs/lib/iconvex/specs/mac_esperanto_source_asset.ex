defmodule Iconvex.Specs.MacEsperanto.SourceAsset do
  @moduledoc false

  @source_dir Path.expand("../../../priv/sources/mac-esperanto", __DIR__)
  @mapping_path Path.join(@source_dir, "macos_esperanto_0_3.csv")
  @metadata_path Path.join(@source_dir, "SOURCE_METADATA.md")
  @external_resource @mapping_path
  @external_resource @metadata_path

  @header "byte_hex,unicode_hex,provenance"
  @mapping_sha256 "4ad11598020843b2728f438dc8e8e3149ee822ae03a688330ad0b80dc013aa05"
  @metadata_sha256 "20a59bec95edd225467b15124a6a1634799c01322ebe3dd0ac125b42a5e93ea1"
  @upstream_sha256 "d7ca70a8da95d5ec5338705d3cd0907232eed98416fe062bb731d86090a52084"
  @gnu_fixture_sha256 %{
    encodings_def: "156cc484a53109241e3c4d23e0ac1d75c0e199eac48f3de8e9d9e87ecc1ce5f1",
    encodings_extra_def: "0747ecd7a6311ea3fab734d666e49b17e39750a4ba5d498fee267132461e3303",
    iconv_l_default: "f747cadfad9e17ecfa455937b2f95e8bef5c747dcd989d66e52e4681e49b3da1"
  }

  @expected_high_hex """
  000000C4000000C5000000C7000000C9000000D1000000D6000000DC000000E1
  000000E0000000E2000000E4000000E3000000E5000000E7000000E9000000E8
  000000EA000000EB000000ED000000EC000000EE000000EF000000F1000000F3
  000000F2000000F4000000F6000000F5000000FA000000F9000000FB000000FC
  00002020000000B0000000A2000000A3000000A700002022000000B6000000DF
  000000AE000000A900002122000000B4000000A800002260000000C6000000D8
  00000108000000B1000022640000226500000109000000B50000011C0000011D
  000001240000012500000134000001350000015C0000015D000000E6000000F8
  0000016C0000016D000000AC0000010A000001920000010B00000120000000AB
  000000BB00002026000000A0000000C0000000C3000000D50000015200000153
  00002013000020140000201C0000201D0000201800002019000000F7000025CA
  000000FF000001780000011E0000011F00000130000001310000015E0000015F
  00002021000000B70000201A0000201E00002030000000C2000000CA000000C1
  000000CB000000C8000000CD000000CE000000CF000000CC000000D3000000D4
  00000121000000D2000000DA000000DB000000D9000000A4000002C6000002DC
  00000126000002D8000002D90000017B000000B80000017C00000127000002C7
  """

  @expected_high @expected_high_hex
                 |> String.replace(~r/\s+/, "")
                 |> Base.decode16!()
                 |> then(fn binary ->
                   for <<codepoint::unsigned-big-32 <- binary>>, do: codepoint
                 end)

  @required_metadata [
    "MacOS_Esperanto",
    "Table version: 0.3",
    "15 August 1997",
    "Michael Everson",
    "Apple Computer, Inc.",
    "13,591 bytes",
    @upstream_sha256,
    @mapping_sha256,
    "C0 and DEL",
    "Unicode-identity text transport",
    "LGPL-2.1-or-later",
    "GNU libiconv 1.19 does not expose",
    "156cc484a53109241e3c4d23e0ac1d75c0e199eac48f3de8e9d9e87ecc1ce5f1",
    "0747ecd7a6311ea3fab734d666e49b17e39750a4ba5d498fee267132461e3303",
    "f747cadfad9e17ecfa455937b2f95e8bef5c747dcd989d66e52e4681e49b3da1"
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
    |> Enum.map(fn %{unicode: codepoint} -> <<codepoint::unsigned-big-32>> end)
    |> IO.iodata_to_binary()
    |> Base.encode16()
  end

  def mapping_sha256, do: @mapping_sha256
  def metadata_sha256, do: @metadata_sha256
  def upstream_sha256, do: @upstream_sha256
  def gnu_fixture_sha256(fixture), do: Map.fetch!(@gnu_fixture_sha256, fixture)
  def source_size, do: 13_591
  def source_version, do: "0.3"
  def source_date, do: "1997-08-15"
  def source_author, do: "Michael Everson"

  def source_url,
    do: "https://www.evertype.com/standards/eo/eo-table.html"

  defp verify_sha!(label, bytes, expected) do
    actual = :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)

    unless actual == expected do
      raise ArgumentError,
            "MacOS Esperanto #{label} SHA-256 mismatch: expected #{expected}, got #{actual}"
    end
  end

  defp validate_metadata!(metadata) do
    unless Enum.all?(@required_metadata, &String.contains?(metadata, &1)) do
      raise ArgumentError,
            "MacOS Esperanto metadata omits a required provenance or policy statement"
    end
  end

  defp parse_rows!(mapping_bytes) do
    if String.contains?(mapping_bytes, "\r") do
      raise ArgumentError, "MacOS Esperanto mapping must use LF line endings"
    end

    lines = String.split(mapping_bytes, "\n", trim: false)

    unless List.last(lines) == "" and Enum.at(lines, -2) != "" do
      raise ArgumentError, "MacOS Esperanto mapping must end with exactly one LF"
    end

    case Enum.drop(lines, -1) do
      [@header | source_rows] when length(source_rows) == 256 ->
        source_rows
        |> Enum.with_index()
        |> Enum.map(fn {row, byte} -> parse_row!(row, byte) end)

      [@header | source_rows] ->
        raise ArgumentError,
              "MacOS Esperanto mapping must contain 256 data rows, got #{length(source_rows)}"

      [header | _rows] ->
        raise ArgumentError,
              "unexpected MacOS Esperanto mapping header: #{inspect(header)}"

      [] ->
        raise ArgumentError, "unexpected MacOS Esperanto mapping header: missing"
    end
  end

  defp parse_row!(row, expected_byte) do
    expected_hex = Base.encode16(<<expected_byte>>)

    case String.split(row, ",", parts: 3) do
      [^expected_hex, unicode_hex, provenance] ->
        %{
          byte: expected_byte,
          unicode: parse_unicode!(unicode_hex, expected_hex),
          provenance: provenance
        }

      [byte_hex, _unicode_hex, _provenance] ->
        raise ArgumentError,
              "MacOS Esperanto mapping must contain ordered row #{expected_hex}; " <>
                "got #{inspect(byte_hex)}"

      _ ->
        raise ArgumentError,
              "MacOS Esperanto row #{expected_hex} must contain exactly three fields"
    end
  end

  defp parse_unicode!(unicode_hex, byte_hex) do
    unless Regex.match?(~r/\A[0-9A-F]{4,6}\z/, unicode_hex) do
      raise ArgumentError,
            "MacOS Esperanto row #{byte_hex} has invalid Unicode scalar #{inspect(unicode_hex)}"
    end

    codepoint = String.to_integer(unicode_hex, 16)

    unless codepoint in 0x0000..0x10FFFF and codepoint not in 0xD800..0xDFFF do
      raise ArgumentError,
            "MacOS Esperanto row #{byte_hex} contains a non-scalar Unicode value"
    end

    codepoint
  end

  defp validate_invariants!(rows) do
    table = Enum.map(rows, & &1.unicode)
    provenance = Enum.map(rows, & &1.provenance)

    unless Enum.take(table, 0x80) == Enum.to_list(0x00..0x7F) do
      raise ArgumentError,
            "MacOS Esperanto bytes 00..7F must use the audited identity policy"
    end

    unless Enum.drop(table, 0x80) == @expected_high do
      raise ArgumentError,
            "MacOS Esperanto bytes 80..FF differ from source table version 0.3"
    end

    expected_provenance =
      Enum.map(0..255, fn
        byte when byte in 0x00..0x1F or byte == 0x7F -> "transport_identity"
        byte when byte in 0x20..0x7E -> "source_identity"
        _byte -> "source_mapping"
      end)

    unless provenance == expected_provenance do
      raise ArgumentError,
            "MacOS Esperanto provenance must distinguish source rows from transport rows"
    end

    unless length(Enum.uniq(table)) == 256 do
      raise ArgumentError, "MacOS Esperanto must have a unique mapping for every octet"
    end
  end
end
