defmodule Iconvex.Specs.ECMA44BenchmarkTest do
  use ExUnit.Case, async: false
  @moduletag timeout: :infinity

  @modes ["7-bit", "8-bit"]
  @operations [
    "masks encode",
    "masks decode",
    "packed MSB encode",
    "packed MSB decode",
    "packed LSB encode",
    "packed LSB decode",
    "16BE encode",
    "16BE decode",
    "16LE encode",
    "16LE decode"
  ]

  test "RED: production benchmark covers every raw transport and hard reduction gate" do
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
        ["run", "--no-compile", "bench/ecma44_benchmark.exs", "--quick"],
        cd: root,
        env: env,
        stderr_to_stdout: true
      )

    assert status == 0, output

    for mode <- @modes, operation <- @operations do
      assert output =~ "#{mode} #{operation}",
             "missing benchmark row: #{mode} #{operation}\n\n#{output}"

      assert output =~ "#{mode} #{operation} reduction scaling 20k->40k:",
             "missing reduction gate: #{mode} #{operation}\n\n#{output}"
    end

    assert output =~ "round-trip parity: 2/2 modes x 4 serialized transports plus masks"
    assert output =~ "all 20 reduction-scaling gates passed"
  end
end
