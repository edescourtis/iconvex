defmodule Iconvex.Specs.SCSUTest do
  use ExUnit.Case, async: false

  alias Iconvex.Specs.SCSU

  @icu_vectors [
    {"Hello Ångström",
     <<0x48, 0x65, 0x6C, 0x6C, 0x6F, 0x20, 0xC5, 0x6E, 0x67, 0x73, 0x74, 0x72, 0xF6, 0x6D>>},
    {"Καλημέρα", <<0x1F, 0xFB, 0xAA, 0xC1, 0xCB, 0xC7, 0xCC, 0xBD, 0xD1, 0xC1>>},
    {"日本語", <<0x0F, 0x65, 0xE5, 0x67, 0x2C, 0x8A, 0x9E>>},
    {"😀😁😂", <<0x0B, 0xE1, 0xEC, 0x80, 0x81, 0x82>>},
    {"A\uE000B", <<0x41, 0x1F, 0x68, 0x80, 0x42>>},
    {"हिन्दी", <<0x14, 0xB9, 0xBF, 0xA8, 0xCD, 0xA6, 0xC0>>}
  ]

  test "matches ICU 78 vectors for every SCSU compression path" do
    Enum.each(@icu_vectors, fn {utf8, encoded} ->
      codepoints = String.to_charlist(utf8)
      assert SCSU.decode(encoded) == {:ok, codepoints}
      assert SCSU.encode(codepoints) == {:ok, encoded}
    end)
  end

  test "combines surrogate pairs even when each unit is separately quoted" do
    encoded = <<0x0E, 0xD8, 0x3D, 0x0E, 0xDE, 0x00>>
    assert SCSU.decode(encoded) == {:ok, [0x1F600]}
  end

  test "rejects reserved commands, reserved window indexes, and truncation" do
    assert SCSU.decode(<<0x0C>>) == {:error, :invalid_sequence, 0, <<0x0C>>}
    assert SCSU.decode(<<0x18, 0>>) == {:error, :invalid_sequence, 0, <<0x18, 0>>}
    assert SCSU.decode(<<0x0F, 0xF2>>) == {:error, :invalid_sequence, 1, <<0xF2>>}

    assert SCSU.decode(<<0x0E, 0x12>>) ==
             {:error, :incomplete_sequence, 0, <<0x0E, 0x12>>}
  end

  test "covers all scalar range transitions in one stateful stream" do
    codepoints =
      [
        0,
        1,
        9,
        0x7F,
        0x80,
        0x17F,
        0x300,
        0x33FF,
        0x3400,
        0xD7FF,
        0xE000,
        0xFFFF,
        0x10000,
        0x10FFFF
      ]

    assert {:ok, encoded} = SCSU.encode(codepoints)
    assert SCSU.decode(encoded) == {:ok, codepoints}
  end

  test "is registered using the IANA name" do
    assert Iconvex.canonical_name("csSCSU") == {:ok, "SCSU"}

    assert Iconvex.convert(<<0x0B, 0xE1, 0xEC, 0x80>>, "SCSU", "UTF-8") ==
             {:ok, "😀"}
  end
end
