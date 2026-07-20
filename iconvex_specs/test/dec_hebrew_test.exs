defmodule Iconvex.Specs.DECHebrewTest do
  use ExUnit.Case, async: false

  alias Iconvex.Specs.{DECHebrew8, Packed, SI960}

  @source_directory Path.expand("../priv/sources/dec-hebrew-7", __DIR__)

  @guide_source_path Path.join(
                       @source_directory,
                       "Kennelly_Digital_Guide_To_Developing_International_Software_1991.pdf"
                     )

  @vt510_source_path Path.join(@source_directory, "vt510rmb.pdf")
  @source_metadata_path Path.join(@source_directory, "SOURCE_METADATA.md")

  @kermit_source_path Path.expand(
                        "../dec-terminal-character-sets/kermit/ckcuni.c",
                        @source_directory
                      )

  @kermit_license_path Path.expand(
                         "../dec-terminal-character-sets/kermit/COPYING",
                         @source_directory
                       )
  @guide_sha256 "a28083a4057e8bffcc928bda4f56bb316b939b6c6b5f498a3a180322bd1cb80b"
  @vt510_sha256 "440bbee110eb75027a06b5b375683fbc87cb739edac32899005ad46981c7d514"
  @kermit_sha256 "af93d5a1c779aa73fa3221ab5ec0125de20267110cf23395971ce35cc88527ca"
  @kermit_license_sha256 "067b8c8fc98d9359dfbd211820e1d57bed1e173144a184a21e8ead802b6502be"
  @hebrew Enum.to_list(0x05D0..0x05EA)
  @si960 Enum.to_list(0x00..0x5F) ++ @hebrew ++ Enum.to_list(0x7B..0x7F)

  test "RED: pins DEC's exact Hebrew definitions and the licensed Kermit cross-check" do
    assert sha256(File.read!(@guide_source_path)) == @guide_sha256
    assert sha256(File.read!(@vt510_source_path)) == @vt510_sha256
    assert sha256(File.read!(@kermit_source_path)) == @kermit_sha256
    assert sha256(File.read!(@kermit_license_path)) == @kermit_license_sha256
    assert File.read!(@source_metadata_path) =~ "positions 96-122"
    assert File.read!(@source_metadata_path) =~ "Israeli Standards Institute Standard 960"
    assert SI960.guide_source_page() == 39
    assert SI960.printed_guide_source_page() == 19
    assert SI960.vt510_source_page() == 180
    assert SI960.printed_vt510_source_page() == "5-57"
    assert SI960.unit_bits() == 7
  end

  test "implements every SI 960 septet and rejects every high octet" do
    units = :binary.list_to_bin(Enum.to_list(0..0x7F))
    assert SI960.decode(units) == {:ok, @si960}
    assert SI960.encode(@si960) == {:ok, units}

    for unit <- 0x80..0xFF do
      assert SI960.decode(<<unit>>) == {:error, :invalid_sequence, 0, <<unit>>}
      assert SI960.decode(<<0, unit>>) == {:error, :invalid_sequence, 1, <<unit>>}
    end

    assert SI960.encode([?a]) == {:error, :unrepresentable_character, ?a}
    assert SI960.encode([0x05D0, 0x05EA]) == {:ok, <<0x60, 0x7A>>}
  end

  test "implements all 256 DEC Hebrew 8-bit positions from DEC MCS plus the Hebrew overlay" do
    dec_mcs = Iconvex.Specs.RFC1345.Codecs.C088

    for byte <- 0..0xFF do
      expected = dec_hebrew_oracle(byte, dec_mcs)
      assert DECHebrew8.decode(<<byte>>) == expected

      case expected do
        {:ok, [codepoint]} -> assert DECHebrew8.encode([codepoint]) == {:ok, <<byte>>}
        {:error, :invalid_sequence, 0, _} -> :ok
      end
    end

    assert DECHebrew8.decode(:binary.list_to_bin(Enum.to_list(0xE0..0xFA))) ==
             {:ok, @hebrew}

    assert DECHebrew8.encode(@hebrew) ==
             {:ok, :binary.list_to_bin(Enum.to_list(0xE0..0xFA))}

    assert DECHebrew8.encode([0x00C0]) ==
             {:error, :unrepresentable_character, 0x00C0}
  end

  test "discard and direct UTF-8 paths preserve strict offsets" do
    assert SI960.decode_discard(<<0x41, 0x80, 0x60>>) == {:ok, [?A, 0x05D0]}
    assert SI960.encode_discard([?A, ?a, 0x05D0]) == {:ok, <<0x41, 0x60>>}
    assert SI960.decode_to_utf8(<<0x41, 0x60, 0x7B>>) == {:ok, "Aא{"}
    assert SI960.encode_from_utf8("Aא{") == {:ok, <<0x41, 0x60, 0x7B>>}

    assert {:decode_error, :invalid_sequence, 1, <<0xFF>>} =
             SI960.encode_from_utf8(<<?A, 0xFF>>)

    assert DECHebrew8.decode_discard(<<0x41, 0xC0, 0xE0>>) == {:ok, [?A, 0x05D0]}
    assert DECHebrew8.encode_discard([?A, 0x00C0, 0x05D0]) == {:ok, <<0x41, 0xE0>>}
    assert DECHebrew8.decode_to_utf8(<<0x41, 0xE0>>) == {:ok, "Aא"}
    assert DECHebrew8.encode_from_utf8("Aא") == {:ok, <<0x41, 0xE0>>}
  end

  test "registers both profiles and publishes SI 960 packed septets in both orders" do
    assert Iconvex.canonical_name("SI960") == {:ok, "SI-960"}
    assert Iconvex.canonical_name("HEBREW-7") == {:ok, "SI-960"}
    assert Iconvex.canonical_name("DEC-HEBREW") == {:ok, "DEC-HEBREW-8"}

    assert %{canonical: "SI-960", unit_bits: 7, standard_order: :msb} =
             Packed.profile("DEC-HEBREW-7")

    assert {:ok, <<0x41::7, 0x60::7>> = msb} =
             Packed.encode_from_utf8("Aא", "SI-960", :msb)

    assert Packed.decode_to_utf8(msb, "SI-960", :msb) == {:ok, "Aא"}

    assert {:ok, %Iconvex.Packed.LSB{bit_size: 14} = lsb} =
             Packed.encode_from_utf8("Aא", "SI-960", :lsb)

    assert Packed.decode_to_utf8(lsb, "SI-960", :lsb) == {:ok, "Aא"}
  end

  defp dec_hebrew_oracle(byte, _dec_mcs) when byte in 0xE0..0xFA,
    do: {:ok, [0x05D0 + byte - 0xE0]}

  defp dec_hebrew_oracle(byte, _dec_mcs) when byte in 0xC0..0xDF or byte in 0xFB..0xFF,
    do: {:error, :invalid_sequence, 0, <<byte>>}

  defp dec_hebrew_oracle(byte, dec_mcs), do: dec_mcs.decode(<<byte>>)

  defp sha256(bytes), do: :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)
end
