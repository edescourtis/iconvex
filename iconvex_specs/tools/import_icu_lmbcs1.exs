defmodule Iconvex.Specs.Tools.ImportICULMBCS1 do
  @moduledoc false

  @release "78.3"
  @revision "21d1eb0f306e1141c10931e914dfc038c06121da"
  @aggregate_sha256 "8d7070af86babdf51973219367d85130b996f757cb7a8081068385dfed8502fb"
  @source_url "https://github.com/unicode-org/icu/tree/#{@revision}/icu4c/source"
  @files [
    "ucnv_lmb.cpp",
    "lmb-excp.ucm",
    "ibm-850_P100-1995.ucm",
    "ibm-851_P100-1995.ucm",
    "ibm-9447_P100-2002.ucm",
    "ibm-9448_X100-2005.ucm",
    "ibm-5347_P100-1998.ucm",
    "ibm-852_P100-1995.ucm",
    "ibm-5350_P100-1998.ucm",
    "windows-874-2000.ucm",
    "ibm-943_P15A-2003.ucm",
    "windows-949-2000.ucm",
    "windows-950-2000.ucm",
    "windows-936-2000.ucm",
    "convrtrs.txt"
  ]
  @groups %{
    0x00 => "lmb-excp.ucm",
    0x01 => "ibm-850_P100-1995.ucm",
    0x02 => "ibm-851_P100-1995.ucm",
    0x03 => "ibm-9447_P100-2002.ucm",
    0x04 => "ibm-9448_X100-2005.ucm",
    0x05 => "ibm-5347_P100-1998.ucm",
    0x06 => "ibm-852_P100-1995.ucm",
    0x08 => "ibm-5350_P100-1998.ucm",
    0x0B => "windows-874-2000.ucm",
    0x10 => "ibm-943_P15A-2003.ucm",
    0x11 => "windows-949-2000.ucm",
    0x12 => "windows-950-2000.ucm",
    0x13 => "windows-936-2000.ucm"
  }
  @group_tokens %{
    "ULMBCS_GRP_EXCEPT" => 0x00,
    "ULMBCS_GRP_L1" => 0x01,
    "ULMBCS_GRP_GR" => 0x02,
    "ULMBCS_GRP_HE" => 0x03,
    "ULMBCS_GRP_AR" => 0x04,
    "ULMBCS_GRP_RU" => 0x05,
    "ULMBCS_GRP_L2" => 0x06,
    "ULMBCS_GRP_TR" => 0x08,
    "ULMBCS_GRP_TH" => 0x0B,
    "ULMBCS_GRP_CTRL" => 0x0F,
    "ULMBCS_GRP_JA" => 0x10,
    "ULMBCS_GRP_KO" => 0x11,
    "ULMBCS_GRP_TW" => 0x12,
    "ULMBCS_GRP_CN" => 0x13,
    "ULMBCS_GRP_UNICODE" => 0x14,
    "ULMBCS_AMBIGUOUS_SBCS" => 0x80,
    "ULMBCS_AMBIGUOUS_MBCS" => 0x81,
    "ULMBCS_AMBIGUOUS_ALL" => 0x82
  }

  def run do
    root = Path.expand("..", __DIR__)
    committed = Path.join([root, "priv", "sources", "icu-#{@release}-lmbcs1"])
    sources = source_paths(root, committed)
    assert_sources!(sources)
    copy_sources(sources, committed)

    groups =
      Map.new(@groups, fn {group, filename} ->
        {group, parse_ucm(Path.join(committed, filename))}
      end)

    ranges = parse_ranges(File.read!(Path.join(committed, "ucnv_lmb.cpp")))

    classification =
      for codepoint <- 0..0xFFFF, into: <<>> do
        <<classify(codepoint, ranges)>>
      end

    data = %{classification: classification, groups: groups, ranges: ranges}

    File.write!(
      Path.join(root, "priv/icu_lmbcs1.etf"),
      :erlang.term_to_binary(data, [:deterministic, :compressed])
    )

    sources = Enum.map(@files, &{&1, sha256(File.read!(Path.join(committed, &1)))})

    manifest = %{
      aggregate_sha256: @aggregate_sha256,
      aliases: ["lmbcs", "ibm-65025"],
      canonical_name: "LMBCS-1",
      format: 1,
      group_counts:
        Map.new(groups, fn {group, table} ->
          {group, %{decode: map_size(table.decode), encode: map_size(table.encode)}}
        end),
      range_rows: length(ranges),
      release: @release,
      revision: @revision,
      source_url: @source_url,
      sources: sources
    }

    File.write!(
      Path.join(root, "priv/icu_lmbcs1_manifest.etf"),
      :erlang.term_to_binary(manifest, [:deterministic])
    )

    write_support_matrix(root, manifest)
    IO.puts("wrote ICU #{@release} LMBCS-1 tables")
  end

  defp source_paths(_root, committed) do
    cond do
      Enum.all?(@files, &File.regular?(Path.join(committed, &1))) ->
        Enum.map(@files, &{&1, Path.join(committed, &1)})

      source_root = System.get_env("ICU_SOURCE_DIR") ->
        mappings = Path.join([source_root, "data", "mappings"])

        Enum.map(@files, fn
          "ucnv_lmb.cpp" = name -> {name, Path.join([source_root, "common", name])}
          name -> {name, Path.join(mappings, name)}
        end)

      true ->
        mappings = "/private/tmp/iconvex-icu/icu4c/source/data/mappings"

        Enum.map(@files, fn
          "ucnv_lmb.cpp" = name -> {name, "/private/tmp/#{name}"}
          name -> {name, Path.join(mappings, name)}
        end)
    end
  end

  defp assert_sources!(sources) do
    Enum.each(sources, fn {name, path} ->
      unless File.regular?(path), do: Mix.raise("missing ICU LMBCS source #{name}: #{path}")
    end)

    digest =
      Enum.reduce(sources, :crypto.hash_init(:sha256), fn {name, path}, context ->
        context
        |> :crypto.hash_update(name)
        |> :crypto.hash_update(<<0>>)
        |> :crypto.hash_update(File.read!(path))
      end)
      |> :crypto.hash_final()
      |> Base.encode16(case: :lower)

    unless digest == @aggregate_sha256,
      do: Mix.raise("ICU LMBCS-1 source-set SHA-256 mismatch: #{digest}")
  end

  defp copy_sources(sources, committed) do
    File.mkdir_p!(committed)

    Enum.each(sources, fn {name, path} ->
      target = Path.join(committed, name)
      if Path.expand(path) != Path.expand(target), do: File.cp!(path, target)
    end)
  end

  defp parse_ranges(source) do
    [_, body] = Regex.run(~r/UniLMBCSGrpMap\[\]\s*=\s*\{(.*?)\n\};/s, source)

    Regex.scan(
      ~r/\{0x([0-9A-Fa-f]+),\s*0x([0-9A-Fa-f]+),\s*(ULMBCS_[A-Z0-9_]+)\}/,
      body,
      capture: :all_but_first
    )
    |> Enum.map(fn [first, last, token] ->
      {String.to_integer(first, 16), String.to_integer(last, 16),
       Map.fetch!(@group_tokens, token)}
    end)
  end

  defp parse_ucm(path) do
    rows =
      path
      |> File.stream!()
      |> Enum.flat_map(fn line ->
        case Regex.run(
               ~r/^<U([0-9A-Fa-f]+)>\s+((?:\\x[0-9A-Fa-f]{2})+)(?:\s+\|(\d))?/,
               line,
               capture: :all_but_first
             ) do
          [unicode, encoded, precision] -> [row(unicode, encoded, precision)]
          [unicode, encoded] -> [row(unicode, encoded, "0")]
          nil -> []
        end
      end)

    decode =
      rows
      |> Enum.filter(&(&1.precision in [0, 3]))
      |> Enum.sort_by(&precision_priority/1)
      |> Enum.reduce(%{}, fn mapping, result ->
        Map.put_new(result, mapping.bytes, mapping.codepoint)
      end)

    encode =
      rows
      |> Enum.filter(fn mapping ->
        mapping.precision in [0, 4] or
          (mapping.precision == 1 and private_use?(mapping.codepoint))
      end)
      |> Enum.sort_by(&precision_priority/1)
      |> Enum.reduce(%{}, fn mapping, result ->
        Map.put_new(result, mapping.codepoint, mapping.bytes)
      end)

    %{decode: decode, encode: encode}
  end

  defp classify(codepoint, ranges) do
    Enum.find_value(ranges, 0x14, fn {first, last, group} ->
      if codepoint <= last, do: if(codepoint >= first, do: group, else: 0x14)
    end)
  end

  defp row(unicode, encoded, precision) do
    bytes =
      Regex.scan(~r/\\x([0-9A-Fa-f]{2})/, encoded, capture: :all_but_first)
      |> List.flatten()
      |> Enum.map(&String.to_integer(&1, 16))
      |> :binary.list_to_bin()

    %{
      bytes: bytes,
      codepoint: String.to_integer(unicode, 16),
      precision: String.to_integer(precision)
    }
  end

  defp precision_priority(%{precision: 0}), do: 0
  defp precision_priority(%{precision: precision}) when precision in [3, 4], do: 1
  defp precision_priority(%{precision: 1}), do: 2

  defp private_use?(codepoint),
    do:
      codepoint in 0xE000..0xF8FF or codepoint in 0xF0000..0xFFFFD or
        codepoint in 0x100000..0x10FFFD

  defp write_support_matrix(root, manifest) do
    lines = [
      "# ICU 78.3 LMBCS profiles",
      "",
      "Native Elixir port pinned to Unicode ICU revision `#{@revision}`.",
      "The annotated ICU algorithm and all thirteen loaded mapping tables are committed and hashed.",
      "ICU instantiates optimization groups `1`, `2`, `3`, `4`, `5`, `6`, `8`, `11`, `16`, `17`, `18`, and `19`; Iconvex Specs exposes exactly those twelve canonical profiles.",
      "The eleven non-default names are working but intentionally unadvertised in ICU's alias list, so they have no invented aliases.",
      "",
      "| Group | Decode mappings | Encode mappings |",
      "|---:|---:|---:|"
    ]

    rows =
      manifest.group_counts
      |> Enum.sort()
      |> Enum.map(fn {group, counts} ->
        "| `0x#{group |> Integer.to_string(16) |> String.upcase() |> String.pad_leading(2, "0")}` | #{counts.decode} | #{counts.encode} |"
      end)

    File.write!(Path.join(root, "ICU_LMBCS1.md"), Enum.join(lines ++ rows, "\n") <> "\n")
  end

  defp sha256(binary), do: :crypto.hash(:sha256, binary) |> Base.encode16(case: :lower)
end

Iconvex.Specs.Tools.ImportICULMBCS1.run()
