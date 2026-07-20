defmodule Iconvex.Specs.CESU8Test do
  use ExUnit.Case, async: false

  alias Iconvex.Specs.CESU8

  test "implements the six-byte supplementary form from UTR 26" do
    encoded = <<0x4D, 0x61, 0xED, 0xA0, 0x80, 0xED, 0xB0, 0x80>>
    assert CESU8.encode([?M, ?a, 0x10000]) == {:ok, encoded}
    assert CESU8.decode(encoded) == {:ok, [?M, ?a, 0x10000]}
  end

  test "accepts shortest BMP forms and rejects UTF-8 four-byte forms" do
    assert CESU8.decode("A¢€") == {:ok, [?A, 0xA2, 0x20AC]}

    assert CESU8.decode(<<0xF0, 0x90, 0x80, 0x80>>) ==
             {:error, :invalid_sequence, 0, <<0xF0>>}

    assert CESU8.decode(<<0xC0, 0x80>>) == {:error, :invalid_sequence, 0, <<0xC0>>}
  end

  test "requires paired UTF-16 surrogates and reports truncation" do
    assert CESU8.decode(<<0xED, 0xA0, 0x80>>) ==
             {:error, :incomplete_sequence, 0, <<0xED, 0xA0, 0x80>>}

    assert CESU8.decode(<<0xED, 0xB0, 0x80>>) ==
             {:error, :invalid_sequence, 0, <<0xED, 0xB0, 0x80>>}
  end

  test "registers as an external Iconvex codec" do
    assert Iconvex.canonical_name("csCESU-8") == {:ok, "CESU-8"}

    assert Iconvex.convert(<<0xED, 0xA0, 0x80, 0xED, 0xB0, 0x80>>, "CESU-8", "UTF-8") ==
             {:ok, <<0xF0, 0x90, 0x80, 0x80>>}
  end
end
