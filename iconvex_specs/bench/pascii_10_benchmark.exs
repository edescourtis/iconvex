defmodule Iconvex.Specs.PASCII10Benchmark.Reference do
  @moduledoc false

  @mapping_path Path.expand(
                  "../priv/sources/pascii-cdac-gist-1.0-2002/mapping.csv",
                  __DIR__
                )

  [_header | source_rows] =
    @mapping_path
    |> File.read!()
    |> String.split("\n", trim: true)

  parse_mapping = fn
    "" ->
      :invalid

    value ->
      case value |> String.split("+") |> Enum.map(&String.to_integer(&1, 16)) do
        [codepoint] -> codepoint
        [first, second] -> {first, second}
      end
  end

  profile_columns = %{
    urdu_kashmiri_best_fit: 2,
    sindhi_best_fit: 3,
    lossless_vpua_1: 4,
    raw_vpua_1: 5
  }

  tables =
    Map.new(profile_columns, fn {profile, column} ->
      table =
        source_rows
        |> Enum.map(fn row ->
          row |> String.split(",") |> Enum.at(column) |> parse_mapping.()
        end)
        |> List.to_tuple()

      {profile, table}
    end)

  singles =
    Map.new(tables, fn {profile, table} ->
      encoder =
        table
        |> Tuple.to_list()
        |> Enum.with_index()
        |> Enum.reduce(%{}, fn
          {codepoint, byte}, acc when is_integer(codepoint) -> Map.put_new(acc, codepoint, byte)
          {_sequence_or_invalid, _byte}, acc -> acc
        end)

      {profile, encoder}
    end)

  sequences =
    Map.new(tables, fn {profile, table} ->
      encoder =
        table
        |> Tuple.to_list()
        |> Enum.with_index()
        |> Enum.reduce(%{}, fn
          {{first, second}, byte}, acc -> Map.put_new(acc, {first, second}, byte)
          {_scalar_or_invalid, _byte}, acc -> acc
        end)

      {profile, encoder}
    end)

  @tables tables
  @singles singles
  @sequences sequences

  def decode(profile, source) when is_binary(source) do
    table = Map.fetch!(@tables, profile)

    text =
      source
      |> :binary.bin_to_list()
      |> Enum.flat_map(fn byte ->
        case elem(table, byte) do
          codepoint when is_integer(codepoint) -> [codepoint]
          {first, second} -> [first, second]
        end
      end)
      |> List.to_string()

    {:ok, text}
  end

  def encode(profile, text) when is_binary(text) do
    case :unicode.characters_to_list(text, :utf8) do
      codepoints when is_list(codepoints) ->
        encode_all(
          codepoints,
          Map.fetch!(@singles, profile),
          Map.fetch!(@sequences, profile),
          []
        )

      error ->
        error
    end
  end

  defp encode_all([], _singles, _sequences, acc),
    do: {:ok, acc |> :lists.reverse() |> :erlang.list_to_binary()}

  defp encode_all([first, second | rest], singles, sequences, acc) do
    case Map.fetch(sequences, {first, second}) do
      {:ok, byte} -> encode_all(rest, singles, sequences, [byte | acc])
      :error -> encode_single(first, [second | rest], singles, sequences, acc)
    end
  end

  defp encode_all([codepoint], singles, sequences, acc),
    do: encode_single(codepoint, [], singles, sequences, acc)

  defp encode_single(codepoint, rest, singles, sequences, acc) do
    case Map.fetch(singles, codepoint) do
      {:ok, byte} -> encode_all(rest, singles, sequences, [byte | acc])
      :error -> {:error, :unrepresentable_character, codepoint}
    end
  end
end

defmodule Iconvex.Specs.PASCII10Benchmark do
  alias Iconvex.Specs.PASCII10Benchmark.Reference

  @quick "--quick" in System.argv()
  @timing_units if(@quick, do: 131_072, else: 1_048_576)
  @samples if(@quick, do: 3, else: 7)
  @warmups if(@quick, do: 1, else: 2)
  @scaling_samples 3
  @small_units 65_536
  @large_units 131_072
  @reduction_bounds {1.55, 2.60}
  @relative_ceiling 2.0
  @throughput_floor 0.19

  @profiles [
    {Iconvex.Specs.PASCII10UrduKashmiriBestFit, :urdu_kashmiri_best_fit},
    {Iconvex.Specs.PASCII10SindhiBestFit, :sindhi_best_fit},
    {Iconvex.Specs.PASCII10LosslessVPUA1, :lossless_vpua_1},
    {Iconvex.Specs.PASCII10RawVPUA1, :raw_vpua_1}
  ]

  @alphabets %{
    urdu_kashmiri_best_fit: <<0x41, 0x81, 0x8C, 0x9E, 0xCB, 0xD4, 0xF8>>,
    sindhi_best_fit: <<0x41, 0x81, 0x8C, 0x9D, 0x9E, 0xAB, 0xBA, 0xCB, 0xD4>>,
    lossless_vpua_1: <<0x00, 0x41, 0x81, 0x9E, 0xCB, 0xD4, 0xF9>>,
    raw_vpua_1: <<0x00, 0x41, 0x80, 0x9E, 0xCB, 0xFA, 0xFF>>
  }

  def run do
    IO.puts("schema\ticonvex-pascii-1.0-benchmark\t1")

    IO.puts(
      "columns\tprofile\toperation\tinput_bytes\tmedian_us\tmib_per_second\t" <>
        "small_us\tlarge_us\ttime_scaling\tsmall_reductions\tlarge_reductions\t" <>
        "reduction_scaling\treference_us\tnative_to_reference"
    )

    results =
      Enum.flat_map(@profiles, fn {codec, profile} ->
        timing = corpus(codec, profile, @timing_units)
        small = corpus(codec, profile, @small_units)
        large = corpus(codec, profile, @large_units)

        for operation <- [:direct_decode, :direct_encode, :public_decode, :public_encode] do
          benchmark(codec, profile, operation, timing, small, large)
        end
      end)

    worst = Enum.max_by(results, & &1.relative)

    IO.puts(
      Enum.join(
        [
          "comparator",
          "gnu-libiconv-1.19",
          "N/A",
          "GNU libiconv does not expose a PASCII codec or source-qualified PASCII profile"
        ],
        "\t"
      )
    )

    IO.puts(
      "summary\t4 profiles\t16 direct/public paths\tall reduction-linearity gates passed\t" <>
        "worst native/reference=#{decimal(worst.relative)}x " <>
        "(#{worst.codec.canonical_name()} #{worst.operation})"
    )
  end

  defp benchmark(codec, profile, operation, timing, small, large) do
    timing_case = operation_case(codec, profile, operation, timing)
    small_case = operation_case(codec, profile, operation, small)
    large_case = operation_case(codec, profile, operation, large)
    reference_case = reference_case(profile, operation, timing)

    median_us = median_us(timing_case, @samples, @warmups)
    reference_us = median_us(reference_case, @samples, @warmups)
    small_us = median_us(small_case, @scaling_samples, 1)
    large_us = median_us(large_case, @scaling_samples, 1)
    small_reductions = reductions(small_case)
    large_reductions = reductions(large_case)
    time_scaling = large_us / max(small_us, 1)
    reduction_scaling = large_reductions / max(small_reductions, 1)
    relative = median_us / max(reference_us, 1)
    input_bytes = input_bytes(operation, timing)
    rate = input_bytes / 1_048_576 / (median_us / 1_000_000)

    gate!(codec, operation, time_scaling, reduction_scaling, relative, rate)

    IO.puts(
      Enum.join(
        [
          "result",
          codec.canonical_name(),
          operation,
          input_bytes,
          median_us,
          decimal(rate),
          small_us,
          large_us,
          decimal(time_scaling),
          small_reductions,
          large_reductions,
          decimal(reduction_scaling),
          reference_us,
          decimal(relative)
        ],
        "\t"
      )
    )

    %{codec: codec, operation: operation, relative: relative}
  end

  defp operation_case(codec, _profile, :direct_decode, corpus),
    do: {fn -> codec.decode_to_utf8(corpus.source) end, {:ok, corpus.text}}

  defp operation_case(codec, _profile, :direct_encode, corpus),
    do: {fn -> codec.encode_from_utf8(corpus.text) end, {:ok, corpus.source}}

  defp operation_case(codec, _profile, :public_decode, corpus) do
    name = codec.canonical_name()
    {fn -> Iconvex.convert(corpus.source, name, "UTF-8") end, {:ok, corpus.text}}
  end

  defp operation_case(codec, _profile, :public_encode, corpus) do
    name = codec.canonical_name()
    {fn -> Iconvex.convert(corpus.text, "UTF-8", name) end, {:ok, corpus.source}}
  end

  defp reference_case(profile, operation, corpus)
       when operation in [:direct_decode, :public_decode],
       do: {fn -> Reference.decode(profile, corpus.source) end, {:ok, corpus.text}}

  defp reference_case(profile, operation, corpus)
       when operation in [:direct_encode, :public_encode],
       do: {fn -> Reference.encode(profile, corpus.text) end, {:ok, corpus.source}}

  defp input_bytes(operation, corpus)
       when operation in [:direct_decode, :public_decode],
       do: byte_size(corpus.source)

  defp input_bytes(operation, corpus)
       when operation in [:direct_encode, :public_encode],
       do: byte_size(corpus.text)

  defp gate!(codec, operation, _time_scaling, reduction_scaling, relative, rate) do
    label = "#{codec.canonical_name()} #{operation}"
    {minimum_reductions, maximum_reductions} = @reduction_bounds

    unless reduction_scaling >= minimum_reductions and
             reduction_scaling <= maximum_reductions do
      raise "#{label} reduction scaling #{reduction_scaling} is outside " <>
              "#{minimum_reductions}..#{maximum_reductions}"
    end

    if relative > @relative_ceiling do
      raise "#{label} native/reference #{relative} exceeds #{@relative_ceiling}"
    end

    if rate < @throughput_floor do
      raise "#{label} throughput #{rate} MiB/s is below #{@throughput_floor}"
    end
  end

  defp corpus(codec, profile, units) do
    source = repeat_to_size(Map.fetch!(@alphabets, profile), units)
    {:ok, text} = Reference.decode(profile, source)
    {:ok, ^source} = Reference.encode(profile, text)
    {:ok, ^text} = codec.decode_to_utf8(source)
    {:ok, ^source} = codec.encode_from_utf8(text)
    {:ok, ^text} = Iconvex.convert(source, codec.canonical_name(), "UTF-8")
    {:ok, ^source} = Iconvex.convert(text, "UTF-8", codec.canonical_name())
    %{source: source, text: text}
  end

  defp repeat_to_size(alphabet, units) do
    copies = div(units + byte_size(alphabet) - 1, byte_size(alphabet))
    alphabet |> :binary.copy(copies) |> binary_part(0, units)
  end

  defp median_us({function, expected}, samples, warmups) do
    for _ <- 1..warmups, do: assert_result(function.(), expected)

    for _ <- 1..samples do
      :erlang.garbage_collect()
      {microseconds, result} = :timer.tc(function)
      assert_result(result, expected)
      microseconds
    end
    |> Enum.sort()
    |> Enum.at(div(samples, 2))
  end

  defp reductions({function, expected}) do
    parent = self()
    token = make_ref()

    {_pid, monitor} =
      spawn_monitor(fn ->
        :erlang.garbage_collect()
        {:reductions, before_count} = Process.info(self(), :reductions)
        result = function.()
        {:reductions, after_count} = Process.info(self(), :reductions)
        send(parent, {token, result, after_count - before_count})
      end)

    receive do
      {^token, result, count} ->
        assert_result(result, expected)

        receive do
          {:DOWN, ^monitor, :process, _pid, :normal} -> count
          {:DOWN, ^monitor, :process, _pid, reason} -> raise "worker failed: #{inspect(reason)}"
        after
          30_000 -> raise "reduction worker did not terminate"
        end

      {:DOWN, ^monitor, :process, _pid, reason} ->
        raise "reduction worker failed before reporting: #{inspect(reason)}"
    after
      30_000 -> raise "benchmark reduction worker timed out"
    end
  end

  defp assert_result(expected, expected), do: :ok

  defp assert_result(actual, expected),
    do:
      raise(
        "expected exact benchmark result, got #{inspect(actual)} instead of #{inspect(expected)}"
      )

  defp decimal(value), do: :erlang.float_to_binary(value * 1.0, decimals: 3)
end

Iconvex.Specs.PASCII10Benchmark.run()
