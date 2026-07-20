defmodule Iconvex.Specs.UnicodeLegacyMappingsTest do
  use ExUnit.Case, async: false

  alias Iconvex.Specs.UnicodeLegacyMappings

  @source_directory Path.expand("../priv/sources/unicode-legacy", __DIR__)

  test "catalogues every standalone legacy coded-set mapping selected by the audit" do
    assert UnicodeLegacyMappings.aggregate_sha256() ==
             "1247487cb8f5e4cdcf8d304f5ed218827f9a8543b362576759cab114a7b40fef"

    assert Enum.map(UnicodeLegacyMappings.encodings(), & &1.name) == [
             "JIS0201",
             "JIS0212",
             "KSX1001",
             "OLD5601",
             "US-ASCII-QUOTES"
           ]
  end

  test "preserves the historical ASCII typographic quote variant" do
    codec = List.last(UnicodeLegacyMappings.codecs())
    assert codec.decode(<<0x27, 0x60>>) == {:ok, [0x2019, 0x2018]}
    assert codec.encode([0x2019, 0x2018]) == {:ok, <<0x27, 0x60>>}
  end

  test "verifies every source row, source digest, and canonical direction" do
    for {entry, codec} <-
          Enum.zip(UnicodeLegacyMappings.encodings(), UnicodeLegacyMappings.codecs()) do
      source = File.read!(Path.join(@source_directory, entry.source_file))
      rows = parse_mappings(source)
      decode = Enum.reduce(rows, %{}, fn {bytes, cp}, map -> Map.put_new(map, bytes, cp) end)
      encode = Enum.reduce(rows, %{}, fn {bytes, cp}, map -> Map.put_new(map, cp, bytes) end)

      assert sha256(source) == entry.sha256
      assert length(rows) == entry.mapping_rows
      assert map_size(decode) == entry.decode_mappings
      assert map_size(encode) == entry.encode_mappings

      for {bytes, codepoint} <- decode, do: assert(codec.decode(bytes) == {:ok, [codepoint]})
      for {codepoint, bytes} <- encode, do: assert(codec.encode([codepoint]) == {:ok, bytes})
    end
  end

  defp parse_mappings(source) do
    source
    |> String.split("\n")
    |> Enum.flat_map(fn line ->
      case Regex.run(~r/^0x([0-9A-Fa-f]+)\s+0x([0-9A-Fa-f]+)/, line, capture: :all_but_first) do
        [encoded, unicode] ->
          encoded = if rem(byte_size(encoded), 2) == 1, do: "0" <> encoded, else: encoded
          [{Base.decode16!(encoded, case: :mixed), String.to_integer(unicode, 16)}]

        nil ->
          []
      end
    end)
  end

  defp sha256(contents), do: :crypto.hash(:sha256, contents) |> Base.encode16(case: :lower)
end
