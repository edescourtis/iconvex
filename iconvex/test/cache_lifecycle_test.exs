defmodule Iconvex.ProviderSnapshotOneShotCodec do
  use Iconvex.Codec

  @impl true
  def canonical_name, do: "X-ICONVEX-PROVIDER-SNAPSHOT-ONE-SHOT"

  @impl true
  def decode(_input) do
    :ok = Iconvex.Tables.unregister_provider(:ascii, :iconvex)
    :ok = Iconvex.Tables.register_provider(:ascii, :iconvex_test_replacement_provider)
    {?A} = elem(Iconvex.Tables.fetch!(:ascii).one, ?A)
    {:ok, [?A]}
  end

  @impl true
  def decode_discard(input), do: decode(input)

  @impl true
  def encode([?A]), do: {:ok, "A"}

  @impl true
  def encode([codepoint | _rest]),
    do: {:error, :unrepresentable_character, codepoint}

  @impl true
  def encode([]), do: {:ok, <<>>}

  @impl true
  def encode_discard(codepoints) do
    output = for codepoint <- codepoints, codepoint == ?A, into: <<>>, do: <<?A>>
    {:ok, output}
  end

  @impl true
  def encode_substitute(codepoints, _replacer), do: encode(codepoints)
end

defmodule Iconvex.ProviderSnapshotStreamCodec do
  use Iconvex.Codec

  @impl true
  def canonical_name, do: "X-ICONVEX-PROVIDER-SNAPSHOT-STREAM"

  @impl true
  def decode(input), do: decode_complete(input)

  @impl true
  def decode_discard(input), do: decode_complete(input)

  @impl true
  def decode_chunk(<<>>, true) do
    {?A} = elem(Iconvex.Tables.fetch!(:ascii).one, ?A)
    {:ok, [], <<>>}
  end

  def decode_chunk(_input, _final?) do
    {?A} = elem(Iconvex.Tables.fetch!(:ascii).one, ?A)
    {:ok, [?A], <<>>}
  end

  @impl true
  def encode([?A]), do: {:ok, "A"}

  @impl true
  def encode([codepoint | _rest]),
    do: {:error, :unrepresentable_character, codepoint}

  @impl true
  def encode([]), do: {:ok, <<>>}

  @impl true
  def encode_discard(codepoints) do
    output = for codepoint <- codepoints, codepoint == ?A, into: <<>>, do: <<?A>>
    {:ok, output}
  end

  @impl true
  def encode_substitute(codepoints, _replacer), do: encode(codepoints)

  defp decode_complete(<<>>), do: {:ok, []}

  defp decode_complete(_input) do
    {?A} = elem(Iconvex.Tables.fetch!(:ascii).one, ?A)
    {:ok, [?A]}
  end
end

defmodule Iconvex.CacheLifecycleTest do
  use ExUnit.Case, async: false

  test "RED: stale-version table and transliteration terms are replaced" do
    table_key = {{Iconvex.Tables, :table}, :iconvex, :ascii}
    translit_key = {Iconvex.Transliterator, :mapping}

    :persistent_term.put(table_key, {1, {1, ~c"stale"}, :stale})
    :persistent_term.put(translit_key, {1, {1, ~c"stale"}, %{0x00DF => ~c"wrong"}})

    table = Iconvex.Tables.fetch!(:ascii)
    assert is_tuple(table.one)
    assert elem(table.one, ?A) == {?A}
    assert Iconvex.Transliterator.fetch(0x00DF) == {:ok, ~c"ss"}

    refute :persistent_term.get(table_key) == {1, {1, ~c"stale"}, :stale}
    refute :persistent_term.get(translit_key) == {1, {1, ~c"stale"}, %{0x00DF => ~c"wrong"}}
  end

  test "concurrent cold fetches serialize loading and return one exact term" do
    key = {{Iconvex.Tables, :table}, :iconvex, :cp1252}
    :persistent_term.erase(key)

    results =
      1..64
      |> Task.async_stream(fn _ -> Iconvex.Tables.fetch!(:cp1252) end,
        max_concurrency: 64,
        ordered: false,
        timeout: 30_000
      )
      |> Enum.map(fn {:ok, table} -> table end)

    assert length(results) == 64
    assert Enum.all?(results, &(&1 === hd(results)))
    assert elem(hd(results).one, 0x80) == {0x20AC}
  end

  test "Vietnamese composition bases are precomputed during a cold table load" do
    for id <- [:cp1258, :tcvn] do
      key = {{Iconvex.Tables, :table}, :iconvex, id}
      :persistent_term.erase(key)

      table = Iconvex.Tables.fetch!(id)
      assert %{vietnamese_base_bytes: %MapSet{} = bases} = table
      assert bases == expected_vietnamese_base_bytes(table)
    end
  end

  test "a live pre-optimization Vietnamese cache is rehydrated" do
    key = {{Iconvex.Tables, :table}, :iconvex, :cp1258}
    :persistent_term.erase(key)

    table = Iconvex.Tables.fetch!(:cp1258)
    {schema, version, identity, ^table} = :persistent_term.get(key)

    :persistent_term.put(
      key,
      {schema, version, identity, Map.delete(table, :vietnamese_base_bytes)}
    )

    assert %{vietnamese_base_bytes: %MapSet{}} = Iconvex.Tables.fetch!(:cp1258)
  end

  test "a provider ownership token cannot remove a later replacement" do
    id = :iconvex_test_owned_provider
    provider_key = {{Iconvex.Tables, :provider}, id}

    on_exit(fn -> Iconvex.Tables.unregister_provider(id, :iconvex) end)

    assert {:ok, token} = Iconvex.Tables.register_provider_owned(id, :iconvex)
    assert is_reference(token)
    assert :ok = Iconvex.Tables.unregister_provider(id, :iconvex)
    assert :ok = Iconvex.Tables.register_provider(id, :iconvex)

    assert :ok = Iconvex.Tables.unregister_provider(id, :iconvex, token)
    assert :persistent_term.get(provider_key) == {:iconvex, :unowned}
  end

  test "RED: provider unload erases its base table and every derived decode cache" do
    cases = [
      {:cp932, :dense_two_byte_decode},
      {:tcvn, :vietnamese_sparse_two_byte_decode},
      {:cp1255, :variable_width_decode_trie}
    ]

    Enum.each(cases, fn {id, cache_tag} ->
      entry = %{id: id, table_app: :iconvex}
      table_key = {{Iconvex.Tables, :table}, :iconvex, id}
      cache_key = {Iconvex.TableCodec, cache_tag, :iconvex, id, 1}

      on_exit(fn -> Iconvex.Tables.unregister_provider(id, :iconvex) end)
      assert :ok = Iconvex.Tables.unregister_provider(id, :iconvex)
      assert {:ok, token} = Iconvex.Tables.register_provider_owned(id, :iconvex)

      table = Iconvex.Tables.fetch!(entry)

      {bytes, {codepoint}} =
        Enum.find(table.many, fn
          {bytes, {_codepoint}} -> byte_size(bytes) > 1
          _other -> false
        end)

      assert Iconvex.TableCodec.decode_to_explicit_ucs4_discard(entry, bytes, :big) ==
               {:ok, <<codepoint::unsigned-big-32>>}

      refute :persistent_term.get(table_key, :missing) == :missing
      refute :persistent_term.get(cache_key, :missing) == :missing

      assert :ok = Iconvex.Tables.unregister_provider(id, :iconvex, token)
      assert :persistent_term.get(table_key, :missing) == :missing
      assert :persistent_term.get(cache_key, :missing) == :missing
    end)
  end

  test "provider snapshots retain one resolved provider while live lookups follow replacement" do
    id = :iconvex_test_provider_snapshot
    first_app = :iconvex_test_provider_snapshot_first
    second_app = :iconvex_test_provider_snapshot_second
    first_table_key = {{Iconvex.Tables, :table}, first_app, id}
    second_table_key = {{Iconvex.Tables, :table}, second_app, id}
    version = {1, ~c"unloaded"}

    on_exit(fn ->
      Iconvex.Tables.unregister_provider(id, first_app)
      Iconvex.Tables.unregister_provider(id, second_app)
      :persistent_term.erase(first_table_key)
      :persistent_term.erase(second_table_key)
    end)

    assert :ok = Iconvex.Tables.register_provider(id, first_app)
    first_snapshot = Iconvex.Tables.provider_snapshot()
    assert first_snapshot[id] == first_app
    assert Iconvex.Tables.provider_snapshot() === first_snapshot

    assert :ok = Iconvex.Tables.unregister_provider(id, first_app)
    assert :ok = Iconvex.Tables.register_provider(id, second_app)

    :persistent_term.put(first_table_key, {1, version, make_ref(), %{provider: :first}})
    :persistent_term.put(second_table_key, {1, version, make_ref(), %{provider: :second}})

    second_snapshot = Iconvex.Tables.provider_snapshot()
    assert first_snapshot[id] == first_app
    assert second_snapshot[id] == second_app
    assert :erts_debug.same(second_snapshot, Iconvex.Tables.provider_snapshot())
    assert Iconvex.Tables.fetch!(id) == %{provider: :second}

    assert Iconvex.Tables.with_provider_snapshot(first_snapshot, fn ->
             assert Iconvex.Tables.fetch!(id) == %{provider: :first}

             assert Iconvex.Tables.with_provider_snapshot(second_snapshot, fn ->
                      Iconvex.Tables.fetch!(id)
                    end) == %{provider: :second}

             Iconvex.Tables.fetch!(id)
           end) == %{provider: :first}

    assert Iconvex.Tables.fetch!(id) == %{provider: :second}
  end

  test "one-shot conversion retains its provider when the codec replaces the live route" do
    provider_key = {{Iconvex.Tables, :provider}, :ascii}

    on_exit(fn ->
      Iconvex.unregister_codec(Iconvex.ProviderSnapshotOneShotCodec)
      Iconvex.Tables.unregister_provider(:ascii, :iconvex_test_replacement_provider)
      Iconvex.Tables.unregister_provider(:ascii, :iconvex)
    end)

    assert :ok = Iconvex.Tables.register_provider(:ascii, :iconvex)
    assert :ok = Iconvex.register_codec(Iconvex.ProviderSnapshotOneShotCodec)

    assert Iconvex.convert(
             "ignored",
             "X-ICONVEX-PROVIDER-SNAPSHOT-ONE-SHOT",
             "UTF-8"
           ) == {:ok, "A"}

    assert :persistent_term.get(provider_key) ==
             {:iconvex_test_replacement_provider, :unowned}
  end

  test "RED: a lazy Stream retains its provider through transform and finalization" do
    on_exit(fn ->
      Iconvex.unregister_codec(Iconvex.ProviderSnapshotStreamCodec)
      Iconvex.Tables.unregister_provider(:ascii, :iconvex_test_replacement_provider)
      Iconvex.Tables.unregister_provider(:ascii, :iconvex)
    end)

    assert :ok = Iconvex.Tables.register_provider(:ascii, :iconvex)
    assert :ok = Iconvex.register_codec(Iconvex.ProviderSnapshotStreamCodec)

    assert {:ok, stream} =
             Iconvex.stream(
               ["ignored"],
               "X-ICONVEX-PROVIDER-SNAPSHOT-STREAM",
               "UTF-8"
             )

    assert :ok = Iconvex.Tables.unregister_provider(:ascii, :iconvex)
    assert :ok = Iconvex.Tables.register_provider(:ascii, :iconvex_test_replacement_provider)
    assert Enum.to_list(stream) == ["A"]
  end

  test "provider registration atomically publishes and recovers its ownership token" do
    id = :iconvex_test_retry_owned_provider
    provider_key = {{Iconvex.Tables, :provider}, id}
    legacy_token_key = {{Iconvex.Tables, :provider_token}, id}

    on_exit(fn -> Iconvex.Tables.unregister_provider(id, :iconvex) end)
    assert :ok = Iconvex.Tables.unregister_provider(id, :iconvex)

    assert {:ok, token} = Iconvex.Tables.register_provider_owned(id, :iconvex)
    assert {:ok, ^token} = Iconvex.Tables.register_provider_owned(id, :iconvex)
    assert :persistent_term.get(provider_key) == {:iconvex, {:owned, token}}
    assert :persistent_term.get(legacy_token_key, :missing) == :missing

    assert :ok = Iconvex.Tables.unregister_provider(id, :iconvex, token)
    assert :persistent_term.get(provider_key, :missing) == :missing
  end

  test "provider registration adopts an interrupted legacy commit" do
    id = :iconvex_test_interrupted_owned_provider
    provider_key = {{Iconvex.Tables, :provider}, id}
    legacy_token_key = {{Iconvex.Tables, :provider_token}, id}

    on_exit(fn -> Iconvex.Tables.unregister_provider(id, :iconvex) end)
    assert :ok = Iconvex.Tables.unregister_provider(id, :iconvex)

    :persistent_term.put(provider_key, :iconvex)
    :persistent_term.erase(legacy_token_key)

    assert {:ok, token} = Iconvex.Tables.register_provider_owned(id, :iconvex)
    assert is_reference(token)
    assert :persistent_term.get(provider_key) == {:iconvex, {:owned, token}}

    assert :ok = Iconvex.Tables.unregister_provider(id, :iconvex, token)
    assert :persistent_term.get(provider_key, :missing) == :missing
  end

  test "concurrent same-app provider registration shares one recoverable owner token" do
    id = :iconvex_test_concurrent_owned_provider
    on_exit(fn -> Iconvex.Tables.unregister_provider(id, :iconvex) end)
    assert :ok = Iconvex.Tables.unregister_provider(id, :iconvex)

    results =
      1..64
      |> Task.async_stream(fn _ -> Iconvex.Tables.register_provider_owned(id, :iconvex) end,
        max_concurrency: 64,
        timeout: 5_000
      )
      |> Enum.map(fn {:ok, result} -> result end)

    tokens = for {:ok, token} <- results, do: token

    assert length(tokens) == 64
    assert tokens |> Enum.uniq() |> length() == 1
    assert :ok = Iconvex.Tables.unregister_provider(id, :iconvex, hd(tokens))
    assert :persistent_term.get({{Iconvex.Tables, :provider}, id}, :missing) == :missing
  end

  test "owned registration preserves an existing same-app unowned provider" do
    id = :iconvex_test_unowned_provider
    provider_key = {{Iconvex.Tables, :provider}, id}
    legacy_token_key = {{Iconvex.Tables, :provider_token}, id}

    on_exit(fn ->
      :persistent_term.erase(provider_key)
      :persistent_term.erase(legacy_token_key)
    end)

    assert :ok = Iconvex.Tables.register_provider(id, :iconvex)
    assert {:ok, :existing} = Iconvex.Tables.register_provider_owned(id, :iconvex)
    assert :persistent_term.get(provider_key) == {:iconvex, :unowned}

    :persistent_term.put(provider_key, :iconvex)
    assert :ok = Iconvex.Tables.register_provider(id, :iconvex)
    assert :persistent_term.get(provider_key) == :iconvex
  end

  test "owned registration migrates and preserves a legacy ownership token" do
    id = :iconvex_test_legacy_owned_provider
    provider_key = {{Iconvex.Tables, :provider}, id}
    legacy_token_key = {{Iconvex.Tables, :provider_token}, id}
    token = make_ref()

    on_exit(fn ->
      :persistent_term.erase(provider_key)
      :persistent_term.erase(legacy_token_key)
    end)

    :persistent_term.put(provider_key, :iconvex)
    :persistent_term.put(legacy_token_key, token)

    assert {:ok, ^token} = Iconvex.Tables.register_provider_owned(id, :iconvex)
    assert :persistent_term.get(provider_key) == {:iconvex, {:owned, token}}
    assert :persistent_term.get(legacy_token_key, :missing) == :missing
  end

  test "atomic and legacy providers reject both conflicting registration APIs" do
    id = :iconvex_test_conflicting_provider
    provider_key = {{Iconvex.Tables, :provider}, id}
    other_app = :iconvex_test_other_provider
    conflict = {:error, {:table_provider_conflict, id, other_app}}

    on_exit(fn -> :persistent_term.erase(provider_key) end)

    :persistent_term.put(provider_key, {other_app, :unowned})
    assert Iconvex.Tables.register_provider_owned(id, :iconvex) == conflict
    assert Iconvex.Tables.register_provider(id, :iconvex) == conflict
    assert :persistent_term.get(provider_key) == {other_app, :unowned}

    :persistent_term.put(provider_key, other_app)
    assert Iconvex.Tables.register_provider_owned(id, :iconvex) == conflict
    assert Iconvex.Tables.register_provider(id, :iconvex) == conflict
    assert :persistent_term.get(provider_key) == other_app
  end

  test "only the matching legacy token unregisters a legacy owned provider" do
    id = :iconvex_test_legacy_unregister_provider
    provider_key = {{Iconvex.Tables, :provider}, id}
    legacy_token_key = {{Iconvex.Tables, :provider_token}, id}
    token = make_ref()

    on_exit(fn ->
      :persistent_term.erase(provider_key)
      :persistent_term.erase(legacy_token_key)
    end)

    :persistent_term.put(provider_key, :iconvex)
    :persistent_term.put(legacy_token_key, token)

    assert :ok = Iconvex.Tables.unregister_provider(id, :iconvex, make_ref())
    assert :persistent_term.get(provider_key) == :iconvex
    assert :persistent_term.get(legacy_token_key) == token

    assert :ok = Iconvex.Tables.unregister_provider(id, :iconvex, :not_an_owner_token)
    assert :persistent_term.get(provider_key) == :iconvex

    assert :ok = Iconvex.Tables.unregister_provider(id, :iconvex, token)
    assert :persistent_term.get(provider_key, :missing) == :missing
    assert :persistent_term.get(legacy_token_key, :missing) == :missing
  end

  test "fetch normalizes atomic, legacy, missing, and invalid provider records" do
    id = :ascii
    provider_key = {{Iconvex.Tables, :provider}, id}

    on_exit(fn -> :persistent_term.erase(provider_key) end)

    for record <- [
          {:iconvex, {:owned, make_ref()}},
          {:iconvex, :unowned},
          :iconvex,
          :missing,
          {:invalid_provider_record}
        ] do
      if record == :missing do
        :persistent_term.erase(provider_key)
      else
        :persistent_term.put(provider_key, record)
      end

      table = Iconvex.Tables.fetch!(id)
      assert elem(table.one, ?A) == {?A}
    end
  end

  defp expected_vietnamese_base_bytes(table) do
    Enum.reduce(table.many, MapSet.new(), fn
      {<<base, combining>>, codepoints}, bases when tuple_size(codepoints) == 1 ->
        base_codepoints = elem(table.one, base)
        combining_codepoints = elem(table.one, combining)

        if base_codepoints != nil and combining_codepoints != nil and
             elem(base_codepoints, 0) >= 0x41 and
             elem(combining_codepoints, 0) in [0x0300, 0x0301, 0x0303, 0x0309, 0x0323] do
          MapSet.put(bases, base)
        else
          bases
        end

      _, bases ->
        bases
    end)
  end
end
