defmodule Iconvex.Specs.OT1CMapBenchmark.Reference do
  @moduledoc false

  @codecs [Iconvex.Specs.OT1CMap10J, Iconvex.Specs.OT1TTCMap10J]

  @profiles Map.new(@codecs, fn codec ->
              decode =
                Enum.reduce(0..255, %{}, fn byte, acc ->
                  case codec.decode(<<byte>>) do
                    {:ok, codepoints} -> Map.put(acc, byte, codepoints)
                    {:error, :invalid_sequence, 0, <<^byte>>} -> acc
                  end
                end)

              singles =
                Enum.reduce(decode, %{}, fn
                  {byte, [codepoint]}, acc -> Map.put_new(acc, codepoint, byte)
                  {_byte, _sequence}, acc -> acc
                end)

              sequences =
                Enum.reduce(decode, %{}, fn
                  {byte, [_first, _second] = sequence}, acc ->
                    Map.put(acc, sequence, byte)

                  {byte, [_first, _second, _third] = sequence}, acc ->
                    Map.put(acc, sequence, byte)

                  {_byte, _single}, acc ->
                    acc
                end)

              {codec, %{decode: decode, singles: singles, sequences: sequences}}
            end)

  def decode(codec, source) do
    %{decode: decode} = Map.fetch!(@profiles, codec)

    codepoints =
      source
      |> :binary.bin_to_list()
      |> Enum.flat_map(&Map.fetch!(decode, &1))

    {:ok, List.to_string(codepoints)}
  end

  def encode(codec, text) do
    profile = Map.fetch!(@profiles, codec)

    case :unicode.characters_to_list(text, :utf8) do
      codepoints when is_list(codepoints) -> encode_all(codepoints, profile, [])
      error -> error
    end
  end

  defp encode_all([], _profile, acc),
    do: {:ok, acc |> :lists.reverse() |> :erlang.list_to_binary()}

  defp encode_all([first, second, third | rest] = codepoints, profile, acc) do
    case Map.fetch(profile.sequences, [first, second, third]) do
      {:ok, byte} -> encode_all(rest, profile, [byte | acc])
      :error -> encode_pair(codepoints, profile, acc)
    end
  end

  defp encode_all(codepoints, profile, acc), do: encode_pair(codepoints, profile, acc)

  defp encode_pair([first, second | rest] = codepoints, profile, acc) do
    case Map.fetch(profile.sequences, [first, second]) do
      {:ok, byte} -> encode_all(rest, profile, [byte | acc])
      :error -> encode_single(codepoints, profile, acc)
    end
  end

  defp encode_pair(codepoints, profile, acc), do: encode_single(codepoints, profile, acc)

  defp encode_single([codepoint | rest], profile, acc) do
    case Map.fetch(profile.singles, codepoint) do
      {:ok, byte} -> encode_all(rest, profile, [byte | acc])
      :error -> {:error, :unrepresentable_character, codepoint}
    end
  end
end

defmodule Iconvex.Specs.OT1CMapBenchmark do
  @moduledoc false

  alias Iconvex.Specs.OT1CMapBenchmark.Reference

  @quick "--quick" in System.argv()
  @timing_units if(@quick, do: 65_536, else: 1_048_576)
  @samples if(@quick, do: 5, else: 9)
  @warmups 2
  @small_units 65_536
  @large_units 131_072
  @reduction_bounds {1.60, 2.60}
  @relative_ceiling 3.0
  @throughput_floor 0.20

  @codecs [Iconvex.Specs.OT1CMap10J, Iconvex.Specs.OT1TTCMap10J]
  @corpora [:identity, :special, :sequences]

  def run do
    IO.puts("schema\ticonvex-ot1-cmap-benchmark\t1")

    IO.puts(
      "columns\tprofile\tcorpus\toperation\tencoded_units\tmedian_us\t" <>
        "mi_units_per_second\tsmall_reductions\tlarge_reductions\t" <>
        "reduction_scaling\treference_us\tnative_to_reference"
    )

    for codec <- @codecs, corpus_name <- @corpora do
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
      "comparator\tgnu-libiconv\tunavailable\t" <>
        "GNU libiconv exposes neither source-qualified CMap profile"
    )

    IO.puts("summary\t2 profiles\t3 corpora\t12 strict native-path gates passed")
  end

  defp benchmark(codec, corpus, operation, timing, small, large, reference, encoded_units) do
    median_us = median_us(timing)
    reference_us = median_us(reference)
    small_reductions = reductions(small)
    large_reductions = reductions(large)
    scaling = large_reductions / max(small_reductions, 1)
    relative = median_us / max(reference_us, 1)
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
      raise "#{label} throughput #{rate} Mi encoded units/s is below #{@throughput_floor}"
    end
  end

  defp corpus(codec, corpus_name, units) do
    seed = seed(codec, corpus_name)
    source = repeat_whole(seed, units)
    {:ok, text} = codec.decode_to_utf8(source)
    {:ok, ^source} = codec.encode_from_utf8(text)
    %{source: source, text: text}
  end

  defp seed(_codec, :identity), do: "ABCDxyz0123"

  defp seed(Iconvex.Specs.OT1CMap10J, :special),
    do: <<?A, 0x00, 0x02, 0x10, 0x19, 0x1A, 0x1F, 0x22, 0x3C, 0x5C, 0x7F, ?A>>

  defp seed(Iconvex.Specs.OT1TTCMap10J, :special),
    do: <<?A, 0x00, 0x02, 0x0B, 0x0C, 0x0E, 0x0F, 0x10, 0x19, 0x20, 0x7F, ?A>>

  defp seed(Iconvex.Specs.OT1CMap10J, :sequences),
    do: <<?A, 0x0E, ?A, 0x0F, ?A, 0x0B, ?A, 0x0C, ?A, 0x0D, ?A>>

  defp seed(Iconvex.Specs.OT1TTCMap10J, :sequences), do: "AffiAfflAffAfiAflA"

  defp repeat_whole(seed, minimum_units) do
    copies = div(minimum_units + byte_size(seed) - 1, byte_size(seed))
    :binary.copy(seed, copies)
  end

  defp median_us({function, expected}) do
    for _ <- 1..@warmups, do: assert_result!(function.(), expected)

    for _ <- 1..@samples do
      :erlang.garbage_collect()
      {microseconds, result} = :timer.tc(function)
      assert_result!(result, expected)
      max(microseconds, 1)
    end
    |> Enum.sort()
    |> Enum.at(div(@samples, 2))
  end

  defp reductions({function, expected}) do
    :erlang.garbage_collect()
    before = elem(:erlang.statistics(:reductions), 0)
    result = function.()
    after_count = elem(:erlang.statistics(:reductions), 0)
    assert_result!(result, expected)
    after_count - before
  end

  defp assert_result!(expected, expected), do: :ok

  defp assert_result!(actual, expected) do
    raise "benchmark result #{inspect(actual, limit: 5)} differs from #{inspect(expected, limit: 5)}"
  end

  defp decimal(value), do: :erlang.float_to_binary(value * 1.0, decimals: 3)
end

Iconvex.Specs.OT1CMapBenchmark.run()
