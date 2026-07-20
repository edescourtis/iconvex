defmodule Iconvex.Specs.Tools.ImportICUJIS do
  @moduledoc false

  @release "78.3"
  @revision "21d1eb0f306e1141c10931e914dfc038c06121da"
  @aggregate_sha256 "1769c631b4d3bc50af77cd15ce41167b6df9151542285b03a3c4a1880a53ddcc"
  @source_url "https://github.com/unicode-org/icu/tree/#{@revision}/icu4c/source"
  @files [
    "ucnv2022.cpp",
    "ibm-943_P15A-2003.ucm",
    "jisx-212.ucm",
    "ibm-5478_P100-1995.ucm",
    "windows-949-2000.ucm",
    "ibm-9005_X110-2007.ucm",
    "convrtrs.txt"
  ]

  def run do
    root = Path.expand("..", __DIR__)
    committed = Path.join([root, "priv", "sources", "icu-#{@release}-jis"])
    sources = source_paths(root, committed)

    assert_sources!(sources)
    File.mkdir_p!(committed)

    Enum.each(sources, fn {name, path} ->
      target = Path.join(committed, name)

      if Path.expand(path) != Path.expand(target) do
        File.cp!(path, target)
      end
    end)

    maps = build_maps(committed)

    File.write!(
      Path.join(root, "priv/icu_jis.etf"),
      :erlang.term_to_binary(maps, [:deterministic, :compressed])
    )

    source_hashes = Enum.map(@files, &{&1, sha256(File.read!(Path.join(committed, &1)))})

    manifest = %{
      aggregate_sha256: @aggregate_sha256,
      encodings: [
        %{aliases: ["ISO_2022,locale=ja,version=3"], id: :icu_jis7, name: "JIS7", variant: :jis7},
        %{aliases: ["ISO_2022,locale=ja,version=4"], id: :icu_jis8, name: "JIS8", variant: :jis8}
      ],
      format: 1,
      mapping_counts:
        Map.new(maps, fn {name, table} ->
          {name, %{decode: map_size(table.decode), encode: map_size(table.encode)}}
        end),
      release: @release,
      revision: @revision,
      source_url: @source_url,
      sources: source_hashes
    }

    File.write!(
      Path.join(root, "priv/icu_jis_manifest.etf"),
      :erlang.term_to_binary(manifest, [:deterministic])
    )

    write_support_matrix(root, manifest)
    IO.puts("wrote ICU #{@release} JIS7/JIS8 tables")
  end

  defp source_paths(root, committed) do
    cond do
      Enum.all?(@files, &File.regular?(Path.join(committed, &1))) ->
        Enum.map(@files, &{&1, Path.join(committed, &1)})

      source_root = System.get_env("ICU_SOURCE_DIR") ->
        mappings = Path.join([source_root, "data", "mappings"])

        [
          {"ucnv2022.cpp", Path.join([source_root, "common", "ucnv2022.cpp"])},
          {"ibm-943_P15A-2003.ucm", Path.join(mappings, "ibm-943_P15A-2003.ucm")},
          {"jisx-212.ucm", Path.join(mappings, "jisx-212.ucm")},
          {"ibm-5478_P100-1995.ucm", Path.join(mappings, "ibm-5478_P100-1995.ucm")},
          {"windows-949-2000.ucm", Path.join(mappings, "windows-949-2000.ucm")},
          {"ibm-9005_X110-2007.ucm", Path.join(mappings, "ibm-9005_X110-2007.ucm")},
          {"convrtrs.txt", Path.join(mappings, "convrtrs.txt")}
        ]

      true ->
        multibyte = Path.join([root, "priv", "sources", "icu-#{@release}-multibyte"])
        sbcs = Path.join([root, "priv", "sources", "icu-#{@release}"])

        [
          {"ucnv2022.cpp", "/private/tmp/ucnv2022.cpp"},
          {"ibm-943_P15A-2003.ucm", Path.join(multibyte, "ibm-943_P15A-2003.ucm")},
          {"jisx-212.ucm", Path.join(multibyte, "jisx-212.ucm")},
          {"ibm-5478_P100-1995.ucm", Path.join(multibyte, "ibm-5478_P100-1995.ucm")},
          {"windows-949-2000.ucm", Path.join(multibyte, "windows-949-2000.ucm")},
          {"ibm-9005_X110-2007.ucm", Path.join(sbcs, "ibm-9005_X110-2007.ucm")},
          {"convrtrs.txt", Path.join(multibyte, "convrtrs.txt")}
        ]
    end
  end

  defp assert_sources!(sources) do
    Enum.each(sources, fn {name, path} ->
      unless File.regular?(path), do: Mix.raise("missing ICU JIS source #{name}: #{path}")
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
      do: Mix.raise("ICU JIS source-set SHA-256 mismatch: #{digest}")
  end

  defp build_maps(source_dir) do
    sjis = source_dir |> source("ibm-943_P15A-2003.ucm") |> maps()
    jis212 = source_dir |> source("jisx-212.ucm") |> maps()
    gb = source_dir |> source("ibm-5478_P100-1995.ucm") |> maps()
    ksc = source_dir |> source("windows-949-2000.ucm") |> maps()
    greek = source_dir |> source("ibm-9005_X110-2007.ucm") |> maps()

    %{
      jis208: transform(sjis, &sjis_to_jis/1),
      jis212: filter(jis212, &gl94?/1),
      gb: filter(gb, &gl94?/1),
      ksc: ksc |> filter(&gr94?/1) |> transform(&gr_to_gl/1),
      greek: greek |> filter(&gr96?/1) |> transform(&gr_to_gl/1)
    }
  end

  defp source(dir, name), do: Path.join(dir, name)

  defp maps(path) do
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

  defp transform(table, transform) do
    %{
      decode:
        Enum.reduce(table.decode, %{}, fn {bytes, codepoint}, result ->
          case transform.(bytes) do
            nil -> result
            transformed -> Map.put_new(result, transformed, codepoint)
          end
        end),
      encode:
        Enum.reduce(table.encode, %{}, fn {codepoint, bytes}, result ->
          case transform.(bytes) do
            nil -> result
            transformed -> Map.put_new(result, codepoint, transformed)
          end
        end)
    }
  end

  defp filter(table, predicate) do
    %{
      decode: Map.new(Enum.filter(table.decode, fn {bytes, _codepoint} -> predicate.(bytes) end)),
      encode: Map.new(Enum.filter(table.encode, fn {_codepoint, bytes} -> predicate.(bytes) end))
    }
  end

  defp sjis_to_jis(<<lead, trail>>) do
    value = lead * 0x100 + trail

    if value > 0xEFFC do
      nil
    else
      row = if(lead <= 0x9F, do: lead - 0x70, else: lead - 0xB0) * 2

      cond do
        trail <= 0x7E -> <<row - 1, trail - 0x1F>>
        trail <= 0x9E -> <<row - 1, trail - 0x20>>
        trail <= 0xFC -> <<row, trail - 0x7E>>
        true -> nil
      end
    end
  end

  defp sjis_to_jis(_bytes), do: nil
  defp gl94?(<<a, b>>), do: a in 0x21..0x7E and b in 0x21..0x7E
  defp gl94?(_bytes), do: false
  defp gr94?(<<a, b>>), do: a in 0xA1..0xFE and b in 0xA1..0xFE
  defp gr94?(_bytes), do: false
  defp gr96?(<<byte>>), do: byte in 0xA0..0xFF
  defp gr96?(_bytes), do: false
  defp gr_to_gl(bytes), do: for(<<byte <- bytes>>, into: <<>>, do: <<byte - 0x80>>)

  defp precision_priority(%{precision: 0}), do: 0
  defp precision_priority(%{precision: precision}) when precision in [3, 4], do: 1
  defp precision_priority(%{precision: 1}), do: 2

  defp private_use?(codepoint),
    do:
      codepoint in 0xE000..0xF8FF or codepoint in 0xF0000..0xFFFFD or
        codepoint in 0x100000..0x10FFFD

  defp write_support_matrix(root, manifest) do
    lines = [
      "# ICU 78.3 JIS7 and JIS8",
      "",
      "Native Elixir state machines pinned to Unicode ICU revision `#{@revision}`.",
      "Every reachable component mapping is reconstructed from the five pinned UCM files.",
      "",
      "| Component | Decode mappings | Encode mappings |",
      "|---|---:|---:|"
    ]

    rows =
      Enum.map([:jis208, :jis212, :gb, :ksc, :greek], fn name ->
        counts = manifest.mapping_counts[name]
        "| `#{name}` | #{counts.decode} | #{counts.encode} |"
      end)

    File.write!(Path.join(root, "ICU_JIS7_JIS8.md"), Enum.join(lines ++ rows, "\n") <> "\n")
  end

  defp sha256(binary), do: :crypto.hash(:sha256, binary) |> Base.encode16(case: :lower)
end

Iconvex.Specs.Tools.ImportICUJIS.run()
