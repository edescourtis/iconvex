defmodule Iconvex.Specs.ICUSBCSTest do
  use ExUnit.Case, async: false

  alias Iconvex.Specs.ICUUCM

  @source_directory Path.expand("../priv/sources/icu-78.3", __DIR__)
  @revision "21d1eb0f306e1141c10931e914dfc038c06121da"

  test "pins every standalone ICU 78.3 SBCS mapping source" do
    assert ICUUCM.revision() == @revision
    assert length(ICUUCM.encodings()) == 135
    assert Enum.all?(ICUUCM.encodings(), &(&1.uconv_class == "SBCS"))
    assert Enum.uniq_by(ICUUCM.encodings(), &String.downcase(&1.name)) == ICUUCM.encodings()

    refute Enum.any?(ICUUCM.encodings(), fn entry ->
             String.starts_with?(entry.source_file, "icu-internal-") or
               entry.source_file == "gsm-03.38-2009.ucm"
           end)
  end

  test "verifies every committed source digest and generated mapping count" do
    for entry <- ICUUCM.encodings() do
      source = File.read!(Path.join(@source_directory, entry.source_file))
      assert sha256(source) == entry.sha256

      mappings = parse_mappings(source)
      assert entry.mapping_rows == length(mappings)
      assert entry.decode_mappings == map_size(decode_map(mappings))
      assert entry.encode_mappings == map_size(encode_map(mappings))
    end
  end

  test "exhaustively decodes all 256 values according to UCM precision flags" do
    for {entry, codec} <- Enum.zip(ICUUCM.encodings(), ICUUCM.codecs()) do
      source = File.read!(Path.join(@source_directory, entry.source_file))
      expected = source |> parse_mappings() |> decode_map()

      for byte <- 0..255 do
        case expected do
          %{^byte => codepoints} -> assert codec.decode(<<byte>>) == {:ok, codepoints}
          _ -> assert codec.decode(<<byte>>) == {:error, :invalid_sequence, 0, <<byte>>}
        end
      end
    end
  end

  test "exhaustively encodes every canonical UCM roundtrip and good one-way row" do
    for {entry, codec} <- Enum.zip(ICUUCM.encodings(), ICUUCM.codecs()) do
      source = File.read!(Path.join(@source_directory, entry.source_file))

      for {codepoints, byte} <- source |> parse_mappings() |> encode_map() do
        assert codec.encode(Tuple.to_list(codepoints)) == {:ok, <<byte>>}
      end
    end
  end

  test "registers exact ICU revision names and their non-conflicting aliases" do
    entry = Enum.find(ICUUCM.encodings(), &(&1.name == "ibm-803_P100-1999"))
    assert entry
    assert Iconvex.canonical_name(entry.name) == {:ok, entry.name}

    Enum.each(entry.aliases, fn alias_name ->
      assert match?({:ok, _}, Iconvex.canonical_name(alias_name))
    end)
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

    [byte] =
      Regex.scan(~r/\\x([0-9A-Fa-f]{2})/, encoded, capture: :all_but_first)
      |> List.flatten()
      |> Enum.map(&String.to_integer(&1, 16))

    {codepoints, byte, String.to_integer(precision)}
  end

  defp decode_map(mappings) do
    mappings
    |> Enum.filter(fn {_codepoints, _byte, precision} -> precision in [0, 3] end)
    |> Enum.sort_by(fn {_codepoints, _byte, precision} -> if precision == 0, do: 0, else: 1 end)
    |> Enum.reduce(%{}, fn {codepoints, byte, _precision}, result ->
      Map.put_new(result, byte, Tuple.to_list(codepoints))
    end)
  end

  defp encode_map(mappings) do
    mappings
    |> Enum.filter(fn {codepoints, _byte, precision} ->
      precision in [0, 4] or (precision == 1 and private_use?(codepoints))
    end)
    |> Enum.sort_by(fn {_codepoints, _byte, precision} ->
      case precision do
        0 -> 0
        4 -> 1
        1 -> 2
      end
    end)
    |> Enum.reduce(%{}, fn {codepoints, byte, _precision}, result ->
      Map.put_new(result, codepoints, byte)
    end)
  end

  defp private_use?(codepoints) do
    Tuple.to_list(codepoints)
    |> Enum.all?(fn codepoint ->
      codepoint in 0xE000..0xF8FF or codepoint in 0xF0000..0xFFFFD or
        codepoint in 0x100000..0x10FFFD
    end)
  end

  defp sha256(binary), do: :crypto.hash(:sha256, binary) |> Base.encode16(case: :lower)
end
