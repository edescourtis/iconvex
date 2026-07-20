defmodule Iconvex.Specs.Tools.ImportUnicodeMappingComponents do
  @moduledoc false

  @aggregate_sha256 "f47ff713ec66d48328892ff13b1521f049f620c37fd973de36c697dfba0dfa53"
  @source_files ["HANGUL.TXT", "IBMGRAPH.TXT"]
  @specs [
    %{
      file: "HANGUL.TXT",
      name: "HANGUL-WANSUNG-COMPONENT",
      aliases: ["UNICODE-HANGUL-WANSUNG"],
      parser: {:hangul, 1},
      url: "https://www.unicode.org/Public/MAPPINGS/OBSOLETE/EASTASIA/KSC/HANGUL.TXT"
    },
    %{
      file: "HANGUL.TXT",
      name: "HANGUL-UHANGUL",
      aliases: ["HANGUL", "UHANGUL", "UNICODE-HANGUL-UNIFIED"],
      parser: {:hangul, 2},
      url: "https://www.unicode.org/Public/MAPPINGS/OBSOLETE/EASTASIA/KSC/HANGUL.TXT"
    },
    %{
      file: "HANGUL.TXT",
      name: "HANGUL-JOHAB-COMPONENT",
      aliases: ["UNICODE-HANGUL-JOHAB"],
      parser: {:hangul, 3},
      url: "https://www.unicode.org/Public/MAPPINGS/OBSOLETE/EASTASIA/KSC/HANGUL.TXT"
    },
    %{
      file: "IBMGRAPH.TXT",
      name: "IBMGRAPH",
      aliases: ["IBM-PC-VIDEO-GRAPHICS"],
      parser: {:ibmgraph, 1},
      url: "https://www.unicode.org/Public/MAPPINGS/VENDORS/MISC/IBMGRAPH.TXT"
    },
    %{
      file: "IBMGRAPH.TXT",
      name: "IBMGRAPH-CP864",
      aliases: ["IBM-PC-VIDEO-GRAPHICS-CP864"],
      parser: {:ibmgraph, 2},
      url: "https://www.unicode.org/Public/MAPPINGS/VENDORS/MISC/IBMGRAPH.TXT"
    }
  ]

  def run do
    root = Path.expand("..", __DIR__)
    committed = Path.join([root, "priv", "sources", "unicode-mapping-components"])
    source_root = System.get_env("UNICODE_MAPPING_COMPONENT_SOURCE_DIR") || committed
    assert_source_set!(source_root)
    copy_sources(source_root, committed)
    table_dir = Path.join(root, "priv/tables")
    File.mkdir_p!(table_dir)

    encodings =
      @specs
      |> Enum.with_index(1)
      |> Enum.map(fn {spec, index} -> import(spec, index, committed, table_dir) end)

    manifest = %{aggregate_sha256: @aggregate_sha256, encodings: encodings, format: 1}

    File.write!(
      Path.join(root, "priv/unicode_mapping_components_manifest.etf"),
      :erlang.term_to_binary(manifest, [:deterministic, :compressed])
    )

    write_support_matrix(root, encodings)
    IO.puts("wrote #{length(encodings)} Unicode mapping-table component codecs")
  end

  defp assert_source_set!(source_root) do
    digest =
      Enum.reduce(@source_files, :crypto.hash_init(:sha256), fn file, context ->
        context
        |> :crypto.hash_update(file)
        |> :crypto.hash_update(<<0>>)
        |> :crypto.hash_update(File.read!(Path.join(source_root, file)))
      end)
      |> :crypto.hash_final()
      |> Base.encode16(case: :lower)

    unless digest == @aggregate_sha256,
      do: Mix.raise("Unicode component source-set SHA-256 mismatch: #{digest}")
  end

  defp copy_sources(source_root, committed) do
    if Path.expand(source_root) != Path.expand(committed) do
      File.mkdir_p!(committed)

      Enum.each(@source_files, fn file ->
        File.cp!(Path.join(source_root, file), Path.join(committed, file))
      end)
    end
  end

  defp import(spec, index, committed, table_dir) do
    source = File.read!(Path.join(committed, spec.file))
    rows = parse_mappings(source, spec.parser)
    decode = Enum.reduce(rows, %{}, fn {bytes, cp}, map -> Map.put_new(map, bytes, {cp}) end)
    encode = Enum.reduce(rows, %{}, fn {bytes, cp}, map -> Map.put_new(map, {cp}, bytes) end)
    id = String.to_atom("unicode_mapping_component_#{index}")
    table = build_table(decode, encode)

    File.write!(
      Path.join(table_dir, "#{id}.etf"),
      :erlang.term_to_binary(table, [:deterministic, :compressed])
    )

    %{
      aliases: spec.aliases,
      decode_mappings: map_size(decode),
      encode_mappings: map_size(encode),
      id: id,
      index: index,
      mapping_rows: length(rows),
      max_input: table.max_input,
      name: spec.name,
      parser: spec.parser,
      sha256: sha256(source),
      source_file: spec.file,
      source_url: spec.url
    }
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

  defp build_table(decode, encode) do
    {one, many} =
      Enum.reduce(decode, {%{}, %{}}, fn {bytes, cps}, {one, many} ->
        if byte_size(bytes) == 1,
          do: {Map.put(one, :binary.first(bytes), cps), many},
          else: {one, Map.put(many, bytes, cps)}
      end)

    prefixes =
      Enum.reduce(many, MapSet.new(), fn {bytes, _cps}, result ->
        Enum.reduce(1..(byte_size(bytes) - 1), result, fn size, prefixes ->
          MapSet.put(prefixes, binary_part(bytes, 0, size))
        end)
      end)

    %{
      encode: encode,
      many: many,
      max_codepoints: 1,
      max_input: decode |> Map.keys() |> Enum.map(&byte_size/1) |> Enum.max(),
      one: 0..255 |> Enum.map(&Map.get(one, &1)) |> List.to_tuple(),
      prefixes: prefixes
    }
  end

  defp write_support_matrix(root, encodings) do
    header = [
      "# Unicode mapping-table component codecs",
      "",
      "These are exact, separately named component representations from pinned Unicode mapping tables.",
      "The Hangul columns are not advertised as full EUC-KR, UHC, or JOHAB transports; they contain",
      "only the Hangul syllable mappings explicitly present in `HANGUL.TXT`. `IBMGRAPH` exposes the",
      "memory-mapped PC video glyph positions and its distinct CP864 column.",
      "",
      "| Encoding | Aliases | Decode mappings | Encode mappings | Source SHA-256 |",
      "|---|---|---:|---:|---|"
    ]

    rows =
      Enum.map(encodings, fn entry ->
        aliases = Enum.map_join(entry.aliases, ", ", &"`#{&1}`")

        "| `#{entry.name}` | #{aliases} | #{entry.decode_mappings} | " <>
          "#{entry.encode_mappings} | `#{entry.sha256}` |"
      end)

    File.write!(
      Path.join(root, "UNICODE_MAPPING_COMPONENTS.md"),
      Enum.join(header ++ rows, "\n") <> "\n"
    )
  end

  defp sha256(contents), do: :crypto.hash(:sha256, contents) |> Base.encode16(case: :lower)
end

Iconvex.Specs.Tools.ImportUnicodeMappingComponents.run()
