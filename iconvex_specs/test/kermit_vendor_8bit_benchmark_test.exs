defmodule Iconvex.Specs.KermitVendor8BitBenchmarkTest do
  use ExUnit.Case, async: false

  @moduletag timeout: :infinity

  @profiles [
    "LUXOR-ABC800-BASIC-II-1981-CHARACTER-MODE",
    "RFC698-SU-AI-STANFORD-1975-FORMAT-EFFECTOR",
    "RFC698-SU-AI-STANFORD-1975-HIDDEN-GRAPHICS",
    "BULGARIA-PC",
    "MAZOVIA",
    "QNX-CONSOLE",
    "DG-INTERNATIONAL",
    "KERMIT-DG-LINEDRAWING",
    "KERMIT-DG-WORDPROCESSING",
    "KERMIT-HP-MATH-TECHNICAL",
    "KERMIT-SNI-BRACKETS",
    "KERMIT-SNI-EURO",
    "KERMIT-SNI-FACET",
    "KERMIT-SNI-IBM"
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
        ["run", "--no-compile", "bench/kermit_vendor_8bit_bench.exs", "--quick"],
        cd: root,
        env: env,
        stderr_to_stdout: true
      )

    assert status == 0, output

    for profile <- @profiles, direction <- ~w(decode encode) do
      assert output =~ "#{profile}\t#{direction}\t",
             "missing benchmark row: #{profile} #{direction}\n\n#{output}"
    end

    assert output =~ "all 28 reduction-scaling gates passed"
    assert output =~ "GNU comparison unavailable:"
  end
end
