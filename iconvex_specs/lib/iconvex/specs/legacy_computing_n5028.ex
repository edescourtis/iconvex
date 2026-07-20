defmodule Iconvex.Specs.LegacyComputingN5028 do
  @moduledoc """
  Complete mapping attachment set from Unicode/WG2 N5028 (L2/19-025).

  Seventy distinct mappings preserve video-memory versus interchange order,
  primary versus alternate character generators, national variants, holes,
  multi-byte cells, and multi-codepoint Unicode mappings.
  """

  @manifest_path Path.expand("../../../priv/legacy_computing_n5028_manifest.etf", __DIR__)
  @external_resource @manifest_path
  @manifest @manifest_path |> File.read!() |> :erlang.binary_to_term()

  def attachment_count, do: @manifest.attachment_count
  def document, do: @manifest.document
  def entries, do: @manifest.encodings
  def encodings, do: Enum.map(@manifest.encodings, & &1.name)
  def mapping_aggregate_sha256, do: @manifest.mapping_aggregate_sha256
  def proposal_sha256, do: @manifest.proposal_sha256
  def proposal_url, do: @manifest.proposal_url
  def sources, do: @manifest.sources

  def codecs, do: Iconvex.Specs.LegacyComputingN5028.Codecs.modules()

  def codec(entry),
    do: Module.concat(Iconvex.Specs.LegacyComputingN5028.Codecs, "C#{entry.index}")

  def resolve(name) when is_binary(name) do
    normalized = String.upcase(name, :ascii)

    case Enum.find(@manifest.encodings, fn entry ->
           Enum.any?([entry.name | entry.aliases], &(String.upcase(&1, :ascii) == normalized))
         end) do
      nil -> :error
      entry -> {:ok, entry}
    end
  end

  def decode(name, input) do
    with {:ok, entry} <- resolve(name), do: codec(entry).decode(input)
  end

  def encode(name, codepoints) do
    with {:ok, entry} <- resolve(name), do: codec(entry).encode(codepoints)
  end
end
