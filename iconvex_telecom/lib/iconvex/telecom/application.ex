defmodule Iconvex.Telecom.Application do
  @moduledoc false
  use Application

  @registry_priority 0

  @impl true
  def start(_type, _args) do
    case register_codecs() do
      {:ok, codec_token} ->
        case Supervisor.start_link([], strategy: :one_for_one) do
          {:ok, supervisor} ->
            {:ok, supervisor, %{codec_token: codec_token}}

          error ->
            unregister_codecs(codec_token)
            error
        end

      {:error, error} ->
        {:error, error}
    end
  end

  @impl true
  def stop(%{codec_token: codec_token}) do
    unregister_codecs(codec_token)
    :ok
  end

  def stop(_state), do: :ok

  defp register_codecs do
    Iconvex.ExternalRegistry.register_set_owned(Iconvex.Telecom.codecs(),
      owner: :iconvex_telecom,
      priority: @registry_priority
    )
  end

  defp unregister_codecs(token), do: Iconvex.ExternalRegistry.unregister_set(token)
end
