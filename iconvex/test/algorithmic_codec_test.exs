defmodule Iconvex.AlgorithmicCodecTest do
  use ExUnit.Case, async: true

  test "UTF-16 emits BOM, handles surrogate pairs, and consumes midstream byte-order marks" do
    assert Iconvex.convert("A😀", "UTF-8", "UTF-16") ==
             {:ok, <<0xFE, 0xFF, 0x00, 0x41, 0xD8, 0x3D, 0xDE, 0x00>>}

    assert Iconvex.convert(
             <<0xFE, 0xFF, 0x00, 0x41, 0xFF, 0xFE, 0x42, 0x00>>,
             "UTF-16",
             "UTF-8"
           ) == {:ok, "AB"}
  end

  test "fixed-endian UTF-16 does not emit a BOM" do
    assert Iconvex.convert("A😀", "UTF-8", "UTF-16LE") ==
             {:ok, <<0x41, 0x00, 0x3D, 0xD8, 0x00, 0xDE>>}

    assert Iconvex.convert(<<0x41, 0x00, 0x3D, 0xD8, 0x00, 0xDE>>, "UTF-16LE", "UTF-8") ==
             {:ok, "A😀"}
  end

  test "UCS-2 applies GNU's default replacement to supplementary characters" do
    assert Iconvex.convert("😀", "UTF-8", "UCS-2") == {:ok, <<0xFF, 0xFD>>}
  end

  test "C99 and JAVA escapes round-trip" do
    assert Iconvex.convert("é😀", "UTF-8", "C99") == {:ok, ~S(\u00e9\U0001f600)}
    assert Iconvex.convert(~S(\u00e9\U0001f600), "C99", "UTF-8") == {:ok, "é😀"}

    assert Iconvex.convert("é😀", "UTF-8", "JAVA") == {:ok, ~S(\u00e9\ud83d\ude00)}
    assert Iconvex.convert(~S(\u00e9\ud83d\ude00), "JAVA", "UTF-8") == {:ok, "é😀"}
  end

  test "GB18030 supplementary range uses algorithmic four-byte mapping" do
    encoded = <<0x94, 0x39, 0xFC, 0x36>>
    assert Iconvex.convert("😀", "UTF-8", "GB18030") == {:ok, encoded}
    assert Iconvex.convert(encoded, "GB18030", "UTF-8") == {:ok, "😀"}
    assert Iconvex.convert("😀", "UTF-8", "GB18030:2022") == {:ok, encoded}
  end
end
