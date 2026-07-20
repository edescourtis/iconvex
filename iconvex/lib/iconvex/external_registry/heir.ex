defmodule Iconvex.ExternalRegistry.Heir do
  @moduledoc false
  use GenServer

  alias Iconvex.RouteSnapshot

  @table Iconvex.ExternalRegistry

  def start_link(_options), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  def take_table(new_owner) when is_pid(new_owner) do
    GenServer.call(__MODULE__, {:take_table, new_owner})
  end

  def unregister_owned(module, token) when is_atom(module) and is_reference(token) do
    GenServer.call(__MODULE__, {:unregister_owned, module, token}, :infinity)
  end

  def unregister_set(token) when is_reference(token) do
    GenServer.call(__MODULE__, {:unregister_set, token}, :infinity)
  end

  @impl true
  def init(:ok) do
    # Installation is deliberately asynchronous. A synchronous call leaves a
    # replacement heir stuck in init while a surviving registry is suspended;
    # if that registry then dies, both children can exhaust the supervisor's
    # restart intensity before either becomes available to the other.
    case Process.whereis(Iconvex.ExternalRegistry) do
      registry when is_pid(registry) ->
        GenServer.cast(registry, {:install_heir, self()})

      nil ->
        :ok
    end

    {:ok, nil}
  end

  @impl true
  def handle_call({:take_table, new_owner}, {caller, _tag}, state) do
    result =
      if is_pid(new_owner) and caller == new_owner and
           Process.whereis(Iconvex.ExternalRegistry) == new_owner do
        do_take_table(new_owner)
      else
        {:error, :unauthorized_registry_owner}
      end

    {:reply, result, state}
  end

  def handle_call({:unregister_owned, module, token}, _from, state) do
    result =
      if :ets.info(@table, :owner) == self() do
        delete_if_owned(module, token)
      else
        :not_owner
      end

    {:reply, result, state}
  end

  def handle_call({:unregister_set, token}, _from, state) do
    result =
      if :ets.info(@table, :owner) == self() do
        delete_set_if_owned(token)
      else
        :not_owner
      end

    {:reply, result, state}
  end

  @impl true
  def handle_info({:"ETS-TRANSFER", _table, _from, :registry_heir}, state),
    do: {:noreply, state}

  def handle_info(_unrelated_message, state), do: {:noreply, state}

  defp do_take_table(new_owner) do
    case :ets.whereis(@table) do
      :undefined ->
        :missing

      table ->
        case :ets.info(table, :owner) do
          owner when owner == self() ->
            true = :ets.give_away(table, new_owner, :registry_reclaimed)
            :transferred

          ^new_owner ->
            :already_owned

          owner ->
            {:error, {:unexpected_registry_table_owner, owner}}
        end
    end
  end

  defp delete_if_owned(module, token) do
    key = {:module, module}

    case :ets.lookup(@table, key) do
      [{^key, %{registration_token: ^token} = entry}] ->
        registration_rows = registration_rows_without_module(entry, module)
        commit_entry_removal([entry], registration_rows)

      _missing_or_replaced ->
        :ok
    end
  end

  defp delete_set_if_owned(token) do
    key = {:set, token}

    case :ets.lookup(@table, key) do
      [{^key, %{status: :committed, modules: modules}}] ->
        entries =
          Enum.flat_map(modules, fn module ->
            module_key = {:module, module}

            case :ets.lookup(@table, module_key) do
              [{^module_key, %{registration_token: ^token} = entry}] -> [entry]
              _missing_or_replaced -> []
            end
          end)

        commit_entry_removal(entries, [{key, :deleted}])

      _missing_or_replaced ->
        :ok
    end
  end

  defp commit_entry_removal(entries, registration_rows) do
    removed_modules = MapSet.new(entries, & &1.codec)
    affected_names = entries |> Enum.flat_map(& &1.names) |> Enum.uniq()

    name_rows =
      Enum.map(affected_names, fn name ->
        remaining_claims =
          name
          |> claims_for_name()
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
        true = :ets.insert(@table, objects)
        delete_tombstones(objects)
      end)

      :ok = Iconvex.ExternalRegistry.checkpoint_recovery_state()
    end

    :ok
  end

  defp delete_tombstones(objects) do
    Enum.each(objects, fn {key, value} ->
      if value == :deleted and :ets.lookup(@table, key) == [{key, :deleted}] do
        :ets.delete(@table, key)
      end
    end)
  end

  defp registration_rows_without_module(
         %{registration_mode: {:managed, _owner, _priority}, registration_token: token},
         module
       ) do
    key = {:set, token}

    case :ets.lookup(@table, key) do
      [{^key, %{status: :committed, modules: modules} = registration}] ->
        [{key, %{registration | modules: List.delete(modules, module)}}]

      _missing_or_replaced ->
        []
    end
  end

  defp registration_rows_without_module(_strict_or_legacy, _module), do: []

  defp claims_for_name(name) do
    @table
    |> :ets.match({{:claim, name, :_}, :"$1"})
    |> Enum.map(&hd/1)
    |> Enum.filter(&is_map/1)
  end

  defp winner_for_claims(claims) do
    Enum.max_by(claims, fn claim ->
      {if(claim.kind == :canonical, do: 1, else: 0), claim.priority}
    end)
  end
end
