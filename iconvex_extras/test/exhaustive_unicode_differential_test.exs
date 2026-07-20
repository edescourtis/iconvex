defmodule Iconvex.ExhaustiveUnicodeDifferentialTest do
  use ExUnit.Case, async: false

  @corpus Path.expand("fixtures/all-unicode-codepoints.ucs4be", __DIR__)
  @report Path.expand("../EXHAUSTIVE_UNICODE_DIFFERENTIAL.md", __DIR__)
  @runner Path.expand("../tools/exhaustive_unicode_differential.exs", __DIR__)
  @helper Path.expand("../tools/gnu_iconv_engine_benchmark.c", __DIR__)
  @corpus_sha256 "087f212baaa35562a226c5834e723620bb7d9f4103b76f9c7cbdaaff2d6cd67c"
  @runtime_patterns ["lib/**/*.ex", "priv/**/*.etf", "mix.exs"]

  test "exhaustive differential artifacts cover every Unicode code point and every codec" do
    assert File.regular?(@runner)
    assert File.regular?(@helper)
    assert File.stat!(@corpus).size == 1_114_112 * 4

    corpus = File.read!(@corpus)

    corpus_digest = corpus |> then(&:crypto.hash(:sha256, &1)) |> Base.encode16(case: :lower)

    assert corpus_digest == @corpus_sha256

    {count, surrogate_count, last} =
      for <<codepoint::unsigned-big-32 <- corpus>>, reduce: {0, 0, -1} do
        {count, surrogate_count, previous} ->
          assert codepoint == previous + 1
          assert codepoint <= 0x10FFFF
          surrogate_count = surrogate_count + if(codepoint in 0xD800..0xDFFF, do: 1, else: 0)
          {count + 1, surrogate_count, codepoint}
      end

    assert count == 1_114_112
    assert surrogate_count == 2_048
    assert last == 0x10FFFF

    report = File.read!(@report)

    assert report =~ "Unicode code points: **1,114,112/1,114,112**"
    assert report =~ "Unicode scalar values: **1,112,064**"
    assert report =~ "Non-scalar surrogate code points: **2,048**"
    assert report =~ "Every Unicode code point from U+0000 through U+10FFFF"
    assert report =~ "UCS-4BE"
    assert report =~ "| Round-trip code points |"
    assert report =~ "Codecs passed: **198/198**"
    assert report =~ "Mismatches: **0**"
    assert report =~ "Performance ceiling: **30.00x GNU**"
    assert report =~ "Performance failures: **0**"
    assert report =~ "Corpus SHA-256: `#{corpus_digest}`"
    assert report =~ "Timing unit: **microseconds (µs)**"
    assert report =~ "GNU engine forward µs"
    assert report =~ "GNU engine reverse µs"
    assert report =~ "GNU benchmark timings exclude process startup, file I/O, and stdout"
    assert report =~ "GNU CLI output remains the byte-correctness oracle"

    helper_digest = @helper |> File.read!() |> sha256()
    assert report =~ "GNU timing helper source SHA-256: `#{helper_digest}`"

    assert Regex.match?(
             ~r/GNU timing helper executable SHA-256: `[0-9a-f]{64}`/,
             report
           )

    assert Regex.match?(
             ~r/GNU libiconv benchmark artifact SHA-256: `[0-9a-f]{64}`/,
             report
           )

    runner_digest = @runner |> File.read!() |> sha256()
    assert report =~ "Differential runner SHA-256: `#{runner_digest}`"

    runtime_digest = combined_runtime_digest()
    assert report =~ "Combined runtime artifact SHA-256: `#{runtime_digest}`"

    codecs =
      Regex.scan(~r/^\| `([^`]+)` \| PASS \|/m, report, capture: :all_but_first)
      |> List.flatten()

    assert codecs == Iconvex.encodings()
  end

  test "core benchmark narrative matches the current combined report" do
    report = File.read!(@report)
    core_root = Mix.Project.deps_paths() |> Map.fetch!(:iconvex) |> Path.expand()
    benchmarks = File.read!(Path.join(core_root, "BENCHMARKS.md"))

    [_, report_wall_ms] = Regex.run(~r/Total measured wall time: \*\*(\d+) ms\*\*/, report)
    [_, report_passed, report_total] = Regex.run(~r/Codecs passed: \*\*(\d+)\/(\d+)\*\*/, report)
    [_, report_mismatches] = Regex.run(~r/Mismatches: \*\*(\d+)\*\*/, report)

    [_, report_performance_failures] =
      Regex.run(~r/Performance failures: \*\*(\d+)\*\*/, report)

    [_, report_performance_ceiling] =
      Regex.run(~r/Performance ceiling: \*\*([0-9.]+)x GNU\*\*/, report)

    {worst_codec, worst_slowdown} =
      ~r/^\| `([^`]+)` \| PASS \| ([0-9.]+)x \|/m
      |> Regex.scan(report, capture: :all_but_first)
      |> Enum.map(fn [codec, slowdown] -> {codec, String.to_float(slowdown)} end)
      |> Enum.max_by(&elem(&1, 1))

    [
      _,
      benchmark_wall_ms,
      benchmark_passed,
      benchmark_total,
      benchmark_mismatches,
      benchmark_performance_failures,
      benchmark_codec,
      benchmark_slowdown
    ] =
      Regex.run(
        ~r/latest source-bound rerun took ([\d,]+) ms:\s+(\d+)\/(\d+) codecs\s+were byte-exact, with ([[:alnum:]]+) mismatches and ([[:alnum:]]+) performance failures\..*?worst\s+measured slowdown was ([^\s]+) at ([0-9.]+)x/s,
        benchmarks
      )

    normalize_count = fn
      "zero" -> "0"
      count -> count
    end

    [_, benchmark_performance_ceiling] =
      Regex.run(~r/fails if any codec exceeds ([0-9.]+)x its GNU 1\.19/, benchmarks)

    assert String.replace(benchmark_wall_ms, ",", "") == report_wall_ms
    assert benchmark_passed == report_passed
    assert benchmark_total == report_total
    assert normalize_count.(benchmark_mismatches) == report_mismatches
    assert normalize_count.(benchmark_performance_failures) == report_performance_failures

    assert String.to_float(benchmark_performance_ceiling) ==
             String.to_float(report_performance_ceiling)

    assert benchmark_codec == worst_codec
    assert String.to_float(benchmark_slowdown) == worst_slowdown
  end

  test "package hotspot and deep-dive narratives match the current combined report" do
    report = File.read!(@report)
    extras_root = Path.expand("..", __DIR__)
    core_root = Mix.Project.deps_paths() |> Map.fetch!(:iconvex) |> Path.expand()
    benchmarks = File.read!(Path.join(extras_root, "BENCHMARKS.md"))
    readme = File.read!(Path.join(extras_root, "README.md"))
    deep_dive = File.read!(Path.join(core_root, "DEEP_DIVE_REMEDIATION.md"))

    measurements =
      Map.new(["EUC-JISX0213", "CP943"], fn codec ->
        row =
          report
          |> String.split("\n")
          |> Enum.find(&String.starts_with?(&1, "| `#{codec}` | PASS |"))

        [
          _codec,
          "PASS",
          _worst,
          forward,
          reverse,
          _encoded_bytes,
          _encoded_digest,
          _roundtrip_codepoints,
          _roundtrip_digest,
          iconvex_forward,
          gnu_forward,
          iconvex_reverse,
          gnu_reverse,
          "-"
        ] = split_report_row(row)

        {codec,
         %{
           forward: ratio(forward),
           reverse: ratio(reverse),
           iconvex_forward: String.to_float(iconvex_forward),
           gnu_forward: String.to_float(gnu_forward),
           iconvex_reverse: String.to_float(iconvex_reverse),
           gnu_reverse: String.to_float(gnu_reverse)
         }}
      end)

    for {codec, values} <- measurements do
      assert benchmark_measurement(benchmarks, codec, "forward") ==
               {values.iconvex_forward, values.gnu_forward, values.forward}

      assert benchmark_measurement(benchmarks, codec, "reverse") ==
               {values.iconvex_reverse, values.gnu_reverse, values.reverse}
    end

    [_, euc_forward, euc_reverse, cp943_forward, cp943_reverse] =
      Regex.run(
        ~r/EUC-JISX0213 is ([0-9.]+)x forward\/([0-9.]+)x\s+reverse and CP943 is ([0-9.]+)x\/([0-9.]+)x/,
        readme
      )

    assert {String.to_float(euc_forward), String.to_float(euc_reverse)} ==
             {measurements["EUC-JISX0213"].forward, measurements["EUC-JISX0213"].reverse}

    assert {String.to_float(cp943_forward), String.to_float(cp943_reverse)} ==
             {measurements["CP943"].forward, measurements["CP943"].reverse}

    {worst_codec, worst_slowdown} =
      ~r/^\| `([^`]+)` \| PASS \| ([0-9.]+)x \|/m
      |> Regex.scan(report, capture: :all_but_first)
      |> Enum.map(fn [codec, slowdown] -> {codec, String.to_float(slowdown)} end)
      |> Enum.max_by(&elem(&1, 1))

    [_, deep_dive_slowdown, deep_dive_codec] =
      Regex.run(~r/records a ([0-9.]+)x worst case \(([^)]+)\)/, deep_dive)

    assert {deep_dive_codec, String.to_float(deep_dive_slowdown)} ==
             {worst_codec, worst_slowdown}
  end

  defp combined_runtime_digest do
    extras_root = Path.expand("..", __DIR__)
    core_root = Mix.Project.deps_paths() |> Map.fetch!(:iconvex) |> Path.expand()

    [{"iconvex", core_root}, {"iconvex_extras", extras_root}]
    |> Enum.flat_map(fn {label, root} ->
      @runtime_patterns
      |> Enum.flat_map(&Path.wildcard(Path.join(root, &1)))
      |> Enum.filter(&File.regular?/1)
      |> Enum.map(fn path -> {Path.join(label, Path.relative_to(path, root)), path} end)
    end)
    |> Enum.sort_by(&elem(&1, 0))
    |> Enum.map(fn {relative, path} ->
      [relative, <<0>>, path |> File.read!() |> sha256(), "\n"]
    end)
    |> sha256()
  end

  defp split_report_row(row) do
    row
    |> String.trim()
    |> String.trim("|")
    |> String.split("|")
    |> Enum.map(&String.trim/1)
    |> List.update_at(0, &String.trim(&1, "`"))
  end

  defp ratio(value), do: value |> String.trim_trailing("x") |> String.to_float()

  defp benchmark_measurement(document, codec, direction) do
    [_, iconvex, gnu, slowdown] =
      Regex.run(
        ~r/\| #{Regex.escape(codec)} #{direction} \| ([\d,.]+) µs \| ([\d,.]+) µs \| ([0-9.]+)x \|/,
        document
      )

    {decimal(iconvex), decimal(gnu), String.to_float(slowdown)}
  end

  defp decimal(value), do: value |> String.replace(",", "") |> String.to_float()

  defp sha256(iodata) do
    iodata
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end
end
