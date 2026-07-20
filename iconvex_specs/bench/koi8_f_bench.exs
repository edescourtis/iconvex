defmodule Iconvex.Specs.KOI8FBenchmark do
  @quick "--quick" in System.argv()
  @timing_units if(@quick, do: 262_144, else: 1_048_576)
  @timing_samples if(@quick, do: 5, else: 9)
  @timing_warmups if(@quick, do: 2, else: 3)
  @reduction_samples 3
  @small_units 20_000
  @large_units 40_000
  @reduction_lower_bound 1.75
  @reduction_upper_bound 2.25

  # The mixed corpus covers the ASCII identity fast path, symbols, Cyrillic,
  # and the canonical 0x9A encoding of NBSP. It intentionally omits duplicate
  # decode byte 0xA0 so encode parity can require byte-for-byte equality.
  @alphabet <<
    0x00,
    0x20,
    0x41,
    0x5A,
    0x61,
    0x7E,
    0x7F,
    0x80,
    0x81,
    0x91,
    0x95,
    0x9A,
    0xA1,
    0xAE,
    0xB0,
    0xBF,
    0xC0,
    0xCF,
    0xD0,
    0xDF,
    0xE0,
    0xEF,
    0xF0,
    0xFF
  >>

  @gates %{
    "decode_to_utf8" => %{throughput_floor: 0.5, relative_ceiling: 1.25},
    "encode_from_utf8" => %{throughput_floor: 0.3, relative_ceiling: 1.25}
  }

  def run do
    small_source = corpus(@small_units)
    large_source = corpus(@large_units)
    timing_source = corpus(@timing_units)

    {:ok, small_utf8} = Iconvex.Specs.KOI8F.decode_to_utf8(small_source)
    {:ok, large_utf8} = Iconvex.Specs.KOI8F.decode_to_utf8(large_source)
    {:ok, timing_utf8} = Iconvex.Specs.KOI8F.decode_to_utf8(timing_source)

    verify_parity(timing_source, timing_utf8)

    IO.puts("schema\ticonvex-koi8-f-benchmark\t1")

    IO.puts(
      "columns\tkind\toperation\tsmall_units\tlarge_units\tsmall_reductions\t" <>
        "large_reductions\treduction_scaling\tmedian_us\tmib_per_second\t" <>
        "throughput_floor\tbaseline_us\tnative_to_baseline\trelative_ceiling"
    )

    IO.puts(
      "baseline\tgeneric codec callback composition (decode + Unicode conversion; " <>
        "UTF-8 parsing + encode)"
    )

    IO.puts("timing\tpaired-alternating\t#{@timing_samples}\tmedian-of-pair-ratios")

    operations = [
      %{
        name: "decode_to_utf8",
        small: fn -> Iconvex.Specs.KOI8F.decode_to_utf8(small_source) end,
        large: fn -> Iconvex.Specs.KOI8F.decode_to_utf8(large_source) end,
        timing: fn -> Iconvex.Specs.KOI8F.decode_to_utf8(timing_source) end,
        baseline: fn -> baseline_decode(timing_source) end,
        input_bytes: byte_size(timing_source)
      },
      %{
        name: "encode_from_utf8",
        small: fn -> Iconvex.Specs.KOI8F.encode_from_utf8(small_utf8) end,
        large: fn -> Iconvex.Specs.KOI8F.encode_from_utf8(large_utf8) end,
        timing: fn -> Iconvex.Specs.KOI8F.encode_from_utf8(timing_utf8) end,
        baseline: fn -> baseline_encode(timing_utf8) end,
        input_bytes: byte_size(timing_utf8)
      }
    ]

    Enum.each(operations, &benchmark_and_gate/1)

    IO.puts(
      "comparator\tgnu-libiconv\tunavailable\t" <>
        "source-qualified KOI8-F-NMSU-2008 profile is not provided; " <>
        "no alias-based parity claim was made"
    )

    IO.puts("summary\t#{length(operations)}\tpassed")
  end

  defp benchmark_and_gate(operation) do
    gate = Map.fetch!(@gates, operation.name)

    {native_us, baseline_us, native_to_baseline} =
      paired_alternating_timings(operation.timing, operation.baseline)

    mib_per_second = operation.input_bytes / 1_048_576 / (native_us / 1_000_000)
    small_reductions = median_reductions(operation.small)
    large_reductions = median_reductions(operation.large)
    reduction_scaling = large_reductions / max(small_reductions, 1)

    unless reduction_scaling >= @reduction_lower_bound and
             reduction_scaling <= @reduction_upper_bound do
      raise "#{operation.name} reduction scaling #{reduction_scaling} is outside " <>
              "#{@reduction_lower_bound}..#{@reduction_upper_bound}"
    end

    if mib_per_second < gate.throughput_floor do
      raise "#{operation.name} throughput #{mib_per_second} MiB/s is below " <>
              "#{gate.throughput_floor} MiB/s"
    end

    if native_to_baseline > gate.relative_ceiling do
      raise "#{operation.name} native/baseline ratio #{native_to_baseline} exceeds " <>
              "#{gate.relative_ceiling}"
    end

    IO.puts(
      Enum.join(
        [
          "result",
          operation.name,
          @small_units,
          @large_units,
          small_reductions,
          large_reductions,
          decimal(reduction_scaling),
          native_us,
          decimal(mib_per_second),
          decimal(gate.throughput_floor),
          baseline_us,
          decimal(native_to_baseline),
          decimal(gate.relative_ceiling)
        ],
        "\t"
      )
    )
  end

  defp verify_parity(source, utf8) do
    {:ok, ^utf8} = baseline_decode(source)
    {:ok, ^source} = Iconvex.Specs.KOI8F.encode_from_utf8(utf8)
    {:ok, ^source} = baseline_encode(utf8)
  end

  defp baseline_decode(source) do
    with {:ok, codepoints} <- Iconvex.Specs.KOI8F.decode(source) do
      {:ok, :unicode.characters_to_binary(codepoints)}
    end
  end

  defp baseline_encode(utf8) do
    case :unicode.characters_to_list(utf8, :utf8) do
      codepoints when is_list(codepoints) -> Iconvex.Specs.KOI8F.encode(codepoints)
      error -> error
    end
  end

  defp paired_alternating_timings(native, baseline) do
    Enum.each(1..@timing_warmups, fn sample ->
      measure_pair(native, baseline, sample)
    end)

    pairs =
      for sample <- 1..@timing_samples do
        measure_pair(native, baseline, sample)
      end

    native_us = pairs |> Enum.map(&elem(&1, 0)) |> median()
    baseline_us = pairs |> Enum.map(&elem(&1, 1)) |> median()

    native_to_baseline =
      pairs
      |> Enum.map(fn {native_sample_us, baseline_sample_us} ->
        native_sample_us / max(baseline_sample_us, 1)
      end)
      |> median()

    {native_us, baseline_us, native_to_baseline}
  end

  defp measure_pair(native, baseline, sample) when rem(sample, 2) == 1 do
    {timed_us(native), timed_us(baseline)}
  end

  defp measure_pair(native, baseline, _sample) do
    baseline_us = timed_us(baseline)
    native_us = timed_us(native)
    {native_us, baseline_us}
  end

  defp timed_us(function) do
    :erlang.garbage_collect()
    {microseconds, result} = :timer.tc(function)
    assert_ok(result)
    microseconds
  end

  defp median(values), do: values |> Enum.sort() |> Enum.at(div(length(values), 2))

  defp median_reductions(function) do
    for(_ <- 1..@reduction_samples, do: isolated_reductions(function))
    |> Enum.sort()
    |> Enum.at(div(@reduction_samples, 2))
  end

  defp isolated_reductions(function) do
    parent = self()
    token = make_ref()

    {_pid, monitor} =
      spawn_monitor(fn ->
        :erlang.garbage_collect()
        {:reductions, before_count} = Process.info(self(), :reductions)
        assert_ok(function.())
        {:reductions, after_count} = Process.info(self(), :reductions)
        send(parent, {token, after_count - before_count})
      end)

    receive do
      {^token, count} ->
        receive do
          {:DOWN, ^monitor, :process, _pid, :normal} -> count
          {:DOWN, ^monitor, :process, _pid, reason} -> raise "worker failed: #{inspect(reason)}"
        after
          30_000 -> raise "reduction worker did not terminate"
        end

      {:DOWN, ^monitor, :process, _pid, reason} ->
        raise "reduction worker failed before reporting: #{inspect(reason)}"
    after
      30_000 -> raise "reduction worker timed out"
    end
  end

  defp corpus(units) do
    copies = div(units + byte_size(@alphabet) - 1, byte_size(@alphabet))
    @alphabet |> :binary.copy(copies) |> binary_part(0, units)
  end

  defp decimal(value) when is_float(value),
    do: :erlang.float_to_binary(value, decimals: 3)

  defp assert_ok({:ok, _output}), do: :ok
  defp assert_ok(other), do: raise("benchmark operation failed: #{inspect(other)}")
end

Iconvex.Specs.KOI8FBenchmark.run()
