defmodule Iconvex.Specs.ABICOMPBenchmark.Reference do
  @moduledoc false

  @codec Iconvex.Specs.ABICOMP

  @table 0x00..0xFF
         |> Enum.map(fn byte ->
           case @codec.decode(<<byte>>) do
             {:ok, [codepoint]} -> codepoint
             {:error, :invalid_sequence, 0, <<^byte>>} -> nil
           end
         end)
         |> List.to_tuple()

  @encoder @table
           |> Tuple.to_list()
           |> Enum.with_index()
           |> Enum.reject(fn {codepoint, _byte} -> is_nil(codepoint) end)
           |> Map.new()

  def decode(source) when is_binary(source) do
    text = source |> :binary.bin_to_list() |> Enum.map(&elem(@table, &1)) |> List.to_string()
    {:ok, text}
  end

  def encode(text) when is_binary(text) do
    case :unicode.characters_to_list(text, :utf8) do
      codepoints when is_list(codepoints) ->
        encoded = codepoints |> Enum.map(&Map.fetch!(@encoder, &1)) |> :erlang.list_to_binary()
        {:ok, encoded}

      error ->
        error
    end
  end
end

defmodule Iconvex.Specs.ABICOMPBenchmark do
  alias Iconvex.Specs.ABICOMP
  alias Iconvex.Specs.ABICOMPBenchmark.Reference

  @quick "--quick" in System.argv()
  @timing_units if(@quick, do: 65_536, else: 1_048_576)
  @samples if(@quick, do: 5, else: 9)
  @warmups 2
  @small_units 65_536
  @large_units 131_072
  @reduction_bounds {1.60, 2.60}
  @relative_ceiling 1.25
  @throughput_floor 1.0

  def run do
    IO.puts("schema\ticonvex-abicomp-benchmark\t1")

    IO.puts(
      "columns\tcorpus\toperation\tencoded_bytes\tmedian_us\t" <>
        "mib_per_second\tsmall_reductions\tlarge_reductions\t" <>
        "reduction_scaling\treference_us\tnative_to_reference"
    )

    for corpus_name <- [:ascii, :extended, :complete_defined] do
      timing = corpus(corpus_name, @timing_units)
      small = corpus(corpus_name, @small_units)
      large = corpus(corpus_name, @large_units)

      benchmark(
        corpus_name,
        "decode_to_utf8",
        {fn -> ABICOMP.decode_to_utf8(timing.source) end, {:ok, timing.text}},
        {fn -> ABICOMP.decode_to_utf8(small.source) end, {:ok, small.text}},
        {fn -> ABICOMP.decode_to_utf8(large.source) end, {:ok, large.text}},
        {fn -> Reference.decode(timing.source) end, {:ok, timing.text}},
        byte_size(timing.source)
      )

      benchmark(
        corpus_name,
        "encode_from_utf8",
        {fn -> ABICOMP.encode_from_utf8(timing.text) end, {:ok, timing.source}},
        {fn -> ABICOMP.encode_from_utf8(small.text) end, {:ok, small.source}},
        {fn -> ABICOMP.encode_from_utf8(large.text) end, {:ok, large.source}},
        {fn -> Reference.encode(timing.text) end, {:ok, timing.source}},
        byte_size(timing.source)
      )
    end

    IO.puts(
      "comparator\tgnu-libiconv-1.19\tunavailable\t" <>
        "ABICOMP and CP3848 are absent from default and --enable-extra-encodings catalogs"
    )

    IO.puts("summary\t1 exact profile\t3 corpora\tall performance gates passed")
  end

  defp benchmark(corpus, operation, timing, small, large, reference, encoded_bytes) do
    median_us = median_us(timing)
    reference_us = median_us(reference)
    small_reductions = reductions(small)
    large_reductions = reductions(large)
    scaling = large_reductions / max(small_reductions, 1)
    relative = median_us / max(reference_us, 1)
    rate = encoded_bytes / 1_048_576 / (median_us / 1_000_000)

    gate!(corpus, operation, scaling, relative, rate)

    IO.puts(
      Enum.join(
        [
          "result",
          corpus,
          operation,
          encoded_bytes,
          median_us,
          decimal(rate),
          small_reductions,
          large_reductions,
          decimal(scaling),
          reference_us,
          decimal(relative)
        ],
        "\t"
      )
    )
  end

  defp gate!(corpus, operation, scaling, relative, rate) do
    label = "ABICOMP #{corpus} #{operation}"
    {minimum_scaling, maximum_scaling} = @reduction_bounds

    unless scaling >= minimum_scaling and scaling <= maximum_scaling do
      raise "#{label} reduction scaling #{scaling} is outside " <>
              "#{minimum_scaling}..#{maximum_scaling}"
    end

    if relative > @relative_ceiling do
      raise "#{label} native/reference #{relative} exceeds #{@relative_ceiling}"
    end

    if rate < @throughput_floor do
      raise "#{label} throughput #{rate} MiB/s is below #{@throughput_floor}"
    end
  end

  defp corpus(:ascii, units), do: build_corpus(<<?A>>, units)

  defp corpus(:extended, units),
    do: build_corpus(:erlang.list_to_binary(Enum.to_list(0xA0..0xDF)), units)

  defp corpus(:complete_defined, units) do
    alphabet = :erlang.list_to_binary(Enum.to_list(0x00..0x7F) ++ Enum.to_list(0xA0..0xDF))
    build_corpus(alphabet, units)
  end

  defp build_corpus(alphabet, units) do
    source = repeat_to_size(alphabet, units)
    {:ok, text} = ABICOMP.decode_to_utf8(source)
    {:ok, ^source} = ABICOMP.encode_from_utf8(text)
    %{source: source, text: text}
  end

  defp repeat_to_size(alphabet, units) do
    copies = div(units + byte_size(alphabet) - 1, byte_size(alphabet))
    alphabet |> :binary.copy(copies) |> binary_part(0, units)
  end

  defp median_us({function, expected}) do
    for _ <- 1..@warmups, do: assert_result(function.(), expected)

    for _ <- 1..@samples do
      :erlang.garbage_collect()
      {microseconds, result} = :timer.tc(function)
      assert_result(result, expected)
      microseconds
    end
    |> Enum.sort()
    |> Enum.at(div(@samples, 2))
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
      30_000 -> raise "benchmark reduction measurement timed out"
    end
  end

  defp assert_result(actual, expected) do
    unless actual == expected do
      raise "benchmark result mismatch"
    end
  end

  defp decimal(value), do: :erlang.float_to_binary(value / 1, decimals: 3)
end

Iconvex.Specs.ABICOMPBenchmark.run()
