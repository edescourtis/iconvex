defmodule Iconvex.Specs.IBMAdditionalCodePagesBenchmarkTest do
  use ExUnit.Case, async: false

  @moduletag timeout: :infinity

  @profiles [
    "IBM-310-293-P100-COMPOSITE-VPUA",
    "IBM-TNZ-CP310-B1EAE3C",
    "IBM-907-CDRA-P100-VPUA-COMPOSITE",
    "IBM-1116-850-P100-COMPOSITE",
    "IBM-1117-437-P100-COMPOSITE",
    "DEC-GREEK-8-1994",
    "DEC-TURKISH-8-1994"
  ]

  test "executable benchmark covers every profile, direction, and linear-scaling gate" do
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
        ["run", "--no-compile", "bench/ibm_additional_code_pages_bench.exs", "--quick"],
        cd: root,
        env: env,
        stderr_to_stdout: true
      )

    assert status == 0, output

    for profile <- @profiles, direction <- ~w(decode encode) do
      assert output =~ "#{profile}\t#{direction}\t",
             "missing benchmark row: #{profile} #{direction}\n\n#{output}"
    end

    assert output =~ "all 14 reduction-scaling gates passed"
    assert output =~ "GNU comparison unavailable:"
  end
end
