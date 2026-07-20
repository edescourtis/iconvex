defmodule Iconvex.Specs.UnicodeSubstitutionRegressionTest do
  use ExUnit.Case, async: false

  @targets [
    {Iconvex.Specs.BOCU1, "BOCU-1", 0xD800},
    {Iconvex.Specs.SCSU, "SCSU", 0xD800},
    {Iconvex.Specs.WTF8, "WTF-8", 0x110000},
    {Iconvex.Specs.CESU8, "CESU-8", 0xD800},
    {Iconvex.Specs.UTF8Mac, "UTF-8-MAC", 0xD800},
    {Iconvex.Specs.UTFEBCDIC, "UTF-EBCDIC", 0xD800},
    {Iconvex.Specs.JavaModifiedUTF8, "JAVA-MODIFIED-UTF-8", 0xD800},
    {Iconvex.Specs.IMAPUTF7, "UTF-7-IMAP", 0xD800},
    {Iconvex.Specs.UTF8Sig, "UTF-8-SIG", 0xD800},
    {Iconvex.Specs.UTF1, "UTF-1", 0xD800},
    {Iconvex.Specs.ICUUTF16PlatformEndian, "UTF16_PlatformEndian", 0xD800},
    {Iconvex.Specs.ICUUTF16OppositeEndian, "UTF16_OppositeEndian", 0xD800},
    {Iconvex.Specs.ICUUTF32PlatformEndian, "UTF32_PlatformEndian", 0xD800},
    {Iconvex.Specs.ICUUTF32OppositeEndian, "UTF32_OppositeEndian", 0xD800},
    {Iconvex.Specs.ICUUTF16Version1, "UTF-16,version=1", 0xD800},
    {Iconvex.Specs.ICUUTF16Version2, "UTF-16,version=2", 0xD800}
  ]

  for {codec, target, unrepresentable} <- @targets do
    @tag codec: codec, target: target, unrepresentable: unrepresentable
    test "#{target} applies public Unicode substitution in one target encode", context do
      %{codec: codec, target: target, unrepresentable: unrepresentable} = context
      replacement = unicode_replacement(unrepresentable)
      transformed = ~c"A" ++ String.to_charlist(replacement) ++ ~c"B"
      source = <<?A::unsigned-big-32, unrepresentable::unsigned-big-32, ?B::unsigned-big-32>>

      assert {:ok, expected} = codec.encode(transformed)

      assert Iconvex.convert(source, "UCS-4BE", target, unicode_substitute: "<U+%04X>") ==
               {:ok, expected}
    end
  end

  defp unicode_replacement(codepoint) do
    hex = codepoint |> Integer.to_string(16) |> String.upcase() |> String.pad_leading(4, "0")
    "<U+#{hex}>"
  end
end
