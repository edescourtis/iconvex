defmodule IconvexIntegration.AggregateCIWorkflowContractTest do
  use ExUnit.Case, async: true

  @workspace Path.expand("../..", __DIR__)
  @workflow Path.join(@workspace, ".github/workflows/iconvex.yml")
  @packages ~w(
    iconvex_extras
    iconvex_telecom
    iconvex_specs_icu_archive_a
    iconvex_specs_icu_archive_b
    iconvex_specs_icu_archive_c
    iconvex_specs
    iconvex_integration
  )

  test "RED: aggregate checkout exposes a root-discovered full-stack workflow" do
    assert File.regular?(@workflow)
    workflow = File.read!(@workflow)

    assert workflow =~ "working-directory: iconvex"
    assert workflow =~ ~s(working-directory: \${{ matrix.directory }})
    assert workflow =~ "mix deps.get --check-locked"
    refute Regex.match?(~r/^\s*- run: mix deps\.get\s*$/m, workflow)
    assert workflow =~ "mix compile --warnings-as-errors"
    assert workflow =~ "mix test --cover"
    assert workflow =~ "elixir tools/release_check.exs"
    assert workflow =~ "mix docs --warnings-as-errors"

    assert length(Regex.scan(~r/^\s*- run: mix format --check-formatted$/m, workflow)) == 2

    for package <- @packages do
      assert workflow =~ "directory: #{package}"
    end
  end
end
