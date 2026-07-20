defmodule Iconvex.Specs.OpenJDKRemainingQuarantineTest do
  use ExUnit.Case, async: true

  @root Path.expand("..", __DIR__)
  @canonical_names ["x-eucJP-Open", "x-MS950-HKSCS-XP"]
  @aliases ["EUC_JP_Solaris", "eucJP-open", "MS950_HKSCS_XP"]
  @modules [Iconvex.Specs.OpenJDKEUCJPOpen, Iconvex.Specs.OpenJDKMS950HKSCSXP]

  @removed_files ~w(
    lib/iconvex/specs/openjdk_euc_jp_open.ex
    lib/iconvex/specs/openjdk_ms950_hkscs_xp.ex
    tools/import_openjdk_euc_jp_open.exs
    tools/import_openjdk_ms950_hkscs_xp.exs
    test/openjdk_euc_jp_open_test.exs
    test/openjdk_ms950_hkscs_xp_test.exs
    priv/tables/openjdk_euc_jp_open.etf
    priv/tables/openjdk_ms950_hkscs_xp.etf
    priv/openjdk_euc_jp_open_manifest.etf
    priv/openjdk_ms950_hkscs_xp_manifest.etf
  )

  test "remaining OpenJDK-derived codecs and assets are absent from the LGPL runtime" do
    registrations = Iconvex.Specs.registrations()
    names = Enum.flat_map(registrations, &[&1.canonical | &1.aliases])

    assert length(registrations) == 1_841
    assert length(Iconvex.Specs.codecs()) == 1_841

    for name <- @canonical_names ++ @aliases, do: refute(name in names)

    {:ok, application_modules} = :application.get_key(:iconvex_specs, :modules)

    for module <- @modules do
      refute module in application_modules
      refute Code.ensure_loaded?(module)
    end

    for relative <- @removed_files do
      refute File.exists?(Path.join(@root, relative)), relative
    end
  end

  test "exact upstream snapshots remain repository-only with the factual disposition" do
    package_files = Mix.Project.config() |> Keyword.fetch!(:package) |> Keyword.fetch!(:files)

    for {directory, expected_count} <- [
          {"priv/sources/openjdk-euc-jp-open", 11},
          {"priv/sources/openjdk-ms950-hkscs-xp", 8}
        ] do
      files =
        Path.wildcard(Path.join([@root, directory, "**", "*"]), match_dot: true)
        |> Enum.filter(&File.regular?/1)

      assert length(files) == expected_count

      for file <- files do
        relative = Path.relative_to(file, @root)
        refute selected_by_package?(package_files, relative)
      end

      metadata = File.read!(Path.join(@root, directory <> "/SOURCE_METADATA.md"))
      refute metadata =~ "independently written Elixir implementation"
      assert metadata =~ "source-informed"
      assert metadata =~ "quarantined"
      assert metadata =~ "repository-only"
    end

    for document <- ["OPENJDK_EUC_JP_OPEN.md", "OPENJDK_ENCODINGS.md"] do
      assert File.regular?(Path.join(@root, document))
      refute document in package_files
    end
  end

  defp selected_by_package?(selectors, relative) do
    target = Path.join(@root, relative)

    Enum.any?(selectors, fn selector ->
      absolute_selector = Path.join(@root, selector)

      cond do
        File.dir?(absolute_selector) ->
          target == absolute_selector or String.starts_with?(target, absolute_selector <> "/")

        String.contains?(selector, ["*", "?", "["]) ->
          target in Path.wildcard(absolute_selector, match_dot: true)

        true ->
          target == absolute_selector
      end
    end)
  end
end
