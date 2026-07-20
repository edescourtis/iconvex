defmodule IconvexExtras.MixProject do
  use Mix.Project

  @source_url "https://github.com/edescourtis/iconvex"

  def project do
    [
      app: :iconvex_extras,
      version: "0.1.0",
      elixir: "~> 1.16",
      description: "Optional GNU libiconv extra and platform codecs for Iconvex",
      source_url: @source_url,
      start_permanent: Mix.env() == :prod,
      package: package(),
      deps: deps()
    ]
  end

  def application, do: [mod: {Iconvex.Extras.Application, []}]

  defp deps do
    case System.get_env("ICONVEX_PATH") do
      nil -> [{:iconvex, "~> 0.1.0"}]
      path -> [{:iconvex, "~> 0.1.0", path: path}]
    end
  end

  defp package do
    [
      licenses: ["LGPL-2.1-or-later"],
      links: %{
        "GitHub" => @source_url,
        "Iconvex" => "https://hex.pm/packages/iconvex"
      },
      files:
        ~w(lib priv mix.exs README.md BENCHMARKS.md SUPPORTED_ENCODINGS.md SUPPORTED_CODEC_INVENTORY.csv EXHAUSTIVE_UNICODE_DIFFERENTIAL.md CHANGELOG.md LICENSE NOTICE TDD_LOG.md)
    ]
  end
end
