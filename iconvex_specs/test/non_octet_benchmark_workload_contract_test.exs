defmodule Iconvex.Specs.NonOctetBenchmarkWorkloadContractTest do
  use ExUnit.Case, async: true

  @benchmark Path.expand("../bench/non_octet_benchmark.exs", __DIR__)

  test "each reported throughput uses the workload actually measured" do
    source = File.read!(@benchmark)

    assert source =~ "defp bench(name, scalar_count, function)"
    assert length(Regex.scan(~r/bench\("UTF-9 [^\n]+", length\(@scalars\), fn/, source)) == 4

    assert length(Regex.scan(~r/bench\("UTF-18 [^\n]+", length\(@utf18_scalars\), fn/, source)) ==
             4

    assert source =~ "scalar_count * 1_000_000 / median"
    refute source =~ "length(@scalars) * 1_000_000 / median"
  end
end
