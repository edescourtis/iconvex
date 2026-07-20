defmodule Iconvex.Specs.DraftUTF5UTF6ReleaseContractTest do
  use ExUnit.Case, async: true

  @root Path.expand("..", __DIR__)
  @utf5_sha256 "12ae18367c110b5dcef9cc3f06b6ae40e60c8fde489fdd161f1bb98e3e5f2375"
  @utf6_sha256 "80033b5e41bc9f2fd01bddf99a300827b837f06ba93ef303bc54bc53df3755ca"
  @utf5_benchmark_sha256 "b17e0ab352d27ab93c56bb743a8846b4a866303f658a1827a405ddd603dbfc94"
  @utf6_benchmark_sha256 "0846d5a2b875f5eb30bd893a4fe0ad86f5b4ab2a0a51a07ec8df0a04dc8f4dd5"
  @utf5_runtime_sha256 "0bce145bb958b7b60baf4d921ae72cc1b67af1413555918580d2fa26412e6a45"
  @utf6_runtime_sha256 "82ac0b0e4f914bac3bc1e98447f6c9b86b3f0f09eaea9dd5fdcd6d3d1d536a45"

  test "RED: UTF-5 and UTF-6 sources, notices, and executable benchmarks are release-bound" do
    sources = File.read!(Path.join(@root, "SOURCES.md"))
    notice = File.read!(Path.join(@root, "NOTICE"))
    benchmarks = File.read!(Path.join(@root, "BENCHMARKS.md"))
    package = File.read!(Path.join(@root, "mix.exs"))

    for marker <- ["UTF-5 (`draft-jseng-utf5-01`)", @utf5_sha256] do
      assert sources =~ marker
      assert notice =~ marker
    end

    for marker <- ["UTF-6 (`draft-ietf-idn-utf6-00`)", @utf6_sha256] do
      assert sources =~ marker
      assert notice =~ marker
    end

    assert benchmarks =~ "<!-- utf5-benchmark:start -->"
    assert benchmarks =~ "<!-- utf5-benchmark:end -->"
    assert benchmarks =~ @utf5_benchmark_sha256
    assert benchmarks =~ @utf5_runtime_sha256

    assert String.replace(benchmarks, ~r/\s+/, " ") =~
             "3.178–77.492 MiB/s over eight paths. Native/reference latency was 0.342x–0.504x and reduction scaling was 1.931x–2.008x"

    assert benchmarks =~ "<!-- utf6-benchmark:start -->"
    assert benchmarks =~ "<!-- utf6-benchmark:end -->"
    assert benchmarks =~ @utf6_benchmark_sha256
    assert benchmarks =~ @utf6_runtime_sha256

    assert String.replace(benchmarks, ~r/\s+/, " ") =~
             "15.097–73.996 MiB/s over ten paths. Native/reference latency had a worst case of 1.151x and reduction scaling was 1.956x–2.006x"

    assert String.replace(benchmarks, ~r/\s+/, " ") =~ "all performance gates passed"

    assert package =~ "priv/sources/draft-jseng-utf5-01/*"
    assert package =~ "priv/sources/draft-ietf-idn-utf6-00/*"
  end
end
