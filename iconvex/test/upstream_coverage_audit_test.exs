defmodule Iconvex.UpstreamCoverageAuditTest do
  use ExUnit.Case, async: false

  alias Iconvex.UpstreamFixture

  @root UpstreamFixture.root()
  @makefile Path.join(@root, "Makefile.in")
  @coverage_doc Path.expand("../UPSTREAM_TEST_COVERAGE.md", __DIR__)

  test "all 267 upstream and one derived files belong to audited categories" do
    corpus = UpstreamFixture.corpus_files() |> basenames()
    mappings = UpstreamFixture.mapping_files() |> basenames()
    irreversible = paths("*.IRREVERSIBLE.TXT") |> basenames()
    snippets = paths("*-snippet") |> basenames()
    snippet_utf8 = paths("*-snippet.UTF-8") |> basenames()
    alternatives = paths("*-snippet.alt") |> basenames()

    transliteration =
      MapSet.new(~w(
        Quotes.ASCII Quotes.ISO-8859-1 Quotes.UTF-8
        Translit1.ASCII Translit1.ISO-8859-1 TranslitFail1.ISO-8859-1
      ))

    scripts = paths("check-*") |> basenames()
    c_sources = paths("*.c") |> basenames()
    build_files = MapSet.new(~w(Makefile Makefile.in))
    headers = MapSet.new(["qemu.h"])

    classified =
      [
        mappings,
        irreversible,
        snippets,
        snippet_utf8,
        alternatives,
        transliteration,
        scripts,
        c_sources,
        build_files,
        headers
      ]
      |> Enum.reduce(MapSet.new(), &MapSet.union/2)

    assert {MapSet.size(mappings), MapSet.size(irreversible)} == {164, 20}

    assert {MapSet.size(snippets), MapSet.size(snippet_utf8), MapSet.size(alternatives)} ==
             {27, 27, 1}

    assert {MapSet.size(transliteration), MapSet.size(scripts), MapSet.size(c_sources)} ==
             {6, 10, 10}

    assert classified == corpus
  end

  test "every active check-stateless invocation has an ExUnit charmap or generated-range case" do
    active = check_names("check-stateless") |> MapSet.new()

    covered =
      UpstreamFixture.mapping_files()
      |> Enum.map(&UpstreamFixture.encoding_for/1)
      |> MapSet.new()
      |> MapSet.put("UTF-8")

    assert MapSet.size(active) == 165
    assert active == covered
  end

  test "every active check-stateful invocation has an exact snippet round-trip case" do
    active = check_names("check-stateful") |> MapSet.new()

    covered =
      UpstreamFixture.snippet_names()
      |> Enum.map(&UpstreamFixture.snippet_encoding/1)
      |> MapSet.new()

    assert MapSet.size(active) == 27
    assert active == covered
  end

  test "every transliteration Makefile invocation maps to an exact fixture case" do
    makefile = File.read!(@makefile)

    transliteration =
      Regex.scan(
        ~r/^\t.*\/check-translit\s+\S+\s+(\S+)\s+(\S+)\s+(\S+)$/m,
        makefile,
        capture: :all_but_first
      )
      |> MapSet.new()

    failure =
      Regex.scan(
        ~r/^\t.*\/check-translitfailure\s+\S+\s+(\S+)\s+(\S+)\s+(\S+)$/m,
        makefile,
        capture: :all_but_first
      )
      |> MapSet.new()

    assert transliteration ==
             MapSet.new([
               ["Quotes", "UTF-8", "ISO-8859-1"],
               ["Quotes", "UTF-8", "ASCII"],
               ["Translit1", "ISO-8859-1", "ASCII"]
             ])

    assert failure == MapSet.new([["TranslitFail1", "ISO-8859-1", "ASCII"]])
  end

  test "all standalone shell and C checks are classified" do
    makefile = File.read!(@makefile)

    shell_checks =
      Regex.scan(
        ~r/^\t.*\/(check-(?:subst|ebcdic|tag))\b/m,
        makefile,
        capture: :all_but_first
      )
      |> List.flatten()
      |> MapSet.new()

    executables =
      Regex.scan(~r/^\t\.\/(test-[a-z-]+)$/m, makefile, capture: :all_but_first)
      |> List.flatten()
      |> MapSet.new()

    assert shell_checks == MapSet.new(~w(check-subst check-ebcdic check-tag))

    assert executables ==
             MapSet.new(~w(test-shiftseq test-to-wchar test-bom-state test-discard))
  end

  test "published traceability document contains counts, digest, and platform disposition" do
    document = File.read!(@coverage_doc)

    for marker <- [
          "267/267 upstream files",
          "268 audited files total",
          "165/165",
          "27/27",
          "U+10000..U+10FFFF",
          "b328fa4374b3b76df8acc47009a2b39b5ff5aaa1d7430cb12d9ae89a20202225",
          "dd437384d8e116abb838757ec1d7809d17a5fae8b3fe48e08b3d6f31910ff09b",
          "546c5b74a57687415f6bc67548dc1a190e9be54417b4df530addf7f9b96b095d",
          "Core 623 tests plus Extras 134 tests",
          "check-tag",
          "Not applicable"
        ] do
      assert document =~ marker
    end
  end

  test "release prose distinguishes archive-origin fixtures from configured output" do
    for {relative, marker} <- [
          {"README.md", "267 byte-exact upstream files plus one derived configured `Makefile`"},
          {"NOTICE", "267-file byte-exact upstream mirror plus one derived configured Makefile"},
          {"CHANGELOG.md",
           "267 GNU libiconv 1.19 test files plus one derived configured Makefile"}
        ] do
      document = File.read!(Path.expand("../#{relative}", __DIR__))
      assert document =~ marker
      refute document =~ "268-file mirror"
      refute document =~ "all 268 files from GNU libiconv"
      refute document =~ "all 268 GNU libiconv"
    end
  end

  defp check_names(check) do
    regex = Regex.compile!("^\\t.*\\/#{check}\\s+\\S+\\s+([^\\s&]+)", "m")

    @makefile
    |> File.read!()
    |> then(&Regex.scan(regex, &1, capture: :all_but_first))
    |> List.flatten()
  end

  defp paths(pattern), do: @root |> Path.join(pattern) |> Path.wildcard()
  defp basenames(paths), do: paths |> Enum.map(&Path.basename/1) |> MapSet.new()
end
