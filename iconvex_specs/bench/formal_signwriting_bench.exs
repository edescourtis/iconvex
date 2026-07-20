defmodule Iconvex.Specs.FormalSignWritingBenchmark do
  @codec Iconvex.Specs.FormalSignWriting
  @quick "--quick" in System.argv()
  @repetitions if(@quick, do: 4_000, else: 20_000)
  @samples if(@quick, do: 5, else: 9)
  @warmups 2
  @reduction_small 2_000
  @reduction_large 4_000
  @relative_ceilings %{"decode_to_utf8" => 1.15, "encode_from_utf8" => 1.25}
  @throughput_floor 0.50
  @reduction_lower 1.70
  @reduction_upper 2.30
  @unit "AS00000S10000S38b07M250x749S20500500x500"

  def run do
    source = :binary.copy(@unit, @repetitions)
    {:ok, swu} = @codec.decode_to_utf8(source)

    IO.puts("schema\ticonvex-formal-signwriting-benchmark\t1")

    IO.puts(
      "columns\toperation\tsource_bytes\tmedian_us\tmi_source_bytes_per_second\t" <>
        "small_reductions\tlarge_reductions\treduction_scaling\tbaseline_us\t" <>
        "native_to_baseline"
    )

    benchmark(
      "decode_to_utf8",
      byte_size(source),
      fn -> @codec.decode_to_utf8(source) end,
      fn -> baseline_decode(source) end,
      fn repetitions -> @codec.decode_to_utf8(:binary.copy(@unit, repetitions)) end
    )

    benchmark(
      "encode_from_utf8",
      byte_size(source),
      fn -> @codec.encode_from_utf8(swu) end,
      fn -> baseline_encode(swu) end,
      fn repetitions ->
        repetitions
        |> then(&:binary.copy(@unit, &1))
        |> @codec.decode_to_utf8()
        |> then(fn {:ok, text} -> @codec.encode_from_utf8(text) end)
      end
    )

    exhaustive_gate!()

    IO.puts(
      "comparator\tgnu-libiconv\tunavailable\tGNU libiconv 1.19 exposes no " <>
        "Formal SignWriting FSW/SWU lexical codec"
    )

    IO.puts("summary\t63010 exact mappings\tbounded pending 6 bytes/1 scalar\tpassed")
  end

  defp benchmark(operation, source_bytes, native, baseline, reduction_function) do
    median = median_us(native)
    baseline_median = median_us(baseline)
    rate = source_bytes / 1_048_576 / (median / 1_000_000)
    small = reductions(fn -> reduction_function.(@reduction_small) end)
    large = reductions(fn -> reduction_function.(@reduction_large) end)
    scaling = large / max(small, 1)
    relative = median / max(baseline_median, 1)

    unless rate >= @throughput_floor do
      raise "#{operation} throughput #{rate} is below #{@throughput_floor} MiB/s"
    end

    unless scaling >= @reduction_lower and scaling <= @reduction_upper do
      raise "#{operation} reduction scaling #{scaling} is outside " <>
              "#{@reduction_lower}..#{@reduction_upper}"
    end

    relative_ceiling = Map.fetch!(@relative_ceilings, operation)

    unless relative <= relative_ceiling do
      raise "#{operation} native/baseline #{relative} exceeds #{relative_ceiling}"
    end

    IO.puts(
      Enum.join(
        [
          "result",
          operation,
          source_bytes,
          median,
          decimal(rate),
          small,
          large,
          decimal(scaling),
          baseline_median,
          decimal(relative)
        ],
        "\t"
      )
    )
  end

  defp baseline_decode(source) do
    with {:ok, codepoints} <- @codec.decode(source), do: {:ok, List.to_string(codepoints)}
  end

  defp baseline_encode(text) do
    case :unicode.characters_to_list(text, :utf8) do
      codepoints when is_list(codepoints) -> @codec.encode(codepoints)
      error -> error
    end
  end

  defp exhaustive_gate! do
    fsw = IO.iodata_to_binary(for id <- 1..62_504, do: fsw_symbol(id))
    expected = Enum.to_list(0x40001..0x4F428)
    {:ok, ^expected} = @codec.decode(fsw)
    {:ok, ^fsw} = @codec.encode(expected)
  end

  defp fsw_symbol(id) do
    q = id - 1
    base = 0x100 + div(q, 96)
    remainder = rem(q, 96)
    fill = div(remainder, 16)
    rotation = rem(remainder, 16)

    [
      "S",
      base |> Integer.to_string(16) |> String.downcase() |> String.pad_leading(3, "0"),
      Integer.to_string(fill),
      rotation |> Integer.to_string(16) |> String.downcase()
    ]
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

  defp assert_ok({:ok, _output}), do: :ok
  defp assert_ok(other), do: raise("benchmark operation failed: #{inspect(other)}")
  defp decimal(value), do: :erlang.float_to_binary(value * 1.0, decimals: 3)
end

Iconvex.Specs.FormalSignWritingBenchmark.run()
