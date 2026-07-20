defmodule Iconvex.Specs.IANAPCLSymbolSetsTest do
  use ExUnit.Case, async: false

  @source Path.expand("../priv/sources/iana-pcl-symbol-sets/mappings.txt", __DIR__)
  @manifest Path.expand("../priv/iana_pcl_symbol_sets_manifest.etf", __DIR__)

  @specs [
    {"HP-DeskTop", "7J", ["csHPDesktop"]},
    {"HP-Legal", "1U", ["csHPLegal"]},
    {"HP-Math8", "8M", ["csHPMath8"]},
    {"HP-Pi-font", "15U", ["csHPPiFont"]},
    {"ISO-8859-1-Windows-3.0-Latin-1", "9U", ["csWindows30Latin1"]},
    {"ISO-8859-1-Windows-3.1-Latin-1", "19U", ["csWindows31Latin1"]},
    {"ISO-8859-2-Windows-Latin-2", "9E", ["csWindows31Latin2"]},
    {"ISO-8859-9-Windows-Latin-5", "5T", ["csWindows31Latin5"]},
    {"Microsoft-Publishing", "6J", ["csMicrosoftPublishing"]},
    {"PC8-Danish-Norwegian", "11U", ["csPC8DanishNorwegian"]},
    {"PC8-Turkish", "9T", ["csPC8Turkish"]},
    {"Ventura-International", "13J", ["csVenturaInternational"]},
    {"Ventura-Math", "6M", ["csVenturaMath"]},
    {"Ventura-US", "14J", ["csVenturaUS"]}
  ]

  test "registers every official IANA name and alias" do
    for {canonical, _symbol_set, aliases} <- @specs,
        name <- [canonical | aliases] do
      assert {:ok, %{canonical: ^canonical}} = Iconvex.Registry.resolve(name)
    end
  end

  test "pins the exact public GhostPDL PCL mapping source" do
    manifest = @manifest |> File.read!() |> :erlang.binary_to_term()

    assert manifest.source_commit == "409356a1ad15aeca1280bb91aed58564c5524540"

    assert manifest.source_sha256 ==
             "80f85c019f6e7de90c7e2fd804cdb0b2e74a016b4ec142e193c76f24698bb6ec"

    assert manifest.normalized_sha256 == sha256(File.read!(@source))
    assert length(manifest.encodings) == 14
  end

  test "decodes all 3,584 possible single-byte inputs exactly as the PCL tables" do
    source = File.read!(@source)

    for {canonical, symbol_set, _aliases} <- @specs do
      mapping = parse_mapping(source, symbol_set)
      assert length(mapping) == 256

      for {codepoint, byte} <- Enum.with_index(mapping) do
        expected =
          if codepoint == 0xFFFF,
            do: {:error, :invalid_sequence},
            else: {:ok, <<codepoint::utf8>>}

        assert normalized(Iconvex.convert(<<byte>>, canonical, "UTF-8")) == expected
      end
    end
  end

  test "encodes every representable character using the first registered byte" do
    source = File.read!(@source)

    for {canonical, symbol_set, _aliases} <- @specs do
      encode = expected_encode(source, symbol_set)

      for {codepoint, byte} <- encode do
        assert Iconvex.convert(<<codepoint::utf8>>, "UTF-8", canonical) == {:ok, <<byte>>}
      end
    end
  end

  @tag timeout: 120_000
  test "checks discard encoding over every Unicode scalar for all 14 codecs" do
    source = File.read!(@source)

    all_scalars =
      0..0x10FFFF
      |> Stream.reject(&(&1 in 0xD800..0xDFFF))
      |> Stream.chunk_every(4_096)
      |> Enum.map(&List.to_string/1)
      |> IO.iodata_to_binary()

    for {canonical, symbol_set, _aliases} <- @specs do
      expected =
        source
        |> expected_encode(symbol_set)
        |> Enum.sort()
        |> Enum.map(fn {_codepoint, byte} -> byte end)
        |> :binary.list_to_bin()

      assert Iconvex.convert(all_scalars, "UTF-8", canonical, unrepresentable: :discard) ==
               {:ok, expected}
    end
  end

  defp parse_mapping(source, symbol_set) do
    escaped = Regex.escape(symbol_set)

    [body] =
      Regex.run(
        ~r/^\[#{escaped}\]\s*\n(.*?)(?=^\[|\z)/ms,
        source,
        capture: :all_but_first
      )

    body
    |> String.split("\n", trim: true)
    |> Enum.reject(&String.starts_with?(&1, "#"))
    |> Enum.map(fn row ->
      [_byte, value] = String.split(row, "\t")
      if value == "-", do: 0xFFFF, else: String.to_integer(value, 16)
    end)
  end

  defp expected_encode(source, symbol_set) do
    source
    |> parse_mapping(symbol_set)
    |> Enum.with_index()
    |> Enum.reject(fn {codepoint, _byte} -> codepoint == 0xFFFF end)
    |> Enum.reduce(%{}, fn {codepoint, byte}, result ->
      Map.put_new(result, codepoint, byte)
    end)
  end

  defp normalized({:ok, output}), do: {:ok, output}
  defp normalized({:error, %{kind: kind}}), do: {:error, kind}

  defp sha256(binary), do: :crypto.hash(:sha256, binary) |> Base.encode16(case: :lower)
end
