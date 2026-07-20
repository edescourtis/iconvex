defmodule Iconvex.Specs.LotusLICSBenchmark do
  @moduledoc false

  @quick "--quick" in System.argv()
  @timing_units if(@quick, do: 262_144, else: 1_048_576)
  @samples if(@quick, do: 3, else: 7)
  @warmups 2
  @small_units 32_768
  @large_units 65_536
  @relative_ceiling 1.35
  @linear_ceiling 2.40
  @throughput_floor 1.0
  @codec Iconvex.Specs.LotusLICS
  @undefined Enum.to_list(0x85..0x8F) ++
               [0x99] ++ Enum.to_list(0x9C..0x9F) ++ [0xFF]

  def run do
    source = corpus(@timing_units)
    small_source = corpus(@small_units)
    large_source = corpus(@large_units)
    {:ok, text} = @codec.decode_to_utf8(source)
    {:ok, small_text} = @codec.decode_to_utf8(small_source)
    {:ok, large_text} = @codec.decode_to_utf8(large_source)
    {:ok, encoded} = @codec.encode_from_utf8(text)

    unless byte_size(encoded) == byte_size(source) do
      raise "canonical LICS output changed the unit count"
    end

    IO.puts("schema\ticonvex-lotus-lics-benchmark\t1")

    IO.puts(
      "columns\tkind\toperation\tunits\tmedian_us\tmib_per_second\t" <>
        "small_reductions\tlarge_reductions\treduction_scaling\tbaseline_us\t" <>
        "native_to_baseline"
    )

    benchmark(
      "decode_to_utf8",
      fn -> @codec.decode_to_utf8(source) end,
      fn -> @codec.decode_to_utf8(small_source) end,
      fn -> @codec.decode_to_utf8(large_source) end,
      fn -> baseline_decode(source) end
    )

    benchmark(
      "encode_from_utf8",
      fn -> @codec.encode_from_utf8(text) end,
      fn -> @codec.encode_from_utf8(small_text) end,
      fn -> @codec.encode_from_utf8(large_text) end,
      fn -> baseline_encode(text) end
    )

    IO.puts(
      "comparator\tgnu-libiconv-1.19\tunavailable\t" <>
        "LICS absent from default and --enable-extra-encodings inventories"
    )

    IO.puts(
      "summary\tLICS\t239 assigned octets\t234 unique scalars\t" <>
        "5 canonical duplicate pairs\tall gates passed"
    )
  end

  defp benchmark(operation, timing, small, large, baseline) do
    median_us = median_us(timing)
    baseline_us = median_us(baseline)
    rate = @timing_units / 1_048_576 / (median_us / 1_000_000)
    small_reductions = reductions(small)
    large_reductions = reductions(large)
    scaling = large_reductions / max(small_reductions, 1)
    relative = median_us / max(baseline_us, 1)

    unless rate >= @throughput_floor do
      raise "#{operation} throughput #{rate} MiB/s is below #{@throughput_floor}"
    end

    unless scaling <= @linear_ceiling do
      raise "#{operation} reduction scaling #{scaling} exceeds #{@linear_ceiling}"
    end

    unless relative <= @relative_ceiling do
      raise "#{operation} native/baseline #{relative} exceeds #{@relative_ceiling}"
    end

    IO.puts(
      Enum.join(
        [
          "result",
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

  defp baseline_decode(source) do
    with {:ok, codepoints} <- @codec.decode(source), do: {:ok, List.to_string(codepoints)}
  end

  defp baseline_encode(text) do
    case :unicode.characters_to_list(text, :utf8) do
      codepoints when is_list(codepoints) -> @codec.encode(codepoints)
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
    alphabet = 0..255 |> Enum.reject(&(&1 in @undefined)) |> :binary.list_to_bin()
    copies = div(units + byte_size(alphabet) - 1, byte_size(alphabet))
    alphabet |> :binary.copy(copies) |> binary_part(0, units)
  end

  defp decimal(value), do: :erlang.float_to_binary(value * 1.0, decimals: 3)
  defp assert_ok({:ok, _output}), do: :ok
  defp assert_ok(other), do: raise("benchmark operation failed: #{inspect(other)}")
end

Iconvex.Specs.LotusLICSBenchmark.run()
