defmodule Iconvex.ExternalRegistry do
  @moduledoc false
  use GenServer

  alias Iconvex.ExternalCallbacks
  alias Iconvex.Registry
  alias Iconvex.RouteSnapshot
  alias Iconvex.ExternalRegistry.Heir

  @heir_data :registry_heir
  @recovery_snapshot_key {__MODULE__, :recovery_snapshot}
  @ready_key {__MODULE__, :ready}
  @recovery_snapshot_version 1
  @default_registration_restart_attempts 2_000
  @resolve_fast_retries 8

  @required_callbacks [
    canonical_name: 0,
    decode: 1,
    decode_discard: 1,
    encode: 1,
    encode_discard: 1,
    encode_substitute: 2
  ]

  def start_link(configured_codecs) do
    GenServer.start_link(__MODULE__, configured_codecs, name: __MODULE__)
  end

  def register(module, options \\ []) do
    case register_owned(module, options) do
      {:ok, _token} -> :ok
      error -> error
    end
  end

  def register_owned(module, options \\ []) do
    token = make_ref()
    expected = registration_identity(module)

    registration_call(module, token, fn
      :initial -> {:register, module, options, token, :replace, expected}
      :retry -> {:register, module, options, token, :adopt, expected}
    end)
  end

  def register_if_absent(module, options \\ []) do
    token = make_ref()

    registration_call(module, token, fn _attempt ->
      {:register_if_absent, module, options, token}
    end)
  end

  @doc false
  def register_set_owned(registrations, options) do
    token = make_ref()
    registration_set_call(registrations, options, token)
  end

  @doc false
  def unregister_set(token) when is_reference(token), do: owned_set_unregistration_call(token)
  def unregister_set(_token), do: {:error, {:invalid_argument, :registration_token}}

  def unregister(module) when is_atom(module), do: call({:unregister, module})
  def unregister(_module), do: {:error, {:invalid_argument, :module}}

  def unregister(module, token) when is_atom(module) and is_reference(token),
    do: owned_unregistration_call(module, token)

  def unregister(module, _token) when not is_atom(module),
    do: {:error, {:invalid_argument, :module}}

  def unregister(_module, _token), do: {:error, {:invalid_argument, :registration_token}}

  def resolve(name) when is_binary(name), do: resolve_when_ready({:name, name})
  def resolve(module) when is_atom(module), do: resolve_when_ready({:module, module})
  def resolve(_name), do: :error

  def canonical_names do
    {{:module, :_}, :"$1"}
    |> safe_match()
    |> Enum.map(&hd/1)
    |> Enum.filter(&is_map/1)
    |> Enum.map(& &1.canonical)
    |> Enum.sort()
    |> Enum.uniq_by(&normalize/1)
  end

  defp resolve_lookup(key) do
    case lookup(key) do
      {:ok, %{kind: :external, codec: module} = entry} ->
        {:ok,
         %{
           entry
           | decode_to_utf8?: function_exported?(module, :decode_to_utf8, 1),
             encode_from_utf8?: function_exported?(module, :encode_from_utf8, 1),
             decode_to_ucs4_discard?: function_exported?(module, :decode_to_ucs4_discard, 2),
             encode_from_ucs4_discard?: function_exported?(module, :encode_from_ucs4_discard, 2)
         }}

      result ->
        result
    end
  end

  defp resolve_stable(key, attempt) when attempt <= @resolve_fast_retries do
    generation = RouteSnapshot.generation()
    result = resolve_lookup(key)

    if RouteSnapshot.generation_current?(generation) do
      result
    else
      :erlang.yield()
      resolve_stable(key, attempt + 1)
    end
  end

  defp resolve_stable(key, _attempt) do
    RouteSnapshot.serialized(fn -> resolve_lookup(key) end)
  end

  defp resolve_when_ready(key) do
    case :persistent_term.get(@ready_key, :missing) do
      registry when is_pid(registry) ->
        if Process.alive?(registry), do: resolve_stable(key, 1), else: resolve_after_restart(key)

      _missing_or_invalid ->
        resolve_after_restart(key)
    end
  end

  defp resolve_after_restart(key) do
    case Process.whereis(__MODULE__) do
      registry when is_pid(registry) ->
        if RouteSnapshot.lock_held?() do
          :route_retry
        else
          try do
            GenServer.call(registry, {:resolve_when_ready, key}, :infinity)
          catch
            :exit, _reason -> resolve_when_ready(key)
          end
        end

      nil ->
        resolve_stable(key, 1)
    end
  end

  @doc false
  def await_ready do
    case :persistent_term.get(@ready_key, :missing) do
      registry when is_pid(registry) ->
        if Process.alive?(registry), do: :ok, else: await_replacement_ready()

      _missing_or_invalid ->
        await_replacement_ready()
    end
  end

  defp await_replacement_ready do
    case Process.whereis(__MODULE__) do
      registry when is_pid(registry) ->
        try do
          GenServer.call(registry, :await_ready, :infinity)
        catch
          :exit, _reason -> await_ready()
        end

      nil ->
        :ok
    end
  end

  @doc false
  def checkpoint_recovery_state do
    rows = :ets.tab2list(__MODULE__)
    :persistent_term.put(@recovery_snapshot_key, {@recovery_snapshot_version, rows})
    :ok
  rescue
    ArgumentError -> :ok
  catch
    :error, :badarg -> :ok
  end

  @doc false
  def clear_recovery_snapshot do
    :persistent_term.erase(@recovery_snapshot_key)
    :persistent_term.erase(@ready_key)
    :ok
  end

  @impl true
  def init(configured_codecs) do
    result =
      case prepare_configured(configured_codecs) do
        {:ok, configured_entries} -> initialize_registry(configured_entries)
        {:error, _reason} = error -> finish_init(error)
      end

    case result do
      {:ok, _state} ->
        :persistent_term.put(@ready_key, self())
        result

      _stopped ->
        :persistent_term.erase(@ready_key)
        result
    end
  end

  @impl true
  def handle_call({:resolve_when_ready, key}, _from, state) do
    {:reply, resolve_lookup(key), state}
  end

  def handle_call(:await_ready, _from, state), do: {:reply, :ok, state}

  def handle_call({:register, module, options, token, :replace, _expected}, _from, state) do
    {:reply, put_codec(module, options, state, token), state}
  end

  def handle_call({:register, module, options, token, :adopt, expected}, _from, state) do
    result =
      case lookup({:module, module}) do
        {:ok, %{registration_token: ^token}} ->
          {:ok, token}

        current ->
          if registration_identity_from_lookup(current) == expected do
            put_codec(module, options, state, token)
          else
            {:error, :registration_replaced_during_retry}
          end
      end

    {:reply, result, state}
  end

  def handle_call({:register_if_absent, module, options, token}, _from, state) do
    result =
      case lookup({:module, module}) do
        {:ok, %{registration_token: ^token}} -> {:ok, token}
        {:ok, _entry} -> {:ok, :existing}
        :error -> put_codec(module, options, state, token)
      end

    {:reply, result, state}
  end

  def handle_call({:register_set, registrations, options, token, :initial}, _from, state) do
    {:reply, put_registration_set(registrations, options, state, token), state}
  end

  def handle_call({:register_set, registrations, options, token, :retry}, _from, state) do
    result =
      case lookup({:set, token}) do
        {:ok, %{status: :committed}} -> {:ok, token}
        _missing_or_incomplete -> put_registration_set(registrations, options, state, token)
      end

    {:reply, result, state}
  end

  def handle_call({:unregister, module}, _from, state) do
    delete_codec(module)
    {:reply, :ok, state}
  end

  def handle_call({:unregister, module, token}, _from, state) do
    case lookup({:module, module}) do
      {:ok, %{registration_token: ^token}} -> delete_codec(module)
      _missing_or_replaced -> :ok
    end

    {:reply, :ok, state}
  end

  def handle_call({:unregister_set, token}, _from, state) do
    delete_registration_set(token)
    {:reply, :ok, state}
  end

  @impl true
  def handle_cast({:install_heir, heir}, state) do
    if is_pid(heir) and Process.whereis(Heir) == heir do
      :ets.setopts(__MODULE__, {:heir, heir, @heir_data})
    end

    {:noreply, state}
  end

  @impl true
  def handle_info({:"ETS-TRANSFER", _table, _from, :registry_reclaimed}, state),
    do: {:noreply, state}

  def handle_info(_unrelated_message, state), do: {:noreply, state}

  defp initialize_registry(configured_entries) do
    case Heir.take_table(self()) do
      :missing ->
        RouteSnapshot.with_update(fn ->
          create_table()
          restore_recovery_state()
          initialize_registry_table(configured_entries, :ets.tab2list(__MODULE__))
        end)

      status when status in [:transferred, :already_owned] ->
        RouteSnapshot.with_update(fn ->
          initialize_registry_table(configured_entries, :ets.tab2list(__MODULE__))
        end)

      {:error, reason} ->
        {:stop, reason}
    end
  end

  defp initialize_registry_table(configured_entries, original_rows) do
    rollback_pending_sets()
    repair_name_index()

    case finish_init(ensure_configured(configured_entries)) do
      {:ok, _state} = started ->
        started

      {:stop, _reason} = stopped ->
        restore_table_rows(original_rows)
        stopped
    end
  end

  defp restore_table_rows(rows) do
    :ets.delete_all_objects(__MODULE__)
    true = :ets.insert(__MODULE__, rows)
    :ok
  end

  defp prepare_configured(configured_codecs) when is_list(configured_codecs) do
    configured_codecs
    |> Enum.reduce_while({:ok, []}, fn configured, {:ok, reversed} ->
      {module, options} = configured_codec_specification(configured)

      case build_entry(module, options) do
        {:ok, entry} -> {:cont, {:ok, [entry | reversed]}}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, reversed} -> {:ok, :lists.reverse(reversed)}
      {:error, _reason} = error -> error
    end
  end

  defp prepare_configured(_configured_codecs),
    do: {:error, {:invalid_configuration, :external_codecs_must_be_a_list}}

  defp configured_codec_specification({module, options}) when is_list(options),
    do: {module, options}

  defp configured_codec_specification(module), do: {module, []}

  defp ensure_configured(configured_entries) do
    missing_entries =
      configured_entries
      |> Enum.uniq_by(& &1.codec)
      |> Enum.reject(&match?({:ok, _entry}, lookup({:module, &1.codec})))
      |> Enum.map(fn entry ->
        entry
        |> Map.put(:registration_token, make_ref())
        |> Map.put(:registration_mode, :strict)
      end)

    with :ok <- ensure_configured_names_available(missing_entries) do
      objects =
        Enum.flat_map(missing_entries, fn entry ->
          [{{:module, entry.codec}, entry}] ++
            Enum.map(entry_claims(entry), &claim_row/1) ++
            Enum.map(entry.names, &{{:name, &1}, entry.codec})
        end)

      if objects != [] do
        true = :ets.insert(__MODULE__, objects)
      end

      :ok
    end
  end

  defp ensure_configured_names_available(entries) do
    affected_names = entries |> Enum.flat_map(& &1.names) |> Enum.uniq()
    existing_claims_by_name = claims_for_names(affected_names)

    with :ok <-
           Enum.reduce_while(entries, :ok, fn entry, :ok ->
             case ensure_names_available(entry, existing_claims_by_name) do
               :ok -> {:cont, :ok}
               {:error, _reason} = error -> {:halt, error}
             end
           end),
         :ok <- ensure_configured_entries_do_not_collide(entries) do
      :ok
    end
  end

  defp ensure_configured_entries_do_not_collide(entries) do
    entries
    |> Enum.reduce_while({:ok, %{}}, fn entry, {:ok, owners} ->
      case Enum.find(entry.names, fn name ->
             case Map.fetch(owners, name) do
               {:ok, owner} -> owner != entry.codec
               :error -> false
             end
           end) do
        nil ->
          updated = Enum.reduce(entry.names, owners, &Map.put(&2, &1, entry.codec))
          {:cont, {:ok, updated}}

        name ->
          {:halt, {:error, {:name_conflict, name}}}
      end
    end)
    |> case do
      {:ok, _owners} -> :ok
      {:error, _reason} = error -> error
    end
  end

  defp put_codec(module, options, state, token) do
    with {:ok, entry} <- build_entry(module, options) do
      entry =
        entry
        |> Map.put(:registration_token, token)
        |> Map.put(:registration_mode, :strict)

      previous_entry = current_entry(module)
      claims = entry_claims(entry)
      previous_names = if previous_entry, do: previous_entry.names, else: []
      affected_names = Enum.uniq(previous_names ++ entry.names)
      claims_by_name = Map.new(claims, &{&1.name, &1})
      existing_claims_by_name = claims_for_names(affected_names)

      with :ok <- ensure_names_available(entry, existing_claims_by_name) do
        name_rows =
          Enum.map(affected_names, fn name ->
            remaining_claims =
              existing_claims_by_name
              |> Map.get(name, [])
              |> Enum.reject(&(&1.module == module))

            updated_claims =
              case Map.get(claims_by_name, name) do
                nil -> remaining_claims
                claim -> [claim | remaining_claims]
              end

            case updated_claims do
              [] -> {{:name, name}, :deleted}
              name_claims -> {{:name, name}, winner_for_claims(name_claims).module}
            end
          end)

        obsolete_claim_rows =
          previous_names
          |> Enum.reject(&MapSet.member?(entry.name_index, &1))
          |> Enum.map(&{{:claim, &1, module}, :deleted})

        registration_rows =
          if previous_entry,
            do: registration_rows_without_module(previous_entry, module),
            else: []

        objects =
          [{{:module, module}, entry}] ++
            Enum.map(claims, &claim_row/1) ++
            obsolete_claim_rows ++ name_rows ++ registration_rows

        RouteSnapshot.with_update(fn ->
          true = :ets.insert(__MODULE__, objects)
          delete_tombstones(objects)
        end)

        :ok = checkpoint_recovery_state()
        run_after_commit_hook(state, module)
        {:ok, token}
      end
    end
  end

  defp put_registration_set(registrations, options, state, token) do
    with {:ok, owner, priority} <- validate_set_options(options),
         {:ok, specifications} <- normalize_set_registrations(registrations) do
      case adopt_committed_registration_set(specifications, owner, priority) do
        {:ok, _existing_token} = adopted ->
          adopted

        :missing ->
          insert_registration_set(specifications, owner, priority, state, token)
      end
    end
  end

  defp insert_registration_set(specifications, owner, priority, state, token) do
    with {:ok, entries} <- build_missing_set_entries(specifications, owner, priority, token) do
      modules = Enum.map(entries, & &1.codec)
      claims = Enum.flat_map(entries, &entry_claims/1)

      affected_names =
        claims
        |> Enum.map(& &1.name)
        |> Enum.uniq()

      candidate_claims_by_name = Enum.group_by(claims, & &1.name)
      existing_claims_by_name = claims_for_names(affected_names)

      with :ok <-
             ensure_managed_names_available(
               affected_names,
               candidate_claims_by_name,
               existing_claims_by_name
             ),
           :ok <-
             ensure_unambiguous_managed_claims(
               affected_names,
               candidate_claims_by_name,
               existing_claims_by_name
             ) do
        winner_rows =
          Enum.map(affected_names, fn name ->
            winner =
              winner_for_claims(
                Map.get(existing_claims_by_name, name, []) ++
                  Map.fetch!(candidate_claims_by_name, name)
              )

            {{:name, name}, winner.module}
          end)

        objects =
          Enum.map(entries, &{{:module, &1.codec}, &1}) ++
            Enum.map(claims, &claim_row/1) ++
            winner_rows ++
            [
              {{:set, token},
               %{status: :committed, owner: owner, priority: priority, modules: modules}}
            ]

        RouteSnapshot.with_update(fn ->
          true = :ets.insert(__MODULE__, objects)
        end)

        :ok = checkpoint_recovery_state()
        run_after_commit_hook(state, {:set, token})
        {:ok, token}
      end
    end
  end

  defp adopt_committed_registration_set([], _owner, _priority), do: :missing

  defp adopt_committed_registration_set(
         [{first_module, _options} | _rest] = specifications,
         owner,
         priority
       ) do
    requested_modules = Enum.map(specifications, &elem(&1, 0))

    with {:ok,
          %{
            registration_token: existing_token,
            registration_mode: {:managed, ^owner, ^priority}
          }} <- lookup({:module, first_module}),
         {:ok,
          %{
            status: :committed,
            owner: ^owner,
            priority: ^priority,
            modules: registered_modules
          }} <- lookup({:set, existing_token}),
         true <- same_module_set?(requested_modules, registered_modules),
         true <-
           Enum.all?(specifications, fn specification ->
             managed_registration_matches?(
               specification,
               existing_token,
               owner,
               priority
             )
           end) do
      {:ok, existing_token}
    else
      _not_an_exact_committed_set -> :missing
    end
  end

  defp same_module_set?(requested_modules, registered_modules) do
    length(requested_modules) == length(registered_modules) and
      MapSet.new(requested_modules) == MapSet.new(registered_modules)
  end

  defp managed_registration_matches?({module, options}, token, owner, priority) do
    with {:ok,
          %{
            registration_token: ^token,
            registration_mode: {:managed, ^owner, ^priority}
          } = current} <- lookup({:module, module}),
         {:ok, expected} <- build_entry(module, options) do
      Map.drop(current, [:registration_token, :registration_mode]) == expected
    else
      _missing_or_changed -> false
    end
  end

  defp validate_set_options(options) do
    cond do
      not Keyword.keyword?(options) ->
        {:error, {:invalid_registration_set, :options_must_be_a_keyword_list}}

      Keyword.keys(options) -- [:owner, :priority] != [] ->
        {:error, {:invalid_registration_set, :unknown_options}}

      not is_atom(Keyword.get(options, :owner)) or is_nil(Keyword.get(options, :owner)) ->
        {:error, {:invalid_registration_set, :owner_must_be_an_atom}}

      not is_integer(Keyword.get(options, :priority)) ->
        {:error, {:invalid_registration_set, :priority_must_be_an_integer}}

      true ->
        {:ok, Keyword.fetch!(options, :owner), Keyword.fetch!(options, :priority)}
    end
  end

  defp normalize_set_registrations(registrations) when is_list(registrations) do
    with {:ok, specifications} <- collect_set_registrations(registrations, []),
         :ok <- ensure_unique_set_modules(specifications) do
      {:ok, specifications}
    end
  end

  defp normalize_set_registrations(_registrations),
    do: {:error, {:invalid_registration_set, :registrations_must_be_a_list}}

  defp collect_set_registrations([], acc), do: {:ok, :lists.reverse(acc)}

  defp collect_set_registrations([{module, options} | rest], acc) when is_list(options),
    do: collect_set_registrations(rest, [{module, options} | acc])

  defp collect_set_registrations([module | rest], acc) when is_atom(module),
    do: collect_set_registrations(rest, [{module, []} | acc])

  defp collect_set_registrations([_invalid | _rest], _acc),
    do: {:error, {:invalid_registration_set, :invalid_registration}}

  defp ensure_unique_set_modules(specifications) do
    modules = Enum.map(specifications, &elem(&1, 0))

    if length(modules) == MapSet.size(MapSet.new(modules)) do
      :ok
    else
      {:error, {:invalid_registration_set, :duplicate_module}}
    end
  end

  defp build_missing_set_entries(specifications, owner, priority, token) do
    Enum.reduce_while(specifications, {:ok, []}, fn {module, options}, {:ok, entries} ->
      case lookup({:module, module}) do
        {:ok, %{registration_mode: {:managed, _existing_owner, _existing_priority}}} ->
          {:halt, {:error, {:managed_registration_conflict, module}}}

        {:ok, _strict_or_caller_owned} ->
          {:cont, {:ok, entries}}

        :error ->
          case build_entry(module, options) do
            {:ok, entry} ->
              entry =
                entry
                |> Map.put(:registration_token, token)
                |> Map.put(:registration_mode, {:managed, owner, priority})

              {:cont, {:ok, [entry | entries]}}

            error ->
              {:halt, error}
          end
      end
    end)
    |> case do
      {:ok, entries} -> {:ok, :lists.reverse(entries)}
      error -> error
    end
  end

  defp ensure_managed_names_available(
         affected_names,
         candidate_claims_by_name,
         existing_claims_by_name
       ) do
    Enum.reduce_while(affected_names, :ok, fn name, :ok ->
      candidates = Map.fetch!(candidate_claims_by_name, name)
      existing = Map.get(existing_claims_by_name, name, [])

      cond do
        match?({:ok, _entry}, Registry.builtin_resolve(name)) ->
          {:halt, {:error, {:name_conflict, name}}}

        strict_claim_conflicts?(existing, candidates) ->
          {:halt, {:error, {:name_conflict, name}}}

        true ->
          {:cont, :ok}
      end
    end)
  end

  defp strict_claim_conflicts?(existing_claims, candidate_claims) do
    Enum.any?(existing_claims, fn existing ->
      existing.mode == :strict and
        Enum.any?(candidate_claims, &(&1.module != existing.module))
    end)
  end

  defp ensure_unambiguous_managed_claims(
         affected_names,
         candidate_claims_by_name,
         existing_claims_by_name
       ) do
    ambiguous =
      affected_names
      |> Enum.sort()
      |> Enum.find_value(fn name ->
        claims =
          Map.get(existing_claims_by_name, name, []) ++
            Map.fetch!(candidate_claims_by_name, name)

        claims
        |> unique_managed_claims()
        |> Enum.group_by(&claim_rank/1)
        |> Enum.sort_by(&elem(&1, 0))
        |> Enum.find_value(fn {_rank, ranked_claims} ->
          modules = ranked_claims |> Enum.map(& &1.module) |> Enum.sort()
          if length(modules) > 1, do: {name, Enum.sort(modules)}, else: nil
        end)
      end)

    case ambiguous do
      nil -> :ok
      {name, modules} -> {:error, {:ambiguous_name_conflict, name, modules}}
    end
  end

  defp unique_managed_claims(claims) do
    {_modules, reversed} =
      Enum.reduce(claims, {MapSet.new(), []}, fn claim, {modules, acc} ->
        cond do
          claim.mode != :managed ->
            {modules, acc}

          MapSet.member?(modules, claim.module) ->
            {modules, acc}

          true ->
            {MapSet.put(modules, claim.module), [claim | acc]}
        end
      end)

    :lists.reverse(reversed)
  end

  defp build_entry(module, options) do
    with :ok <- validate_options(options),
         :ok <- validate_module(module),
         {:ok, metadata} <- read_metadata(module, options) do
      {:ok,
       %{
         id: metadata.codec_id,
         kind: :external,
         codec: module,
         canonical: metadata.canonical,
         names: metadata.names,
         name_index: MapSet.new(metadata.names),
         claim_kinds: metadata.claim_kinds,
         stateful?: metadata.stateful?,
         decode_to_utf8?: function_exported?(module, :decode_to_utf8, 1),
         encode_from_utf8?: function_exported?(module, :encode_from_utf8, 1),
         decode_to_ucs4_discard?: function_exported?(module, :decode_to_ucs4_discard, 2),
         encode_from_ucs4_discard?: function_exported?(module, :encode_from_ucs4_discard, 2),
         decode_error_recovery: metadata.decode_error_recovery
       }}
    end
  end

  defp validate_options(options) do
    cond do
      not Keyword.keyword?(options) ->
        {:error, {:invalid_codec, :options_must_be_a_keyword_list}}

      Keyword.keys(options) -- [:aliases, :canonical] != [] ->
        {:error, {:invalid_codec, :unknown_options}}

      true ->
        :ok
    end
  end

  defp validate_module(module) when is_atom(module) do
    cond do
      not Code.ensure_loaded?(module) ->
        {:error, {:invalid_codec, :module_not_loaded}}

      missing =
          Enum.find(@required_callbacks, fn {name, arity} ->
            not function_exported?(module, name, arity)
          end) ->
        {:error, {:invalid_codec, {:missing_callback, missing}}}

      true ->
        :ok
    end
  end

  defp validate_module(_module), do: {:error, {:invalid_codec, :module_must_be_an_atom}}

  defp read_metadata(module, options) do
    try do
      declared_canonical = module.canonical_name()
      canonical = Keyword.get(options, :canonical, declared_canonical)
      module_aliases = optional_metadata(module, :aliases, [])
      aliases = module_aliases ++ Keyword.get(options, :aliases, [])
      stateful? = optional_metadata(module, :stateful?, false)
      codec_id = optional_metadata(module, :codec_id, module)
      decode_error_recovery = optional_metadata(module, :decode_error_recovery, :resynchronize)

      with :ok <- validate_names(canonical, aliases) do
        cond do
          not is_boolean(stateful?) ->
            {:error, {:invalid_codec, :stateful_must_be_boolean}}

          not is_atom(codec_id) ->
            {:error, {:invalid_codec, :codec_id_must_be_an_atom}}

          decode_error_recovery not in [:resynchronize, :stop] ->
            {:error, {:invalid_codec, :invalid_decode_error_recovery}}

          true ->
            names = [canonical | aliases] |> Enum.map(&normalize/1) |> Enum.uniq()
            normalized_canonical = normalize(canonical)

            {:ok,
             %{
               canonical: canonical,
               names: names,
               claim_kinds:
                 Map.new(names, fn name ->
                   {name, if(name == normalized_canonical, do: :canonical, else: :alias)}
                 end),
               stateful?: stateful?,
               codec_id: codec_id,
               decode_error_recovery: decode_error_recovery
             }}
        end
      end
    rescue
      exception -> {:error, {:invalid_codec, {:metadata_exception, Exception.message(exception)}}}
    catch
      kind, reason -> {:error, {:invalid_codec, {:metadata_throw, {kind, reason}}}}
    end
  end

  defp optional_metadata(module, callback, default) do
    case ExternalCallbacks.call(module, callback, []) do
      {:called, value} -> value
      :missing -> default
    end
  end

  defp validate_names(canonical, aliases) when is_list(aliases) do
    case Enum.find([canonical | aliases], &(not valid_name?(&1))) do
      nil -> :ok
      invalid -> {:error, {:invalid_codec, {:invalid_name, invalid}}}
    end
  end

  defp validate_names(_canonical, _aliases),
    do: {:error, {:invalid_codec, :aliases_must_be_a_list}}

  defp valid_name?(name) when is_binary(name) do
    byte_size(name) > 0 and not String.contains?(name, "/") and
      String.match?(name, ~r/^[\x21-\x7e]+$/)
  end

  defp valid_name?(_name), do: false

  defp ensure_names_available(entry, existing_claims_by_name) do
    Enum.reduce_while(entry.names, :ok, fn normalized, :ok ->
      cond do
        match?({:ok, _entry}, Registry.builtin_resolve(normalized)) ->
          {:halt, {:error, {:name_conflict, normalized}}}

        existing_claims_by_name
        |> Map.get(normalized, [])
        |> Enum.any?(&(&1.module != entry.codec)) ->
          {:halt, {:error, {:name_conflict, normalized}}}

        true ->
          {:cont, :ok}
      end
    end)
  end

  defp entry_claims(entry) do
    {mode, owner, priority} = claim_registration_metadata(entry)

    Enum.map(entry.names, fn name ->
      %{
        name: name,
        module: entry.codec,
        kind: Map.fetch!(entry.claim_kinds, name),
        mode: mode,
        owner: owner,
        priority: priority,
        token: entry.registration_token
      }
    end)
  end

  defp claim_registration_metadata(%{registration_mode: {:managed, owner, priority}}),
    do: {:managed, owner, priority}

  defp claim_registration_metadata(_strict_or_legacy), do: {:strict, nil, 0}

  defp claim_row(claim), do: {{:claim, claim.name, claim.module}, claim}

  defp claims_for_names([]), do: %{}

  defp claims_for_names(names) do
    selected_names = MapSet.new(names)

    safe_match({{:claim, :"$1", :_}, :"$2"})
    |> Enum.reduce(%{}, fn
      [name, claim], acc when is_map(claim) ->
        if MapSet.member?(selected_names, name) do
          Map.update(acc, name, [claim], &[claim | &1])
        else
          acc
        end

      _invalid_or_deleted, acc ->
        acc
    end)
    |> Map.new(fn {name, reversed} -> {name, :lists.reverse(reversed)} end)
  end

  defp claim_rank(%{kind: kind, priority: priority}) do
    {if(kind == :canonical, do: 1, else: 0), priority}
  end

  defp winner_for_claims(claims) do
    Enum.max_by(claims, &claim_rank/1)
  end

  defp lookup(name) when is_binary(name), do: lookup({:name, name})

  defp lookup({:name, name} = key) do
    case safe_lookup(key) do
      [{^key, module}] when is_atom(module) ->
        resolve_name_through_module(name, module)

      # Supports a table inherited from a pre-ownership-index code version.
      [{^key, %{codec: module}}] ->
        resolve_name_through_module(name, module)

      [{^key, :deleted}] ->
        :error

      [] ->
        :error
    end
  end

  defp lookup(key) do
    case safe_lookup(key) do
      [{^key, :deleted}] -> :error
      [{^key, entry}] -> {:ok, entry}
      [] -> :error
    end
  end

  defp delete_codec(module) do
    case lookup({:module, module}) do
      {:ok, entry} ->
        registration_rows = registration_rows_without_module(entry, module)
        commit_entry_removal([entry], registration_rows)

      :error ->
        :ok
    end
  end

  defp delete_registration_set(token) do
    case lookup({:set, token}) do
      {:ok, %{status: :committed, modules: modules}} ->
        entries =
          Enum.flat_map(modules, fn module ->
            case lookup({:module, module}) do
              {:ok, %{registration_token: ^token} = entry} -> [entry]
              _missing_or_replaced -> []
            end
          end)

        commit_entry_removal(entries, [{{:set, token}, :deleted}])

      _missing_or_incomplete ->
        :ok
    end
  end

  defp commit_entry_removal(entries, registration_rows) do
    removed_modules = MapSet.new(entries, & &1.codec)
    affected_names = entries |> Enum.flat_map(& &1.names) |> Enum.uniq()
    existing_claims_by_name = claims_for_names(affected_names)

    name_rows =
      Enum.map(affected_names, fn name ->
        remaining_claims =
          existing_claims_by_name
          |> Map.get(name, [])
          |> Enum.reject(&MapSet.member?(removed_modules, &1.module))

        case remaining_claims do
          [] -> {{:name, name}, :deleted}
          claims -> {{:name, name}, winner_for_claims(claims).module}
        end
      end)

    claim_rows =
      for entry <- entries, name <- entry.names do
        {{:claim, name, entry.codec}, :deleted}
      end

    module_rows = Enum.map(entries, &{{:module, &1.codec}, :deleted})
    objects = module_rows ++ claim_rows ++ name_rows ++ registration_rows

    if objects != [] do
      RouteSnapshot.with_update(fn ->
        true = :ets.insert(__MODULE__, objects)
        delete_tombstones(objects)
      end)

      :ok = checkpoint_recovery_state()
    end

    :ok
  end

  defp delete_tombstones(objects) do
    Enum.each(objects, fn {key, value} ->
      if value == :deleted and safe_lookup(key) == [{key, :deleted}] do
        :ets.delete(__MODULE__, key)
      end
    end)
  end

  defp registration_rows_without_module(
         %{registration_mode: {:managed, _owner, _priority}, registration_token: token},
         module
       ) do
    case lookup({:set, token}) do
      {:ok, %{status: :committed, modules: modules} = registration} ->
        [{{:set, token}, %{registration | modules: List.delete(modules, module)}}]

      _missing_or_replaced ->
        []
    end
  end

  defp registration_rows_without_module(_strict_or_legacy, _module), do: []

  defp call(message) do
    if Process.whereis(__MODULE__) do
      # A timeout does not cancel a queued GenServer request. Waiting for the
      # authoritative reply prevents a delayed unconditional delete from
      # surprising a caller that already observed a timeout.
      GenServer.call(__MODULE__, message, :infinity)
    else
      {:error, :registry_not_started}
    end
  end

  defp registration_call(module, token, message_builder) do
    case Process.whereis(__MODULE__) do
      registry when is_pid(registry) ->
        call_registration_worker(
          registry,
          module,
          token,
          message_builder,
          :initial,
          registration_restart_attempts(),
          nil
        )

      nil ->
        {:error, :registry_not_started}
    end
  end

  defp registration_set_call(registrations, options, token) do
    case Process.whereis(__MODULE__) do
      registry when is_pid(registry) ->
        call_registration_set_worker(
          registry,
          registrations,
          options,
          token,
          :initial,
          registration_restart_attempts(),
          nil
        )

      nil ->
        {:error, :registry_not_started}
    end
  end

  defp call_registration_set_worker(
         registry,
         registrations,
         options,
         token,
         attempt,
         attempts,
         last_exit
       ) do
    try do
      GenServer.call(
        registry,
        {:register_set, registrations, options, token, attempt},
        :infinity
      )
    catch
      :exit, reason ->
        if Process.alive?(registry) do
          exit(reason)
        else
          retry_registration_set(
            registrations,
            options,
            token,
            attempts,
            reason || last_exit
          )
        end
    end
  end

  defp retry_registration_set(_registrations, _options, token, 0, last_exit) do
    case committed_set(token) do
      {:ok, ^token} = committed -> committed
      :error -> {:error, {:registry_restart_timeout, last_exit}}
    end
  end

  defp retry_registration_set(registrations, options, token, attempts, last_exit) do
    case committed_set(token) do
      {:ok, ^token} = committed ->
        committed

      :error ->
        case Process.whereis(__MODULE__) do
          registry when is_pid(registry) ->
            call_registration_set_worker(
              registry,
              registrations,
              options,
              token,
              :retry,
              attempts - 1,
              last_exit
            )

          nil ->
            Process.sleep(1)
            retry_registration_set(registrations, options, token, attempts - 1, last_exit)
        end
    end
  end

  defp owned_set_unregistration_call(token), do: continue_owned_set_unregistration(token)

  defp continue_owned_set_unregistration(token) do
    case committed_set(token) do
      :error ->
        :ok

      {:ok, ^token} ->
        case Process.whereis(__MODULE__) do
          registry when is_pid(registry) ->
            try do
              GenServer.call(registry, {:unregister_set, token}, :infinity)
            catch
              :exit, _reason -> continue_owned_set_unregistration(token)
            end

          nil ->
            unregister_set_through_heir(token)
        end
    end
  end

  defp unregister_set_through_heir(token) do
    case Process.whereis(Heir) do
      heir when is_pid(heir) ->
        try do
          case Heir.unregister_set(token) do
            :ok -> :ok
            :not_owner -> retry_set_unregistration_after_transition(token)
          end
        catch
          :exit, _reason -> retry_set_unregistration_after_transition(token)
        end

      nil ->
        retry_set_unregistration_after_transition(token)
    end
  end

  defp retry_set_unregistration_after_transition(token) do
    Process.sleep(1)
    continue_owned_set_unregistration(token)
  end

  defp owned_unregistration_call(module, token) do
    continue_owned_unregistration(module, token)
  end

  defp continue_owned_unregistration(module, token) do
    case committed_registration(module, token) do
      :error ->
        # The owned registration was removed or replaced. In either case this
        # caller no longer owns anything and must not delete a replacement.
        :ok

      {:ok, ^token} ->
        case Process.whereis(__MODULE__) do
          registry when is_pid(registry) ->
            try do
              # As with registration, a finite timeout would not cancel this
              # ownership-changing call and would make its outcome ambiguous.
              GenServer.call(registry, {:unregister, module, token}, :infinity)
            catch
              :exit, _reason -> continue_owned_unregistration(module, token)
            end

          nil ->
            unregister_owned_through_heir(module, token)
        end
    end
  end

  defp unregister_owned_through_heir(module, token) do
    case Process.whereis(Heir) do
      heir when is_pid(heir) ->
        try do
          case Heir.unregister_owned(module, token) do
            :ok -> :ok
            :not_owner -> retry_owned_unregistration_after_transition(module, token)
          end
        catch
          :exit, _reason -> retry_owned_unregistration_after_transition(module, token)
        end

      nil ->
        retry_owned_unregistration_after_transition(module, token)
    end
  end

  defp retry_owned_unregistration_after_transition(module, token) do
    Process.sleep(1)
    continue_owned_unregistration(module, token)
  end

  defp call_registration_worker(
         registry,
         module,
         token,
         message_builder,
         attempt,
         attempts,
         last_exit
       ) do
    try do
      # A finite GenServer timeout does not cancel a queued call. The registry
      # could commit after the caller timed out, permanently hiding its cleanup
      # token, so ownership-changing calls wait for a reply or worker death.
      GenServer.call(registry, message_builder.(attempt), :infinity)
    catch
      :exit, reason ->
        if Process.alive?(registry) do
          exit(reason)
        else
          retry_registration(module, token, message_builder, attempts, reason || last_exit)
        end
    end
  end

  defp retry_registration(module, token, _message_builder, 0, last_exit) do
    case committed_registration(module, token) do
      {:ok, ^token} = committed -> committed
      :error -> {:error, {:registry_restart_timeout, last_exit}}
    end
  end

  defp retry_registration(module, token, message_builder, attempts, last_exit) do
    case committed_registration(module, token) do
      {:ok, ^token} = committed ->
        committed

      :error ->
        case Process.whereis(__MODULE__) do
          registry when is_pid(registry) ->
            call_registration_worker(
              registry,
              module,
              token,
              message_builder,
              :retry,
              attempts - 1,
              last_exit
            )

          nil ->
            Process.sleep(1)
            retry_registration(module, token, message_builder, attempts - 1, last_exit)
        end
    end
  end

  if Mix.env() == :test do
    defp registration_restart_attempts do
      case Process.get({__MODULE__, :registration_restart_attempts}) do
        attempts when is_integer(attempts) and attempts > 0 -> attempts
        _unset_or_invalid -> @default_registration_restart_attempts
      end
    end
  else
    defp registration_restart_attempts, do: @default_registration_restart_attempts
  end

  defp committed_registration(module, token) do
    case lookup({:module, module}) do
      {:ok, %{registration_token: ^token}} -> {:ok, token}
      _missing_or_replaced -> :error
    end
  end

  defp registration_identity(module) when is_atom(module) do
    module
    |> then(&lookup({:module, &1}))
    |> registration_identity_from_lookup()
  end

  defp registration_identity(_invalid_module), do: :missing

  defp registration_identity_from_lookup({:ok, %{registration_token: token}}),
    do: {:registered, token}

  defp registration_identity_from_lookup(:error), do: :missing

  defp committed_set(token) do
    case lookup({:set, token}) do
      {:ok, %{status: :committed}} -> {:ok, token}
      _missing_or_incomplete -> :error
    end
  end

  defp safe_lookup(key) do
    try do
      :ets.lookup(__MODULE__, key)
    rescue
      ArgumentError -> []
    catch
      :error, :badarg -> []
    end
  end

  defp safe_match(pattern) do
    try do
      :ets.match(__MODULE__, pattern)
    rescue
      ArgumentError -> []
    catch
      :error, :badarg -> []
    end
  end

  defp normalize(name), do: String.upcase(name, :ascii)

  defp create_table do
    heir = Process.whereis(Heir)

    options = [:named_table, :protected, read_concurrency: true]
    options = if is_pid(heir), do: [{:heir, heir, @heir_data} | options], else: options
    :ets.new(__MODULE__, options)
  end

  defp restore_recovery_state do
    case :persistent_term.get(@recovery_snapshot_key, :missing) do
      {@recovery_snapshot_version, rows} when is_list(rows) ->
        true = :ets.insert(__MODULE__, rows)
        :ok

      _missing_or_incompatible ->
        :ok
    end
  end

  defp finish_init(:ok) do
    :ok = checkpoint_recovery_state()
    {:ok, %{}}
  end

  defp finish_init({:error, reason}), do: {:stop, {:invalid_external_codec, reason}}

  defp current_entry(module) do
    case lookup({:module, module}) do
      {:ok, entry} -> entry
      :error -> nil
    end
  end

  defp resolve_name_through_module(name, module),
    do: resolve_name_through_module(name, module, 3)

  defp resolve_name_through_module(name, module, retries_left) do
    run_after_name_lookup_hook(name, module)

    case lookup({:module, module}) do
      {:ok, entry} ->
        if entry_claims_name?(entry, name) do
          {:ok, entry}
        else
          retry_changed_name_winner(name, module, retries_left)
        end

      :error ->
        retry_changed_name_winner(name, module, retries_left)
    end
  end

  defp retry_changed_name_winner(_name, _previous_module, 0), do: :error

  defp retry_changed_name_winner(name, previous_module, retries_left) do
    case safe_lookup({:name, name}) do
      [{{:name, ^name}, module}] when is_atom(module) and module != previous_module ->
        resolve_name_through_module(name, module, retries_left - 1)

      [{{:name, ^name}, %{codec: module}}] when module != previous_module ->
        resolve_name_through_module(name, module, retries_left - 1)

      _unchanged_or_removed ->
        :error
    end
  end

  if Mix.env() == :test do
    defp run_after_name_lookup_hook(name, module) do
      case Process.get({__MODULE__, :after_name_lookup}) do
        {owner, reference} when is_pid(owner) and is_reference(reference) ->
          Process.delete({__MODULE__, :after_name_lookup})
          send(owner, {:external_registry_name_read, self(), name, module, reference})

          receive do
            {:continue_external_registry_name_read, ^reference} -> :ok
          end

        _unset ->
          :ok
      end
    end
  else
    defp run_after_name_lookup_hook(_name, _module), do: :ok
  end

  defp entry_claims_name?(%{name_index: name_index}, name),
    do: MapSet.member?(name_index, name)

  defp entry_claims_name?(entry, name), do: name in entry.names

  defp repair_name_index do
    __MODULE__
    |> :ets.tab2list()
    |> Enum.each(fn
      {{:module, _module} = key, :deleted} -> :ets.delete(__MODULE__, key)
      {{:set, _token} = key, :deleted} -> :ets.delete(__MODULE__, key)
      _durable_row -> :ok
    end)

    entries =
      __MODULE__
      |> :ets.match({{:module, :_}, :"$1"})
      |> Enum.map(&hd/1)
      |> Enum.filter(&is_map/1)
      |> Enum.map(&normalize_entry_for_repair/1)

    claims = Enum.flat_map(entries, &entry_claims/1)

    winner_rows =
      claims
      |> Enum.group_by(& &1.name)
      |> Enum.map(fn {name, name_claims} ->
        {{:name, name}, winner_for_claims(name_claims).module}
      end)

    valid_claim_keys = MapSet.new(claims, fn claim -> {:claim, claim.name, claim.module} end)
    valid_name_keys = MapSet.new(winner_rows, &elem(&1, 0))

    true =
      :ets.insert(
        __MODULE__,
        Enum.map(entries, &{{:module, &1.codec}, &1}) ++
          Enum.map(claims, &claim_row/1) ++ winner_rows
      )

    __MODULE__
    |> :ets.tab2list()
    |> Enum.each(fn
      {{:claim, _name, _module} = key, _value} ->
        unless MapSet.member?(valid_claim_keys, key), do: :ets.delete(__MODULE__, key)

      {{:name, _name} = key, _value} ->
        unless MapSet.member?(valid_name_keys, key), do: :ets.delete(__MODULE__, key)

      _durable_row ->
        :ok
    end)

    repair_set_indexes(entries)
  end

  defp normalize_entry_for_repair(entry) do
    names = Enum.uniq(entry.names)
    normalized_canonical = normalize(entry.canonical)

    entry
    |> Map.put(:names, names)
    |> Map.put(:name_index, MapSet.new(names))
    |> Map.put_new(:registration_mode, :strict)
    |> Map.put_new(
      :claim_kinds,
      Map.new(names, fn name ->
        {name, if(name == normalized_canonical, do: :canonical, else: :alias)}
      end)
    )
  end

  defp repair_set_indexes(entries) do
    managed_by_token =
      entries
      |> Enum.filter(&match?(%{registration_mode: {:managed, _, _}}, &1))
      |> Enum.group_by(& &1.registration_token)

    __MODULE__
    |> :ets.match({{:set, :"$1"}, :"$2"})
    |> Enum.each(fn
      [token, %{status: :committed} = registration] ->
        modules = managed_by_token |> Map.get(token, []) |> Enum.map(& &1.codec)
        :ets.insert(__MODULE__, {{:set, token}, %{registration | modules: modules}})

      [token, _invalid_or_pending] ->
        :ets.delete(__MODULE__, {:set, token})
    end)

    Enum.each(managed_by_token, fn {token, token_entries} ->
      if lookup({:set, token}) == :error do
        [{:managed, owner, priority} | _rest] =
          Enum.map(token_entries, & &1.registration_mode)

        :ets.insert(
          __MODULE__,
          {{:set, token},
           %{
             status: :committed,
             owner: owner,
             priority: priority,
             modules: Enum.map(token_entries, & &1.codec)
           }}
        )
      end
    end)
  end

  defp rollback_pending_sets do
    # Compatibility with inherited ETS tables from the earlier two-phase set
    # writer: a registry can receive one of these rows from its Heir during a
    # rolling upgrade or a crash between prepare and commit.
    __MODULE__
    |> :ets.match({{:set, :"$1"}, :"$2"})
    |> Enum.each(fn
      [token, %{status: :pending, modules: modules}] ->
        Enum.each(modules, fn module ->
          case safe_lookup({:module, module}) do
            [{{:module, ^module}, %{registration_token: ^token}}] ->
              :ets.delete(__MODULE__, {:module, module})

            _missing_or_replaced ->
              :ok
          end
        end)

        :ets.delete(__MODULE__, {:set, token})

      _committed_or_unrelated ->
        :ok
    end)
  end

  if Mix.env() == :test do
    defp run_after_commit_hook(%{after_commit: {owner, reference}}, module)
         when is_pid(owner) and is_reference(reference) do
      send(owner, {:external_registry_committed, self(), module, reference})

      receive do
        {:continue_external_registry, ^reference} -> :ok
      end
    end

    defp run_after_commit_hook(_state, _module), do: :ok
  else
    defp run_after_commit_hook(_state, _module), do: :ok
  end
end
