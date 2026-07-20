defmodule Iconvex.Specs.IANAPCLSymbolSets do
  @moduledoc "IANA-registered HP PCL symbol-set codecs from pinned public mappings."

  @manifest_path Path.expand("../../../priv/iana_pcl_symbol_sets_manifest.etf", __DIR__)
  @external_resource @manifest_path
  @manifest @manifest_path |> File.read!() |> :erlang.binary_to_term()

  def encodings, do: @manifest.encodings
  def source_commit, do: @manifest.source_commit
  def source_sha256, do: @manifest.source_sha256
  def normalized_sha256, do: @manifest.normalized_sha256
  def source_url, do: @manifest.source_url
end
