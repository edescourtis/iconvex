defmodule Iconvex.Specs.UnicodeLegacyMappings do
  @moduledoc "Pinned standalone coded-set mappings from Unicode's legacy archive."

  @manifest_path Path.expand("../../../priv/unicode_legacy_manifest.etf", __DIR__)
  @external_resource @manifest_path
  @manifest @manifest_path |> File.read!() |> :erlang.binary_to_term()

  def aggregate_sha256, do: @manifest.aggregate_sha256
  def codecs, do: Iconvex.Specs.UnicodeLegacyMappings.Codecs.modules()
  def encodings, do: @manifest.encodings
end
