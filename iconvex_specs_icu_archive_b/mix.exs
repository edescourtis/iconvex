defmodule IconvexSpecsICUArchiveB.MixProject do
  use Mix.Project

  @source_url "https://github.com/edescourtis/iconvex"

  def project do
    [
      app: :iconvex_specs_icu_archive_b,
      version: "0.1.0",
      elixir: "~> 1.16",
      description: "ICU historical mapping-table shard B for Iconvex Specs",
      source_url: @source_url,
      start_permanent: Mix.env() == :prod,
      package: package(),
      deps: deps()
    ]
  end

  def application, do: [mod: {Iconvex.Specs.ICUArchiveShardB.Application, []}]

  defp deps do
    case System.get_env("ICONVEX_PATH") do
      nil -> [{:iconvex, "~> 0.1.0"}]
      path -> [{:iconvex, "~> 0.1.0", path: path}]
    end
  end

  defp package do
    [
      licenses: ["LGPL-2.1-or-later", "Unicode-3.0"],
      links: %{
        "GitHub" => @source_url,
        "Iconvex Specs" => "https://hex.pm/packages/iconvex_specs"
      },
      files: ~w(lib priv mix.exs README.md LICENSE LICENSE.UNICODE NOTICE)
    ]
  end
end
