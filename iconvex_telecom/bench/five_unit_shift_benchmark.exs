defmodule FiveUnitMapBaseline do
  @moduledoc false

  def decode(input, config),
    do: decode_loop(input, config.initial, config.decode, config.shifts, 0, [])

  def encode(codepoints, config),
    do: encode_loop(codepoints, config.initial, config, [])

  defp decode_loop(<<>>, _mode, _tables, _shifts, _offset, acc),
    do: {:ok, :lists.reverse(acc)}

  defp decode_loop(<<byte, _rest::binary>>, _mode, _tables, _shifts, offset, _acc)
       when byte > 31,
       do: {:error, :invalid_sequence, offset, <<byte>>}

  defp decode_loop(<<byte, rest::binary>>, mode, tables, shifts, offset, acc) do
    case shifts do
      %{^byte => next_mode} ->
        decode_loop(rest, next_mode, tables, shifts, offset + 1, acc)

      _ ->
        case elem(Map.fetch!(tables, mode), byte) do
          nil -> {:error, :invalid_sequence, offset, <<byte>>}
          codepoint -> decode_loop(rest, mode, tables, shifts, offset + 1, [codepoint | acc])
        end
    end
  end

  defp encode_loop([], _mode, _config, acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_loop([codepoint | rest], mode, config, acc) do
    case encoded(codepoint, mode, config) do
      {:ok, bytes, next_mode} -> encode_loop(rest, next_mode, config, [bytes | acc])
      :error -> {:error, :unrepresentable_character, codepoint}
    end
  end

  defp encoded(codepoint, mode, config) do
    case Map.fetch!(config.encode, mode) do
      %{^codepoint => code} -> {:ok, code, mode}
      _ -> encoded_in_another_mode(codepoint, config)
    end
  end

  defp encoded_in_another_mode(codepoint, config) do
    Enum.find_value(config.order, fn mode ->
      case Map.fetch!(config.encode, mode) do
        %{^codepoint => code} -> {:ok, <<Map.fetch!(config.shift_codes, mode), code>>, mode}
        _ -> nil
      end
    end) || encoded_alias(codepoint, config)
  end

  defp encoded_alias(codepoint, config) do
    case config.aliases do
      %{^codepoint => {mode, code}} ->
        {:ok, <<Map.fetch!(config.shift_codes, mode), code>>, mode}

      _ ->
        :error
    end
  end
end

alias Iconvex.Telecom.{ITA2USTTY, MTK2}

config = fn tables, initial, shifts, shift_codes, order, aliases ->
  %{
    initial: initial,
    decode:
      Map.new(tables, fn {mode, table} ->
        {mode, 0..31 |> Enum.map(&Map.get(table, &1)) |> List.to_tuple()}
      end),
    encode:
      Map.new(tables, fn {mode, table} ->
        {mode, Map.new(table, fn {code, codepoint} -> {codepoint, code} end)}
      end),
    shifts: shifts,
    shift_codes: shift_codes,
    order: order,
    aliases: aliases
  }
end

us_config =
  config.(
    ITA2USTTY.tables(),
    :letters,
    %{27 => :figures, 31 => :letters},
    %{letters: 31, figures: 27},
    [:letters, :figures],
    %{}
  )

mtk_config =
  config.(
    MTK2.tables(),
    :latin,
    %{31 => :latin, 0 => :russian, 27 => :figures},
    MTK2.shift_codes(),
    [:latin, :russian, :figures],
    %{?Ч => {:figures, 10}, 0x0007 => {:figures, 11}}
  )

us_text = String.to_charlist(String.duplicate("HELLO 123 ", 16))
mtk_text = String.to_charlist(String.duplicate("TEST ТЕСТ 123 ", 10))
{:ok, us_encoded} = ITA2USTTY.encode(us_text)
{:ok, mtk_encoded} = MTK2.encode(mtk_text)

iterations = 30_000
rounds = 12

measure = fn fun ->
  :erlang.garbage_collect()
  started = System.monotonic_time()
  for _ <- 1..iterations, do: fun.()
  elapsed = System.monotonic_time() - started
  System.convert_time_unit(elapsed, :native, :nanosecond) / 1_000_000_000
end

median = fn values ->
  values = Enum.sort(values)
  (Enum.at(values, div(length(values), 2) - 1) + Enum.at(values, div(length(values), 2))) / 2
end

pair = fn label, baseline, optimized ->
  for _ <- 1..3_000 do
    baseline.()
    optimized.()
  end

  {old_times, new_times} =
    Enum.reduce(0..(rounds - 1), {[], []}, fn round, {old, new} ->
      if rem(round, 2) == 0 do
        {[measure.(baseline) | old], [measure.(optimized) | new]}
      else
        new_time = measure.(optimized)
        old_time = measure.(baseline)
        {[old_time | old], [new_time | new]}
      end
    end)

  old_rate = iterations / median.(old_times)
  new_rate = iterations / median.(new_times)

  IO.puts(
    "#{label}: map baseline #{Float.round(old_rate, 1)} ops/s; " <>
      "optimized #{Float.round(new_rate, 1)} ops/s; " <>
      "#{Float.round((new_rate / old_rate - 1) * 100, 1)}%"
  )
end

pair.(
  "US TTY encode 160 chars",
  fn -> FiveUnitMapBaseline.encode(us_text, us_config) end,
  fn -> ITA2USTTY.encode(us_text) end
)

pair.(
  "US TTY decode #{byte_size(us_encoded)} units",
  fn -> FiveUnitMapBaseline.decode(us_encoded, us_config) end,
  fn -> ITA2USTTY.decode(us_encoded) end
)

pair.(
  "MTK-2 encode 140 chars",
  fn -> FiveUnitMapBaseline.encode(mtk_text, mtk_config) end,
  fn -> MTK2.encode(mtk_text) end
)

pair.(
  "MTK-2 decode #{byte_size(mtk_encoded)} units",
  fn -> FiveUnitMapBaseline.decode(mtk_encoded, mtk_config) end,
  fn -> MTK2.decode(mtk_encoded) end
)
