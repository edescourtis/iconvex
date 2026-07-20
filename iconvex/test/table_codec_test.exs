defmodule Iconvex.TableCodecTest do
  use ExUnit.Case, async: true

  test "encodes UTF-8 into a single-byte table" do
    assert Iconvex.convert("café €", "UTF-8", "CP1252") ==
             {:ok, <<0x63, 0x61, 0x66, 0xE9, 0x20, 0x80>>}
  end

  test "decodes and encodes a multibyte table" do
    encoded = <<0x93, 0xFA, 0x96, 0x7B>>
    assert Iconvex.convert(encoded, "SHIFT_JIS", "UTF-8") == {:ok, "日本"}
    assert Iconvex.convert("日本", "UTF-8", "SHIFT_JIS") == {:ok, encoded}
  end

  test "returns byte offset and offending sequence for invalid input" do
    assert {:error,
            %Iconvex.Error{
              kind: :invalid_sequence,
              encoding: "SHIFT_JIS",
              offset: 1,
              sequence: <<0x80>>
            }} = Iconvex.convert(<<0x41, 0x80>>, "SHIFT_JIS", "UTF-8")
  end
end
