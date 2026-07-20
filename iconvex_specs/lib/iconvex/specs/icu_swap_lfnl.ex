defmodule Iconvex.Specs.ICUSwapLFNL do
  @moduledoc "Pinned ICU S/390 `swaplfnl` EBCDIC converter variants."

  @manifest_path Path.expand("../../../priv/icu_swap_lfnl_manifest.etf", __DIR__)
  @external_resource @manifest_path
  @manifest @manifest_path |> File.read!() |> :erlang.binary_to_term()

  def aggregate_sha256, do: @manifest.aggregate_sha256
  def codecs, do: Iconvex.Specs.ICUSwapLFNL.Codecs.modules()
  def encodings, do: @manifest.encodings
  def release, do: @manifest.release
  def revision, do: @manifest.revision
  def source_url, do: @manifest.source_url
end
