defmodule Iconvex.Specs.ICUEBCDICStatefulTest do
  use ExUnit.Case, async: false

  alias Iconvex.Specs.ICUEBCDICStateful

  @source_directory Path.expand("../priv/sources/icu-78.3-ebcdic-stateful", __DIR__)
  @revision "21d1eb0f306e1141c10931e914dfc038c06121da"

  test "pins all ICU 78.3 EBCDIC_STATEFUL sources" do
    assert ICUEBCDICStateful.revision() == @revision
    assert length(ICUEBCDICStateful.encodings()) == 10
    assert Enum.all?(ICUEBCDICStateful.encodings(), &(&1.uconv_class == "EBCDIC_STATEFUL"))
  end

  test "verifies every source digest and directional mapping count" do
    for entry <- ICUEBCDICStateful.encodings() do
      source = File.read!(Path.join(@source_directory, entry.source_file))
      mappings = parse_mappings(source)

      assert sha256(source) == entry.sha256
      assert length(mappings) == entry.mapping_rows
      assert map_size(decode_map(mappings)) == entry.decode_mappings
      assert map_size(encode_map(mappings)) == entry.encode_mappings
    end
  end

  @tag timeout: 180_000
  test "executes every source decoder mapping in its proper shift state" do
    for {entry, codec} <- Enum.zip(ICUEBCDICStateful.encodings(), ICUEBCDICStateful.codecs()) do
      source = File.read!(Path.join(@source_directory, entry.source_file))

      for {bytes, codepoints} <- source |> parse_mappings() |> decode_map() do
        input = if byte_size(bytes) == 1, do: bytes, else: <<0x0E, bytes::binary, 0x0F>>
        assert codec.decode(input) == {:ok, Tuple.to_list(codepoints)}
      end
    end
  end

  @tag timeout: 180_000
  test "executes every canonical encoder mapping with canonical SI/SO framing" do
    for {entry, codec} <- Enum.zip(ICUEBCDICStateful.encodings(), ICUEBCDICStateful.codecs()) do
      source = File.read!(Path.join(@source_directory, entry.source_file))

      for {codepoints, bytes} <- source |> parse_mappings() |> encode_map() do
        expected = if byte_size(bytes) == 1, do: bytes, else: <<0x0E, bytes::binary, 0x0F>>
        assert codec.encode(Tuple.to_list(codepoints)) == {:ok, expected}
      end
    end
  end

  test "maintains stream shift state, closes DBCS output, and rejects an incomplete pair" do
    entry = Enum.find(ICUEBCDICStateful.encodings(), &(&1.name == "ibm-930_P120-1999"))
    codec = Enum.at(ICUEBCDICStateful.codecs(), entry.index - 1)

    assert codec.encode(~c"AあいB") == {:ok, <<0xC1, 0x0E, 0x44, 0x81, 0x44, 0x82, 0x0F, 0xC2>>}
    assert codec.decode(<<0xC1, 0x0E, 0x44, 0x81, 0x44, 0x82, 0x0F, 0xC2>>) == {:ok, ~c"AあいB"}
    assert codec.encode(~c"あ") == {:ok, <<0x0E, 0x44, 0x81, 0x0F>>}
    assert codec.decode(<<0x0E, 0x44>>) == {:error, :incomplete_sequence, 1, <<0x44>>}
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
