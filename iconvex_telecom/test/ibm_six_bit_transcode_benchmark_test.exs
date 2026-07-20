defmodule Iconvex.Telecom.IBMSixBitTranscodeBenchmarkTest do
  use ExUnit.Case, async: false

  @benchmark Path.expand("../bench/ibm_six_bit_transcode_benchmark.exs", __DIR__)
  @benchmark_record Path.expand("../BENCHMARKS.md", __DIR__)

  @tag timeout: 180_000
  test "RED: production benchmark covers both profiles, both packed orders, scaling, and 30x gate" do
    benchmark = File.read!(@benchmark)
    assert benchmark =~ "@relative_ceiling 30.0"
    assert benchmark =~ "@reduction_bounds"
    assert benchmark =~ "@reduction_heap_words 1_000_000"
    assert benchmark =~ "spawn_opt("
    assert benchmark =~ "{:min_heap_size, @reduction_heap_words}"
    assert benchmark =~ ":code.priv_dir(:iconvex_telecom)"
    assert benchmark =~ "unit_hex,unicode_hex"

    for {filename, digest} <- [
          {"ga27-3005-3.csv", "cbb94188f9ac1a8b9a95dcff91d0744c84f77ad53377d62dd76eff4d6a476416"},
          {"ga27-3004-2.csv", "5dccf290006224a0de51dddda9ec227183f1527610f61cf2f70b606ccea7c31e"}
        ] do
      assert benchmark =~ filename
      assert benchmark =~ digest
    end

    refute benchmark =~ "codec.table()"
    refute benchmark =~ "SixBitTranscode.table"

    independent_reference =
      benchmark
      |> String.split("defp reference_pack_lsb_from_utf8", parts: 2)
      |> List.last()
      |> String.split("defp measure", parts: 2)
      |> hd()

    for helper <- [
          "reference_pack_lsb_units",
          "reference_unpack_lsb_units",
          "reference_pack_msb_units",
          "reference_unpack_msb_units"
        ] do
      assert independent_reference =~ helper
    end

    refute independent_reference =~ "Iconvex.Packed."
    refute independent_reference =~ "Iconvex.Telecom.Packed."

    {output, status} =
      System.cmd("mix", ["run", @benchmark],
        env: [{"MIX_ENV", "prod"}, {"ICONVEX_PATH", "../iconvex"}],
        stderr_to_stdout: true
      )

    assert status == 0, output

    profiles = [
      {"2780", "IBM-2780-SIX-BIT-TRANSCODE-GA27-3005-3"},
      {"bsc", "IBM-BSC-SIX-BIT-TRANSCODE-GA27-3004-2"}
    ]

    operations = ["encode", "decode", "pack_lsb", "unpack_lsb", "pack_msb", "unpack_msb"]

    for {label, profile} <- profiles, operation <- operations do
      assert output =~ "bench\t#{profile}\t#{operation}\t",
             "missing benchmark: #{profile} #{operation}\n\n#{output}"

      assert output =~ "comparison\t#{profile}\t#{operation}\toutput_equal\tpass",
             "missing output equality: #{profile} #{operation}\n\n#{output}"

      assert output =~ "gate\t#{label}\t#{operation}\treduction_scaling\t",
             "missing scaling gate: #{profile} #{operation}\n\n#{output}"

      benchmark_line =
        output
        |> String.split("\n")
        |> Enum.find(&String.starts_with?(&1, "bench\t#{profile}\t#{operation}\t"))

      refute benchmark_line =~ "relative=n/a"
    end

    assert output =~ "all 12 native/reference output-equality gates passed"
    assert output =~ "all 12 native/reference ratios <= 30.0x"
    assert output =~ "all 12 reduction-scaling gates passed"
  end

  test "RED: recorded benchmark run count is internally consistent" do
    record = File.read!(@benchmark_record)
    assert record =~ "Two isolated runs on 2026-07-18"
    assert record =~ "Throughput across two runs"
    refute record =~ "Three isolated runs on 2026-07-18"
  end
end
