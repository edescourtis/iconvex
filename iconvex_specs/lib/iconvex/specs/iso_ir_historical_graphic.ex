defmodule Iconvex.Specs.ISOIRHistoricalGraphic do
  @moduledoc "Historical ISO-IR graphic-set codecs with audited Unicode mappings."

  @manifest_path Path.expand("../../../priv/iso_ir_historical_graphic_manifest.etf", __DIR__)
  @external_resource @manifest_path
  @manifest @manifest_path |> File.read!() |> :erlang.binary_to_term()

  def encodings, do: @manifest.encodings
  def manifest, do: @manifest
end
