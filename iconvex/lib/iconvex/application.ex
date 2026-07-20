defmodule Iconvex.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    configured_codecs = Application.get_env(:iconvex, :external_codecs, [])

    Supervisor.start_link(
      [
        {Iconvex.ExternalRegistry.Heir, []},
        {Iconvex.ExternalRegistry, configured_codecs}
      ],
      strategy: :one_for_one
    )
  end

  @impl true
  def stop(_state) do
    Iconvex.ExternalRegistry.clear_recovery_snapshot()
    :ok
  end
end
