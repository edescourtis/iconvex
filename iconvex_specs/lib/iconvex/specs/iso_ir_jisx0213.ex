defmodule Iconvex.Specs.ISOIRJISX0213 do
  @moduledoc "JIS X 0213:2000/2004 planes registered as ISO-IR 228, 229, and 233."

  @manifest_path Path.expand("../../../priv/iso_ir_jisx0213_manifest.etf", __DIR__)
  @external_resource @manifest_path
  @manifest @manifest_path |> File.read!() |> :erlang.binary_to_term()

  def encodings, do: @manifest.encodings
  def manifest, do: @manifest
end
