defmodule Iconvex.Specs.ICUMultibyteTest do
  use ExUnit.Case, async: false

  alias Iconvex.Specs.ICUMultibyte

  @source_directory Path.expand("../priv/sources/icu-78.3-multibyte", __DIR__)
  @revision "21d1eb0f306e1141c10931e914dfc038c06121da"

  test "pins all complete table-driven ICU MBCS and DBCS sources" do
    assert ICUMultibyte.revision() == @revision
    assert length(ICUMultibyte.encodings()) == 30
    assert Enum.all?(ICUMultibyte.encodings(), &(&1.uconv_class in ["MBCS", "DBCS"]))

    assert ICUMultibyte.exclusions() == [
             "gb18030-2022.ucm",
             "icu-internal-25546.ucm",
             "icu-internal-compound-d1.ucm",
             "icu-internal-compound-d2.ucm",
             "icu-internal-compound-d3.ucm",
             "icu-internal-compound-d4.ucm",
             "icu-internal-compound-d5.ucm",
             "icu-internal-compound-d6.ucm",
             "icu-internal-compound-d7.ucm",
             "icu-internal-compound-t.ucm",
             "lmb-excp.ucm"
           ]
  end

  test "verifies source digests and independently rebuilds every mapping count" do
    for entry <- ICUMultibyte.encodings() do
      source = File.read!(Path.join(@source_directory, entry.source_file))
      mappings = parse_mappings(source)

      assert sha256(source) == entry.sha256
      assert length(mappings) == entry.mapping_rows
      assert map_size(decode_map(mappings)) == entry.decode_mappings
      assert map_size(encode_map(mappings)) == entry.encode_mappings
    end
  end

  @tag timeout: 180_000
  test "executes every UCM multibyte decoder mapping" do
    for {entry, codec} <- Enum.zip(ICUMultibyte.encodings(), ICUMultibyte.codecs()) do
      source = File.read!(Path.join(@source_directory, entry.source_file))

      for {bytes, codepoints} <- source |> parse_mappings() |> decode_map() do
        assert codec.decode(bytes) == {:ok, Tuple.to_list(codepoints)}
      end
    end
  end

  @tag timeout: 180_000
  test "executes every canonical UCM multibyte encoder mapping" do
    for {entry, codec} <- Enum.zip(ICUMultibyte.encodings(), ICUMultibyte.codecs()) do
      source = File.read!(Path.join(@source_directory, entry.source_file))

      for {codepoints, bytes} <- source |> parse_mappings() |> encode_map() do
        assert codec.encode(Tuple.to_list(codepoints)) == {:ok, bytes}
      end
    end
  end

  test "keeps incomplete prefixes strict and registers exact revision names" do
    entry = Enum.find(ICUMultibyte.encodings(), &(&1.name == "euc-jp-2007"))
    codec = Enum.at(ICUMultibyte.codecs(), entry.index - 1)

    assert codec.decode(<<0x8F>>) == {:error, :incomplete_sequence, 0, <<0x8F>>}
    assert Iconvex.canonical_name(entry.name) == {:ok, entry.name}
  end

  defp parse_mappings(source) do
    source
    |> String.split("CHARMAP", parts: 2)
    |> List.last()
    |> String.split("END CHARMAP", parts: 2)
    |> hd()
    |> String.split("\n")
    |> Enum.flat_map(fn line ->
      case Regex.run(
             ~r/^((?:<U[0-9A-Fa-f]+>\+?)+)\s+((?:\\x[0-9A-Fa-f]{2}\+?)+)(?:\s+\|(\d))?/,
             line,
             capture: :all_but_first
           ) do
        [unicode, encoded, precision] -> [mapping(unicode, encoded, precision)]
        [unicode, encoded] -> [mapping(unicode, encoded, "0")]
        nil -> []
      end
    end)
  end

  defp mapping(unicode, encoded, precision) do
    codepoints =
      Regex.scan(~r/<U([0-9A-Fa-f]+)>/, unicode, capture: :all_but_first)
      |> List.flatten()
      |> Enum.map(&String.to_integer(&1, 16))
      |> List.to_tuple()

    bytes =
      Regex.scan(~r/\\x([0-9A-Fa-f]{2})/, encoded, capture: :all_but_first)
      |> List.flatten()
      |> Enum.map(&String.to_integer(&1, 16))
      |> :binary.list_to_bin()

    {codepoints, bytes, String.to_integer(precision)}
  end

  defp decode_map(mappings) do
    mappings
    |> Enum.filter(fn {_codepoints, _bytes, precision} -> precision in [0, 3] end)
    |> Enum.sort_by(fn {_codepoints, _bytes, precision} -> if precision == 0, do: 0, else: 1 end)
    |> Enum.reduce(%{}, fn {codepoints, bytes, _precision}, result ->
      Map.put_new(result, bytes, codepoints)
    end)
  end

  defp encode_map(mappings) do
    mappings
    |> Enum.filter(fn {codepoints, _bytes, precision} ->
      precision in [0, 4] or (precision == 1 and private_use?(codepoints))
    end)
    |> Enum.sort_by(fn {_codepoints, _bytes, precision} ->
      if precision == 0, do: 0, else: precision
    end)
    |> Enum.reduce(%{}, fn {codepoints, bytes, _precision}, result ->
      Map.put_new(result, codepoints, bytes)
    end)
  end

  defp private_use?(codepoints) do
    codepoints
    |> Tuple.to_list()
    |> Enum.all?(fn codepoint ->
      codepoint in 0xE000..0xF8FF or codepoint in 0xF0000..0xFFFFD or
        codepoint in 0x100000..0x10FFFD
    end)
  end

  defp sha256(binary), do: :crypto.hash(:sha256, binary) |> Base.encode16(case: :lower)
end
