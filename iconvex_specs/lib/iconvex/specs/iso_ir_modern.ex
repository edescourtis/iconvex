defmodule Iconvex.Specs.ISOIRModern do
  @moduledoc "Modern coded character sets pinned from official ISO-IR registration sheets."

  @manifest_path Path.expand("../../../priv/iso_ir_modern_manifest.etf", __DIR__)
  @external_resource @manifest_path
  @manifest @manifest_path |> File.read!() |> :erlang.binary_to_term()

  def aggregate_sha256, do: @manifest.aggregate_sha256
  def auxiliary_sources, do: @manifest.auxiliary_sources
  def codecs, do: Iconvex.Specs.ISOIRModern.Codecs.modules()
  def encodings, do: @manifest.encodings
end
