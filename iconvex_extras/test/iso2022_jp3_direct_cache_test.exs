defmodule Iconvex.Extras.ISO2022JP3DirectCacheTest do
  use ExUnit.Case, async: false

  @cache_key {Iconvex.StatefulPairCache, :euc_jisx0213_planes, 1}
  @integrity_key {Iconvex.StatefulPairCache, :integrity, :euc_jisx0213_planes, 1}
  @fixtures Path.expand("fixtures", __DIR__)

  test "Extras startup leaves JP3 direct tables lazy until first conversion" do
    previous = :persistent_term.get(@cache_key, :missing)
    previous_integrity = :persistent_term.get(@integrity_key, :missing)

    on_exit(fn ->
      Application.ensure_all_started(:iconvex_extras)
      restore(@cache_key, previous)
      restore(@integrity_key, previous_integrity)
    end)

    assert :ok = Application.stop(:iconvex_extras)
    :persistent_term.erase(@cache_key)
    :persistent_term.erase(@integrity_key)

    assert {:ok, _started} = Application.ensure_all_started(:iconvex_extras)
    assert :persistent_term.get(@cache_key, :missing) == :missing
    assert :persistent_term.get(@integrity_key, :missing) == :missing

    encoded = File.read!(Path.join(@fixtures, "ISO-2022-JP-3-snippet"))
    utf8 = File.read!(Path.join(@fixtures, "ISO-2022-JP-3-snippet.UTF-8"))
    expected = :unicode.characters_to_binary(utf8, :utf8, {:utf32, :big})

    assert Iconvex.convert!(encoded, "ISO-2022-JP-3", "UCS-4BE", invalid: :discard) ==
             expected

    assert_cache_bound_to_current_table()
  end

  test "a stale dense descriptor is rebuilt from the current table source" do
    previous = :persistent_term.get(@cache_key, :missing)
    previous_integrity = :persistent_term.get(@integrity_key, :missing)

    on_exit(fn ->
      case previous do
        :missing -> :persistent_term.erase(@cache_key)
        value -> :persistent_term.put(@cache_key, value)
      end

      case previous_integrity do
        :missing -> :persistent_term.erase(@integrity_key)
        value -> :persistent_term.put(@integrity_key, value)
      end
    end)

    {_table, current_identity} =
      Iconvex.Tables.fetch_with_identity!(%{id: :euc_jisx0213})

    stale_identity = make_ref()
    stale_witness = make_ref()
    empty_plane = List.duplicate(nil, 94 * 94) |> List.to_tuple()

    :persistent_term.put(
      @cache_key,
      {1, :euc_jisx0213_planes, stale_identity, {empty_plane, empty_plane}, stale_witness}
    )

    :persistent_term.put(
      @integrity_key,
      {1, :euc_jisx0213_planes, stale_identity, stale_witness}
    )

    encoded = File.read!(Path.join(@fixtures, "ISO-2022-JP-3-snippet"))
    utf8 = File.read!(Path.join(@fixtures, "ISO-2022-JP-3-snippet.UTF-8"))
    expected = :unicode.characters_to_binary(utf8, :utf8, {:utf32, :big})

    assert Iconvex.convert!(encoded, "ISO-2022-JP-3", "UCS-4BE", invalid: :discard) ==
             expected

    assert current_identity != stale_identity
    assert_cache_bound_to_current_table()
  end

  test "application restart restores provider and codec while direct tables remain lazy" do
    previous = :persistent_term.get(@cache_key, :missing)
    previous_integrity = :persistent_term.get(@integrity_key, :missing)

    on_exit(fn ->
      Application.ensure_all_started(:iconvex_extras)
      restore(@cache_key, previous)
      restore(@integrity_key, previous_integrity)
    end)

    assert :ok = Application.stop(:iconvex_extras)
    :persistent_term.erase(@cache_key)
    :persistent_term.erase(@integrity_key)

    assert {:ok, _started} = Application.ensure_all_started(:iconvex_extras)
    assert :persistent_term.get(@cache_key, :missing) == :missing
    assert :persistent_term.get(@integrity_key, :missing) == :missing

    encoded = File.read!(Path.join(@fixtures, "ISO-2022-JP-3-snippet"))
    utf8 = File.read!(Path.join(@fixtures, "ISO-2022-JP-3-snippet.UTF-8"))

    assert Iconvex.convert!(encoded, "ISO-2022-JP-3", "UTF-8") == utf8
    assert Iconvex.convert!(utf8, "UTF-8", "ISO-2022-JP-3") == encoded

    expected = :unicode.characters_to_binary(utf8, :utf8, {:utf32, :little})

    assert Iconvex.convert!(encoded, "ISO-2022-JP-3", "UCS-4LE", invalid: :discard) ==
             expected

    assert_cache_bound_to_current_table()
  end

  defp assert_cache_bound_to_current_table do
    {table, identity} = Iconvex.Tables.fetch_with_identity!(%{id: :euc_jisx0213})

    assert is_map(table.many)
    assert is_reference(identity)

    assert {1, :euc_jisx0213_planes, ^identity, {plane1, plane2}, witness} =
             :persistent_term.get(@cache_key)

    assert {1, :euc_jisx0213_planes, ^identity, ^witness} =
             :persistent_term.get(@integrity_key)

    assert is_reference(witness)
    assert tuple_size(plane1) == 94 * 94
    assert tuple_size(plane2) == 94 * 94
  end

  defp restore(key, :missing), do: :persistent_term.erase(key)
  defp restore(key, value), do: :persistent_term.put(key, value)
end
