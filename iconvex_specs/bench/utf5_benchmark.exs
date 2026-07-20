defmodule Iconvex.Specs.UTF5Benchmark.Reference do
  @moduledoc false

  @sequences ~r/[G-V][0-9A-F]*/

  def encode(codepoints) do
    encoded =
      Enum.map(codepoints, fn
        0 ->
          "G"

        codepoint ->
          <<first, rest::binary>> = Integer.to_string(codepoint, 16)
          <<?G + hex_value(first), rest::binary>>
      end)

    {:ok, IO.iodata_to_binary(encoded)}
  end

  def decode(input) do
    codepoints =
      @sequences
      |> Regex.scan(input, return: :binary)
      |> Enum.map(fn [<<initial, rest::binary>>] ->
        case initial - ?G do
          0 -> 0
          high -> String.to_integer(Integer.to_string(high, 16) <> rest, 16)
        end
      end)

    {:ok, codepoints}
  end

  defp hex_value(digit) when digit in ?1..?9, do: digit - ?0
  defp hex_value(digit) when digit in ?A..?F, do: digit - ?A + 10
end

defmodule Iconvex.Specs.UTF5Benchmark do
  alias Iconvex.Specs.UTF5
  alias Iconvex.Specs.UTF5Benchmark.Reference

  @quick "--quick" in System.argv()
  @timing_units if(@quick, do: 65_536, else: 1_048_576)
  @small_units 32_768
  @large_units 65_536
  @samples if(@quick, do: 5, else: 9)
  @warmups 2
  @relative_ceiling 30.0
  @throughput_floor 0.5
  @reduction_bounds {1.65, 2.35}

  def run do
    IO.puts("schema\ticonvex-utf5-benchmark\t1")
    IO.puts("mode\t#{if(@quick, do: "quick", else: "production")}")
    IO.puts("draft\t#{UTF5.draft_revision()}\t#{UTF5.source_sha256()}")

    IO.puts(
      "columns\tcorpus\toperation\tscalars\tencoded_bytes\tmedian_us\t" <>
        "mib_per_second\treference_us\tnative_to_reference\treduction_scaling"
    )

    for corpus_name <- [:ascii, :bmp, :supplementary, :mixed] do
      timing = corpus(corpus_name, @timing_units)
      small = corpus(corpus_name, @small_units)
      large = corpus(corpus_name, @large_units)

      benchmark(
        corpus_name,
        "encode",
        {fn -> UTF5.encode(timing.codepoints) end, {:ok, timing.encoded}},
        {fn -> Reference.encode(timing.codepoints) end, {:ok, timing.encoded}},
        {fn -> UTF5.encode(small.codepoints) end, {:ok, small.encoded}},
        {fn -> UTF5.encode(large.codepoints) end, {:ok, large.encoded}},
        length(timing.codepoints),
        byte_size(timing.encoded)
      )

      benchmark(
        corpus_name,
        "decode",
        {fn -> UTF5.decode(timing.encoded) end, {:ok, timing.codepoints}},
        {fn -> Reference.decode(timing.encoded) end, {:ok, timing.codepoints}},
        {fn -> UTF5.decode(small.encoded) end, {:ok, small.codepoints}},
        {fn -> UTF5.decode(large.encoded) end, {:ok, large.codepoints}},
        length(timing.codepoints),
        byte_size(timing.encoded)
      )
    end

    IO.puts(
      "comparator\tgnu-libiconv-1.19\tunavailable\t" <>
        "UTF-5 is absent from the default and --enable-extra-encodings catalogs"
    )

    IO.puts("summary\t1 exact draft profile\t4 corpora\tall performance gates passed")
  end

  defp benchmark(
         corpus,
         operation,
         native,
         reference,
         small,
         large,
         scalars,
         encoded_bytes
       ) do
    {native_us, reference_us} = paired_medians_us(native, reference)
    ratio = native_us / max(reference_us, 1)
    scaling = reductions(large) / max(reductions(small), 1)
    throughput = encoded_bytes / 1_048_576 / (native_us / 1_000_000)

    gate!(corpus, operation, ratio, scaling, throughput)

    IO.puts(
      Enum.join(
        [
          "result",
          corpus,
          operation,
          scalars,
          encoded_bytes,
          native_us,
          decimal(throughput),
          reference_us,
          decimal(ratio),
          decimal(scaling)
        ],
        "\t"
      )
    )
  end

  defp gate!(corpus, operation, ratio, scaling, throughput) do
    label = "UTF-5 #{corpus} #{operation}"
    {minimum_scaling, maximum_scaling} = @reduction_bounds

    if ratio > @relative_ceiling,
      do: raise("#{label} native/reference #{ratio} exceeds #{@relative_ceiling}")

    unless scaling >= minimum_scaling and scaling <= maximum_scaling,
      do: raise("#{label} reduction scaling #{scaling} is outside #{inspect(@reduction_bounds)}")

    if throughput < @throughput_floor,
      do: raise("#{label} throughput #{throughput} MiB/s is below #{@throughput_floor}")
  end

  defp corpus(:ascii, units), do: build_corpus([0, ?A, ?z, 0x7F], units)
  defp corpus(:bmp, units), do: build_corpus([0x391, 0x3B1, 0x2262, 0x65E5, 0x8A9E], units)

  defp corpus(:supplementary, units),
    do: build_corpus([0x10000, 0x1F600, 0x2FA1D, 0xE0100, 0x10FFFF], units)

  defp corpus(:mixed, units),
    do: build_corpus([0, ?A, 0x3B1, 0x65E5, 0x1F600, 0x10FFFF], units)

  defp build_corpus(alphabet, units) do
    copies = div(units + length(alphabet) - 1, length(alphabet))
    codepoints = alphabet |> List.duplicate(copies) |> List.flatten() |> Enum.take(units)
    {:ok, encoded} = UTF5.encode(codepoints)
    {:ok, ^codepoints} = UTF5.decode(encoded)
    {:ok, ^encoded} = Reference.encode(codepoints)
    {:ok, ^codepoints} = Reference.decode(encoded)
    %{codepoints: codepoints, encoded: encoded}
  end

  defp paired_medians_us(native, reference) do
    for _ <- 1..@warmups do
      timed_us(native)
      timed_us(reference)
    end

    samples =
      for index <- 0..(@samples - 1) do
        if rem(index, 2) == 0 do
          {timed_us(native), timed_us(reference)}
        else
          reference_us = timed_us(reference)
          {timed_us(native), reference_us}
        end
      end

    midpoint = div(@samples, 2)

    {
      samples |> Enum.map(&elem(&1, 0)) |> Enum.sort() |> Enum.at(midpoint),
      samples |> Enum.map(&elem(&1, 1)) |> Enum.sort() |> Enum.at(midpoint)
    }
  end

  defp timed_us({function, expected}) do
    :erlang.garbage_collect()
    {microseconds, result} = :timer.tc(function)
    assert_result(result, expected)
    microseconds
  end

  defp reductions({function, expected}) do
    parent = self()
    token = make_ref()

    spawn(fn ->
      :erlang.garbage_collect()
      {:reductions, before_count} = Process.info(self(), :reductions)
      result = function.()
      {:reductions, after_count} = Process.info(self(), :reductions)
      send(parent, {token, result, after_count - before_count})
    end)

    receive do
      {^token, result, count} ->
        assert_result(result, expected)
        count
    after
      30_000 -> raise("UTF-5 benchmark reduction measurement timed out")
    end
  end

  defp assert_result(actual, expected) do
    unless actual == expected, do: raise("UTF-5 benchmark result mismatch")
  end

  defp decimal(value), do: :erlang.float_to_binary(value / 1, decimals: 3)
end

Iconvex.Specs.UTF5Benchmark.run()
