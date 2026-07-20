defmodule Iconvex.Specs.CorkT1Benchmark.Reference do
  @moduledoc false

  @codecs [Iconvex.Specs.CorkT1ECGlyph, Iconvex.Specs.CorkT1CMap10J]

  @profiles Map.new(@codecs, fn codec ->
              table =
                0..255
                |> Enum.map(fn
                  0x18 ->
                    :undefined

                  byte ->
                    {:ok, codepoints} = codec.decode(<<byte>>)

                    case codepoints do
                      [codepoint] -> codepoint
                      sequence -> List.to_tuple(sequence)
                    end
                end)
                |> List.to_tuple()

              singles =
                table
                |> Tuple.to_list()
                |> Enum.with_index()
                |> Enum.reduce(%{}, fn
                  {codepoint, byte}, acc when is_integer(codepoint) ->
                    Map.put_new(acc, codepoint, byte)

                  {_mapping, _byte}, acc ->
                    acc
                end)

              sequences =
                table
                |> Tuple.to_list()
                |> Enum.with_index()
                |> Enum.reduce(%{}, fn
                  {sequence, byte}, acc when is_tuple(sequence) -> Map.put(acc, sequence, byte)
                  {_mapping, _byte}, acc -> acc
                end)

              {codec, {table, singles, sequences}}
            end)

  def decode(codec, source) do
    {table, _singles, _sequences} = Map.fetch!(@profiles, codec)

    codepoints =
      source
      |> :binary.bin_to_list()
      |> Enum.flat_map(fn byte ->
        case elem(table, byte) do
          codepoint when is_integer(codepoint) -> [codepoint]
          sequence when is_tuple(sequence) -> Tuple.to_list(sequence)
        end
      end)

    {:ok, List.to_string(codepoints)}
  end

  def encode(codec, text) do
    {_table, singles, sequences} = Map.fetch!(@profiles, codec)

    case :unicode.characters_to_list(text, :utf8) do
      codepoints when is_list(codepoints) -> encode_all(codepoints, singles, sequences, [])
      error -> error
    end
  end

  defp encode_all([], _singles, _sequences, acc),
    do: {:ok, acc |> :lists.reverse() |> :erlang.list_to_binary()}

  defp encode_all([first, second, third | rest], singles, sequences, acc) do
    case Map.fetch(sequences, {first, second, third}) do
      {:ok, byte} -> encode_all(rest, singles, sequences, [byte | acc])
      :error -> encode_pair([first, second, third | rest], singles, sequences, acc)
    end
  end

  defp encode_all(codepoints, singles, sequences, acc),
    do: encode_pair(codepoints, singles, sequences, acc)

  defp encode_pair([first, second | rest], singles, sequences, acc) do
    case Map.fetch(sequences, {first, second}) do
      {:ok, byte} -> encode_all(rest, singles, sequences, [byte | acc])
      :error -> encode_single(first, [second | rest], singles, sequences, acc)
    end
  end

  defp encode_pair([codepoint], singles, sequences, acc),
    do: encode_single(codepoint, [], singles, sequences, acc)

  defp encode_single(codepoint, rest, singles, sequences, acc) do
    case Map.fetch(singles, codepoint) do
      {:ok, byte} -> encode_all(rest, singles, sequences, [byte | acc])
      :error -> {:error, :unrepresentable_character, codepoint}
    end
  end
end

defmodule Iconvex.Specs.CorkT1Benchmark do
  alias Iconvex.Specs.CorkT1Benchmark.Reference

  @quick "--quick" in System.argv()
  @timing_units if(@quick, do: 65_536, else: 1_048_576)
  @samples if(@quick, do: 5, else: 9)
  @warmups 2
  @small_units 65_536
  @large_units 131_072
  @reduction_bounds {1.60, 2.60}
  @reduction_heap_words 1_000_000
  @relative_ceiling 1.25
  @throughput_floor 0.25

  @codecs [
    Iconvex.Specs.CorkT1ECGlyph,
    Iconvex.Specs.CorkT1CMap10J
  ]

  def run do
    IO.puts("schema\ticonvex-cork-t1-benchmark\t1")

    IO.puts(
      "columns\tprofile\tcorpus\toperation\tencoded_units\tmedian_us\t" <>
        "mi_units_per_second\tsmall_reductions\tlarge_reductions\t" <>
        "reduction_scaling\tgeneric_us\tnative_to_generic"
    )

    for codec <- @codecs, corpus_name <- [:identity, :extended, :sequences] do
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

    IO.puts("comparator\tgnu-libiconv\tunavailable\tGNU libiconv exposes no Cork/T1 profile")

    IO.puts("summary\t2 profiles\t3 corpora\tstrict native paths passed")
  end

  defp benchmark(codec, corpus, operation, timing, small, large, generic, encoded_units) do
    median_us = median_us(timing)
    generic_us = median_us(generic)
    small_reductions = reductions(small)
    large_reductions = reductions(large)
    scaling = large_reductions / max(small_reductions, 1)
    relative = median_us / max(generic_us, 1)
    rate = encoded_units / 1_048_576 / (median_us / 1_000_000)

    gate!(codec, corpus, operation, scaling, relative, rate)

    IO.puts(
      Enum.join(
        [
          "result",
          codec.canonical_name(),
          corpus,
          operation,
          encoded_units,
          median_us,
          decimal(rate),
          small_reductions,
          large_reductions,
          decimal(scaling),
          generic_us,
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
      raise "#{label} native/generic #{relative} exceeds #{@relative_ceiling}"
    end

    if rate < @throughput_floor do
      raise "#{label} throughput #{rate} Mi encoded units/s is below #{@throughput_floor}"
    end
  end

  defp corpus(_codec, :identity, units) do
    source = :binary.copy(<<?A>>, units)
    %{source: source, text: source}
  end

  defp corpus(codec, :extended, units) do
    alphabet = :binary.list_to_bin(Enum.to_list(0x80..0xFF))
    source = repeat_to_size(alphabet, units)
    {:ok, text} = codec.decode_to_utf8(source)
    {:ok, ^source} = codec.encode_from_utf8(text)
    %{source: source, text: text}
  end

  defp corpus(codec, :sequences, units) do
    text = repeat_to_size("ffifflfffiflSSA", units)
    {:ok, source} = codec.encode_from_utf8(text)
    {:ok, ^text} = codec.decode_to_utf8(source)
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

    {pid, monitor} =
      :erlang.spawn_opt(
        fn ->
          :erlang.garbage_collect()
          {:reductions, before_count} = Process.info(self(), :reductions)
          result = function.()
          {:reductions, after_count} = Process.info(self(), :reductions)
          assert_result(result, expected)
          send(parent, {token, self(), after_count - before_count})
        end,
        [:monitor, {:min_heap_size, @reduction_heap_words}]
      )

    receive do
      {^token, ^pid, count} ->
        Process.demonitor(monitor, [:flush])
        count

      {:DOWN, ^monitor, :process, ^pid, reason} ->
        raise "benchmark reduction worker failed: #{inspect(reason)}"
    after
      30_000 ->
        Process.exit(pid, :kill)
        raise "benchmark reduction worker timed out"
    end
  end

  defp assert_result(expected, expected), do: :ok

  defp assert_result(actual, expected),
    do: raise("expected #{inspect(expected)}, got #{inspect(actual)}")

  defp decimal(value), do: :erlang.float_to_binary(value * 1.0, decimals: 3)
end

Iconvex.Specs.CorkT1Benchmark.run()
