defmodule Iconvex.Specs.Tools.ImportISOIRModern do
  @moduledoc false

  @aggregate_sha256 "ad53201db2a9fa430c3854069b7f63437a30728e51d9dcf323e937cdebaf5ed2"
  @numbers [164, 167, 182, 200, 201, 204, 205, 206, 207, 208, 232, 234]
  @unicode_data_file "UnicodeData-17.0.0.txt"
  @source_files Enum.map(@numbers, &"#{&1}.pdf") ++ [@unicode_data_file]

  @specs [
    %{number: 164, mode: :hebrew_supplementary, aliases: ["HEBREW-SUPPLEMENTARY-ISO-IR-164"]},
    %{
      number: 167,
      mode: :arabic_french_german,
      aliases: ["ARABIC-FRENCH-GERMAN-ISO-IR-167"]
    },
    %{number: 182, mode: :welsh, aliases: ["WELSH-ISO-IR-182"]},
    %{number: 200, mode: :position_unicode, aliases: ["URALIC-SUPPLEMENTARY-CYRILLIC"]},
    %{number: 201, mode: :position_unicode, aliases: ["VOLGAIC-SUPPLEMENTARY-CYRILLIC"]},
    %{number: 204, mode: {:euro, :iso8859_1}, aliases: ["LATIN-1-EURO-ISO-IR-204"]},
    %{number: 205, mode: {:euro, :iso8859_4}, aliases: ["LATIN-4-EURO-ISO-IR-205"]},
    %{number: 206, mode: {:euro, :iso8859_13}, aliases: ["LATIN-7-EURO-ISO-IR-206"]},
    %{number: 207, mode: :position_unicode_7bit, aliases: ["IRISH-GAELIC-ISO-IR-207"]},
    %{number: 208, mode: :position_unicode, aliases: ["OGHAM-ISO-IR-208"]},
    %{number: 232, mode: :turkmen, aliases: ["TURKMEN-ISO-IR-232"]},
    %{number: 234, mode: :annex_high_bit, aliases: ["LATIN-HEBREW-ISO-IR-234"]}
  ]

  @welsh_replacements %{
    0xA8 => 0x1E80,
    0xAA => 0x1E82,
    0xAC => 0x1EF2,
    0xAF => 0x0178,
    0xB8 => 0x1E81,
    0xBA => 0x1E83,
    0xBC => 0x1EF3,
    0xBD => 0x1E84,
    0xBE => 0x1E85,
    0xD0 => 0x0174,
    0xDE => 0x0176,
    0xF0 => 0x0175,
    0xFE => 0x0177
  }

  @turkmen [
    {0xB1, 0x0041},
    {0xB2, 0x0042},
    {0xB3, 0x00C7},
    {0xB4, 0x0044},
    {0xB5, 0x0045},
    {0xB6, 0x00C4},
    {0xB7, 0x0046},
    {0xB8, 0x0047},
    {0xB9, 0x0048},
    {0xBA, 0x0049},
    {0xBB, 0x004A},
    {0xBC, 0x017D},
    {0xBD, 0x004B},
    {0xBE, 0x004C},
    {0xBF, 0x004D},
    {0xC0, 0x004E},
    {0xC1, 0x0147},
    {0xC2, 0x004F},
    {0xC3, 0x00D6},
    {0xC4, 0x0050},
    {0xC5, 0x0052},
    {0xC6, 0x0053},
    {0xC7, 0x015E},
    {0xC8, 0x0054},
    {0xC9, 0x0055},
    {0xCA, 0x00DC},
    {0xCB, 0x0057},
    {0xCC, 0x0059},
    {0xCD, 0x00DD},
    {0xCE, 0x005A},
    {0xD0, 0x2116},
    {0xD1, 0x0061},
    {0xD2, 0x0062},
    {0xD3, 0x00E7},
    {0xD4, 0x0064},
    {0xD5, 0x0065},
    {0xD6, 0x00E4},
    {0xD7, 0x0066},
    {0xD8, 0x0067},
    {0xD9, 0x0068},
    {0xDA, 0x0069},
    {0xDB, 0x006A},
    {0xDC, 0x017E},
    {0xDD, 0x006B},
    {0xDE, 0x006C},
    {0xDF, 0x006D},
    {0xE0, 0x006E},
    {0xE1, 0x0148},
    {0xE2, 0x006F},
    {0xE3, 0x00F6},
    {0xE4, 0x0070},
    {0xE5, 0x0072},
    {0xE6, 0x0073},
    {0xE7, 0x015F},
    {0xE8, 0x0074},
    {0xE9, 0x0075},
    {0xEA, 0x00FC},
    {0xEB, 0x0077},
    {0xEC, 0x0079},
    {0xED, 0x00FD},
    {0xEE, 0x007A}
  ]

  @iso_ir_200_unicode_17 %{
    0xA4 => {0x04EC, "CYRILLIC CAPITAL LETTER E WITH DIAERESIS"},
    0xA9 => {0x052E, "CYRILLIC CAPITAL LETTER EL WITH DESCENDER"},
    0xAE => {0x048E, "CYRILLIC CAPITAL LETTER ER WITH TICK"},
    0xF4 => {0x04ED, "CYRILLIC SMALL LETTER E WITH DIAERESIS"},
    0xF9 => {0x052F, "CYRILLIC SMALL LETTER EL WITH DESCENDER"},
    0xFE => {0x048F, "CYRILLIC SMALL LETTER ER WITH TICK"},
    0xFF => {0x02EE, "MODIFIER LETTER DOUBLE APOSTROPHE"}
  }

  @iso_ir_167_non_arabic %{
    0xA0 => 0x00A0,
    0xA4 => 0x00A4,
    0xA8 => 0x00C8,
    0xA9 => 0x00C9,
    0xAA => 0x00CA,
    0xAB => 0x00CB,
    0xAC => 0x060C,
    0xAD => 0x00AD,
    0xAE => 0x00CE,
    0xAF => 0x00CF,
    0xB0 => 0x00C0,
    0xB1 => 0x00C2,
    0xB2 => 0x00E2,
    0xB3 => 0x00C4,
    0xB4 => 0x00DF,
    0xB5 => 0x00E4,
    0xB6 => 0x00C7,
    0xB7 => 0x00E7,
    0xB8 => 0x00E8,
    0xB9 => 0x00E9,
    0xBA => 0x00EA,
    0xBB => 0x061B,
    0xBC => 0x00EB,
    0xBD => 0x00EE,
    0xBE => 0x00EF,
    0xBF => 0x061F,
    0xC0 => 0x00E0,
    0xDB => 0x00D4,
    0xDC => 0x00D6,
    0xDD => 0x00DA,
    0xDE => 0x00DB,
    0xDF => 0x00DC,
    0xFB => 0x00F4,
    0xFC => 0x00F6,
    0xFD => 0x00F9,
    0xFE => 0x00FB,
    0xFF => 0x00FC
  }

  def run do
    root = Path.expand("..", __DIR__)
    committed = Path.join([root, "priv", "sources", "iso-ir-modern"])
    source_root = System.get_env("ISO_IR_SOURCE_DIR") || committed
    assert_source_set!(source_root)
    copy_sources(source_root, committed)
    validate_unicode_names!(committed)
    table_dir = Path.join(root, "priv/tables")
    File.mkdir_p!(table_dir)

    encodings =
      @specs
      |> Enum.with_index(1)
      |> Enum.map(fn {spec, index} -> import(spec, index, committed, table_dir) end)

    manifest = %{
      aggregate_sha256: @aggregate_sha256,
      auxiliary_sources: [
        %{
          file: @unicode_data_file,
          sha256: sha256(File.read!(Path.join(committed, @unicode_data_file))),
          url: "https://www.unicode.org/Public/17.0.0/ucd/UnicodeData.txt"
        }
      ],
      encodings: encodings,
      format: 1,
      source: "ISO International Register of Coded Character Sets"
    }

    File.write!(
      Path.join(root, "priv/iso_ir_modern_manifest.etf"),
      :erlang.term_to_binary(manifest, [:deterministic, :compressed])
    )

    write_support_matrix(root, encodings)
    IO.puts("wrote #{length(encodings)} modern ISO-IR coded-set codecs")
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
      do: Mix.raise("ISO-IR source-set SHA-256 mismatch: #{digest}")
  end

  defp copy_sources(source_root, committed) do
    if Path.expand(source_root) != Path.expand(committed) do
      File.mkdir_p!(committed)

      Enum.each(@source_files, fn file ->
        File.cp!(Path.join(source_root, file), Path.join(committed, file))
      end)
    end
  end

  defp import(spec, index, source_root, table_dir) do
    source_file = "#{spec.number}.pdf"
    source_path = Path.join(source_root, source_file)
    mappings = mappings(spec.mode, source_path)
    id = String.to_atom("iso_ir_modern_#{index}")
    canonical_encode = canonical_encode(mappings)
    table = build_table(mappings, canonical_encode)

    File.write!(
      Path.join(table_dir, "#{id}.etf"),
      :erlang.term_to_binary(table, [:deterministic, :compressed])
    )

    %{
      aliases: spec.aliases,
      canonical_encode: canonical_encode,
      decode_mappings: map_size(mappings),
      encode_mappings: map_size(canonical_encode),
      id: id,
      index: index,
      mappings: Enum.sort(mappings),
      name: "ISO-IR-#{spec.number}",
      number: spec.number,
      sha256: sha256(File.read!(source_path)),
      source_file: source_file,
      source_url: "https://itscj.ipsj.or.jp/ir/#{spec.number}.pdf"
    }
  end

  defp mappings(:welsh, _source_path),
    do: Map.merge(identity(0..255), @welsh_replacements)

  defp mappings(:hebrew_supplementary, _source_path) do
    hebrew = Map.new(0xE0..0xFA, fn byte -> {byte, 0x05D0 + byte - 0xE0} end)
    Map.merge(identity(0..0x9F), hebrew)
  end

  defp mappings(:arabic_french_german, _source_path) do
    arabic_letters = Map.new(0xC1..0xDA, fn byte -> {byte, 0x0621 + byte - 0xC1} end)
    arabic_marks = Map.new(0xE0..0xF2, fn byte -> {byte, 0x0640 + byte - 0xE0} end)

    identity(0..0x9F)
    |> Map.merge(@iso_ir_167_non_arabic)
    |> Map.merge(arabic_letters)
    |> Map.merge(arabic_marks)
  end

  defp mappings({:euro, :iso8859_1}, _source_path),
    do: Map.put(identity(0..255), 0xA4, 0x20AC)

  defp mappings({:euro, base}, _source_path),
    do: base_mapping(base) |> Map.put(0xA4, 0x20AC)

  defp mappings(:position_unicode, source_path),
    do:
      identity(0..0x9F)
      |> Map.merge(parse_position_unicode(extract_text(source_path)))
      |> add_unicode_17_assignments(source_path)

  defp mappings(:position_unicode_7bit, source_path),
    do: Map.merge(identity(0..0x7F), parse_position_unicode(extract_text(source_path)))

  defp mappings(:turkmen, _source_path),
    do: Map.merge(identity(0..0x9F), Map.new(@turkmen))

  defp mappings(:annex_high_bit, source_path) do
    rows =
      Regex.scan(~r/(?m)^\s*([0-9A-F]{2})\s+U\+([0-9A-F]{4,6})\s*$/, extract_text(source_path),
        capture: :all_but_first
      )
      |> Map.new(fn [encoded, unicode] ->
        {String.to_integer(encoded, 16) + 0x80, String.to_integer(unicode, 16)}
      end)

    Map.merge(identity(0..0x9F), rows)
  end

  defp parse_position_unicode(text) do
    Regex.scan(
      ~r/(?m)^\s*([0-9]{1,2})\/([0-9]{2})\s+.*?U\+([0-9A-F]{4,6})\s*$/,
      text,
      capture: :all_but_first
    )
    |> Map.new(fn [column, row, unicode] ->
      byte = String.to_integer(column) * 16 + String.to_integer(row)
      {byte, String.to_integer(unicode, 16)}
    end)
  end

  defp extract_text(source_path) do
    executable =
      System.get_env("PDFTOTEXT") ||
        System.find_executable("pdftotext") ||
        Mix.raise("pdftotext is required; set PDFTOTEXT to its absolute path")

    case System.cmd(executable, ["-layout", source_path, "-"]) do
      {text, 0} -> text
      {output, status} -> Mix.raise("pdftotext failed (#{status}): #{output}")
    end
  end

  defp add_unicode_17_assignments(mappings, source_path) do
    if Path.basename(source_path) == "200.pdf" do
      Map.merge(
        mappings,
        Map.new(@iso_ir_200_unicode_17, fn {byte, {codepoint, _name}} -> {byte, codepoint} end)
      )
    else
      mappings
    end
  end

  defp validate_unicode_names!(source_root) do
    names =
      source_root
      |> Path.join(@unicode_data_file)
      |> File.stream!()
      |> Enum.reduce(%{}, fn line, result ->
        case String.split(line, ";", parts: 3) do
          [codepoint, name, _rest] -> Map.put(result, name, String.to_integer(codepoint, 16))
          _ -> result
        end
      end)

    Enum.each(@iso_ir_200_unicode_17, fn {_byte, {codepoint, name}} ->
      unless names[name] == codepoint,
        do: Mix.raise("Unicode 17 name mismatch for #{name}")
    end)
  end

  defp base_mapping(id) do
    iconvex_root =
      System.get_env("ICONVEX_PATH") || Path.expand("../../iconvex", __DIR__)

    table =
      [iconvex_root, "priv", "tables", "#{id}.etf"]
      |> Path.join()
      |> File.read!()
      |> :erlang.binary_to_term()

    0..255
    |> Enum.reduce(%{}, fn byte, result ->
      case elem(table.one, byte) do
        {codepoint} -> Map.put(result, byte, codepoint)
        nil -> result
      end
    end)
  end

  defp canonical_encode(mappings) do
    mappings
    |> Enum.sort()
    |> Enum.reduce(%{}, fn {byte, codepoint}, result -> Map.put_new(result, codepoint, byte) end)
  end

  defp build_table(mappings, canonical_encode) do
    one =
      0..255
      |> Enum.map(fn byte ->
        case Map.fetch(mappings, byte) do
          {:ok, codepoint} -> {codepoint}
          :error -> nil
        end
      end)
      |> List.to_tuple()

    %{
      encode: Map.new(canonical_encode, fn {codepoint, byte} -> {{codepoint}, <<byte>>} end),
      many: %{},
      max_codepoints: 1,
      max_input: 1,
      one: one,
      prefixes: MapSet.new()
    }
  end

  defp identity(range), do: Map.new(range, &{&1, &1})

  defp write_support_matrix(root, encodings) do
    header = [
      "# Modern ISO-IR coded-set registrations",
      "",
      "These codecs are generated from pinned official ISO International Register PDFs.",
      "Supplementary G1 sets are exposed as usable 8-bit codes combined with ISO-IR-6",
      "and identity C0/C1 controls; the registered graphic positions remain exact.",
      "",
      "| Encoding | Decode mappings | Encode mappings | Source SHA-256 |",
      "|---|---:|---:|---|"
    ]

    rows =
      Enum.map(encodings, fn entry ->
        "| `#{entry.name}` | #{entry.decode_mappings} | #{entry.encode_mappings} | `#{entry.sha256}` |"
      end)

    File.write!(
      Path.join(root, "ISO_IR_MODERN_ENCODINGS.md"),
      Enum.join(header ++ rows, "\n") <> "\n"
    )
  end

  defp sha256(contents), do: :crypto.hash(:sha256, contents) |> Base.encode16(case: :lower)
end

Iconvex.Specs.Tools.ImportISOIRModern.run()
