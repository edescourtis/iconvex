defmodule Iconvex.ISO2022CNEncoder do
  @moduledoc false

  alias Iconvex.Tables

  @cache_schema 1
  @cache_prefix {__MODULE__, :dispatch}

  def fetch(variant) when variant in [:iso2022_cn, :iso2022_cn_ext] do
    version = {@cache_schema, Application.spec(:iconvex, :vsn)}
    key = {@cache_prefix, version, variant}

    case :persistent_term.get(key, :missing) do
      :missing ->
        :global.trans({{__MODULE__, version, variant}, self()}, fn ->
          case :persistent_term.get(key, :missing) do
            :missing ->
              dispatch = build(variant)
              :persistent_term.put(key, dispatch)
              dispatch

            dispatch ->
              dispatch
          end
        end)

      dispatch ->
        dispatch
    end
  end

  defp build(variant) do
    %{}
    |> add_pair_table(:gb2312, :gb2312)
    |> add_cns(variant)
    |> add_ir165(variant)
  end

  defp add_pair_table(dispatch, id, target) do
    Enum.reduce(Tables.fetch!(id).encode, dispatch, fn
      {{codepoint}, <<first, second>> = pair}, acc
      when first in 0x21..0x7E and second in 0x21..0x7E ->
        Map.put_new(acc, codepoint, {:g1, target, pair})

      _, acc ->
        acc
    end)
  end

  defp add_cns(dispatch, variant) do
    maximum_plane = if variant == :iso2022_cn_ext, do: 7, else: 2

    Enum.reduce(Tables.fetch!(:euc_tw).encode, dispatch, fn
      {{codepoint}, <<first, second>>}, acc ->
        Map.put_new(acc, codepoint, {:g1, 1, <<first - 0x80, second - 0x80>>})

      {{codepoint}, <<0x8E, plane_byte, first, second>>}, acc ->
        plane = plane_byte - 0xA0

        if plane in 2..maximum_plane do
          action =
            if plane == 2,
              do: {:g2, 2, <<first - 0x80, second - 0x80>>},
              else: {:g3, plane, <<first - 0x80, second - 0x80>>}

          Map.put_new(acc, codepoint, action)
        else
          acc
        end

      _, acc ->
        acc
    end)
  end

  defp add_ir165(dispatch, :iso2022_cn_ext),
    do: add_pair_table(dispatch, :isoir165, :iso_ir_165)

  defp add_ir165(dispatch, :iso2022_cn), do: dispatch
end
