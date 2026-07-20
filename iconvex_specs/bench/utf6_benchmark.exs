defmodule Iconvex.Specs.UTF6Benchmark.Reference do
  @moduledoc false

  import Bitwise

  def encode([]), do: {:ok, <<>>}

  def encode(codepoints) do
    output =
      codepoints
      |> Enum.chunk_by(&(&1 == ?.))
      |> Enum.reject(&(&1 == [?.]))
      |> Enum.map_join(".", &encode_component/1)

    {:ok, output}
  end

  def decode(<<>>), do: {:ok, []}

  def decode(input) do
    codepoints =
      input
      |> String.split(".")
      |> Enum.map(&decode_component/1)
      |> Enum.intersperse([?.])
      |> List.flatten()

    {:ok, codepoints}
  end

  defp encode_component(codepoints) do
    units = Enum.flat_map(codepoints, &utf16_units/1)
    compared = Enum.reject(units, &(&1 == ?-))

    {header, mask} =
      cond do
        length(compared) < 2 ->
          {"", 0xFFFF}

        Enum.uniq_by(compared, &(&1 >>> 8)) |> length() == 1 ->
          {"y" <> vle(hd(compared) >>> 8), 0xFF}

        Enum.uniq_by(compared, &(&1 >>> 12)) |> length() == 1 ->
          {"z" <> vle(hd(compared) >>> 12), 0xFFF}

        true ->
          {"", 0xFFFF}
      end

    payload =
      Enum.map(units, fn
        ?- -> "-"
        unit -> vle(unit &&& mask)
      end)

    IO.iodata_to_binary(["wq--", header, payload])
  end

  defp decode_component("wq--" <> payload) do
    {common, body} =
      case payload do
        <<header, rest::binary>> when header in [?y, ?z] ->
          {encoded, body} = take_vle(rest)
          value = decode_vle(encoded)
          {value <<< if(header == ?y, do: 8, else: 12), body}

        _ ->
          {0, payload}
      end

    body
    |> decode_units(common, [])
    |> :lists.reverse()
    |> units_to_scalars([])
    |> :lists.reverse()
  end

  defp decode_units(<<>>, _common, acc), do: acc
  defp decode_units(<<?-, rest::binary>>, common, acc), do: decode_units(rest, common, [?- | acc])

  defp decode_units(input, common, acc) do
    {encoded, rest} = take_vle(input)
    decode_units(rest, common, [common + decode_vle(encoded) | acc])
  end

  defp take_vle(<<initial, rest::binary>>) do
    take_vle_cont(rest, <<initial>>)
  end

  defp take_vle_cont(<<byte, rest::binary>>, acc) when byte in ?0..?9 or byte in ?a..?f,
    do: take_vle_cont(rest, acc <> <<byte>>)

  defp take_vle_cont(rest, acc), do: {acc, rest}

  defp decode_vle(<<initial, rest::binary>>) do
    Enum.reduce(:binary.bin_to_list(rest), initial - ?g, fn digit, value ->
      value * 16 + if(digit in ?0..?9, do: digit - ?0, else: digit - ?a + 10)
    end)
  end

  defp utf16_units(?-), do: [?-]
  defp utf16_units(codepoint) when codepoint <= 0xFFFF, do: [codepoint]

  defp utf16_units(codepoint) do
    value = codepoint - 0x10000
    [0xD800 + (value >>> 10), 0xDC00 + (value &&& 0x3FF)]
  end

  defp units_to_scalars([], acc), do: acc

  defp units_to_scalars([high, low | rest], acc)
       when high in 0xD800..0xDBFF and low in 0xDC00..0xDFFF do
    scalar = 0x10000 + ((high - 0xD800) <<< 10) + (low - 0xDC00)
    units_to_scalars(rest, [scalar | acc])
  end

  defp units_to_scalars([unit | rest], acc), do: units_to_scalars(rest, [unit | acc])

  defp vle(0), do: "g"

  defp vle(value) do
    <<first, rest::binary>> = value |> Integer.to_string(16) |> String.downcase(:ascii)
    <<?g + hex_value(first), rest::binary>>
  end

  defp hex_value(digit) when digit in ?0..?9, do: digit - ?0
  defp hex_value(digit), do: digit - ?a + 10
end

defmodule Iconvex.Specs.UTF6Benchmark do
  alias Iconvex.Specs.UTF6
  alias Iconvex.Specs.UTF6Benchmark.Reference

  @quick "--quick" in System.argv()
  @timing_components if(@quick, do: 512, else: 4_096)
  @small_components 1_000
  @large_components 2_000
  @samples if(@quick, do: 5, else: 9)
  @warmups 2
  @relative_ceiling 30.0
  @throughput_floor 0.1
  @reduction_bounds {1.65, 2.35}

  def run do
    IO.puts("schema\ticonvex-utf6-benchmark\t1")
    IO.puts("mode\t#{if(@quick, do: "quick", else: "production")}")
    IO.puts("draft\t#{UTF6.draft_revision()}\t#{UTF6.source_sha256()}")

    IO.puts(
      "columns\tcorpus\toperation\tscalars\tencoded_bytes\tmedian_us\t" <>
        "mib_per_second\treference_us\tnative_to_reference\treduction_scaling"
    )

    for corpus_name <- [:arabic, :high_nibble, :uncompressed, :supplementary, :mixed] do
      timing = corpus(corpus_name, @timing_components)
      small = corpus(corpus_name, @small_components)
      large = corpus(corpus_name, @large_components)

      benchmark(
        corpus_name,
        "encode",
        {fn -> UTF6.encode(timing.codepoints) end, {:ok, timing.encoded}},
        {fn -> Reference.encode(timing.codepoints) end, {:ok, timing.encoded}},
        {fn -> UTF6.encode(small.codepoints) end, {:ok, small.encoded}},
        {fn -> UTF6.encode(large.codepoints) end, {:ok, large.encoded}},
        length(timing.codepoints),
        byte_size(timing.encoded)
      )

      benchmark(
        corpus_name,
        "decode",
        {fn -> UTF6.decode(timing.encoded) end, {:ok, timing.codepoints}},
        {fn -> Reference.decode(timing.encoded) end, {:ok, timing.codepoints}},
        {fn -> UTF6.decode(small.encoded) end, {:ok, small.codepoints}},
        {fn -> UTF6.decode(large.encoded) end, {:ok, large.codepoints}},
        length(timing.codepoints),
        byte_size(timing.encoded)
      )
    end

    IO.puts(
      "comparator\tgnu-libiconv-1.19\tunavailable\t" <>
        "expired draft-ietf-idn-utf6-00 is absent from default and extra catalogs"
    )

    IO.puts("summary\t1 exact draft profile\t5 corpora\tall performance gates passed")
  end

  defp benchmark(corpus, operation, native, reference, small, large, scalars, encoded_bytes) do
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
    label = "UTF-6 #{corpus} #{operation}"
    {minimum_scaling, maximum_scaling} = @reduction_bounds

    if ratio > @relative_ceiling,
      do: raise("#{label} native/reference #{ratio} exceeds #{@relative_ceiling}")

    unless scaling >= minimum_scaling and scaling <= maximum_scaling,
      do: raise("#{label} reduction scaling #{scaling} is outside #{inspect(@reduction_bounds)}")

    if throughput < @throughput_floor,
      do: raise("#{label} throughput #{throughput} MiB/s is below #{@throughput_floor}")
  end

  defp corpus(:arabic, components), do: build_corpus([0x0645, 0x0648, 0x0642, 0x0639], components)
  defp corpus(:high_nibble, components), do: build_corpus([0x305D, 0x3ABC], components)
  defp corpus(:uncompressed, components), do: build_corpus([0x305D, 0x5834, 0x6240], components)
  defp corpus(:supplementary, components), do: build_corpus([0x1F600, 0x10FFFF], components)
  defp corpus(:mixed, components), do: build_corpus([?A, ?-, 0x0645, 0x305D, 0x1F600], components)

  defp build_corpus(component, components) do
    codepoints =
      1..components
      |> Enum.map(fn _index -> component end)
      |> Enum.intersperse([?.])
      |> List.flatten()

    {:ok, encoded} = UTF6.encode(codepoints)
    {:ok, ^encoded} = Reference.encode(codepoints)
    {:ok, ^codepoints} = UTF6.decode(encoded)
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
    max(microseconds, 1)
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
      30_000 -> raise("UTF-6 benchmark reduction measurement timed out")
    end
  end

  defp assert_result(actual, expected) do
    unless actual == expected, do: raise("UTF-6 benchmark result mismatch")
  end

  defp decimal(value), do: :erlang.float_to_binary(value / 1, decimals: 3)
end

Iconvex.Specs.UTF6Benchmark.run()
