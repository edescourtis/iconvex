defmodule Iconvex.ISO2022CNTest do
  use ExUnit.Case, async: true

  @fixtures Path.expand("fixtures/gnu-libiconv-1.19", __DIR__)

  for encoding <- ["ISO-2022-CN", "ISO-2022-CN-EXT"] do
    test "GNU libiconv 1.19 #{encoding} snippet decodes and re-encodes" do
      encoding = unquote(encoding)
      encoded = File.read!(Path.join(@fixtures, "#{encoding}-snippet"))
      utf8 = File.read!(Path.join(@fixtures, "#{encoding}-snippet.UTF-8"))

      assert Iconvex.convert(encoded, encoding, "UTF-8") == {:ok, utf8}
      assert Iconvex.convert(utf8, "UTF-8", encoding) == {:ok, encoded}
    end
  end

  test "ISO-2022-CN-EXT designates ISO-IR-165 as G1" do
    utf8 = <<32470::utf8>>
    encoded = <<0x1B, "$)E", 0x0E, 0x7E, 0x57, 0x0F>>

    assert Iconvex.convert(utf8, "UTF-8", "ISO-2022-CN-EXT") == {:ok, encoded}
    assert Iconvex.convert(encoded, "ISO-2022-CN-EXT", "UTF-8") == {:ok, utf8}
  end
end
