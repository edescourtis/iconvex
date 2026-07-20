defmodule IconvexTelecom.MixProject do
  use Mix.Project

  @source_url "https://github.com/edescourtis/iconvex"

  def project do
    [
      app: :iconvex_telecom,
      version: "0.1.0",
      elixir: "~> 1.16",
      description: "Pure Elixir telecom encodings for Iconvex",
      source_url: @source_url,
      start_permanent: Mix.env() == :prod,
      package: package(),
      deps: deps()
    ]
  end

  def application, do: [mod: {Iconvex.Telecom.Application, []}]

  defp deps do
    case System.get_env("ICONVEX_PATH") do
      nil -> [{:iconvex, "~> 0.1.0"}]
      path -> [{:iconvex, "~> 0.1.0", path: path}]
    end
  end

  defp package do
    [
      licenses: ["LGPL-2.1-or-later", "Apache-2.0", "Unicode-3.0"],
      links: %{
        "GitHub" => @source_url,
        "3GPP TS 23.038" => "https://www.3gpp.org/ftp/Specs/archive/23_series/23.038/",
        "IBM GA27-3005-3" =>
          "https://www.bitsavers.org/pdf/ibm/2780/GA27-3005-3-2780_Data_Terminal_Description_Aug71.pdf",
        "IBM GA27-3004-2" =>
          "https://www.bitsavers.org/pdf/ibm/datacomm/GA27-3004-2_General_Information_Binary_Synchronous_Communications_Oct70.pdf",
        "ITU-R M.1371-6" => "https://www.itu.int/rec/R-REC-M.1371/en",
        "ITU-T S.2" => "https://www.itu.int/rec/T-REC-S.2/en",
        "Iconvex" => "https://hex.pm/packages/iconvex"
      },
      files:
        ~w(lib priv mix.exs README.md SUPPORTED_ENCODINGS.md SUPPORTED_CODEC_INVENTORY.csv SUPPORTED_PACKED_CODEC_INVENTORY.csv CONFORMANCE.md BENCHMARKS.md TDD_LOG.md CHANGELOG.md SOURCE_PROVENANCE.md LICENSE LICENSE.APACHE-2.0 LICENSE.UNICODE NOTICE)
    ]
  end
end
