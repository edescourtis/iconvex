defmodule Iconvex.ISO2022JPTest do
  use ExUnit.Case, async: true

  @fixtures Path.expand("fixtures/gnu-libiconv-1.19", __DIR__)
  @encodings [
    "ISO-2022-JP",
    "ISO-2022-JP-1",
    "ISO-2022-JP-2",
    "ISO-2022-JP-MS"
  ]

  for encoding <- @encodings do
    test "GNU libiconv 1.19 #{encoding} snippet decodes and re-encodes" do
      encoding = unquote(encoding)
      encoded = File.read!(Path.join(@fixtures, "#{encoding}-snippet"))
      utf8 = File.read!(Path.join(@fixtures, "#{encoding}-snippet.UTF-8"))

      assert Iconvex.convert(encoded, encoding, "UTF-8") == {:ok, utf8}
      assert Iconvex.convert(utf8, "UTF-8", encoding) == {:ok, encoded}
    end
  end

  test "ISO-2022-JP switches between ASCII, JIS Roman, and JIS X 0208" do
    encoded = <<0x1B, "(J", 0x5C, 0x7E, 0x1B, "$B", 0x46, 0x7C, 0x4B, 0x5C, 0x1B, "(B">>

    assert Iconvex.convert(encoded, "ISO-2022-JP", "UTF-8") == {:ok, "¥‾日本"}
  end
end
