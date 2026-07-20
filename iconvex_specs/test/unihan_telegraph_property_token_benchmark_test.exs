defmodule Iconvex.Specs.UnihanTelegraphPropertyTokenBenchmarkTest do
  use ExUnit.Case, async: false

  @moduletag timeout: :infinity

  @profiles [
    "UNIHAN-17.0.0-KMAINLANDTELEGRAPH-DECIMAL-TOKEN",
    "UNIHAN-17.0.0-KTAIWANTELEGRAPH-DECIMAL-TOKEN-READABLE",
    "UNIHAN-17.0.0-KTAIWANTELEGRAPH-DECIMAL-TOKEN-LOSSLESS-VPUA-1"
  ]
  @operations [
    "assigned decode",
    "unassigned decode",
    "reverse encode",
    "token_to_utf8",
    "utf8_to_token"
  ]
  @recorded_minimums %{
    "assigned decode" => 130.41,
    "unassigned decode" => 149.21,
    "reverse encode" => 54.45,
    "token_to_utf8" => 78.67,
    "utf8_to_token" => 42.68
  }
  @throughput_floors %{
    "assigned decode" => 4.35,
    "unassigned decode" => 4.98,
    "reverse encode" => 1.82,
    "token_to_utf8" => 2.63,
    "utf8_to_token" => 1.43
  }

  test "RED: executable benchmark covers all property-token paths and fresh-process gates" do
    {output, status} = run_benchmark(["--quick"])
    assert status == 0, output

    assert output =~
             "profile\toperation\ttokens/s\tlogical 4-byte MiB/s\tmedian us"

    for profile <- @profiles, operation <- @operations do
      assert output =~ "#{profile}\t#{operation}\t",
             "missing benchmark row: #{profile} #{operation}\n\n#{output}"

      assert output =~ "#{profile} #{operation} reduction scaling",
             "missing reduction gate: #{profile} #{operation}\n\n#{output}"

      floor = Map.fetch!(@throughput_floors, operation)
      recorded = Map.fetch!(@recorded_minimums, operation)

      assert floor == Float.ceil(recorded / 30, 2)
      assert recorded / floor <= 30

      assert output =~
               "#{profile} #{operation} throughput floor:",
             "missing throughput floor: #{profile} #{operation}\n\n#{output}"

      assert output =~ ">= #{floor} logical 4-byte MiB/s",
             "wrong throughput floor: #{profile} #{operation}\n\n#{output}"
    end

    assert output =~ "round-trip parity: 3/3 source-qualified property-token profiles"
    assert output =~ "all 15 fresh-process reduction-scaling gates passed"
    assert output =~ "all 15 conservative throughput floors passed"
    assert output =~ "no concatenated stream is benchmarked"
    assert output =~ "GNU comparison unavailable:"
    assert output =~ "no equivalent converter performance comparison is defined"
  end

  test "RED: GNU probe queries -l first and exact-matches only complete mapping names" do
    root = Path.expand("..", __DIR__)

    temp =
      Path.join(
        System.tmp_dir!(),
        "iconvex-unihan-token-gnu-probe-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(temp)
    on_exit(fn -> File.rm_rf!(temp) end)

    positive =
      fake_iconv(
        temp,
        "positive",
        "UTF-8 unihan_17_0_0_kmainlandtelegraph_decimal_token\n"
      )

    positive_log = Path.join(temp, "positive.log")
    {positive_output, 0} = run_probe(root, positive, positive_log)

    assert File.read!(positive_log) |> String.split("\n", trim: true) |> hd() == "-l"

    assert positive_output =~
             "GNU support listing includes exact normalized Unihan property-token"

    assert positive_output =~ "unihan_17_0_0_kmainlandtelegraph_decimal_token"
    refute positive_output =~ "GNU comparison unavailable:"

    negative =
      fake_iconv(
        temp,
        "negative",
        "UTF-8 X-UNIHAN-17.0.0-KMAINLANDTELEGRAPH-DECIMAL-TOKEN-WRAPPER\n"
      )

    negative_log = Path.join(temp, "negative.log")
    {negative_output, 0} = run_probe(root, negative, negative_log)

    assert File.read!(negative_log) |> String.split("\n", trim: true) |> hd() == "-l"
    assert negative_output =~ "queried iconv -l"
    assert negative_output =~ "no exact normalized Unihan property-token alias was listed"
    assert negative_output =~ "GNU comparison unavailable:"
    assert negative_output =~ "no equivalent converter performance comparison is defined"
  end

  defp run_benchmark(arguments) do
    root = Path.expand("..", __DIR__)
    mix = System.find_executable("mix") || flunk("mix executable is unavailable")

    System.cmd(
      mix,
      ["run", "--no-compile", "bench/unihan_telegraph_property_token_bench.exs" | arguments],
      cd: root,
      env: benchmark_env(root),
      stderr_to_stdout: true
    )
  end

  defp fake_iconv(directory, name, listing) do
    path = Path.join(directory, name)

    File.write!(
      path,
      """
      #!/bin/sh
      printf '%s\n' "$1" >> "$GNU_ICONV_LOG"
      case "$1" in
        -l) printf '%s' '#{listing}' ;;
        --version) printf '%s\n' 'iconv (GNU libiconv fake)' ;;
        *) exit 64 ;;
      esac
      """
    )

    File.chmod!(path, 0o755)
    path
  end

  defp run_probe(root, executable, log) do
    mix = System.find_executable("mix") || flunk("mix executable is unavailable")

    System.cmd(
      mix,
      [
        "run",
        "--no-compile",
        "bench/unihan_telegraph_property_token_bench.exs",
        "--quick",
        "--gnu-probe-only"
      ],
      cd: root,
      env:
        benchmark_env(root) ++
          [
            {"GNU_ICONV", executable},
            {"GNU_ICONV_LOG", log}
          ],
      stderr_to_stdout: true
    )
  end

  defp benchmark_env(root) do
    [
      {"MIX_ENV", "test"},
      {"MIX_BUILD_PATH", Path.expand(Mix.Project.build_path(), root)},
      {"ICONVEX_PATH", Path.expand("../iconvex", root)},
      {"ICONVEX_ARCHIVE_PATH", Path.expand("..", root)}
    ]
  end
end
