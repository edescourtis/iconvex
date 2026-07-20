glyph_dir = Path.expand("../priv/sources/glyph-vector-unicode", __DIR__)
tace_dir = Path.expand("../priv/sources/tace16-2010", __DIR__)
File.mkdir_p!(glyph_dir)
File.mkdir_p!(tace_dir)

agl =
  "/tmp/agl-aglfn/glyphlist.txt"
  |> File.stream!()
  |> Enum.reduce(%{}, fn line, acc ->
    case line |> String.trim() |> String.split(";", parts: 2) do
      ["#" <> _, _] ->
        acc

      [name, value] when name != "" ->
        codepoints =
          value |> String.split(" ", trim: true) |> Enum.map(&String.to_integer(&1, 16))

        Map.put(acc, name, codepoints)

      _ ->
        acc
    end
  end)

ly1_names =
  "/tmp/ly1-src/ly1/enc/texnansi.enc"
  |> File.read!()
  |> String.split("/TeXnANSIEncoding [", parts: 2)
  |> List.last()
  |> String.split("] def", parts: 2)
  |> List.first()
  |> String.split("\n")
  |> Enum.flat_map(fn line ->
    case Regex.run(~r/^\/([^\s%]+)/, String.trim_leading(line), capture: :all_but_first) do
      [name] -> [name]
      nil -> []
    end
  end)

unless length(ly1_names) == 256, do: raise("LY1 vector is not 256 entries")

ascii_names = %{
  32 => "space",
  33 => "exclam",
  34 => "quotedbl",
  35 => "numbersign",
  36 => "dollar",
  37 => "percent",
  38 => "ampersand",
  39 => "quoteright",
  40 => "parenleft",
  41 => "parenright",
  42 => "asterisk",
  43 => "plus",
  44 => "comma",
  45 => "hyphen",
  46 => "period",
  47 => "slash",
  48 => "zero",
  49 => "one",
  50 => "two",
  51 => "three",
  52 => "four",
  53 => "five",
  54 => "six",
  55 => "seven",
  56 => "eight",
  57 => "nine",
  58 => "colon",
  59 => "semicolon",
  60 => "less",
  61 => "equal",
  62 => "greater",
  63 => "question",
  64 => "at",
  91 => "bracketleft",
  92 => "backslash",
  93 => "bracketright",
  94 => "asciicircum",
  95 => "underscore",
  96 => "quoteleft",
  123 => "braceleft",
  124 => "bar",
  125 => "braceright",
  126 => "asciitilde"
}

ascii_names =
  ascii_names
  |> Map.merge(Map.new(Enum.with_index(?A..?Z, 65), fn {char, byte} -> {byte, <<char>>} end))
  |> Map.merge(Map.new(Enum.with_index(?a..?z, 97), fn {char, byte} -> {byte, <<char>>} end))

accents = %{
  0x90 => "dotlessi",
  0x91 => "grave",
  0x92 => "acute",
  0x93 => "circumflex",
  0x94 => "tilde",
  0x95 => "macron",
  0x96 => "breve",
  0x97 => "dotaccent",
  0x98 => "dieresis",
  0x9A => "ring",
  0x9B => "cedilla",
  0x9D => "hungarumlaut",
  0x9E => "ogonek",
  0x9F => "caron"
}

latin1_names = [
  "space",
  "exclamdown",
  "cent",
  "sterling",
  "currency",
  "yen",
  "brokenbar",
  "section",
  "dieresis",
  "copyright",
  "ordfeminine",
  "guillemotleft",
  "logicalnot",
  "hyphen",
  "registered",
  "macron",
  "degree",
  "plusminus",
  "twosuperior",
  "threesuperior",
  "acute",
  "mu",
  "paragraph",
  "periodcentered",
  "cedilla",
  "onesuperior",
  "ordmasculine",
  "guillemotright",
  "onequarter",
  "onehalf",
  "threequarters",
  "questiondown",
  "Agrave",
  "Aacute",
  "Acircumflex",
  "Atilde",
  "Adieresis",
  "Aring",
  "AE",
  "Ccedilla",
  "Egrave",
  "Eacute",
  "Ecircumflex",
  "Edieresis",
  "Igrave",
  "Iacute",
  "Icircumflex",
  "Idieresis",
  "Eth",
  "Ntilde",
  "Ograve",
  "Oacute",
  "Ocircumflex",
  "Otilde",
  "Odieresis",
  "multiply",
  "Oslash",
  "Ugrave",
  "Uacute",
  "Ucircumflex",
  "Udieresis",
  "Yacute",
  "Thorn",
  "germandbls",
  "agrave",
  "aacute",
  "acircumflex",
  "atilde",
  "adieresis",
  "aring",
  "ae",
  "ccedilla",
  "egrave",
  "eacute",
  "ecircumflex",
  "edieresis",
  "igrave",
  "iacute",
  "icircumflex",
  "idieresis",
  "eth",
  "ntilde",
  "ograve",
  "oacute",
  "ocircumflex",
  "otilde",
  "odieresis",
  "divide",
  "oslash",
  "ugrave",
  "uacute",
  "ucircumflex",
  "udieresis",
  "yacute",
  "thorn",
  "ydieresis"
]

unless length(latin1_names) == 96, do: raise("Latin-1 tail is not 96 entries")

ps_names =
  List.duplicate(".notdef", 256)
  |> List.to_tuple()
  |> then(fn tuple ->
    Enum.reduce(ascii_names, tuple, fn {byte, name}, acc -> put_elem(acc, byte, name) end)
  end)
  |> then(fn tuple ->
    Enum.reduce(accents, tuple, fn {byte, name}, acc -> put_elem(acc, byte, name) end)
  end)
  |> then(fn tuple ->
    Enum.reduce(Enum.with_index(latin1_names, 0xA0), tuple, fn {name, byte}, acc ->
      put_elem(acc, byte, name)
    end)
  end)
  |> Tuple.to_list()

write_vector = fn path, names ->
  rows =
    Enum.with_index(names)
    |> Enum.map(fn {name, byte} -> "#{Base.encode16(<<byte>>)},#{name}\n" end)

  File.write!(path, ["byte,glyph\n" | rows])
end

write_mapping = fn path, names, invalid_names ->
  rows =
    names
    |> Enum.with_index()
    |> Enum.flat_map(fn {name, byte} ->
      cond do
        name in invalid_names ->
          []

        true ->
          case Map.fetch!(agl, name) do
            [codepoint] ->
              [
                "#{Base.encode16(<<byte>>)},#{codepoint |> Integer.to_string(16) |> String.upcase()}\n"
              ]

            sequence ->
              raise "glyph #{name} has non-single AGL mapping #{inspect(sequence)}"
          end
      end
    end)

  File.write!(path, ["byte,unicode\n" | rows])
end

write_vector.(Path.join(glyph_dir, "postscript3_isolatin1_vector.csv"), ps_names)
write_mapping.(Path.join(glyph_dir, "ly1_agl_4036a9ca.csv"), ly1_names, [".notdef", "cwm"])

write_mapping.(Path.join(glyph_dir, "postscript3_isolatin1_agl_4036a9ca.csv"), ps_names, [
  ".notdef"
])

vowels = [
  {0xE201, [0x0B85], "TAMIL LETTER A"},
  {0xE202, [0x0B86], "TAMIL LETTER AA"},
  {0xE203, [0x0B87], "TAMIL LETTER I"},
  {0xE204, [0x0B88], "TAMIL LETTER II"},
  {0xE205, [0x0B89], "TAMIL LETTER U"},
  {0xE206, [0x0B8A], "TAMIL LETTER UU"},
  {0xE207, [0x0B8E], "TAMIL LETTER E"},
  {0xE208, [0x0B8F], "TAMIL LETTER EE"},
  {0xE209, [0x0B90], "TAMIL LETTER AI"},
  {0xE20A, [0x0B92], "TAMIL LETTER O"},
  {0xE20B, [0x0B93], "TAMIL LETTER OO"},
  {0xE20C, [0x0B94], "TAMIL LETTER AU"},
  {0xE20D, [0x0B83], "TAMIL LETTER AYTHAM"}
]

consonants = [
  {0xE210, 0x0B95, "K"},
  {0xE220, 0x0B99, "NG"},
  {0xE230, 0x0B9A, "C"},
  {0xE240, 0x0B9E, "NY"},
  {0xE250, 0x0B9F, "TT"},
  {0xE260, 0x0BA3, "NN"},
  {0xE270, 0x0BA4, "T"},
  {0xE280, 0x0BA8, "N"},
  {0xE290, 0x0BAA, "P"},
  {0xE2A0, 0x0BAE, "M"},
  {0xE2B0, 0x0BAF, "Y"},
  {0xE2C0, 0x0BB0, "R"},
  {0xE2D0, 0x0BB2, "L"},
  {0xE2E0, 0x0BB5, "V"},
  {0xE2F0, 0x0BB4, "LLL"},
  {0xE300, 0x0BB3, "LL"},
  {0xE310, 0x0BB1, "RR"},
  {0xE320, 0x0BA9, "NNN"},
  {0xE330, 0x0B9C, "J"},
  {0xE340, 0x0BB6, "SH"},
  {0xE350, 0x0BB7, "SS"},
  {0xE360, 0x0BB8, "S"},
  {0xE370, 0x0BB9, "H"}
]

forms = [
  {0, [0x0BCD], "CONSONANT"},
  {1, [], "A"},
  {2, [0x0BBE], "AA"},
  {3, [0x0BBF], "I"},
  {4, [0x0BC0], "II"},
  {5, [0x0BC1], "U"},
  {6, [0x0BC2], "UU"},
  {7, [0x0BC6], "E"},
  {8, [0x0BC7], "EE"},
  {9, [0x0BC8], "AI"},
  {10, [0x0BCA], "O"},
  {11, [0x0BCB], "OO"},
  {12, [0x0BCC], "AU"}
]

letters =
  Enum.flat_map(consonants, fn {start, base, name} ->
    Enum.map(forms, fn {offset, suffix, form} ->
      label = if offset == 0, do: "TAMIL CONSONANT #{name}", else: "TAMIL SYLLABLE #{name}#{form}"
      {start + offset, [base | suffix], label}
    end)
  end)

kssa =
  Enum.map(forms, fn {offset, suffix, form} ->
    sequence =
      if offset == 0,
        do: [0x0B95, 0x0BCD, 0x0BB7, 0x0BCD],
        else: [0x0B95, 0x0BCD, 0x0BB7 | suffix]

    label = if offset == 0, do: "TAMIL CONSONANT KSS", else: "TAMIL SYLLABLE KSS#{form}"
    {0xE380 + offset, sequence, label}
  end)

symbols =
  Enum.map(0..7, fn offset ->
    {0xE100 + offset, [0x0BF3 + offset], "TAMIL HISTORIC SYMBOL #{offset}"}
  end) ++
    Enum.map(8..11, fn offset ->
      {0xE100 + offset, [0xE100 + offset], "TAMIL PUA SYMBOL #{offset}"}
    end) ++
    [{0xE10C, [0x0BD0], "TAMIL SIGN OM"}] ++
    Enum.map(0..12, fn offset ->
      {0xE180 + offset, [0x0BE6 + offset], "TAMIL NUMBER #{offset}"}
    end) ++
    Enum.map(0..15, fn offset ->
      {0xE1A0 + offset, [0xE1A0 + offset], "TAMIL PUA FRACTION #{offset}"}
    end) ++
    [{0xE1F0, [0x0BCD], "TAMIL VOWEL SIGN PULLI"}] ++
    Enum.map(
      Enum.with_index(
        [0x0BBE, 0x0BBF, 0x0BC0, 0x0BC1, 0x0BC2, 0x0BC6, 0x0BC7, 0x0BC8, 0x0BCA, 0x0BCB, 0x0BCC],
        0xE1F2
      ),
      fn {unicode, unit} ->
        {unit, [unicode], "TAMIL VOWEL SIGN"}
      end
    )

tace_rows =
  (symbols ++
     vowels ++
     letters ++ kssa ++ [{0xE38D, [0x0BB6, 0x0BCD, 0x0BB0, 0x0BC0], "TAMIL SYLLABLE SHRII"}])
  |> Enum.sort_by(&elem(&1, 0))

unless length(tace_rows) == 380, do: raise("TACE row count is not 380")

tace_csv =
  Enum.map(tace_rows, fn {unit, unicode, name} ->
    status = if unicode == [unit], do: "pua_identity", else: "equivalent"
    sequence = Enum.map_join(unicode, "+", &(Integer.to_string(&1, 16) |> String.upcase()))
    "#{Integer.to_string(unit, 16) |> String.upcase()},#{sequence},#{status},#{name}\n"
  end)

File.write!(Path.join(tace_dir, "appendix_d.csv"), [
  "tace,unicode_sequence,status,name\n" | tace_csv
])

for path <- [
      Path.join(glyph_dir, "postscript3_isolatin1_vector.csv"),
      Path.join(glyph_dir, "ly1_agl_4036a9ca.csv"),
      Path.join(glyph_dir, "postscript3_isolatin1_agl_4036a9ca.csv"),
      Path.join(tace_dir, "appendix_d.csv")
    ] do
  digest = :crypto.hash(:sha256, File.read!(path)) |> Base.encode16(case: :lower)
  IO.puts("#{Path.basename(path)} #{digest} #{File.stat!(path).size}")
end
