defmodule Iconvex.Telecom.IA5Test do
  use ExUnit.Case, async: false

  alias Iconvex.Telecom.IA5
  alias Iconvex.Telecom.IA5.Packing

  @source_sha256 "849a6848640618846f4688c9f65884af1c54d51c9228141d9c13eec33f2a9c88"

  test "registers every historical and current T.50 name" do
    for name <- [
          "ITU-T-T.50-IRV",
          "ITU-T-T.50",
          "IRA",
          "IA5",
          "ITA5",
          "ITA-5",
          "CCITT-5",
          "CCITT-NO-5"
        ] do
      assert Iconvex.canonical_name(name) == {:ok, "ITU-T-T.50-IRV"}
    end
  end

  test "pins the exact in-force ITU-T T.50 source" do
    assert IA5.source_manifest() == %{
             recommendation: "ITU-T T.50 (09/1992)",
             source_sha256: @source_sha256,
             source_url:
               "https://www.itu.int/rec/dologin_pub.asp?id=T-REC-T.50-199209-I!!PDF-E&lang=e&type=items"
           }
  end

  test "exhaustively implements all 128 IRV code positions" do
    assert IA5.table() == Map.new(0..127, &{&1, &1})

    for value <- 0..127 do
      assert IA5.decode(<<value>>) == {:ok, [value]}
      assert IA5.encode([value]) == {:ok, <<value>>}
    end
  end

  test "strictly rejects the complete high-bit octet domain and supports discard" do
    for value <- 128..255 do
      assert IA5.decode(<<value>>) == {:error, :invalid_sequence, 0, <<value>>}
      assert IA5.encode([value]) == {:error, :unrepresentable_character, value}
    end

    assert IA5.decode_discard(<<128, ?A, 255>>) == {:ok, [?A]}
    assert IA5.encode_discard([0x100, ?A, 0x10FFFF]) == {:ok, "A"}
  end

  test "packs and unpacks consecutive seven-bit IA5 units" do
    units = <<0, ?I, ?A, ?5, 127>>
    assert {:ok, packed} = Packing.pack(units)
    assert bit_size(packed) == 35
    assert Packing.unpack(packed) == {:ok, units}

    assert Packing.pack(<<128>>) == {:error, :invalid_sequence, 0, <<128>>}
    assert Packing.unpack(<<1::6>>) == {:error, :incomplete_sequence, 0, <<1::6>>}
  end

  test "preserves UTF-8 callback error boundaries" do
    assert IA5.encode_from_utf8("A") == {:ok, "A"}

    assert IA5.encode_from_utf8(<<"A", 0xC2>>) ==
             {:decode_error, :incomplete_sequence, 1, <<0xC2>>}

    assert IA5.encode_from_utf8("Aé") ==
             {:encode_error, :unrepresentable_character, 0x00E9}
  end
end
