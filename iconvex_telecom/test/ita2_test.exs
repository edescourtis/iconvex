defmodule Iconvex.Telecom.ITA2Test do
  use ExUnit.Case, async: false

  alias Iconvex.Telecom.ITA2
  alias Iconvex.Telecom.ITA2.Packing

  test "encodes and decodes the ITU-T S.1 letters/figures example" do
    encoded = <<20, 1, 18, 18, 24, 4, 27, 23, 19, 1>>
    assert ITA2.encode(String.to_charlist("HELLO 123")) == {:ok, encoded}
    assert ITA2.decode(encoded) == {:ok, String.to_charlist("HELLO 123")}
  end

  test "uses shifts only when the active alphabet does not contain the character" do
    assert ITA2.encode(String.to_charlist("A1B")) == {:ok, <<3, 27, 23, 31, 25>>}
    assert ITA2.decode(<<3, 27, 23, 31, 25>>) == {:ok, String.to_charlist("A1B")}

    assert ITA2.decode(<<27, 27, 23, 31, 31, 3>>) == {:ok, String.to_charlist("1A")}
  end

  test "rejects octets whose upper three bits are nonzero" do
    assert ITA2.decode(<<0x20>>) == {:error, :invalid_sequence, 0, <<0x20>>}
    assert ITA2.decode_discard(<<0x20, 3>>) == {:ok, [?A]}
  end

  test "packs and unpacks consecutive five-bit units without padding ambiguity" do
    units = <<20, 1, 18, 18, 24, 4, 27, 23, 19, 1>>
    assert {:ok, packed} = Packing.pack(units)
    assert bit_size(packed) == 50
    assert Packing.unpack(packed) == {:ok, units}
  end

  test "exhaustively exercises every letters and figures table position" do
    for {mode, table} <- ITA2.tables() do
      shift = if mode == :letters, do: <<31>>, else: <<27>>

      for {codepoint, code} <- table do
        assert ITA2.decode(shift <> <<code>>) == {:ok, [codepoint]}
      end
    end
  end

  test "registers ITA2 and its standards aliases" do
    assert Iconvex.canonical_name("ITA2") == {:ok, "ITA2"}
    assert Iconvex.canonical_name("CCITT-2") == {:ok, "ITA2"}
  end
end
