defmodule Iconvex.Specs.SecondarySourceQualifiedSingleByteBenchmark do
  @quick "--quick" in System.argv()
  @iterations if(@quick, do: 3, else: 9)
  @warmups if(@quick, do: 1, else: 2)
  @sample_repetitions if(@quick, do: 256, else: 4_096)
  @reduction_samples 3
  @reduction_lower_bound 1.65
  @reduction_upper_bound 2.35
  @native_reference_ceiling 30.0
  @expected_mapping_rows 726
  @source_dir Path.expand(
                "../priv/sources/secondary-source-qualified-single-byte",
                __DIR__
              )

  @profiles [
    {Iconvex.Specs.Secondary.WangWiscii1983WikipediaRev1352856854, "wang_wiscii.csv",
     "f40f80a592676f36f782481d9826996528471589795f969fe817fc3ac2c50bb7"},
    {Iconvex.Specs.Secondary.WikipediaWindowsPolytonicGreekRev1354794598,
     "windows_polytonic_greek.csv",
     "12774c7a072e9976b6903f8388130891833a24d10086e59d6878ebf45d99d324"},
    {Iconvex.Specs.Secondary.WikipediaEkiSamiWinCp1270Rev1340817319, "eki_sami_win_cp1270.csv",
     "9fdf47f7766938ab266cd5b9776d00329cf4083c1ce68af4fc4ce0a439ea32e4"}
  ]

  def run do
    runs = Enum.map(@profiles, &prepare/1)
    row_count = Enum.sum(Enum.map(runs, &map_size(&1.decode)))

    unless row_count == @expected_mapping_rows,
      do: raise("source-bound row count changed: #{row_count}")

    IO.puts(
      "source-bound mapping coverage: #{row_count}/#{@expected_mapping_rows} rows and 768/768 byte positions"
    )

    Enum.each(runs, &benchmark_profile/1)

    IO.puts("round-trip and direct UTF-8 parity: 3/3 profiles")
    IO.puts("all 9 native/reference 30x ceiling gates passed")
    reduction_scaling_gates()
    IO.puts("GNU comparator: unavailable for all three content-qualified profiles")
  end

  defp prepare({codec, file, expected_sha256}) do
    path = Path.join(@source_dir, file)
    csv = File.read!(path)
    actual_sha256 = :crypto.hash(:sha256, csv) |> Base.encode16(case: :lower)

    unless actual_sha256 == expected_sha256,
      do: raise("mapping digest mismatch for #{file}: #{actual_sha256}")

    rows = parse_mapping(csv)
    mapped = Enum.reject(rows, &is_nil(&1.mapping))
    decode = Map.new(mapped, &{&1.byte, &1.mapping})
    encode = canonical_inverse(mapped)
    unit_bytes = mapped |> Enum.map(& &1.byte) |> :erlang.list_to_binary()
    bytes = :binary.copy(unit_bytes, @sample_repetitions)
    reference_decoded = reference_decode(bytes, decode)
    codepoints = List.duplicate(reference_decoded, 1) |> List.flatten()
    reference_encoded = reference_encode(codepoints, encode)
    reference_utf8 = List.to_string(reference_decoded)

    unless codec.decode(bytes) == {:ok, reference_decoded} and
             codec.encode(codepoints) == {:ok, reference_encoded} and
             codec.decode_to_utf8(bytes) == {:ok, reference_utf8} do
      raise "#{codec.canonical_name()} differs from normalized source evidence"
    end

    %{
      codec: codec,
      decode: decode,
      encode: encode,
      bytes: bytes,
      codepoints: codepoints
    }
  end

  defp benchmark_profile(run) do
    name = run.codec.canonical_name()

    compare(
      name,
      "decode",
      byte_size(run.bytes),
      fn -> run.codec.decode(run.bytes) end,
      fn -> reference_decode(run.bytes, run.decode) end
    )

    compare(
      name,
      "encode",
      length(run.codepoints),
      fn -> run.codec.encode(run.codepoints) end,
      fn -> reference_encode(run.codepoints, run.encode) end
    )

    compare(
      name,
      "decode_to_utf8",
      byte_size(run.bytes),
      fn -> run.codec.decode_to_utf8(run.bytes) end,
      fn -> run.bytes |> reference_decode(run.decode) |> List.to_string() end
    )
  end

  defp compare(name, operation, units, native, reference) do
    native_us = timed_median(native)
    reference_us = timed_median(reference)
    ratio = native_us / max(reference_us, 1)
    rate = units / max(native_us, 1)

    unless ratio <= @native_reference_ceiling,
      do: raise("#{name} #{operation} is #{decimal(ratio)}x its independent reference")

    IO.puts(
      "#{name} #{operation} native/reference #{decimal(ratio)}x; native #{decimal(rate)} million units/s"
    )
  end

  defp parse_mapping(csv) do
    ["byte_hex,unicode_sequence,status" | source_rows] = String.split(csv, "\n", trim: true)

    Enum.map(source_rows, fn row ->
      [byte_hex, sequence, status] = String.split(row, ",", parts: 3)

      mapping =
        case {sequence, status} do
          {"", "undefined"} ->
            nil

          {sequence, "assigned"} ->
            sequence |> String.split("+") |> Enum.map(&String.to_integer(&1, 16))
        end

      %{byte: String.to_integer(byte_hex, 16), mapping: mapping}
    end)
  end

  defp canonical_inverse(rows) do
    Enum.reduce(rows, %{}, fn row, inverse ->
      Map.put_new(inverse, List.to_tuple(row.mapping), row.byte)
    end)
  end

  defp reference_decode(bytes, decode) do
    bytes
    |> :binary.bin_to_list()
    |> Enum.flat_map(&Map.fetch!(decode, &1))
  end

  defp reference_encode(codepoints, encode),
    do: reference_encode_loop(codepoints, encode, [])

  defp reference_encode_loop([], _encode, result),
    do: result |> :lists.reverse() |> :erlang.list_to_binary()

  defp reference_encode_loop([first, second | rest], encode, result) do
    case Map.fetch(encode, {first, second}) do
      {:ok, byte} ->
        reference_encode_loop(rest, encode, [byte | result])

      :error ->
        reference_encode_loop([second | rest], encode, [Map.fetch!(encode, {first}) | result])
    end
  end

  defp reference_encode_loop([first | rest], encode, result),
    do: reference_encode_loop(rest, encode, [Map.fetch!(encode, {first}) | result])

  defp timed_median(function) do
    for _ <- 1..@warmups, do: function.()

    for _ <- 1..@iterations do
      :erlang.garbage_collect()
      {microseconds, _result} = :timer.tc(function)
      microseconds
    end
    |> Enum.sort()
    |> Enum.at(div(@iterations, 2))
  end

  defp reduction_scaling_gates do
    codec = Iconvex.Specs.Secondary.WikipediaWindowsPolytonicGreekRev1354794598
    short_bytes = corpus(20_000)
    long_bytes = corpus(40_000)
    {:ok, short_codepoints} = codec.decode(short_bytes)
    {:ok, long_codepoints} = codec.decode(long_bytes)

    operations = [
      {"decode", fn -> codec.decode(short_bytes) end, fn -> codec.decode(long_bytes) end},
      {"encode", fn -> codec.encode(short_codepoints) end,
       fn -> codec.encode(long_codepoints) end},
      {"decode_to_utf8", fn -> codec.decode_to_utf8(short_bytes) end,
       fn -> codec.decode_to_utf8(long_bytes) end}
    ]

    Enum.each(operations, fn {operation, short, long} ->
      short_reductions = reduction_median(short)
      long_reductions = reduction_median(long)
      ratio = long_reductions / max(short_reductions, 1)

      IO.puts(
        "#{operation} reduction scaling 20k->40k: #{decimal(ratio)}x (#{short_reductions} -> #{long_reductions})"
      )

      unless ratio > @reduction_lower_bound and ratio < @reduction_upper_bound,
        do: raise("#{operation} failed linear reduction scaling: #{ratio}x")
    end)

    IO.puts("all 3 reduction-scaling gates passed")
  end

  defp corpus(units) do
    pattern = :erlang.list_to_binary(Enum.to_list(0..255))
    copies = div(units + byte_size(pattern) - 1, byte_size(pattern))
    pattern |> :binary.copy(copies) |> binary_part(0, units)
  end

  defp reduction_median(function) do
    for(_ <- 1..@reduction_samples, do: isolated_reductions(function))
    |> Enum.sort()
    |> Enum.at(div(@reduction_samples, 2))
  end

  defp isolated_reductions(function) do
    parent = self()
    token = make_ref()

    {_pid, monitor} =
      spawn_monitor(fn ->
        :erlang.garbage_collect()
        {:reductions, before_count} = Process.info(self(), :reductions)
        function.()
        {:reductions, after_count} = Process.info(self(), :reductions)
        send(parent, {token, after_count - before_count})
      end)

    receive do
      {^token, reductions} ->
        Process.demonitor(monitor, [:flush])
        reductions

      {:DOWN, ^monitor, :process, _pid, reason} ->
        raise "reduction worker failed: #{inspect(reason)}"
    after
      30_000 -> raise "reduction worker timed out"
    end
  end

  defp decimal(value), do: :erlang.float_to_binary(value * 1.0, decimals: 3)
end

Iconvex.Specs.SecondarySourceQualifiedSingleByteBenchmark.run()
