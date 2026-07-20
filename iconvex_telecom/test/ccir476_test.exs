defmodule Iconvex.Telecom.CCIR476Test do
  use ExUnit.Case, async: false

  import Bitwise

  alias Iconvex.Telecom.CCIR476
  alias Iconvex.Telecom.CCIR476.Packing

  @hello <<0x4B, 0x35, 0x53, 0x53, 0x47, 0x1D, 0x36, 0x3A, 0x72, 0x35>>

  test "encodes the ITU-R M.476-5 traffic table through ITA2 state" do
    assert CCIR476.encode(String.to_charlist("HELLO 123")) == {:ok, @hello}
    assert CCIR476.decode(@hello) == {:ok, String.to_charlist("HELLO 123")}
  end

  test "exhaustively implements all 32 four-of-seven traffic signals" do
    table = CCIR476.traffic_table()
    assert map_size(table) == 32

    for {ita2_unit, signal} <- table do
      assert popcount(signal) == 4
      assert CCIR476.from_ita2(<<ita2_unit>>) == {:ok, <<signal>>}
      assert CCIR476.to_ita2(<<signal>>) == {:ok, <<ita2_unit>>}
    end

    inverse = Map.new(table, fn {ita2_unit, signal} -> {signal, ita2_unit} end)

    for signal <- 0..127 do
      case inverse do
        %{^signal => ita2_unit} ->
          assert CCIR476.to_ita2(<<signal>>) == {:ok, <<ita2_unit>>}

        _ ->
          assert CCIR476.to_ita2(<<signal>>) ==
                   {:error, :invalid_sequence, 0, <<signal>>}
      end
    end
  end

  test "publishes the exact service signals separately from text" do
    assert CCIR476.service_signals() == %{
             alpha: 0x78,
             beta: 0x66,
             cs1: 0x53,
             cs2: 0x2B,
             cs3: 0x4D,
             repetition: 0x33
           }

    assert CCIR476.decode(<<0x33>>) == {:error, :invalid_sequence, 0, <<0x33>>}
    assert CCIR476.decode(<<0x66>>) == {:error, :invalid_sequence, 0, <<0x66>>}
    assert CCIR476.decode(<<0x78>>) == {:error, :invalid_sequence, 0, <<0x78>>}
  end

  test "rejects malformed signals and discards them without corrupting shift state" do
    assert CCIR476.decode(<<0x00>>) == {:error, :invalid_sequence, 0, <<0x00>>}
    assert CCIR476.decode(<<0x80>>) == {:error, :invalid_sequence, 0, <<0x80>>}
    assert CCIR476.decode_discard(<<0x36, 0x00, 0x3A, 0x2D, 0x71>>) == {:ok, ~c"1A"}
  end

  test "packs seven-unit signals and applies the specified FEC polarity inversion" do
    assert {:ok, packed} = Packing.pack(@hello)
    assert bit_size(packed) == 70
    assert Packing.unpack(packed) == {:ok, @hello}

    inverted = for <<signal <- @hello>>, into: <<>>, do: <<bxor(signal, 0x7F)>>
    assert CCIR476.invert(@hello) == {:ok, inverted}
    assert CCIR476.invert(inverted) == {:ok, @hello}
  end

  test "registers the CCIR, SITOR, and NAVTEX names" do
    assert Iconvex.canonical_name("CCIR476") == {:ok, "CCIR476"}
    assert Iconvex.canonical_name("SITOR-B") == {:ok, "CCIR476"}
    assert Iconvex.canonical_name("NAVTEX") == {:ok, "CCIR476"}
  end

  defp popcount(value), do: value |> Integer.digits(2) |> Enum.sum()
end
