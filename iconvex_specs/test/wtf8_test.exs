defmodule Iconvex.Specs.WTF8Test do
  use ExUnit.Case, async: false
  import Bitwise

  alias Iconvex.Specs.WTF8

  test "registers the public WTF-8 specification names" do
    for name <- ["WTF-8", "WTF8", "WOBBLY-TRANSFORMATION-FORMAT-8"] do
      assert Iconvex.canonical_name(name) == {:ok, "WTF-8"}
    end
  end

  @tag timeout: 120_000
  test "is byte-identical to UTF-8 for every Unicode scalar value" do
    scalars = Enum.to_list(0..0xD7FF) ++ Enum.to_list(0xE000..0x10FFFF)
    utf8 = :unicode.characters_to_binary(scalars, :unicode, :utf8)

    assert WTF8.encode(scalars) == {:ok, utf8}
    assert WTF8.decode(utf8) == {:ok, scalars}
  end

  test "round-trips every isolated surrogate as its generalized UTF-8 sequence" do
    surrogates = Enum.to_list(0xD800..0xDFFF)

    encoded =
      for codepoint <- surrogates, into: <<>> do
        <<0xE0 ||| codepoint >>> 12, 0x80 ||| (codepoint >>> 6 &&& 0x3F),
          0x80 ||| (codepoint &&& 0x3F)>>
      end

    # Keep every surrogate isolated from a complementary neighbour.
    separated = Enum.intersperse(surrogates, ?|)

    separated_encoded =
      encoded
      |> :binary.bin_to_list()
      |> Enum.chunk_every(3)
      |> Enum.map(&IO.iodata_to_binary/1)
      |> Enum.intersperse("|")
      |> IO.iodata_to_binary()

    assert WTF8.encode(separated) == {:ok, separated_encoded}
    assert WTF8.decode(separated_encoded) == {:ok, separated}
  end

  test "normalizes paired surrogates and rejects their six-byte non-WTF-8 spelling" do
    high = 0xD83D
    low = 0xDE00
    scalar = 0x1F600
    generalized_pair = <<0xED, 0xA0, 0xBD, 0xED, 0xB8, 0x80>>

    assert WTF8.encode([high, low]) == {:ok, <<scalar::utf8>>}
    assert WTF8.decode(<<scalar::utf8>>) == {:ok, [scalar]}

    assert WTF8.decode(generalized_pair) ==
             {:error, :invalid_sequence, 0, generalized_pair}

    assert WTF8.decode(<<0xED, 0xA0, 0xBD, ?A, 0xED, 0xB8, 0x80>>) ==
             {:ok, [high, ?A, low]}
  end

  test "enforces canonical generalized UTF-8 grammar and exact error offsets" do
    for input <- [
          <<0x80>>,
          <<0xC0, 0x80>>,
          <<0xC1, 0xBF>>,
          <<0xE0, 0x9F, 0x80>>,
          <<0xF0, 0x8F, 0xBF, 0xBF>>,
          <<0xF4, 0x90, 0x80, 0x80>>,
          <<0xF5, 0x80, 0x80, 0x80>>
        ] do
      assert {:error, :invalid_sequence, 0, _sequence} = WTF8.decode(input)
    end

    assert WTF8.decode(<<?A, 0xC2>>) ==
             {:error, :incomplete_sequence, 1, <<0xC2>>}

    assert WTF8.decode(<<?A, 0xE1, 0x80>>) ==
             {:error, :incomplete_sequence, 1, <<0xE1, 0x80>>}

    assert WTF8.decode(<<?A, 0xF0, 0x90, 0x80>>) ==
             {:error, :incomplete_sequence, 1, <<0xF0, 0x90, 0x80>>}
  end

  test "discard mode remains linear and UTF-8 target policies match GNU surrogate fallback" do
    assert WTF8.decode_discard(<<?A, 0x80, ?B, 0xED, 0xA0, 0x80, ?C>>) ==
             {:ok, [?A, ?B, 0xD800, ?C]}

    assert WTF8.encode_discard([?A, -1, 0xD800, ?B, 0x11_0000, ?C]) ==
             {:ok, <<?A, 0xED, 0xA0, 0x80, ?B, ?C>>}

    surrogate = <<0xED, 0xA0, 0x80>>

    assert Iconvex.convert(surrogate, "WTF-8", "UTF-8") == {:ok, "�"}
    assert Iconvex.convert(surrogate, "WTF-8", "UTF-8", transliterate: true) == {:ok, "�"}

    assert Iconvex.convert(surrogate, "WTF-8", "UTF-8", unrepresentable: :discard) ==
             {:ok, <<>>}

    assert Iconvex.convert(
             surrogate,
             "WTF-8",
             "UTF-8",
             unicode_substitute: "<U+%04X>"
           ) == {:ok, "<U+D800>"}

    assert Iconvex.convert(surrogate, "WTF-8", "WTF-8") == {:ok, surrogate}
  end
end
