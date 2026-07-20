defmodule Iconvex.Specs.RuntimeAssetCacheTest do
  use ExUnit.Case, async: false

  alias Iconvex.Specs.RuntimeAsset

  defmodule StaleOwner do
  end

  defmodule ConcurrentOwner do
  end

  defmodule UnsafeOwner do
  end

  @runtime_owners [
    Iconvex.Specs.ICUCompoundText.Data,
    Iconvex.Specs.ICUJIS.Data,
    Iconvex.Specs.ICULMBCS1.Data,
    Iconvex.Specs.ISCII.Data,
    Iconvex.Specs.MARC8.Data
  ]

  setup do
    owners = [StaleOwner, ConcurrentOwner, UnsafeOwner | @runtime_owners]

    Enum.each(owners, fn owner ->
      if Code.ensure_loaded?(RuntimeAsset) do
        :persistent_term.erase(RuntimeAsset.cache_key(owner))
      end
    end)

    on_exit(fn ->
      Enum.each(owners, fn owner ->
        if Code.ensure_loaded?(RuntimeAsset) do
          :persistent_term.erase(RuntimeAsset.cache_key(owner))
        end
      end)
    end)

    :ok
  end

  test "safe decoding rejects an ETF atom that is not already interned" do
    atom_name = "iconvex_specs_untrusted_atom_#{System.unique_integer([:positive])}"
    assert_raise ArgumentError, fn -> String.to_existing_atom(atom_name) end

    path = temporary_path("unsafe.etf")
    File.write!(path, <<131, 119, byte_size(atom_name), atom_name::binary>>)
    on_exit(fn -> File.rm(path) end)

    assert_raise ArgumentError, fn -> RuntimeAsset.fetch(UnsafeOwner, path) end
    assert_raise ArgumentError, fn -> String.to_existing_atom(atom_name) end
  end

  test "a stale cache schema/version is isolated and replaced" do
    path = temporary_path("stale.etf")
    expected = %{decode: %{?A => ?A}}
    File.write!(path, :erlang.term_to_binary(expected))
    on_exit(fn -> File.rm(path) end)

    key = RuntimeAsset.cache_key(StaleOwner)
    :persistent_term.put(key, {1, {1, ~c"stale"}, :stale})

    assert RuntimeAsset.fetch(StaleOwner, path) == expected
    assert {1, version, ^expected} = :persistent_term.get(key)
    assert version == RuntimeAsset.cache_version()

    :persistent_term.put(key, :legacy_unversioned_value)
    assert RuntimeAsset.fetch(StaleOwner, path) == expected
    assert {1, ^version, ^expected} = :persistent_term.get(key)
  end

  test "concurrent cold fetches execute and publish one load" do
    counter = :atomics.new(1, [])
    version = {RuntimeAsset.cache_version(), :concurrent_contract}

    results =
      1..64
      |> Task.async_stream(
        fn _ ->
          RuntimeAsset.fetch_with(ConcurrentOwner, version, fn ->
            :atomics.add_get(counter, 1, 1)
            Process.sleep(10)
            %{loaded_by: self()}
          end)
        end,
        max_concurrency: 64,
        ordered: false,
        timeout: 30_000
      )
      |> Enum.map(fn {:ok, result} -> result end)

    assert :atomics.get(counter, 1) == 1
    assert length(Enum.uniq(results)) == 1
    assert {1, ^version, result} = :persistent_term.get(RuntimeAsset.cache_key(ConcurrentOwner))
    assert result == hd(results)
  end

  test "all five migrated runtime assets retain representative codec behavior" do
    assert Iconvex.Specs.ICUCompoundText.encode([?A]) == {:ok, <<?A>>}
    assert Iconvex.Specs.ICUJIS.encode(:jis7, [?A]) == {:ok, <<?A>>}
    assert Iconvex.Specs.ICULMBCS1.encode([?A]) == {:ok, <<?A>>}
    assert Iconvex.Specs.ISCII.decode("ISCII-91", <<?A>>) == {:ok, [?A]}
    assert Iconvex.Specs.MARC8.decode(<<?A>>) == {:ok, [?A]}
  end

  defp temporary_path(suffix) do
    Path.join(
      System.tmp_dir!(),
      "iconvex-specs-runtime-asset-#{System.unique_integer([:positive])}-#{suffix}"
    )
  end
end
