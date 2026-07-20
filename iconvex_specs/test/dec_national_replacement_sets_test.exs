defmodule Iconvex.Specs.DECNationalReplacementSetsTest do
  use ExUnit.Case, async: false

  alias Iconvex.Specs.Packed

  @source_path Path.expand(
                 "../priv/sources/dec-terminal-character-sets/kermit/ckcuni.c",
                 __DIR__
               )
  @metadata_path Path.expand(
                   "../priv/sources/dec-terminal-character-sets/SOURCE_METADATA.md",
                   __DIR__
                 )

  @profiles [
    {"DEC-NRC-UNITED-KINGDOM", "BRITISH", "u_british", %{0x23 => 0x00A3}},
    {"DEC-NRC-DUTCH", "DUTCH", "u_dutch",
     %{
       0x23 => 0x00A3,
       0x40 => 0x00BE,
       0x5B => 0x00FF,
       0x5C => 0x00BD,
       0x5D => 0x007C,
       0x7B => 0x00A8,
       0x7C => 0x0192,
       0x7D => 0x00BC,
       0x7E => 0x00B4
     }},
    {"DEC-NRC-FINNISH", "FINNISH", "u_finnish",
     %{
       0x5B => 0x00C4,
       0x5C => 0x00D6,
       0x5D => 0x00C5,
       0x5E => 0x00DC,
       0x60 => 0x00E9,
       0x7B => 0x00E4,
       0x7C => 0x00F6,
       0x7D => 0x00E5,
       0x7E => 0x00FC
     }},
    {"DEC-NRC-FRENCH", "FRENCH", "u_french",
     %{
       0x23 => 0x00A3,
       0x40 => 0x00E0,
       0x5B => 0x00B0,
       0x5C => 0x00E7,
       0x5D => 0x00A7,
       0x7B => 0x00E9,
       0x7C => 0x00F9,
       0x7D => 0x00E8,
       0x7E => 0x00A8
     }},
    {"DEC-NRC-FRENCH-CANADIAN", "CANADIAN-FRENCH", "u_fr_canadian",
     %{
       0x40 => 0x00E0,
       0x5B => 0x00E2,
       0x5C => 0x00E7,
       0x5D => 0x00EA,
       0x5E => 0x00EE,
       0x60 => 0x00F4,
       0x7B => 0x00E9,
       0x7C => 0x00F9,
       0x7D => 0x00E8,
       0x7E => 0x00FB
     }},
    {"DEC-NRC-GERMAN", "GERMAN", "u_german",
     %{
       0x40 => 0x00A7,
       0x5B => 0x00C4,
       0x5C => 0x00D6,
       0x5D => 0x00DC,
       0x7B => 0x00E4,
       0x7C => 0x00F6,
       0x7D => 0x00FC,
       0x7E => 0x00DF
     }},
    {"DEC-NRC-ITALIAN", "ITALIAN", "u_italian",
     %{
       0x23 => 0x00A3,
       0x40 => 0x00A7,
       0x5B => 0x00B0,
       0x5C => 0x00E7,
       0x5D => 0x00E9,
       0x60 => 0x00F9,
       0x7B => 0x00E0,
       0x7C => 0x00F2,
       0x7D => 0x00E8,
       0x7E => 0x00EC
     }},
    {"DEC-NRC-NORWEGIAN-DANISH", "NORWEGIAN", "u_norwegian",
     %{
       0x5B => 0x00C6,
       0x5C => 0x00D8,
       0x5D => 0x00C5,
       0x7B => 0x00E6,
       0x7C => 0x00F8,
       0x7D => 0x00E5
     }},
    {"DEC-NRC-PORTUGUESE", "PORTUGUESE", "u_portuguese",
     %{
       0x5B => 0x00C3,
       0x5C => 0x00C7,
       0x5D => 0x00D5,
       0x7B => 0x00E3,
       0x7C => 0x00E7,
       0x7D => 0x00F5
     }},
    {"DEC-NRC-SPANISH", "SPANISH", "u_spanish",
     %{
       0x23 => 0x00A3,
       0x40 => 0x00A7,
       0x5B => 0x00A1,
       0x5C => 0x00D1,
       0x5D => 0x00BF,
       0x7B => 0x00B0,
       0x7C => 0x00F1,
       0x7D => 0x00E7
     }},
    {"DEC-NRC-SWEDISH", "SWEDISH", "u_swedish",
     %{
       0x40 => 0x00C9,
       0x5B => 0x00C4,
       0x5C => 0x00D6,
       0x5D => 0x00C5,
       0x5E => 0x00DC,
       0x60 => 0x00E9,
       0x7B => 0x00E4,
       0x7C => 0x00F6,
       0x7D => 0x00E5,
       0x7E => 0x00FC
     }},
    {"DEC-NRC-SWISS", "SWISS", "u_swiss",
     %{
       0x23 => 0x00F9,
       0x40 => 0x00E0,
       0x5B => 0x00E9,
       0x5C => 0x00E7,
       0x5D => 0x00EA,
       0x5E => 0x00EE,
       0x5F => 0x00E8,
       0x60 => 0x00F4,
       0x7B => 0x00E4,
       0x7C => 0x00F6,
       0x7D => 0x00FC,
       0x7E => 0x00FB
     }}
  ]

  test "RED: all twelve DEC manual NRC tables decode every septet exactly" do
    for {canonical, _alias, _kermit, replacements} <- @profiles do
      for byte <- 0x00..0x7F do
        assert Iconvex.convert(<<byte>>, canonical, "UTF-32BE") ==
                 {:ok, <<Map.get(replacements, byte, byte)::unsigned-big-32>>}
      end
    end
  end

  test "all twelve profiles encode the complete inverse and reject high octets" do
    for {canonical, _alias, _kermit, replacements} <- @profiles do
      table = Enum.map(0x00..0x7F, &Map.get(replacements, &1, &1))

      for {codepoint, byte} <- Enum.with_index(table) do
        assert Iconvex.convert(<<codepoint::unsigned-big-32>>, "UTF-32BE", canonical) ==
                 {:ok, <<byte>>}
      end

      assert {:error, %Iconvex.Error{kind: :invalid_sequence, offset: 1}} =
               Iconvex.convert(<<0x41, 0x80>>, canonical, "UTF-8")
    end
  end

  test "simple national names resolve and every profile has both packed orders" do
    for {canonical, alias_name, _kermit, replacements} <- @profiles do
      assert Iconvex.canonical_name(alias_name) == {:ok, canonical}
      assert %{canonical: ^canonical, unit_bits: 7} = Packed.profile(alias_name)

      text = Enum.map_join(0x00..0x7F, &<<Map.get(replacements, &1, &1)::utf8>>)

      for order <- [:msb, :lsb] do
        assert {:ok, packed} = Packed.encode_from_utf8(text, alias_name, order)
        assert Packed.decode_to_utf8(packed, alias_name, order) == {:ok, text}
      end
    end
  end

  test "manual is primary and permanently guards two defective Kermit tables" do
    metadata = File.read!(@metadata_path)
    source = File.read!(@source_path)

    assert metadata =~ "Table 2-1"
    assert metadata =~ "printed page 25 / PDF page 38"
    assert metadata =~ "Dutch"
    assert metadata =~ "Portuguese"

    for {_canonical, _alias, kermit, replacements} <- @profiles do
      manual = Enum.map(0x21..0x7E, &Map.get(replacements, &1, &1))
      differences = difference_count(manual, source_table(source, kermit))

      expected = if kermit == "u_dutch", do: 2, else: if(kermit == "u_portuguese", do: 6, else: 0)
      assert differences == expected, "unexpected #{kermit} difference count"
    end
  end

  defp source_table(source, table_name) do
    pattern =
      ~r/struct\s+x_to_unicode\s+#{Regex.escape(table_name)}\s*=\s*\{(?<body>.*?)\n\};/s

    %{"body" => body} = Regex.named_captures(pattern, source)

    ~r/0x([0-9A-Fa-f]+)/
    |> Regex.scan(body, capture: :all_but_first)
    |> Enum.take(94)
    |> Enum.map(fn [hex] -> String.to_integer(hex, 16) end)
  end

  defp difference_count(left, right) do
    left |> Enum.zip(right) |> Enum.count(fn {a, b} -> a != b end)
  end
end
