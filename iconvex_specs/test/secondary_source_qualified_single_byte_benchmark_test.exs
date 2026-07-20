defmodule Iconvex.Specs.SecondarySourceQualifiedSingleByteBenchmarkTest do
  use ExUnit.Case, async: false

  @benchmark Path.expand(
               "../bench/secondary_source_qualified_single_byte_bench.exs",
               __DIR__
             )

  test "RED: executable benchmark enforces source parity, 30x ceilings, and linear work" do
    source = File.read!(@benchmark)

    assert source =~ "@native_reference_ceiling 30.0"
    assert source =~ "@expected_mapping_rows 726"
    assert source =~ "reduction_scaling_gates"
    assert source =~ "reference_decode"
    assert source =~ "reference_encode"

    {output, status} =
      System.cmd(
        System.find_executable("mix"),
        ["run", "--no-compile", @benchmark, "--quick"],
        cd: Path.expand("..", __DIR__),
        stderr_to_stdout: true,
        env: [
          {"MIX_ENV", "test"},
          {"ICONVEX_PATH", "../iconvex"},
          {"ICONVEX_ARCHIVE_PATH", ".."}
        ]
      )

    assert status == 0, output
    assert output =~ "source-bound mapping coverage: 726/726 rows and 768/768 byte positions"
    assert output =~ "round-trip and direct UTF-8 parity: 3/3 profiles"
    assert output =~ "all 9 native/reference 30x ceiling gates passed"
    assert output =~ "all 3 reduction-scaling gates passed"
    assert output =~ "GNU comparator: unavailable for all three content-qualified profiles"
  end
end
