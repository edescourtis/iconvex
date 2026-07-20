defmodule Iconvex.Specs.Tools.ImportUnicodeMisc do
  @moduledoc false

  @aggregate_sha256 "f76182817119b7cdf4a61be5aa5fa5d661654039210563c92ab9a1971892e369"
  @specs [
    %{
      file: "APL-ISO-IR-68.TXT",
      name: "APL-ISO-IR-68",
      aliases: ["ISO-IR-68-APL"],
      url: "https://www.unicode.org/Public/MAPPINGS/VENDORS/MISC/APL-ISO-IR-68.TXT"
    },
    %{
      file: "APL-ISO-IR-68-2004.TXT",
      name: "APL-ISO-IR-68-2004",
      aliases: ["ISO-IR-68-APL-2004"],
      url:
        "https://www.unicode.org/Public/MAPPINGS/VENDORS/MISC/DatedVersions/APL-ISO-IR-68-2004.TXT"
    },
    %{
      file: "KPS9566.TXT",
      name: "KPS-9566-2003",
      aliases: ["KPS9566", "KPS-9566", "KPS-9566-2003"],
      url: "https://www.unicode.org/Public/MAPPINGS/VENDORS/MISC/KPS9566.TXT"
    }
  ]

  def run do
    root = Path.expand("..", __DIR__)
    committed = Path.join([root, "priv", "sources", "unicode-misc"])
    source_root = System.get_env("UNICODE_MISC_SOURCE_DIR") || committed
    assert_source_set!(source_root)
    copy_sources(source_root, committed)
    table_dir = Path.join(root, "priv/tables")
    File.mkdir_p!(table_dir)

    encodings =
      @specs
      |> Enum.with_index(1)
      |> Enum.map(fn {spec, index} -> import(spec, committed, table_dir, index) end)

    manifest = %{
      aggregate_sha256: @aggregate_sha256,
      encodings: encodings,
      format: 1
    }

    File.write!(
      Path.join(root, "priv/unicode_misc_manifest.etf"),
      :erlang.term_to_binary(manifest, [:deterministic, :compressed])
    )

    IO.puts("wrote #{length(encodings)} Unicode miscellaneous mapping codecs")
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
      do: Mix.raise("Unicode miscellaneous source-set SHA-256 mismatch: #{digest}")
  end

  defp copy_sources(source_root, committed) do
    if Path.expand(source_root) != Path.expand(committed) do
      File.mkdir_p!(committed)

      Enum.each(@specs, fn spec ->
        File.cp!(Path.join(source_root, spec.file), Path.join(committed, spec.file))
      end)
    end
  end

  defp import(spec, committed, table_dir, index) do
    source = File.read!(Path.join(committed, spec.file))
    mappings = parse_mappings(source)

    decode =
      mappings
      |> Enum.reduce(%{}, fn {bytes, codepoint}, map -> Map.put_new(map, bytes, {codepoint}) end)

    encode =
      mappings
      |> Enum.reduce(%{}, fn {bytes, codepoint}, map -> Map.put_new(map, {codepoint}, bytes) end)

    id = String.to_atom("unicode_misc_#{index}")
    table = build_table(decode, encode)

    File.write!(
      Path.join(table_dir, "#{id}.etf"),
      :erlang.term_to_binary(table, [:deterministic, :compressed])
    )

    %{
      aliases: spec.aliases,
      decode_duplicates: length(mappings) - map_size(decode),
      decode_mappings: map_size(decode),
      encode_duplicates: length(mappings) - map_size(encode),
      encode_mappings: map_size(encode),
      id: id,
      index: index,
      mapping_rows: length(mappings),
      max_input: table.max_input,
      name: spec.name,
      sha256: sha256(source),
      source_file: spec.file,
      source_url: spec.url
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
      max_codepoints: 1,
      max_input: decode |> Map.keys() |> Enum.map(&byte_size/1) |> Enum.max(),
      one: 0..255 |> Enum.map(&Map.get(one, &1)) |> List.to_tuple(),
      prefixes: prefixes
    }
  end

  defp parse_mappings(source) do
    source
    |> String.split("\n")
    |> Enum.flat_map(fn line ->
      case Regex.run(~r/^0x([0-9A-Fa-f]+)\s+0x([0-9A-Fa-f]+)/, line, capture: :all_but_first) do
        [encoded, unicode] ->
          [{Base.decode16!(encoded, case: :mixed), String.to_integer(unicode, 16)}]

        nil ->
          []
      end
    end)
  end

  defp sha256(binary), do: :crypto.hash(:sha256, binary) |> Base.encode16(case: :lower)
end

Iconvex.Specs.Tools.ImportUnicodeMisc.run()
