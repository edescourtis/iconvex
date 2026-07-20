defmodule Iconvex.Specs.UNIVACI1959Benchmark do
  @quick "--quick" in System.argv()
  @timing_units if(@quick, do: 65_536, else: 262_144)
  @samples if(@quick, do: 5, else: 9)
  @warmups 2
  @small_units 20_000
  @large_units 40_000
  @reduction_lower 1.70
  @reduction_upper 2.30
  @relative_ceiling 1.25
  @throughput_floor 0.20

  @profiles [
    {Iconvex.Specs.UNIVACIExpanded1959, :basic, true},
    {Iconvex.Specs.UNIVACIExpanded1959LosslessVPUA, :basic_lossless, true},
    {Iconvex.Specs.UNIVACIExpanded1959RawVPUA, :basic_raw, true},
    {Iconvex.Specs.UNIVACIExpanded1959OddParity7Bit, :checked, true},
    {Iconvex.Specs.UNIVACIExpanded1959PaperTapeRow, :tape, false}
  ]

  def run do
    IO.puts("schema\ticonvex-univac-i-1959-benchmark\t1")

    IO.puts(
      "columns\tkind\tprofile\toperation\tunits\tmedian_us\tmi_units_per_second\t" <>
        "small_reductions\tlarge_reductions\treduction_scaling\tbaseline_us\t" <>
        "native_to_baseline"
    )

    for {codec, corpus_kind, packed?} <- @profiles do
      canonical = codec.canonical_name()
      timing_source = corpus(corpus_kind, @timing_units)
      small_source = corpus(corpus_kind, @small_units)
      large_source = corpus(corpus_kind, @large_units)
      {:ok, timing_text} = codec.decode_to_utf8(timing_source)
      {:ok, small_text} = codec.decode_to_utf8(small_source)
      {:ok, large_text} = codec.decode_to_utf8(large_source)

      benchmark_direct(
        canonical,
        "decode_to_utf8",
        fn -> codec.decode_to_utf8(timing_source) end,
        fn -> codec.decode_to_utf8(small_source) end,
        fn -> codec.decode_to_utf8(large_source) end,
        fn -> baseline_decode(codec, timing_source) end
      )

      benchmark_direct(
        canonical,
        "encode_from_utf8",
        fn -> codec.encode_from_utf8(timing_text) end,
        fn -> codec.encode_from_utf8(small_text) end,
        fn -> codec.encode_from_utf8(large_text) end,
        fn -> baseline_encode(codec, timing_text) end
      )

      if packed? do
        for order <- [:msb, :lsb] do
          {:ok, packed} = Iconvex.Specs.Packed.encode_from_utf8(timing_text, canonical, order)

          benchmark_packed(canonical, "packed_#{order}_encode", fn ->
            Iconvex.Specs.Packed.encode_from_utf8(timing_text, canonical, order)
          end)

          benchmark_packed(canonical, "packed_#{order}_decode", fn ->
            Iconvex.Specs.Packed.decode_to_utf8(packed, canonical, order)
          end)
        end
      end
    end

    IO.puts(
      "comparator\tgnu-libiconv\tunavailable\tGNU libiconv 1.19 exposes no " <>
        "source-qualified UNIVAC I expanded-code profile"
    )

    IO.puts("summary\t5 profiles\t4 packed profiles\tpassed")
  end

  defp benchmark_direct(canonical, operation, timing, small, large, baseline) do
    median_us = median_us(timing)
    baseline_us = median_us(baseline)
    rate = @timing_units / 1_048_576 / (median_us / 1_000_000)
    small_reductions = reductions(small)
    large_reductions = reductions(large)
    scaling = large_reductions / max(small_reductions, 1)
    relative = median_us / max(baseline_us, 1)
    gate!(canonical, operation, rate, scaling, relative)

    result(canonical, operation, median_us, rate, small_reductions, large_reductions, scaling,
      baseline_us: baseline_us,
      relative: relative
    )
  end

  defp benchmark_packed(canonical, operation, timing) do
    median_us = median_us(timing)
    rate = @timing_units / 1_048_576 / (median_us / 1_000_000)

    if rate < @throughput_floor do
      raise "#{canonical} #{operation} throughput #{rate} is below #{@throughput_floor}"
    end

    result(canonical, operation, median_us, rate, 0, 0, 0.0,
      baseline_us: 0,
      relative: 0.0
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

  defp result(canonical, operation, median_us, rate, small, large, scaling, options) do
    IO.puts(
      Enum.join(
        [
          "result",
          canonical,
          operation,
          @timing_units,
          median_us,
          decimal(rate),
          small,
          large,
          decimal(scaling),
          Keyword.fetch!(options, :baseline_us),
          decimal(Keyword.fetch!(options, :relative))
        ],
        "\t"
      )
    )
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

  defp corpus(kind, units) do
    alphabet =
      case kind do
        :basic -> :binary.list_to_bin(Enum.to_list(1..62))
        :basic_lossless -> :binary.list_to_bin(Enum.to_list(0..62))
        :basic_raw -> :binary.list_to_bin(Enum.to_list(0..63))
        :checked -> :binary.list_to_bin(for basic <- 0..62, do: checked(basic))
        :tape -> :binary.list_to_bin(for basic <- 0..62, do: tape(checked(basic)))
      end

    copies = div(units + byte_size(alphabet) - 1, byte_size(alphabet))
    alphabet |> :binary.copy(copies) |> binary_part(0, units)
  end

  defp checked(basic) do
    if basic |> Integer.digits(2) |> Enum.sum() |> rem(2) == 1,
      do: basic,
      else: Bitwise.bor(basic, 0x40)
  end

  defp tape(checked) do
    import Bitwise
    (checked &&& 0x78) <<< 1 ||| 0x08 ||| (checked &&& 0x07)
  end

  defp decimal(value), do: :erlang.float_to_binary(value * 1.0, decimals: 3)
  defp assert_ok({:ok, _output}), do: :ok
  defp assert_ok(other), do: raise("benchmark operation failed: #{inspect(other)}")
end

Iconvex.Specs.UNIVACI1959Benchmark.run()
