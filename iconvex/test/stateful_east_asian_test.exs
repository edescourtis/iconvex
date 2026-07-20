defmodule Iconvex.StatefulEastAsianTest do
  use ExUnit.Case, async: true

  @fixtures Path.expand("fixtures/gnu-libiconv-1.19", __DIR__)

  for encoding <- ["HZ", "ISO-2022-KR"] do
    test "GNU libiconv 1.19 #{encoding} snippet decodes and re-encodes" do
      encoding = unquote(encoding)
      encoded = File.read!(Path.join(@fixtures, "#{encoding}-snippet"))
      utf8 = File.read!(Path.join(@fixtures, "#{encoding}-snippet.UTF-8"))

      assert Iconvex.convert(encoded, encoding, "UTF-8") == {:ok, utf8}
      assert Iconvex.convert(utf8, "UTF-8", encoding) == {:ok, encoded}
    end
  end

  test "HZ handles shifts, literal tilde, and line continuation" do
    hz = "~{VPND~}~~\n~\nASCII"

    assert Iconvex.convert(hz, "HZ", "UTF-8") == {:ok, "中文~\nASCII"}
  end

  test "ISO-2022-KR designates KSC 5601 and shifts with SO/SI" do
    encoded = <<0x1B, "$)C", 0x0E, 0x47, 0x51, 0x31, 0x5B, 0x0F>>

    assert Iconvex.convert(encoded, "ISO-2022-KR", "UTF-8") == {:ok, "한글"}
  end
end
