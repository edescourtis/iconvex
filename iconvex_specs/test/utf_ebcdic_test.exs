defmodule Iconvex.Specs.UTFEBCDICCTest do
  use ExUnit.Case, async: false

  alias Iconvex.Specs.UTFEBCDIC

  test "matches the UTR #16 signature and EBCDIC invariant vectors" do
    assert UTFEBCDIC.encode([0xFEFF]) == {:ok, <<0xDD, 0x73, 0x66, 0x73>>}
    assert UTFEBCDIC.decode(<<0xDD, 0x73, 0x66, 0x73>>) == {:ok, [0xFEFF]}
    assert UTFEBCDIC.encode([?A, ?a, ?0, 0x0A]) == {:ok, <<0xC1, 0x81, 0xF0, 0x15>>}
  end

  test "round trips every I8 length boundary" do
    codepoints = [
      0,
      0x7F,
      0x80,
      0x9F,
      0xA0,
      0x3FF,
      0x400,
      0x3FFF,
      0x4000,
      0x3FFFF,
      0x40000,
      0x10FFFF
    ]

    assert {:ok, encoded} = UTFEBCDIC.encode(codepoints)
    assert UTFEBCDIC.decode(encoded) == {:ok, codepoints}
  end

  test "rejects non-shortest, malformed, incomplete, and surrogate forms" do
    assert UTFEBCDIC.decode(<<0x74, 0x42>>) ==
             {:error, :invalid_sequence, 0, <<0x74, 0x42>>}

    assert UTFEBCDIC.decode(<<0x80, 0x00>>) ==
             {:error, :invalid_sequence, 0, <<0x80, 0x00>>}

    assert UTFEBCDIC.decode(<<0x80>>) == {:error, :incomplete_sequence, 0, <<0x80>>}
    assert UTFEBCDIC.encode([0xD800]) == {:error, :unrepresentable_character, 0xD800}
  end

  test "registers the Unicode encoding name" do
    assert Iconvex.canonical_name("UTF_EBCDIC") == {:ok, "UTF-EBCDIC"}

    assert Iconvex.convert(<<0xDD, 0x73, 0x66, 0x73>>, "UTF-EBCDIC", "UTF-8") ==
             {:ok, <<0xFEFF::utf8>>}
  end
end
