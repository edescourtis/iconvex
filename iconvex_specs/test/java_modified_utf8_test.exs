defmodule Iconvex.Specs.JavaModifiedUTF8Test do
  use ExUnit.Case, async: false

  alias Iconvex.Specs.JavaModifiedUTF8

  test "encodes NUL specially and supplementary characters as surrogate pairs" do
    codepoints = [0, 0x7F, 0x80, 0x7FF, 0x800, 0xFFFF, 0x1F600]

    encoded =
      <<0xC0, 0x80, 0x7F, 0xC2, 0x80, 0xDF, 0xBF, 0xE0, 0xA0, 0x80, 0xEF, 0xBF, 0xBF, 0xED, 0xA0,
        0xBD, 0xED, 0xB8, 0x80>>

    assert JavaModifiedUTF8.encode(codepoints) == {:ok, encoded}
    assert JavaModifiedUTF8.decode(encoded) == {:ok, codepoints}
  end

  test "rejects forms that are not canonical Java modified UTF-8" do
    assert JavaModifiedUTF8.decode(<<0>>) == {:error, :invalid_sequence, 0, <<0>>}

    assert JavaModifiedUTF8.decode(<<0xC1, 0x81>>) ==
             {:error, :invalid_sequence, 0, <<0xC1, 0x81>>}

    assert JavaModifiedUTF8.decode(<<0xF0, 0x9F, 0x98, 0x80>>) ==
             {:error, :invalid_sequence, 0, <<0xF0>>}

    assert JavaModifiedUTF8.decode(<<0xED, 0xA0, 0xBD>>) ==
             {:error, :incomplete_sequence, 0, <<0xED, 0xA0, 0xBD>>}
  end

  test "is registered as a public-spec external codec" do
    assert Iconvex.canonical_name("MUTF-8") == {:ok, "JAVA-MODIFIED-UTF-8"}
    assert Iconvex.convert(<<0xC0, 0x80>>, "MUTF-8", "UTF-8") == {:ok, <<0>>}
  end

  test "registers Android DEX's identical modified UTF-8 wire encoding" do
    for name <- ["DEX-MUTF-8", "DEX-MODIFIED-UTF-8", "ANDROID-DEX-MUTF-8"] do
      assert Iconvex.canonical_name(name) == {:ok, "JAVA-MODIFIED-UTF-8"}
    end

    sample = [0, ?A, 0x20AC, 0x1F600]

    assert JavaModifiedUTF8.encode(sample) ==
             {:ok, <<0xC0, 0x80, 0x41, 0xE2, 0x82, 0xAC, 0xED, 0xA0, 0xBD, 0xED, 0xB8, 0x80>>}
  end
end
