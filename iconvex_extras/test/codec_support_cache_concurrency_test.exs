defmodule Iconvex.Extras.CodecSupportCacheConcurrencyTest do
  use ExUnit.Case, async: false

  alias Iconvex.Extras.CodecSupport

  @workers 24
  @cache_key {CodecSupport, :cp943_decode_cache, 1}
  @cache_schema {:iconvex_extras_binary_cache, 1}
  @cache_kind {:cp943_dense_u32be, 65_536, 1}
  @cache_bytes 65_536 * 4

  test "RED: concurrent cold CodecSupport cache users share one built binary" do
    assert_single_concurrent_build(:cold)
  end

  test "RED: concurrent stale-source CodecSupport cache users share one rebuilt binary" do
    assert_single_concurrent_build(:stale)
  end

  test "RED: a same-source malformed CodecSupport cache value is rebuilt" do
    with_restored_cache(fn source ->
      {bytes, {codepoint}} = Enum.find(source, fn {_bytes, value} -> tuple_size(value) == 1 end)
      assert {:ok, []} = CodecSupport.decode_discard(:cp943, <<>>)

      assert {@cache_schema, @cache_kind, ^source, witness, _valid_binary} =
               :persistent_term.get(@cache_key)

      poison = :binary.copy(<<0xFF>>, @cache_bytes)

      :persistent_term.put(
        @cache_key,
        {@cache_schema, @cache_kind, source, witness, poison}
      )

      assert CodecSupport.decode_discard(:cp943, bytes) == {:ok, [codepoint]}

      assert {@cache_schema, @cache_kind, cached_source, repaired_witness, binary} =
               :persistent_term.get(@cache_key)

      assert cached_source === source
      assert repaired_witness == witness
      refute binary == poison
      assert byte_size(binary) == @cache_bytes
    end)
  end

  test "a warm source-valid CodecSupport cache hit does not acquire a global lock" do
    with_restored_cache(fn _source ->
      assert {:ok, []} = CodecSupport.decode_discard(:cp943, <<>>)

      assert_no_global_transaction(fn ->
        assert CodecSupport.decode_discard(:cp943, <<>>) == {:ok, []}
      end)
    end)
  end

  defp assert_single_concurrent_build(state) do
    with_restored_cache(fn source ->
      case state do
        :cold -> :persistent_term.erase(@cache_key)
        :stale -> :persistent_term.put(@cache_key, {%{}, <<0>>})
      end

      Code.ensure_loaded!(CodecSupport)
      mfa = {CodecSupport, :build_cached_binary, 3}
      :erlang.trace_pattern(mfa, true, [:local, :call_count])

      try do
        results = concurrent_cache_calls()
        assert Enum.all?(results, &(&1 == {:ok, []}))
        assert :erlang.trace_info(mfa, :call_count) == {:call_count, 1}
      after
        :erlang.trace_pattern(mfa, false, [:local, :call_count])
      end

      assert {@cache_schema, @cache_kind, cached_source, _witness, cached_binary} =
               :persistent_term.get(@cache_key)

      assert cached_source === source
      assert byte_size(cached_binary) == @cache_bytes
    end)
  end

  defp concurrent_cache_calls do
    parent = self()

    tasks =
      for _index <- 1..@workers do
        Task.async(fn ->
          send(parent, {:cache_worker_ready, self()})

          receive do
            :run_cache_call -> CodecSupport.decode_discard(:cp943, <<>>)
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

  defp with_restored_cache(fun) do
    source =
      Iconvex.Tables.fetch!(%{id: :cp943, table_app: :iconvex_extras}).many

    previous = :persistent_term.get(@cache_key, :missing)

    try do
      fun.(source)
    after
      case previous do
        :missing -> :persistent_term.erase(@cache_key)
        value -> :persistent_term.put(@cache_key, value)
      end
    end
  end

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
