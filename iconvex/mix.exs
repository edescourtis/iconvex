defmodule Iconvex.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/edescourtis/iconvex"

  def project do
    [
      app: :iconvex,
      version: @version,
      elixir: "~> 1.16",
      description: "Pure native Elixir character-set conversion based on GNU libiconv 1.19",
      source_url: @source_url,
      start_permanent: Mix.env() == :prod,
      package: package(),
      docs: docs(),
      homepage_url: "https://hex.pm/packages/iconvex",
      deps: deps()
    ]
  end

  def application, do: [mod: {Iconvex.Application, []}]

  defp package do
    [
      licenses: ["LGPL-2.1-or-later"],
      links: %{
        "Documentation and source archive" => "https://hex.pm/packages/iconvex",
        "GitHub" => @source_url,
        "GNU libiconv" => "https://www.gnu.org/software/libiconv/"
      },
      files:
        ~w(lib priv mix.exs README.md EXTENDING.md DEEP_DIVE_REMEDIATION.md BENCHMARKS.md SUPPORTED_ENCODINGS.md SUPPORTED_NAME_INVENTORY.csv EXHAUSTIVE_UNICODE_DIFFERENTIAL.md UPSTREAM_TEST_COVERAGE.md CHANGELOG.md LICENSE NOTICE TDD_LOG.md)
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      source_url_pattern: "#{@source_url}/blob/v#{@version}/iconvex/%{path}#L%{line}",
      extras: [
        "README.md",
        "EXTENDING.md",
        "DEEP_DIVE_REMEDIATION.md",
        "SUPPORTED_ENCODINGS.md",
        "EXHAUSTIVE_UNICODE_DIFFERENTIAL.md",
        "UPSTREAM_TEST_COVERAGE.md",
        "BENCHMARKS.md",
        "TDD_LOG.md",
        "CHANGELOG.md",
        "LICENSE",
        "NOTICE"
      ],
      groups_for_extras: [
        "Using Iconvex": ["README.md", "EXTENDING.md", "SUPPORTED_ENCODINGS.md"],
        Verification: [
          "DEEP_DIVE_REMEDIATION.md",
          "EXHAUSTIVE_UNICODE_DIFFERENTIAL.md",
          "UPSTREAM_TEST_COVERAGE.md",
          "BENCHMARKS.md",
          "TDD_LOG.md"
        ],
        Legal: ["LICENSE", "NOTICE"]
      ]
    ]
  end

  defp deps do
    [{:ex_doc, "~> 0.40.3", only: :dev, runtime: false}]
  end
end
