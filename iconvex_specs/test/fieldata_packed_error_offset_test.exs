defmodule Iconvex.Specs.FieldataPackedErrorOffsetTest do
  use ExUnit.Case, async: true

  alias Iconvex.Packed.LSB
  alias Iconvex.Specs.Packed

  @encoding "FIELDATA-UNIVAC-4009-INPUT"

  test "MSB errors identify the invalid cell at its physical bit offset" do
    packed = <<0o06::6, 0o06::6, 0o06::6, 0o06::6, 0o04::6>>

    assert Packed.decode_to_utf8(packed, @encoding, :msb) ==
             {:error, :invalid_sequence, 24, <<0o04::6>>}
  end

  test "LSB errors identify the invalid cell at its physical bit offset" do
    packed = %LSB{
      data: <<0x86, 0x61, 0x18, 0x04>>,
      bit_size: 30,
      unit_bits: 6
    }

    assert Packed.decode_to_utf8(packed, @encoding, :lsb) ==
             {:error, :invalid_sequence, 24, 0o04}
  end
end
