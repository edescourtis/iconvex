defmodule Iconvex.Telecom.ITA2S2Test do
  use ExUnit.Case, async: false

  alias Iconvex.Telecom.ITA2S2

  @fs 27
  @ls 31

  test "uses one LS for an isolated capital and reverts to small letters" do
    encoded = <<3, @ls, 25, 14>>
    assert ITA2S2.encode(~c"aBc") == {:ok, encoded}
    assert ITA2S2.decode(encoded) == {:ok, ~c"aBc"}
  end

  test "locks groups of three capitals with FS LS and unlocks with LS" do
    assert ITA2S2.encode(~c"ABCd") == {:ok, <<@fs, @ls, 3, 25, 14, @ls, 9>>}
    assert ITA2S2.decode(<<@fs, @ls, 3, 25, 14, @ls, 9>>) == {:ok, ~c"ABCd"}

    assert ITA2S2.encode(~c"A B C") ==
             {:ok, <<@fs, @ls, 3, 4, 25, 4, 14>>}
  end

  test "preserves mode while entering figures and handles case after figures" do
    assert ITA2S2.encode(~c"a1B") == {:ok, <<3, @fs, 23, @ls, @ls, 25>>}
    assert ITA2S2.decode(<<3, @fs, 23, @ls, @ls, 25>>) == {:ok, ~c"a1B"}

    assert ITA2S2.encode(~c"a1BCD") ==
             {:ok, <<3, @fs, 23, @ls, @fs, @ls, 25, 14, 9>>}
  end

  test "recognizes the normative FS LS LS initialization sequence" do
    assert ITA2S2.decode(<<@fs, @ls, @ls, 3, 25, 14>>) == {:ok, ~c"abc"}
  end

  test "round trips the complete Latin alphabet in both cases" do
    text = ~c"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
    assert {:ok, encoded} = ITA2S2.encode(text)
    assert ITA2S2.decode(encoded) == {:ok, text}
  end

  test "is strict about unpacked units and registers S.2 aliases" do
    assert ITA2S2.decode(<<64>>) == {:error, :invalid_sequence, 0, <<64>>}
    assert ITA2S2.decode_discard(<<64, 3, 255>>) == {:ok, ~c"a"}
    assert ITA2S2.encode([0x00E9]) == {:error, :unrepresentable_character, 0x00E9}
    assert Iconvex.canonical_name("ITA2-S2") == {:ok, "ITA2-S2"}
    assert Iconvex.canonical_name("ITU-T-S.2") == {:ok, "ITA2-S2"}
  end
end
