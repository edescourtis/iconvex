defmodule Iconvex.Specs.PDP1CharacterCodesBenchmark do
  @quick "--quick" in System.argv()
  @timing_units if(@quick, do: 65_536, else: 262_144)
  @samples if(@quick, do: 5, else: 9)
  @warmups 2
  @small_units 20_000
  @large_units 40_000
  @reduction_lower 1.70
  @reduction_upper 2.30
  @relative_ceiling 1.40
  @throughput_floor 0.20

  @profiles [
    Iconvex.Specs.PDP1Concise1960InitialLower,
    Iconvex.Specs.PDP1FridenFPC81960InitialLower,
    Iconvex.Specs.PDP1ConciseFIODEC1963InitialLower,
    Iconvex.Specs.PDP1FIODECOddParity8Bit1963InitialLower
  ]

  def run do
    IO.puts("schema\ticonvex-pdp1-character-codes-benchmark\t1")

    IO.puts(
      "columns\tkind\tprofile\toperation\tunits\tmedian_us\tmi_units_per_second\t" <>
        "small_reductions\tlarge_reductions\treduction_scaling\tbaseline_us\t" <>
        "native_to_baseline"
    )

    for codec <- @profiles do
      canonical = codec.canonical_name()
      timing_text = corpus(@timing_units)
      small_text = corpus(@small_units)
      large_text = corpus(@large_units)
      {:ok, timing_source} = codec.encode_from_utf8(timing_text)
      {:ok, small_source} = codec.encode_from_utf8(small_text)
      {:ok, large_source} = codec.encode_from_utf8(large_text)

      benchmark(
        canonical,
        "decode_to_utf8",
        fn -> codec.decode_to_utf8(timing_source) end,
        fn -> codec.decode_to_utf8(small_source) end,
        fn -> codec.decode_to_utf8(large_source) end,
        fn -> baseline_decode(codec, timing_source) end
      )

      benchmark(
        canonical,
        "encode_from_utf8",
        fn -> codec.encode_from_utf8(timing_text) end,
        fn -> codec.encode_from_utf8(small_text) end,
        fn -> codec.encode_from_utf8(large_text) end,
        fn -> baseline_encode(codec, timing_text) end
      )
    end

    IO.puts(
      "comparator\tgnu-libiconv\tunavailable\tGNU libiconv 1.19 exposes no PDP-1 " <>
        "Concise, Friden FPC-8, or FIO-DEC codec"
    )

    IO.puts("summary\t4 transports\t8 explicit initial-state profiles\tpassed")
  end

  defp benchmark(canonical, operation, timing, small, large, baseline) do
    median_us = median_us(timing)
    baseline_us = median_us(baseline)
    rate = @timing_units / 1_048_576 / (median_us / 1_000_000)
    small_reductions = reductions(small)
    large_reductions = reductions(large)
    scaling = large_reductions / max(small_reductions, 1)
    relative = median_us / max(baseline_us, 1)
    gate!(canonical, operation, rate, scaling, relative)

    IO.puts(
      Enum.join(
        [
          "result",
          canonical,
          operation,
          @timing_units,
          median_us,
          decimal(rate),
          small_reductions,
          large_reductions,
          decimal(scaling),
          baseline_us,
          decimal(relative)
        ],
        "\t"
      )
    )
  end

  defp gate!(canonical, operation, rate, scaling, relative) do
    unless scaling >= @reduction_lower and scaling <= @reduction_upper do
      raise "#{canonical} #{operation} reduction scaling #{scaling} is outside " <>
              "#{@reduction_lower}..#{@reduction_upper}"
    end

    if rate < @throughput_floor do
      raise "#{canonical} #{operation} throughput #{rate} is below #{@throughput_floor}"
    end

    if relative > @relative_ceiling do
      raise "#{canonical} #{operation} native/baseline #{relative} exceeds #{@relative_ceiling}"
    end
  end

  defp baseline_decode(codec, source) do
    with {:ok, codepoints} <- codec.decode(source), do: {:ok, List.to_string(codepoints)}
  end

  defp baseline_encode(codec, text) do
    case :unicode.characters_to_list(text, :utf8) do
      codepoints when is_list(codepoints) -> codec.encode(codepoints)
      error -> error
    end
  end

  defp median_us(function) do
    for _ <- 1..@warmups, do: assert_ok(function.())

    for _ <- 1..@samples do
      :erlang.garbage_collect()
      {microseconds, result} = :timer.tc(function)
      assert_ok(result)
      microseconds
    end
    |> Enum.sort()
    |> Enum.at(div(@samples, 2))
  end

  defp reductions(function) do
    parent = self()
    token = make_ref()

    spawn(fn ->
      :erlang.garbage_collect()
      {:reductions, before_count} = Process.info(self(), :reductions)
      assert_ok(function.())
      {:reductions, after_count} = Process.info(self(), :reductions)
      send(parent, {token, after_count - before_count})
    end)

    receive do
      {^token, count} -> count
    after
      30_000 -> raise "reduction worker timed out"
    end
  end

  defp corpus(units) do
    alphabet = "abABa09 "
    copies = div(units + byte_size(alphabet) - 1, byte_size(alphabet))
    alphabet |> :binary.copy(copies) |> binary_part(0, units)
  end

  defp decimal(value), do: :erlang.float_to_binary(value * 1.0, decimals: 3)
  defp assert_ok({:ok, _output}), do: :ok
  defp assert_ok(other), do: raise("benchmark operation failed: #{inspect(other)}")
end

Iconvex.Specs.PDP1CharacterCodesBenchmark.run()
