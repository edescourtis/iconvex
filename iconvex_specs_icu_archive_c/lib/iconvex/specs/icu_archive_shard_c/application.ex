defmodule Iconvex.Specs.ICUArchiveShardC.Application do
  @moduledoc false
  use Application

  @ids for index <- 701..1050, do: String.to_atom("icu_archive_#{index}")
  @impl true
  def start(_type, _args) do
    case register_providers() do
      {:ok, providers} ->
        case Supervisor.start_link([], strategy: :one_for_one) do
          {:ok, supervisor} ->
            {:ok, supervisor, providers}

          error ->
            unregister_providers(providers)
            error
        end

      {:error, reason, providers} ->
        unregister_providers(providers)
        {:error, reason}
    end
  end

  @impl true
  def stop(providers) when is_list(providers) do
    unregister_providers(providers)
    :ok
  end

  def stop(_state), do: :ok

  defp register_providers do
    Enum.reduce_while(@ids, {:ok, []}, fn id, {:ok, owned} ->
      case Iconvex.Tables.register_provider_owned(id, :iconvex_specs_icu_archive_c) do
        {:ok, :existing} ->
          {:cont, {:ok, owned}}

        {:ok, token} when is_reference(token) ->
          {:cont, {:ok, [{id, token} | owned]}}

        {:error, reason} ->
          {:halt, {:error, reason, owned}}
      end
    end)
  end

  defp unregister_providers(providers) do
    Enum.each(providers, fn {id, token} ->
      Iconvex.Tables.unregister_provider(id, :iconvex_specs_icu_archive_c, token)
    end)
  end
end
