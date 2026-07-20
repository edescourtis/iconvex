ExUnit.start()

defmodule Iconvex.Extras.TestFixture do
  @moduledoc false
  @mapping_root Path.expand("fixtures/mappings", __DIR__)
  @definition_root Path.expand("fixtures/definitions", __DIR__)

  def mapping_files do
    @mapping_root
    |> Path.join("*.TXT")
    |> Path.wildcard()
    |> Enum.reject(&String.ends_with?(&1, ".IRREVERSIBLE.TXT"))
    |> Enum.sort()
  end

  def encoding_for(path), do: Path.basename(path, ".TXT")
  def definitions, do: @definition_root

  def mappings(path), do: path |> File.stream!([], :line) |> Enum.map(&parse_mapping/1)

  def inverse_mappings(path) do
    reversible =
      Enum.filter(mappings(path), fn {_bytes, codepoints} -> length(codepoints) == 1 end)

    irreversible = String.replace_suffix(path, ".TXT", ".IRREVERSIBLE.TXT")

    entries =
      if File.regular?(irreversible), do: reversible ++ mappings(irreversible), else: reversible

    entries
    |> Enum.frequencies()
    |> Enum.flat_map(fn {entry, count} -> if count == 1, do: [entry], else: [] end)
    |> Enum.sort()
  end

  def interspersed_decode_input(mappings) do
    {separator_bytes, [separator_codepoint]} =
      Enum.find(mappings, fn {_bytes, codepoints} -> codepoints == [0] end) ||
        Enum.find(mappings, fn {_bytes, codepoints} -> length(codepoints) == 1 end)

    input = mappings |> Enum.map(&elem(&1, 0)) |> Enum.intersperse(separator_bytes)
    expected = mappings |> Enum.map(&elem(&1, 1)) |> Enum.intersperse([separator_codepoint])
    {IO.iodata_to_binary(input), List.flatten(expected)}
  end

  def interspersed_encode_input(mappings) do
    {separator_bytes, [separator_codepoint]} =
      Enum.find(mappings, fn {_bytes, codepoints} -> codepoints == [0] end) || hd(mappings)

    input = mappings |> Enum.map(&elem(&1, 1)) |> Enum.intersperse([separator_codepoint])
    expected = mappings |> Enum.map(&elem(&1, 0)) |> Enum.intersperse(separator_bytes)
    {List.flatten(input), IO.iodata_to_binary(expected)}
  end

  def parse_definitions(files) do
    {entries, aliases} =
      Enum.reduce(files, {%{}, %{}}, fn filename, acc ->
        @definition_root
        |> Path.join(filename)
        |> File.read!()
        |> parse_definition_file(acc)
      end)

    aliases =
      Enum.reduce(entries, aliases, fn {id, canonical}, acc ->
        Map.put(acc, String.upcase(canonical, :ascii), id)
      end)

    {entries, aliases}
  end

  defp parse_definition_file(source, {entries, aliases}) do
    source = Regex.replace(~r{/\*.*?\*/}s, source, "")

    definitions =
      Regex.scan(~r/DEFENCODING\(\(\s*(.*?)\),\s*([a-z0-9_]+)\s*,/s, source,
        capture: :all_but_first
      )

    {entries, aliases} =
      Enum.reduce(definitions, {entries, aliases}, fn [names_source, id], {entries, aliases} ->
        names = Regex.scan(~r/"([^"]+)"/, names_source, capture: :all_but_first) |> List.flatten()
        aliases = Enum.reduce(names, aliases, &Map.put(&2, String.upcase(&1, :ascii), id))
        {Map.put_new(entries, id, hd(names)), aliases}
      end)

    aliases =
      Regex.scan(~r/DEFALIAS\(\s*"([^"]+)"\s*,\s*([a-z0-9_]+)\s*\)/s, source,
        capture: :all_but_first
      )
      |> Enum.reduce(aliases, fn [name, id], acc ->
        Map.put(acc, String.upcase(name, :ascii), id)
      end)

    {entries, aliases}
  end

  defp parse_mapping(line) do
    [encoded, unicode] = line |> String.trim() |> String.split("\t", parts: 2)

    bytes =
      encoded
      |> String.trim_leading("0x")
      |> then(fn hex -> if rem(byte_size(hex), 2) == 0, do: hex, else: "0" <> hex end)
      |> Base.decode16!(case: :mixed)

    codepoints =
      unicode
      |> String.split()
      |> Enum.map(fn "0x" <> hex -> String.to_integer(hex, 16) end)

    {bytes, codepoints}
  end
end
