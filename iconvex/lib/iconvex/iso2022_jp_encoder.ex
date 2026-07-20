defmodule Iconvex.ISO2022JPEncoder do
  @moduledoc false

  alias Iconvex.Tables

  @cache_schema 4
  @cache_prefix {__MODULE__, :dispatch}

  def fetch(variant) do
    version =
      {@cache_schema, Application.spec(:iconvex, :vsn), Application.spec(:iconvex_extras, :vsn)}

    key = {@cache_prefix, version, variant}

    case :persistent_term.get(key, :missing) do
      :missing ->
        :global.trans({{__MODULE__, version, variant}, self()}, fn ->
          case :persistent_term.get(key, :missing) do
            :missing ->
              dispatch = variant |> build() |> add_direct_metadata()
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

  def choose(dispatch, codepoints), do: choose(dispatch, codepoints, :none)

  def choose(_dispatch, [codepoint | _], _language) when codepoint in 0..0x7F,
    do: {:primary, :ascii, <<codepoint>>, 1}

  def choose(%{languages: languages} = dispatch, codepoints, language)
      when language in [:ko, :zh] do
    case Map.fetch(languages, language) do
      {:ok, overrides} -> choose_with_overrides(dispatch, overrides, codepoints)
      :error -> choose(dispatch, codepoints, :none)
    end
  end

  def choose(%{pairs: pairs, singles: singles}, [first, second | _], _language)
      when map_size(pairs) > 0 do
    case Map.fetch(pairs, {first, second}) do
      {:ok, {mode, bytes}} -> {:primary, mode, bytes, 2}
      :error -> choose_single(singles, first)
    end
  end

  def choose(_dispatch, [], _language), do: :error

  def choose(%{singles: singles}, [codepoint | _], _language) do
    choose_single(singles, codepoint)
  end

  defp choose_single(singles, codepoint) do
    case Map.fetch(singles, codepoint) do
      {:ok, {:primary, mode, bytes}} -> {:primary, mode, bytes, 1}
      {:ok, {:g2, id, byte}} -> {:g2, id, byte}
      :error -> :error
    end
  end

  defp build(:iso2022_jp) do
    dispatch()
    |> add_roman()
    |> add_pair_table(:jisx0208, :jis0208)
  end

  defp build(:iso2022_jp1) do
    dispatch()
    |> add_roman()
    |> add_pair_table(:jisx0208, :jis0208)
    |> add_pair_table(:jisx0212, :jis0212)
  end

  defp build(:iso2022_jp_ext) do
    dispatch()
    |> add_pair_table(:jisx0208, :jis0208)
    |> add_pair_table(:jisx0212, :jis0212_pyext, &(&1 != 0xFF5E))
    |> add_roman()
    |> add_kana()
  end

  defp build(:iso2022_jp2) do
    default = jp2_dispatch([:japanese, :european, :chinese, :korean, :other])
    korean = jp2_dispatch([:korean, :european, :japanese, :chinese, :other])
    chinese = jp2_dispatch([:chinese, :european, :japanese, :korean, :other])

    Map.put(default, :languages, %{
      ko: dispatch_overrides(default, korean),
      zh: dispatch_overrides(default, chinese)
    })
  end

  defp build(:iso2022_jp3) do
    dispatch()
    |> add_jis0213_pairs()
    |> add_roman()
    |> add_pair_table(:jisx0208, :jis0208)
    |> add_jis0213_singles()
    |> add_kana()
  end

  defp build(:iso2022_jpms) do
    dispatch()
    |> add_kana()
    |> add_private_range(0xE000..0xE3AB, 0xE000, 0x75, :jis0208ms)
    |> put_single(0x663B, :jis0208ms, <<0x7A, 0x36>>)
    |> put_single(0xFFE2, :jis0208ms, <<0x7C, 0x7B>>)
    |> put_single(0xFFE4, :jis0208ms, <<0x7C, 0x7C>>)
    |> add_pair_table(:jisx0208, :jis0208ms)
    |> add_index_table(:cp50221_0208_ext, 0x2D)
    |> add_cp932_extensions()
    |> add_private_range(0xE3AC..0xE757, 0xE3AC, 0x75, :jis0212ms)
    |> add_pair_table(:jisx0212, :jis0212ms)
    |> add_index_table(:cp50221_0212_ext, 0x73)
  end

  defp dispatch, do: %{singles: %{}, pairs: %{}}

  defp add_direct_metadata(%{singles: singles, pairs: pairs} = dispatch) do
    maximum =
      Enum.reduce(singles, 0x7F, fn {codepoint, _action}, current ->
        max(codepoint, current)
      end)

    maximum =
      Enum.reduce(pairs, maximum, fn {{first, second}, _action}, current ->
        max(max(first, second), current)
      end)

    Map.put(dispatch, :direct_max, maximum)
  end

  defp dispatch_overrides(default, preferred) do
    %{
      singles:
        Map.filter(preferred.singles, fn {codepoint, action} ->
          Map.get(default.singles, codepoint) != action
        end),
      pairs:
        Map.filter(preferred.pairs, fn {codepoints, action} ->
          Map.get(default.pairs, codepoints) != action
        end)
    }
  end

  defp choose_with_overrides(_dispatch, _overrides, [codepoint | _])
       when codepoint in 0..0x7F,
       do: {:primary, :ascii, <<codepoint>>, 1}

  defp choose_with_overrides(dispatch, overrides, [first, second | _] = codepoints) do
    case Map.fetch(overrides.pairs, {first, second}) do
      {:ok, {mode, bytes}} ->
        {:primary, mode, bytes, 2}

      :error ->
        case Map.fetch(overrides.singles, first) do
          {:ok, action} -> selected_action(action)
          :error -> choose(dispatch, codepoints, :none)
        end
    end
  end

  defp choose_with_overrides(_dispatch, _overrides, []), do: :error

  defp choose_with_overrides(dispatch, overrides, [codepoint | _]) do
    choose_single_override(dispatch, overrides, codepoint)
  end

  defp choose_single_override(dispatch, overrides, codepoint) do
    case Map.fetch(overrides.singles, codepoint) do
      {:ok, action} -> selected_action(action)
      :error -> choose(dispatch, [codepoint], :none)
    end
  end

  defp selected_action({:primary, mode, bytes}), do: {:primary, mode, bytes, 1}
  defp selected_action({:g2, id, byte}), do: {:g2, id, byte}

  defp jp2_dispatch(categories) do
    Enum.reduce(categories, dispatch(), fn
      :european, acc ->
        acc |> add_g2(:iso8859_1) |> add_g2(:iso8859_7)

      :japanese, acc ->
        acc
        |> add_roman()
        |> add_pair_table(:jisx0208, :jis0208)
        |> add_pair_table(:jisx0212, :jis0212)

      :chinese, acc ->
        add_pair_table(acc, :gb2312, :gb2312)

      :korean, acc ->
        add_pair_table(acc, :ksc5601, :ksc5601)

      :other, acc ->
        add_kana(acc)
    end)
  end

  defp add_roman(dispatch) do
    dispatch
    |> put_single(0x00A5, :roman, <<0x5C>>)
    |> put_single(0x203E, :roman, <<0x7E>>)
  end

  defp add_pair_table(dispatch, id, mode, allowed? \\ fn _codepoint -> true end) do
    table = Tables.fetch!(id)

    singles =
      Enum.reduce(table.encode, dispatch.singles, fn
        {{codepoint}, <<first, second>> = bytes}, acc
        when first in 0x21..0x7E and second in 0x21..0x7E ->
          if allowed?.(codepoint),
            do: Map.put_new(acc, codepoint, {:primary, mode, bytes}),
            else: acc

        _, acc ->
          acc
      end)

    %{dispatch | singles: singles}
  end

  defp add_kana(dispatch) do
    singles =
      Enum.reduce(Tables.fetch!(:jisx0201).encode, dispatch.singles, fn
        {{codepoint}, <<byte>>}, acc when byte in 0xA1..0xDF ->
          Map.put_new(acc, codepoint, {:primary, :kana, <<byte - 0x80>>})

        _, acc ->
          acc
      end)

    %{dispatch | singles: singles}
  end

  defp add_g2(dispatch, id) do
    singles =
      Enum.reduce(Tables.fetch!(id).encode, dispatch.singles, fn
        {{codepoint}, <<byte>>}, acc when byte >= 0x80 ->
          Map.put_new(acc, codepoint, {:g2, id, byte - 0x80})

        _, acc ->
          acc
      end)

    %{dispatch | singles: singles}
  end

  defp add_jis0213_pairs(dispatch) do
    pairs =
      Enum.reduce(Tables.fetch!(:euc_jisx0213).encode, dispatch.pairs, fn
        {{first, second}, bytes}, acc ->
          case jis0213_action(bytes) do
            {:ok, mode, encoded} -> Map.put_new(acc, {first, second}, {mode, encoded})
            :error -> acc
          end

        _, acc ->
          acc
      end)

    %{dispatch | pairs: pairs}
  end

  defp add_jis0213_singles(dispatch) do
    singles =
      Enum.reduce(Tables.fetch!(:euc_jisx0213).encode, dispatch.singles, fn
        {{codepoint}, bytes}, acc ->
          case jis0213_action(bytes) do
            {:ok, mode, encoded} ->
              Map.put_new(acc, codepoint, {:primary, mode, encoded})

            :error ->
              acc
          end

        _, acc ->
          acc
      end)

    %{dispatch | singles: singles}
  end

  defp jis0213_action(<<first, second>>) when first >= 0xA1 and second >= 0xA1,
    do: {:ok, :jis0213_1, <<first - 0x80, second - 0x80>>}

  defp jis0213_action(<<0x8F, first, second>>),
    do: {:ok, :jis0213_2, <<first - 0x80, second - 0x80>>}

  defp jis0213_action(_bytes), do: :error

  defp add_private_range(dispatch, range, base, first_row, mode) do
    Enum.reduce(range, dispatch, fn codepoint, acc ->
      index = codepoint - base
      bytes = <<div(index, 94) + first_row, rem(index, 94) + 0x21>>
      put_single(acc, codepoint, mode, bytes)
    end)
  end

  defp add_index_table(dispatch, id, first_row) do
    singles =
      Enum.reduce(Tables.fetch!(id).encode, dispatch.singles, fn
        {codepoint, index}, acc when is_integer(codepoint) and is_integer(index) ->
          adjusted = index - 1
          bytes = <<div(adjusted, 94) + first_row, rem(adjusted, 94) + 0x21>>
          Map.put_new(acc, codepoint, {:primary, index_mode(id), bytes})

        _, acc ->
          acc
      end)

    %{dispatch | singles: singles}
  end

  defp index_mode(:cp50221_0208_ext), do: :jis0208ms
  defp index_mode(:cp50221_0212_ext), do: :jis0212ms

  defp add_cp932_extensions(dispatch) do
    singles =
      Enum.reduce(Tables.fetch!(:cp932).encode, dispatch.singles, fn
        {{codepoint}, <<lead, trail>>}, acc ->
          case sjis_to_jis(lead, trail) do
            {:ok, <<row, _::binary>> = pair} when row == 0x2D or row in 0x79..0x7C ->
              Map.put_new(acc, codepoint, {:primary, :jis0208ms, pair})

            _ ->
              acc
          end

        _, acc ->
          acc
      end)

    %{dispatch | singles: singles}
  end

  defp put_single(dispatch, codepoint, mode, bytes) do
    %{dispatch | singles: Map.put_new(dispatch.singles, codepoint, {:primary, mode, bytes})}
  end

  defp sjis_to_jis(lead, trail)
       when (lead in 0x81..0x9F or lead in 0xE0..0xFC) and
              (trail in 0x40..0x7E or trail in 0x80..0xFC) do
    row0 = if lead <= 0x9F, do: (lead - 0x81) * 2 + 0x21, else: (lead - 0xC1) * 2 + 0x21

    if trail < 0x9F do
      cell = trail - if(trail < 0x7F, do: 0x1F, else: 0x20)
      {:ok, <<row0, cell>>}
    else
      {:ok, <<row0 + 1, trail - 0x7E>>}
    end
  end

  defp sjis_to_jis(_lead, _trail), do: :error
end
