defmodule Iconvex.Specs.AlgorithmicExhaustiveTest do
  use ExUnit.Case, async: false

  @moduletag timeout: :infinity
  @corpus Path.expand("fixtures/all-unicode-scalars.utf32be", __DIR__)
  @corpus_sha256 "d037f6200ae8845906b4372a8b3fcd39730e3a61c4af0e354823010e6f93be54"
  @scalar_count 1_112_064

  test "every full-Unicode algorithmic codec round trips every Unicode scalar" do
    corpus = File.read!(@corpus)
    assert byte_size(corpus) == @scalar_count * 4
    assert sha256(corpus) == @corpus_sha256

    codepoints = for <<codepoint::unsigned-big-32 <- corpus>>, do: codepoint
    assert length(codepoints) == @scalar_count

    Enum.each(
      [
        Iconvex.Specs.BOCU1,
        Iconvex.Specs.Punycode,
        Iconvex.Specs.CESU8,
        Iconvex.Specs.IMAPUTF7,
        Iconvex.Specs.JavaModifiedUTF8,
        Iconvex.Specs.SCSU,
        Iconvex.Specs.UTFEBCDIC,
        Iconvex.Specs.UTF1,
        Iconvex.Specs.IconvexUTF16SignatureLEDefault,
        Iconvex.Specs.IconvexUTF32BESignature,
        Iconvex.Specs.IconvexUTF32LESignature
      ],
      fn codec ->
        assert {:ok, encoded} = codec.encode(codepoints)
        assert codec.decode(encoded) == {:ok, codepoints}
      end
    )
  end

  test "x-user-defined exhaustively inverts its complete 256-byte repertoire" do
    bytes = :binary.list_to_bin(Enum.to_list(0..255))
    assert {:ok, codepoints} = Iconvex.Specs.XUserDefined.decode(bytes)
    assert length(codepoints) == 256
    assert Iconvex.Specs.XUserDefined.encode(codepoints) == {:ok, bytes}
  end

  defp sha256(binary),
    do: binary |> then(&:crypto.hash(:sha256, &1)) |> Base.encode16(case: :lower)
end
