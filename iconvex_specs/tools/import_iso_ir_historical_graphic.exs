defmodule Iconvex.Specs.Tools.ImportISOIRHistoricalGraphic do
  @moduledoc false

  @registrations [
    {31, ["GREEK-BIBLIOGRAPHIC-1976"],
     "2006784a60655960304cc9ceeb05599355242d83352e0ebbe2aff4fb8eef14f2"},
    {38, ["DIN-31624", "DIN_31624"],
     "42ff603c9fbaf7518ea3253568a2e88f7accf8ef00635486e031c0603a2665cd"},
    {39, ["ISO-6438", "DIN-31625"],
     "15510e5c252717ffbff519a7beb8a07cb26295be9111ad527016cddfd61826c9"},
    {53, ["ISO-5426", "ISO_5426:1980"],
     "cc37311a58fee1c31868b1486fbde279a7f00ee9a6a496642a2dfa2731ead18f"},
    {59, ["CODAR-U", "CODARU"],
     "fcbf4dfa7d522a9332ef6cd1cb73c7ab2531fdccbbd1b330dca2bd7e47d23862"},
    {198, ["LATIN-HEBREW-ISO-IR-198"],
     "acbf5b215a37a343e90f849106b118f532ab9c35340e27a1768382930c8f3aba"}
  ]

  @unicode_mapping_sources %{
    38 => %{
      crosscheck_revision: "4bf9adbd874894d2484de1664969de43e4206492",
      crosscheck_sha256: "28f856d12347859c9cb7f10361c813c4a4f3f7c9d33911544b50c7897748d860",
      crosscheck_url:
        "https://github.com/pikelang/Pike/blob/4bf9adbd874894d2484de1664969de43e4206492/src/modules/_Charset/tables.c"
    },
    39 => %{
      mapping_filename: "039-unicode.pdf",
      mapping_sha256: "d4872f2e9b75cc011b63c60e75e22a36358228e85f56dc35817624fd4250b498",
      mapping_url: "https://www.unicode.org/L2/L2000/00223-map-6438.pdf"
    },
    59 => %{
      crosscheck_revision: "4bf9adbd874894d2484de1664969de43e4206492",
      crosscheck_sha256: "28f856d12347859c9cb7f10361c813c4a4f3f7c9d33911544b50c7897748d860",
      crosscheck_url:
        "https://github.com/pikelang/Pike/blob/4bf9adbd874894d2484de1664969de43e4206492/src/modules/_Charset/tables.c"
    }
  }

  @greek_diacritics %{
    0x21 => {0x0300},
    0x22 => {0x0301},
    0x23 => {0x0308, 0x0300},
    0x24 => {0x0342},
    0x25 => {0x0313},
    0x26 => {0x0314},
    0x27 => {0x0313, 0x0301},
    0x28 => {0x0314, 0x0301},
    0x29 => {0x0308},
    0x2A => {0x0345},
    0x2B => {0x0313, 0x0300},
    0x2C => {0x0314, 0x0300},
    0x2D => {0x0313, 0x0342},
    0x2E => {0x0314, 0x0342},
    0x2F => {0x0308, 0x0301},
    0x35 => {0x1FBF},
    0x36 => {0x1FFE},
    0x37 => {0x1FCE},
    0x38 => {0x1FDE},
    0x3B => {0x1FCD},
    0x3C => {0x1FDD},
    0x3D => {0x1FCF},
    0x3E => {0x1FDF}
  }

  @greek_punctuation %{
    0x59 => {0x0387},
    0x5A => {0x00AB},
    0x5B => {0x00BB},
    0x5C => {0x201C},
    0x5D => {0x201D},
    0x5E => {0x0374},
    0x5F => {0x0375},
    0x79 => {0x03C2},
    0x7A => {0x03DD},
    0x7B => {0x03DF},
    0x7C => {0x03E1},
    0x7D => {0x03DB}
  }

  def run do
    root = Path.expand("..", __DIR__)
    normalized = Path.join(root, "priv/sources/iso-ir-historical-graphic/mappings.txt")
    mappings = load_mappings(normalized)
    registration_dir = Path.join(root, "priv/sources/iso-ir-historical-graphic/registrations")
    materialize_registrations(registration_dir)

    materialize_unicode_mappings(
      Path.join(root, "priv/sources/iso-ir-historical-graphic/unicode-mappings")
    )

    table_dir = Path.join(root, "priv/tables")
    File.mkdir_p!(table_dir)

    encodings =
      @registrations
      |> Enum.with_index(1)
      |> Enum.map(fn {{registration, aliases, registration_sha256}, index} ->
        id = String.to_atom("iso_ir_historical_graphic_#{registration}")
        {table, decode_mappings, encode_mappings} = build_table(mappings[registration])

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
          name: "ISO-IR-#{registration}",
          registration: registration,
          registration_sha256: registration_sha256,
          registration_url:
            "https://itscj.ipsj.or.jp/ir/#{registration |> Integer.to_string() |> String.pad_leading(3, "0")}.pdf"
        }
        |> Map.merge(Map.get(@unicode_mapping_sources, registration, %{}))
      end)

    manifest = %{
      encodings: encodings,
      format: 1,
      normalized_sha256: normalized |> File.read!() |> sha256()
    }

    File.write!(
      Path.join(root, "priv/iso_ir_historical_graphic_manifest.etf"),
      :erlang.term_to_binary(manifest, [:deterministic, :compressed])
    )

    write_documentation(root, manifest)
    IO.puts("wrote #{length(encodings)} historical ISO-IR graphic-set codecs")
  end

  defp load_mappings(normalized) do
    if File.exists?(normalized) do
      mappings = normalized |> File.read!() |> parse_normalized()

      complete =
        Map.merge(mappings, %{
          38 => din_31624(),
          39 => iso_6438(),
          53 => iso_5426(),
          59 => codar_u()
        })

      if mappings == complete do
        mappings
      else
        File.write!(normalized, serialize_normalized(complete))
        complete
      end
    else
      iso8859_table =
        System.fetch_env!("ICONVEX_ISO8859_8_TABLE")
        |> File.read!()
        |> :erlang.binary_to_term()

      mappings = %{
        31 => greek_bibliographic(),
        38 => din_31624(),
        39 => iso_6438(),
        53 => iso_5426(),
        59 => codar_u(),
        198 => latin_hebrew(iso8859_table)
      }

      File.mkdir_p!(Path.dirname(normalized))
      File.write!(normalized, serialize_normalized(mappings))
      mappings
    end
  end

  defp greek_bibliographic do
    uppercase =
      Enum.zip(0x41..0x58, Enum.to_list(0x0391..0x03A1) ++ Enum.to_list(0x03A3..0x03A9))

    lowercase =
      Enum.zip(
        0x61..0x78,
        Enum.to_list(0x03B1..0x03C1) ++ Enum.to_list(0x03C3..0x03C9)
      )

    @greek_diacritics
    |> Enum.concat(Enum.map(uppercase, fn {byte, codepoint} -> {byte, {codepoint}} end))
    |> Enum.concat(Enum.map(lowercase, fn {byte, codepoint} -> {byte, {codepoint}} end))
    |> Enum.concat(@greek_punctuation)
    |> Map.new(fn {byte, codepoints} -> {<<byte>>, codepoints} end)
  end

  defp latin_hebrew(table) do
    for byte <- 0xA0..0xFF,
        codepoints = elem(table.one, byte),
        codepoints != nil,
        into: %{} do
      {<<byte - 0x80>>, codepoints}
    end
  end

  # Revised ISO-IR 53 registration table, including its deliberate duplicate
  # mappings at 0x28/0x38 and 0x48/0x49.  The three context-sensitive trailing
  # half signs use the registration's literal standalone UCS mappings.
  defp iso_5426 do
    %{
      0x20 => 0x0020,
      0x21 => 0x00A1,
      0x22 => 0x201E,
      0x23 => 0x00A3,
      0x24 => 0x0024,
      0x25 => 0x00A5,
      0x26 => 0x2020,
      0x27 => 0x00B6,
      0x28 => 0x2033,
      0x29 => 0x2018,
      0x2A => 0x201C,
      0x2B => 0x00AB,
      0x2C => 0x266D,
      0x2D => 0x00A9,
      0x2E => 0x2117,
      0x2F => 0x2122,
      0x30 => 0x02BD,
      0x31 => 0x02BE,
      0x32 => 0x201A,
      0x36 => 0x2021,
      0x37 => 0x00B7,
      0x38 => 0x2033,
      0x39 => 0x2019,
      0x3A => 0x201D,
      0x3B => 0x00BB,
      0x3C => 0x266F,
      0x3D => 0x02B9,
      0x3E => 0x02BA,
      0x3F => 0x00BF,
      0x40 => 0x0309,
      0x41 => 0x0300,
      0x42 => 0x0301,
      0x43 => 0x0302,
      0x44 => 0x0303,
      0x45 => 0x0304,
      0x46 => 0x0306,
      0x47 => 0x0307,
      0x48 => 0x0308,
      0x49 => 0x0308,
      0x4A => 0x030A,
      0x4B => 0x0315,
      0x4C => 0x0312,
      0x4D => 0x030B,
      0x4E => 0x031B,
      0x4F => 0x030C,
      0x50 => 0x0327,
      0x51 => 0x031C,
      0x52 => 0x0326,
      0x53 => 0x0328,
      0x54 => 0x0325,
      0x55 => 0x032E,
      0x56 => 0x0323,
      0x57 => 0x0324,
      0x58 => 0x0332,
      0x59 => 0x0333,
      0x5A => 0x0329,
      0x5B => 0x032D,
      0x5D => 0xFE20,
      0x5E => 0xFE21,
      0x5F => 0xFE23,
      0x61 => 0x00C6,
      0x62 => 0x0110,
      0x66 => 0x0132,
      0x68 => 0x0141,
      0x69 => 0x00D8,
      0x6A => 0x0152,
      0x6C => 0x00DE,
      0x71 => 0x00E6,
      0x72 => 0x0111,
      0x73 => 0x00F0,
      0x75 => 0x0131,
      0x76 => 0x0133,
      0x78 => 0x0142,
      0x79 => 0x00F8,
      0x7A => 0x0153,
      0x7B => 0x00DF,
      0x7C => 0x00FE
    }
    |> Map.new(fn {byte, codepoint} -> {<<byte>>, {codepoint}} end)
  end

  # The final ISO/TC 46/SC 4/WG 1 mapping in Unicode L2/00-223 corrects
  # position 3/8 to U+01DD by using the standard's U+018E case pairing.
  defp iso_6438 do
    %{
      0x22 => 0x0181,
      0x23 => 0x0187,
      0x24 => 0x018A,
      0x25 => 0x0189,
      0x27 => 0x0190,
      0x28 => 0x018E,
      0x2A => 0x0191,
      0x2B => 0x0193,
      0x2C => 0x0194,
      0x2D => 0x0126,
      0x2F => 0x0197,
      0x32 => 0x0253,
      0x33 => 0x0188,
      0x34 => 0x0257,
      0x35 => 0x0256,
      0x37 => 0x025B,
      0x38 => 0x01DD,
      0x3A => 0x0192,
      0x3B => 0x0260,
      0x3C => 0x0263,
      0x3D => 0x0127,
      0x3F => 0x026A,
      0x40 => 0x0198,
      0x47 => 0x014A,
      0x49 => 0x019F,
      0x4A => 0x0186,
      0x4B => 0x01A4,
      0x4F => 0x01A9,
      0x50 => 0x0199,
      0x51 => 0x026C,
      0x53 => 0x0271,
      0x55 => 0x0273,
      0x56 => 0x0272,
      0x57 => 0x014B,
      0x59 => 0x0275,
      0x5A => 0x0254,
      0x5B => 0x01A5,
      0x5D => 0x027D,
      0x5F => 0x0283,
      0x60 => 0x01AC,
      0x61 => 0x01AE,
      0x63 => 0x01B1,
      0x64 => 0x01B2,
      0x65 => 0xA7B3,
      0x66 => 0x01B3,
      0x67 => 0x01B7,
      0x70 => 0x01AD,
      0x71 => 0x0288,
      0x73 => 0x028A,
      0x74 => 0x028B,
      0x75 => 0xAB53,
      0x76 => 0x01B4,
      0x77 => 0x0292,
      0x78 => 0x0295,
      0x79 => 0x0294,
      0x7A => 0x0298,
      0x7B => 0x01C0,
      0x7C => 0x01C2,
      0x7D => 0x01C3,
      0x7E => 0x01C1
    }
    |> Map.new(fn {byte, codepoint} -> {<<byte>>, {codepoint}} end)
  end

  # DIN 31624 is read directly from ISO-IR 38. The current mappings use the
  # dedicated Unicode combining signs and sound-recording copyright character;
  # Pike's independently implemented 94-position table is pinned as a cross-check.
  defp din_31624 do
    %{
      0x21 => 0x00A1,
      0x22 => 0x201E,
      0x23 => 0x00A3,
      0x24 => 0x00A4,
      0x25 => 0x2030,
      0x26 => 0x2020,
      0x27 => 0x0040,
      0x28 => 0x00B0,
      0x29 => 0x005B,
      0x2A => 0x007B,
      0x2B => 0x00AB,
      0x2C => 0x266D,
      0x2D => 0x00A9,
      0x2E => 0x2117,
      0x2F => 0x00AE,
      0x30 => 0x02BF,
      0x31 => 0x02BE,
      0x32 => 0x201A,
      0x34 => 0x005C,
      0x35 => 0x007C,
      0x36 => 0x2021,
      0x37 => 0x00B7,
      0x38 => 0x2192,
      0x39 => 0x005D,
      0x3A => 0x007D,
      0x3B => 0x00BB,
      0x3C => 0x266F,
      0x3D => 0x02B9,
      0x3E => 0x02BA,
      0x3F => 0x00BF,
      0x40 => 0x0309,
      0x41 => 0x0300,
      0x42 => 0x0301,
      0x43 => 0x0302,
      0x44 => 0x0303,
      0x45 => 0x0304,
      0x46 => 0x0306,
      0x47 => 0x0307,
      0x48 => 0x0308,
      0x49 => 0x0336,
      0x4A => 0x030A,
      0x4B => 0x0315,
      0x4C => 0x0312,
      0x4D => 0x030B,
      0x4E => 0x031B,
      0x4F => 0x030C,
      0x50 => 0x0327,
      0x51 => 0x031C,
      0x52 => 0x0326,
      0x53 => 0x0328,
      0x54 => 0x0325,
      0x55 => 0x032E,
      0x56 => 0x0323,
      0x57 => 0x0338,
      0x58 => 0x0332,
      0x59 => 0x0333,
      0x5A => 0x0329,
      0x5B => 0x032D,
      0x5D => 0xFE20,
      0x5E => 0xFE21,
      0x5F => 0xFE23,
      0x61 => 0x00C6,
      0x62 => 0x0110,
      0x68 => 0x0141,
      0x69 => 0x00D8,
      0x6A => 0x0152,
      0x6C => 0x00DE,
      0x71 => 0x00E6,
      0x72 => 0x0111,
      0x73 => 0x00F0,
      0x75 => 0x0131,
      0x78 => 0x0142,
      0x79 => 0x00F8,
      0x7A => 0x0153,
      0x7B => 0x01A6,
      0x7C => 0x00FE
    }
    |> Map.new(fn {byte, codepoint} -> {<<byte>>, {codepoint}} end)
  end

  # CODAR-U has one compound graphic at 0x5E: tatweel plus hamza above.
  # The remaining 93 positions use the literal Unicode/presentation-form
  # values independently implemented by Pike's pinned CODAR-U table.
  defp codar_u do
    values = [
      0x0021,
      0x0022,
      0x0023,
      0x00A4,
      0x0025,
      0x0026,
      0x0027,
      0x0028,
      0x0029,
      0x002A,
      0x002B,
      0x060C,
      0x002D,
      0x002E,
      0x002F,
      0x0030,
      0x0031,
      0x0032,
      0x0033,
      0x0034,
      0x0035,
      0x0036,
      0x0037,
      0x0038,
      0x0039,
      0x003A,
      0x061B,
      0x003C,
      0x003D,
      0x003E,
      0x061F,
      0x0040,
      0xFCF2,
      0xFC60,
      0xFCF3,
      0xFC61,
      0xFCF4,
      0xFC62,
      0xFE77,
      0xFE76,
      0xFE70,
      0xFE79,
      0xFE78,
      0xFE72,
      0xFE7B,
      0xFE7A,
      0xFE74,
      0xFE7F,
      0xFE7E,
      0xFE7D,
      0xFE7C,
      0x0623,
      0x0622,
      0x0624,
      0x0626,
      0x0626,
      0x0625,
      0xFEF2,
      0x067E,
      0x06A4,
      0x06AF,
      {0x0640, 0x0654},
      0x0627,
      0x0628,
      0x062A,
      0x0629,
      0x062B,
      0x062C,
      0x062D,
      0x062E,
      0x062F,
      0x0630,
      0x0631,
      0x0632,
      0x0633,
      0x0634,
      0x0635,
      0x0636,
      0x0637,
      0x0638,
      0x0639,
      0x063A,
      0x0642,
      0x0643,
      0x06A9,
      0x0644,
      0x0645,
      0x0646,
      0x0647,
      0x0648,
      0x064A,
      0x00A6,
      0x0649,
      0x0640
    ]

    values
    |> Enum.with_index(0x21)
    |> Map.new(fn
      {codepoints, byte} when is_tuple(codepoints) -> {<<byte>>, codepoints}
      {codepoint, byte} -> {<<byte>>, {codepoint}}
    end)
  end

  defp serialize_normalized(mappings) do
    header = "# ISO-IR historical graphic-set byte-to-Unicode mappings\n"

    body =
      Enum.map_join(Enum.map(@registrations, &elem(&1, 0)), "", fn registration ->
        rows =
          mappings[registration]
          |> Enum.sort()
          |> Enum.map_join("", fn {bytes, codepoints} ->
            unicode = codepoints |> Tuple.to_list() |> Enum.map_join(",", &hex(&1, 4))
            "#{Base.encode16(bytes)}\t#{unicode}\n"
          end)

        "\n[#{registration}]\n" <> rows
      end)

    header <> body
  end

  defp parse_normalized(source) do
    source
    |> String.split(~r/^\[([0-9]+)\]\s*$/m, include_captures: true, trim: true)
    |> Enum.drop(1)
    |> Enum.chunk_every(2)
    |> Map.new(fn [header, rows] ->
      registration =
        header |> String.trim_leading("[") |> String.trim_trailing("]") |> String.to_integer()

      mapping =
        rows
        |> String.split("\n", trim: true)
        |> Enum.reject(&String.starts_with?(&1, "#"))
        |> Map.new(fn row ->
          [encoded, unicode] = String.split(row, "\t")

          codepoints =
            unicode
            |> String.split(",")
            |> Enum.map(&String.to_integer(&1, 16))
            |> List.to_tuple()

          {Base.decode16!(encoded), codepoints}
        end)

      {registration, mapping}
    end)
  end

  defp build_table(decode) do
    encode =
      decode
      |> Enum.sort()
      |> Enum.reduce(%{}, fn {bytes, codepoints}, result ->
        Map.put_new(result, codepoints, bytes)
      end)

    one =
      0..255
      |> Enum.map(fn byte -> Map.get(decode, <<byte>>) end)
      |> List.to_tuple()

    table = %{
      encode: encode,
      many: %{},
      max_codepoints: decode |> Map.values() |> Enum.map(&tuple_size/1) |> Enum.max(),
      max_input: 1,
      one: one,
      prefixes: MapSet.new()
    }

    {table, map_size(decode), map_size(encode)}
  end

  defp materialize_registrations(destination) do
    source_dir = System.get_env("ISO_IR_HISTORICAL_SOURCE_DIR") || destination
    File.mkdir_p!(destination)

    Enum.each(@registrations, fn {registration, _aliases, sha256} ->
      filename =
        registration |> Integer.to_string() |> String.pad_leading(3, "0") |> Kernel.<>(".pdf")

      candidate = Path.join(source_dir, filename)

      source =
        if File.exists?(candidate), do: candidate, else: Path.join(source_dir, "isoir#{filename}")

      assert_sha!(source, sha256)
      target = Path.join(destination, filename)
      if Path.expand(source) != Path.expand(target), do: File.cp!(source, target)
    end)
  end

  defp materialize_unicode_mappings(destination) do
    source_dir = System.get_env("ISO_IR_HISTORICAL_MAPPING_SOURCE_DIR") || destination
    File.mkdir_p!(destination)

    @unicode_mapping_sources
    |> Enum.filter(fn {_registration, source} -> Map.has_key?(source, :mapping_filename) end)
    |> Enum.each(fn {_registration, source} ->
      candidate = Path.join(source_dir, source.mapping_filename)
      assert_sha!(candidate, source.mapping_sha256)
      target = Path.join(destination, source.mapping_filename)
      if Path.expand(candidate) != Path.expand(target), do: File.cp!(candidate, target)
    end)
  end

  defp write_documentation(root, manifest) do
    rows =
      Enum.map_join(manifest.encodings, "", fn entry ->
        source_sha = entry[:mapping_sha256] || entry[:crosscheck_sha256]
        mapping_sha = if source_sha, do: "`#{source_sha}`", else: "—"

        "| `#{entry.name}` | #{entry.decode_mappings} | #{entry.encode_mappings} | " <>
          "`#{entry.registration_sha256}` | #{mapping_sha} |\n"
      end)

    document = """
    # Historical ISO-IR graphic sets

    These codecs expose the registered graphic positions directly. ISO-IR 31
    maps composite Greek diacritics to Unicode combining sequences and preposed
    breathing signs to their Greek Extended spacing characters. ISO-IR 38 is
    the 77-character DIN 31624 bibliographic set, checked against Pike's pinned
    independent 94-position table and updated to current Unicode combining
    characters. ISO-IR 39 uses
    the final Unicode L2/00-223 mapping for ISO 6438, including its corrected
    U+01DD case pairing, with the dedicated Latin chi characters added in
    Unicode 7 and 8 replacing the old Greek-chi fallbacks. ISO-IR 53 is
    the revised 76-character ISO 5426 bibliographic extension with the literal
    UCS mappings recorded on its registration sheet. ISO-IR 59 is the complete
    94-position Arabic CODAR-U set, including vocalization presentation forms
    and its compound tatweel-plus-hamza graphic. ISO-IR 198 is the exact
    60-character Latin/Hebrew supplementary repertoire.

    | Encoding | Decode mappings | Encode mappings | Registration SHA-256 | Mapping/cross-check SHA-256 |
    |---|---:|---:|---|---|
    #{rows}
    """

    File.write!(Path.join(root, "ISO_IR_HISTORICAL_GRAPHIC.md"), document)
  end

  defp assert_sha!(path, expected) do
    actual = path |> File.read!() |> sha256()

    unless actual == expected,
      do: Mix.raise("#{path}: expected SHA-256 #{expected}, got #{actual}")
  end

  defp hex(integer, width),
    do: integer |> Integer.to_string(16) |> String.upcase() |> String.pad_leading(width, "0")

  defp sha256(binary), do: :crypto.hash(:sha256, binary) |> Base.encode16(case: :lower)
end

Iconvex.Specs.Tools.ImportISOIRHistoricalGraphic.run()
