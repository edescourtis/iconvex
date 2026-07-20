defmodule Iconvex.Specs.Tools.ImportICUMultibyte do
  @moduledoc false

  @revision "21d1eb0f306e1141c10931e914dfc038c06121da"
  @release "78.3"
  @aggregate_sha256 "f4c776ca0dadaf0892acaee8fc8aaadfd3b68d0247ec119b49fd1967b0ae64a6"
  @source_url "https://github.com/unicode-org/icu/tree/#{@revision}/icu4c/source/data/mappings"
  @exclusions [
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

  def run do
    root = Path.expand("..", __DIR__)
    committed = Path.join([root, "priv", "sources", "icu-#{@release}-multibyte"])
    source_root = System.get_env("ICU_SOURCE_DIR") || committed
    files = select_sources(source_root)

    assert_source_set!(source_root, files)
    copy_sources(source_root, committed, files)

    aliases = parse_aliases(File.read!(Path.join(committed, "convrtrs.txt")))
    table_dir = Path.join(root, "priv/tables")
    File.mkdir_p!(table_dir)

    encodings =
      files
      |> Enum.with_index(1)
      |> Enum.map(fn {file, index} ->
        import(Path.join(committed, file), table_dir, aliases, index)
      end)

    manifest = %{
      aggregate_sha256: @aggregate_sha256,
      encodings: encodings,
      exclusions: @exclusions,
      format: 1,
      release: @release,
      revision: @revision,
      source_url: @source_url
    }

    File.write!(
      Path.join(root, "priv/icu_multibyte_manifest.etf"),
      :erlang.term_to_binary(manifest, [:deterministic])
    )

    write_support_matrix(root, encodings)
    IO.puts("wrote #{length(encodings)} ICU #{@release} multibyte codecs")
  end

  defp select_sources(source_root) do
    source_root
    |> Path.join("*.ucm")
    |> Path.wildcard()
    |> Enum.filter(fn path ->
      source = File.read!(path)
      uconv_class(source) in ["MBCS", "DBCS"] and Path.basename(path) not in @exclusions
    end)
    |> Enum.map(&Path.basename/1)
    |> Enum.sort()
  end

  defp assert_source_set!(source_root, files) do
    unless length(files) == 30,
      do: Mix.raise("expected 30 standalone multibyte sources, found #{length(files)}")

    paths =
      Enum.map(files, &Path.join(source_root, &1)) ++ [Path.join(source_root, "convrtrs.txt")]

    digest =
      Enum.zip(files ++ ["convrtrs.txt"], paths)
      |> Enum.reduce(:crypto.hash_init(:sha256), fn {file, path}, context ->
        context
        |> :crypto.hash_update(file)
        |> :crypto.hash_update(<<0>>)
        |> :crypto.hash_update(File.read!(path))
      end)
      |> :crypto.hash_final()
      |> Base.encode16(case: :lower)

    unless digest == @aggregate_sha256,
      do: Mix.raise("ICU multibyte source-set SHA-256 mismatch: #{digest}")
  end

  defp copy_sources(source_root, committed, files) do
    if Path.expand(source_root) != Path.expand(committed) do
      File.mkdir_p!(committed)

      Enum.each(files ++ ["convrtrs.txt"], fn file ->
        File.cp!(Path.join(source_root, file), Path.join(committed, file))
      end)
    end
  end

  defp import(path, table_dir, aliases_by_name, index) do
    source = File.read!(path)
    name = header(source, "code_set_name")
    uconv_class = uconv_class(source)
    mappings = parse_mappings(source)
    {decode, encode} = directional_maps(mappings)
    id = String.to_atom("icu_multibyte_#{index}")
    table = build_table(decode, encode)

    File.write!(
      Path.join(table_dir, "#{id}.etf"),
      :erlang.term_to_binary(table, [:deterministic, :compressed])
    )

    ucm_aliases =
      Regex.scan(~r/^<icu:alias>\s+"([^"]+)"/m, source, capture: :all_but_first)
      |> List.flatten()

    aliases =
      Map.get(aliases_by_name, name, [])
      |> Kernel.++(ucm_aliases)
      |> Enum.filter(&registerable_name?/1)
      |> Enum.reject(&(String.downcase(&1) == String.downcase(name)))
      |> Enum.uniq_by(&String.downcase/1)

    %{
      aliases: aliases,
      decode_mappings: map_size(decode),
      encode_mappings: map_size(encode),
      fallback_rows: Enum.count(mappings, fn mapping -> mapping.precision == 1 end),
      id: id,
      index: index,
      mapping_rows: length(mappings),
      max_codepoints: table.max_codepoints,
      max_input: table.max_input,
      name: name,
      reverse_fallback_rows: Enum.count(mappings, fn mapping -> mapping.precision == 3 end),
      sha256: sha256(source),
      source_file: Path.basename(path),
      state_rows: length(Regex.scan(~r/^<icu:state>/m, source)),
      uconv_class: uconv_class
    }
  end

  defp build_table(decode, encode) do
    {one, many} =
      Enum.reduce(decode, {%{}, %{}}, fn {bytes, codepoints}, {one, many} ->
        if byte_size(bytes) == 1,
          do: {Map.put(one, :binary.first(bytes), codepoints), many},
          else: {one, Map.put(many, bytes, codepoints)}
      end)

    prefixes =
      Enum.reduce(many, MapSet.new(), fn {bytes, _codepoints}, result ->
        Enum.reduce(1..(byte_size(bytes) - 1), result, fn size, prefixes ->
          MapSet.put(prefixes, binary_part(bytes, 0, size))
        end)
      end)

    %{
      encode: encode,
      many: many,
      max_codepoints: encode |> Map.keys() |> Enum.map(&tuple_size/1) |> Enum.max(fn -> 1 end),
      max_input: decode |> Map.keys() |> Enum.map(&byte_size/1) |> Enum.max(fn -> 1 end),
      one: 0..255 |> Enum.map(&Map.get(one, &1)) |> List.to_tuple(),
      prefixes: prefixes
    }
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

    %{bytes: bytes, codepoints: codepoints, precision: String.to_integer(precision)}
  end

  defp directional_maps(mappings) do
    decode =
      mappings
      |> Enum.filter(&(&1.precision in [0, 3]))
      |> Enum.sort_by(&precision_priority/1)
      |> Enum.reduce(%{}, fn mapping, result ->
        Map.put_new(result, mapping.bytes, mapping.codepoints)
      end)

    encode =
      mappings
      |> Enum.filter(fn mapping ->
        mapping.precision in [0, 4] or
          (mapping.precision == 1 and private_use?(mapping.codepoints))
      end)
      |> Enum.sort_by(&precision_priority/1)
      |> Enum.reduce(%{}, fn mapping, result ->
        Map.put_new(result, mapping.codepoints, mapping.bytes)
      end)

    {decode, encode}
  end

  defp precision_priority(%{precision: 0}), do: 0
  defp precision_priority(%{precision: 4}), do: 1
  defp precision_priority(%{precision: 3}), do: 1
  defp precision_priority(%{precision: 1}), do: 2

  defp private_use?(codepoints) do
    codepoints
    |> Tuple.to_list()
    |> Enum.all?(fn codepoint ->
      codepoint in 0xE000..0xF8FF or codepoint in 0xF0000..0xFFFFD or
        codepoint in 0x100000..0x10FFFD
    end)
  end

  defp parse_aliases(source) do
    source
    |> logical_lines()
    |> Enum.reduce(%{}, fn line, result ->
      tokens = line |> String.replace(~r/\{[^}]*\}/, "") |> String.split()

      case tokens do
        [name | aliases] -> Map.put(result, name, aliases)
        [] -> result
      end
    end)
  end

  defp logical_lines(source) do
    {lines, current} =
      source
      |> String.split("\n")
      |> Enum.reduce({[], nil}, fn raw_line, {lines, current} ->
        line = raw_line |> String.split("#", parts: 2) |> hd()

        cond do
          String.trim(line) == "" ->
            {lines, current}

          String.match?(line, ~r/^\s/) and current != nil ->
            {lines, current <> " " <> String.trim(line)}

          current == nil ->
            {lines, String.trim(line)}

          true ->
            {[current | lines], String.trim(line)}
        end
      end)

    [current | lines] |> Enum.reject(&is_nil/1) |> Enum.reverse()
  end

  defp write_support_matrix(root, encodings) do
    lines = [
      "# ICU 78.3 multibyte converter revisions",
      "",
      "Generated by `tools/import_icu_multibyte.exs` from Unicode ICU revision",
      "`#{@revision}`. Internal compound components and the separately audited",
      "algorithmic GB18030-2022 converter are excluded.",
      "",
      "| Canonical encoding | Class | Decode mappings | Encode mappings | Max bytes | Source SHA-256 |",
      "|---|---|---:|---:|---:|---|"
    ]

    rows =
      Enum.map(encodings, fn entry ->
        "| `#{entry.name}` | #{entry.uconv_class} | #{entry.decode_mappings} | " <>
          "#{entry.encode_mappings} | #{entry.max_input} | `#{entry.sha256}` |"
      end)

    File.write!(
      Path.join(root, "ICU_MULTIBYTE_ENCODINGS.md"),
      Enum.join(lines ++ rows, "\n") <> "\n"
    )
  end

  defp header(source, key) do
    [value] =
      Regex.run(~r/^<#{Regex.escape(key)}>\s+"([^"]+)"/m, source, capture: :all_but_first)

    value
  end

  defp uconv_class(source), do: header(source, "uconv_class")

  defp registerable_name?(name),
    do: not String.contains?(name, "/") and String.match?(name, ~r/^[\x21-\x7e]+$/)

  defp sha256(binary), do: :crypto.hash(:sha256, binary) |> Base.encode16(case: :lower)
end

Iconvex.Specs.Tools.ImportICUMultibyte.run()
