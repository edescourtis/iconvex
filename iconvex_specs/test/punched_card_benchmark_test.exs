defmodule Iconvex.Specs.PunchedCardBenchmarkTest do
  use ExUnit.Case, async: false

  @moduletag timeout: :infinity

  @profiles [
    "IBM H report",
    "IBM H program",
    "IBM 1401",
    "CDC 167/166 1965",
    "CDC 6000 1970",
    "BCD CDC Iowa reconstruction"
  ]

  @operations [
    "packed MSB encode",
    "packed MSB decode",
    "packed LSB encode",
    "packed LSB decode",
    "16BE encode",
    "16BE decode",
    "16LE encode",
    "16LE decode"
  ]

  @profile_ids [
    "IBM-7040-H-REPORT",
    "IBM-7040-H-PROGRAM",
    "IBM-1401-CARD",
    "CDC-167-BCD-HOLLERITH-1965",
    "CDC-6000-STANDARD-HOLLERITH-1970",
    "BCD-CDC-IOWA"
  ]

  @canonical_counts %{
    "IBM-7040-H-REPORT" => 64,
    "IBM-7040-H-PROGRAM" => 64,
    "IBM-1401-CARD" => 63,
    "CDC-167-BCD-HOLLERITH-1965" => 63,
    "CDC-6000-STANDARD-HOLLERITH-1970" => 63,
    "BCD-CDC-IOWA" => 64
  }

  test "RED: benchmark reference is evidence-derived and every canonical row is covered" do
    root = Path.expand("..", __DIR__)
    source = File.read!(Path.join(root, "bench/punched_card_benchmark.exs"))

    assert source =~ "canonical_maps.csv"
    assert source =~ "decode_aliases.csv"
    assert source =~ "@benchmark_alphabet_units 64"
    assert source =~ "@iterations if(@quick, do: 5, else: 7)"
    assert source =~ "@sample_repetitions if(@quick, do: 256, else: 1_024)"
    assert source =~ "reference_evidence(profile_id)"
    assert source =~ "complete_coverage_alphabet(evidence.canonical_rows)"
    assert source =~ "MapSet.subset?(MapSet.new(codepoints), MapSet.new(alphabet))"
    refute source =~ "defp reference_encode_map(logical)"
    refute source =~ "logical.encode_packed([codepoint])"

    evidence_loader =
      source
      |> String.split("defp reference_evidence(profile_id)", parts: 2)
      |> List.last()
      |> String.split("defp reference_msb_encode", parts: 2)
      |> List.first()

    assert evidence_loader =~ "File.read!"
    assert evidence_loader =~ ":crypto.hash"
    refute evidence_loader =~ "Iconvex."
    refute evidence_loader =~ "logical"
    refute evidence_loader =~ "transport"

    rows =
      root
      |> Path.join("priv/sources/punched-card-codes/canonical_maps.csv")
      |> File.read!()
      |> String.split("\n", trim: true)
      |> tl()
      |> Enum.map(fn line ->
        [profile | _rest] =
          line
          |> String.trim_leading("\"")
          |> String.trim_trailing("\"")
          |> String.split("\",\"")

        profile
      end)
      |> Enum.filter(&(&1 in @profile_ids))

    assert Enum.frequencies(rows) == @canonical_counts
    assert length(rows) == 381
  end

  test "RED: executable benchmark covers every profile, transport, direction, and scaling gate" do
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
        ["run", "--no-compile", "bench/punched_card_benchmark.exs", "--quick"],
        cd: root,
        env: env,
        stderr_to_stdout: true
      )

    assert status == 0, output

    for profile <- @profiles, operation <- @operations do
      assert output =~ "#{profile} #{operation}",
             "missing benchmark row: #{profile} #{operation}\n\n#{output}"
    end

    assert output =~ "round-trip parity: 6/6 profiles x 4 transports"
    assert output =~ "source-bound reference evidence: 381/381 canonical rows across 6/6 profiles"
    assert output =~ "complete-coverage benchmark alphabets: 6/6 profiles x 64 units"

    for operation <- @operations do
      assert output =~ "#{operation} reduction scaling 20k->40k:",
             "missing reduction gate: #{operation}\n\n#{output}"
    end

    assert output =~ "all 8 reduction-scaling gates passed"

    for profile <- @profiles, operation <- @operations do
      assert output =~ "#{profile} #{operation} native / independent reference:",
             "missing comparative ceiling: #{profile} #{operation}\n\n#{output}"
    end

    assert output =~ "all 48 native/reference 30x ceiling gates passed"
  end
end
