defmodule Iconvex.Specs.KOI7SwitchedTest do
  use ExUnit.Case, async: false

  alias Iconvex.Specs.KOI7Switched

  test "implements the IANA initial state and 016/017 octal switches" do
    encoded = <<?A, 0o16, 0x61, 0x51, 0o17, ?Z>>
    assert KOI7Switched.decode(encoded) == {:ok, [?A, 0x0410, 0x044F, ?Z]}
    assert KOI7Switched.encode([?A, 0x0410, 0x044F, ?Z]) == {:ok, encoded}
  end

  test "the switched state exactly delegates every non-switch ISO 5427 byte" do
    for byte <- 0..0x7F, byte not in [0o16, 0o17] do
      assert {:ok, expected} = Iconvex.convert(<<byte>>, "ISO_5427", "UTF-32BE")
      assert {:ok, actual} = Iconvex.convert(<<0o16, byte>>, "KOI7-switched", "UTF-32BE")
      assert actual == expected, "byte #{inspect(byte, base: :hex)}"
    end
  end

  test "switches are syntax, high-bit octets are invalid, and discard retains state" do
    assert KOI7Switched.decode(<<0o16, 0o17>>) == {:ok, []}
    assert KOI7Switched.decode(<<0x80>>) == {:error, :invalid_sequence, 0, <<0x80>>}
    assert KOI7Switched.encode([0o16]) == {:error, :unrepresentable_character, 0o16}
    assert KOI7Switched.decode_discard(<<0o16, 0x80, 0x61>>) == {:ok, [0x0410]}
  end

  test "registers the IANA name and historical cs alias" do
    assert {:ok, %{canonical: "KOI7-switched"}} = Iconvex.Registry.resolve("csKOI7switched")
  end
end
