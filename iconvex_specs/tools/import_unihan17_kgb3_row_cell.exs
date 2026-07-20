defmodule Iconvex.Specs.Tools.ImportUnihan17KGB3RowCell do
  @moduledoc false

  @unihan_sha256 "4fabda168d04a5ac360809a8bfa377fe54e04fbc069ba67cacad4df03d691fa0"
  @unicode_data_sha256 "2e1efc1dcb59c575eedf5ccae60f95229f706ee6d031835247d843c11d96470c"
  @mapping_sha256 "63dd2f9d88dc53b9c3603fe798b6f414c578fc22b68d840225a5d44b890d6baf"

  def run(arguments) do
    check? = arguments == ["--check"]

    unless arguments in [[], ["--check"]],
      do: Mix.raise("usage: mix run tools/import_unihan17_kgb3_row_cell.exs -- [--check]")

    root = Path.expand("..", __DIR__)
    fixture_dir = Path.join(root, "test/fixtures/unihan-17.0.0-telegraph")
    unihan = Path.join(fixture_dir, "Unihan_OtherMappings-17.0.0.txt")
    unicode_data = Path.join(fixture_dir, "UnicodeData-17.0.0.txt")
    output = Path.join(root, "priv/sources/unihan-17.0.0-kgb3/row_cells.csv")

    assert_sha!(unihan, @unihan_sha256)
    assert_sha!(unicode_data, @unicode_data_sha256)

    rows = parse_unihan!(File.read!(unihan))
    validate!(rows)
    contents = serialize(rows)

    unless sha256(contents) == @mapping_sha256,
      do: Mix.raise("generated kGB3 mapping digest differs from the pinned snapshot")

    if check? do
      unless File.regular?(output) and File.read!(output) == contents,
        do: Mix.raise("#{Path.relative_to_cwd(output)} is out of date")

      IO.puts("#{Path.relative_to_cwd(output)} is current (7,236 mappings)")
    else
      output |> Path.dirname() |> File.mkdir_p!()
      File.write!(output, contents)
      IO.puts("wrote 7,236 Unicode 17 kGB3 mappings to #{Path.relative_to_cwd(output)}")
    end
  end

  defp parse_unihan!(contents) do
    contents
    |> String.split("\n", trim: true)
    |> Enum.flat_map(fn line ->
      case Regex.run(~r/^U\+([0-9A-F]{4,6})\tkGB3\t([0-9]{4})$/, line) do
        [_, scalar, coordinate] ->
          [{String.to_integer(coordinate), String.to_integer(scalar, 16)}]

        _ ->
          []
      end
    end)
    |> Enum.sort()
  end

  defp validate!(rows) do
    coordinates = Enum.map(rows, &elem(&1, 0))
    scalars = Enum.map(rows, &elem(&1, 1))

    unless length(rows) == 7_236 and length(Enum.uniq(coordinates)) == 7_236 and
             length(Enum.uniq(scalars)) == 7_236 do
      Mix.raise("kGB3 must contain exactly 7,236 one-to-one mappings")
    end

    unless Enum.all?(coordinates, fn coordinate ->
             row = div(coordinate, 100)
             cell = rem(coordinate, 100)
             row in 16..92 and cell in 1..94
           end) do
      Mix.raise("kGB3 contains a coordinate outside rows 16..92 and cells 01..94")
    end

    expected_coordinates = for row <- 16..92, cell <- 1..94, do: row * 100 + cell

    unless expected_coordinates -- coordinates == [1893, 9294],
      do: Mix.raise("kGB3 missing-coordinate set differs from [1893, 9294]")

    unless Enum.count(scalars, &(&1 in 0x3400..0x4DBF)) == 2_391 and
             Enum.count(scalars, &(&1 in 0x4E00..0x9FFF)) == 4_843 and
             Enum.count(scalars, &(&1 in 0x20000..0x2A6DF)) == 2 do
      Mix.raise("kGB3 Unicode block counts differ from the pinned Unicode 17 snapshot")
    end
  end

  defp serialize(rows) do
    "row_cell_decimal,unicode_scalar\n" <>
      Enum.map_join(rows, "", fn {coordinate, scalar} ->
        Integer.to_string(coordinate) <>
          ",U+" <>
          (scalar |> Integer.to_string(16) |> String.upcase() |> String.pad_leading(4, "0")) <>
          "\n"
      end)
  end

  defp assert_sha!(path, expected) do
    actual = path |> File.read!() |> sha256()

    unless actual == expected,
      do: Mix.raise("#{path}: expected SHA-256 #{expected}, got #{actual}")
  end

  defp sha256(binary), do: :crypto.hash(:sha256, binary) |> Base.encode16(case: :lower)
end

arguments =
  case System.argv() do
    ["--" | rest] -> rest
    rest -> rest
  end

Iconvex.Specs.Tools.ImportUnihan17KGB3RowCell.run(arguments)
