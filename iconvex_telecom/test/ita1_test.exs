defmodule Iconvex.Telecom.ITA1Test do
  use ExUnit.Case, async: false

  alias Iconvex.Telecom.ITA1
  alias Iconvex.Telecom.ITA1.Packing

  @codes [
    30,
    19,
    18,
    16,
    29,
    17,
    21,
    20,
    25,
    22,
    6,
    4,
    5,
    1,
    24,
    0,
    2,
    3,
    11,
    10,
    26,
    8,
    9,
    13,
    27,
    12,
    28,
    14,
    15,
    23,
    7,
    31
  ]

  test "registers the historical International Telegraph Alphabet No. 1 names" do
    for name <- ["ITA1", "ITA-1", "CCITT-1", "CCITT-NO-1", "BAUDOT-ORIGINAL"] do
      assert Iconvex.canonical_name(name) == {:ok, "ITA1"}
    end
  end

  test "implements every polarity row of the 1958 ITU table" do
    table = ITA1.signal_table()
    assert Enum.map(1..32, &table[&1].code) == @codes
    assert Enum.sort(@codes) == Enum.to_list(0..31)

    for signal <- 1..32 do
      code = table[signal].code
      assert ITA1.signal_number(code) == {:ok, signal}
    end
  end

  test "implements the complete international letters and figures repertoire" do
    assert ITA1.encode(~c"MEET 4:30") ==
             {:ok, <<5, 29, 29, 10, 23, 26, 12, 27, 16>>}

    assert ITA1.decode(<<5, 29, 29, 10, 23, 26, 12, 27, 16>>) ==
             {:ok, ~c"MEET 4:30"}

    for {mode, table} <- ITA1.tables(), {codepoint, code} <- table do
      shift = if mode == :letters, do: <<15>>, else: <<23>>
      assert ITA1.decode(shift <> <<code>>) == {:ok, [32, codepoint]}
    end
  end

  test "does not invent mappings for national-use or non-text signals" do
    assert ITA1.national_use_signals() == [6, 9, 14, 20]

    for signal <- ITA1.national_use_signals() do
      code = Enum.at(@codes, signal - 1)

      assert ITA1.decode(<<23, code>>) ==
               {:error, :invalid_sequence, 1, <<code>>}
    end

    # Table rows 31 and 32 are Error and Instrument-at-rest, not characters.
    for code <- [7, 31] do
      assert ITA1.decode(<<code>>) == {:error, :invalid_sequence, 0, <<code>>}
    end

    # A figures character cannot be introduced without the specified blank.
    assert ITA1.encode(~c"4") == {:error, :unrepresentable_character, ?4}
  end

  test "exhausts every octet in both case states" do
    for byte <- 0..255 do
      letter_result = ITA1.decode(<<15, byte>>)
      figure_result = ITA1.decode(<<23, byte>>)

      if byte <= 31 and byte not in [7, 31] do
        assert match?({:ok, _}, letter_result)
      else
        assert match?({:error, :invalid_sequence, _, _}, letter_result)
      end

      if byte <= 31 and byte not in [1, 7, 10, 17, 25, 31] do
        assert match?({:ok, _}, figure_result)
      else
        assert match?({:error, :invalid_sequence, _, _}, figure_result)
      end
    end
  end

  test "packs all five-bit signals without padding ambiguity" do
    units = 0..31 |> Enum.to_list() |> :erlang.list_to_binary()
    assert {:ok, packed} = Packing.pack(units)
    assert bit_size(packed) == 160
    assert Packing.unpack(packed) == {:ok, units}
    assert Packing.pack(<<32>>) == {:error, :invalid_sequence, 0, <<32>>}
  end
end
