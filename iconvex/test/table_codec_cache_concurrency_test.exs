defmodule Iconvex.TableCodecCacheConcurrencyTest do
  use ExUnit.Case, async: false

  alias Iconvex.{TableCodec, Tables}

  @workers 24
  @cache_schema {:iconvex_table_decode_cache, 2}
  @dense_cache_kind {:dense_two_byte, 65_536, 1}
  @trie_cache_kind {:variable_width_trie, 256, 1}

  test "RED: concurrent cold dense and trie cache users build once per key" do
    for cache <- cache_cases() do
      assert_single_concurrent_build(cache, :cold)
    end
  end

  test "RED: concurrent stale-source dense and trie cache users rebuild once per key" do
    for cache <- cache_cases() do
      assert_single_concurrent_build(cache, :stale)
    end
  end

  test "RED: same-source malformed dense and trie cache values are rebuilt" do
    for cache <- cache_cases() do
      with_restored_cache(cache, fn key, table, bytes ->
        {^table, table_identity} = Tables.fetch_with_identity!(cache.entry)
        poison_size = if cache.kind == :dense, do: 65_536, else: 256
        poison = Tuple.duplicate(:poison, poison_size)

        :persistent_term.put(
          key,
          {@cache_schema, cache_kind(cache.kind), table_identity, poison}
        )

        assert TableCodec.decode_to_explicit_ucs4_discard(cache.entry, bytes, :big) ==
                 {:ok, expected_word(table, bytes)}

        assert {@cache_schema, cache_kind, source, artifact} = :persistent_term.get(key)
        assert cache_kind == cache_kind(cache.kind)
        assert source === table_identity
        assert valid_artifact?(cache.kind, artifact)
      end)
    end
  end

  test "dense cache repair abandons a partially written binary accumulator" do
    cache = hd(cache_cases())

    with_restored_cache(cache, fn key, table, _bytes ->
      [{first_bytes, {first_codepoint}}, {second_bytes, {second_codepoint}} | _rest] =
        Enum.filter(table.many, fn {_bytes, value} -> tuple_size(value) == 1 end)

      assert {:ok, _warm_output} =
               TableCodec.decode_to_explicit_ucs4_discard(cache.entry, first_bytes, :big)

      {@cache_schema, @dense_cache_kind, source, dense} = :persistent_term.get(key)
      <<first, second>> = second_bytes
      poisoned = put_elem(dense, first * 0x100 + second, {second_codepoint, :poison})
      :persistent_term.put(key, {@cache_schema, @dense_cache_kind, source, poisoned})

      assert TableCodec.decode_to_explicit_ucs4_discard(
               cache.entry,
               first_bytes <> second_bytes,
               :big
             ) == {:ok, <<first_codepoint::unsigned-big-32, second_codepoint::unsigned-big-32>>}

      assert {@cache_schema, @dense_cache_kind, ^source, repaired} = :persistent_term.get(key)
      refute repaired === poisoned
    end)
  end

  test "warm source-valid dense and trie cache hits do not acquire global locks" do
    for cache <- cache_cases() do
      with_restored_cache(cache, fn _key, table, bytes ->
        assert {:ok, _output} =
                 TableCodec.decode_to_explicit_ucs4_discard(cache.entry, bytes, :big)

        assert_no_global_transaction(fn ->
          assert TableCodec.decode_to_explicit_ucs4_discard(cache.entry, bytes, :big) ==
                   {:ok, expected_word(table, bytes)}
        end)
      end)
    end
  end

  test "RED: warm cache validity uses constant-size table generation tokens" do
    for cache <- cache_cases() do
      with_restored_cache(cache, fn key, _table, bytes ->
        assert {:ok, _output} =
                 TableCodec.decode_to_explicit_ucs4_discard(cache.entry, bytes, :big)

        assert {@cache_schema, cache_kind, source_token, artifact} =
                 :persistent_term.get(key)

        assert cache_kind == cache_kind(cache.kind)
        assert is_reference(source_token)
        assert valid_artifact?(cache.kind, artifact)
      end)
    end
  end

  defp assert_single_concurrent_build(cache, state) do
    with_restored_cache(cache, fn key, table, bytes ->
      case state do
        :cold -> :persistent_term.erase(key)
        :stale -> :persistent_term.put(key, {%{}, :unsupported})
      end

      Code.ensure_loaded!(TableCodec)
      mfa = {TableCodec, cache.builder, 1}
      :erlang.trace_pattern(mfa, true, [:local, :call_count])

      try do
        results =
          concurrent_calls(fn ->
            TableCodec.decode_to_explicit_ucs4_discard(cache.entry, bytes, :big)
          end)

        expected = {:ok, expected_word(table, bytes)}
        assert Enum.all?(results, &(&1 == expected))
        assert :erlang.trace_info(mfa, :call_count) == {:call_count, 1}

        assert {@cache_schema, cache_kind, source, artifact} = :persistent_term.get(key)
        assert cache_kind == cache_kind(cache.kind)
        assert is_reference(source)
        assert valid_artifact?(cache.kind, artifact)
      after
        :erlang.trace_pattern(mfa, false, [:local, :call_count])
      end
    end)
  end

  defp concurrent_calls(fun) do
    parent = self()

    tasks =
      for _index <- 1..@workers do
        Task.async(fn ->
          send(parent, {:cache_worker_ready, self()})

          receive do
            :run_cache_call -> fun.()
          end
        end)
      end

    workers =
      for _index <- 1..@workers do
        assert_receive {:cache_worker_ready, worker}, 5_000
        worker
      end

    Enum.each(workers, &send(&1, :run_cache_call))
    Enum.map(tasks, &Task.await(&1, 30_000))
  end

  defp with_restored_cache(cache, fun) do
    table = Tables.fetch!(cache.entry)

    {bytes, {_codepoint}} =
      Enum.find(table.many, fn {_bytes, value} -> tuple_size(value) == 1 end)

    key = {TableCodec, cache.tag, :iconvex, cache.entry.id, 1}
    previous = :persistent_term.get(key, :missing)

    try do
      fun.(key, table, bytes)
    after
      case previous do
        :missing -> :persistent_term.erase(key)
        value -> :persistent_term.put(key, value)
      end
    end
  end

  defp cache_cases do
    [
      %{
        kind: :dense,
        entry: %{id: :cp932},
        tag: :dense_two_byte_decode,
        builder: :build_dense_two_byte_decode
      },
      %{
        kind: :trie,
        entry: %{id: :cp1255},
        tag: :variable_width_decode_trie,
        builder: :build_variable_width_decode_trie
      }
    ]
  end

  defp expected_word(table, bytes) do
    {codepoint} = Map.fetch!(table.many, bytes)
    <<codepoint::unsigned-big-32>>
  end

  defp valid_artifact?(:dense, :unsupported), do: true
  defp valid_artifact?(:dense, tuple), do: is_tuple(tuple) and tuple_size(tuple) == 65_536
  defp valid_artifact?(:trie, :unsupported), do: true
  defp valid_artifact?(:trie, tuple), do: is_tuple(tuple) and tuple_size(tuple) == 256

  defp cache_kind(:dense), do: @dense_cache_kind
  defp cache_kind(:trie), do: @trie_cache_kind

  defp assert_no_global_transaction(fun) do
    mfa = {:global, :trans, 2}
    :erlang.trace_pattern(mfa, true, [])
    :erlang.trace(self(), true, [:call])

    try do
      fun.()
      delivered = :erlang.trace_delivered(self())
      assert_receive {:trace_delivered, _pid, ^delivered}, 5_000
      refute_receive {:trace, _pid, :call, {:global, :trans, _arguments}}, 0
    after
      :erlang.trace(self(), false, [:call])
      :erlang.trace_pattern(mfa, false, [])
    end
  end
end
