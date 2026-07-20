defmodule Iconvex.Specs.UnihanGB3RowCell.SourceAsset do
  @moduledoc false

  @expected_hashes %{
    mapping: "63dd2f9d88dc53b9c3603fe798b6f414c578fc22b68d840225a5d44b890d6baf",
    metadata: "00bf033ed91971e6d5fdc81bde75386ad935ed22f408541bf6b9f4e04091e6cf"
  }

  @metadata_markers [
    "Unicode 17.0.0",
    "provisional `kGB3`",
    "does not claim exact GB 13131-1991 conformance",
    "no ISO-2022 designation",
    "Unicode License v3",
    @expected_hashes.mapping
  ]

  def expected_hashes, do: @expected_hashes

  def validate!(mapping, metadata, hashes)
      when is_binary(mapping) and is_binary(metadata) and is_map(hashes) do
    unless Map.keys(hashes) |> Enum.sort() == [:mapping, :metadata],
      do: raise(ArgumentError, "kGB3 asset hashes must contain mapping and metadata")

    verify_hash!(mapping, Map.fetch!(hashes, :mapping), "mapping")
    verify_hash!(metadata, Map.fetch!(hashes, :metadata), "metadata")
    validate_metadata!(metadata)
    validate_mapping!(mapping)
  end

  def validate!(_mapping, _metadata, _hashes),
    do: raise(ArgumentError, "kGB3 assets and hashes must be binary/map values")

  defp validate_mapping!(mapping) do
    if :binary.match(mapping, "\r") != :nomatch,
      do: raise(ArgumentError, "kGB3 mapping must use LF line endings")

    unless String.ends_with?(mapping, "\n") and not String.ends_with?(mapping, "\n\n"),
      do: raise(ArgumentError, "kGB3 mapping must end with exactly one LF")

    [header | rows] = String.split(mapping, "\n", trim: true)

    unless header == "row_cell_decimal,unicode_scalar",
      do: raise(ArgumentError, "unexpected kGB3 mapping header: #{inspect(header)}")

    unless length(rows) == 7_236,
      do: raise(ArgumentError, "kGB3 mapping must contain exactly 7,236 rows")

    parsed = Enum.map(rows, &parse_row!/1)
    coordinates = Enum.map(parsed, & &1.coordinate)
    scalars = Enum.map(parsed, & &1.scalar)

    unless coordinates == Enum.sort(coordinates) and
             length(coordinates) == length(Enum.uniq(coordinates)) do
      raise ArgumentError, "kGB3 coordinates must be unique and strictly increasing"
    end

    unless length(scalars) == length(Enum.uniq(scalars)),
      do: raise(ArgumentError, "kGB3 Unicode scalars must be unique")

    expected = for row <- 16..92, cell <- 1..94, do: row * 100 + cell

    unless expected -- coordinates == [1893, 9294],
      do: raise(ArgumentError, "kGB3 missing-coordinate set must equal [1893, 9294]")

    parsed
  end

  defp parse_row!(row) do
    case Regex.run(~r/^([0-9]{4}),U\+([0-9A-F]{4,6})$/, row) do
      [_, coordinate_text, scalar_text] ->
        coordinate = String.to_integer(coordinate_text)
        scalar = String.to_integer(scalar_text, 16)
        row_number = div(coordinate, 100)
        cell = rem(coordinate, 100)

        unless row_number in 16..92 and cell in 1..94,
          do: raise(ArgumentError, "kGB3 row/cell domain violation: #{coordinate_text}")

        unless valid_scalar?(scalar),
          do: raise(ArgumentError, "invalid kGB3 Unicode scalar: U+#{scalar_text}")

        %{coordinate: coordinate, row: row_number, cell: cell, scalar: scalar}

      _ ->
        raise ArgumentError, "invalid kGB3 mapping row: #{inspect(row)}"
    end
  end

  defp validate_metadata!(metadata) do
    unless Enum.all?(@metadata_markers, &String.contains?(metadata, &1)) do
      raise ArgumentError,
            "kGB3 metadata omits required source, version, transport, caveat, or license claims"
    end
  end

  defp verify_hash!(contents, expected, label) do
    actual = sha256(contents)

    unless actual == expected,
      do:
        raise(
          ArgumentError,
          "kGB3 #{label} SHA-256 mismatch: expected #{expected}, got #{actual}"
        )
  end

  defp valid_scalar?(scalar),
    do: scalar in 0..0x10FFFF and scalar not in 0xD800..0xDFFF

  defp sha256(binary), do: :crypto.hash(:sha256, binary) |> Base.encode16(case: :lower)
end
