defmodule Iconvex.Telecom.ITA4Test do
  use ExUnit.Case, async: false

  import Bitwise

  @table Map.new(0..31, fn
           0 -> {0, 1}
           unit -> {unit, unit <<< 1}
         end)

  test "registers the International Telegraph Alphabet No. 4 names" do
    for name <- ["ITA4", "ITA-4", "CCITT-4", "CCITT-NO-4", "ITU-T-R.44"] do
      assert Iconvex.canonical_name(name) == {:ok, "ITA4"}
    end
  end

  test "implements all 32 normative R.44 traffic combinations" do
    assert Iconvex.Telecom.ITA4.traffic_table() == @table

    for {ita2, ita4} <- @table do
      assert Iconvex.Telecom.ITA4.from_ita2(<<ita2>>) == {:ok, <<ita4>>}
      assert Iconvex.Telecom.ITA4.to_ita2(<<ita4>>) == {:ok, <<ita2>>}
    end
  end

  test "exhausts the complete six-bit space and rejects high-bit octets" do
    inverse = Map.new(@table, fn {ita2, ita4} -> {ita4, ita2} end)

    for byte <- 0..255 do
      case inverse do
        %{^byte => ita2} ->
          assert Iconvex.Telecom.ITA4.to_ita2(<<byte>>) == {:ok, <<ita2>>}

        _ ->
          assert match?({:error, :invalid_sequence, 0, _}, Iconvex.Telecom.ITA4.to_ita2(<<byte>>))
      end
    end
  end

  test "preserves the complete ITA2 text state machine through ITA4" do
    text = ~c"THE QUICK BROWN FOX 123 / 456"
    assert {:ok, ita2} = Iconvex.Telecom.ITA2.encode(text)

    expected = for <<unit <- ita2>>, into: <<>>, do: <<Map.fetch!(@table, unit)>>
    assert Iconvex.Telecom.ITA4.encode(text) == {:ok, expected}
    assert Iconvex.Telecom.ITA4.decode(expected) == {:ok, text}
  end

  test "keeps the three multiplex service signals out of Unicode text" do
    assert Iconvex.Telecom.ITA4.service_signals() == %{alpha: 0, beta: 63, phasing: 51}

    for signal <- [0, 63, 51] do
      assert Iconvex.Telecom.ITA4.decode(<<signal>>) ==
               {:error, :invalid_sequence, 0, <<signal>>}
    end
  end
end
