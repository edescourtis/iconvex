defmodule Iconvex.PackedErrorCoordinatesTest do
  use ExUnit.Case, async: true

  alias Iconvex.Error
  alias Iconvex.Packed
  alias Iconvex.Packed.LSB

  @units <<0x5C, 0x65, 0x00, 0x00>>

  test "RED: MSB semantic failures use physical packed-bit coordinates" do
    assert {:ok, packed} = Packed.pack(@units, 7)

    assert {:error, %Error{} = error} =
             Packed.decode_to_utf8(packed, "JIS_X0208", 7)

    assert error.kind == :invalid_sequence
    assert error.offset == 14
    assert Map.fetch!(error, :offset_unit) == :bit
    assert error.sequence == <<0::14>>

    assert Exception.message(error) ==
             "invalid_sequence in JIS_X0208 at bit offset 14"

    assert {:ok, incomplete} = Packed.pack(<<0x46, 0x7C, 0x5C>>, 7)

    assert {:error,
            %Error{
              kind: :incomplete_sequence,
              offset: 14,
              offset_unit: :bit,
              sequence: <<0x5C::size(7)>>
            }} = Packed.decode_to_utf8(incomplete, "JIS_X0208", 7)
  end

  test "RED: LSB semantic failures retain their physical packed wire fragment" do
    assert {:ok, packed} = Packed.pack_lsb(@units, 7)

    assert {:error, %Error{} = error} =
             Packed.decode_to_utf8_lsb(packed, "JIS_X0208")

    assert error.kind == :invalid_sequence
    assert error.offset == 14
    assert Map.fetch!(error, :offset_unit) == :bit

    assert error.sequence ==
             %LSB{data: <<0, 0>>, bit_size: 14, unit_bits: 7, bit_order: :lsb}

    assert Exception.message(error) ==
             "invalid_sequence in JIS_X0208 at bit offset 14"

    assert {:ok, incomplete} = Packed.pack_lsb(<<0x46, 0x7C, 0x5C>>, 7)

    assert {:error,
            %Error{
              kind: :incomplete_sequence,
              offset: 14,
              offset_unit: :bit,
              sequence: %LSB{data: <<0x5C>>, bit_size: 7, unit_bits: 7, bit_order: :lsb}
            }} = Packed.decode_to_utf8_lsb(incomplete, "JIS_X0208")
  end
end
