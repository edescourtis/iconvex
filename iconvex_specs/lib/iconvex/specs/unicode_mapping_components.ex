defmodule Iconvex.Specs.UnicodeMappingComponents do
  @moduledoc "Pinned separately framed components from Unicode mapping tables."

  @manifest_path Path.expand("../../../priv/unicode_mapping_components_manifest.etf", __DIR__)
  @external_resource @manifest_path
  @manifest @manifest_path |> File.read!() |> :erlang.binary_to_term()

  def aggregate_sha256, do: @manifest.aggregate_sha256
  def codecs, do: Iconvex.Specs.UnicodeMappingComponents.Codecs.modules()
  def encodings, do: @manifest.encodings
end
