defmodule IconvexIntegration.MixProject do
  use Mix.Project

  def project do
    [
      app: :iconvex_integration,
      version: "0.1.0",
      elixir: "~> 1.16",
      deps: deps()
    ]
  end

  def application, do: []

  defp deps do
    [
      {:iconvex, path: "../iconvex", runtime: false, override: true},
      {:iconvex_extras, path: "../iconvex_extras", runtime: false},
      {:iconvex_telecom, path: "../iconvex_telecom", runtime: false},
      {:iconvex_specs_icu_archive_a,
       path: "../iconvex_specs_icu_archive_a", runtime: false, override: true},
      {:iconvex_specs_icu_archive_b,
       path: "../iconvex_specs_icu_archive_b", runtime: false, override: true},
      {:iconvex_specs_icu_archive_c,
       path: "../iconvex_specs_icu_archive_c", runtime: false, override: true},
      {:iconvex_specs, path: "../iconvex_specs", runtime: false}
    ]
  end
end
