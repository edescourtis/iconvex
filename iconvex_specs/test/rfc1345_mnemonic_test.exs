defmodule Iconvex.Specs.RFC1345MnemonicTest do
  use ExUnit.Case, async: false

  alias Iconvex.Specs.RFC1345Mnemonic

  test "registers both RFC 1345 shorthand mnemonic charsets" do
    assert Enum.map(RFC1345Mnemonic.codecs(), & &1.canonical_name()) == ["MNEMONIC", "MNEM"]
  end

  test "encodes and decodes ampersand-introduced mnemonic text" do
    codec = Iconvex.Specs.Mnemonic
    assert codec.encode(String.to_charlist("Café & tea")) == {:ok, "Caf&e' && tea"}
    assert codec.decode("Caf&e' && tea") == {:ok, String.to_charlist("Café & tea")}
    assert codec.decode("&ZZ") == {:ok, String.to_charlist("&ZZ")}
  end

  test "MNEM uses and escapes the space-backspace intro sequence" do
    codec = Iconvex.Specs.Mnem
    intro = <<0x20, 0x08>>
    assert codec.encode([0xE9]) == {:ok, intro <> "e'"}
    assert codec.decode(intro <> "e'") == {:ok, [0xE9]}
    assert codec.encode([0x20, 0x08]) == {:ok, intro <> intro}
    assert codec.decode(intro <> intro) == {:ok, [0x20, 0x08]}
  end

  test "exhaustively decodes all 1,893 pinned RFC mnemonic assignments" do
    mappings = RFC1345Mnemonic.mappings()
    assert length(mappings) == 1_893

    assert RFC1345Mnemonic.source().sha256 ==
             "d1a4b6a3d6514f8ea96b74e49af40edae5c8edfcc1b1e7d9d7caebc9d622e3b0"

    for {mnemonic, codepoint} <- mappings, byte_size(mnemonic) >= 2 do
      escaped = encode_mnemonic(mnemonic)
      assert Iconvex.Specs.Mnemonic.decode("&" <> escaped) == {:ok, [codepoint]}
      assert Iconvex.Specs.Mnem.decode(<<0x20, 0x08>> <> escaped) == {:ok, [codepoint]}
    end

    for {_mnemonic, codepoint} <- mappings do
      for codec <- RFC1345Mnemonic.codecs() do
        assert {:ok, encoded} = codec.encode([codepoint])
        assert codec.decode(encoded) == {:ok, [codepoint]}
      end
    end
  end

  defp encode_mnemonic(mnemonic) when byte_size(mnemonic) <= 2, do: mnemonic

  defp encode_mnemonic(mnemonic),
    do: "_" <> :binary.replace(mnemonic, "_", "__", [:global]) <> "_"
end
