defmodule Iconvex.Specs.RFC1345 do
  @moduledoc "RFC 1345 coded character sets imported from the pinned RFC source."

  @manifest_path Path.expand("../../../priv/rfc1345_manifest.etf", __DIR__)
  @external_resource @manifest_path
  @manifest @manifest_path |> File.read!() |> :erlang.binary_to_term()
  @encodings @manifest.encodings

  @by_name Enum.reduce(@encodings, %{}, fn entry, acc ->
             Enum.reduce([entry.name | entry.aliases], acc, fn name, names ->
               Map.put_new(names, String.upcase(name, :ascii), entry)
             end)
           end)

  def source, do: @manifest.source
  def errata_source, do: Map.fetch!(@manifest, :errata_source)
  def mapping_sources, do: Map.fetch!(@manifest, :mapping_sources)
  def encodings, do: @encodings

  def coverage_summary do
    %{
      charsets: length(@encodings),
      combining_mappings: Enum.sum(Enum.map(@encodings, & &1.combinations)),
      complete_charsets: Enum.count(@encodings, &(&1.unresolved_spec_positions == 0)),
      decode_mappings: Enum.sum(Enum.map(@encodings, & &1.decode_mappings)),
      intentional_undefined_positions:
        Enum.sum(Enum.map(@encodings, & &1.intentional_undefined_positions)),
      partial_charsets: Enum.count(@encodings, &(&1.unresolved_spec_positions > 0)),
      unresolved_spec_positions: Enum.sum(Enum.map(@encodings, & &1.unresolved_spec_positions))
    }
  end

  def resolve(name) when is_binary(name) do
    Map.fetch(@by_name, String.upcase(name, :ascii))
  end

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
