defmodule Iconvex.Tables do
  @moduledoc false

  alias Iconvex.RouteSnapshot

  @prefix {__MODULE__, :table}
  @provider_prefix {__MODULE__, :provider}
  @provider_token_prefix {__MODULE__, :provider_token}
  @provider_clock_key {__MODULE__, :provider_clock}
  @provider_snapshot_key {__MODULE__, :provider_snapshot}
  @provider_context_key {__MODULE__, :provider_context}
  @missing {__MODULE__, :missing}
  @conversion_cache_key {__MODULE__, :conversion_cache}
  @cache_schema 1
  @table_schema_atoms [
    MapSet,
    :__struct__,
    :dbcs,
    :dbcs_decode,
    :encode,
    :many,
    :map,
    :max_codepoints,
    :max_input,
    nil,
    :one,
    :prefixes,
    :sbcs,
    :sbcs_decode,
    :vietnamese_base_bytes
  ]

  def fetch!(%{id: id, table_app: app}), do: fetch_cached!(app, id)
  def fetch!(%{id: id}), do: fetch!(id)

  def fetch!(id) do
    app = provider_app_for(id)
    fetch_cached!(app, id)
  end

  @doc false
  def fetch_with_identity!(%{id: id, table_app: app}), do: fetch_cached_with_identity!(app, id)

  def fetch_with_identity!(%{id: id}) do
    app = provider_app_for(id)
    fetch_cached_with_identity!(app, id)
  end

  @doc false
  def with_conversion_cache(function) when is_function(function, 0) do
    case Process.get(@conversion_cache_key, :missing) do
      %{tables: %{}, versions: %{}} ->
        function.()

      :missing ->
        Process.put(@conversion_cache_key, %{tables: %{}, versions: %{}})

        try do
          function.()
        after
          Process.delete(@conversion_cache_key)
        end

      previous ->
        Process.put(@conversion_cache_key, %{tables: %{}, versions: %{}})

        try do
          function.()
        after
          Process.put(@conversion_cache_key, previous)
        end
    end
  end

  @doc false
  def provider_snapshot do
    clock = provider_clock()
    read_provider_snapshot(clock)
  end

  @doc false
  def with_provider_snapshot(snapshot, function)
      when is_map(snapshot) and is_function(function, 0) do
    previous = Process.get(@provider_context_key, @missing)
    Process.put(@provider_context_key, snapshot)

    try do
      function.()
    after
      restore_provider_context(previous)
    end
  end

  def register_provider(id, app) when is_atom(id) and is_atom(app) do
    :global.trans({{__MODULE__, :provider_registration, id}, self()}, fn ->
      with_provider_update(fn -> put_unowned_provider(id, app) end)
    end)
  end

  def register_provider_owned(id, app) when is_atom(id) and is_atom(app) do
    :global.trans({{__MODULE__, :provider_registration, id}, self()}, fn ->
      with_provider_update(fn -> put_provider(id, app) end)
    end)
  end

  defp put_provider(id, app) do
    key = {@provider_prefix, id}
    legacy_token_key = {@provider_token_prefix, id}

    case :persistent_term.get(key, @missing) do
      @missing ->
        token = make_ref()
        :persistent_term.put(key, {app, {:owned, token}})
        :persistent_term.erase(legacy_token_key)
        {:ok, token}

      {^app, {:owned, token}} when is_reference(token) ->
        :persistent_term.erase(legacy_token_key)
        {:ok, token}

      {^app, :unowned} ->
        {:ok, :existing}

      ^app ->
        token =
          case :persistent_term.get(legacy_token_key, @missing) do
            token when is_reference(token) -> token
            _missing_or_invalid -> make_ref()
          end

        :persistent_term.put(key, {app, {:owned, token}})
        :persistent_term.erase(legacy_token_key)
        {:ok, token}

      {current, _ownership} when is_atom(current) ->
        {:error, {:table_provider_conflict, id, current}}

      current ->
        {:error, {:table_provider_conflict, id, current}}
    end
  end

  defp put_unowned_provider(id, app) do
    key = {@provider_prefix, id}

    case :persistent_term.get(key, @missing) do
      @missing ->
        :persistent_term.put(key, {app, :unowned})
        :persistent_term.erase({@provider_token_prefix, id})
        :ok

      {^app, _ownership} ->
        :ok

      ^app ->
        :ok

      {current, _ownership} when is_atom(current) ->
        {:error, {:table_provider_conflict, id, current}}

      current ->
        {:error, {:table_provider_conflict, id, current}}
    end
  end

  def unregister_provider(id, app) when is_atom(id) and is_atom(app) do
    :global.trans({{__MODULE__, :provider_registration, id}, self()}, fn ->
      with_provider_update(fn -> delete_provider(id, app) end)
    end)
  end

  def unregister_provider(id, app, token)
      when is_atom(id) and is_atom(app) and is_reference(token) do
    :global.trans({{__MODULE__, :provider_registration, id}, self()}, fn ->
      with_provider_update(fn ->
        case :persistent_term.get({@provider_prefix, id}, @missing) do
          {^app, {:owned, ^token}} ->
            delete_provider(id, app)

          ^app ->
            if :persistent_term.get({@provider_token_prefix, id}, @missing) == token,
              do: delete_provider(id, app)

          _other ->
            :ok
        end

        :ok
      end)
    end)
  end

  def unregister_provider(_id, _app, _token), do: :ok

  defp delete_provider(id, app) do
    if provider_matches?(:persistent_term.get({@provider_prefix, id}, @missing), app) do
      :persistent_term.erase({@provider_prefix, id})
      :persistent_term.erase({@provider_token_prefix, id})
      :persistent_term.erase({@prefix, app, id})
      Iconvex.TableCodec.clear_decode_caches(app, id)
    end

    :ok
  end

  defp provider_app({app, {:owned, token}}) when is_atom(app) and is_reference(token), do: app
  defp provider_app({app, :unowned}) when is_atom(app), do: app
  defp provider_app(app) when is_atom(app), do: app
  defp provider_app(_missing_or_invalid), do: :iconvex

  defp provider_matches?({app, {:owned, token}}, app)
       when is_atom(app) and is_reference(token),
       do: true

  defp provider_matches?({app, :unowned}, app) when is_atom(app), do: true
  defp provider_matches?(app, app) when is_atom(app), do: true
  defp provider_matches?(_provider, _app), do: false

  defp provider_app_for(id) do
    case Process.get(@provider_context_key, @missing) do
      snapshot when is_map(snapshot) -> Map.get(snapshot, id, :iconvex)
      @missing -> provider_app(:persistent_term.get({@provider_prefix, id}, @missing))
    end
  end

  defp provider_clock do
    case :persistent_term.get(@provider_clock_key, @missing) do
      clock when is_reference(clock) ->
        clock

      @missing ->
        :global.trans({{__MODULE__, :provider_clock}, self()}, fn ->
          case :persistent_term.get(@provider_clock_key, @missing) do
            clock when is_reference(clock) ->
              clock

            @missing ->
              clock = :atomics.new(1, signed: false)
              :persistent_term.put(@provider_clock_key, clock)
              clock
          end
        end)
    end
  end

  defp with_provider_update(function) do
    RouteSnapshot.with_update(fn ->
      clock = provider_clock()
      :atomics.add_get(clock, 1, 1)
      run_after_provider_invalidate_hook()
      function.()
    end)
  end

  defp read_provider_snapshot(clock) do
    generation = :atomics.get(clock, 1)

    case :persistent_term.get(@provider_snapshot_key, @missing) do
      {^generation, snapshot} when is_map(snapshot) ->
        if :atomics.get(clock, 1) == generation do
          snapshot
        else
          read_provider_snapshot(clock)
        end

      _missing_or_stale ->
        rebuild_provider_snapshot(clock)
    end
  end

  defp rebuild_provider_snapshot(clock) do
    :global.trans({{__MODULE__, :provider_snapshot}, self()}, fn ->
      generation = :atomics.get(clock, 1)

      case :persistent_term.get(@provider_snapshot_key, @missing) do
        {^generation, snapshot} when is_map(snapshot) ->
          snapshot

        _missing_or_stale ->
          route_generation = RouteSnapshot.generation()
          snapshot = collect_provider_snapshot()

          if :atomics.get(clock, 1) == generation and
               RouteSnapshot.generation_current?(route_generation) do
            :persistent_term.put(@provider_snapshot_key, {generation, snapshot})
            {^generation, published} = :persistent_term.get(@provider_snapshot_key)
            published
          else
            snapshot
          end
      end
    end)
  end

  defp collect_provider_snapshot do
    Enum.reduce(:persistent_term.get(), %{}, fn
      {{@provider_prefix, id}, record}, snapshot when is_atom(id) ->
        Map.put(snapshot, id, provider_app(record))

      _other, snapshot ->
        snapshot
    end)
  end

  defp restore_provider_context(@missing), do: Process.delete(@provider_context_key)
  defp restore_provider_context(previous), do: Process.put(@provider_context_key, previous)

  if Mix.env() == :test do
    defp run_after_provider_invalidate_hook do
      case Process.get({__MODULE__, :after_provider_invalidate}) do
        {owner, reference} when is_pid(owner) and is_reference(reference) ->
          Process.delete({__MODULE__, :after_provider_invalidate})
          send(owner, {:iconvex_provider_update_invalid, self(), reference})

          receive do
            {:continue_iconvex_provider_update, ^reference} -> :ok
          end

        _unset ->
          :ok
      end
    end
  else
    defp run_after_provider_invalidate_hook, do: :ok
  end

  defp fetch_cached!(app, id) do
    {table, _identity} = fetch_cached_with_identity!(app, id)
    table
  end

  defp fetch_cached_with_identity!(app, id) do
    case Process.get(@conversion_cache_key, :missing) do
      %{tables: tables} ->
        cache_key = {app, id}

        case Map.fetch(tables, cache_key) do
          {:ok, {table, identity}} when is_reference(identity) ->
            {table, identity}

          _missing_or_legacy ->
            table_with_identity = fetch_uncached_with_identity!(app, id)
            cache = Process.get(@conversion_cache_key)

            Process.put(
              @conversion_cache_key,
              put_in(cache, [:tables, cache_key], table_with_identity)
            )

            table_with_identity
        end

      :missing ->
        fetch_uncached_with_identity!(app, id)
    end
  end

  defp fetch_uncached_with_identity!(app, id) do
    key = {@prefix, app, id}
    version = cache_version(app)

    case :persistent_term.get(key, :missing) do
      {@cache_schema, ^version, identity, %{vietnamese_base_bytes: %MapSet{}} = table}
      when is_reference(identity) and id in [:cp1258, :tcvn] ->
        {table, identity}

      {@cache_schema, ^version, identity, table}
      when is_reference(identity) and id not in [:cp1258, :tcvn] ->
        {table, identity}

      {@cache_schema, ^version, %{vietnamese_base_bytes: %MapSet{}}}
      when id in [:cp1258, :tcvn] ->
        migrate_or_load(key, app, id, version)

      {@cache_schema, ^version, _table} when id not in [:cp1258, :tcvn] ->
        migrate_or_load(key, app, id, version)

      _missing_or_stale ->
        migrate_or_load(key, app, id, version)
    end
  end

  defp migrate_or_load(key, app, id, version) do
    :global.trans({{__MODULE__, app, id}, self()}, fn ->
      load_if_stale(key, app, id, version)
    end)
  end

  defp load_if_stale(key, app, id, version) do
    case :persistent_term.get(key, :missing) do
      {@cache_schema, ^version, identity, %{vietnamese_base_bytes: %MapSet{}} = table}
      when is_reference(identity) and id in [:cp1258, :tcvn] ->
        {table, identity}

      {@cache_schema, ^version, identity, table}
      when is_reference(identity) and id not in [:cp1258, :tcvn] ->
        {table, identity}

      {@cache_schema, ^version, %{vietnamese_base_bytes: %MapSet{}} = table}
      when id in [:cp1258, :tcvn] ->
        publish_identity(key, version, table)

      {@cache_schema, ^version, table} when id not in [:cp1258, :tcvn] ->
        publish_identity(key, version, table)

      _missing_or_stale ->
        path = app |> :code.priv_dir() |> Path.join("tables/#{id}.etf")
        # `:safe` permits only atoms already present in the VM. Keep every atom
        # in the generated, finite table schema as a module literal so a truly
        # cold load is both safe and valid.
        Enum.each(@table_schema_atoms, &:erlang.atom_to_binary/1)

        # Generated terms ship with trusted application code; :safe still blocks executable terms.
        table =
          path
          |> File.read!()
          |> :erlang.binary_to_term([:safe])
          |> prepare_table(id)

        publish_identity(key, version, table)
    end
  end

  defp publish_identity(key, version, table) do
    # The reference names this exact published generation. Downstream caches
    # can validate it in O(1) without retaining and comparing a second table.
    identity = make_ref()
    :persistent_term.put(key, {@cache_schema, version, identity, table})
    {table, identity}
  end

  defp prepare_table(table, id) when id in [:cp1258, :tcvn],
    do: Map.put(table, :vietnamese_base_bytes, vietnamese_base_bytes(table))

  defp prepare_table(table, _id), do: table

  defp vietnamese_base_bytes(table) do
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

  defp cache_version(app) do
    case Process.get(@conversion_cache_key, :missing) do
      %{versions: versions} ->
        case Map.fetch(versions, app) do
          {:ok, version} ->
            version

          :error ->
            version = read_cache_version(app)
            cache = Process.get(@conversion_cache_key)
            Process.put(@conversion_cache_key, put_in(cache, [:versions, app], version))
            version
        end

      :missing ->
        read_cache_version(app)
    end
  end

  defp read_cache_version(app),
    do: {@cache_schema, Application.spec(app, :vsn) || ~c"unloaded"}
end
