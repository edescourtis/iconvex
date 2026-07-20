defmodule Iconvex.Specs.CustomNativeSubstitutionTest do
  use ExUnit.Case, async: true

  @stateful_finite [
    Iconvex.Specs.ICUJIS7,
    Iconvex.Specs.ICUJIS8,
    Iconvex.Specs.IBM5052,
    Iconvex.Specs.IBM5053,
    Iconvex.Specs.IBM958,
    Iconvex.Specs.IBM5055,
    Iconvex.Specs.IBM965,
    Iconvex.Specs.IBM17354,
    Iconvex.Specs.IBM934,
    Iconvex.Specs.IBM938,
    Iconvex.Specs.KOI7Switched,
    Iconvex.Specs.MARC8
  ]

  @unicode_fallback [
    Iconvex.Specs.ICULMBCS1,
    Iconvex.Specs.ICULMBCS2,
    Iconvex.Specs.ICULMBCS3,
    Iconvex.Specs.ICULMBCS4,
    Iconvex.Specs.ICULMBCS5,
    Iconvex.Specs.ICULMBCS6,
    Iconvex.Specs.ICULMBCS8,
    Iconvex.Specs.ICULMBCS11,
    Iconvex.Specs.ICULMBCS16,
    Iconvex.Specs.ICULMBCS17,
    Iconvex.Specs.ICULMBCS18,
    Iconvex.Specs.ICULMBCS19,
    Iconvex.Specs.ICUCompoundText
  ]

  test "custom codecs expose a native substitution callback" do
    modules = @stateful_finite ++ @unicode_fallback ++ Iconvex.Specs.ISCII.Codecs.modules()

    assert Enum.all?(modules, &function_exported?(&1, :encode_substitute, 2))
  end

  test "finite custom codecs substitute repeated failures without changing encoder state" do
    replacement = ~c"<U+1F600>"
    replacer = fn 0x1F600 -> replacement end

    input = List.duplicate([?A, 0x1F600, ?B], 32) |> List.flatten()

    for codec <- @stateful_finite ++ Iconvex.Specs.ISCII.Codecs.modules() do
      expected =
        input
        |> Enum.flat_map(fn
          0x1F600 -> replacement
          codepoint -> [codepoint]
        end)
        |> then(&codec.encode/1)

      assert codec.encode_substitute(input, replacer) == expected,
             "native substitution diverged for #{inspect(codec)}"
    end
  end

  test "custom Unicode fallback codecs substitute invalid code points" do
    replacement = ~c"<U+110000>"
    replacer = fn 0x110000 -> replacement end
    input = [?A, 0x110000, ?B]
    expected_input = [?A] ++ replacement ++ [?B]

    for codec <- @unicode_fallback do
      assert codec.encode_substitute(input, replacer) == codec.encode(expected_input),
             "native substitution diverged for #{inspect(codec)}"
    end
  end
end
