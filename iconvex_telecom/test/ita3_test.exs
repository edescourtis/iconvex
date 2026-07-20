defmodule Iconvex.Telecom.ITA3Test do
  use ExUnit.Case, async: false

  @table %{
    0 => 112,
    1 => 14,
    2 => 13,
    3 => 44,
    4 => 11,
    5 => 42,
    6 => 7,
    7 => 38,
    8 => 97,
    9 => 28,
    10 => 19,
    11 => 98,
    12 => 21,
    13 => 100,
    14 => 25,
    15 => 104,
    16 => 81,
    17 => 70,
    18 => 35,
    19 => 82,
    20 => 37,
    21 => 84,
    22 => 41,
    23 => 88,
    24 => 49,
    25 => 76,
    26 => 67,
    27 => 50,
    28 => 69,
    29 => 52,
    30 => 73,
    31 => 56
  }

  test "registers the International Telegraph Alphabet No. 3 names" do
    for name <- ["ITA3", "ITA-3", "CCITT-3", "CCITT-NO-3", "ITU-T-S.13"] do
      assert Iconvex.canonical_name(name) == {:ok, "ITA3"}
    end
  end

  test "implements every S.13 ITA2-to-ITA3 code conversion" do
    assert Iconvex.Telecom.ITA3.traffic_table() == @table

    for {ita2, ita3} <- @table do
      assert Iconvex.Telecom.ITA3.from_ita2(<<ita2>>) == {:ok, <<ita3>>}
      assert Iconvex.Telecom.ITA3.to_ita2(<<ita3>>) == {:ok, <<ita2>>}
      assert popcount(ita3) == 3
    end
  end

  test "exhausts all possible seven-bit and octet inputs" do
    inverse = Map.new(@table, fn {ita2, ita3} -> {ita3, ita2} end)

    for byte <- 0..255 do
      case inverse do
        %{^byte => ita2} ->
          assert Iconvex.Telecom.ITA3.to_ita2(<<byte>>) == {:ok, <<ita2>>}

        _ ->
          assert match?({:error, :invalid_sequence, 0, _}, Iconvex.Telecom.ITA3.to_ita2(<<byte>>))
      end
    end
  end

  test "preserves the complete ITA2 text state machine through ITA3" do
    text = ~c"THE QUICK BROWN FOX 123 / 456"
    assert {:ok, ita2} = Iconvex.Telecom.ITA2.encode(text)

    expected = for <<unit <- ita2>>, into: <<>>, do: <<Map.fetch!(@table, unit)>>
    assert Iconvex.Telecom.ITA3.encode(text) == {:ok, expected}
    assert Iconvex.Telecom.ITA3.decode(expected) == {:ok, text}
  end

  test "keeps ARQ service signals out of Unicode text" do
    assert Iconvex.Telecom.ITA3.service_signals() == %{alpha: 74, beta: 26, repetition: 22}

    for signal <- [22, 74, 26] do
      assert Iconvex.Telecom.ITA3.decode(<<signal>>) ==
               {:error, :invalid_sequence, 0, <<signal>>}
    end
  end

  defp popcount(value), do: value |> Integer.digits(2) |> Enum.sum()
end
