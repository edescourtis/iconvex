defmodule Iconvex.Specs.ISOIRHistoricalGraphicSetsTest do
  use ExUnit.Case, async: false

  @manifest Path.expand("../priv/iso_ir_historical_graphic_manifest.etf", __DIR__)
  @specs [
    {"ISO-IR-31", ["GREEK-BIBLIOGRAPHIC-1976"], 31},
    {"ISO-IR-38", ["DIN-31624", "DIN_31624"], 38},
    {"ISO-IR-39", ["ISO-6438", "DIN-31625"], 39},
    {"ISO-IR-53", ["ISO-5426", "ISO_5426:1980"], 53},
    {"ISO-IR-59", ["CODAR-U", "CODARU"], 59},
    {"ISO-IR-198", ["LATIN-HEBREW-ISO-IR-198"], 198}
  ]

  test "registers the historical Greek bibliography and Latin/Hebrew sets" do
    for {canonical, aliases, _registration} <- @specs,
        name <- [canonical | aliases] do
      assert {:ok, %{canonical: ^canonical}} = Iconvex.Registry.resolve(name)
    end
  end

  test "pins both official ISO-IR sheets" do
    manifest = @manifest |> File.read!() |> :erlang.binary_to_term()

    assert Enum.map(manifest.encodings, &{&1.registration, &1.registration_sha256}) == [
             {31, "2006784a60655960304cc9ceeb05599355242d83352e0ebbe2aff4fb8eef14f2"},
             {38, "42ff603c9fbaf7518ea3253568a2e88f7accf8ef00635486e031c0603a2665cd"},
             {39, "15510e5c252717ffbff519a7beb8a07cb26295be9111ad527016cddfd61826c9"},
             {53, "cc37311a58fee1c31868b1486fbde279a7f00ee9a6a496642a2dfa2731ead18f"},
             {59, "fcbf4dfa7d522a9332ef6cd1cb73c7ab2531fdccbbd1b330dca2bd7e47d23862"},
             {198, "acbf5b215a37a343e90f849106b118f532ab9c35340e27a1768382930c8f3aba"}
           ]

    assert %{mapping_sha256: mapping_sha256} =
             Enum.find(manifest.encodings, &(&1.registration == 39))

    assert mapping_sha256 ==
             "d4872f2e9b75cc011b63c60e75e22a36358228e85f56dc35817624fd4250b498"

    assert %{crosscheck_revision: revision, crosscheck_sha256: source_sha256} =
             Enum.find(manifest.encodings, &(&1.registration == 38))

    assert revision == "4bf9adbd874894d2484de1664969de43e4206492"
    assert source_sha256 == "28f856d12347859c9cb7f10361c813c4a4f3f7c9d33911544b50c7897748d860"

    assert %{crosscheck_revision: ^revision, crosscheck_sha256: ^source_sha256} =
             Enum.find(manifest.encodings, &(&1.registration == 59))
  end

  test "exhausts every possible byte against independent specification maps" do
    expected = %{
      31 => greek_bibliographic(),
      38 => din_31624(),
      39 => iso_6438(),
      53 => iso_5426(),
      59 => codar_u(),
      198 => latin_hebrew()
    }

    for {canonical, _aliases, registration} <- @specs,
        byte <- 0..255 do
      result =
        case Map.fetch(expected[registration], <<byte>>) do
          {:ok, codepoints} -> {:ok, List.to_string(codepoints)}
          :error -> {:error, :invalid_sequence}
        end

      assert normalized(Iconvex.convert(<<byte>>, canonical, "UTF-8")) == result
    end
  end

  test "round-trips every canonical mapping, including compound Greek diacritics" do
    expected = %{
      31 => greek_bibliographic(),
      38 => din_31624(),
      39 => iso_6438(),
      53 => iso_5426(),
      59 => codar_u(),
      198 => latin_hebrew()
    }

    for {canonical, _aliases, registration} <- @specs do
      encode =
        Enum.reduce(expected[registration], %{}, fn {bytes, codepoints}, result ->
          Map.put_new(result, codepoints, bytes)
        end)

      for {codepoints, bytes} <- encode do
        assert Iconvex.convert(List.to_string(codepoints), "UTF-8", canonical) == {:ok, bytes}
      end
    end
  end

  @tag timeout: 120_000
  test "checks singleton encoding over every Unicode scalar" do
    expected = %{
      31 => greek_bibliographic(),
      38 => din_31624(),
      39 => iso_6438(),
      53 => iso_5426(),
      59 => codar_u(),
      198 => latin_hebrew()
    }

    all_scalars =
      0..0x10FFFF
      |> Stream.reject(&(&1 in 0xD800..0xDFFF))
      |> Stream.chunk_every(4_096)
      |> Enum.map(&List.to_string/1)
      |> IO.iodata_to_binary()

    for {canonical, _aliases, registration} <- @specs do
      output =
        expected[registration]
        |> Enum.filter(fn {_bytes, codepoints} -> length(codepoints) == 1 end)
        |> Enum.reduce(%{}, fn {bytes, [codepoint]}, result ->
          Map.put_new(result, codepoint, bytes)
        end)
        |> Enum.sort()
        |> Enum.map(fn {_codepoint, bytes} -> bytes end)
        |> IO.iodata_to_binary()

      assert Iconvex.convert(all_scalars, "UTF-8", canonical, unrepresentable: :discard) ==
               {:ok, output}
    end
  end

  defp greek_bibliographic do
    diacritics = %{
      0x21 => [0x0300],
      0x22 => [0x0301],
      0x23 => [0x0308, 0x0300],
      0x24 => [0x0342],
      0x25 => [0x0313],
      0x26 => [0x0314],
      0x27 => [0x0313, 0x0301],
      0x28 => [0x0314, 0x0301],
      0x29 => [0x0308],
      0x2A => [0x0345],
      0x2B => [0x0313, 0x0300],
      0x2C => [0x0314, 0x0300],
      0x2D => [0x0313, 0x0342],
      0x2E => [0x0314, 0x0342],
      0x2F => [0x0308, 0x0301],
      0x35 => [0x1FBF],
      0x36 => [0x1FFE],
      0x37 => [0x1FCE],
      0x38 => [0x1FDE],
      0x3B => [0x1FCD],
      0x3C => [0x1FDD],
      0x3D => [0x1FCF],
      0x3E => [0x1FDF]
    }

    uppercase =
      Enum.zip(0x41..0x58, Enum.to_list(0x0391..0x03A1) ++ Enum.to_list(0x03A3..0x03A9))

    lowercase =
      Enum.zip(
        0x61..0x78,
        Enum.to_list(0x03B1..0x03C1) ++ Enum.to_list(0x03C3..0x03C9)
      )

    punctuation = %{
      0x59 => [0x0387],
      0x5A => [0x00AB],
      0x5B => [0x00BB],
      0x5C => [0x201C],
      0x5D => [0x201D],
      0x5E => [0x0374],
      0x5F => [0x0375],
      0x79 => [0x03C2],
      0x7A => [0x03DD],
      0x7B => [0x03DF],
      0x7C => [0x03E1],
      0x7D => [0x03DB]
    }

    diacritics
    |> Enum.concat(Enum.map(uppercase, fn {byte, codepoint} -> {byte, [codepoint]} end))
    |> Enum.concat(Enum.map(lowercase, fn {byte, codepoint} -> {byte, [codepoint]} end))
    |> Enum.concat(punctuation)
    |> Map.new(fn {byte, codepoints} -> {<<byte>>, codepoints} end)
  end

  defp latin_hebrew do
    table = Iconvex.Tables.fetch!(%{id: :iso8859_8, table_app: :iconvex})

    for byte <- 0xA0..0xFF,
        codepoints = elem(table.one, byte),
        codepoints != nil,
        into: %{} do
      {<<byte - 0x80>>, Tuple.to_list(codepoints)}
    end
  end

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
    |> Map.new(fn {byte, codepoint} -> {<<byte>>, [codepoint]} end)
  end

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
    |> Map.new(fn {byte, codepoint} -> {<<byte>>, [codepoint]} end)
  end

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
    |> Map.new(fn {byte, codepoint} -> {<<byte>>, [codepoint]} end)
  end

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
      [0x0640, 0x0654],
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
      {codepoints, byte} when is_list(codepoints) -> {<<byte>>, codepoints}
      {codepoint, byte} -> {<<byte>>, [codepoint]}
    end)
  end

  defp normalized({:ok, output}), do: {:ok, output}
  defp normalized({:error, %{kind: kind}}), do: {:error, kind}
end
