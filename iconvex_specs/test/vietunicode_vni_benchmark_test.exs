defmodule Iconvex.Specs.VietUnicodeVNIBenchmarkTest do
  use ExUnit.Case, async: false

  @moduletag timeout: 120_000

  @canonicals [
    "VIETUNICODE-2002-VNI-ASCII-DOS",
    "VIETUNICODE-2002-VNI-ANSI-WIN-UNIX",
    "VIETUNICODE-2002-VNI-MAC",
    "VIETUNICODE-2002-VNI-INTERNET-MAIL"
  ]

  test "RED: all four source profiles have independent 30x and linear-scaling gates" do
    root = Path.expand("..", __DIR__)
    benchmark = Path.join(root, "bench/vietunicode_vni_bench.exs")
    source = File.read!(benchmark)

    assert source =~ "priv/sources/vietunicode-vni-2002/vni_profiles.csv"
    assert source =~ ":crypto.hash(:sha256"
    assert source =~ "@mapping_sha256"
    assert source =~ "@native_reference_ceiling 30.0"
    assert source =~ "reference_decode"
    assert source =~ "reference_encode"

    reference =
      source
      |> String.split("defp reference_decode", parts: 2)
      |> List.last()
      |> String.split("defp timed_median", parts: 2)
      |> List.first()

    refute reference =~ "codec."
    refute reference =~ "Iconvex.Specs.VietUnicodeVNI"

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
        ["run", "--no-compile", benchmark, "--quick"],
        cd: root,
        env: env,
        stderr_to_stdout: true
      )

    assert status == 0, output

    for canonical <- @canonicals,
        operation <- ["decode", "encode", "decode_to_utf8"] do
      assert output =~ "#{canonical} #{operation} native/reference",
             "missing benchmark row #{canonical} #{operation}\n\n#{output}"
    end

    assert output =~ "source-bound mapping coverage: 1041/1041 rows across 4/4 profiles"
    assert output =~ "all 12 native/reference 30x ceiling gates passed"
    assert output =~ "all 3 reduction-scaling gates passed"
  end
end
