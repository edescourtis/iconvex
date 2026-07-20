defmodule Iconvex.CIWorkflowContractTest do
  use ExUnit.Case, async: true

  test "CI treats the committed dependency lock as immutable" do
    workflow = File.read!(Path.expand("../.github/workflows/ci.yml", __DIR__))

    assert length(Regex.scan(~r/run: mix deps\.get --check-locked\b/, workflow)) == 2
    refute Regex.match?(~r/run: mix deps\.get\s*$/, workflow)
    assert workflow =~ "run: mix docs --warnings-as-errors"
    refute Regex.match?(~r/run: mix docs\s*$/, workflow)
  end
end
