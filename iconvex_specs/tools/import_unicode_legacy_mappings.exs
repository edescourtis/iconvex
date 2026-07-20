defmodule Iconvex.Specs.Tools.ImportUnicodeLegacyMappings do
  @moduledoc false

  @aggregate_sha256 "1247487cb8f5e4cdcf8d304f5ed218827f9a8543b362576759cab114a7b40fef"
  @specs [
    %{
      file: "JIS0201.TXT",
      name: "JIS0201",
      aliases: ["UNICODE-MAPPING-JIS0201"],
      url: "https://www.unicode.org/Public/MAPPINGS/OBSOLETE/EASTASIA/JIS/JIS0201.TXT"
    },
    %{
      file: "JIS0212.TXT",
      name: "JIS0212",
      aliases: ["UNICODE-MAPPING-JIS0212", "JIS-X-0212-ROW-CELL"],
      url: "https://www.unicode.org/Public/MAPPINGS/OBSOLETE/EASTASIA/JIS/JIS0212.TXT"
    },
    %{
      file: "KSX1001.TXT",
      name: "KSX1001",
      aliases: ["UNICODE-MAPPING-KSX1001", "KS-X-1001-ROW-CELL"],
      url: "https://www.unicode.org/Public/MAPPINGS/OBSOLETE/EASTASIA/KSC/KSX1001.TXT"
    },
    %{
      file: "OLD5601.TXT",
      name: "OLD5601",
      aliases: ["UNICODE-MAPPING-OLD5601", "OLD-KSC5601-ROW-CELL"],
      url: "https://www.unicode.org/Public/MAPPINGS/OBSOLETE/EASTASIA/KSC/OLD5601.TXT"
    },
    %{
      file: "US-ASCII-QUOTES.TXT",
      name: "US-ASCII-QUOTES",
      aliases: ["ASCII-TYPOGRAPHIC-QUOTES"],
      url: "https://www.unicode.org/Public/MAPPINGS/VENDORS/MISC/US-ASCII-QUOTES.TXT"
    }
  ]

  def run do
    root = Path.expand("..", __DIR__)
    committed = Path.join([root, "priv", "sources", "unicode-legacy"])
    source_root = System.get_env("UNICODE_LEGACY_SOURCE_DIR") || committed
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
      Path.join(root, "priv/unicode_legacy_manifest.etf"),
      :erlang.term_to_binary(manifest, [:deterministic, :compressed])
    )

    write_support_matrix(root, encodings)
    IO.puts("wrote #{length(encodings)} Unicode legacy coded-set mappings")
  end

  defp assert_source_set!(source_root) do
    digest =
      Enum.reduce(@specs, :crypto.hash_init(:sha256), fn spec, context ->
        context
        |> :crypto.hash_update(spec.file)
        |> :crypto.hash_update(<<0>>)
        |> :crypto.hash_update(File.read!(Path.join(source_root, spec.file)))
      end)
      |> :crypto.hash_final()
      |> Base.encode16(case: :lower)

    unless digest == @aggregate_sha256,
      do: Mix.raise("Unicode legacy source-set SHA-256 mismatch: #{digest}")
  end

  defp copy_sources(source_root, committed) do
    if Path.expand(source_root) != Path.expand(committed) do
      File.mkdir_p!(committed)

      Enum.each(@specs, fn spec ->
        File.cp!(Path.join(source_root, spec.file), Path.join(committed, spec.file))
      end)
    end
  end

  defp import(spec, index, committed, table_dir) do
    source = File.read!(Path.join(committed, spec.file))
    rows = parse_mappings(source)
    decode = Enum.reduce(rows, %{}, fn {bytes, cp}, map -> Map.put_new(map, bytes, {cp}) end)
    encode = Enum.reduce(rows, %{}, fn {bytes, cp}, map -> Map.put_new(map, {cp}, bytes) end)
    id = String.to_atom("unicode_legacy_#{index}")
    table = build_table(decode, encode)

    File.write!(
      Path.join(table_dir, "#{id}.etf"),
      :erlang.term_to_binary(table, [:deterministic, :compressed])
    )

    %{
      aliases: spec.aliases,
      decode_duplicates: length(rows) - map_size(decode),
      decode_mappings: map_size(decode),
      encode_duplicates: length(rows) - map_size(encode),
      encode_mappings: map_size(encode),
      id: id,
      index: index,
      mapping_rows: length(rows),
      max_input: table.max_input,
      name: spec.name,
      sha256: sha256(source),
      source_file: spec.file,
      source_url: spec.url
    }
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
      "# Unicode legacy coded-set mappings",
      "",
      "These standalone coded-set/component representations are pinned from the Unicode",
      "mapping archive. They are exposed under explicit names so row-cell codes are not",
      "confused with EUC or Shift-JIS transport encodings.",
      "",
      "| Encoding | Decode mappings | Encode mappings | Source SHA-256 |",
      "|---|---:|---:|---|"
    ]

    rows =
      Enum.map(encodings, fn entry ->
        "| `#{entry.name}` | #{entry.decode_mappings} | #{entry.encode_mappings} | `#{entry.sha256}` |"
      end)

    File.write!(
      Path.join(root, "UNICODE_LEGACY_ENCODINGS.md"),
      Enum.join(header ++ rows, "\n") <> "\n"
    )
  end

  defp sha256(contents), do: :crypto.hash(:sha256, contents) |> Base.encode16(case: :lower)
end

Iconvex.Specs.Tools.ImportUnicodeLegacyMappings.run()
