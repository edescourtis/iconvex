defmodule Iconvex.Specs.ICUUCM do
  @moduledoc "Pinned ICU UCM converter mappings supplied as native Elixir table codecs."

  @manifest_path Path.expand("../../../priv/icu_ucm_manifest.etf", __DIR__)
  @external_resource @manifest_path
  @manifest @manifest_path |> File.read!() |> :erlang.binary_to_term()

  def aggregate_sha256, do: @manifest.aggregate_sha256
  def codecs, do: Iconvex.Specs.ICUUCM.Codecs.modules()
  def encodings, do: @manifest.encodings
  def release, do: @manifest.release
  def revision, do: @manifest.revision
  def source_url, do: @manifest.source_url
end
