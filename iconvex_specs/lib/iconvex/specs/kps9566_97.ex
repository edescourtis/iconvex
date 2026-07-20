defmodule Iconvex.Specs.KPS956697 do
  @moduledoc "Audited KPS 9566-97 / ISO-IR-202 mapping and transport codecs."

  @manifest_path Path.expand("../../../priv/kps9566_97_manifest.etf", __DIR__)
  @external_resource @manifest_path
  @manifest @manifest_path |> File.read!() |> :erlang.binary_to_term()

  def codecs, do: Iconvex.Specs.KPS956697.Codecs.modules()
  def encodings, do: @manifest.encodings
  def manifest, do: @manifest
end
