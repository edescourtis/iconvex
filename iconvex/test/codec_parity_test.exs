defmodule Iconvex.CodecParityTest do
  use ExUnit.Case, async: false

  alias Iconvex.Registry

  @root Path.expand("fixtures/gnu-libiconv-1.19-encodings", __DIR__)
  @fixed_files ~w(
    encodings.def encodings_extra.def encodings_aix.def encodings_dos.def
    encodings_osf1.def encodings_zos.def
  )
  @support_doc Path.expand("../SUPPORTED_ENCODINGS.md", __DIR__)
  @name_inventory Path.expand("../SUPPORTED_NAME_INVENTORY.csv", __DIR__)

  test "GNU 1.19 encoding-definition snapshots are byte-exact" do
    digest =
      @root
      |> Path.join("*")
      |> Path.wildcard()
      |> Enum.sort()
      |> Enum.map(fn path ->
        hash =
          path |> File.read!() |> then(&:crypto.hash(:sha256, &1)) |> Base.encode16(case: :lower)

        [hash, "  ./", Path.basename(path), "\n"]
      end)
      |> then(&:crypto.hash(:sha256, &1))
      |> Base.encode16(case: :lower)

    assert digest == "5eb5c6ed6dd8fe0ae6664a2bcf9c08f5353b6d692e72f2f3e7d75823c3256ad5"
  end

  test "Iconvex core canonical set exactly equals GNU default codecs" do
    {entries, _aliases} = parse(["encodings.def"])
    gnu = entries |> Map.values() |> Enum.sort()
    ours = Iconvex.encodings()

    assert length(gnu) == 112
    assert length(ours) == 112
    assert ours -- gnu == []
    assert gnu -- ours == []

    for canonical <- gnu do
      assert {:ok, %{kind: kind}} = Registry.resolve(canonical)
      assert kind in [:table, :unicode, :escape, :gb18030, :stateful]
    end
  end

  test "every GNU spelling targeting a default codec resolves in core" do
    {entries, _base_aliases} = parse(["encodings.def"])
    {_union_entries, union_aliases} = parse(@fixed_files)
    aliases = Map.filter(union_aliases, fn {_name, id} -> Map.has_key?(entries, id) end)

    assert map_size(aliases) == 416

    for {name, id} <- aliases do
      assert Iconvex.canonical_name(name) == {:ok, Map.fetch!(entries, id)}, name

      assert Iconvex.canonical_name(String.downcase(name, :ascii)) ==
               {:ok, Map.fetch!(entries, id)}
    end
  end

  test "generated core name inventory is an exact runtime snapshot" do
    Code.ensure_loaded!(Registry)
    assert function_exported?(Registry, :builtin_aliases, 0)

    expected =
      Registry.builtin_aliases()
      |> Map.new(fn {name, id} ->
        assert {:ok, entry} = Registry.builtin_resolve(id)
        {name, entry.canonical}
      end)

    actual =
      @name_inventory
      |> File.read!()
      |> String.split("\n", trim: true)
      |> tl()
      |> Map.new(fn line ->
        [name, canonical] = String.split(line, ",", parts: 2)
        {name, canonical}
      end)

    assert map_size(actual) == 441
    assert actual == expected
    assert actual["IBM-5054"] == "ISO-2022-JP-1"
    refute Map.has_key?(actual, "ISO-IR-180")
  end

  test "built default GNU iconv -l groups are a 112-codec subset, all resolved" do
    {base_entries, _aliases} = parse(["encodings.def"])
    expected = base_entries |> Map.values() |> MapSet.new()

    actual =
      @root
      |> Path.join("iconv-l-default.txt")
      |> File.stream!([], :line)
      |> Enum.map(fn line ->
        resolved =
          line
          |> String.split()
          |> Enum.map(&Iconvex.canonical_name/1)
          |> Enum.uniq()

        assert [{:ok, canonical}] = resolved
        canonical
      end)
      |> MapSet.new()

    assert MapSet.size(actual) == 112
    assert actual == expected
  end

  test "GNU locale and ABI adapters are explicitly distinguished from fixed codecs" do
    {local_entries, _aliases} = parse(["encodings_local.def"])

    assert local_entries |> Map.values() |> Enum.sort() == ["CHAR", "WCHAR_T"]
    assert Iconvex.canonical_name("CHAR") == :error
    assert Iconvex.canonical_name("WCHAR_T") == :error
  end

  test "published support matrix reports exact parity and both codec lists" do
    document = File.read!(@support_doc)

    for marker <- [
          "112 core + 86 extras",
          "112/112",
          "GNU-only fixed codecs: **0**",
          "Iconvex-only fixed codecs: **0**",
          "CHAR",
          "WCHAR_T",
          "IBM-16804",
          "UTF-8"
        ] do
      assert document =~ marker
    end
  end

  defp parse(files) do
    {entries, aliases} =
      Enum.reduce(files, {%{}, %{}}, fn filename, {entries, aliases} ->
        source =
          @root
          |> Path.join(filename)
          |> File.read!()
          |> then(&Regex.replace(~r{/\*.*?\*/}s, &1, ""))

        definitions =
          Regex.scan(~r/DEFENCODING\(\(\s*(.*?)\),\s*([a-z0-9_]+)\s*,/s, source,
            capture: :all_but_first
          )

        {entries, aliases} =
          Enum.reduce(definitions, {entries, aliases}, fn [names_source, id],
                                                          {entries, aliases} ->
            names =
              Regex.scan(~r/"([^"]+)"/, names_source, capture: :all_but_first)
              |> List.flatten()

            canonical = hd(names)
            aliases = Enum.reduce(names, aliases, &Map.put(&2, normalize(&1), id))
            {Map.put_new(entries, id, canonical), aliases}
          end)

        aliases =
          Regex.scan(~r/DEFALIAS\(\s*"([^"]+)"\s*,\s*([a-z0-9_]+)\s*\)/s, source,
            capture: :all_but_first
          )
          |> Enum.reduce(aliases, fn [name, id], acc -> Map.put(acc, normalize(name), id) end)

        {entries, aliases}
      end)

    aliases =
      Enum.reduce(entries, aliases, fn {id, canonical}, acc ->
        Map.put(acc, normalize(canonical), id)
      end)

    {entries, aliases}
  end

  defp normalize(name), do: String.upcase(name, :ascii)
end
