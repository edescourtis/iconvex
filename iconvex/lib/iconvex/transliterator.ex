defmodule Iconvex.Transliterator do
  @moduledoc false

  @key {__MODULE__, :mapping}
  @cache_schema 1

  def fetch(codepoint) do
    case Map.fetch(mapping(), codepoint) do
      {:ok, replacement} -> {:ok, replacement}
      :error -> :error
    end
  end

  defp mapping do
    version = {@cache_schema, Application.spec(:iconvex, :vsn) || ~c"unloaded"}

    case :persistent_term.get(@key, :missing) do
      {@cache_schema, ^version, mapping} ->
        mapping

      _missing_or_stale ->
        :global.trans({{__MODULE__, :mapping}, self()}, fn -> load_if_stale(version) end)
    end
  end

  defp load_if_stale(version) do
    case :persistent_term.get(@key, :missing) do
      {@cache_schema, ^version, mapping} ->
        mapping

      _missing_or_stale ->
        path = :iconvex |> :code.priv_dir() |> Path.join("translit.etf")
        mapping = path |> File.read!() |> :erlang.binary_to_term([:safe])
        :persistent_term.put(@key, {@cache_schema, version, mapping})
        mapping
    end
  end
end
