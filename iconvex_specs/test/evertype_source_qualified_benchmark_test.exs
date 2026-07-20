defmodule Iconvex.Specs.EvertypeSourceQualifiedBenchmarkTest do
  use ExUnit.Case, async: false

  @moduletag timeout: 120_000

  @canonicals [
    "EVERTYPE-2001-LATIN-8-EXTENDED",
    "EVERTYPE-2001-MAC-ARMENIAN",
    "EVERTYPE-2001-MAC-BARENTS-CYRILLIC",
    "EVERTYPE-2002-MAC-GEORGIAN",
    "EVERTYPE-2001-MAC-MALTESE-ESPERANTO",
    "EVERTYPE-2001-MAC-OGHAM",
    "EVERTYPE-2002-MAC-TURKIC-CYRILLIC"
  ]

  test "RED: benchmark is source-bound and covers every profile and hot path" do
    root = Path.expand("..", __DIR__)
    benchmark = Path.join(root, "bench/evertype_source_qualified_bench.exs")
    source = File.read!(benchmark)

    assert source =~ "priv/sources/evertype-source-qualified"
    assert source =~ ":crypto.hash(:sha256"
    assert source =~ "parse_mapping"
    assert source =~ "canonical_inverse"
    assert source =~ "@native_reference_ceiling 30.0"
    assert source =~ "@expected_mapping_rows 1_694"

    reference =
      source
      |> String.split("defp reference_decode", parts: 2)
      |> List.last()
      |> String.split("defp timed_median", parts: 2)
      |> List.first()

    refute reference =~ "codec."
    refute reference =~ "Iconvex.Specs.Evertype"

    mix = System.find_executable("mix") || flunk("mix executable is unavailable")

    env = [
      {"MIX_ENV", "test"},
      {"MIX_BUILD_PATH", Path.expand(Mix.Project.build_path(), root)},
      {"ICONVEX_PATH", Path.expand("../iconvex", root)},
      {"ICONVEX_ARCHIVE_PATH", Path.expand("..", root)}
    ]

    {output, status} =
      System.cmd(
        mix,
        ["run", "--no-compile", benchmark, "--quick"],
        cd: root,
        env: env,
        stderr_to_stdout: true
      )

    assert status == 0, output

    for canonical <- @canonicals,
        operation <- ["decode", "encode", "decode_to_utf8"] do
      assert output =~ "#{canonical} #{operation} native/reference",
             "missing benchmark row #{canonical} #{operation}\n\n#{output}"
    end

    assert output =~ "source-bound mapping coverage: 1694/1694 rows across 7/7 profiles"
    assert output =~ "round-trip and direct UTF-8 parity: 7/7 profiles"
    assert output =~ "all 21 native/reference 30x ceiling gates passed"
    assert output =~ "all 3 reduction-scaling gates passed"
  end
end
