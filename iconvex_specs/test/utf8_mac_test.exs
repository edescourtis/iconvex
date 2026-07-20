defmodule Iconvex.Specs.UTF8MacTest do
  use ExUnit.Case, async: false

  alias Iconvex.Specs.UTF8Mac

  @source_dir Path.expand("../priv/sources/utf8-mac", __DIR__)
  @apple_table Path.join(@source_dir, "tn1150table.html")
  @apple_implementation Path.join(@source_dir, "citrus_utf8mac.c")
  @unicode_data Path.join(@source_dir, "UnicodeData-3.2.0.txt")
  @normalization_test Path.join(@source_dir, "NormalizationTest-3.2.0.txt")

  @hashes %{
    "CompositionExclusions-3.2.0.txt" =>
      "1d3a450d0f39902710df4972ac4a60ec31fbcb54ffd4d53cd812fc1200c732cb",
    "NormalizationTest-3.2.0.txt" =>
      "c4513869bb7098d19838be4a1fd5d760843c5804bfe03bd6bbb20623ceb6e57d",
    "UnicodeData-3.2.0.txt" => "5e444028b6e76d96f9dc509609c5e3222bf609056f35e5fcde7e6fb8a58cd446",
    "citrus_utf8mac.c" => "2a018de7f0ce2b641bfae97ff4c2c8cf5e12789239d7d77b3f11ec63e224936d",
    "libiconv_test.c" => "67f8a968f8c17dbef0338aa7c3e909139dbc8bb5187a24b62552a0b4067cb1c6",
    "tn1150table.html" => "67c7f9572752693800df3cd79974b59374e36b2240bc7f31a14192efa57a5e03"
  }

  test "registers Apple's HFS Plus UTF-8 normalization convention" do
    for name <- ["UTF-8-MAC", "UTF8-MAC", "UTF-8-HFS", "UTF8-HFS"] do
      assert Iconvex.canonical_name(name) == {:ok, "UTF-8-MAC"}
    end
  end

  test "pins every normative Apple and Unicode 3.2 source byte-for-byte" do
    assert UTF8Mac.source_hashes() == @hashes

    for {file, expected} <- @hashes do
      actual =
        @source_dir
        |> Path.join(file)
        |> File.read!()
        |> then(&:crypto.hash(:sha256, &1))
        |> Base.encode16(case: :lower)

      assert actual == expected
    end
  end

  test "ports every current Apple decomposition row at the mandated Unicode revision" do
    historic = apple_rows()
    keys = implementation_keys()
    direct = canonical_decompositions()
    rows = Map.new(keys, &{&1, recursively_decompose(&1, direct)})

    assert map_size(historic) == 942
    assert MapSet.size(keys) == 970
    assert MapSet.size(MapSet.difference(keys, MapSet.new(Map.keys(historic)))) == 44
    assert MapSet.size(MapSet.difference(MapSet.new(Map.keys(historic)), keys)) == 16
    assert UTF8Mac.decomposition_table() == rows

    for {illegal, replacement} <- rows do
      expected = utf8(replacement)
      assert UTF8Mac.encode([illegal]) == {:ok, expected}
    end
  end

  test "honours HFS Plus exclusions, ordering, and Unicode composition exclusions" do
    assert UTF8Mac.encode([0x00E9]) == {:ok, <<?e, 0xCC, 0x81>>}
    assert UTF8Mac.decode(<<?e, 0xCC, 0x81>>) == {:ok, [0x00E9]}

    # U+0958 is canonically decomposed but excluded from canonical composition.
    assert UTF8Mac.encode([0x0958]) == {:ok, <<0xE0, 0xA4, 0x95, 0xE0, 0xA4, 0xBC>>}
    assert UTF8Mac.decode(<<0xE0, 0xA4, 0x95, 0xE0, 0xA4, 0xBC>>) == {:ok, [0x0915, 0x093C]}

    # HFS Plus deliberately leaves these compatibility ranges unchanged.
    for codepoint <- [0x2126, 0xF900] do
      bytes = <<codepoint::utf8>>
      assert UTF8Mac.encode([codepoint]) == {:ok, bytes}
      assert UTF8Mac.decode(bytes) == {:ok, [codepoint]}
    end

    # Apple's converter decomposes characters but does not reorder an already
    # decomposed input sequence.
    assert UTF8Mac.encode([?A, 0x0315, 0x0300]) ==
             {:ok, <<?A, 0xCC, 0x95, 0xCC, 0x80>>}

    assert UTF8Mac.encode([0x2F800]) ==
             {:error, :unrepresentable_character, 0x2F800}
  end

  @tag timeout: 120_000
  test "algorithmically decomposes and recomposes every Hangul syllable" do
    syllables = Enum.to_list(0xAC00..0xD7A3)
    assert {:ok, decomposed} = UTF8Mac.encode(syllables)
    assert UTF8Mac.decode(decomposed) == {:ok, syllables}

    assert UTF8Mac.encode([0xAC00, 0xAC01, 0xD7A3]) ==
             {:ok,
              :unicode.characters_to_binary(
                [0x1100, 0x1161, 0x1100, 0x1161, 0x11A8, 0x1112, 0x1175, 0x11C2],
                :unicode,
                :utf8
              )}
  end

  @tag timeout: 120_000
  test "classifies every Unicode scalar value without lossy truncation" do
    encodable =
      Enum.to_list(0..0xD7FF) ++
        Enum.to_list(0xE000..0xFEFE) ++ Enum.to_list(0xFF00..0xFFFD) ++ [0xFFFF]

    round_trippable = List.delete(encodable, 0xFFFF)
    supplementary = Enum.to_list(0x10000..0x10FFFF)
    scalars = Enum.to_list(0..0xD7FF) ++ Enum.to_list(0xE000..0x10FFFF)

    assert {:ok, encoded} = UTF8Mac.encode(round_trippable)
    assert String.valid?(encoded)
    assert {:ok, decoded} = UTF8Mac.decode(encoded)
    assert UTF8Mac.encode(decoded) == {:ok, encoded}

    assert UTF8Mac.encode_discard(scalars) == UTF8Mac.encode(encodable)
    assert UTF8Mac.encode_discard(supplementary) == {:ok, <<>>}

    supplementary_utf8 = utf8(supplementary)
    assert UTF8Mac.decode_discard(supplementary_utf8) == {:ok, []}

    assert UTF8Mac.encode([0x10000]) ==
             {:error, :unrepresentable_character, 0x10000}

    assert UTF8Mac.decode(<<0x10000::utf8>>) ==
             {:error, :invalid_sequence, 0, <<0x10000::utf8>>}
  end

  @tag timeout: 120_000
  test "matches Apple's installed iconv over the complete supported BMP domain" do
    {names, 0} = System.cmd("iconv", ["-l"])

    if String.contains?(String.upcase(names), "UTF-8-MAC") do
      encodable =
        Enum.to_list(0..0xD7FF) ++
          Enum.to_list(0xE000..0xFEFE) ++ Enum.to_list(0xFF00..0xFFFD) ++ [0xFFFF]

      round_trippable = List.delete(encodable, 0xFFFF)

      assert {apple_encoded, 0} = system_iconv(utf8(encodable), "UTF-8", "UTF-8-MAC")

      assert UTF8Mac.encode(encodable) == {:ok, apple_encoded}
      {:ok, ours_decomposed} = UTF8Mac.encode(round_trippable)

      assert {apple_composed, 0} = system_iconv(ours_decomposed, "UTF-8-MAC", "UTF-8")

      assert UTF8Mac.decode_to_utf8(ours_decomposed) == {:ok, apple_composed}
    end
  end

  @tag timeout: 120_000
  test "passes every applicable Unicode 3.2 normalization conformance row" do
    rows = normalization_rows()
    assert length(rows) == 16_992

    keys = implementation_keys()
    direct = canonical_decompositions()
    effective = Map.new(keys, &{&1, recursively_decompose(&1, direct)})

    applicable =
      Enum.filter(rows, fn [c1, c2, c3, _c4, _c5] ->
        reference_decompose(c1, effective) == c3 and
          reference_decompose(c2, effective) == c3 and
          Enum.all?(c1 ++ c2 ++ c3, &(&1 <= 0xFFFF and &1 not in [0xFEFF, 0xFFFE, 0xFFFF]))
      end)

    assert length(applicable) == 14_381

    for [c1, c2, c3, _c4, _c5] <- applicable do
      assert UTF8Mac.encode(c1) == {:ok, utf8(c3)}
      assert UTF8Mac.decode(utf8(c3)) == {:ok, c2}
    end
  end

  test "preserves strict UTF-8 error boundaries" do
    assert UTF8Mac.decode(<<?A, 0xC2>>) ==
             {:error, :incomplete_sequence, 1, <<0xC2>>}

    assert match?({:error, :invalid_sequence, 1, _}, UTF8Mac.decode(<<?A, 0xC0, 0x80>>))

    for codepoint <- [0xFFFE, 0xFFFF] do
      assert UTF8Mac.decode(<<?A, codepoint::utf8>>) ==
               {:error, :invalid_sequence, 1, <<codepoint::utf8>>}
    end
  end

  defp apple_rows do
    values =
      Regex.scan(
        ~r/<P>\s*(0x[0-9A-Fa-f]+(?:\s+0x[0-9A-Fa-f]+)*)\s*<\/p>/i,
        File.read!(@apple_table),
        capture: :all_but_first
      )
      |> List.flatten()

    values
    |> Enum.chunk_every(2)
    |> Map.new(fn [illegal, replacement] ->
      [source] = parse_hex_sequence(illegal)
      {source, parse_hex_sequence(replacement)}
    end)
  end

  defp normalization_rows do
    @normalization_test
    |> File.stream!()
    |> Enum.flat_map(fn line ->
      line = line |> String.split("#", parts: 2) |> hd() |> String.trim()

      if line == "" or String.starts_with?(line, "@") do
        []
      else
        [line |> String.split(";") |> Enum.take(5) |> Enum.map(&parse_hex_sequence/1)]
      end
    end)
  end

  defp implementation_keys do
    body =
      @apple_implementation
      |> File.read!()
      |> String.split("__CFUniCharDecompositionTable[] = {", parts: 2)
      |> List.last()
      |> String.split("};", parts: 2)
      |> hd()

    body
    |> then(&Regex.scan(~r/0x([0-9A-Fa-f]+)/, &1, capture: :all_but_first))
    |> List.flatten()
    |> Enum.map(&String.to_integer(&1, 16))
    |> Enum.take_every(2)
    |> MapSet.new()
  end

  defp canonical_decompositions do
    @unicode_data
    |> File.stream!()
    |> Enum.reduce(%{}, fn line, result ->
      fields = String.split(String.trim(line), ";")
      decomposition = Enum.at(fields, 5)

      if decomposition != "" and not String.starts_with?(decomposition, "<") do
        Map.put(
          result,
          String.to_integer(Enum.at(fields, 0), 16),
          parse_hex_sequence(decomposition)
        )
      else
        result
      end
    end)
  end

  defp reference_decompose(codepoints, apple) do
    codepoints
    |> Enum.flat_map(fn codepoint ->
      cond do
        Map.has_key?(apple, codepoint) -> Map.fetch!(apple, codepoint)
        codepoint in 0xAC00..0xD7A3 -> decompose_hangul(codepoint)
        true -> [codepoint]
      end
    end)
  end

  defp recursively_decompose(codepoint, direct) do
    case direct do
      %{^codepoint => children} -> Enum.flat_map(children, &recursively_decompose(&1, direct))
      _ -> [codepoint]
    end
  end

  defp decompose_hangul(syllable) do
    index = syllable - 0xAC00
    leading = 0x1100 + div(index, 588)
    vowel = 0x1161 + div(rem(index, 588), 28)

    case rem(index, 28) do
      0 -> [leading, vowel]
      trailing -> [leading, vowel, 0x11A7 + trailing]
    end
  end

  defp parse_hex_sequence(value) do
    value
    |> String.trim()
    |> String.split(~r/\s+/, trim: true)
    |> Enum.map(fn token ->
      token = String.replace_prefix(token, "0x", "")
      String.to_integer(token, 16)
    end)
  end

  defp utf8(codepoints), do: :unicode.characters_to_binary(codepoints, :unicode, :utf8)

  defp system_iconv(input, from, to) do
    path =
      Path.join(
        System.tmp_dir!(),
        "iconvex-utf8-mac-#{System.unique_integer([:positive, :monotonic])}.bin"
      )

    try do
      File.write!(path, input)
      System.cmd("iconv", ["-f", from, "-t", to, path], stderr_to_stdout: true)
    after
      File.rm(path)
    end
  end
end
