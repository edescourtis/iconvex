defmodule Iconvex.Telecom.TBCDTest do
  use ExUnit.Case, async: true

  alias Iconvex.Telecom.TBCD

  test "encodes the low nibble first and pads an odd final digit with F" do
    assert TBCD.encode("12345") == {:ok, <<0x21, 0x43, 0xF5>>}
    assert TBCD.decode(<<0x21, 0x43, 0xF5>>) == {:ok, "12345"}
  end

  test "supports the complete telephony digit alphabet" do
    assert TBCD.encode("0123456789*#abc") ==
             {:ok, <<0x10, 0x32, 0x54, 0x76, 0x98, 0xBA, 0xDC, 0xFE>>}

    assert TBCD.decode(<<0x10, 0x32, 0x54, 0x76, 0x98, 0xBA, 0xDC, 0xFE>>) ==
             {:ok, "0123456789*#abc"}
  end

  test "rejects invalid digits and a filler anywhere except the final high nibble" do
    assert TBCD.encode("12+") == {:error, {:invalid_digit, 2, ?+}}
    assert TBCD.decode(<<0x1F>>) == {:error, {:invalid_filler, 0, :low}}
    assert TBCD.decode(<<0xF1, 0x32>>) == {:error, {:invalid_filler, 0, :high}}
  end
end
