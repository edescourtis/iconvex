defmodule Iconvex.Specs.USArmyTapCodePairValuesBenchmark.Reference do
  @moduledoc false

  @letters ~c"ABCDEFGHIJLMNOPQRSTUVWXYZ"
  @decode List.to_tuple(@letters)
  @encode @letters
          |> Enum.with_index()
          |> Map.new(fn {codepoint, index} ->
            {codepoint, <<div(index, 5) + 1, rem(index, 5) + 1>>}
          end)
          |> Map.put(?K, <<1, 3>>)

  def decode(source) when is_binary(source) do
    text =
      for <<row, column <- source>>, into: <<>> do
        <<elem(@decode, (row - 1) * 5 + column - 1)>>
      end

    {:ok, text}
  end

  def encode(text) when is_binary(text) do
    encoded = text |> :binary.bin_to_list() |> Enum.map(&Map.fetch!(@encode, &1))
    {:ok, IO.iodata_to_binary(encoded)}
  end
end

defmodule Iconvex.Specs.USArmyTapCodePairValuesBenchmark do
  alias Iconvex.Specs.USArmyTapCodePairValues, as: TapCode
  alias Iconvex.Specs.USArmyTapCodePairValues.SourceAsset
  alias Iconvex.Specs.USArmyTapCodePairValuesBenchmark.Reference

  @quick "--quick" in System.argv()
  @timing_bytes if(@quick, do: 65_536, else: 1_048_576)
  @samples if(@quick, do: 5, else: 9)
  @warmups 2
  @small_bytes 65_536
  @large_bytes 131_072
  @reduction_bounds {1.60, 2.60}
  @relative_ceiling 1.25
  @throughput_floor 1.0

  def run do
    IO.puts("schema\ticonvex-us-army-tap-code-pair-values-benchmark\t1")
    IO.puts("mode\t#{if(@quick, do: "quick", else: "production")}")
    IO.puts("mapping_sha256\t#{SourceAsset.mapping_sha256()}")
    IO.puts("metadata_sha256\t#{SourceAsset.metadata_sha256()}")

    IO.puts(
      "columns\tcorpus\toperation\tencoded_bytes\tmedian_us\t" <>
        "mib_per_second\tsmall_reductions\tlarge_reductions\t" <>
        "reduction_scaling\treference_us\tnative_to_reference"
    )

    for corpus_name <- [:single_a, :c_pair, :k_alias, :complete_matrix] do
      timing = corpus(corpus_name, @timing_bytes)
      small = corpus(corpus_name, @small_bytes)
      large = corpus(corpus_name, @large_bytes)

      benchmark(
        corpus_name,
        "decode_to_utf8",
        {fn -> TapCode.decode_to_utf8(timing.source) end, {:ok, timing.decoded_text}},
        {fn -> TapCode.decode_to_utf8(small.source) end, {:ok, small.decoded_text}},
        {fn -> TapCode.decode_to_utf8(large.source) end, {:ok, large.decoded_text}},
        {fn -> Reference.decode(timing.source) end, {:ok, timing.decoded_text}},
        byte_size(timing.source)
      )

      benchmark(
        corpus_name,
        "encode_from_utf8",
        {fn -> TapCode.encode_from_utf8(timing.encode_text) end, {:ok, timing.source}},
        {fn -> TapCode.encode_from_utf8(small.encode_text) end, {:ok, small.source}},
        {fn -> TapCode.encode_from_utf8(large.encode_text) end, {:ok, large.source}},
        {fn -> Reference.encode(timing.encode_text) end, {:ok, timing.source}},
        byte_size(timing.source)
      )
    end

    IO.puts(
      "comparator\tgnu-libiconv-1.19\tunavailable\t" <>
        "Tap Code is absent from default and --enable-extra-encodings catalogs; " <>
        "the numeric-count-octet transport is project-defined"
    )

    IO.puts(
      "summary\t1 exact source-qualified profile\t4 corpora\t" <>
        "all performance gates passed"
    )
  end

  defp benchmark(corpus, operation, timing, small, large, reference, encoded_bytes) do
    {median_us, reference_us} = paired_medians_us(timing, reference)
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
    label = "Army Tap Code #{corpus} #{operation}"
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

  defp corpus(:single_a, encoded_bytes), do: build_corpus(<<1, 1>>, "A", encoded_bytes)
  defp corpus(:c_pair, encoded_bytes), do: build_corpus(<<1, 3>>, "C", encoded_bytes)
  defp corpus(:k_alias, encoded_bytes), do: build_corpus(<<1, 3>>, "K", encoded_bytes)

  defp corpus(:complete_matrix, encoded_bytes) do
    alphabet = for row <- 1..5, column <- 1..5, into: <<>>, do: <<row, column>>
    build_corpus(alphabet, "ABCDEFGHIJLMNOPQRSTUVWXYZ", encoded_bytes)
  end

  defp build_corpus(source_alphabet, encode_alphabet, encoded_bytes) do
    source = repeat_to_size(source_alphabet, encoded_bytes)
    encode_units = div(byte_size(source), 2)
    encode_text = repeat_to_size(encode_alphabet, encode_units)
    {:ok, decoded_text} = TapCode.decode_to_utf8(source)
    {:ok, ^source} = TapCode.encode_from_utf8(encode_text)
    %{source: source, decoded_text: decoded_text, encode_text: encode_text}
  end

  defp repeat_to_size(alphabet, size) do
    copies = div(size + byte_size(alphabet) - 1, byte_size(alphabet))
    alphabet |> :binary.copy(copies) |> binary_part(0, size)
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
          native_us = timed_us(native)
          {native_us, reference_us}
        end
      end

    native_samples = samples |> Enum.map(&elem(&1, 0)) |> Enum.sort()
    reference_samples = samples |> Enum.map(&elem(&1, 1)) |> Enum.sort()
    midpoint = div(@samples, 2)
    {Enum.at(native_samples, midpoint), Enum.at(reference_samples, midpoint)}
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

Iconvex.Specs.USArmyTapCodePairValuesBenchmark.run()
