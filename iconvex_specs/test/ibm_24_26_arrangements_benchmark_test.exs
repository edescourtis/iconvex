defmodule Iconvex.Specs.IBM2426ArrangementsBenchmarkTest do
  use ExUnit.Case, async: false

  @moduletag timeout: :infinity

  test "RED: focused benchmark covers ten profiles, four transports, scaling, and 30x gate" do
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
        ["run", "--no-compile", "bench/ibm_24_26_arrangements_benchmark.exs", "--quick"],
        cd: root,
        env: env,
        stderr_to_stdout: true
      )

    assert status == 0, output

    for letter <- ~w(A B C D E F G H J K),
        operation <- ["packed MSB", "packed LSB", "16BE", "16LE"] do
      assert output =~ "arrangement #{letter} #{operation}",
             "missing #{letter} #{operation} benchmark evidence\n\n#{output}"
    end

    assert output =~ "round-trip parity: 10/10 arrangements x 4 transports"
    assert output =~ "reduction scaling 20k->40k:"
    assert output =~ "wall scaling 20k->40k:"
    assert output =~ "native / dense-table reference:"
    assert output =~ "30x regression gate: pass"
  end
end
