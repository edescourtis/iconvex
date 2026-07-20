defmodule Iconvex.Specs.TI83Plus2002BenchmarkTest do
  use ExUnit.Case, async: false

  @moduletag timeout: :infinity

  @profiles [
    "TI-83-PLUS-LARGE",
    "TI-83-PLUS-LARGE-LOSSLESS-VPUA",
    "TI-83-PLUS-LARGE-RAW-VPUA",
    "TI-83-PLUS-SMALL",
    "TI-83-PLUS-SMALL-LOSSLESS-VPUA",
    "TI-83-PLUS-SMALL-RAW-VPUA"
  ]
  @readable_profiles ["TI-83-PLUS-LARGE", "TI-83-PLUS-SMALL"]
  @core_operations ["direct decode", "direct encode", "public decode", "public encode"]
  @invalid_operations [
    "direct invalid strict",
    "direct invalid discard",
    "public invalid strict",
    "public invalid discard",
    "public invalid replace"
  ]

  @recorded_minimums %{
    readable: %{
      "direct decode" => 39.54,
      "direct encode" => 14.38,
      "public decode" => 24.0,
      "public encode" => 15.16
    },
    lossless: %{
      "direct decode" => 39.27,
      "direct encode" => 15.04,
      "public decode" => 23.61,
      "public encode" => 15.2
    },
    raw: %{
      "direct decode" => 39.17,
      "direct encode" => 27.23,
      "public decode" => 25.99,
      "public encode" => 27.29
    },
    invalid: %{
      "direct invalid strict" => 40.05,
      "direct invalid discard" => 16.81,
      "public invalid strict" => 40.12,
      "public invalid discard" => 11.17,
      "public invalid replace" => 1.1
    }
  }

  @throughput_floors %{
    readable: %{
      "direct decode" => 1.32,
      "direct encode" => 0.48,
      "public decode" => 0.81,
      "public encode" => 0.51
    },
    lossless: %{
      "direct decode" => 1.31,
      "direct encode" => 0.51,
      "public decode" => 0.79,
      "public encode" => 0.51
    },
    raw: %{
      "direct decode" => 1.31,
      "direct encode" => 0.91,
      "public decode" => 0.87,
      "public encode" => 0.91
    },
    invalid: %{
      "direct invalid strict" => 1.34,
      "direct invalid discard" => 0.57,
      "public invalid strict" => 1.34,
      "public invalid discard" => 0.38,
      "public invalid replace" => 0.04
    }
  }

  test "RED: executable benchmark covers all profiles, hot paths, invalid policies, and gates" do
    {output, status} = run_benchmark(["--quick"])
    assert status == 0, output

    for profile <- @profiles, operation <- @core_operations do
      assert_gate(output, profile, operation)
      assert_derived_floor(output, family(profile), operation)
    end

    for profile <- @readable_profiles, operation <- @invalid_operations do
      assert_gate(output, profile, operation)
      assert_derived_floor(output, :invalid, operation)
    end

    assert output =~ "sequence-heavy corpus includes 11, CB, CC, and D8"
    assert output =~ "decode-only 1D and DE remain excluded from readable reverse tries"
    assert output =~ "invalid corpora exercise strict, discard, and replacement recovery"
    assert output =~ "round-trip parity: 6/6 profiles x direct/public paths"
    assert output =~ "all 34 reduction-scaling gates passed"
    assert output =~ "all 34 throughput floors passed"
    assert output =~ "GNU comparison unavailable:"
  end

  test "RED: GNU support probe queries -l and accepts only exact normalized TI-83 aliases" do
    root = Path.expand("..", __DIR__)

    temp =
      Path.join(System.tmp_dir!(), "iconvex-ti83-gnu-probe-#{System.unique_integer([:positive])}")

    File.mkdir_p!(temp)
    on_exit(fn -> File.rm_rf!(temp) end)

    positive = fake_iconv(temp, "positive", "UTF-8 ti_83_plus_large\n")
    positive_log = Path.join(temp, "positive.log")
    {positive_output, 0} = run_probe(root, positive, positive_log)

    assert File.read!(positive_log) |> String.split("\n", trim: true) |> hd() == "-l"
    assert positive_output =~ "GNU support listing includes exact normalized TI-83 alias"
    assert positive_output =~ "ti_83_plus_large"
    refute positive_output =~ "GNU comparison unavailable:"

    negative = fake_iconv(temp, "negative", "UTF-8 X-TI-83-PLUS-LARGE-WRAPPER\n")
    negative_log = Path.join(temp, "negative.log")
    {negative_output, 0} = run_probe(root, negative, negative_log)

    assert File.read!(negative_log) |> String.split("\n", trim: true) |> hd() == "-l"
    assert negative_output =~ "queried iconv -l"
    assert negative_output =~ "no exact normalized TI-83 alias"
    assert negative_output =~ "GNU comparison unavailable:"
  end

  defp assert_gate(output, profile, operation) do
    assert output =~ "#{profile}\t#{operation}\t",
           "missing benchmark row: #{profile} #{operation}\n\n#{output}"

    assert output =~ "#{profile} #{operation} reduction scaling",
           "missing reduction gate: #{profile} #{operation}\n\n#{output}"

    assert output =~ "#{profile} #{operation} throughput floor:",
           "missing throughput floor: #{profile} #{operation}\n\n#{output}"
  end

  defp assert_derived_floor(output, family, operation) do
    recorded = @recorded_minimums |> Map.fetch!(family) |> Map.fetch!(operation)
    floor = @throughput_floors |> Map.fetch!(family) |> Map.fetch!(operation)

    assert floor == Float.ceil(recorded / 30, 2),
           "floor must be ceil(#{recorded} / 30) to 0.01: #{family} #{operation}"

    assert output =~ ">= #{floor} Mi input bytes/s",
           "wrong throughput floor: #{family} #{operation}\n\n#{output}"
  end

  defp family(profile) do
    cond do
      String.ends_with?(profile, "-RAW-VPUA") -> :raw
      String.ends_with?(profile, "-LOSSLESS-VPUA") -> :lossless
      true -> :readable
    end
  end

  defp run_benchmark(arguments) do
    root = Path.expand("..", __DIR__)
    mix = System.find_executable("mix") || flunk("mix executable is unavailable")

    System.cmd(
      mix,
      ["run", "--no-compile", "bench/ti83_plus_2002_bench.exs" | arguments],
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
        "bench/ti83_plus_2002_bench.exs",
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
