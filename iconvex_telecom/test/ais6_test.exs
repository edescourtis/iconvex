defmodule Iconvex.Telecom.AIS6Test do
  use ExUnit.Case, async: false

  alias Iconvex.Telecom.AIS6
  alias Iconvex.Telecom.AIS6.{Armor, Packing}

  test "encodes ITU-R M.1371-6 Table 45 text as unpacked six-bit units" do
    encoded = <<1, 9, 19, 32, 49, 50, 51, 63>>
    assert AIS6.encode(~c"AIS 123?") == {:ok, encoded}
    assert AIS6.decode(encoded) == {:ok, ~c"AIS 123?"}
  end

  test "exhaustively implements all 64 Table 45 characters" do
    table = AIS6.table()
    assert map_size(table) == 64

    for value <- 0..63 do
      codepoint = Map.fetch!(table, value)
      assert AIS6.decode(<<value>>) == {:ok, [codepoint]}
      assert AIS6.encode([codepoint]) == {:ok, <<value>>}
    end
  end

  test "strictly rejects non-six-bit octets and supports discard" do
    assert AIS6.decode(<<64>>) == {:error, :invalid_sequence, 0, <<64>>}
    assert AIS6.decode(<<255>>) == {:error, :invalid_sequence, 0, <<255>>}
    assert AIS6.decode_discard(<<64, 1, 255>>) == {:ok, [?A]}
    assert AIS6.encode([?a]) == {:error, :unrepresentable_character, ?a}
  end

  test "packs and unpacks exact consecutive six-bit characters" do
    units = <<1, 9, 19, 32, 49, 50, 51, 63>>
    assert {:ok, packed} = Packing.pack(units)
    assert bit_size(packed) == 48
    assert Packing.unpack(packed) == {:ok, units}
    assert Packing.unpack(<<1::5>>) == {:error, :incomplete_sequence, 0, <<1::5>>}
  end

  test "implements IEC 61162 AIVDM six-bit payload armoring and fill bits" do
    assert Armor.encode(<<0, 1, 39, 40, 63>>) == {:ok, "01W`w"}
    assert Armor.decode("01W`w") == {:ok, <<0, 1, 39, 40, 63>>}

    bits = <<1::6, 63::6, 5::3>>
    assert Armor.encode_bits(bits) == {:ok, "1w`", 3}
    assert Armor.decode_bits("1w`", 3) == {:ok, bits}

    assert Armor.decode("X") == {:error, :invalid_sequence, 0, "X"}
    assert Armor.decode_bits("1", 1) == {:error, :nonzero_fill_bits}
  end

  test "registers AIS six-bit standards aliases" do
    assert Iconvex.canonical_name("AIS6") == {:ok, "AIS6"}
    assert Iconvex.canonical_name("AIS-6BIT") == {:ok, "AIS6"}
    assert Iconvex.canonical_name("ITU-R-M.1371-6") == {:ok, "AIS6"}
  end
end
