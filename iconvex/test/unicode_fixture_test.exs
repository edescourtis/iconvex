defmodule Iconvex.UnicodeFixtureTest do
  use ExUnit.Case, async: true

  @fixtures Path.expand("fixtures/gnu-libiconv-1.19", __DIR__)
  @encodings ~w(UCS-2BE UCS-2LE UCS-4BE UCS-4LE UTF-16 UTF-16BE UTF-16LE UTF-32 UTF-32BE UTF-32LE)

  for encoding <- @encodings do
    test "GNU libiconv 1.19 #{encoding} snippet decodes and re-encodes" do
      encoding = unquote(encoding)
      encoded = File.read!(Path.join(@fixtures, "#{encoding}-snippet"))
      utf8 = File.read!(Path.join(@fixtures, "#{encoding}-snippet.UTF-8"))

      assert Iconvex.convert(encoded, encoding, "UTF-8") == {:ok, utf8}
      assert Iconvex.convert(utf8, "UTF-8", encoding) == {:ok, encoded}
    end
  end
end
