defmodule Iconvex.Specs.Tools.ImportICUCompoundText do
  @moduledoc false

  @release "78.3"
  @revision "21d1eb0f306e1141c10931e914dfc038c06121da"
  @aggregate_sha256 "29154f92a16b2da89bf446193c987e5fb91d1b8a0e4791667e4dddcf29c99c66"
  @source_url "https://github.com/unicode-org/icu/tree/#{@revision}/icu4c/source"
  @state_files %{
    1 => "icu-internal-compound-s1.ucm",
    2 => "icu-internal-compound-s2.ucm",
    3 => "icu-internal-compound-s3.ucm",
    4 => "icu-internal-compound-d1.ucm",
    5 => "icu-internal-compound-d2.ucm",
    6 => "icu-internal-compound-d3.ucm",
    7 => "icu-internal-compound-d4.ucm",
    8 => "icu-internal-compound-d5.ucm",
    9 => "icu-internal-compound-d6.ucm",
    10 => "icu-internal-compound-d7.ucm",
    11 => "icu-internal-compound-t.ucm",
    12 => "ibm-915_P100-1995.ucm",
    13 => "ibm-916_P100-1995.ucm",
    14 => "ibm-914_P100-1995.ucm",
    15 => "ibm-874_P100-1995.ucm",
    16 => "ibm-912_P100-1995.ucm",
    17 => "ibm-913_P100-2000.ucm",
    18 => "iso-8859_14-1998.ucm",
    19 => "ibm-923_P100-1998.ucm"
  }
  @escapes %{
    0 => <<0x1B, "-A">>,
    1 => <<0x1B, "-M">>,
    2 => <<0x1B, "-F">>,
    3 => <<0x1B, "-G">>,
    4 => <<0x1B, "$)A">>,
    5 => <<0x1B, "$)B">>,
    6 => <<0x1B, "$)C">>,
    7 => <<0x1B, "$)D">>,
    8 => <<0x1B, "$)G">>,
    9 => <<0x1B, "$)H">>,
    10 => <<0x1B, "$)I">>,
    11 => <<0x1B, "%G">>,
    12 => <<0x1B, "-L">>,
    13 => <<0x1B, "-H">>,
    14 => <<0x1B, "-D">>,
    15 => <<0x1B, "-T">>,
    16 => <<0x1B, "-B">>,
    17 => <<0x1B, "-C">>,
    18 => <<0x1B, "-_">>,
    19 => <<0x1B, "-b">>
  }
  @files ["ucnv_ct.cpp"] ++ Map.values(@state_files) ++ ["convrtrs.txt"]

  def run do
    root = Path.expand("..", __DIR__)
    committed = Path.join([root, "priv", "sources", "icu-#{@release}-compound-text"])
    sources = source_paths(committed)
    assert_sources!(sources)
    copy_sources(sources, committed)

    states =
      Map.new(@state_files, fn {state, filename} ->
        {state, parse_ucm(Path.join(committed, filename))}
      end)

    preferred = for cp <- 0..0xFFFF, into: <<>>, do: <<preferred_state(cp)>>
    data = %{escapes: @escapes, preferred: preferred, states: states}

    File.write!(
      Path.join(root, "priv/icu_compound_text.etf"),
      :erlang.term_to_binary(data, [:deterministic, :compressed])
    )

    sources = Enum.map(@files, &{&1, sha256(File.read!(Path.join(committed, &1)))})

    manifest = %{
      aggregate_sha256: @aggregate_sha256,
      aliases: ["COMPOUND_TEXT", "x-compound-text"],
      canonical_name: "x11-compound-text",
      format: 1,
      release: @release,
      revision: @revision,
      source_url: @source_url,
      sources: sources,
      state_counts:
        Map.new(states, fn {state, table} ->
          {state, %{decode: map_size(table.decode), encode: map_size(table.encode)}}
        end)
    }

    File.write!(
      Path.join(root, "priv/icu_compound_text_manifest.etf"),
      :erlang.term_to_binary(manifest, [:deterministic])
    )

    write_support_matrix(root, manifest)
    IO.puts("wrote ICU #{@release} X11 Compound Text tables")
  end

  defp source_paths(committed) do
    cond do
      Enum.all?(@files, &File.regular?(Path.join(committed, &1))) ->
        Enum.map(@files, &{&1, Path.join(committed, &1)})

      source_root = System.get_env("ICU_SOURCE_DIR") ->
        mappings = Path.join([source_root, "data", "mappings"])

        Enum.map(@files, fn
          "ucnv_ct.cpp" = name -> {name, Path.join([source_root, "common", name])}
          name -> {name, Path.join(mappings, name)}
        end)

      true ->
        mappings = "/private/tmp/iconvex-icu/icu4c/source/data/mappings"

        Enum.map(@files, fn
          "ucnv_ct.cpp" = name -> {name, "/private/tmp/#{name}"}
          name -> {name, Path.join(mappings, name)}
        end)
    end
  end

  defp assert_sources!(sources) do
    Enum.each(sources, fn {name, path} ->
      unless File.regular?(path),
        do: Mix.raise("missing ICU Compound Text source #{name}: #{path}")
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
      do: Mix.raise("ICU Compound Text source-set SHA-256 mismatch: #{digest}")
  end

  defp copy_sources(sources, committed) do
    File.mkdir_p!(committed)

    Enum.each(sources, fn {name, path} ->
      target = Path.join(committed, name)
      if Path.expand(path) != Path.expand(target), do: File.cp!(path, target)
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

    prefixes =
      Enum.reduce(decode, MapSet.new(), fn {bytes, _codepoint}, result ->
        if byte_size(bytes) > 1 do
          Enum.reduce(1..(byte_size(bytes) - 1), result, fn size, prefixes ->
            MapSet.put(prefixes, binary_part(bytes, 0, size))
          end)
        else
          result
        end
      end)

    %{
      decode: decode,
      encode: encode,
      max_input: decode |> Map.keys() |> Enum.map(&byte_size/1) |> Enum.max(fn -> 1 end),
      prefixes: prefixes
    }
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

  defp preferred_state(cp) do
    cond do
      cp in [0x0000, 0x0009, 0x000A] or cp in 0x0020..0x007F or cp in 0x00A0..0x00FF -> 0
      ibm912?(cp) -> 16
      ibm913?(cp) -> 17
      iso8859_14?(cp) -> 18
      ibm923?(cp) -> 19
      ibm874?(cp) -> 15
      ibm914?(cp) -> 14
      compound_s2?(cp) -> 2
      compound_s3?(cp) -> 3
      ibm916?(cp) -> 13
      ibm915?(cp) -> 12
      compound_s1?(cp) -> 1
      true -> 0xFF
    end
  end

  defp ibm915?(cp), do: cp in 0x0401..0x045F or cp == 0x2116
  defp ibm916?(cp), do: cp in 0x05D0..0x05EA or cp in [0x2017, 0x203E]

  defp compound_s3?(cp),
    do:
      cp in [0x060C, 0x061B, 0x061F, 0x200B, 0xFE74] or cp in 0x0621..0x063A or
        cp in 0x0640..0x0652 or cp in 0x0660..0x066D or cp in 0xFE70..0xFE72 or
        cp in 0xFE76..0xFEBE

  defp compound_s2?(cp), do: cp in [0x02BC, 0x02BD, 0x2015] or cp in 0x0384..0x03CE

  defp ibm914?(cp),
    do:
      cp in [
        0x0100,
        0x0101,
        0x0112,
        0x0113,
        0x0116,
        0x0117,
        0x0122,
        0x0123,
        0x012E,
        0x012F,
        0x013B,
        0x013C,
        0x0145,
        0x0146,
        0x0156,
        0x0157,
        0x0172,
        0x0173
      ] or cp in 0x0128..0x012B or cp in 0x0136..0x0138 or cp in 0x014A..0x014D or
        cp in 0x0166..0x016B

  defp ibm874?(cp), do: cp in 0x0E01..0x0E3A or cp in 0x0E3F..0x0E5B

  defp ibm912?(cp),
    do:
      cp in [
        0x0139,
        0x013A,
        0x013D,
        0x013E,
        0x0147,
        0x0150,
        0x0151,
        0x0154,
        0x0155,
        0x015E,
        0x015F,
        0x016E,
        0x016F,
        0x0170,
        0x0171,
        0x02C7,
        0x02D8,
        0x02D9,
        0x02DB,
        0x02DD
      ] or cp in 0x0102..0x0107 or cp in 0x010C..0x0111 or cp in 0x0118..0x011B or
        cp in 0x0141..0x0144 or cp in 0x0158..0x015B or cp in 0x0160..0x0165 or
        cp in 0x0179..0x017E

  defp ibm913?(cp),
    do:
      cp in [0x011C, 0x011D, 0x0120, 0x0121, 0x0134, 0x0135, 0x015C, 0x015D, 0x016C, 0x016D] or
        cp in 0x0108..0x010B or cp in 0x0124..0x0127

  defp compound_s1?(cp), do: cp in [0x011E, 0x011F, 0x0130, 0x0131] or cp in 0x0218..0x021B

  defp iso8859_14?(cp),
    do:
      cp in 0x0174..0x0177 or cp in 0x1E80..0x1E85 or
        cp in [
          0x1E0A,
          0x1E0B,
          0x1E1E,
          0x1E1F,
          0x1E40,
          0x1E41,
          0x1E56,
          0x1E57,
          0x1E60,
          0x1E61,
          0x1E6A,
          0x1E6B,
          0x1EF2,
          0x1EF3
        ]

  defp ibm923?(cp), do: cp in [0x0152, 0x0153, 0x0178, 0x20AC]
  defp precision_priority(%{precision: 0}), do: 0
  defp precision_priority(%{precision: precision}) when precision in [3, 4], do: 1
  defp precision_priority(%{precision: 1}), do: 2

  defp private_use?(codepoint),
    do:
      codepoint in 0xE000..0xF8FF or codepoint in 0xF0000..0xFFFFD or
        codepoint in 0x100000..0x10FFFD

  defp write_support_matrix(root, manifest) do
    lines = [
      "# ICU 78.3 X11 Compound Text",
      "",
      "Native Elixir port pinned to Unicode ICU revision `#{@revision}`.",
      "All nineteen mapping states and their escape designators are committed and hashed.",
      "",
      "| State | Decode mappings | Encode mappings |",
      "|---:|---:|---:|"
    ]

    rows =
      manifest.state_counts
      |> Enum.sort()
      |> Enum.map(fn {state, counts} ->
        "| #{state} | #{counts.decode} | #{counts.encode} |"
      end)

    File.write!(
      Path.join(root, "ICU_X11_COMPOUND_TEXT.md"),
      Enum.join(lines ++ rows, "\n") <> "\n"
    )
  end

  defp sha256(binary), do: :crypto.hash(:sha256, binary) |> Base.encode16(case: :lower)
end

Iconvex.Specs.Tools.ImportICUCompoundText.run()
