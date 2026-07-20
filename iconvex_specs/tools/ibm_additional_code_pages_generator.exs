defmodule Iconvex.Specs.IBMAdditionalCodePages.Generator do
  @moduledoc """
  Deterministically regenerates the seven IBM/DEC source-exact mapping vectors.

  The four composite profiles join IBM GCGID page positions to pinned IBM/ICU
  UCM Unicode bindings. IBM-293 VPUA has explicit first priority for its CP310
  profile; the four documented context collisions and page-specific SM910
  choice are resolved explicitly. The IBM/tnz profile is parsed from its exact
  Python `DECODING_TABLE`. DEC 8-bit C0/C1 structure is combined with the IBM
  CPGID 1287/1288 graphic rows independently identified by the DEC manual.
  """

  import Bitwise

  @pair_specs [
    {"CP00293.txt", "icu-data-archive/ibm-293_P100-1995.ucm"},
    {"CP00437.txt", "icu-data-archive/ibm-437_P100-1995.ucm"},
    {"CP00775.txt", "icu-data-archive/ibm-775_P100-1996.ucm"},
    {"CP00850.txt", "icu-78.3/ibm-850_P100-1995.ucm"},
    {"CP00857.txt", "icu-data-archive/ibm-857_P100-1995.ucm"},
    {"CP00875.txt", "icu-data-archive/ibm-875_P100-1995.ucm"},
    {"CP01254.txt", "icu-data-archive/ibm-1254_P100-1995.ucm"}
  ]

  @context_overrides %{
    "SM240000" => 0x00A7,
    "SM250000" => 0x00B6,
    "SM570000" => 0x2022,
    "SD630000" => 0x00B7
  }

  @map_names [
    "cp310-293-p100-composite-vpua.map",
    "cp310-tnz-07d60f4.map",
    "cp907-cdra-p100-vpua-composite.map",
    "cp1116-850-p100-composite.map",
    "cp1117-437-p100-composite.map",
    "cp1287-dec-1994.map",
    "cp1288-dec-1994.map"
  ]

  @spec generate(Path.t()) :: %{String.t() => binary()}
  def generate(source_dir) do
    sources_root = Path.expand("..", source_dir)
    crosswalk = build_crosswalk(source_dir, sources_root)
    tnz = parse_tnz(Path.join(source_dir, "ibm-tnz-cp310-07d60f4.py"))

    cp310_target = parse_cp_registry(Path.join(source_dir, "CP00310.txt"))
    cp293_target = parse_cp_registry(Path.join(source_dir, "CP00293.txt"))

    cp293_ucm =
      parse_ucm(Path.join(sources_root, "icu-data-archive/ibm-293_P100-1995.ucm"))

    cp310_composite =
      cp310_composite(cp310_target, cp293_target, cp293_ucm, crosswalk, tnz)

    cp907 =
      source_dir
      |> Path.join("CP00907.pdf")
      |> parse_ibm_grid_pdf()
      |> resolve_target!(crosswalk, 0x266B)

    cp1116 =
      source_dir
      |> Path.join("CP01116.pdf")
      |> parse_ibm_grid_pdf()
      |> resolve_target!(crosswalk, 0x266C)

    cp1117 =
      source_dir
      |> Path.join("CP01117.pdf")
      |> parse_ibm_grid_pdf()
      |> resolve_target!(crosswalk, 0x266B)

    cp1287 =
      source_dir
      |> Path.join("CP01287.txt")
      |> parse_cp_registry()
      |> resolve_target!(crosswalk, nil)
      |> add_dec_controls()

    cp1288 =
      source_dir
      |> Path.join("CP01288.txt")
      |> parse_cp_registry()
      |> resolve_target!(crosswalk, nil)
      |> add_dec_controls()

    %{
      "cp310-293-p100-composite-vpua.map" => render(cp310_composite),
      "cp310-tnz-07d60f4.map" =>
        tnz
        |> Enum.reject(fn {_byte, codepoint} -> codepoint == 0xFFFD end)
        |> Map.new()
        |> render(),
      "cp907-cdra-p100-vpua-composite.map" => render(cp907),
      "cp1116-850-p100-composite.map" => render(cp1116),
      "cp1117-437-p100-composite.map" => render(cp1117),
      "cp1287-dec-1994.map" => render(cp1287),
      "cp1288-dec-1994.map" => render(cp1288)
    }
  end

  @spec write!(Path.t()) :: :ok
  def write!(source_dir) do
    generated = generate(source_dir)

    for name <- @map_names do
      File.write!(Path.join(source_dir, name), Map.fetch!(generated, name))
    end

    :ok
  end

  defp build_crosswalk(source_dir, sources_root) do
    Enum.reduce(@pair_specs, %{}, fn {registry_name, ucm_relative}, crosswalk ->
      registry = parse_cp_registry(Path.join(source_dir, registry_name))
      ucm = parse_ucm(Path.join(sources_root, ucm_relative))

      Enum.reduce(registry, crosswalk, fn {byte, gcgid}, acc ->
        case Map.get(ucm, byte, []) do
          [] ->
            acc

          candidates ->
            Map.update(
              acc,
              gcgid,
              [select_candidate(candidates)],
              &[select_candidate(candidates) | &1]
            )
        end
      end)
    end)
  end

  defp cp310_composite(target, cp293, cp293_ucm, crosswalk, tnz) do
    cp293_by_gcgid = Map.new(cp293, fn {byte, gcgid} -> {gcgid, byte} end)

    Map.new(target, fn {byte, gcgid} ->
      codepoint =
        with {:ok, cp293_byte} <- Map.fetch(cp293_by_gcgid, gcgid),
             [_ | _] = candidates <- Map.get(cp293_ucm, cp293_byte, []) do
          select_candidate(candidates)
        else
          _ -> resolve_gcgid(gcgid, crosswalk, nil) || Map.fetch!(tnz, byte)
        end

      {byte, codepoint}
    end)
  end

  defp resolve_target!(target, crosswalk, sm910) do
    Enum.reduce(target, %{}, fn {byte, gcgid}, resolved ->
      case resolve_gcgid(gcgid, crosswalk, sm910) do
        nil -> raise "unresolved GCGID #{gcgid} at byte #{hex_byte(byte)}"
        codepoint -> Map.put(resolved, byte, codepoint)
      end
    end)
  end

  defp resolve_gcgid("SM910000", _crosswalk, sm910) when is_integer(sm910), do: sm910

  defp resolve_gcgid(gcgid, crosswalk, _sm910) do
    case Map.fetch(@context_overrides, gcgid) do
      {:ok, codepoint} ->
        codepoint

      :error ->
        values = crosswalk |> Map.get(gcgid, []) |> MapSet.new() |> MapSet.to_list()

        case values do
          [codepoint] -> codepoint
          [] -> nil
          _ -> raise "ambiguous GCGID #{gcgid}: #{inspect(Enum.sort(values))}"
        end
    end
  end

  defp add_dec_controls(mapping) do
    controls = Map.new(Enum.concat([0x00..0x1F, 0x7F..0x9F]), &{&1, &1})
    Map.merge(mapping, controls)
  end

  defp parse_cp_registry(path) do
    path
    |> File.stream!([], :line)
    |> Enum.reduce(%{}, fn line, mapping ->
      case Regex.run(
             ~r/^([0-9A-F]{2})(?:\s+([A-Z]{2}\d{6})(?:\s+.*)?)?\s*$/,
             String.trim_trailing(line),
             capture: :all_but_first
           ) do
        [byte_hex, gcgid] when gcgid != "" ->
          Map.put(mapping, String.to_integer(byte_hex, 16), gcgid)

        _ ->
          mapping
      end
    end)
  end

  defp parse_ucm(path) do
    {_inside?, mapping} =
      path
      |> File.stream!([], :line)
      |> Enum.reduce({false, %{}}, fn line, {inside?, mapping} ->
        trimmed = String.trim(line)

        cond do
          trimmed == "CHARMAP" ->
            {true, mapping}

          trimmed == "END CHARMAP" ->
            {false, mapping}

          inside? ->
            case Regex.run(
                   ~r/^<U([0-9A-Fa-f]{4,6})>\s+((?:\\x[0-9A-Fa-f]{2})+)\s+\|([0-4])/,
                   line,
                   capture: :all_but_first
                 ) do
              [unicode_hex, encoded, precision] ->
                units =
                  Regex.scan(~r/\\x([0-9A-Fa-f]{2})/, encoded, capture: :all_but_first)
                  |> List.flatten()

                case units do
                  [byte_hex] ->
                    candidate =
                      {String.to_integer(unicode_hex, 16), String.to_integer(precision)}

                    {true,
                     Map.update(
                       mapping,
                       String.to_integer(byte_hex, 16),
                       [candidate],
                       &[candidate | &1]
                     )}

                  _ ->
                    {true, mapping}
                end

              nil ->
                {true, mapping}
            end

          true ->
            {inside?, mapping}
        end
      end)

    mapping
  end

  defp select_candidate(candidates) do
    graphic = Enum.reject(candidates, fn {codepoint, _precision} -> control?(codepoint) end)
    pool = if graphic == [], do: candidates, else: graphic

    {codepoint, _precision} =
      Enum.min_by(pool, fn {codepoint, precision} ->
        {if(precision == 0, do: 0, else: 1), precision, codepoint}
      end)

    codepoint
  end

  defp control?(codepoint), do: codepoint < 0x20 or codepoint in 0x7F..0x9F

  defp parse_tnz(path) do
    entries =
      path
      |> File.stream!([], :line)
      |> Enum.flat_map(fn line ->
        case Regex.run(
               ~r/^\s+'([^']*)'\s+# 0x([0-9A-Fa-f]{2})/,
               line,
               capture: :all_but_first
             ) do
          [literal, byte_hex] ->
            [{String.to_integer(byte_hex, 16), python_literal_codepoint(literal)}]

          nil ->
            []
        end
      end)

    if length(entries) != 256 or Enum.map(entries, &elem(&1, 0)) != Enum.to_list(0..255) do
      raise "IBM/tnz DECODING_TABLE did not contain exactly 256 ordered rows"
    end

    Map.new(entries)
  end

  defp python_literal_codepoint("\\U" <> hex) when byte_size(hex) == 8,
    do: String.to_integer(hex, 16)

  defp python_literal_codepoint("\\u" <> hex) when byte_size(hex) == 4,
    do: String.to_integer(hex, 16)

  defp python_literal_codepoint(literal) do
    case String.to_charlist(literal) do
      [codepoint] -> codepoint
      _ -> raise "unsupported IBM/tnz Python literal #{inspect(literal)}"
    end
  end

  defp parse_ibm_grid_pdf(path) do
    content = path |> File.read!() |> pdf_lzw_stream()

    cells =
      Regex.scan(
        ~r/[-0-9.]+ 0 0 [-0-9.]+ ([-0-9.]+) ([-0-9.]+) Tm\s+(?:[-0-9.]+ Tc\s+)?\(([A-Z]{2}\d{6})\)Tj/,
        content,
        capture: :all_but_first
      )

    mapping =
      Enum.reduce(cells, %{}, fn [x_text, y_text, gcgid], mapping ->
        high = round((String.to_float(x_text) - 61.7) / 32.45)
        low = round((605.9 - String.to_float(y_text)) / 28.8)

        if high not in 0..15 or low not in 0..15 do
          raise "out-of-grid IBM PDF cell #{inspect({x_text, y_text, gcgid})}"
        end

        byte = high * 16 + low

        if Map.has_key?(mapping, byte) do
          raise "duplicate IBM PDF byte #{hex_byte(byte)}"
        end

        Map.put(mapping, byte, gcgid)
      end)

    if map_size(mapping) != length(cells) do
      raise "IBM PDF grid extraction lost cells in #{path}"
    end

    mapping
  end

  defp pdf_lzw_stream(pdf) do
    pattern =
      ~r/<<\s*\/Length\s+(\d+)\s*\/Filter\s+\/LZWDecode\s*>>\s*stream\r?\n/

    [_prefix, length_text] = Regex.run(pattern, pdf)
    [{start, prefix_size} | _] = Regex.run(pattern, pdf, return: :index)
    compressed_size = String.to_integer(length_text)
    compressed = binary_part(pdf, start + prefix_size, compressed_size)
    decoded = lzw_decode(compressed)

    if not String.contains?(decoded, "(HEX)Tj") do
      raise "decoded PDF stream is not an IBM code-page grid"
    end

    decoded
  end

  defp lzw_decode(data) do
    dictionary = Map.new(0..255, &{&1, <<&1>>})
    lzw_loop(data, 0, 9, dictionary, 258, nil, [])
  end

  defp lzw_loop(data, bit_offset, width, dictionary, next_code, previous, output) do
    if bit_offset + width > bit_size(data) do
      raise "truncated PDF LZW stream"
    end

    <<_::size(bit_offset), code::size(width), _::bitstring>> = data
    next_offset = bit_offset + width

    case code do
      256 ->
        reset = Map.new(0..255, &{&1, <<&1>>})
        lzw_loop(data, next_offset, 9, reset, 258, nil, output)

      257 ->
        output |> :lists.reverse() |> IO.iodata_to_binary()

      _ ->
        entry =
          case Map.fetch(dictionary, code) do
            {:ok, value} ->
              value

            :error when code == next_code and is_binary(previous) ->
              previous <> binary_part(previous, 0, 1)

            :error ->
              raise "invalid PDF LZW code #{code} at bit #{bit_offset}"
          end

        {dictionary, next_code, width} =
          if is_binary(previous) and next_code <= 4_095 do
            dictionary = Map.put(dictionary, next_code, previous <> binary_part(entry, 0, 1))
            next_code = next_code + 1

            width =
              if width < 12 and next_code == (1 <<< width) - 1,
                do: width + 1,
                else: width

            {dictionary, next_code, width}
          else
            {dictionary, next_code, width}
          end

        lzw_loop(data, next_offset, width, dictionary, next_code, entry, [entry | output])
    end
  end

  defp render(mapping) do
    Enum.map_join(0..255, fn byte ->
      rhs =
        case Map.fetch(mapping, byte) do
          {:ok, codepoint} -> "U+" <> hex_codepoint(codepoint)
          :error -> "UNDEFINED"
        end

      hex_byte(byte) <> "=" <> rhs <> "\n"
    end)
  end

  defp hex_byte(byte),
    do: byte |> Integer.to_string(16) |> String.pad_leading(2, "0") |> String.upcase()

  defp hex_codepoint(codepoint),
    do: codepoint |> Integer.to_string(16) |> String.pad_leading(4, "0") |> String.upcase()
end

if "--write" in System.argv() do
  source_dir =
    Path.expand("../priv/sources/ibm-additional-code-pages", __DIR__)

  :ok = Iconvex.Specs.IBMAdditionalCodePages.Generator.write!(source_dir)
  IO.puts("regenerated seven IBM/DEC mapping vectors")
end
