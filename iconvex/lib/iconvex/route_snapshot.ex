defmodule Iconvex.RouteSnapshot do
  @moduledoc false

  @clock_key {__MODULE__, :clock}
  @lock_context_key {__MODULE__, :lock_context}
  @owner_key {__MODULE__, :owner}
  @update_context_key {__MODULE__, :update_context}
  @missing {__MODULE__, :missing}

  @doc false
  def generation do
    clock = clock()
    {clock, :atomics.get(clock, 1)}
  end

  @doc false
  def generation_current?({clock, generation}) when is_reference(clock) do
    active_before = :atomics.get(clock, 2)
    generation_before = :atomics.get(clock, 1)
    active_after = :atomics.get(clock, 2)
    generation_after = :atomics.get(clock, 1)

    :persistent_term.get(@clock_key, @missing) == clock and active_before == 0 and
      active_after == 0 and generation_before == generation and generation_after == generation
  end

  def generation_current?(_invalid), do: false

  @doc false
  def lock_held?, do: Process.get(@lock_context_key, false) == true

  @doc false
  def with_update(function) when is_function(function, 0) do
    case Process.get(@update_context_key, false) do
      true ->
        function.()

      false ->
        with_route_lock(fn ->
          clock = clock()
          repair_abandoned_update(clock)
          :persistent_term.put(@owner_key, {clock, self()})
          :atomics.add_get(clock, 2, 1)
          Process.put(@update_context_key, true)

          try do
            run_after_invalidate_hook()
            function.()
          after
            Process.delete(@update_context_key)
            :atomics.add_get(clock, 1, 1)
            :atomics.add_get(clock, 2, -1)
            :persistent_term.erase(@owner_key)
          end
        end)
    end
  end

  @doc false
  def serialized(function) when is_function(function, 0) do
    case lock_held?() do
      true ->
        function.()

      false ->
        with_route_lock(fn ->
          clock = clock()
          repair_abandoned_update(clock)
          function.()
        end)
    end
  end

  defp clock do
    case :persistent_term.get(@clock_key, @missing) do
      clock when is_reference(clock) ->
        clock

      @missing ->
        :global.trans({{@clock_key, :initialize}, self()}, fn ->
          case :persistent_term.get(@clock_key, @missing) do
            clock when is_reference(clock) ->
              clock

            @missing ->
              clock = :atomics.new(2, signed: false)
              :persistent_term.put(@clock_key, clock)
              clock
          end
        end)
    end
  end

  defp repair_abandoned_update(clock) do
    if :atomics.get(clock, 2) != 0 do
      case :persistent_term.get(@owner_key, @missing) do
        {^clock, owner} when owner == self() ->
          raise "nested route update"

        _abandoned ->
          close_abandoned_update(clock)
      end
    end
  end

  defp close_abandoned_update(clock) do
    :atomics.add_get(clock, 1, 1)
    run_abandoned_close_hook()
    :atomics.put(clock, 2, 0)
    :persistent_term.erase(@owner_key)
    :ok
  end

  defp with_route_lock(function) do
    :global.trans({{__MODULE__, :route_update}, self()}, fn ->
      previous = Process.get(@lock_context_key, @missing)
      Process.put(@lock_context_key, true)

      try do
        function.()
      after
        restore_lock_context(previous)
      end
    end)
  end

  defp restore_lock_context(@missing), do: Process.delete(@lock_context_key)
  defp restore_lock_context(previous), do: Process.put(@lock_context_key, previous)

  if Mix.env() == :test do
    defp run_after_invalidate_hook do
      case Process.get({__MODULE__, :after_invalidate}) do
        {owner, reference} when is_pid(owner) and is_reference(reference) ->
          Process.delete({__MODULE__, :after_invalidate})
          send(owner, {:iconvex_route_update_invalid, self(), reference})

          receive do
            {:continue_iconvex_route_update, ^reference} -> :ok
          end

        _unset ->
          :ok
      end
    end

    defp run_abandoned_close_hook do
      case Process.get({__MODULE__, :abandoned_close_barrier}) do
        {owner, reference} when is_pid(owner) and is_reference(reference) ->
          Process.delete({__MODULE__, :abandoned_close_barrier})
          send(owner, {:iconvex_abandoned_route_close_barrier, self(), reference})

          receive do
            {:continue_iconvex_abandoned_route_close, ^reference} -> :ok
          end

        _unset ->
          :ok
      end
    end
  else
    defp run_after_invalidate_hook, do: :ok
    defp run_abandoned_close_hook, do: :ok
  end
end
