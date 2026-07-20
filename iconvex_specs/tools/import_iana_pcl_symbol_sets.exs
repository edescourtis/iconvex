defmodule Iconvex.Specs.Tools.ImportIANAPCLSymbolSets do
  @moduledoc false

  @source_url "https://github.com/ArtifexSoftware/ghostpdl/blob/409356a1ad15aeca1280bb91aed58564c5524540/pcl/pl/plsymbol.c"
  @source_commit "409356a1ad15aeca1280bb91aed58564c5524540"
  @source_sha256 "80f85c019f6e7de90c7e2fd804cdb0b2e74a016b4ec142e193c76f24698bb6ec"

  @specs [
    {"HP-DeskTop", "7J", ["csHPDesktop"]},
    {"HP-Legal", "1U", ["csHPLegal"]},
    {"HP-Math8", "8M", ["csHPMath8"]},
    {"HP-Pi-font", "15U", ["csHPPiFont"]},
    {"ISO-8859-1-Windows-3.0-Latin-1", "9U", ["csWindows30Latin1"]},
    {"ISO-8859-1-Windows-3.1-Latin-1", "19U", ["csWindows31Latin1"]},
    {"ISO-8859-2-Windows-Latin-2", "9E", ["csWindows31Latin2"]},
    {"ISO-8859-9-Windows-Latin-5", "5T", ["csWindows31Latin5"]},
    {"Microsoft-Publishing", "6J", ["csMicrosoftPublishing"]},
    {"PC8-Danish-Norwegian", "11U", ["csPC8DanishNorwegian"]},
    {"PC8-Turkish", "9T", ["csPC8Turkish"]},
    {"Ventura-International", "13J", ["csVenturaInternational"]},
    {"Ventura-Math", "6M", ["csVenturaMath"]},
    {"Ventura-US", "14J", ["csVenturaUS"]}
  ]

  def run do
    root = Path.expand("..", __DIR__)
    normalized = Path.join(root, "priv/sources/iana-pcl-symbol-sets/mappings.txt")
    mappings = load_mappings(normalized)
    table_dir = Path.join(root, "priv/tables")
    File.mkdir_p!(table_dir)

    encodings =
      @specs
      |> Enum.with_index(1)
      |> Enum.map(fn {{name, symbol_set, aliases}, index} ->
        mapping = Map.fetch!(mappings, symbol_set)
        id = String.to_atom("iana_pcl_symbol_set_#{index}")
        {table, decode_mappings, encode_mappings} = build_table(mapping)

        File.write!(
          Path.join(table_dir, "#{id}.etf"),
          :erlang.term_to_binary(table, [:deterministic, :compressed])
        )

        %{
          aliases: aliases,
          decode_mappings: decode_mappings,
          encode_mappings: encode_mappings,
          id: id,
          index: index,
          name: name,
          symbol_set: symbol_set
        }
      end)

    normalized_source = File.read!(normalized)

    manifest = %{
      encodings: encodings,
      format: 1,
      normalized_sha256: sha256(normalized_source),
      source_commit: @source_commit,
      source_sha256: @source_sha256,
      source_url: @source_url
    }

    File.write!(
      Path.join(root, "priv/iana_pcl_symbol_sets_manifest.etf"),
      :erlang.term_to_binary(manifest, [:deterministic, :compressed])
    )

    write_documentation(root, manifest)
    IO.puts("wrote #{length(encodings)} IANA PCL symbol-set codecs")
  end

  defp load_mappings(normalized) do
    case System.get_env("GHOSTPDL_PLSYMBOL_SOURCE") do
      nil ->
        normalized |> File.read!() |> parse_normalized()

      source_path ->
        source = File.read!(source_path)

        unless sha256(source) == @source_sha256,
          do: Mix.raise("GhostPDL plsymbol.c SHA-256 mismatch")

        mappings =
          Map.new(@specs, fn {_name, symbol_set, _aliases} ->
            {symbol_set, parse_c_mapping(source, symbol_set)}
          end)

        File.mkdir_p!(Path.dirname(normalized))
        File.write!(normalized, serialize_normalized(mappings))
        mappings
    end
  end

  defp parse_c_mapping(source, symbol_set) do
    escaped = Regex.escape(symbol_set)

    [body] =
      Regex.run(
        ~r/map_#{escaped}_unicode\s*=\s*\{.*?\{(.*?)\}\s*\};/s,
        source,
        capture: :all_but_first
      )

    body = Regex.replace(~r{/\*.*?\*/}s, body, "")

    mapping =
      ~r/0x([0-9A-Fa-f]+)/
      |> Regex.scan(body, capture: :all_but_first)
      |> Enum.map(fn [hex] -> String.to_integer(hex, 16) end)

    unless length(mapping) == 256,
      do: Mix.raise("#{symbol_set}: expected 256 mappings, got #{length(mapping)}")

    mapping
  end

  defp serialize_normalized(mappings) do
    header =
      "# IANA PCL symbol-set byte-to-Unicode facts\n" <>
        "# Extracted from #{@source_url}\n" <>
        "# GhostPDL source SHA-256: #{@source_sha256}\n"

    body =
      Enum.map_join(@specs, "", fn {_name, symbol_set, _aliases} ->
        rows =
          mappings
          |> Map.fetch!(symbol_set)
          |> Enum.with_index()
          |> Enum.map_join("", fn
            {0xFFFF, byte} -> "#{hex(byte, 2)}\t-\n"
            {codepoint, byte} -> "#{hex(byte, 2)}\t#{hex(codepoint, 4)}\n"
          end)

        "\n[#{symbol_set}]\n" <> rows
      end)

    header <> body
  end

  defp parse_normalized(source) do
    source
    |> String.split(~r/^\[([^]]+)\]\s*$/m, include_captures: true, trim: true)
    |> Enum.drop(1)
    |> Enum.chunk_every(2)
    |> Map.new(fn [header, rows] ->
      symbol_set =
        header |> String.trim() |> String.trim_leading("[") |> String.trim_trailing("]")

      mapping =
        rows
        |> String.split("\n", trim: true)
        |> Enum.reject(&String.starts_with?(&1, "#"))
        |> Enum.map(fn row ->
          [_byte, value] = String.split(row, "\t")
          if value == "-", do: 0xFFFF, else: String.to_integer(value, 16)
        end)

      unless length(mapping) == 256,
        do: Mix.raise("#{symbol_set}: expected 256 normalized rows")

      {symbol_set, mapping}
    end)
  end

  defp build_table(mapping) do
    one =
      mapping
      |> Enum.map(fn
        0xFFFF -> nil
        codepoint -> {codepoint}
      end)
      |> List.to_tuple()

    encode =
      mapping
      |> Enum.with_index()
      |> Enum.reject(fn {codepoint, _byte} -> codepoint == 0xFFFF end)
      |> Enum.reduce(%{}, fn {codepoint, byte}, result ->
        Map.put_new(result, {codepoint}, <<byte>>)
      end)

    table = %{
      encode: encode,
      many: %{},
      max_codepoints: 1,
      max_input: 1,
      one: one,
      prefixes: MapSet.new()
    }

    {table, Enum.count(mapping, &(&1 != 0xFFFF)), map_size(encode)}
  end

  defp write_documentation(root, manifest) do
    rows =
      Enum.map_join(manifest.encodings, "", fn entry ->
        "| `#{entry.name}` | `#{entry.symbol_set}` | #{entry.decode_mappings} | " <>
          "#{entry.encode_mappings} |\n"
      end)

    document = """
    # IANA PCL Symbol Sets

    These codecs implement IANA-registered HP PCL symbol sets. The byte-to-Unicode
    facts were extracted reproducibly from the pinned GhostPDL PCL implementation.

    - Source commit: `#{manifest.source_commit}`
    - Source SHA-256: `#{manifest.source_sha256}`
    - Normalized mapping SHA-256: `#{manifest.normalized_sha256}`

    | Encoding | PCL set | Decode mappings | Encode mappings |
    |---|---:|---:|---:|
    #{rows}
    """

    File.write!(Path.join(root, "IANA_PCL_SYMBOL_SETS.md"), document)
  end

  defp hex(integer, width),
    do: integer |> Integer.to_string(16) |> String.upcase() |> String.pad_leading(width, "0")

  defp sha256(binary), do: :crypto.hash(:sha256, binary) |> Base.encode16(case: :lower)
end

Iconvex.Specs.Tools.ImportIANAPCLSymbolSets.run()
