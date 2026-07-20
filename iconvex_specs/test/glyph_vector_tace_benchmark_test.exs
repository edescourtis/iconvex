defmodule Iconvex.Specs.GlyphVectorTACEBenchmarkTest do
  use ExUnit.Case, async: false

  @moduletag timeout: :infinity
  @bench Path.expand("../bench/glyph_vector_tace_benchmark.exs", __DIR__)

  test "RED: every operation has independent reduction and elapsed-time 30x gates" do
    assert File.regular?(@bench)

    {output, 0} =
      System.cmd("mix", ["run", "bench/glyph_vector_tace_benchmark.exs"],
        cd: Path.expand("..", __DIR__),
        env: [{"MIX_ENV", "test"}, {"ICONVEX_BENCH_SECONDS", "0.01"}],
        stderr_to_stdout: true
      )

    for name <- [
          "CTAN-LY1-TEXNANSI-1.1-AGL-4036A9CA",
          "ADOBE-POSTSCRIPT-3-ISOLATIN1-AGL-4036A9CA",
          "TAMILVU-TACE16-APPENDIX-D-2010-16BE",
          "TAMILVU-TACE16-APPENDIX-D-2010-16LE"
        ] do
      assert output =~ name
    end

    assert output =~ "schema\ticonvex-glyph-vector-tace-benchmark\t2"
    assert output =~ "12/12 reduction gates passed"
    assert output =~ "12/12 elapsed-time gates passed"
    assert output =~ "4/4 scaling gates passed"
    refute output =~ "FAILED"

    assert output =~
             "columns\tprofile\toperation\tbytes\tnative_reductions\t" <>
               "reference_reductions\tnative_to_reference_reductions\tnative_us\t" <>
               "reference_us\tnative_to_reference_elapsed"

    results =
      output
      |> String.split("\n", trim: true)
      |> Enum.filter(&String.starts_with?(&1, "result\t"))

    assert length(results) == 12

    for result <- results do
      assert [
               "result",
               _profile,
               operation,
               bytes,
               native_reductions,
               reference_reductions,
               reduction_ratio,
               native_us,
               reference_us,
               elapsed_ratio
             ] = String.split(result, "\t")

      assert operation in ["decode", "encode", "roundtrip"]
      assert String.to_integer(bytes) > 0
      assert String.to_integer(native_reductions) > 0
      assert String.to_integer(reference_reductions) > 0
      assert String.to_float(reduction_ratio) <= 30.0
      assert String.to_integer(native_us) > 0
      assert String.to_integer(reference_us) > 0
      assert String.to_float(elapsed_ratio) <= 30.0
    end
  end
end
