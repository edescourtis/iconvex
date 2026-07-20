defmodule Iconvex.ReleaseMetadataTest do
  use ExUnit.Case, async: true

  @source_url "https://github.com/edescourtis/iconvex"

  @readme Path.expand("../README.md", __DIR__)
  @deep_dive_remediation Path.expand("../DEEP_DIVE_REMEDIATION.md", __DIR__)
  @upstream_test_coverage Path.expand("../UPSTREAM_TEST_COVERAGE.md", __DIR__)
  @coverage_runtime_patterns ["lib/**/*.ex", "priv/**/*.etf", "mix.exs"]
  @coverage_test_patterns ["test/**/*"]

  @registry_document_contracts [
    {Path.expand("../README.md", __DIR__), "their 2,093 canonical names"},
    {Path.expand("../EXTENDING.md", __DIR__), "2,093 canonical-name registry"},
    {Path.expand("../CHANGELOG.md", __DIR__), "with 2,093 unique canonical names"}
  ]

  @documentation_mirrors [
    {Path.expand("../README.md", __DIR__), Path.expand("../doc/readme.md", __DIR__)},
    {Path.expand("../EXTENDING.md", __DIR__), Path.expand("../doc/extending.md", __DIR__)},
    {Path.expand("../CHANGELOG.md", __DIR__), Path.expand("../doc/changelog.md", __DIR__)},
    {Path.expand("../TDD_LOG.md", __DIR__), Path.expand("../doc/tdd_log.md", __DIR__)},
    {Path.expand("../BENCHMARKS.md", __DIR__), Path.expand("../doc/benchmarks.md", __DIR__)},
    {Path.expand("../EXHAUSTIVE_UNICODE_DIFFERENTIAL.md", __DIR__),
     Path.expand("../doc/exhaustive_unicode_differential.md", __DIR__)},
    {@deep_dive_remediation, Path.expand("../doc/deep_dive_remediation.md", __DIR__)},
    {@upstream_test_coverage, Path.expand("../doc/upstream_test_coverage.md", __DIR__)}
  ]

  test "RED: release metadata binds source links to the public tagged monorepo" do
    source_url = Iconvex.MixProject.project()[:source_url]
    docs = Iconvex.MixProject.project()[:docs]
    readme = File.read!(@readme)

    assert source_url == @source_url
    assert docs[:source_ref] == "v0.1.0"

    assert docs[:source_url_pattern] ==
             "#{@source_url}/blob/v0.1.0/iconvex/%{path}#L%{line}"

    assert readme =~ @source_url
    assert readme =~ "matching `v0.1.0` tag"
  end

  test "RED: full-materialization APIs require an application input limit" do
    readme = File.read!(@readme)

    assert readme =~ "must enforce an input-size limit"
    assert readme =~ "Iconvex deliberately does not choose a universal cap"
  end

  test "RED: current registry cardinality is exact in release documents" do
    for {path, expected} <- @registry_document_contracts do
      assert File.read!(path) =~ expected, "#{path} does not contain #{inspect(expected)}"
    end

    if documentation_mirror_verification?() do
      for {source, mirror} <- @documentation_mirrors do
        assert File.read!(mirror) == File.read!(source),
               "#{mirror} is stale relative to #{source}"
      end
    end

    deep_dive = File.read!(@deep_dive_remediation)
    normalized_deep_dive = String.replace(deep_dive, ~r/\s+/, " ")
    root = Path.expand("..", __DIR__)
    runtime_digest = evidence_digest(root, @coverage_runtime_patterns)
    test_digest = evidence_digest(root, @coverage_test_patterns)

    assert normalized_deep_dive =~
             "current clean Core full coverage run on OTP 28 is 623 tests, zero failures, and 93.30% total line coverage"

    assert normalized_deep_dive =~
             "latest independent Dell OTP 27 coverage measurement predates Cycles 141/142 and passed 620 tests with zero failures and 91.53% total line coverage"

    assert deep_dive =~ "Coverage runtime artifact SHA-256: `#{runtime_digest}`"
    assert deep_dive =~ "Coverage test-suite SHA-256: `#{test_digest}`"

    assert normalized_deep_dive =~ "re-read in full again on 2026-07-19"

    for marker <- [
          "OTP 28: Stream 95.36%",
          "Unicode 96.90%",
          "UTF-7 94.49%",
          "Escape 96.18%",
          "Tables 94.77%",
          "ISO-2022-JP 96.34%",
          "Stateful 98.92%",
          "TableCodec 92.65%",
          "ISO-2022-CN 99.49%",
          "OTP 27: Stream 93.72%",
          "Tables 94.77%",
          "ISO-2022-JP 91.55%",
          "Stateful 91.08%",
          "TableCodec 90.63%",
          "ISO-2022-CN 90.40%",
          "current total line coverage is 93.30% on OTP 28; the historical OTP 27 measurement was 91.53%"
        ] do
      assert normalized_deep_dive =~ marker
    end

    assert normalized_deep_dive =~ "1,114,112 code points"
    assert normalized_deep_dive =~ "112/112 core codecs"

    for marker <- [
          "Core provides 112 codecs",
          "Extras provides 86",
          "Telecom provides 54",
          "Specs provides 1,841 runtime codecs and 1,843 catalog identities",
          "1,050 archive codecs are included in the Specs runtime count",
          "combined registry therefore exposes 2,093 unique canonical names",
          "`new/3`, `feed/2`, and `finish/1` form a buffered compatibility transaction",
          "`stream/4` is the genuinely incremental API",
          "`stateful_callback_recovery_test.exs`",
          "supplied review recorded 62.9 MiB",
          "documentary evidence rather than a newly reproduced measurement",
          "`source_url` is bound to the public `edescourtis/iconvex` monorepo"
        ] do
      assert normalized_deep_dive =~ marker
    end
  end

  test "normal clean-checkout tests do not require ignored generated documentation" do
    assert documentation_mirror_verification?() ==
             (System.get_env("ICONVEX_VERIFY_DOC_MIRRORS") == "1")
  end

  test "RED: registry durability documents its synchronous persistent-term cost" do
    for path <- [Path.expand("../README.md", __DIR__), Path.expand("../EXTENDING.md", __DIR__)] do
      document = path |> File.read!() |> String.downcase() |> String.replace(~r/\s+/, " ")

      assert document =~ "strict per-commit durability", path
      assert document =~ "synchronous recovery snapshot", path
      assert document =~ "vm-wide garbage collection", path
      assert document =~ "register_set", path
    end
  end

  test "RED: Hex artifact excludes the GPL-only upstream test license" do
    package_files = Iconvex.MixProject.project()[:package][:files]

    refute "LICENSE.GPL-3.0" in package_files
    assert File.exists?(Path.expand("../LICENSE.GPL-3.0", __DIR__))
    assert File.exists?(Path.expand("fixtures/gnu-libiconv-1.19/uniq-u.c", __DIR__))

    notice = File.read!(Path.expand("../NOTICE", __DIR__))
    assert notice =~ "repository-only"
    assert notice =~ "excluded from the Hex artifact"
  end

  test "RED: README distinguishes current packages from the planned Specs split" do
    readme = File.read!(@readme)

    assert readme =~
             "1,841 byte-pipeline codecs: 1,050 archive codecs and 791 non-archive codecs"

    assert readme =~ "1,843 catalogued Specs codec identities"
    assert readme =~ "four property-token mapping APIs"
    assert readme =~ "must not be published"
    assert readme =~ "The seven replacement packages do not exist yet"

    for package <- ~w(
      iconvex_unicode
      iconvex_standards
      iconvex_bibliographic
      iconvex_retro
      iconvex_platforms
      iconvex_icu
      iconvex_icu_archive
    ) do
      assert readme =~ "`#{package}`"
    end

    assert readme =~
             "PETSCII currently comes from the local `iconvex_specs` development workspace"

    assert readme =~ "will move to `iconvex_retro`"

    assert readme =~ "1,050 archive codecs and 791 non-archive codecs"
    assert readme =~ "integration harness is GREEN in checkout mode"
    assert readme =~ ~r/plain documented\s+command resolves all seven sibling packages/
    assert readme =~ "explicit 300-second per-test bound"

    {petscii_notice, _} =
      :binary.match(
        readme,
        "PETSCII currently comes from the local `iconvex_specs` development workspace"
      )

    {petscii_example, _} = :binary.match(readme, "Iconvex.convert(petscii")
    assert petscii_notice < petscii_example

    assert length(Regex.scan(~r/\|> Enum\.into\(""\)/, readme)) == 1
  end

  defp documentation_mirror_verification? do
    System.get_env("ICONVEX_VERIFY_DOC_MIRRORS") == "1"
  end

  defp evidence_digest(root, patterns) do
    patterns
    |> Enum.flat_map(&Path.wildcard(Path.join(root, &1)))
    |> Enum.filter(&File.regular?/1)
    |> Enum.sort()
    |> Enum.map(fn path ->
      relative = Path.relative_to(path, root)
      [relative, <<0>>, path |> File.read!() |> sha256(), "\n"]
    end)
    |> sha256()
  end

  defp sha256(iodata) do
    iodata
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end
end
