defmodule Iconvex.Specs.Unihan17KGB3RowCellBenchmark.Reference do
  @moduledoc false

  @mapping_path Path.expand(
                  "../priv/sources/unihan-17.0.0-kgb3/row_cells.csv",
                  __DIR__
                )
  @mapping_sha256 "63dd2f9d88dc53b9c3603fe798b6f414c578fc22b68d840225a5d44b890d6baf"

  mapping = File.read!(@mapping_path)
  actual_sha256 = :crypto.hash(:sha256, mapping) |> Base.encode16(case: :lower)

  unless actual_sha256 == @mapping_sha256 do
    raise "kGB3 benchmark source SHA-256 mismatch: expected #{@mapping_sha256}, " <>
            "got #{actual_sha256}"
  end

  [header | source_rows] = String.split(mapping, "\n", trim: true)

  unless header == "row_cell_decimal,unicode_scalar" and length(source_rows) == 7_236 do
    raise "kGB3 benchmark source must contain the exact 7,236-row mapping schema"
  end

  rows =
    Enum.map(source_rows, fn row ->
      [coordinate_text, "U+" <> scalar_text] = String.split(row, ",", parts: 2)
      coordinate = String.to_integer(coordinate_text)
      source_row = div(coordinate, 100)
      cell = rem(coordinate, 100)
      scalar = String.to_integer(scalar_text, 16)
      pair = (source_row + 0x20) * 0x100 + cell + 0x20
      {pair, scalar}
    end)

  @decode_by_pair Map.new(rows)
  @encode_by_scalar Map.new(rows, fn {pair, scalar} -> {scalar, pair} end)
  @source_alphabet rows
                   |> Enum.map(fn {pair, _scalar} -> <<pair::16>> end)
                   |> IO.iodata_to_binary()
  @text_alphabet rows
                 |> Enum.map(fn {_pair, scalar} -> <<scalar::utf8>> end)
                 |> IO.iodata_to_binary()

  def verify_source! do
    unless map_size(@decode_by_pair) == 7_236 and map_size(@encode_by_scalar) == 7_236 and
             byte_size(@source_alphabet) == 14_472 do
      raise "independent kGB3 benchmark reference is incomplete or non-bijective"
    end

    :ok
  end

  def source_alphabet, do: @source_alphabet
  def text_alphabet, do: @text_alphabet

  def decode_to_utf8(input) when is_binary(input), do: decode_all(input, [])
  def encode_from_utf8(input) when is_binary(input), do: encode_all(input, [])

  defp decode_all(<<>>, acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp decode_all(<<pair::16, rest::binary>>, acc) do
    case @decode_by_pair do
      %{^pair => scalar} -> decode_all(rest, [<<scalar::utf8>> | acc])
      _ -> {:error, :invalid_pair, pair}
    end
  end

  defp decode_all(input, _acc), do: {:error, :incomplete_pair, input}

  defp encode_all(<<>>, acc),
    do: {:ok, acc |> :lists.reverse() |> IO.iodata_to_binary()}

  defp encode_all(<<scalar::utf8, rest::binary>>, acc) do
    case @encode_by_scalar do
      %{^scalar => pair} -> encode_all(rest, [<<pair::16>> | acc])
      _ -> {:error, :unrepresentable_scalar, scalar}
    end
  end

  defp encode_all(input, _acc), do: {:error, :invalid_utf8, input}
end

defmodule Iconvex.Specs.Unihan17KGB3RowCellBenchmark do
  @moduledoc false

  alias Iconvex.Specs.Unihan17KGB3RowCellBenchmark.Reference
  alias Iconvex.Specs.Unihan17KGB3RowCellGL, as: Codec

  @quick "--quick" in System.argv()
  @calibrate "--calibrate" in System.argv()
  @timing_copies if(@quick, do: 10, else: 80)
  @samples if(@quick, do: 3, else: 7)
  @warmups if(@quick, do: 1, else: 2)
  @reduction_samples 3
  @small_copies 4
  @large_copies 8
  @reduction_bounds {1.80, 2.20}
  @relative_ceiling 30.0
  @slowdown_ceiling 30.0

  # Slowest post-optimization native rates from two independent production runs
  # over 1.10/1.66 MiB inputs on OTP 28 / Elixir 1.19.5 / arm64. Every executable
  # floor rounds the recorded minimum / 30 up to 0.01 MiB/s, so it never permits
  # a >30x loss from the measured implementation.
  @recorded_minimum_mib_per_second %{
    direct_decode_to_utf8: 4.525,
    direct_encode_from_utf8: 13.560,
    composed_decode: 3.044,
    composed_encode: 16.477
  }

  @throughput_floors Map.new(@recorded_minimum_mib_per_second, fn {operation, recorded} ->
                       {operation, Float.ceil(recorded / @slowdown_ceiling, 2)}
                     end)

  @operations ~w(
    direct_decode_to_utf8
    direct_encode_from_utf8
    composed_decode
    composed_encode
  )a

  def run do
    Reference.verify_source!()
    verify_floor_derivation!()

    timing = corpus(@timing_copies)
    small = corpus(@small_copies)
    large = corpus(@large_copies)

    IO.puts("schema\ticonvex-unihan17-kgb3-row-cell-benchmark\t1")

    IO.puts(
      "source\tUnicode-17.0.0-kGB3\t7236\t" <>
        "63dd2f9d88dc53b9c3603fe798b6f414c578fc22b68d840225a5d44b890d6baf"
    )

    IO.puts(
      "columns\toperation\tinput_bytes\tnative_median_us\tmib_per_second\t" <>
        "reference_median_us\tnative_to_reference\tsmall_reductions\t" <>
        "large_reductions\treduction_scaling"
    )

    results = Enum.map(@operations, &benchmark(&1, timing, small, large))
    worst = Enum.max_by(results, & &1.relative)

    IO.puts(
      "comparator\tgnu-libiconv-1.19\tunavailable\t" <>
        "no equivalent source-qualified kGB3 row/cell converter"
    )

    IO.puts(
      "summary\t4/4 native paths passed\tall native/reference ratios <= " <>
        "#{@relative_ceiling}x\tworst=#{worst.operation}:#{decimal(worst.relative)}x"
    )
  end

  defp benchmark(operation, timing, small, large) do
    timing_case = operation_case(operation, timing)
    small_case = operation_case(operation, small)
    large_case = operation_case(operation, large)
    reference_case = reference_case(operation, timing)

    native_us = median_us(timing_case)
    reference_us = median_us(reference_case)
    small_reductions = median_reductions(small_case)
    large_reductions = median_reductions(large_case)
    reduction_scaling = large_reductions / max(small_reductions, 1)
    input_bytes = input_bytes(operation, timing)
    rate = input_bytes / 1_048_576 / (native_us / 1_000_000)
    relative = native_us / max(reference_us, 1)
    floor = Map.fetch!(@throughput_floors, operation)

    gate!(operation, rate, floor, relative, reduction_scaling)

    IO.puts(
      Enum.join(
        [
          "result",
          operation,
          input_bytes,
          native_us,
          decimal(rate),
          reference_us,
          decimal(relative),
          small_reductions,
          large_reductions,
          decimal(reduction_scaling)
        ],
        "\t"
      )
    )

    IO.puts(
      "gate\t#{operation}\treduction_scaling\t#{decimal(reduction_scaling)}\t" <>
        "#{elem(@reduction_bounds, 0)}..#{elem(@reduction_bounds, 1)}"
    )

    IO.puts(
      "gate\t#{operation}\tthroughput_floor\t#{decimal(rate)} >= #{decimal(floor)} MiB/s\t" <>
        "ceil(recorded / 30)"
    )

    IO.puts(
      "gate\t#{operation}\tnative_to_reference\t#{decimal(relative)} <= " <>
        "#{decimal(@relative_ceiling)}x"
    )

    %{operation: operation, relative: relative, rate: rate}
  end

  defp operation_case(:direct_decode_to_utf8, corpus),
    do: {fn -> Codec.decode_to_utf8(corpus.source) end, {:ok, corpus.text}}

  defp operation_case(:direct_encode_from_utf8, corpus),
    do: {fn -> Codec.encode_from_utf8(corpus.text) end, {:ok, corpus.source}}

  defp operation_case(:composed_decode, corpus) do
    name = Codec.canonical_name()
    {fn -> Iconvex.convert(corpus.source, name, "UTF-8") end, {:ok, corpus.text}}
  end

  defp operation_case(:composed_encode, corpus) do
    name = Codec.canonical_name()
    {fn -> Iconvex.convert(corpus.text, "UTF-8", name) end, {:ok, corpus.source}}
  end

  defp reference_case(operation, corpus)
       when operation in [:direct_decode_to_utf8, :composed_decode],
       do: {fn -> Reference.decode_to_utf8(corpus.source) end, {:ok, corpus.text}}

  defp reference_case(operation, corpus)
       when operation in [:direct_encode_from_utf8, :composed_encode],
       do: {fn -> Reference.encode_from_utf8(corpus.text) end, {:ok, corpus.source}}

  defp input_bytes(operation, corpus)
       when operation in [:direct_decode_to_utf8, :composed_decode],
       do: byte_size(corpus.source)

  defp input_bytes(operation, corpus)
       when operation in [:direct_encode_from_utf8, :composed_encode],
       do: byte_size(corpus.text)

  defp corpus(copies) do
    source = :binary.copy(Reference.source_alphabet(), copies)
    text = :binary.copy(Reference.text_alphabet(), copies)

    {:ok, ^text} = Reference.decode_to_utf8(source)
    {:ok, ^source} = Reference.encode_from_utf8(text)
    {:ok, ^text} = Codec.decode_to_utf8(source)
    {:ok, ^source} = Codec.encode_from_utf8(text)

    %{source: source, text: text}
  end

  defp median_us(sample) do
    repeat(@warmups, fn -> run_and_assert!(sample) end)

    1..@samples
    |> Enum.map(fn _ ->
      :erlang.garbage_collect()
      {microseconds, _result} = :timer.tc(fn -> run_and_assert!(sample) end)
      max(microseconds, 1)
    end)
    |> median()
  end

  defp median_reductions(sample) do
    for(_ <- 1..@reduction_samples, do: isolated_reductions(sample))
    |> median()
  end

  defp isolated_reductions({function, expected}) do
    parent = self()
    token = make_ref()

    {_pid, monitor} =
      :erlang.spawn_opt(
        fn ->
          :erlang.garbage_collect()
          {:reductions, before_count} = Process.info(self(), :reductions)
          result = function.()
          {:reductions, after_count} = Process.info(self(), :reductions)

          unless result == expected,
            do: raise("benchmark reduction sample returned #{inspect(result)}")

          send(parent, {token, after_count - before_count})
        end,
        [:monitor, {:min_heap_size, 1_000_000}]
      )

    receive do
      {^token, reductions} ->
        receive do
          {:DOWN, ^monitor, :process, _pid, :normal} -> reductions
          {:DOWN, ^monitor, :process, _pid, reason} -> raise "worker failed: #{inspect(reason)}"
        after
          30_000 -> raise "benchmark reduction worker did not terminate"
        end

      {:DOWN, ^monitor, :process, _pid, reason} ->
        raise "benchmark reduction worker failed before reporting: #{inspect(reason)}"
    after
      30_000 -> raise "benchmark reduction worker timed out"
    end
  end

  defp gate!(operation, rate, floor, relative, reduction_scaling) do
    {minimum, maximum} = @reduction_bounds

    unless reduction_scaling >= minimum and reduction_scaling <= maximum do
      raise "#{operation} reduction scaling #{reduction_scaling} is outside #{minimum}..#{maximum}"
    end

    unless @calibrate or rate >= floor do
      raise "#{operation} throughput #{rate} MiB/s is below #{floor} MiB/s"
    end

    if relative > @relative_ceiling do
      raise "#{operation} native/reference #{relative}x exceeds #{@relative_ceiling}x"
    end
  end

  defp verify_floor_derivation! do
    for operation <- @operations do
      recorded = Map.fetch!(@recorded_minimum_mib_per_second, operation)
      floor = Map.fetch!(@throughput_floors, operation)
      expected = Float.ceil(recorded / @slowdown_ceiling, 2)

      unless floor == expected and recorded / floor <= @slowdown_ceiling do
        raise "#{operation} floor #{floor} is not the conservative derivative of #{recorded}"
      end
    end
  end

  defp run_and_assert!({function, expected}) do
    case function.() do
      ^expected -> expected
      result -> raise "benchmark result mismatch: #{inspect(result)}"
    end
  end

  defp repeat(count, function), do: Enum.each(1..count, fn _ -> function.() end)

  defp median(values) do
    sorted = Enum.sort(values)
    Enum.at(sorted, div(length(sorted), 2))
  end

  defp decimal(value), do: :erlang.float_to_binary(value / 1, decimals: 3)
end

Iconvex.Specs.Unihan17KGB3RowCellBenchmark.run()
