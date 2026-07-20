defmodule Iconvex.Specs.TI89AMS20BenchmarkTest do
  use ExUnit.Case, async: false

  @moduletag timeout: :infinity

  @profiles [
    "TI-89-92-PLUS-AMS-2.0",
    "TI-89-92-PLUS-AMS-2.0-VISIBLE",
    "TI-89-92-PLUS-AMS-2.0-LOSSLESS-VPUA",
    "TI-89-92-PLUS-AMS-2.0-RAW-VPUA"
  ]
  @operations ["direct decode", "direct encode", "public decode", "public encode"]
  @readable_floors %{
    "direct decode" => 1.2,
    "direct encode" => 0.51,
    "public decode" => 0.77,
    "public encode" => 0.51
  }
  @raw_floors %{
    "direct decode" => 1.38,
    "direct encode" => 0.96,
    "public decode" => 0.9,
    "public encode" => 0.94
  }
  @readable_recorded_minimums %{
    "direct decode" => 35.9,
    "direct encode" => 15.16,
    "public decode" => 22.85,
    "public encode" => 15.11
  }
  @raw_recorded_minimums %{
    "direct decode" => 41.23,
    "direct encode" => 28.64,
    "public decode" => 26.78,
    "public encode" => 28.18
  }

  test "RED: benchmark covers every profile, direct/public path, and linear-scaling gate" do
    root = Path.expand("..", __DIR__)
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
        ["run", "--no-compile", "bench/ti89_ams2_bench.exs", "--quick"],
        cd: root,
        env: env,
        stderr_to_stdout: true
      )

    assert status == 0, output

    for profile <- @profiles, operation <- @operations do
      assert output =~ "#{profile}\t#{operation}\t",
             "missing benchmark row: #{profile} #{operation}\n\n#{output}"

      assert output =~ "#{profile} #{operation} reduction scaling",
             "missing reduction gate: #{profile} #{operation}\n\n#{output}"

      assert output =~ "#{profile} #{operation} throughput floor:",
             "missing throughput floor: #{profile} #{operation}\n\n#{output}"

      {floors, recorded_minimums} =
        if String.ends_with?(profile, "-RAW-VPUA") do
          {@raw_floors, @raw_recorded_minimums}
        else
          {@readable_floors, @readable_recorded_minimums}
        end

      floor = Map.fetch!(floors, operation)
      recorded_minimum = Map.fetch!(recorded_minimums, operation)

      assert floor == Float.ceil(recorded_minimum / 30, 2),
             "floor must be ceil(#{recorded_minimum} / 30) to 0.01: #{profile} #{operation}"

      assert output =~ ">= #{floor} Mi input bytes/s",
             "wrong throughput floor: #{profile} #{operation}\n\n#{output}"
    end

    assert output =~ "sequence-heavy corpus includes 9A, 9B, and B4"
    assert output =~ "round-trip parity: 4/4 profiles x direct/public paths"
    assert output =~ "all 16 reduction-scaling gates passed"
    assert output =~ "all 16 throughput floors passed"
    assert output =~ "GNU comparison unavailable:"
  end

  test "RED: GNU support probe queries -l and compares exact normalized aliases" do
    root = Path.expand("..", __DIR__)

    temp =
      Path.join(System.tmp_dir!(), "iconvex-ti-gnu-probe-#{System.unique_integer([:positive])}")

    File.mkdir_p!(temp)

    on_exit(fn -> File.rm_rf!(temp) end)

    positive = fake_iconv(temp, "positive", "UTF-8 ti_89_ams_2_0\n")
    positive_log = Path.join(temp, "positive.log")
    {positive_output, 0} = run_probe(root, positive, positive_log)

    assert File.read!(positive_log) |> String.split("\n", trim: true) |> hd() == "-l"
    assert positive_output =~ "GNU support listing includes exact normalized TI alias"
    assert positive_output =~ "ti_89_ams_2_0"
    refute positive_output =~ "GNU comparison unavailable:"

    negative = fake_iconv(temp, "negative", "UTF-8 X-TI-89-AMS-2.0-WRAPPER\n")
    negative_log = Path.join(temp, "negative.log")
    {negative_output, 0} = run_probe(root, negative, negative_log)

    assert File.read!(negative_log) |> String.split("\n", trim: true) |> hd() == "-l"
    assert negative_output =~ "queried iconv -l"
    assert negative_output =~ "no exact normalized TI alias"
    assert negative_output =~ "GNU comparison unavailable:"
  end

  defp fake_iconv(directory, name, listing) do
    path = Path.join(directory, name)

    File.write!(
      path,
      """
      #!/bin/sh
      printf '%s\\n' "$1" >> "$GNU_ICONV_LOG"
      case "$1" in
        -l) printf '%s' '#{listing}' ;;
        --version) printf '%s\\n' 'iconv (GNU libiconv fake)' ;;
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
      ["run", "--no-compile", "bench/ti89_ams2_bench.exs", "--quick", "--gnu-probe-only"],
      cd: root,
      env: [
        {"MIX_ENV", "test"},
        {"MIX_BUILD_PATH", Path.expand(Mix.Project.build_path(), root)},
        {"ICONVEX_PATH", Path.expand("../iconvex", root)},
        {"ICONVEX_ARCHIVE_PATH", Path.expand("..", root)},
        {"GNU_ICONV", executable},
        {"GNU_ICONV_LOG", log}
      ],
      stderr_to_stdout: true
    )
  end
end
