defmodule Iconvex.StatefulLazyStartTest do
  use ExUnit.Case, async: false

  alias Iconvex.{ISO2022CNEncoder, ISO2022JPEncoder, StatefulPairCache}

  test "RED: core application startup leaves stateful direct tables lazy" do
    previous = direct_cache_entries()

    on_exit(fn ->
      Application.ensure_all_started(:iconvex)
      erase_direct_cache_entries()
      Enum.each(previous, fn {key, value} -> :persistent_term.put(key, value) end)
    end)

    assert :ok = Application.stop(:iconvex)
    erase_direct_cache_entries()

    assert {:ok, _started} = Application.ensure_all_started(:iconvex)
    assert direct_cache_entries() == []
  end

  defp erase_direct_cache_entries do
    Enum.each(direct_cache_entries(), fn {key, _value} -> :persistent_term.erase(key) end)
  end

  defp direct_cache_entries do
    Enum.filter(:persistent_term.get(), fn {key, _value} -> direct_cache_key?(key) end)
  end

  defp direct_cache_key?({StatefulPairCache, _id, _schema}), do: true
  defp direct_cache_key?({StatefulPairCache, :integrity, _id, _schema}), do: true

  defp direct_cache_key?({{module, :dispatch}, _version, _variant})
       when module in [ISO2022JPEncoder, ISO2022CNEncoder],
       do: true

  defp direct_cache_key?(_key), do: false
end
