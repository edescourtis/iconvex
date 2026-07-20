defmodule IconvexIntegration.RepositorySourceMetadataContractTest do
  use ExUnit.Case, async: true

  @workspace Path.expand("../..", __DIR__)
  @source_url "https://github.com/edescourtis/iconvex"
  @packages ~w(
    iconvex
    iconvex_specs_icu_archive_a
    iconvex_specs_icu_archive_b
    iconvex_specs_icu_archive_c
    iconvex_extras
    iconvex_telecom
    iconvex_specs
  )

  test "all publishable packages bind Hex metadata to the public monorepo" do
    for package <- @packages do
      mix = File.read!(Path.join([@workspace, package, "mix.exs"]))

      assert mix =~ ~s(@source_url "#{@source_url}"), package
      assert mix =~ "source_url: @source_url", package
      assert mix =~ ~s("GitHub" => @source_url), package
    end
  end

  test "Core ExDoc links resolve inside the tagged monorepo subdirectory" do
    mix = File.read!(Path.join([@workspace, "iconvex", "mix.exs"]))

    assert mix =~ ~s(source_ref: "v\#{@version}")

    assert mix =~ "source_url_pattern:"

    assert mix =~
             ~s("\#{@source_url}/blob/v\#{@version}/iconvex/%{path}#L%{line}")
  end

  test "artifact audit requires the exact GitHub link from every Hex tarball" do
    audit = File.read!(Path.join([@workspace, "iconvex_integration/tools/artifact_audit.exs"]))

    assert audit =~ ~s(expected_github_url = "#{@source_url}")
    assert audit =~ ~S|Map.fetch!(metadata, "links")|
    assert audit =~ ~S|Map.get(links, "GitHub") == expected_github_url|
    assert audit =~ "Hex metadata GitHub link differs"
  end
end
