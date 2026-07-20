defmodule Iconvex.Specs.EvertypeSourceQualifiedBenchmark do
  @quick "--quick" in System.argv()
  @iterations if(@quick, do: 3, else: 9)
  @warmups if(@quick, do: 1, else: 2)
  @sample_repetitions if(@quick, do: 256, else: 4_096)
  @reduction_samples 3
  @reduction_lower_bound 1.65
  @reduction_upper_bound 2.35
  @native_reference_ceiling 30.0
  @expected_mapping_rows 1_694
  @source_dir Path.expand("../priv/sources/evertype-source-qualified", __DIR__)

  @profiles [
    {Iconvex.Specs.Evertype.Latin8Extended2001, "latin8_extended.csv",
     "53750c83e4958e7f530f7eaa59163689caa12c3916cb4103ff066952ab61a13b"},
    {Iconvex.Specs.Evertype.MacArmenian2001, "mac_armenian.csv",
     "696a5f6cd8145857990cf5e0c762c4f91ebb48f07f1744eff84ef0a56f7faba5"},
    {Iconvex.Specs.Evertype.MacBarentsCyrillic2001, "mac_barents_cyrillic.csv",
     "f95ab935a572d1ee82b44228b610156bc2a75d07a3a85cd1d5988a587a751cfd"},
    {Iconvex.Specs.Evertype.MacGeorgian2002, "mac_georgian.csv",
     "2d668f14a934f457495dc86a698f03845525cc9ff43f837fb0f3f98f41819897"},
    {Iconvex.Specs.Evertype.MacMalteseEsperanto2001, "mac_maltese_esperanto.csv",
     "ed4516ebd16e1d715c2c271becf11cfcca8a57c0cf4e4f173d142393c8a88ffe"},
    {Iconvex.Specs.Evertype.MacOgham2001, "mac_ogham.csv",
     "77a027e95f55949aa22756f45f14b7fb03253ff87d67311252d21910fccee3bf"},
    {Iconvex.Specs.Evertype.MacTurkicCyrillic2002, "mac_turkic_cyrillic.csv",
     "228b19300e6baefda3e6aa9d4e89343f42a660bd3d5989cbd52f9dae585a6277"}
  ]

  def run do
    runs = Enum.map(@profiles, &prepare/1)
    row_count = Enum.sum(Enum.map(runs, &length(&1.pairs)))

    unless row_count == @expected_mapping_rows do
      raise "source-bound row count changed: #{row_count}"
    end

    IO.puts(
      "source-bound mapping coverage: #{row_count}/#{@expected_mapping_rows} rows across #{length(runs)}/#{length(@profiles)} profiles"
    )

    Enum.each(runs, &benchmark_profile/1)

    IO.puts("round-trip and direct UTF-8 parity: 7/7 profiles")
    IO.puts("all 21 native/reference 30x ceiling gates passed")
    reduction_scaling_gates()
  end

  defp prepare({codec, file, expected_sha256}) do
    path = Path.join(@source_dir, file)
    csv = File.read!(path)
    actual_sha256 = :crypto.hash(:sha256, csv) |> Base.encode16(case: :lower)

    unless actual_sha256 == expected_sha256 do
      raise "mapping digest mismatch for #{file}: #{actual_sha256}"
    end

    pairs = parse_mapping(csv)
    decode = Map.new(pairs)
    encode = canonical_inverse(pairs)
    unit_bytes = pairs |> Enum.map(&elem(&1, 0)) |> :erlang.list_to_binary()
    unit_codepoints = Enum.map(pairs, &elem(&1, 1))
    bytes = :binary.copy(unit_bytes, @sample_repetitions)
    codepoints = List.duplicate(unit_codepoints, @sample_repetitions) |> List.flatten()
    reference_decoded = reference_decode(bytes, decode)
    reference_encoded = reference_encode(codepoints, encode)
    reference_utf8 = List.to_string(reference_decoded)

    unless codec.decode(bytes) == {:ok, reference_decoded} and
             codec.encode(codepoints) == {:ok, reference_encoded} and
             codec.decode_to_utf8(bytes) == {:ok, reference_utf8} do
      raise "#{codec.canonical_name()} differs from normalized source evidence"
    end

    %{
      codec: codec,
      pairs: pairs,
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

    unless ratio <= @native_reference_ceiling do
      raise "#{name} #{operation} is #{decimal(ratio)}x its independent reference"
    end

    IO.puts(
      "#{name} #{operation} native/reference #{decimal(ratio)}x; native #{decimal(rate)} million units/s"
    )
  end

  defp parse_mapping(csv) do
    ["byte,unicode" | rows] = String.split(csv, "\n", trim: true)

    Enum.map(rows, fn row ->
      [byte, codepoint] = String.split(row, ",", parts: 2)
      {String.to_integer(byte, 16), String.to_integer(codepoint, 16)}
    end)
  end

  defp canonical_inverse(pairs) do
    Enum.reduce(pairs, %{}, fn {byte, codepoint}, inverse ->
      Map.put_new(inverse, codepoint, byte)
    end)
  end

  defp reference_decode(bytes, decode) do
    for <<byte <- bytes>>, do: Map.fetch!(decode, byte)
  end

  defp reference_encode(codepoints, encode) do
    for codepoint <- codepoints, into: <<>>, do: <<Map.fetch!(encode, codepoint)>>
  end

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
    codec = Iconvex.Specs.Evertype.MacArmenian2001
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

      unless ratio > @reduction_lower_bound and ratio < @reduction_upper_bound do
        raise "#{operation} failed linear reduction scaling: #{ratio}x"
      end
    end)

    IO.puts("all 3 reduction-scaling gates passed")
  end

  defp corpus(units) do
    pattern = :erlang.list_to_binary(Enum.to_list(0..255))
    copies = div(units + byte_size(pattern) - 1, byte_size(pattern))
    pattern |> :binary.copy(copies) |> binary_part(0, units)
  end

  defp reduction_median(function) do
    reductions = for _ <- 1..@reduction_samples, do: isolated_reductions(function)

    reductions
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

Iconvex.Specs.EvertypeSourceQualifiedBenchmark.run()
