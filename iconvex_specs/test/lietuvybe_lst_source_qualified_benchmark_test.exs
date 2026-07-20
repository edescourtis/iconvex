defmodule Iconvex.Specs.LietuvybeLSTSourceQualifiedBenchmarkTest do
  use ExUnit.Case, async: false

  @moduletag timeout: 120_000

  @canonicals [
    "LIETUVYBE-52A97895-LST-1564-2000-STRICT-BLANKS",
    "LIETUVYBE-52A97895-LST-1590-2-2000-STRICT-BLANKS",
    "LIETUVYBE-52A97895-LST-1590-4-2000-STRICT-BLANKS"
  ]

  test "RED: source-bound quick benchmark covers all three codecs and hot paths" do
    root = Path.expand("..", __DIR__)
    benchmark = Path.join(root, "bench/lietuvybe_lst_source_qualified_bench.exs")
    source = File.read!(benchmark)

    assert source =~ "priv/sources/lietuvybe-lst-source-qualified"
    assert source =~ ":crypto.hash(:sha256"
    assert source =~ "@native_reference_ceiling 30.0"
    assert source =~ "@expected_mapping_rows 729"

    reference =
      source
      |> String.split("defp reference_decode", parts: 2)
      |> List.last()
      |> String.split("defp timed_median", parts: 2)
      |> List.first()

    refute reference =~ "codec."
    refute reference =~ "Iconvex.Specs.Lietuvybe"

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
        operation <- ["decode", "encode", "decode_to_utf8", "encode_from_utf8"] do
      assert output =~ "#{canonical} #{operation} native/reference",
             "missing benchmark row #{canonical} #{operation}\n\n#{output}"
    end

    assert output =~ "source-bound mapping coverage: 729/729 rows across 3/3 profiles"
    assert output =~ "round-trip and direct UTF-8 parity: 3/3 profiles"
    assert output =~ "all 12 native/reference 30x ceiling gates passed"
  end
end
