defmodule Iconvex.Specs.RuntimeAsset do
  @moduledoc false

  @cache_schema 1

  # `binary_to_term(..., [:safe])` may only decode atoms that already exist in
  # the VM. These are the complete, finite schema atoms used by the seven lazy
  # runtime assets. Keeping them as literals makes the first load safe even in a
  # genuinely cold VM.
  @schema_atoms [
    MapSet,
    :__struct__,
    :aliases,
    :alternate,
    :alternates,
    :ansel,
    :ascii,
    :basic_arabic,
    :basic_cyrillic,
    :basic_greek,
    :basic_hebrew,
    :bytes,
    :candidates,
    :canonical,
    :character_sets,
    :classification,
    :codepoint,
    :codepoints,
    :combining,
    :combining_mappings,
    :control,
    :controls,
    :coverage,
    :cp5022x,
    :custom,
    :decode,
    :decode0208,
    :decode0212,
    :decode_cns,
    :decode_gb,
    :eacc,
    :encode,
    :encode_cns,
    :encode_gb,
    :encoding,
    :encodings,
    :entries,
    :escapes,
    :extended_arabic,
    :extended_cyrillic,
    false,
    :final,
    :fixture_source,
    :format,
    :g0,
    :g1,
    :gb,
    :greek,
    :greek_symbols,
    :groups,
    :id,
    :invocation,
    :jis0208,
    :jis0212,
    :jis208,
    :jis212,
    :kind,
    :ksc,
    :lookup_bytes,
    :map,
    :max_bytes,
    :max_codepoints,
    :max_input,
    :msiso2022jp,
    :name,
    nil,
    :oracle_vectors,
    :preferred,
    :prefixes,
    :primary,
    :primary_mappings,
    :ranges,
    :rank,
    :reserved_escape,
    :reserved_escape_mappings,
    :second_half,
    :second_half_markers,
    :set,
    :sets,
    :sha256,
    :source,
    :span_codepoint,
    :states,
    :subscripts,
    :superscripts,
    true,
    :url,
    :version,
    :versions,
    :width
  ]

  @spec fetch(module(), Path.t()) :: term()
  def fetch(owner, path) when is_atom(owner) and is_binary(path) do
    fetch_with(owner, cache_version(), fn ->
      Enum.each(@schema_atoms, &:erlang.atom_to_binary/1)
      path |> File.read!() |> :erlang.binary_to_term([:safe])
    end)
  end

  @doc false
  @spec fetch_with(module(), term(), (-> term())) :: term()
  def fetch_with(owner, version, loader) when is_atom(owner) and is_function(loader, 0) do
    key = cache_key(owner)

    case :persistent_term.get(key, :missing) do
      {@cache_schema, ^version, value} ->
        value

      _missing_or_stale ->
        :global.trans({{__MODULE__, owner}, self()}, fn ->
          load_if_stale(key, version, loader)
        end)
    end
  end

  @doc false
  @spec cache_key(module()) :: tuple()
  def cache_key(owner) when is_atom(owner), do: {owner, :data}

  @doc false
  @spec cache_version() :: tuple()
  def cache_version do
    {@cache_schema, Application.spec(:iconvex_specs, :vsn) || ~c"unloaded"}
  end

  defp load_if_stale(key, version, loader) do
    case :persistent_term.get(key, :missing) do
      {@cache_schema, ^version, value} ->
        value

      _missing_or_stale ->
        value = loader.()
        :persistent_term.put(key, {@cache_schema, version, value})
        value
    end
  end
end
