defmodule Iconvex.Specs.ISOIRCNS11643 do
  @moduledoc "CNS 11643-1992 planes registered as ISO-IR 171/172/183–187."

  @manifest_path Path.expand("../../../priv/iso_ir_cns11643_manifest.etf", __DIR__)
  @external_resource @manifest_path
  @manifest @manifest_path |> File.read!() |> :erlang.binary_to_term()

  def encodings, do: @manifest.encodings
  def mapping_sha256, do: @manifest.mapping_sha256
  def mapping_url, do: @manifest.mapping_url
end
