defmodule Iconvex.Specs.UnicodeMisc do
  @moduledoc "Pinned Unicode mapping-archive codecs not supplied by other Iconvex packages."

  @manifest_path Path.expand("../../../priv/unicode_misc_manifest.etf", __DIR__)
  @external_resource @manifest_path
  @manifest @manifest_path |> File.read!() |> :erlang.binary_to_term()

  def aggregate_sha256, do: @manifest.aggregate_sha256
  def codecs, do: Iconvex.Specs.UnicodeMisc.Codecs.modules()
  def encodings, do: @manifest.encodings
end
