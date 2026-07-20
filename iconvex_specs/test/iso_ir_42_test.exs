defmodule Iconvex.Specs.ISOIR42Test do
  use ExUnit.Case, async: false

  @ucm Path.expand("../priv/sources/icu-data-archive/ibm-955_P110-1997.ucm", __DIR__)
  @registration Path.expand("../priv/sources/iso-ir-42/042.pdf", __DIR__)

  test "registers JIS C 6226-1978 / ISO-IR-42 under its standard aliases" do
    for name <- [
          "ISO-IR-42",
          "ISOIR42",
          "ISO_42",
          "JIS-C6226-1978",
          "JIS_C6226-1978",
          "JISC6226-1978",
          "CSISO42JISC62261978"
        ] do
      assert {:ok, %{canonical: "ISO-IR-42"}} = Iconvex.Registry.resolve(name)
    end
  end

  test "pins the official registration, ICU mapping, and independent Pike audit" do
    assert sha256(File.read!(@registration)) ==
             "f3ef6fd4f2c126b3477e0763a713dcff14373fc7d3ee121c397b3283380ff2d3"

    assert sha256(File.read!(@ucm)) ==
             "06bd629e1967a5fb9bcb75b5cd964efb60036ca5b5d78bb0ce5b1301ffcfc7f7"

    metadata = Iconvex.Specs.ISOIR42.metadata()
    assert metadata.roundtrip_mappings == 6_879
    assert metadata.unicode_fallbacks == 12
    assert metadata.registration == 42
    assert metadata.pike_revision == "4bf9adbd874894d2484de1664969de43e4206492"

    assert metadata.pike_sha256 ==
             "28f856d12347859c9cb7f10361c813c4a4f3f7c9d33911544b50c7897748d860"
  end

  @tag timeout: 120_000
  test "exhausts all 8,836 positions in the registered 94 by 94 code table" do
    expected = roundtrip_mappings()

    assert map_size(expected) == 6_879

    for first <- 0x21..0x7E, second <- 0x21..0x7E do
      bytes = <<first, second>>

      case Map.fetch(expected, bytes) do
        {:ok, codepoint} ->
          assert Iconvex.convert(bytes, "ISO-IR-42", "UTF-8") ==
                   {:ok, <<codepoint::utf8>>}

        :error ->
          assert {:error, %Iconvex.Error{kind: :invalid_sequence}} =
                   Iconvex.convert(bytes, "ISO-IR-42", "UTF-8")
      end
    end
  end

  test "classifies every one-byte input as incomplete or malformed" do
    leads = MapSet.new(roundtrip_mappings(), fn {<<first, _second>>, _codepoint} -> first end)

    for byte <- 0..255 do
      result = Iconvex.convert(<<byte>>, "ISO-IR-42", "UTF-8")

      if MapSet.member?(leads, byte) do
        assert {:error, %Iconvex.Error{kind: :incomplete_sequence}} = result
      else
        assert {:error, %Iconvex.Error{kind: :invalid_sequence}} = result
      end
    end
  end

  test "round-trips the complete registered repertoire in one conversion" do
    mappings = roundtrip_mappings() |> Enum.sort()
    encoded = mappings |> Enum.map(&elem(&1, 0)) |> IO.iodata_to_binary()
    unicode = mappings |> Enum.map(&elem(&1, 1)) |> List.to_string()

    assert Iconvex.convert(encoded, "ISO-IR-42", "UTF-8") == {:ok, unicode}
    assert Iconvex.convert(unicode, "UTF-8", "ISO-IR-42") == {:ok, encoded}
  end

  test "does not silently enable ICU's twelve non-round-trip fallbacks" do
    roundtrip = roundtrip_mappings()

    for {bytes, codepoint} <- fallback_mappings() do
      assert Map.has_key?(roundtrip, bytes)
      assert roundtrip[bytes] != codepoint

      assert {:error, %Iconvex.Error{kind: :unrepresentable_character}} =
               Iconvex.convert(<<codepoint::utf8>>, "UTF-8", "ISO-IR-42")
    end
  end

  @tag timeout: 120_000
  test "checks canonical encoding over every Unicode scalar" do
    expected =
      roundtrip_mappings()
      |> Enum.sort()
      |> Enum.reduce(%{}, fn {bytes, codepoint}, result ->
        Map.put_new(result, codepoint, bytes)
      end)

    all_scalars =
      0..0x10FFFF
      |> Stream.reject(&(&1 in 0xD800..0xDFFF))
      |> Stream.chunk_every(4_096)
      |> Enum.map(&List.to_string/1)
      |> IO.iodata_to_binary()

    output =
      expected
      |> Enum.sort()
      |> Enum.map(fn {_codepoint, bytes} -> bytes end)
      |> IO.iodata_to_binary()

    assert Iconvex.convert(all_scalars, "UTF-8", "ISO-IR-42", unrepresentable: :discard) ==
             {:ok, output}
  end

  defp roundtrip_mappings, do: ucm_mappings("0") |> Map.new(fn {b, cp} -> {b, cp} end)
  defp fallback_mappings, do: ucm_mappings("1")

  defp ucm_mappings(precision) do
    @ucm
    |> File.stream!()
    |> Enum.flat_map(fn line ->
      case Regex.run(
             ~r/^<U([0-9A-F]+)> \\x([0-9A-F]{2})\\x([0-9A-F]{2}) \|(\d)/,
             line,
             capture: :all_but_first
           ) do
        [unicode, first, second, ^precision] ->
          [{Base.decode16!(first <> second), String.to_integer(unicode, 16)}]

        _ ->
          []
      end
    end)
  end

  defp sha256(binary), do: :crypto.hash(:sha256, binary) |> Base.encode16(case: :lower)
end
