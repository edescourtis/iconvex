defmodule Iconvex.Telecom.GSM0338PackingTest do
  use ExUnit.Case, async: true

  alias Iconvex.Telecom.GSM0338.Packing

  test "packs and unpacks the canonical hellohello septet vector" do
    septets = "hellohello"
    packed = <<0xE8, 0x32, 0x9B, 0xFD, 0x46, 0x97, 0xD9, 0xEC, 0x37>>

    assert Packing.pack(septets) == {:ok, packed}
    assert Packing.unpack(packed, 10) == {:ok, septets}
  end

  test "supports the fill bits required after a user-data header" do
    assert Packing.pack(<<1, 2, 3>>, fill_bits: 1) == {:ok, <<0x02, 0x82, 0x01>>}
    assert Packing.unpack(<<0x02, 0x82, 0x01>>, 3, fill_bits: 1) == {:ok, <<1, 2, 3>>}

    assert Packing.fill_bits_for_udh(5) == 1
    assert Packing.fill_bits_for_udh(6) == 0
  end

  test "TP-UDHL fill alignment accepts exactly the one-octet domain" do
    assert Packing.fill_bits_for_udh(255) == 3

    for invalid <- [-1, 256, "5"] do
      assert Packing.fill_bits_for_udh(invalid) ==
               {:error, {:invalid_udh_octets, invalid}}
    end
  end

  test "round-trips every septet length and fill-bit alignment" do
    for fill_bits <- 0..6, count <- 0..80 do
      septets =
        for index <- 0..(count - 1)//1, count > 0, into: <<>>, do: <<rem(index * 29, 128)>>

      assert {:ok, packed} = Packing.pack(septets, fill_bits: fill_bits)
      assert Packing.unpack(packed, count, fill_bits: fill_bits) == {:ok, septets}
    end
  end

  test "rejects high-bit octets and impossible lengths" do
    assert Packing.pack(<<0x80>>) == {:error, {:invalid_septet, 0, 0x80}}
    assert Packing.unpack(<<0>>, 2) == {:error, :insufficient_bits}
    assert Packing.pack(<<1>>, fill_bits: 7) == {:error, {:invalid_fill_bits, 7}}
  end
end
