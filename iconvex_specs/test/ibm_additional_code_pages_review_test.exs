Code.require_file(Path.expand("../tools/ibm_additional_code_pages_generator.exs", __DIR__))

defmodule Iconvex.Specs.IBMAdditionalCodePagesReviewTest do
  use ExUnit.Case, async: false

  alias Iconvex.Specs.IBMAdditionalCodePages.Generator

  @root Path.expand("..", __DIR__)
  @source_dir Path.join(@root, "priv/sources/ibm-additional-code-pages")
  @corpus Path.join(__DIR__, "fixtures/all-unicode-scalars.utf32be")
  @corpus_sha256 "d037f6200ae8845906b4372a8b3fcd39730e3a61c4af0e354823010e6f93be54"

  @profiles [
    {Iconvex.Specs.IBM310293P100CompositeVPUA, "cp310-293-p100-composite-vpua.map"},
    {Iconvex.Specs.IBMTNZCP310B1EAE3C, "cp310-tnz-07d60f4.map"},
    {Iconvex.Specs.IBM907CDRAP100VPUAComposite, "cp907-cdra-p100-vpua-composite.map"},
    {Iconvex.Specs.IBM1116850P100Composite, "cp1116-850-p100-composite.map"},
    {Iconvex.Specs.IBM1117437P100Composite, "cp1117-437-p100-composite.map"},
    {Iconvex.Specs.DECGreek81994, "cp1287-dec-1994.map"},
    {Iconvex.Specs.DECTurkish81994, "cp1288-dec-1994.map"}
  ]

  test "regenerates all seven mapping vectors byte-for-byte from pinned inputs" do
    generated = Generator.generate(@source_dir)

    assert generated |> Map.keys() |> Enum.sort() ==
             @profiles |> Enum.map(&elem(&1, 1)) |> Enum.sort()

    for {_codec, map_name} <- @profiles do
      expected = File.read!(Path.join(@source_dir, map_name))
      assert generated[map_name] == expected
      assert length(String.split(expected, "\n", trim: true)) == 256
    end

    assert generated["cp310-293-p100-composite-vpua.map"] =~ "41=U+F8F1\n"
    assert generated["cp310-tnz-07d60f4.map"] =~ "41=U+1D434\n"
    assert generated["cp907-cdra-p100-vpua-composite.map"] =~ "0E=U+266B\n"
    assert generated["cp1116-850-p100-composite.map"] =~ "0E=U+266C\n"
    assert generated["cp1117-437-p100-composite.map"] =~ "0E=U+266B\n"
  end

  test "runtime provenance is relative and package-durable" do
    package_files = Mix.Project.config() |> Keyword.fetch!(:package) |> Keyword.fetch!(:files)
    runtime_priv = :iconvex_specs |> :code.priv_dir() |> List.to_string()

    assert "priv/sources/ibm-additional-code-pages/*.map" in package_files
    assert "priv/sources/ibm-additional-code-pages/SOURCE_METADATA.md" in package_files
    refute "priv/sources" in package_files

    for {codec, map_name} <- @profiles do
      manifest = codec.source_manifest()

      assert Enum.all?(manifest, fn {relative_path, digest} ->
               Path.type(relative_path) == :relative and
                 Regex.match?(~r/^[0-9a-f]{64}$/, digest)
             end)

      assert manifest["ibm-additional-code-pages/#{map_name}"] == codec.mapping_sha256()

      assert Path.dirname(codec.source_map_path()) ==
               Path.join([runtime_priv, "sources", "ibm-additional-code-pages"])

      assert codec.source_metadata_path() ==
               Path.join([
                 runtime_priv,
                 "sources",
                 "ibm-additional-code-pages",
                 "SOURCE_METADATA.md"
               ])

      assert File.regular?(codec.source_map_path())
      assert File.regular?(codec.source_metadata_path())
    end
  end

  test "all 1,112,064 Unicode scalars produce exactly the canonical repertoire" do
    corpus_binary = File.read!(@corpus)
    assert sha256(corpus_binary) == @corpus_sha256
    assert byte_size(corpus_binary) == 1_112_064 * 4
    corpus = for <<codepoint::32-big <- corpus_binary>>, do: codepoint

    for {codec, map_name} <- @profiles do
      canonical = canonical_repertoire(Path.join(@source_dir, map_name))
      expected_codepoints = Enum.map(canonical, &elem(&1, 0))
      expected_bytes = for {_codepoint, byte} <- canonical, into: <<>>, do: <<byte>>

      assert codec.encode_discard(corpus) == {:ok, expected_bytes}
      assert codec.decode(expected_bytes) == {:ok, expected_codepoints}
    end
  end

  test "registers every qualified identity without claiming generic composite pages" do
    modules = MapSet.new(Iconvex.Specs.additional_codecs())

    for {codec, _map_name} <- @profiles do
      assert MapSet.member?(modules, codec)
      assert {:ok, %{codec: ^codec}} = Iconvex.Registry.resolve(codec.canonical_name())
    end

    for {alias_name, codec} <- [
          {"IBM-1287", Iconvex.Specs.DECGreek81994},
          {"CP1287", Iconvex.Specs.DECGreek81994},
          {"EL8DEC", Iconvex.Specs.DECGreek81994},
          {"IBM-1288", Iconvex.Specs.DECTurkish81994},
          {"CP1288", Iconvex.Specs.DECTurkish81994},
          {"TR8DEC", Iconvex.Specs.DECTurkish81994}
        ] do
      assert {:ok, %{codec: ^codec}} = Iconvex.Registry.resolve(alias_name)
    end

    composites =
      MapSet.new([
        Iconvex.Specs.IBM310293P100CompositeVPUA,
        Iconvex.Specs.IBMTNZCP310B1EAE3C,
        Iconvex.Specs.IBM907CDRAP100VPUAComposite,
        Iconvex.Specs.IBM1116850P100Composite,
        Iconvex.Specs.IBM1117437P100Composite
      ])

    for generic <- ~w(IBM-310 CP310 IBM-907 CP907 IBM-1116 CP1116 IBM-1117 CP1117) do
      case Iconvex.Registry.resolve(generic) do
        {:ok, %{codec: codec}} -> refute MapSet.member?(composites, codec)
        :error -> :ok
      end
    end
  end

  defp canonical_repertoire(path) do
    path
    |> File.stream!([], :line)
    |> Enum.reduce(%{}, fn line, canonical ->
      [byte_hex, rhs] = line |> String.trim() |> String.split("=", parts: 2)

      case rhs do
        "UNDEFINED" ->
          canonical

        "U+" <> codepoint_hex ->
          Map.put(
            canonical,
            String.to_integer(codepoint_hex, 16),
            String.to_integer(byte_hex, 16)
          )
      end
    end)
    |> Enum.sort_by(&elem(&1, 0))
  end

  defp sha256(binary), do: :crypto.hash(:sha256, binary) |> Base.encode16(case: :lower)
end
