defmodule Iconvex.Specs.Unihan17KGB3RowCellBenchmarkTest do
  use ExUnit.Case, async: false

  @moduletag timeout: :infinity

  @mapping_sha256 "63dd2f9d88dc53b9c3603fe798b6f414c578fc22b68d840225a5d44b890d6baf"
  @runtime_sha256 "8269a3f227cee5220d15adfcea9847986717039a26a7e0d73966d7816d47bfa8"
  @benchmark_sha256 "a79dca2ea76657463d18981cb84d6f917e43d70f0de3ed219de1981b4932f71e"
  @operations ~w(
    direct_decode_to_utf8
    direct_encode_from_utf8
    composed_decode
    composed_encode
  )

  test "RED: benchmark pins its source and contains independent hard performance guards" do
    root = Path.expand("..", __DIR__)
    benchmark_path = Path.join(root, "bench/unihan17_kgb3_row_cell_benchmark.exs")
    runtime_path = Path.join(root, "lib/iconvex/specs/unihan_gb3_row_cell.ex")
    mapping_path = Path.join(root, "priv/sources/unihan-17.0.0-kgb3/row_cells.csv")
    benchmark = File.read!(benchmark_path)
    release_benchmarks = File.read!(Path.join(root, "BENCHMARKS.md"))
    notice = File.read!(Path.join(root, "NOTICE"))

    assert sha256(File.read!(mapping_path)) == @mapping_sha256
    assert sha256(File.read!(runtime_path)) == @runtime_sha256
    assert sha256(benchmark) == @benchmark_sha256
    assert benchmark =~ "priv/sources/unihan-17.0.0-kgb3/row_cells.csv"
    assert benchmark =~ @mapping_sha256
    assert benchmark =~ "defmodule Iconvex.Specs.Unihan17KGB3RowCellBenchmark.Reference"
    assert benchmark =~ "verify_source!"
    assert benchmark =~ "@relative_ceiling 30.0"
    assert benchmark =~ "@slowdown_ceiling 30.0"
    assert benchmark =~ "Float.ceil(recorded / @slowdown_ceiling, 2)"
    assert benchmark =~ "direct_decode_to_utf8: 4.525"
    assert benchmark =~ "direct_encode_from_utf8: 13.560"
    assert benchmark =~ "composed_decode: 3.044"
    assert benchmark =~ "composed_encode: 16.477"
    assert benchmark =~ "@reduction_bounds"
    assert benchmark =~ "--quick"
    refute benchmark =~ "UnihanGB3RowCell.Engine"

    assert release_benchmarks =~ @runtime_sha256
    assert release_benchmarks =~ @benchmark_sha256
    assert release_benchmarks =~ @mapping_sha256
    assert release_benchmarks =~ "3.044–19.194 MiB/s"
    assert release_benchmarks =~ "0.16 MiB/s"
    assert release_benchmarks =~ "0.55 MiB/s"
    assert notice =~ "`kGB3`"
    assert notice =~ "Unicode License V3"
  end

  test "RED: quick benchmark covers direct and composed paths against the independent reference" do
    {output, status} = run_benchmark(["--quick"])
    assert status == 0, output

    assert output =~ "schema\ticonvex-unihan17-kgb3-row-cell-benchmark\t1"
    assert output =~ "source\tUnicode-17.0.0-kGB3\t7236\t#{@mapping_sha256}"

    for operation <- @operations do
      assert output =~ "result\t#{operation}\t",
             "missing benchmark result: #{operation}\n\n#{output}"

      assert output =~ "gate\t#{operation}\treduction_scaling\t",
             "missing reduction gate: #{operation}\n\n#{output}"

      assert output =~ "gate\t#{operation}\tthroughput_floor\t",
             "missing throughput gate: #{operation}\n\n#{output}"

      assert output =~ "gate\t#{operation}\tnative_to_reference\t",
             "missing independent-reference gate: #{operation}\n\n#{output}"
    end

    assert output =~ "comparator\tgnu-libiconv-1.19\tunavailable"
    assert output =~ "no equivalent source-qualified kGB3 row/cell converter"
    assert output =~ "summary\t4/4 native paths passed"
    assert output =~ "all native/reference ratios <= 30.0x"
  end

  defp run_benchmark(arguments) do
    root = Path.expand("..", __DIR__)
    mix = System.find_executable("mix") || flunk("mix executable is unavailable")

    System.cmd(
      mix,
      ["run", "--no-compile", "bench/unihan17_kgb3_row_cell_benchmark.exs" | arguments],
      cd: root,
      env: [
        {"MIX_ENV", "test"},
        {"MIX_BUILD_PATH", Path.expand(Mix.Project.build_path(), root)},
        {"ICONVEX_PATH", Path.expand("../iconvex", root)},
        {"ICONVEX_ARCHIVE_PATH", Path.expand("..", root)}
      ],
      stderr_to_stdout: true
    )
  end

  defp sha256(contents), do: :crypto.hash(:sha256, contents) |> Base.encode16(case: :lower)
end
