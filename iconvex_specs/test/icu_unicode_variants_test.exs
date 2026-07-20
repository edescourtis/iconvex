defmodule Iconvex.Specs.ICUUnicodeVariantsTest do
  use ExUnit.Case, async: false

  alias Iconvex.Specs.ICUUnicodeVariants

  @source_directory Path.expand("../priv/sources/icu-78.3-unicode-variants", __DIR__)

  @corpus Path.expand("fixtures/all-unicode-scalars.utf32be", __DIR__)
  @encodings [
    "UTF16_PlatformEndian",
    "UTF16_OppositeEndian",
    "UTF32_PlatformEndian",
    "UTF32_OppositeEndian",
    "UTF-16,version=1",
    "UTF-16,version=2"
  ]

  test "registers every exact ICU converter name" do
    for name <- @encodings do
      assert {:ok, %{canonical: ^name}} = Iconvex.Registry.resolve(name)
    end
  end

  test "platform and opposite endian codecs are raw and BOM-less" do
    platform = :erlang.system_info(:endian)
    opposite = if platform == :big, do: :little, else: :big
    codepoints = [?A, 0x1F4A9]

    assert ICUUnicodeVariants.encode(:utf16_platform, codepoints) ==
             {:ok, encode16(codepoints, platform)}

    assert ICUUnicodeVariants.encode(:utf16_opposite, codepoints) ==
             {:ok, encode16(codepoints, opposite)}

    assert ICUUnicodeVariants.encode(:utf32_platform, codepoints) ==
             {:ok, encode32(codepoints, platform)}

    assert ICUUnicodeVariants.encode(:utf32_opposite, codepoints) ==
             {:ok, encode32(codepoints, opposite)}

    refute elem(ICUUnicodeVariants.encode(:utf16_platform, codepoints), 1) =~ <<0xFE, 0xFF>>
  end

  test "UTF-16 version 1 requires and consumes either BOM, then follows its endian" do
    assert ICUUnicodeVariants.decode(:utf16_v1, <<0xFE, 0xFF, 0x00, 0x41>>) == {:ok, [?A]}
    assert ICUUnicodeVariants.decode(:utf16_v1, <<0xFF, 0xFE, 0x41, 0x00>>) == {:ok, [?A]}

    assert ICUUnicodeVariants.decode(:utf16_v1, <<0x00, 0x41>>) ==
             {:error, :invalid_sequence, 0, <<0x00, 0x41>>}

    assert ICUUnicodeVariants.decode(:utf16_v1, <<0xFE>>) ==
             {:error, :incomplete_sequence, 0, <<0xFE>>}

    assert ICUUnicodeVariants.decode(:utf16_v1, <<>>) == {:ok, []}

    platform = :erlang.system_info(:endian)
    bom = if platform == :big, do: <<0xFE, 0xFF>>, else: <<0xFF, 0xFE>>
    assert ICUUnicodeVariants.encode(:utf16_v1, [?A]) == {:ok, bom <> encode16([?A], platform)}
    assert ICUUnicodeVariants.encode(:utf16_v1, []) == {:ok, <<>>}
  end

  test "UTF-16 version 2 writes BE and detects BOM while defaulting to BE" do
    assert ICUUnicodeVariants.encode(:utf16_v2, [?A, 0x1F4A9]) ==
             {:ok, <<0xFE, 0xFF>> <> encode16([?A, 0x1F4A9], :big)}

    assert ICUUnicodeVariants.decode(:utf16_v2, <<0x00, 0x41>>) == {:ok, [?A]}
    assert ICUUnicodeVariants.decode(:utf16_v2, <<0xFE, 0xFF, 0x00, 0x41>>) == {:ok, [?A]}
    assert ICUUnicodeVariants.decode(:utf16_v2, <<0xFF, 0xFE, 0x41, 0x00>>) == {:ok, [?A]}

    assert ICUUnicodeVariants.encode(:utf16_v2, [0xFFFE]) ==
             {:ok, <<0xFE, 0xFF, 0xFF, 0xFE>>}

    assert ICUUnicodeVariants.decode(:utf16_v2, <<0xFE, 0xFF, 0xFF, 0xFE>>) ==
             {:ok, [0xFFFE]}

    assert ICUUnicodeVariants.encode(:utf16_v2, []) == {:ok, <<>>}
  end

  @tag timeout: 180_000
  test "all six codecs round-trip every Unicode scalar value" do
    corpus = File.read!(@corpus)
    assert {:ok, utf8} = Iconvex.convert(corpus, "UTF-32BE", "UTF-8")

    for encoding <- @encodings do
      assert {:ok, encoded} = Iconvex.convert(utf8, "UTF-8", encoding)
      assert {:ok, ^utf8} = Iconvex.convert(encoded, encoding, "UTF-8")
    end
  end

  test "pins ICU 78.3 registry and implementation source" do
    assert ICUUnicodeVariants.revision() == "21d1eb0f306e1141c10931e914dfc038c06121da"
    assert byte_size(ICUUnicodeVariants.aggregate_sha256()) == 64

    for {filename, expected_sha} <- ICUUnicodeVariants.sources() do
      path = Path.join(@source_directory, filename)
      assert sha256(File.read!(path)) == expected_sha
    end
  end

  defp encode16(codepoints, endian) do
    Enum.map_join(codepoints, fn
      codepoint when codepoint <= 0xFFFF ->
        write16(codepoint, endian)

      codepoint ->
        value = codepoint - 0x10000

        write16(0xD800 + Bitwise.bsr(value, 10), endian) <>
          write16(0xDC00 + Bitwise.band(value, 0x3FF), endian)
    end)
  end

  defp encode32(codepoints, endian), do: Enum.map_join(codepoints, &write32(&1, endian))
  defp write16(value, :big), do: <<value::unsigned-big-16>>
  defp write16(value, :little), do: <<value::unsigned-little-16>>
  defp write32(value, :big), do: <<value::unsigned-big-32>>
  defp write32(value, :little), do: <<value::unsigned-little-32>>
  defp sha256(binary), do: :crypto.hash(:sha256, binary) |> Base.encode16(case: :lower)
end
