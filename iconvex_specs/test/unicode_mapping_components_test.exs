defmodule Iconvex.Specs.UnicodeMappingComponentsTest do
  use ExUnit.Case, async: false

  @source_directory Path.expand("../priv/sources/unicode-mapping-components", __DIR__)
  @encodings [
    "HANGUL-WANSUNG-COMPONENT",
    "HANGUL-UHANGUL",
    "HANGUL-JOHAB-COMPONENT",
    "IBMGRAPH",
    "IBMGRAPH-CP864"
  ]

  test "registers every separately framed mapping-table component" do
    for encoding <- @encodings do
      assert {:ok, %{canonical: ^encoding}} = Iconvex.Registry.resolve(encoding)
    end

    assert {:ok, %{canonical: "HANGUL-UHANGUL"}} = Iconvex.Registry.resolve("HANGUL")
  end

  test "the complete generated family is available through the public package API" do
    codecs = Iconvex.Specs.UnicodeMappingComponents.codecs()
    entries = Iconvex.Specs.UnicodeMappingComponents.encodings()

    assert Enum.map(entries, & &1.name) == @encodings
    assert Enum.map(codecs, & &1.canonical_name()) == @encodings
  end

  test "pins both complete public sources and every mapping row" do
    family = Iconvex.Specs.UnicodeMappingComponents

    assert family.aggregate_sha256() ==
             "f47ff713ec66d48328892ff13b1521f049f620c37fd973de36c697dfba0dfa53"

    for {entry, codec} <- Enum.zip(family.encodings(), family.codecs()) do
      source = File.read!(Path.join(@source_directory, entry.source_file))
      rows = parse_mappings(source, entry.parser)
      decode = Map.new(rows)
      encode = Map.new(rows, fn {bytes, codepoint} -> {codepoint, bytes} end)

      assert sha256(source) == entry.sha256
      assert length(rows) == entry.mapping_rows
      assert map_size(decode) == entry.decode_mappings
      assert map_size(encode) == entry.encode_mappings

      for {bytes, codepoint} <- decode do
        assert codec.decode(bytes) == {:ok, [codepoint]}
      end

      for {codepoint, bytes} <- encode do
        assert codec.encode([codepoint]) == {:ok, bytes}
      end
    end
  end

  test "exhausts every possible encoded unit without inventing positions" do
    family = Iconvex.Specs.UnicodeMappingComponents

    for {entry, codec} <- Enum.zip(family.encodings(), family.codecs()) do
      source = File.read!(Path.join(@source_directory, entry.source_file))
      expected = source |> parse_mappings(entry.parser) |> Map.new()

      inputs =
        if entry.max_input == 1 do
          for byte <- 0..255, do: <<byte>>
        else
          for word <- 0..0xFFFF, do: <<word::16>>
        end

      for bytes <- inputs do
        case Map.fetch(expected, bytes) do
          {:ok, codepoint} -> assert codec.decode(bytes) == {:ok, [codepoint]}
          :error -> assert match?({:error, _, _, _}, codec.decode(bytes))
        end
      end

      if entry.max_input == 2 do
        for prefix <- 0..255 do
          assert match?({:error, _, _, _}, codec.decode(<<prefix>>))
        end
      end
    end
  end

  @tag timeout: 120_000
  test "checks every Unicode scalar against every component encoder" do
    scalars = Enum.to_list(0..0xD7FF) ++ Enum.to_list(0xE000..0x10FFFF)
    family = Iconvex.Specs.UnicodeMappingComponents

    for {entry, codec} <- Enum.zip(family.encodings(), family.codecs()) do
      source = File.read!(Path.join(@source_directory, entry.source_file))

      expected =
        source
        |> parse_mappings(entry.parser)
        |> Map.new(fn {bytes, codepoint} -> {codepoint, bytes} end)

      expected_binary =
        scalars
        |> Enum.flat_map(fn codepoint ->
          case expected do
            %{^codepoint => bytes} -> [bytes]
            _ -> []
          end
        end)
        |> IO.iodata_to_binary()

      assert codec.encode_discard(scalars) == {:ok, expected_binary}
    end
  end

  defp parse_mappings(source, {:hangul, column}) do
    source
    |> String.split("\n")
    |> Enum.flat_map(fn line ->
      fields = String.split(line)

      if length(fields) >= 7 and Regex.match?(~r/^\d+$/, hd(fields)) do
        encoded = Enum.at(fields, column)
        unicode = Enum.at(fields, 6)

        if encoded == "-",
          do: [],
          else: [{Base.decode16!(encoded), String.to_integer(unicode, 16)}]
      else
        []
      end
    end)
  end

  defp parse_mappings(source, {:ibmgraph, column}) do
    source
    |> String.split("\n")
    |> Enum.flat_map(fn line ->
      fields = String.split(line)

      if length(fields) >= 3 and Regex.match?(~r/^[0-9A-Fa-f]{4,6}$/, hd(fields)) do
        encoded = Enum.at(fields, column)

        if encoded == "--",
          do: [],
          else: [{Base.decode16!(encoded), String.to_integer(hd(fields), 16)}]
      else
        []
      end
    end)
  end

  defp sha256(contents), do: :crypto.hash(:sha256, contents) |> Base.encode16(case: :lower)
end
