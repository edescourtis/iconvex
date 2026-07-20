defmodule Iconvex.Specs.VendorMappings do
  @moduledoc "Unicode-hosted Adobe and Apple legacy encoding maps."

  @manifest_path Path.expand("../../../priv/vendor_mappings_manifest.etf", __DIR__)
  @external_resource @manifest_path
  @manifest @manifest_path |> File.read!() |> :erlang.binary_to_term()
  @encodings @manifest.encodings

  @by_name Enum.reduce(@encodings, %{}, fn entry, acc ->
             Enum.reduce([entry.name | entry.aliases], acc, fn name, names ->
               Map.put_new(names, String.upcase(name, :ascii), entry)
             end)
           end)

  def documentation_sources, do: @manifest.documentation_sources
  def encodings, do: @encodings
  def exclusions, do: @manifest.exclusions
  def sources, do: @manifest.sources

  def coverage_summary do
    %{
      codecs: length(@encodings),
      decode_mappings: Enum.sum(Enum.map(@encodings, & &1.decode_mappings)),
      encode_mappings: Enum.sum(Enum.map(@encodings, & &1.encode_mappings)),
      mapping_rows: Enum.sum(Enum.map(@encodings, & &1.mapping_rows)),
      vendors: Enum.frequencies_by(@encodings, & &1.vendor)
    }
  end

  def resolve(name) when is_binary(name), do: Map.fetch(@by_name, String.upcase(name, :ascii))
  def resolve(_name), do: :error

  def decode(name, input) when is_binary(input) do
    with {:ok, entry} <- resolve(name) do
      Iconvex.Specs.CodecSupport.decode(entry.id, input)
    end
  end

  def encode(name, codepoints) when is_list(codepoints) do
    with {:ok, entry} <- resolve(name) do
      Iconvex.Specs.CodecSupport.encode(entry.id, codepoints)
    end
  end
end
