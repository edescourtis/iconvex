defmodule Iconvex.Telecom.SourceProvenanceContractTest do
  use ExUnit.Case, async: true

  @root Path.expand("..", __DIR__)

  test "RED: every retained telecom research artifact has ownership and digest metadata" do
    provenance = File.read!(Path.join(@root, "SOURCE_PROVENANCE.md"))
    notice = File.read!(Path.join(@root, "NOTICE"))

    for relative <- research_artifacts() do
      digest = @root |> Path.join(relative) |> File.read!() |> sha256()

      assert provenance =~ "`#{relative}`"
      assert provenance =~ digest
    end

    assert provenance =~ "repository-only"
    assert provenance =~ "excluded from Hex"
    assert provenance =~ "No upstream artifact is relicensed as LGPL"
    assert provenance =~ "International Telecommunication Union"
    assert provenance =~ "derived rendering"

    assert notice =~ "SOURCE_PROVENANCE.md"
    assert notice =~ "repository-only"
    assert notice =~ "International Telecommunication Union"
    assert notice =~ "No redistribution license is inferred"
  end

  test "RED: neither the package selectors nor built archive redistribute tmp evidence" do
    package_files = Mix.Project.config() |> Keyword.fetch!(:package) |> Keyword.fetch!(:files)
    refute "tmp" in package_files
    assert "SOURCE_PROVENANCE.md" in package_files

    archive = Path.join(@root, "iconvex_telecom-0.1.0.tar")

    if File.regular?(archive) do
      {listing, 0} = System.cmd("tar", ["-tf", archive])
      refute listing =~ "/tmp/"
    end
  end

  defp research_artifacts do
    @root
    |> Path.join("tmp/**/*")
    |> Path.wildcard(match_dot: true)
    |> Enum.filter(&File.regular?/1)
    |> Enum.map(&Path.relative_to(&1, @root))
    |> Enum.sort()
  end

  defp sha256(binary), do: :crypto.hash(:sha256, binary) |> Base.encode16(case: :lower)
end
