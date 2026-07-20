defmodule Iconvex.Specs.Application do
  @moduledoc false
  use Application

  @registry_priority 0

  @impl true
  def start(_type, _args) do
    case register_providers() do
      {:ok, providers} ->
        start_with_providers(providers)

      {:error, reason, providers} ->
        unregister_providers(providers)
        {:error, reason}
    end
  end

  @impl true
  def stop(%{codec_token: codec_token, providers: providers}) do
    unregister_codecs(codec_token)
    unregister_providers(providers)
    :ok
  end

  def stop(_state), do: :ok

  defp start_with_providers(providers) do
    case register_codecs() do
      {:ok, codec_token} ->
        case Supervisor.start_link([], strategy: :one_for_one) do
          {:ok, supervisor} ->
            {:ok, supervisor, %{codec_token: codec_token, providers: providers}}

          error ->
            unregister_codecs(codec_token)
            unregister_providers(providers)
            error
        end

      {:error, reason} ->
        unregister_providers(providers)
        {:error, reason}
    end
  end

  defp register_codecs do
    registrations =
      Enum.map(Iconvex.Specs.registrations(), fn registration ->
        {registration.codec, canonical: registration.canonical, aliases: registration.aliases}
      end)

    Iconvex.ExternalRegistry.register_set_owned(registrations,
      owner: :iconvex_specs,
      priority: @registry_priority
    )
  end

  defp unregister_codecs(token), do: Iconvex.ExternalRegistry.unregister_set(token)

  defp register_providers do
    provider_entries()
    |> Enum.uniq_by(& &1.id)
    |> Enum.reduce_while({:ok, []}, fn entry, {:ok, owned} ->
      case Iconvex.Tables.register_provider_owned(entry.id, :iconvex_specs) do
        {:ok, :existing} ->
          {:cont, {:ok, owned}}

        {:ok, token} when is_reference(token) ->
          {:cont, {:ok, [{entry.id, token} | owned]}}

        {:error, reason} ->
          {:halt, {:error, reason, owned}}
      end
    end)
  end

  defp unregister_providers(providers) do
    Enum.each(providers, fn {id, token} ->
      Iconvex.Tables.unregister_provider(id, :iconvex_specs, token)
    end)
  end

  defp provider_entries do
    (Iconvex.Specs.RFC1345.encodings() ++
       Iconvex.Specs.VendorMappings.encodings() ++
       Iconvex.Specs.GlibcCharmaps.encodings() ++
       Iconvex.Specs.ICUUCM.encodings() ++
       Iconvex.Specs.ICUMultibyte.encodings() ++
       Iconvex.Specs.ICUEBCDICStateful.encodings() ++
       Iconvex.Specs.ICUSwapLFNL.encodings() ++
       Iconvex.Specs.WindowsBestFit.encodings() ++
       Iconvex.Specs.UnicodeLegacyMappings.encodings() ++
       Iconvex.Specs.UnicodeMappingComponents.encodings() ++
       Iconvex.Specs.UnicodeMisc.encodings() ++
       Iconvex.Specs.ISOIRModern.encodings() ++
       Iconvex.Specs.ISOIRCNS11643.encodings() ++
       Iconvex.Specs.ISOIRJISX0213.encodings() ++
       Iconvex.Specs.KPS956697.encodings() ++
       Iconvex.Specs.ISOIRMosaicTechnical.encodings() ++
       Iconvex.Specs.ISOIRHistoricalGraphic.encodings() ++
       Iconvex.Specs.IANAPCLSymbolSets.encodings())
    |> Kernel.++([
      Iconvex.Specs.ISOIR169.entry()
    ])
  end
end
