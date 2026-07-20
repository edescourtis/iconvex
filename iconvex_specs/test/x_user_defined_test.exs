defmodule Iconvex.Specs.XUserDefinedTest do
  use ExUnit.Case, async: false

  alias Iconvex.Specs.XUserDefined

  test "implements the WHATWG byte-to-private-use mapping exhaustively" do
    bytes = :binary.list_to_bin(Enum.to_list(0..255))
    codepoints = Enum.to_list(0..0x7F) ++ Enum.to_list(0xF780..0xF7FF)

    assert XUserDefined.decode(bytes) == {:ok, codepoints}
    assert XUserDefined.encode(codepoints) == {:ok, bytes}
  end

  test "rejects Unicode values outside the encoding's two ranges" do
    assert XUserDefined.encode([0x80]) == {:error, :unrepresentable_character, 0x80}
    assert XUserDefined.encode([0xF800]) == {:error, :unrepresentable_character, 0xF800}
  end

  test "is registered under the WHATWG name" do
    assert Iconvex.canonical_name("x-user-defined") == {:ok, "X-USER-DEFINED"}
    assert Iconvex.convert(<<0x80>>, "x-user-defined", "UTF-8") == {:ok, <<0xF780::utf8>>}
  end
end
