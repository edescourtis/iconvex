defmodule Iconvex.Specs.GlibcCharmaps do
  @moduledoc "Pinned glibc charmaps for public-standard codecs absent from GNU libiconv."

  @path Path.expand("../../../priv/glibc_charmaps_manifest.etf", __DIR__)
  @external_resource @path
  @manifest @path |> File.read!() |> :erlang.binary_to_term()

  def encodings, do: @manifest.encodings
  def revision, do: @manifest.revision
  def sources, do: @manifest.sources

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
    with {:ok, entry} <- resolve(name), do: Iconvex.Specs.CodecSupport.decode(entry.id, input)
  end

  def encode(name, codepoints) do
    with {:ok, entry} <- resolve(name),
         do: Iconvex.Specs.CodecSupport.encode(entry.id, codepoints)
  end
end
