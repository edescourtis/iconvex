defmodule Iconvex.ExhaustiveUnicodeDifferentialTest do
  use ExUnit.Case, async: false

  @corpus Path.expand("fixtures/all-unicode-codepoints.ucs4be", __DIR__)
  @report Path.expand("../EXHAUSTIVE_UNICODE_DIFFERENTIAL.md", __DIR__)
  @runner Path.expand("../tools/exhaustive_unicode_differential.exs", __DIR__)
  @corpus_sha256 "087f212baaa35562a226c5834e723620bb7d9f4103b76f9c7cbdaaff2d6cd67c"

  test "exhaustive differential artifacts cover every Unicode code point and every codec" do
    assert File.regular?(@runner)
    assert File.stat!(@corpus).size == 1_114_112 * 4

    corpus = File.read!(@corpus)

    corpus_digest = corpus |> then(&:crypto.hash(:sha256, &1)) |> Base.encode16(case: :lower)

    assert corpus_digest == @corpus_sha256

    {count, surrogate_count, last} =
      for <<codepoint::unsigned-big-32 <- corpus>>, reduce: {0, 0, -1} do
        {count, surrogate_count, previous} ->
          assert codepoint == previous + 1
          assert codepoint <= 0x10FFFF
          surrogate_count = surrogate_count + if(codepoint in 0xD800..0xDFFF, do: 1, else: 0)
          {count + 1, surrogate_count, codepoint}
      end

    assert count == 1_114_112
    assert surrogate_count == 2_048
    assert last == 0x10FFFF

    report = File.read!(@report)

    assert report =~ "Unicode code points: **1,114,112/1,114,112**"
    assert report =~ "Unicode scalar values: **1,112,064**"
    assert report =~ "Non-scalar surrogate code points: **2,048**"
    assert report =~ "Every Unicode code point from U+0000 through U+10FFFF"
    assert report =~ "UCS-4BE"
    assert report =~ "| Round-trip code points |"
    assert report =~ "Codecs passed: **112/112**"
    assert report =~ "Mismatches: **0**"
    assert report =~ "Corpus SHA-256: `#{corpus_digest}`"

    runner_digest = @runner |> File.read!() |> sha256()
    assert report =~ "Differential runner SHA-256: `#{runner_digest}`"

    root = Path.expand("..", __DIR__)

    runtime_digest =
      ["lib/**/*.ex", "priv/**/*.etf", "mix.exs"]
      |> Enum.flat_map(&Path.wildcard(Path.join(root, &1)))
      |> Enum.filter(&File.regular?/1)
      |> Enum.sort()
      |> Enum.map(fn path ->
        relative = Path.relative_to(path, root)
        [relative, <<0>>, path |> File.read!() |> sha256(), "\n"]
      end)
      |> sha256()

    assert report =~ "Runtime artifact SHA-256: `#{runtime_digest}`"

    codecs =
      Regex.scan(~r/^\| `([^`]+)` \| PASS \|/m, report, capture: :all_but_first)
      |> List.flatten()

    assert codecs == Iconvex.encodings()
  end

  defp sha256(iodata) do
    iodata
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end
end
