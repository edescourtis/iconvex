defmodule Iconvex.Specs.BOCU1Test do
  use ExUnit.Case, async: false

  alias Iconvex.Specs.BOCU1

  test "matches the Unicode Technical Note BOM vector" do
    assert BOCU1.encode([0xFEFF]) == {:ok, <<0xFB, 0xEE, 0x28>>}
    assert BOCU1.decode(<<0xFB, 0xEE, 0x28>>) == {:ok, [0xFEFF]}
  end

  test "matches an independent ICU 78 multilingual vector" do
    utf8 = "Hello Καλημέρα 日本語 😀"

    encoded =
      <<0x98, 0xB5, 0xBC, 0xBC, 0xBF, 0x20, 0xD3, 0x4E, 0x81, 0x8B, 0x87, 0x8C, 0x7D, 0x91, 0x81,
        0x20, 0xFB, 0x49, 0x2D, 0x3F, 0x8B, 0xE4, 0x5E, 0x20, 0xFC, 0x82, 0x33>>

    assert BOCU1.encode(String.to_charlist(utf8)) == {:ok, encoded}
    assert BOCU1.decode(encoded) == {:ok, String.to_charlist(utf8)}
  end

  test "round trips every algorithm boundary and representative Unicode block" do
    codepoints =
      [
        0,
        0x20,
        0x21,
        0x7F,
        0x80,
        0x7FF,
        0x800,
        0x2FFF,
        0x3040,
        0x309F,
        0x4E00,
        0x9FA5,
        0xAC00,
        0xD7A3,
        0xE000,
        0xFFFF,
        0x10000,
        0x10FFFF
      ]

    assert {:ok, encoded} = BOCU1.encode(codepoints)
    assert BOCU1.decode(encoded) == {:ok, codepoints}
  end

  test "reset byte changes state without emitting a code point" do
    assert BOCU1.decode(<<0xFF, 0x91>>) == {:ok, [?A]}
  end

  test "reports incomplete and illegal trail sequences from their lead offsets" do
    assert BOCU1.decode(<<0xD0>>) == {:error, :incomplete_sequence, 0, <<0xD0>>}
    assert BOCU1.decode(<<0xD0, 0>>) == {:error, :invalid_sequence, 0, <<0xD0, 0>>}
  end

  test "RED: callback and substitution recovery consume the complete invalid sequence" do
    parent = self()

    callback = fn event ->
      send(parent, {:invalid_bocu1, event})
      :discard
    end

    input = <<0xD0, 0x00, 0x91>>

    assert Iconvex.convert(input, "BOCU-1", "UTF-8", on_invalid_byte: callback) ==
             {:ok, "A"}

    assert_receive {:invalid_bocu1,
                    %Iconvex.InvalidByte{
                      kind: :invalid_sequence,
                      encoding: "BOCU-1",
                      offset: 0,
                      byte: 0xD0,
                      sequence: <<0xD0, 0x00>>
                    }}

    refute_receive {:invalid_bocu1, _additional}

    assert Iconvex.convert(input, "BOCU-1", "UTF-8", byte_substitute: "<%02x>") ==
             {:ok, "<d0><00>A"}
  end

  test "preserves scalar lexical order for independently reset values" do
    encoded =
      for codepoint <- [0x21, 0x7F, 0x80, 0x3FF, 0x400, 0xFFFF, 0x10000, 0x10FFFF] do
        {:ok, bytes} = BOCU1.encode([codepoint])
        bytes
      end

    assert encoded == Enum.sort(encoded)
  end

  test "is registered using its IANA name" do
    assert Iconvex.canonical_name("BOCU1") == {:ok, "BOCU-1"}

    assert Iconvex.convert(<<0xFB, 0xEE, 0x28>>, "BOCU-1", "UTF-8") ==
             {:ok, <<0xFEFF::utf8>>}
  end
end
