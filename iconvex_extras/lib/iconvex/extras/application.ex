defmodule Iconvex.Extras.Application do
  @moduledoc false
  use Application

  @provider :euc_jisx0213
  @provider_app :iconvex_extras
  @registry_priority 100

  @impl true
  def start(_type, _args) do
    case register_provider() do
      {:ok, provider_token} ->
        start_with_provider(provider_token)

      error ->
        error
    end
  end

  @impl true
  def stop(%{codec_token: codec_token, provider_token: provider_token}) do
    unregister_codecs(codec_token)
    unregister_provider(provider_token)
    :ok
  end

  def stop(_state), do: :ok

  defp start_with_provider(provider_token) do
    case register_codecs() do
      {:ok, codec_token} ->
        case Supervisor.start_link([], strategy: :one_for_one) do
          {:ok, supervisor} ->
            {:ok, supervisor, %{codec_token: codec_token, provider_token: provider_token}}

          error ->
            rollback_start(codec_token, provider_token)
            error
        end

      {:error, error} ->
        rollback_start(nil, provider_token)
        {:error, error}
    end
  end

  defp register_provider do
    case Iconvex.Tables.register_provider_owned(@provider, @provider_app) do
      {:ok, :existing} -> {:ok, nil}
      {:ok, token} -> {:ok, token}
      error -> error
    end
  end

  defp register_codecs do
    Iconvex.ExternalRegistry.register_set_owned(Iconvex.Extras.codecs(),
      owner: @provider_app,
      priority: @registry_priority
    )
  end

  defp rollback_start(codec_token, provider_token) do
    unregister_codecs(codec_token)
    unregister_provider(provider_token)
  end

  defp unregister_codecs(token) when is_reference(token),
    do: Iconvex.ExternalRegistry.unregister_set(token)

  defp unregister_codecs(nil), do: :ok

  defp unregister_provider(token) when is_reference(token),
    do: Iconvex.Tables.unregister_provider(@provider, @provider_app, token)

  defp unregister_provider(nil), do: :ok
end
