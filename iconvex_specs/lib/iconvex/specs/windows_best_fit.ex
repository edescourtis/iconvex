defmodule Iconvex.Specs.WindowsBestFit do
  @moduledoc "Pinned Microsoft directional best-fit converter profiles from Unicode."

  @manifest_path Path.expand("../../../priv/windows_best_fit_manifest.etf", __DIR__)
  @external_resource @manifest_path
  @manifest @manifest_path |> File.read!() |> :erlang.binary_to_term()

  def aggregate_sha256, do: @manifest.aggregate_sha256
  def codecs, do: Iconvex.Specs.WindowsBestFit.Codecs.modules()
  def encodings, do: @manifest.encodings
  def source_root_url, do: @manifest.source_root_url
end
