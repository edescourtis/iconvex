defmodule Iconvex.Extras.ISO2022JP3Test do
  use ExUnit.Case, async: false

  @fixtures Path.expand("fixtures", __DIR__)

  test "GNU ISO-2022-JP-3 snippet decodes and re-encodes" do
    encoded = File.read!(Path.join(@fixtures, "ISO-2022-JP-3-snippet"))
    utf8 = File.read!(Path.join(@fixtures, "ISO-2022-JP-3-snippet.UTF-8"))

    assert Iconvex.convert(encoded, "ISO-2022-JP-3", "UTF-8") == {:ok, utf8}
    assert Iconvex.convert(utf8, "UTF-8", "ISO-2022-JP-3") == {:ok, encoded}
  end

  test "stateful codec exposes only stateful-correct UCS-4 adapters and matches slow bytes" do
    module = Iconvex.Extras.Codecs.Iso2022Jp3
    encoded = File.read!(Path.join(@fixtures, "ISO-2022-JP-3-snippet"))
    utf8 = File.read!(Path.join(@fixtures, "ISO-2022-JP-3-snippet.UTF-8"))
    codepoints = :unicode.characters_to_list(utf8, :utf8)

    assert function_exported?(module, :decode_to_ucs4_discard, 2)
    assert function_exported?(module, :encode_from_ucs4_discard, 2)

    assert module.decode(encoded) == Iconvex.Extras.CodecSupport.decode_iso2022_jp3(encoded)
    assert module.decode(encoded) == {:ok, codepoints}

    assert module.encode(codepoints) == Iconvex.Extras.CodecSupport.encode_iso2022_jp3(codepoints)
    assert module.encode(codepoints) == {:ok, encoded}

    ucs4 = IO.iodata_to_binary(Enum.map(codepoints, &<<&1::unsigned-big-32>>))

    assert module.decode_to_ucs4_discard(encoded, :big) == {:ok, ucs4}
    assert module.encode_from_ucs4_discard(ucs4, :big) == {:ok, encoded}
  end

  test "ISO-2022-JP-3 preserves state across discard encoding" do
    assert Iconvex.convert("日😀本", "UTF-8", "ISO-2022-JP-3", unrepresentable: :discard) ==
             {:ok, <<0x1B, "$B", 0x46, 0x7C, 0x4B, 0x5C, 0x1B, "(B">>}
  end

  test "ISO-2022-JP-3 preserves designation while discarding invalid bytes" do
    encoded = <<0x1B, "$B", 0x46, 0x7C, 0xFF, 0x4B, 0x5C, 0x1B, "(B">>

    assert Iconvex.convert(encoded, "ISO-2022-JP-3", "UTF-8", invalid: :discard) ==
             {:ok, "日本"}
  end

  test "ISO-2022-JP-3 streams source and target state across every split" do
    input = "ASCII 日本語 ASCII"
    encoded = Iconvex.convert!(input, "UTF-8", "ISO-2022-JP-3")

    for split <- 0..byte_size(encoded) do
      <<first::binary-size(split), second::binary>> = encoded

      assert [first, second]
             |> Iconvex.stream!("ISO-2022-JP-3", "UTF-8")
             |> Enum.join() == input
    end

    for split <- 0..byte_size(input) do
      <<first::binary-size(split), second::binary>> = input

      assert [first, second]
             |> Iconvex.stream!("UTF-8", "ISO-2022-JP-3")
             |> Enum.join() == encoded
    end
  end
end
