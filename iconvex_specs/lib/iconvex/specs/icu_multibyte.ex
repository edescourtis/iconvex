defmodule Iconvex.Specs.ICUMultibyte do
  @moduledoc "Pinned ICU UCM multibyte mapping codecs implemented by native Elixir tables."

  @manifest_path Path.expand("../../../priv/icu_multibyte_manifest.etf", __DIR__)
  @external_resource @manifest_path
  @manifest @manifest_path |> File.read!() |> :erlang.binary_to_term()

  def aggregate_sha256, do: @manifest.aggregate_sha256
  def codecs, do: Iconvex.Specs.ICUMultibyte.Codecs.modules()
  def encodings, do: @manifest.encodings
  def exclusions, do: @manifest.exclusions
  def release, do: @manifest.release
  def revision, do: @manifest.revision
  def source_url, do: @manifest.source_url
end
