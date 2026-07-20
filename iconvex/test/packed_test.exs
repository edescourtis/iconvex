defmodule Iconvex.PackedTest do
  use ExUnit.Case, async: true
  import Bitwise

  test "RED: MSB packing preserves exact bit length and rejects partial units" do
    assert Iconvex.Packed.pack(<<0b10101, 0b00011>>, 5) ==
             {:ok, <<0b10101::5, 0b00011::5>>}

    assert Iconvex.Packed.unpack(<<0b10101::5, 0b00011::5>>, 5) ==
             {:ok, <<0b10101, 0b00011>>}

    assert Iconvex.Packed.pack(<<0x20>>, 5) ==
             {:error, :unit_out_of_range, 0, 0x20}

    assert Iconvex.Packed.unpack(<<0b10101::5, 1::1>>, 5) ==
             {:error, :incomplete_unit, 5, <<1::1>>}
  end

  test "LSB packing matches GSM 7-bit packed wire order" do
    units = "hellohello"
    expected = Base.decode16!("E8329BFD4697D9EC37")

    assert Iconvex.Packed.pack_lsb(units, 7) ==
             {:ok, %Iconvex.Packed.LSB{data: expected, bit_size: 70, unit_bits: 7}}

    assert Iconvex.Packed.unpack_lsb(expected, 70, 7) == {:ok, units}
  end

  test "LSB transport validates declared length, padding, and unit boundary" do
    assert Iconvex.Packed.unpack_lsb(<<0>>, 9, 7) ==
             {:error, :invalid_bit_size}

    assert Iconvex.Packed.unpack_lsb(<<0x80>>, 7, 7) ==
             {:error, :nonzero_padding_bits}

    assert Iconvex.Packed.unpack_lsb(<<0>>, 6, 7) ==
             {:error, :incomplete_unit, 0, 6}
  end

  test "LSB helper rejects a mistagged bit-order container" do
    input = %Iconvex.Packed.LSB{
      data: <<0x41>>,
      bit_size: 7,
      unit_bits: 7,
      bit_order: :msb
    }

    assert Iconvex.Packed.decode_to_utf8_lsb(input, "ASCII") ==
             {:error, :bit_order_mismatch}
  end

  test "all widths round-trip every in-range unit in both orders" do
    for width <- 1..8 do
      units = 0..((1 <<< width) - 1) |> Enum.to_list() |> :erlang.list_to_binary()

      assert {:ok, packed} = Iconvex.Packed.pack(units, width)
      assert bit_size(packed) == byte_size(units) * width
      assert Iconvex.Packed.unpack(packed, width) == {:ok, units}

      assert {:ok, lsb} = Iconvex.Packed.pack_lsb(units, width)
      assert Iconvex.Packed.unpack_lsb(lsb.data, lsb.bit_size, width) == {:ok, units}
    end
  end

  test "bounded chunks preserve exact output and offsets beyond allocation boundaries" do
    for width <- 1..8 do
      mask = (1 <<< width) - 1
      units = for index <- 0..9_999, into: <<>>, do: <<index &&& mask>>

      expected =
        units
        |> :binary.bin_to_list()
        |> Enum.map(&<<&1::size(width)>>)
        |> :erlang.list_to_bitstring()

      assert Iconvex.Packed.pack(units, width) == {:ok, expected}
      assert Iconvex.Packed.unpack(expected, width) == {:ok, units}

      assert {:ok, lsb} = Iconvex.Packed.pack_lsb(units, width)
      assert Iconvex.Packed.unpack_lsb(lsb.data, lsb.bit_size, width) == {:ok, units}
    end

    valid = :binary.copy(<<0x3F>>, 5_000)

    assert Iconvex.Packed.pack(valid <> <<0x40>>, 6) ==
             {:error, :unit_out_of_range, 5_000, 0x40}

    assert {:ok, packed} = Iconvex.Packed.pack(valid, 6)

    assert Iconvex.Packed.unpack(<<packed::bitstring, 1::1>>, 6) ==
             {:error, :incomplete_unit, 30_000, <<1::1>>}
  end

  test "UTF-8 helpers expose packed versions of fixed-width codecs" do
    assert {:ok, packed} = Iconvex.Packed.encode_from_utf8("Hello", "ASCII", 7)
    assert packed == <<?H::7, ?e::7, ?l::7, ?l::7, ?o::7>>
    assert Iconvex.Packed.decode_to_utf8(packed, "ASCII", 7) == {:ok, "Hello"}

    assert {:ok, lsb} = Iconvex.Packed.encode_from_utf8_lsb("hellohello", "ASCII", 7)
    assert Base.encode16(lsb.data) == "E8329BFD4697D9EC37"

    assert Iconvex.Packed.decode_to_utf8_lsb(lsb, "ASCII") == {:ok, "hellohello"}
  end
end
