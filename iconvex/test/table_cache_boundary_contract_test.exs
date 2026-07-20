defmodule Iconvex.TableCacheBoundaryContractTest do
  use ExUnit.Case, async: false

  alias Iconvex.{TableCodec, Tables, UnicodeCodec}

  @conversion_cache_key {Tables, :conversion_cache}
  @sparse_cache_key {TableCodec, :vietnamese_sparse_two_byte_decode, :iconvex, :tcvn, 1}

  test "nested conversion caches share an untouched transaction and restore populated state" do
    assert Process.get(@conversion_cache_key, :missing) == :missing

    Tables.with_conversion_cache(fn ->
      empty = %{tables: %{}, versions: %{}}
      assert Process.get(@conversion_cache_key) == empty

      nested_identity =
        Tables.with_conversion_cache(fn ->
          assert Process.get(@conversion_cache_key) == empty
          {_table, identity} = Tables.fetch_with_identity!(%{id: :cp1252})
          identity
        end)

      populated = Process.get(@conversion_cache_key)

      assert %{
               tables: %{{:iconvex, :cp1252} => {_table, ^nested_identity}},
               versions: %{iconvex: _version}
             } = populated

      Tables.with_conversion_cache(fn ->
        assert Process.get(@conversion_cache_key) === populated
        {_table, ^nested_identity} = Tables.fetch_with_identity!(%{id: :cp1252})
      end)

      assert Process.get(@conversion_cache_key) === populated
    end)

    assert Process.get(@conversion_cache_key, :missing) == :missing

    caller_owned = {:caller_owned_process_state, make_ref()}
    Process.put(@conversion_cache_key, caller_owned)

    assert_raise RuntimeError, "isolated conversion failed", fn ->
      Tables.with_conversion_cache(fn ->
        assert Process.get(@conversion_cache_key) == %{tables: %{}, versions: %{}}
        {_table, identity} = Tables.fetch_with_identity!(%{id: :cp1252})
        assert is_reference(identity)
        raise "isolated conversion failed"
      end)
    end

    assert Process.delete(@conversion_cache_key) === caller_owned
  end

  test "Vietnamese composition codecs decline the single-byte UCS-4 shortcut without loading" do
    fetch = {Tables, :fetch!, 1}

    {results, calls} =
      count_calls([fetch], fn ->
        for id <- [:cp1258, :tcvn], endian <- [:big, :little] do
          TableCodec.decode_single_to_explicit_ucs4_discard(%{id: id}, <<?A>>, endian)
        end ++
          [TableCodec.decode_single_to_explicit_ucs4_discard(%{id: :cp1252}, <<?A>>, :middle)]
      end)

    assert results == [:miss, :miss, :miss, :miss, :miss]
    assert calls[fetch] == 0
  end

  test "Vietnamese sparse cache repairs corrupt selected leaves and lookahead rows" do
    entry = %{id: :tcvn}
    {table, table_identity} = Tables.fetch_with_identity!(entry)
    {bytes = <<lead, second>>, {_codepoint}} = Enum.at(table.many, 0)

    assert {:ok, _warm} = TableCodec.decode_to_explicit_ucs4_discard(entry, bytes, :big)
    previous = :persistent_term.get(@sparse_cache_key)
    on_exit(fn -> :persistent_term.put(@sparse_cache_key, previous) end)

    {schema, kind, ^table_identity, root} = previous

    plain =
      Enum.find(0..0xFF, fn byte ->
        elem(root, byte) == nil and
          match?({codepoint} when is_integer(codepoint), elem(table.one, byte))
      end)

    assert is_integer(plain)

    for endian <- [:big, :little] do
      selected_input = <<plain>> <> bytes <> <<plain>>

      assert_repaired_parity(entry, selected_input, endian, fn current_root ->
        row = elem(current_root, lead)
        put_elem(current_root, lead, put_elem(row, second, :corrupt_stored_codepoint))
      end)

      lookahead_input = <<plain>> <> bytes

      assert_repaired_parity(entry, lookahead_input, endian, fn current_root ->
        put_elem(current_root, lead, :corrupt_lookahead_row)
      end)
    end

    assert {^schema, ^kind, ^table_identity, repaired} =
             :persistent_term.get(@sparse_cache_key)

    assert is_tuple(repaired) and tuple_size(repaired) == 256
  end

  defp assert_repaired_parity(entry, input, endian, poison) do
    assert {:ok, codepoints} = TableCodec.decode_discard(entry, input)
    assert {:ok, expected} = UnicodeCodec.encode(%{id: ucs4_id(endian)}, codepoints)

    {schema, kind, table_identity, current_root} =
      :persistent_term.get(@sparse_cache_key)

    poisoned = poison.(current_root)
    :persistent_term.put(@sparse_cache_key, {schema, kind, table_identity, poisoned})

    assert TableCodec.decode_to_explicit_ucs4_discard(entry, input, endian) ==
             {:ok, expected}

    assert {^schema, ^kind, ^table_identity, repaired} =
             :persistent_term.get(@sparse_cache_key)

    refute repaired === poisoned
  end

  defp count_calls(mfas, function) do
    Enum.each(mfas, fn {module, _name, _arity} = mfa ->
      Code.ensure_loaded!(module)
      :erlang.trace_pattern(mfa, true, [:local, :call_count])
    end)

    try do
      result = function.()

      calls =
        Map.new(mfas, fn mfa ->
          {:call_count, count} = :erlang.trace_info(mfa, :call_count)
          {mfa, count}
        end)

      {result, calls}
    after
      Enum.each(mfas, &:erlang.trace_pattern(&1, false, [:local, :call_count]))
    end
  end

  defp ucs4_id(:big), do: :ucs4be
  defp ucs4_id(:little), do: :ucs4le
end
