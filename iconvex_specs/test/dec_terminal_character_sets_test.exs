defmodule Iconvex.Specs.DECTerminalCharacterSetsTest do
  use ExUnit.Case, async: false

  alias Iconvex.Specs.{DECSpecial, DECSpecialGR, DECTechnical, DECTechnicalGR, Packed}

  @source_directory Path.expand("../priv/sources/dec-terminal-character-sets", __DIR__)

  @manual_source_path Path.join(
                        @source_directory,
                        "EK-VT3XX-TP-002_VT330_VT340_Text_Programming_198805.pdf"
                      )

  @unicode_source_path Path.join(
                         @source_directory,
                         "Unicode_L2_1998_354_Terminal_Character_Sets_Proposal.pdf"
                       )

  @legacy_computing_source_path Path.expand(
                                  "../iso-ir-mosaic-technical/unicode-mappings/n5028.pdf",
                                  @source_directory
                                )

  @kermit_source_path Path.join(@source_directory, "kermit/ckcuni.c")
  @kermit_license_path Path.join(@source_directory, "kermit/COPYING")
  @source_metadata_path Path.join(@source_directory, "SOURCE_METADATA.md")
  @manual_sha256 "518676ad1188d4f75d0780e25f0a8fda2bb4a1a591902c6d62e1b9fde8042978"
  @proposal_sha256 "c50253ab97f2e155f55c920f9e11e449c3a11f955ee585327ef033c647fa1c78"
  @legacy_computing_sha256 "e64a54b4b223b5e6a9d686a7a7ddd1fc98d0bc88585059be02078b082a760e61"
  @kermit_sha256 "af93d5a1c779aa73fa3221ab5ec0125de20267110cf23395971ce35cc88527ca"
  @kermit_license_sha256 "067b8c8fc98d9359dfbd211820e1d57bed1e173144a184a21e8ead802b6502be"

  @special_tail [
    0x25C6,
    0x1FB95,
    0x2409,
    0x240C,
    0x240D,
    0x240A,
    0x00B0,
    0x00B1,
    0x2424,
    0x240B,
    0x2518,
    0x2510,
    0x250C,
    0x2514,
    0x253C,
    0x23BA,
    0x23BB,
    0x2500,
    0x23BC,
    0x23BD,
    0x251C,
    0x2524,
    0x2534,
    0x252C,
    0x2502,
    0x2264,
    0x2265,
    0x03C0,
    0x2260,
    0x00A3,
    0x00B7
  ]
  @special Enum.to_list(0x21..0x5E) ++ [0x00A0] ++ @special_tail

  @technical [
    0x23B7,
    0x250C,
    0x2500,
    0x2320,
    0x2321,
    0x2502,
    0x23A1,
    0x23A3,
    0x23A4,
    0x23A6,
    0x239B,
    0x239D,
    0x239E,
    0x23A0,
    0x23A8,
    0x23AC,
    0x23B2,
    0x23B3,
    0x2572,
    0x2571,
    0x23B4,
    0x23B5,
    0x232A,
    nil,
    nil,
    nil,
    nil,
    0x2264,
    0x2260,
    0x2265,
    0x222B,
    0x2234,
    0x221D,
    0x221E,
    0x00F7,
    0x0394,
    0x2207,
    0x03A6,
    0x0393,
    0x223C,
    0x2243,
    0x0398,
    0x00D7,
    0x039B,
    0x21D4,
    0x21D2,
    0x2261,
    0x03A0,
    0x03A8,
    nil,
    0x03A3,
    nil,
    nil,
    0x221A,
    0x03A9,
    0x039E,
    0x03D2,
    0x2282,
    0x2283,
    0x2229,
    0x222A,
    0x2227,
    0x2228,
    0x00AC,
    0x03B1,
    0x03B2,
    0x03C7,
    0x03B4,
    0x03B5,
    0x03C6,
    0x03B3,
    0x03B7,
    0x03B9,
    0x03B8,
    0x03BA,
    0x03BB,
    nil,
    0x03BD,
    0x2202,
    0x03C0,
    0x03C8,
    0x03C1,
    0x03C3,
    0x03C4,
    nil,
    0x0192,
    0x03C9,
    0x03BE,
    0x03C5,
    0x03B6,
    0x2190,
    0x2191,
    0x2192,
    0x2193
  ]

  @profiles [
    {DECSpecial, @special, 0x21, :gl},
    {DECSpecialGR, @special, 0xA1, :gr},
    {DECTechnical, @technical, 0x21, :gl},
    {DECTechnicalGR, @technical, 0xA1, :gr}
  ]

  test "RED: pins the DEC tables, Unicode proposal, and licensed Kermit cross-check" do
    assert sha256(File.read!(@manual_source_path)) == @manual_sha256
    assert sha256(File.read!(@unicode_source_path)) == @proposal_sha256

    assert sha256(File.read!(@legacy_computing_source_path)) ==
             @legacy_computing_sha256

    assert sha256(File.read!(@kermit_source_path)) == @kermit_sha256
    assert sha256(File.read!(@kermit_license_path)) == @kermit_license_sha256
    assert File.read!(@source_metadata_path) =~ "Figure 2-7"

    assert File.read!(@source_metadata_path) =~
             "8e977425d2f7f618d14aa466d516e9b79787ffc6"

    assert DECSpecial.source_page() == 39
    assert DECSpecial.printed_source_page() == 26
    assert DECTechnical.source_page() == 40
    assert DECTechnical.printed_source_page() == 27
    assert DECSpecial.unit_bits() == 7
    assert DECTechnical.unit_bits() == 7
    assert DECSpecial.source_url() =~ "EK-VT3XX-TP-002"
    assert DECSpecial.unicode_source_url() == "https://www.unicode.org/L2/L1998/98354.pdf"
  end

  test "implements every DEC Special GL and GR assignment exactly" do
    assert length(@special) == 94

    for {codec, offset} <- [{DECSpecial, 0x21}, {DECSpecialGR, 0xA1}] do
      bytes = :binary.list_to_bin(Enum.to_list(offset..(offset + 93)))
      assert codec.decode(bytes) == {:ok, @special}
      assert codec.encode(@special) == {:ok, bytes}

      assert codec.decode(<<offset + 0x3E, offset + 0x3F, offset + 0x40>>) ==
               {:ok, [0x00A0, 0x25C6, 0x1FB95]}
    end
  end

  test "implements every defined and undefined DEC Technical GL and GR position" do
    assert length(@technical) == 94

    for {codec, offset} <- [{DECTechnical, 0x21}, {DECTechnicalGR, 0xA1}],
        {codepoint, index} <- Enum.with_index(@technical) do
      byte = offset + index

      if codepoint do
        assert codec.decode(<<byte>>) == {:ok, [codepoint]}
        assert codec.encode([codepoint]) == {:ok, <<byte>>}
      else
        assert codec.decode(<<byte>>) == {:error, :invalid_sequence, 0, <<byte>>}
        assert codec.decode(<<offset, byte>>) == {:error, :invalid_sequence, 1, <<byte>>}
      end
    end
  end

  test "uses Unicode's standardized large-sigma pieces without private-use values" do
    expected = [0x23B2, 0x23B3, 0x2572, 0x2571, 0x23B4, 0x23B5, 0x232A]

    assert DECTechnical.decode(:binary.list_to_bin(Enum.to_list(0x31..0x37))) ==
             {:ok, expected}

    assert DECTechnical.private_use_codepoints() == []
    refute Enum.any?(@technical, &(&1 in 0xE000..0xF8FF))
  end

  test "all 256 possible octets agree with an independent profile oracle" do
    for {codec, table, offset, _invocation} <- @profiles, byte <- 0..255 do
      assert codec.decode(<<byte>>) == oracle_decode(byte, table, offset)
    end
  end

  test "discard conversion skips invalid octets and unrepresentable Unicode" do
    for {codec, table, offset, _invocation} <- @profiles do
      [{first_index, first}, {last_index, last}] =
        table
        |> Enum.with_index()
        |> Enum.reject(fn {codepoint, _index} -> is_nil(codepoint) end)
        |> then(&[List.first(&1), List.last(&1)])
        |> Enum.map(fn {codepoint, index} -> {index, codepoint} end)

      assert codec.decode_discard(<<offset + first_index, 0x00, offset + last_index>>) ==
               {:ok, [first, last]}

      assert codec.encode_discard([first, 0x10FFFF, last]) ==
               {:ok, <<offset + first_index, offset + last_index>>}
    end
  end

  test "direct UTF-8 paths are exact, strict, and report malformed input offsets" do
    for {codec, table, offset, _invocation} <- @profiles do
      defined = Enum.reject(table, &is_nil/1)
      bytes = oracle_defined_bytes(table, offset)
      utf8 = List.to_string(defined)

      assert codec.decode_to_utf8(bytes) == {:ok, utf8}
      assert codec.encode_from_utf8(utf8) == {:ok, bytes}

      assert codec.encode_from_utf8(utf8 <> "☃") ==
               {:error, :unrepresentable_character, 0x2603}

      first = defined |> hd() |> then(&List.to_string([&1]))

      assert codec.encode_from_utf8(first <> <<0xFF>>) ==
               {:decode_error, :invalid_sequence, byte_size(first), <<0xFF>>}
    end
  end

  test "registers explicit GL and GR profiles with non-colliding aliases" do
    assert Iconvex.canonical_name("VT100-LINE-DRAWING") == {:ok, "DEC-SPECIAL"}
    assert Iconvex.canonical_name("DEC-SPECIAL-GRAPHICS-GR") == {:ok, "DEC-SPECIAL-GR"}
    assert Iconvex.canonical_name("VT300-TECHNICAL") == {:ok, "DEC-TECHNICAL"}
    assert Iconvex.canonical_name("VT300-TECHNICAL-GR") == {:ok, "DEC-TECHNICAL-GR"}

    for {codec, _table, _offset, invocation} <- @profiles do
      assert codec.invocation() == invocation
    end
  end

  test "publishes packed MSB- and LSB-first transports for both 7-bit GL sets" do
    assert Packed.profile(DECSpecial).unit_bits == 7
    assert Packed.profile(DECTechnical).unit_bits == 7
    refute Packed.profile(DECSpecialGR)
    refute Packed.profile(DECTechnicalGR)

    for {codec, table} <- [{DECSpecial, @special}, {DECTechnical, @technical}] do
      defined = Enum.reject(table, &is_nil/1)
      utf8 = List.to_string(defined)

      assert {:ok, msb} = Packed.encode_from_utf8(utf8, codec.canonical_name(), :msb)
      assert bit_size(msb) == length(defined) * 7
      assert Packed.decode_to_utf8(msb, codec.canonical_name(), :msb) == {:ok, utf8}

      assert {:ok, %Iconvex.Packed.LSB{bit_size: bits} = lsb} =
               Packed.encode_from_utf8(utf8, codec.canonical_name(), :lsb)

      assert bits == length(defined) * 7
      assert Packed.decode_to_utf8(lsb, codec.canonical_name(), :lsb) == {:ok, utf8}
    end

    assert Packed.encode_from_utf8("A◆", "DEC-SPECIAL", :msb) ==
             {:ok, <<0x41::7, 0x60::7>>}
  end

  defp oracle_decode(byte, table, offset) do
    index = byte - offset

    if index in 0..93 do
      case Enum.at(table, index) do
        nil -> {:error, :invalid_sequence, 0, <<byte>>}
        codepoint -> {:ok, [codepoint]}
      end
    else
      {:error, :invalid_sequence, 0, <<byte>>}
    end
  end

  defp oracle_defined_bytes(table, offset) do
    table
    |> Enum.with_index()
    |> Enum.reject(fn {codepoint, _index} -> is_nil(codepoint) end)
    |> Enum.map(fn {_codepoint, index} -> offset + index end)
    |> :binary.list_to_bin()
  end

  defp sha256(bytes), do: :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)
end
