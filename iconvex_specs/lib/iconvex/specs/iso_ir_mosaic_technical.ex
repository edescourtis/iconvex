defmodule Iconvex.Specs.ISOIRMosaicTechnical do
  @moduledoc "ISO-IR mosaic and electro-technical graphic-set codecs."

  @manifest_path Path.expand("../../../priv/iso_ir_mosaic_technical_manifest.etf", __DIR__)
  @external_resource @manifest_path
  @manifest @manifest_path |> File.read!() |> :erlang.binary_to_term()

  def encodings, do: @manifest.encodings
  def manifest, do: @manifest
end
