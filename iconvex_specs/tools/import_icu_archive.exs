defmodule Iconvex.Specs.Tools.ImportICUArchive do
  @moduledoc false

  @revision "d7d6dd5bb68930c5e6b3dd4491574153d3a1ba5a"
  @aggregate_sha256 "8103d520bb496cdd34b0428153eb42f81bad603353bd380c4f4d5a6f10e98d81"
  @source_url "https://github.com/unicode-org/icu-data/tree/#{@revision}/charset/data/ucm"
  @expected_classes %{
    "DBCS" => 66,
    "EBCDIC_STATEFUL" => 46,
    "MBCS" => 149,
    "SBCS" => 760,
    "UNCLASSIFIED" => 29
  }
  # Public aliases from ICU 78.3's pinned convrtrs.txt for archive mappings
  # that are no longer shipped as standalone UCM files in the current tree.
  @public_aliases %{
    "ibm-259_P100-1995" => ["ibm-259", "IBM-Symbols", "csIBMSymbols"],
    "ibm-931_P120-1999" => ["CP50931", "windows-50931"]
  }

  def run do
    root = Path.expand("..", __DIR__)
    committed = Path.join([root, "priv", "sources", "icu-data-archive"])
    source_root = System.get_env("ICU_ARCHIVE_SOURCE_DIR") || committed
    files = source_root |> Path.join("*.ucm") |> Path.wildcard() |> Enum.sort()

    assert_source_set!(files)
    copy_sources(source_root, committed, files)
    table_dir = Path.join(root, "priv/tables")
    File.mkdir_p!(table_dir)

    code_set_frequencies =
      files
      |> Enum.map(&(File.read!(&1) |> header!("code_set_name") |> String.downcase()))
      |> Enum.frequencies()

    encodings =
      files
      |> Enum.with_index(1)
      |> Enum.map(fn {source_path, index} ->
        committed_path = Path.join(committed, Path.basename(source_path))
        import(committed_path, table_dir, code_set_frequencies, index)
      end)

    manifest = %{
      aggregate_sha256: @aggregate_sha256,
      encodings: encodings,
      format: 1,
      revision: @revision,
      source_url: @source_url
    }

    File.write!(
      Path.join(root, "priv/icu_archive_manifest.etf"),
      :erlang.term_to_binary(manifest, [:deterministic, :compressed])
    )

    write_support_matrix(root, encodings)
    IO.puts("wrote #{length(encodings)} ICU data-archive codecs")
  end

  defp assert_source_set!(files) do
    classes =
      files
      |> Enum.map(&(File.read!(&1) |> uconv_class()))
      |> Enum.frequencies()

    unless classes == @expected_classes,
      do: Mix.raise("unexpected ICU data-archive class inventory: #{inspect(classes)}")

    digest =
      Enum.reduce(files, :crypto.hash_init(:sha256), fn path, context ->
        context
        |> :crypto.hash_update(Path.basename(path))
        |> :crypto.hash_update(<<0>>)
        |> :crypto.hash_update(File.read!(path))
      end)
      |> :crypto.hash_final()
      |> Base.encode16(case: :lower)

    unless digest == @aggregate_sha256,
      do: Mix.raise("ICU data-archive source-set SHA-256 mismatch: #{digest}")
  end

  defp copy_sources(source_root, committed, files) do
    if Path.expand(source_root) != Path.expand(committed) do
      File.mkdir_p!(committed)

      Enum.each(files, fn path ->
        File.cp!(path, Path.join(committed, Path.basename(path)))
      end)
    end
  end

  defp import(path, table_dir, code_set_frequencies, index) do
    source = File.read!(path)
    source_file = Path.basename(path)
    source_name = Path.rootname(source_file)
    name = "ICU-ARCHIVE-#{source_name}"
    code_set_name = header!(source, "code_set_name")
    uconv_class = uconv_class(source)
    stateful = uconv_class == "EBCDIC_STATEFUL" or String.match?(source, ~r/^<icu:state>.*\.s/m)
    mappings = parse_mappings(source)
    {decode, encode} = directional_maps(mappings)
    id = String.to_atom("icu_archive_#{index}")

    table =
      if stateful,
        do: build_stateful_table(decode, encode),
        else: build_table(decode, encode)

    File.write!(
      Path.join(table_dir, "#{id}.etf"),
      :erlang.term_to_binary(table, [:deterministic, :compressed])
    )

    aliases =
      source
      |> ucm_aliases()
      |> maybe_prepend_code_set_name(code_set_name, code_set_frequencies)
      |> Kernel.++(Map.get(@public_aliases, source_name, []))
      |> Enum.filter(&registerable_name?/1)
      |> Enum.reject(&(String.downcase(&1) == String.downcase(name)))
      |> Enum.uniq_by(&String.downcase/1)

    %{
      aliases: aliases,
      code_set_name: code_set_name,
      decode_sentinel_rows: Enum.count(mappings, &icu_decode_sentinel?/1),
      decode_mappings: map_size(decode),
      encode_mappings: map_size(encode),
      fallback_rows: Enum.count(mappings, &(&1.precision == 1)),
      id: id,
      index: index,
      mapping_rows: length(mappings),
      max_codepoints: table.max_codepoints,
      max_input: max_input(table, stateful),
      name: name,
      source_name: source_name,
      reverse_fallback_rows: Enum.count(mappings, &(&1.precision == 3)),
      sha256: sha256(source),
      source_file: source_file,
      state_rows: length(Regex.scan(~r/^<icu:state>/m, source)),
      stateful: stateful,
      uconv_class: uconv_class
    }
  end

  defp maybe_prepend_code_set_name(aliases, code_set_name, frequencies) do
    if Map.fetch!(frequencies, String.downcase(code_set_name)) == 1,
      do: [code_set_name | aliases],
      else: aliases
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
      max_codepoints: max_codepoints(encode),
      max_input: decode |> Map.keys() |> Enum.map(&byte_size/1) |> Enum.max(fn -> 1 end),
      one: 0..255 |> Enum.map(&Map.get(one, &1)) |> List.to_tuple(),
      prefixes: prefixes
    }
  end

  defp build_stateful_table(decode, encode) do
    {sbcs, dbcs} =
      Enum.reduce(decode, {%{}, %{}}, fn {bytes, codepoints}, {sbcs, dbcs} ->
        case bytes do
          <<byte>> -> {Map.put(sbcs, byte, codepoints), dbcs}
          <<_first, _second>> -> {sbcs, Map.put(dbcs, bytes, codepoints)}
          _ -> Mix.raise("unexpected mixed-EBCDIC mapping width in #{inspect(bytes)}")
        end
      end)

    encoded =
      Map.new(encode, fn {codepoints, bytes} ->
        mode = if byte_size(bytes) == 1, do: :sbcs, else: :dbcs
        {codepoints, {mode, bytes}}
      end)

    %{
      dbcs_decode: dbcs,
      encode: encoded,
      max_codepoints: max_codepoints(encoded),
      sbcs_decode: 0..255 |> Enum.map(&Map.get(sbcs, &1)) |> List.to_tuple()
    }
  end

  defp max_codepoints(encode),
    do: encode |> Map.keys() |> Enum.map(&tuple_size/1) |> Enum.max(fn -> 1 end)

  defp max_input(table, true) do
    if map_size(table.dbcs_decode) == 0, do: 1, else: 2
  end

  defp max_input(table, false), do: table.max_input

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
      |> Enum.filter(&(&1.precision in [0, 3] and not icu_decode_sentinel?(&1)))
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

  defp icu_decode_sentinel?(%{codepoints: codepoints, precision: precision})
       when precision in [0, 3],
       do: Enum.any?(Tuple.to_list(codepoints), &(&1 in [0xFFFE, 0xFFFF]))

  defp icu_decode_sentinel?(_mapping), do: false

  defp private_use?(codepoints) do
    codepoints
    |> Tuple.to_list()
    |> Enum.all?(fn codepoint ->
      codepoint in 0xE000..0xF8FF or codepoint in 0xF0000..0xFFFFD or
        codepoint in 0x100000..0x10FFFD
    end)
  end

  defp ucm_aliases(source) do
    Regex.scan(~r/^<icu:alias>\s+"([^"]+)"/m, source, capture: :all_but_first)
    |> List.flatten()
  end

  defp header!(source, key) do
    case Regex.run(
           ~r/^<#{Regex.escape(key)}>\s+(?:"([^"]+)"|(\S+))/m,
           source,
           capture: :all_but_first
         ) do
      [quoted, ""] -> quoted
      ["", unquoted] -> unquoted
      [quoted] -> quoted
      nil -> Mix.raise("missing <#{key}> UCM header")
    end
  end

  defp uconv_class(source) do
    case Regex.run(~r/^<uconv_class>\s+"?([^"\r\n]+?)"?\s*$/m, source, capture: :all_but_first) do
      [class] -> String.trim(class)
      nil -> "UNCLASSIFIED"
    end
  end

  defp registerable_name?(name),
    do: not String.contains?(name, "/") and String.match?(name, ~r/^[\x21-\x7e]+$/)

  defp sha256(binary), do: :crypto.hash(:sha256, binary) |> Base.encode16(case: :lower)

  defp write_support_matrix(root, encodings) do
    lines = [
      "# ICU historical converter archive",
      "",
      "Generated by `tools/import_icu_archive.exs` from the Unicode ICU data-repository",
      "revision `#{@revision}`. Canonical names use `ICU-ARCHIVE-` plus the exact source",
      "filename stem so vendor/platform revisions are never collapsed or shadowed.",
      "",
      "| Canonical revision | UCM code-set name | Class | Decode | Encode | SHA-256 |",
      "|---|---|---|---:|---:|---|"
    ]

    rows =
      Enum.map(encodings, fn entry ->
        "| `#{entry.name}` | `#{entry.code_set_name}` | #{entry.uconv_class} | " <>
          "#{entry.decode_mappings} | #{entry.encode_mappings} | `#{entry.sha256}` |"
      end)

    File.write!(
      Path.join(root, "ICU_ARCHIVE_ENCODINGS.md"),
      Enum.join(lines ++ rows, "\n") <> "\n"
    )
  end
end

Iconvex.Specs.Tools.ImportICUArchive.run()
