defmodule Iconvex.PackageSplitTest do
  use ExUnit.Case, async: true

  @fixtures Path.expand("fixtures/gnu-libiconv-1.19-encodings", __DIR__)
  @definition_files ~w(
    encodings.def encodings_extra.def encodings_aix.def encodings_dos.def
    encodings_osf1.def encodings_zos.def
  )

  test "core package contains exactly GNU default codecs" do
    core = canonical_names(["encodings.def"])
    union = canonical_names(@definition_files)
    extras = MapSet.difference(union, core)

    assert MapSet.size(core) == 112
    assert MapSet.size(extras) == 86
    assert MapSet.new(Iconvex.encodings()) == core

    for name <- extras do
      assert Iconvex.canonical_name(name) == :error
    end
  end

  test "core package does not ship extra codec tables" do
    refute File.exists?(Path.expand("../priv/tables/atarist.etf", __DIR__))
    refute File.exists?(Path.expand("../priv/tables/euc_jisx0213.etf", __DIR__))
    refute File.exists?(Path.expand("../priv/tables/ebcdic1047.etf", __DIR__))
  end

  defp canonical_names(files) do
    files
    |> Enum.flat_map(fn file ->
      source =
        @fixtures
        |> Path.join(file)
        |> File.read!()
        |> then(&Regex.replace(~r{/\*.*?\*/}s, &1, ""))

      Regex.scan(~r/DEFENCODING\(\(\s*(.*?)\),\s*[a-z0-9_]+\s*,/s, source,
        capture: :all_but_first
      )
      |> Enum.map(fn [names] ->
        names
        |> then(&Regex.scan(~r/"([^"]+)"/, &1, capture: :all_but_first))
        |> hd()
        |> hd()
      end)
    end)
    |> MapSet.new()
  end
end
