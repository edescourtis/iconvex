defmodule Iconvex.Specs.ICUArchive do
  @moduledoc "Pinned historical ICU data-repository UCM revisions as native Elixir codecs."

  @manifest_path Path.expand("../../../priv/icu_archive_manifest.etf", __DIR__)
  @external_resource @manifest_path
  @manifest @manifest_path |> File.read!() |> :erlang.binary_to_term()

  def aggregate_sha256, do: @manifest.aggregate_sha256
  def codecs, do: Iconvex.Specs.ICUArchive.Codecs.modules()
  def encodings, do: @manifest.encodings
  def revision, do: @manifest.revision
  def source_url, do: @manifest.source_url
end
