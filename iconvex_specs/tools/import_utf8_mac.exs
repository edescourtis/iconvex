defmodule Iconvex.Specs.Tools.ImportUTF8Mac do
  @moduledoc false

  @files [
    "CompositionExclusions-3.2.0.txt",
    "NormalizationTest-3.2.0.txt",
    "UnicodeData-3.2.0.txt",
    "citrus_utf8mac.c",
    "libiconv_test.c",
    "tn1150table.html"
  ]

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

  @aggregate_sha256 "7601e4829c3adc8f818a3172284c4e305264e72e4ce9f1376e810d6f48dd6817"
  @apple_revision "f96c1fcdbb308374e39290676b5fea40a3859d17"
  @apple_release "libiconv-115.100.1"

  @urls %{
    "CompositionExclusions-3.2.0.txt" =>
      "https://www.unicode.org/Public/3.2-Update/CompositionExclusions-3.2.0.txt",
    "NormalizationTest-3.2.0.txt" =>
      "https://www.unicode.org/Public/3.2-Update/NormalizationTest-3.2.0.txt",
    "UnicodeData-3.2.0.txt" => "https://www.unicode.org/Public/3.2-Update/UnicodeData-3.2.0.txt",
    "citrus_utf8mac.c" =>
      "https://github.com/apple-oss-distributions/libiconv/blob/f96c1fcdbb308374e39290676b5fea40a3859d17/libiconv_modules/UTF8MAC/citrus_utf8mac.c",
    "libiconv_test.c" =>
      "https://github.com/apple-oss-distributions/libiconv/blob/f96c1fcdbb308374e39290676b5fea40a3859d17/tests/libiconv/libiconv_test.c",
    "tn1150table.html" =>
      "https://developer.apple.com/library/archive/technotes/tn/tn1150table.html"
  }

  def run do
    root = Path.expand("..", __DIR__)
    committed = Path.join([root, "priv", "sources", "utf8-mac"])
    source_root = System.get_env("UTF8_MAC_SOURCE_DIR") || committed

    assert_sources!(source_root)
    copy_sources(source_root, committed)

    historic_apple = parse_apple(Path.join(committed, "tn1150table.html"))
    implementation_keys = parse_implementation_keys(Path.join(committed, "citrus_utf8mac.c"))
    {ccc, direct} = parse_unicode_data(Path.join(committed, "UnicodeData-3.2.0.txt"))

    exclusions =
      parse_exclusions(Path.join(committed, "CompositionExclusions-3.2.0.txt"))

    decompose = implementation_decompositions(implementation_keys, direct)
    standard_compositions = composition_pairs(decompose, direct, exclusions)

    compositions =
      parse_implementation_compositions(Path.join(committed, "citrus_utf8mac.c"))

    standard_only =
      standard_compositions
      |> MapSet.new()
      |> MapSet.difference(MapSet.new(compositions))

    implementation_only =
      compositions
      |> MapSet.new()
      |> MapSet.difference(MapSet.new(standard_compositions))

    additions = MapSet.difference(implementation_keys, MapSet.new(Map.keys(historic_apple)))
    removals = MapSet.difference(MapSet.new(Map.keys(historic_apple)), implementation_keys)

    manifest = %{
      aggregate_sha256: @aggregate_sha256,
      apple_release: @apple_release,
      apple_revision: @apple_revision,
      combining_classes: map_size(ccc),
      composition_exclusions: MapSet.size(exclusions),
      composition_pairs: map_size(compositions),
      composition_pairs_implementation_only: MapSet.size(implementation_only),
      composition_pairs_standard_only: MapSet.size(standard_only),
      compose: compositions,
      decompose: decompose,
      format: 1,
      historic_table_rows: map_size(historic_apple),
      implementation_additions: additions |> MapSet.to_list() |> Enum.sort(),
      implementation_removals: removals |> MapSet.to_list() |> Enum.sort(),
      implementation_rows: map_size(decompose),
      source_hashes: @hashes,
      source_urls: @urls,
      unicode_version: "3.2.0"
    }

    File.write!(
      Path.join(root, "priv/utf8_mac_manifest.etf"),
      :erlang.term_to_binary(manifest, [:deterministic, :compressed])
    )

    write_document(root, manifest)

    IO.puts(
      "wrote UTF-8-MAC: #{manifest.implementation_rows} Apple implementation rows, " <>
        "#{manifest.composition_pairs} composition pairs, " <>
        "#{manifest.combining_classes} nonzero combining classes"
    )
  end

  defp assert_sources!(source_root) do
    Enum.each(@files, fn file ->
      path = Path.join(source_root, file)

      unless File.regular?(path), do: Mix.raise("missing UTF-8-MAC source #{path}")

      actual = path |> File.read!() |> sha256()
      expected = Map.fetch!(@hashes, file)

      unless actual == expected,
        do: Mix.raise("UTF-8-MAC source SHA-256 mismatch for #{file}: #{actual}")
    end)

    aggregate =
      Enum.reduce(@files, :crypto.hash_init(:sha256), fn file, context ->
        context
        |> :crypto.hash_update(file)
        |> :crypto.hash_update(<<0>>)
        |> :crypto.hash_update(File.read!(Path.join(source_root, file)))
      end)
      |> :crypto.hash_final()
      |> Base.encode16(case: :lower)

    unless aggregate == @aggregate_sha256,
      do: Mix.raise("UTF-8-MAC aggregate SHA-256 mismatch: #{aggregate}")
  end

  defp copy_sources(source_root, committed) do
    if Path.expand(source_root) != Path.expand(committed) do
      File.mkdir_p!(committed)

      Enum.each(@files, fn file ->
        File.cp!(Path.join(source_root, file), Path.join(committed, file))
      end)
    end
  end

  defp parse_apple(path) do
    values =
      Regex.scan(
        ~r/<P>\s*(0x[0-9A-Fa-f]+(?:\s+0x[0-9A-Fa-f]+)*)\s*<\/p>/i,
        File.read!(path),
        capture: :all_but_first
      )
      |> List.flatten()

    unless rem(length(values), 2) == 0,
      do: Mix.raise("odd number of cells in Apple's decomposition table")

    result =
      values
      |> Enum.chunk_every(2)
      |> Map.new(fn [illegal, replacement] ->
        [source] = parse_hex_sequence(illegal)
        {source, parse_hex_sequence(replacement)}
      end)

    unless map_size(result) == 942,
      do: Mix.raise("expected 942 Apple decomposition rows, got #{map_size(result)}")

    result
  end

  defp parse_implementation_keys(path) do
    body =
      path
      |> File.read!()
      |> String.split("__CFUniCharDecompositionTable[] = {", parts: 2)
      |> List.last()
      |> String.split("};", parts: 2)
      |> hd()

    values =
      Regex.scan(~r/0x([0-9A-Fa-f]+)/, body, capture: :all_but_first)
      |> List.flatten()
      |> Enum.map(&String.to_integer(&1, 16))

    unless rem(length(values), 2) == 0,
      do: Mix.raise("odd Apple implementation decomposition-table cell count")

    keys = values |> Enum.take_every(2) |> MapSet.new()

    unless MapSet.size(keys) == 970,
      do: Mix.raise("expected 970 Apple implementation decomposition keys")

    keys
  end

  defp parse_implementation_compositions(path) do
    source = File.read!(path)

    source_table =
      parse_c_array(source, "__CFUniCharPrecompSourceTable[] = {")

    destination_table =
      parse_c_array(source, "__CFUniCharBMPPrecompDestinationTable[] = {")

    unless rem(length(source_table), 2) == 0,
      do: Mix.raise("odd Apple precomposition source-table cell count")

    source_table
    |> Enum.chunk_every(2)
    |> Enum.reduce(%{}, fn [combining, descriptor], result ->
      count = div(descriptor, 0x10000)
      # The low half is an offset in u_int32_t units. The destination table is
      # declared as u_int16_t, hence two 16-bit cells per offset unit.
      offset = rem(descriptor, 0x10000) * 2

      entries =
        destination_table
        |> Enum.slice(offset, count * 2)
        |> Enum.chunk_every(2)

      unless length(entries) == count,
        do: Mix.raise("truncated Apple precomposition destination table")

      Enum.reduce(entries, result, fn [base, composite], acc ->
        key = {base, combining}

        if Map.has_key?(acc, key),
          do: Mix.raise("duplicate Apple composition pair for U+#{hex(composite)}")

        Map.put(acc, key, composite)
      end)
    end)
  end

  defp parse_c_array(source, marker) do
    body =
      source
      |> String.split(marker, parts: 2)
      |> case do
        [_prefix, rest] -> rest
        _ -> Mix.raise("missing Apple C array #{marker}")
      end
      |> String.split("};", parts: 2)
      |> hd()

    body
    |> then(&Regex.scan(~r/0x([0-9A-Fa-f]+)/, &1, capture: :all_but_first))
    |> List.flatten()
    |> Enum.map(&String.to_integer(&1, 16))
  end

  defp parse_unicode_data(path) do
    path
    |> File.stream!()
    |> Enum.reduce({%{}, %{}}, fn line, {ccc, direct} ->
      fields = String.split(String.trim(line), ";")
      codepoint = fields |> Enum.at(0) |> String.to_integer(16)
      combining_class = fields |> Enum.at(3) |> String.to_integer()
      decomposition = Enum.at(fields, 5)

      ccc = if combining_class == 0, do: ccc, else: Map.put(ccc, codepoint, combining_class)

      direct =
        if decomposition != "" and not String.starts_with?(decomposition, "<") do
          Map.put(direct, codepoint, parse_hex_sequence(decomposition))
        else
          direct
        end

      {ccc, direct}
    end)
  end

  defp parse_exclusions(path) do
    path
    |> File.stream!()
    |> Enum.reduce(MapSet.new(), fn line, result ->
      case Regex.run(~r/^\s*([0-9A-Fa-f]{4,6})\s*(?:#.*)?$/, line, capture: :all_but_first) do
        [hex] -> MapSet.put(result, String.to_integer(hex, 16))
        nil -> result
      end
    end)
  end

  defp implementation_decompositions(keys, direct) do
    Map.new(keys, fn codepoint ->
      unless Map.has_key?(direct, codepoint),
        do: Mix.raise("Apple implementation key U+#{hex(codepoint)} lacks Unicode 3.2 data")

      {codepoint, recursive_decompose(codepoint, direct, MapSet.new())}
    end)
  end

  defp recursive_decompose(codepoint, direct, seen) do
    if MapSet.member?(seen, codepoint), do: Mix.raise("cyclic Unicode decomposition")

    case direct do
      %{^codepoint => children} ->
        seen = MapSet.put(seen, codepoint)
        Enum.flat_map(children, &recursive_decompose(&1, direct, seen))

      _ ->
        [codepoint]
    end
  end

  defp composition_pairs(decompose, direct, exclusions) do
    decompose
    |> Enum.reduce(%{}, fn {composed, _flat}, result ->
      case direct do
        %{^composed => [starter, combining]} ->
          cond do
            MapSet.member?(exclusions, composed) ->
              result

            Map.has_key?(result, {starter, combining}) ->
              Mix.raise("duplicate composition pair for U+#{hex(composed)}")

            true ->
              Map.put(result, {starter, combining}, composed)
          end

        _ ->
          result
      end
    end)
  end

  defp write_document(root, manifest) do
    sources =
      @files
      |> Enum.map(fn file ->
        "| `#{file}` | [official source](#{Map.fetch!(@urls, file)}) | `#{Map.fetch!(@hashes, file)}` |"
      end)
      |> Enum.join("\n")

    File.write!(
      Path.join(root, "UTF8_MAC.md"),
      """
      # UTF-8-MAC / HFS Plus normalization codec

      This codec implements Apple's frozen HFS Plus canonical decomposition,
      using the exact tables in Apple libiconv #{@apple_release} at commit
      `#{@apple_revision}` and Unicode 3.2 normalization data. Characters
      absent from Apple's implementation table remain unchanged; Hangul
      syllables are handled by the normative algorithm. Like Apple's module,
      decoding greedily precomposes adjacent supported pairs and retains
      Unicode composition exclusions.

      - Current Apple implementation decomposition rows: **#{manifest.implementation_rows}**
      - Historical TN1150 HTML rows: **#{manifest.historic_table_rows}**
      - Unicode 3.2 additions over that historical table: **#{length(manifest.implementation_additions)}**
      - Unicode 3.2 removals from that historical table: **#{length(manifest.implementation_removals)}**
      - Algorithmic Hangul syllables: **11,172**
      - Exact Apple implementation composition pairs: **#{manifest.composition_pairs}**
      - Apple-only versus Unicode-derived reverse pairs: **#{manifest.composition_pairs_implementation_only}**
      - Unicode-derived-only versus Apple table: **#{manifest.composition_pairs_standard_only}**
      - Nonzero combining-class entries: **#{manifest.combining_classes}**
      - Unicode composition exclusions: **#{manifest.composition_exclusions}**
      - Source-set SHA-256: `#{manifest.aggregate_sha256}`

      The upstream files below remain repository-only. The generated Hex runtime
      manifest contains decomposition keys and exact precomposition pairs parsed
      from the BSD-2-Clause C tables plus Unicode 3.2 data; the complete attribution
      ships as `LICENSE.BSD-2-CLAUSE`.

      | Pinned source | Origin | SHA-256 |
      |---|---|---|
      #{sources}
      """
    )
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

  defp sha256(binary), do: :crypto.hash(:sha256, binary) |> Base.encode16(case: :lower)
  defp hex(codepoint), do: codepoint |> Integer.to_string(16) |> String.upcase()
end

Iconvex.Specs.Tools.ImportUTF8Mac.run()
