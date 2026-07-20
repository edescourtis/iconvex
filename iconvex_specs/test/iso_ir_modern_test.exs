defmodule Iconvex.Specs.ISOIRModernTest do
  use ExUnit.Case, async: false

  @source_directory Path.expand("../priv/sources/iso-ir-modern", __DIR__)
  @expected [
    "ISO-IR-164",
    "ISO-IR-167",
    "ISO-IR-182",
    "ISO-IR-200",
    "ISO-IR-201",
    "ISO-IR-204",
    "ISO-IR-205",
    "ISO-IR-206",
    "ISO-IR-207",
    "ISO-IR-208",
    "ISO-IR-232",
    "ISO-IR-234"
  ]

  setup_all do
    Application.ensure_all_started(:iconvex_specs)
    :ok
  end

  test "all selected official ISO-IR registrations are first-class external codecs" do
    assert Enum.all?(@expected, &(&1 in Iconvex.Specs.encodings()))

    for name <- @expected do
      assert {:ok, %{canonical: ^name}} = Iconvex.Registry.resolve(name)
    end
  end

  test "official registration-sheet spot vectors cover every added repertoire" do
    assert_convert("ISO-IR-164", <<0xE0, 0xEF, 0xFA>>, [0x05D0, 0x05DF, 0x05EA])

    assert_convert("ISO-IR-167", <<0xAC, 0xC0, 0xC1, 0xDA, 0xF2, 0xFF>>, [
      0x060C,
      0x00E0,
      0x0621,
      0x063A,
      0x0652,
      0x00FC
    ])

    assert_convert("ISO-IR-182", <<0xA8, 0xBD, 0xFE>>, [0x1E80, 0x1E84, 0x0177])
    assert_convert("ISO-IR-200", <<0xA1, 0xF1>>, [0x0401, 0x0451])

    assert_convert("ISO-IR-200", <<0xA4, 0xA9, 0xAE, 0xF4, 0xF9, 0xFE, 0xFF>>, [
      0x04EC,
      0x052E,
      0x048E,
      0x04ED,
      0x052F,
      0x048F,
      0x02EE
    ])

    assert_convert("ISO-IR-201", <<0xA2, 0xF2>>, [0x04D0, 0x04D1])
    assert_convert("ISO-IR-204", <<0xA4>>, [0x20AC])
    assert_convert("ISO-IR-205", <<0xA4>>, [0x20AC])
    assert_convert("ISO-IR-206", <<0xA4>>, [0x20AC])
    assert_convert("ISO-IR-207", <<0x40, 0x5B, 0x60, 0x7B>>, [0x00D3, 0x00C9, 0x00F3, 0x00E9])
    assert_convert("ISO-IR-208", <<0xE0, 0xFC>>, [0x1680, 0x169C])
    assert_convert("ISO-IR-232", <<0xB3, 0xD3>>, [0x00C7, 0x00E7])
    assert_convert("ISO-IR-234", <<0xD9, 0xE0, 0xFE>>, [0x20AC, 0x05D0, 0x200F])
  end

  test "every source mapping decodes and its canonical encoder round-trips" do
    for entry <- Iconvex.Specs.ISOIRModern.encodings(), {byte, codepoint} <- entry.mappings do
      codec = Enum.find(Iconvex.Specs.ISOIRModern.codecs(), &(&1.canonical_name() == entry.name))
      context = inspect({entry.name, byte, codepoint})
      assert codec.decode(<<byte>>) == {:ok, [codepoint]}, context

      if entry.canonical_encode[codepoint] == byte do
        assert codec.encode([codepoint]) == {:ok, <<byte>>}, context
      end
    end
  end

  test "each complete registration has its declared graphic repertoire cardinality" do
    entry = Enum.find(Iconvex.Specs.ISOIRModern.encodings(), &(&1.name == "ISO-IR-167"))
    assert entry.decode_mappings - 160 == 82
  end

  test "pinned PDFs and generated mapping tables retain their audited digests" do
    assert Iconvex.Specs.ISOIRModern.aggregate_sha256() =~ ~r/\A[0-9a-f]{64}\z/

    for entry <- Iconvex.Specs.ISOIRModern.encodings() do
      path = Path.join(@source_directory, entry.source_file)
      assert File.exists?(path)
      digest = :crypto.hash(:sha256, File.read!(path)) |> Base.encode16(case: :lower)
      assert digest == entry.sha256
    end

    for source <- Iconvex.Specs.ISOIRModern.auxiliary_sources() do
      path = Path.join(@source_directory, source.file)
      digest = :crypto.hash(:sha256, File.read!(path)) |> Base.encode16(case: :lower)
      assert digest == source.sha256
    end
  end

  test "UTF-1 exposes the exact IANA preferred name" do
    assert "ISO-10646-UTF-1" in Iconvex.Specs.UTF1.aliases()
    assert {:ok, %{canonical: "UTF-1"}} = Iconvex.Registry.resolve("ISO-10646-UTF-1")
  end

  test "the RFC 1345 invariant repertoire exposes its ISO registration" do
    assert {:ok, %{canonical: "INVARIANT"}} = Iconvex.Registry.resolve("ISO-IR-170")
  end

  defp assert_convert(name, encoded, codepoints) do
    utf8 = List.to_string(codepoints)
    assert Iconvex.convert(encoded, name, "UTF-8") == {:ok, utf8}
    assert Iconvex.convert(utf8, "UTF-8", name) == {:ok, encoded}
  end
end
