defmodule Iconvex.Specs.KamenickyKeybcs2Benchmark.Reference do
  @moduledoc false

  @codecs [Iconvex.Specs.KEYBCS2, Iconvex.Specs.MySQLKEYBCS2]

  @profiles Map.new(@codecs, fn codec ->
              table =
                0x00..0xFF
                |> Enum.map(fn byte ->
                  {:ok, [codepoint]} = codec.decode(<<byte>>)
                  codepoint
                end)
                |> List.to_tuple()

              encoder =
                table
                |> Tuple.to_list()
                |> Enum.with_index()
                |> Map.new()

              {codec, {table, encoder}}
            end)

  def decode(codec, source) do
    {table, _encoder} = Map.fetch!(@profiles, codec)

    text =
      source
      |> :binary.bin_to_list()
      |> Enum.map(&elem(table, &1))
      |> List.to_string()

    {:ok, text}
  end

  def encode(codec, text) do
    {_table, encoder} = Map.fetch!(@profiles, codec)

    case :unicode.characters_to_list(text, :utf8) do
      codepoints when is_list(codepoints) ->
        encoded = codepoints |> Enum.map(&Map.fetch!(encoder, &1)) |> :erlang.list_to_binary()
        {:ok, encoded}

      error ->
        error
    end
  end
end

defmodule Iconvex.Specs.KamenickyKeybcs2Benchmark do
  alias Iconvex.Specs.KamenickyKeybcs2Benchmark.Reference

  @quick "--quick" in System.argv()
  @timing_units if(@quick, do: 65_536, else: 1_048_576)
  @samples if(@quick, do: 5, else: 9)
  @warmups 2
  @small_units 65_536
  @large_units 131_072
  @reduction_bounds {1.60, 2.60}
  @relative_ceiling 1.25
  @throughput_floor 1.0

  @codecs [Iconvex.Specs.KEYBCS2, Iconvex.Specs.MySQLKEYBCS2]

  def run do
    IO.puts("schema\ticonvex-kamenicky-keybcs2-benchmark\t1")

    IO.puts(
      "columns\tprofile\tcorpus\toperation\tencoded_bytes\tmedian_us\t" <>
        "mib_per_second\tsmall_reductions\tlarge_reductions\t" <>
        "reduction_scaling\treference_us\tnative_to_reference"
    )

    for codec <- @codecs, corpus_name <- [:ascii, :complete_alphabet] do
      timing = corpus(codec, corpus_name, @timing_units)
      small = corpus(codec, corpus_name, @small_units)
      large = corpus(codec, corpus_name, @large_units)

      benchmark(
        codec,
        corpus_name,
        "decode_to_utf8",
        {fn -> codec.decode_to_utf8(timing.source) end, {:ok, timing.text}},
        {fn -> codec.decode_to_utf8(small.source) end, {:ok, small.text}},
        {fn -> codec.decode_to_utf8(large.source) end, {:ok, large.text}},
        {fn -> Reference.decode(codec, timing.source) end, {:ok, timing.text}},
        byte_size(timing.source)
      )

      benchmark(
        codec,
        corpus_name,
        "encode_from_utf8",
        {fn -> codec.encode_from_utf8(timing.text) end, {:ok, timing.source}},
        {fn -> codec.encode_from_utf8(small.text) end, {:ok, small.source}},
        {fn -> codec.encode_from_utf8(large.text) end, {:ok, large.source}},
        {fn -> Reference.encode(codec, timing.text) end, {:ok, timing.source}},
        byte_size(timing.source)
      )
    end

    IO.puts(
      "comparator\tgnu-libiconv-1.19\tunavailable\t" <>
        "KEYBCS2, KAMENICKY, CP895, and CP867 are unsupported"
    )

    IO.puts("summary\t2 exact text profiles\t2 corpora\tall performance gates passed")
  end

  defp benchmark(codec, corpus, operation, timing, small, large, reference, encoded_bytes) do
    median_us = median_us(timing)
    reference_us = median_us(reference)
    small_reductions = reductions(small)
    large_reductions = reductions(large)
    scaling = large_reductions / max(small_reductions, 1)
    relative = median_us / max(reference_us, 1)
    rate = encoded_bytes / 1_048_576 / (median_us / 1_000_000)

    gate!(codec, corpus, operation, scaling, relative, rate)

    IO.puts(
      Enum.join(
        [
          "result",
          codec.canonical_name(),
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

  defp gate!(codec, corpus, operation, scaling, relative, rate) do
    label = "#{codec.canonical_name()} #{corpus} #{operation}"
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

  defp corpus(_codec, :ascii, units) do
    source = :binary.copy(<<?A>>, units)
    %{source: source, text: source}
  end

  defp corpus(codec, :complete_alphabet, units) do
    alphabet = :erlang.list_to_binary(Enum.to_list(0x00..0xFF))
    source = repeat_to_size(alphabet, units)
    {:ok, text} = codec.decode_to_utf8(source)
    {:ok, ^source} = codec.encode_from_utf8(text)
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

Iconvex.Specs.KamenickyKeybcs2Benchmark.run()
