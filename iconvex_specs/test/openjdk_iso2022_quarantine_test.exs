defmodule Iconvex.Specs.OpenJDKISO2022QuarantineTest do
  use ExUnit.Case, async: true

  @root Path.expand("..", __DIR__)

  @canonical_names [
    "x-windows-50220",
    "x-windows-50221",
    "x-windows-iso2022jp",
    "x-ISO-2022-CN-GB",
    "x-ISO-2022-CN-CNS"
  ]

  @aliases [
    "cp50220",
    "ms50220",
    "ms50221",
    "windows-iso2022jp",
    "ISO-2022-CN-GB",
    "ISO2022CN_GB",
    "ISO-2022-CN-CNS",
    "ISO2022CN_CNS"
  ]

  @runtime_modules [
    Iconvex.Specs.OpenJDKISO2022JP.Data,
    Iconvex.Specs.OpenJDKISO2022JP,
    Iconvex.Specs.OpenJDKMS50220,
    Iconvex.Specs.OpenJDKMS50221,
    Iconvex.Specs.OpenJDKMSISO2022JP,
    Iconvex.Specs.OpenJDKISO2022CN.Data,
    Iconvex.Specs.OpenJDKISO2022CN,
    Iconvex.Specs.OpenJDKISO2022CNGB,
    Iconvex.Specs.OpenJDKISO2022CNCNS
  ]

  @removed_runtime_files ~w(
    lib/iconvex/specs/openjdk_iso2022_jp.ex
    lib/iconvex/specs/openjdk_iso2022_cn.ex
    priv/openjdk_iso2022_jp.etf
    priv/openjdk_iso2022_jp_manifest.etf
    priv/openjdk_iso2022_cn.etf
    priv/openjdk_iso2022_cn_manifest.etf
    tools/import_openjdk_iso2022_jp.exs
    tools/import_openjdk_iso2022_cn.exs
  )

  @repository_only_sources [
    {"priv/sources/openjdk-iso2022-jp", 16},
    {"priv/sources/openjdk-iso2022-cn", 15}
  ]

  test "five GPL-derived OpenJDK ISO-2022 codecs are absent from every runtime registry" do
    registrations = Iconvex.Specs.registrations()

    registered_names =
      Enum.flat_map(registrations, fn registration ->
        [registration.canonical | registration.aliases]
      end)

    assert length(Iconvex.Specs.codecs()) == 1_841
    assert length(Iconvex.Specs.encodings()) == 1_841
    assert length(registrations) == 1_841

    for name <- @canonical_names ++ @aliases do
      refute name in registered_names
    end

    {:ok, application_modules} = :application.get_key(:iconvex_specs, :modules)

    for module <- @runtime_modules do
      refute module in application_modules
      refute Code.ensure_loaded?(module)
    end
  end

  test "derived runtime source, generators, and generated assets are deleted" do
    for relative <- @removed_runtime_files do
      refute File.exists?(Path.join(@root, relative)), relative
    end
  end

  test "GPL snapshots remain repository-only provenance and are not Hex-selected" do
    package_files =
      Mix.Project.config() |> Keyword.fetch!(:package) |> Keyword.fetch!(:files)

    for {directory, expected_file_count} <- @repository_only_sources do
      paths = Path.wildcard(Path.join([@root, directory, "**", "*"]), match_dot: true)
      files = Enum.filter(paths, &File.regular?/1)

      assert length(files) == expected_file_count

      for path <- files do
        relative = Path.relative_to(path, @root)
        refute selected_by_package?(package_files, relative), "Hex selects GPL source #{relative}"
      end
    end

    refute "OPENJDK_ISO2022_JP.md" in package_files
    refute "OPENJDK_ISO2022_CN.md" in package_files
  end

  test "release documentation records the resolved quarantine and honest counts" do
    readme = File.read!(Path.join(@root, "README.md"))
    notice = File.read!(Path.join(@root, "NOTICE"))
    supported = File.read!(Path.join(@root, "SUPPORTED_ENCODINGS.md"))

    assert readme =~ "1,841 byte-pipeline codecs"
    assert readme =~ "OpenJDK quarantine"
    assert notice =~ "OpenJDK quarantine"
    assert supported =~ "**1,841** registered canonical codecs"

    for name <- @canonical_names do
      assert readme =~ name
      assert notice =~ name
    end
  end

  defp selected_by_package?(selectors, relative) do
    target = Path.join(@root, relative)

    Enum.any?(selectors, fn selector ->
      absolute_selector = Path.join(@root, selector)

      if String.contains?(selector, ["*", "?", "["]) do
        target in Path.wildcard(absolute_selector, match_dot: true)
      else
        target == absolute_selector or String.starts_with?(target, absolute_selector <> "/")
      end
    end)
  end
end
