defmodule Iconvex.Specs.TI89AMS20Benchmark do
  @quick "--quick" in System.argv()
  @logical_bytes if(@quick, do: 262_144, else: 1_048_576)
  @samples if(@quick, do: 3, else: 7)
  @warmups if(@quick, do: 1, else: 2)
  @reduction_samples 3
  @reduction_lower_bound 1.65
  @reduction_upper_bound 2.35
  @readable_throughput_floors %{
    "direct decode" => 1.2,
    "direct encode" => 0.51,
    "public decode" => 0.77,
    "public encode" => 0.51
  }
  @raw_throughput_floors %{
    "direct decode" => 1.38,
    "direct encode" => 0.96,
    "public decode" => 0.9,
    "public encode" => 0.94
  }

  @profiles [
    Iconvex.Specs.TI89AMS20,
    Iconvex.Specs.TI89AMS20Visible,
    Iconvex.Specs.TI89AMS20LosslessVPUA,
    Iconvex.Specs.TI89AMS20RawVPUA
  ]
  @ti_aliases Enum.flat_map(@profiles, fn codec ->
                [codec.canonical_name() | codec.aliases()]
              end)

  # Nine of eleven source bytes take a multi-scalar reverse-mapping path in
  # the three readable profiles. The raw profile deliberately interprets the
  # same octets as one-to-one forensic identities.
  @sequence_heavy_alphabet <<0x9A, 0x9B, 0xB4, 0x9A, 0x9B, 0xB4, 0x9A, 0x9B, 0xB4, 0x41, 0x95>>

  def run do
    small_source = corpus(@sequence_heavy_alphabet, div(@logical_bytes, 2))
    large_source = corpus(@sequence_heavy_alphabet, @logical_bytes)

    IO.puts("sequence-heavy corpus includes 9A, 9B, and B4")
    IO.puts("profile\toperation\tMi input bytes/s\tmedian us")

    gates =
      for codec <- @profiles,
          operation <- operations(codec, small_source, large_source) do
        benchmark_and_gate(codec.canonical_name(), operation)
      end

    IO.puts("round-trip parity: 4/4 profiles x direct/public paths")

    IO.puts(
      "all #{length(gates)} reduction-scaling gates passed " <>
        "(#{@reduction_lower_bound}x..#{@reduction_upper_bound}x)"
    )

    IO.puts(
      "all #{length(gates)} throughput floors passed " <>
        "(ceil(recorded family minimum / 30); 0.51..1.38 Mi input bytes/s)"
    )

    report_gnu_status()
  end

  defp operations(codec, small_source, large_source) do
    name = codec.canonical_name()
    {:ok, small_utf8} = codec.decode_to_utf8(small_source)
    {:ok, large_utf8} = codec.decode_to_utf8(large_source)

    {:ok, ^small_source} = codec.encode_from_utf8(small_utf8)
    {:ok, ^large_source} = codec.encode_from_utf8(large_utf8)
    {:ok, ^small_utf8} = Iconvex.convert(small_source, name, "UTF-8")
    {:ok, ^large_utf8} = Iconvex.convert(large_source, name, "UTF-8")
    {:ok, ^small_source} = Iconvex.convert(small_utf8, "UTF-8", name)
    {:ok, ^large_source} = Iconvex.convert(large_utf8, "UTF-8", name)

    [
      {"direct decode", fn -> codec.decode_to_utf8(small_source) end,
       fn -> codec.decode_to_utf8(large_source) end, byte_size(large_source)},
      {"direct encode", fn -> codec.encode_from_utf8(small_utf8) end,
       fn -> codec.encode_from_utf8(large_utf8) end, byte_size(large_utf8)},
      {"public decode", fn -> Iconvex.convert(small_source, name, "UTF-8") end,
       fn -> Iconvex.convert(large_source, name, "UTF-8") end, byte_size(large_source)},
      {"public encode", fn -> Iconvex.convert(small_utf8, "UTF-8", name) end,
       fn -> Iconvex.convert(large_utf8, "UTF-8", name) end, byte_size(large_utf8)}
    ]
  end

  defp benchmark_and_gate(name, {operation, small_fun, large_fun, input_bytes}) do
    microseconds = median_us(large_fun)
    mib_per_second = input_bytes / 1_048_576 / (microseconds / 1_000_000)

    IO.puts(
      Enum.join(
        [name, operation, Float.round(mib_per_second, 2), microseconds],
        "\t"
      )
    )

    throughput_floor = throughput_floor(name, operation)

    IO.puts(
      "#{name} #{operation} throughput floor: " <>
        "#{Float.round(mib_per_second, 2)} >= #{throughput_floor} Mi input bytes/s"
    )

    if mib_per_second < throughput_floor do
      raise "#{name} #{operation} throughput #{mib_per_second} Mi input bytes/s is below #{throughput_floor}"
    end

    small_reductions = median_reductions(small_fun)
    large_reductions = median_reductions(large_fun)
    ratio = large_reductions / max(small_reductions, 1)

    IO.puts(
      "#{name} #{operation} reduction scaling: " <>
        "#{Float.round(ratio, 3)}x (#{small_reductions} -> #{large_reductions})"
    )

    unless ratio >= @reduction_lower_bound and ratio <= @reduction_upper_bound do
      raise "#{name} #{operation} failed the linear reduction-scaling gate: #{ratio}x"
    end

    {name, operation, ratio}
  end

  defp median_us(function) do
    Enum.each(1..@warmups, fn _ -> assert_ok(function.()) end)

    for _ <- 1..@samples do
      :erlang.garbage_collect()
      {microseconds, result} = :timer.tc(function)
      assert_ok(result)
      microseconds
    end
    |> Enum.sort()
    |> Enum.at(div(@samples, 2))
  end

  defp throughput_floor(name, operation) do
    floors =
      if String.ends_with?(name, "-RAW-VPUA"),
        do: @raw_throughput_floors,
        else: @readable_throughput_floors

    Map.fetch!(floors, operation)
  end

  defp median_reductions(function) do
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
        assert_ok(function.())
        {:reductions, after_count} = Process.info(self(), :reductions)
        send(parent, {token, after_count - before_count})
      end)

    receive do
      {^token, count} ->
        receive do
          {:DOWN, ^monitor, :process, _pid, :normal} -> count
          {:DOWN, ^monitor, :process, _pid, reason} -> raise "worker failed: #{inspect(reason)}"
        after
          30_000 -> raise "reduction worker did not terminate"
        end

      {:DOWN, ^monitor, :process, _pid, reason} ->
        raise "reduction worker failed before reporting: #{inspect(reason)}"
    after
      30_000 -> raise "reduction worker timed out"
    end
  end

  defp corpus(alphabet, bytes) do
    copies = div(bytes + byte_size(alphabet) - 1, byte_size(alphabet))
    alphabet |> :binary.copy(copies) |> binary_part(0, bytes)
  end

  def report_gnu_status do
    configured = System.get_env("GNU_ICONV", "/opt/homebrew/opt/libiconv/bin/iconv")

    case System.find_executable(configured) do
      nil ->
        IO.puts("GNU comparison unavailable: set GNU_ICONV to a GNU libiconv executable")

      executable ->
        case System.cmd(executable, ["-l"], stderr_to_stdout: true) do
          {listing, 0} -> report_gnu_listing(executable, listing)
          {_output, status} -> report_gnu_list_failure(status)
        end
    end
  end

  defp report_gnu_listing(executable, listing) do
    listed_by_normalized =
      listing
      |> String.split()
      |> Map.new(fn alias_name -> {normalize_alias(alias_name), alias_name} end)

    matches =
      @ti_aliases
      |> Enum.map(&normalize_alias/1)
      |> Enum.uniq()
      |> Enum.flat_map(fn normalized ->
        case listed_by_normalized do
          %{^normalized => listed} -> [listed]
          _ -> []
        end
      end)
      |> Enum.uniq()
      |> Enum.sort()

    version = gnu_version(executable)

    case matches do
      [] ->
        IO.puts(
          "GNU comparison unavailable: queried iconv -l (#{version}); " <>
            "no exact normalized TI alias was listed"
        )

      aliases ->
        IO.puts(
          "GNU support listing includes exact normalized TI aliases after querying iconv -l " <>
            "(#{version}): #{Enum.join(aliases, ", ")}"
        )
    end
  end

  defp report_gnu_list_failure(status) do
    IO.puts("GNU comparison unavailable: iconv -l exited with status #{status}")
  end

  defp gnu_version(executable) do
    case System.cmd(executable, ["--version"], stderr_to_stdout: true) do
      {output, 0} -> output |> String.split("\n") |> List.first()
      {_output, _status} -> Path.basename(executable)
    end
  end

  defp normalize_alias(alias_name) do
    alias_name
    |> String.upcase(:ascii)
    |> String.replace(~r/[^A-Z0-9]/, "")
  end

  defp assert_ok({:ok, _result}), do: :ok
  defp assert_ok(error), do: raise("TI AMS 2.0 benchmark failed: #{inspect(error)}")
end

if "--gnu-probe-only" in System.argv() do
  Iconvex.Specs.TI89AMS20Benchmark.report_gnu_status()
else
  Iconvex.Specs.TI89AMS20Benchmark.run()
end
