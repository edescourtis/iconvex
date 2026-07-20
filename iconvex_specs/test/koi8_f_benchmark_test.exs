defmodule Iconvex.Specs.KOI8FBenchmarkTest do
  use ExUnit.Case, async: false

  @moduletag timeout: :infinity

  @operations ~w(decode_to_utf8 encode_from_utf8)
  @throughput_floors %{"decode_to_utf8" => 0.5, "encode_from_utf8" => 0.3}
  @relative_ceilings %{"decode_to_utf8" => 1.25, "encode_from_utf8" => 1.25}
  @benchmark_source_files [
    "bench/koi8_f_bench.exs",
    "lib/iconvex/specs/kermit_versioned_single_byte.ex",
    "lib/iconvex/specs/koi8_f.ex"
  ]

  test "RED: executable benchmark emits gated machine-readable KOI8-F evidence" do
    root = Path.expand("..", __DIR__)
    mix = System.find_executable("mix") || flunk("mix executable is unavailable")

    {output, status} =
      System.cmd(
        mix,
        ["run", "--no-compile", "bench/koi8_f_bench.exs", "--quick"],
        cd: root,
        env: benchmark_env(root),
        stderr_to_stdout: true
      )

    assert status == 0, output
    assert output =~ "schema\ticonvex-koi8-f-benchmark\t1"

    assert output =~
             "timing\tpaired-alternating\t5\tmedian-of-pair-ratios"

    rows = result_rows(output)
    assert Map.keys(rows) |> Enum.sort() == Enum.sort(@operations)

    for operation <- @operations do
      row = Map.fetch!(rows, operation)

      assert row.small_units == 20_000
      assert row.large_units == 40_000
      assert row.reduction_scaling >= 1.75
      assert row.reduction_scaling <= 2.25
      assert row.throughput_floor == Map.fetch!(@throughput_floors, operation)
      assert row.relative_ceiling == Map.fetch!(@relative_ceilings, operation)
      assert row.mib_per_second >= row.throughput_floor
      assert row.native_to_baseline <= row.relative_ceiling
    end

    assert output =~
             "comparator\tgnu-libiconv\tunavailable\tsource-qualified KOI8-F-NMSU-2008 profile is not provided"

    assert output =~ "summary\t2\tpassed"
  end

  test "RED: packaged benchmark prose is bound to the measured runtime sources" do
    root = Path.expand("..", __DIR__)
    document = File.read!(Path.join(root, "BENCHMARKS.md"))

    assert document =~
             ~r/KOI8-F benchmark source binding:\s+`#{source_digest(root)}`/
  end

  defp result_rows(output) do
    output
    |> String.split("\n", trim: true)
    |> Enum.filter(&String.starts_with?(&1, "result\t"))
    |> Map.new(fn line ->
      [
        "result",
        operation,
        small_units,
        large_units,
        small_reductions,
        large_reductions,
        reduction_scaling,
        median_us,
        mib_per_second,
        throughput_floor,
        baseline_us,
        native_to_baseline,
        relative_ceiling
      ] = String.split(line, "\t")

      {operation,
       %{
         small_units: String.to_integer(small_units),
         large_units: String.to_integer(large_units),
         small_reductions: String.to_integer(small_reductions),
         large_reductions: String.to_integer(large_reductions),
         reduction_scaling: String.to_float(reduction_scaling),
         median_us: String.to_integer(median_us),
         mib_per_second: String.to_float(mib_per_second),
         throughput_floor: String.to_float(throughput_floor),
         baseline_us: String.to_integer(baseline_us),
         native_to_baseline: String.to_float(native_to_baseline),
         relative_ceiling: String.to_float(relative_ceiling)
       }}
    end)
  end

  defp benchmark_env(root) do
    [
      {"MIX_ENV", "test"},
      {"MIX_BUILD_PATH", Path.expand(Mix.Project.build_path(), root)},
      {"ICONVEX_PATH", Path.expand("../iconvex", root)},
      {"ICONVEX_ARCHIVE_PATH", Path.expand("..", root)}
    ]
  end

  defp source_digest(root) do
    @benchmark_source_files
    |> Enum.sort()
    |> Enum.map(fn relative -> [relative, 0, File.read!(Path.join(root, relative)), 0] end)
    |> IO.iodata_to_binary()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end
end
