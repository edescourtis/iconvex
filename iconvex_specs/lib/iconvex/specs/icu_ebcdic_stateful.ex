defmodule Iconvex.Specs.ICUEBCDICStateful do
  @moduledoc "Pinned ICU mixed-width EBCDIC codecs with native Elixir SI/SO state."

  @manifest_path Path.expand("../../../priv/icu_ebcdic_stateful_manifest.etf", __DIR__)
  @external_resource @manifest_path
  @manifest @manifest_path |> File.read!() |> :erlang.binary_to_term()

  def aggregate_sha256, do: @manifest.aggregate_sha256
  def codecs, do: Iconvex.Specs.ICUEBCDICStateful.Codecs.modules()
  def encodings, do: @manifest.encodings
  def release, do: @manifest.release
  def revision, do: @manifest.revision
  def source_url, do: @manifest.source_url
end
