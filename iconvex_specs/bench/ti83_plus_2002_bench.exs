defmodule Iconvex.Specs.TI83Plus2002Benchmark do
  @quick "--quick" in System.argv()
  @logical_bytes if(@quick, do: 262_144, else: 1_048_576)
  @samples if(@quick, do: 3, else: 7)
  @warmups if(@quick, do: 1, else: 2)
  @reduction_samples 3
  @reduction_lower_bound 1.65
  @reduction_upper_bound 2.35

  # Floors are ceil(recorded production family minimum / 30, 0.01).
  @throughput_floors %{
    readable: %{
      "direct decode" => 1.32,
      "direct encode" => 0.48,
      "public decode" => 0.81,
      "public encode" => 0.51
    },
    lossless: %{
      "direct decode" => 1.31,
      "direct encode" => 0.51,
      "public decode" => 0.79,
      "public encode" => 0.51
    },
    raw: %{
      "direct decode" => 1.31,
      "direct encode" => 0.91,
      "public decode" => 0.87,
      "public encode" => 0.91
    },
    invalid: %{
      "direct invalid strict" => 1.34,
      "direct invalid discard" => 0.57,
      "public invalid strict" => 1.34,
      "public invalid discard" => 0.38,
      "public invalid replace" => 0.04
    }
  }

  @profiles [
    {Iconvex.Specs.TI83PlusLarge, :readable},
    {Iconvex.Specs.TI83PlusLargeLosslessVPUA, :lossless},
    {Iconvex.Specs.TI83PlusLargeRawVPUA, :raw},
    {Iconvex.Specs.TI83PlusSmall, :readable},
    {Iconvex.Specs.TI83PlusSmallLosslessVPUA, :lossless},
    {Iconvex.Specs.TI83PlusSmallRawVPUA, :raw}
  ]
  @ti_aliases Enum.flat_map(@profiles, fn {codec, _family} ->
                [codec.canonical_name() | codec.aliases()]
              end)

  @sequence_heavy_alphabet <<0x11, 0xCB, 0xCC, 0xD8, 0x11, 0xCB, 0xCC, 0xD8, 0x41, 0xD6>>

  def run do
    small_source = corpus(@sequence_heavy_alphabet, div(@logical_bytes, 2))
    large_source = corpus(@sequence_heavy_alphabet, @logical_bytes)

    verify_reverse_policy_boundary()
    IO.puts("sequence-heavy corpus includes 11, CB, CC, and D8")
    IO.puts("decode-only 1D and DE remain excluded from readable reverse tries")
    IO.puts("invalid corpora exercise strict, discard, and replacement recovery")
    IO.puts("profile\toperation\tMi input bytes/s\tmedian us")

    core_gates =
      for {codec, family} <- @profiles,
          operation <- core_operations(codec, small_source, large_source) do
        benchmark_and_gate(codec.canonical_name(), family, operation)
      end

    invalid_gates =
      for {codec, :readable} <- @profiles,
          operation <- invalid_operations(codec) do
        benchmark_and_gate(codec.canonical_name(), :invalid, operation)
      end

    gates = core_gates ++ invalid_gates

    IO.puts("round-trip parity: 6/6 profiles x direct/public paths")

    IO.puts(
      "all #{length(gates)} reduction-scaling gates passed " <>
        "(#{@reduction_lower_bound}x..#{@reduction_upper_bound}x)"
    )

    floors = @throughput_floors |> Map.values() |> Enum.flat_map(&Map.values/1)

    IO.puts(
      "all #{length(gates)} throughput floors passed " <>
        "(ceil(recorded family minimum / 30); " <>
        "#{Enum.min(floors)}..#{Enum.max(floors)} Mi input bytes/s)"
    )

    report_gnu_status()
  end

  defp core_operations(codec, small_source, large_source) do
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
       fn -> codec.decode_to_utf8(large_source) end, byte_size(large_source), :ok},
      {"direct encode", fn -> codec.encode_from_utf8(small_utf8) end,
       fn -> codec.encode_from_utf8(large_utf8) end, byte_size(large_utf8), :ok},
      {"public decode", fn -> Iconvex.convert(small_source, name, "UTF-8") end,
       fn -> Iconvex.convert(large_source, name, "UTF-8") end, byte_size(large_source), :ok},
      {"public encode", fn -> Iconvex.convert(small_utf8, "UTF-8", name) end,
       fn -> Iconvex.convert(large_utf8, "UTF-8", name) end, byte_size(large_utf8), :ok}
    ]
  end

  defp invalid_operations(codec) do
    name = codec.canonical_name()
    invalid = if name == "TI-83-PLUS-LARGE", do: 0xF2, else: 0xED

    small_strict = corpus(<<0x11, 0xCB, 0x41>>, div(@logical_bytes, 2) - 1) <> <<invalid>>
    large_strict = corpus(<<0x11, 0xCB, 0x41>>, @logical_bytes - 1) <> <<invalid>>
    small_recovery = recovery_corpus(invalid, div(@logical_bytes, 2))
    large_recovery = recovery_corpus(invalid, @logical_bytes)

    {:error, :invalid_sequence, _, <<^invalid>>} = codec.decode_to_utf8(small_strict)

    {:error, %Iconvex.Error{kind: :invalid_sequence}} =
      Iconvex.convert(small_strict, name, "UTF-8")

    {:ok, _} = codec.decode_discard(small_recovery)
    {:ok, _} = Iconvex.convert(small_recovery, name, "UTF-8", invalid: :discard)
    {:ok, _} = Iconvex.convert(small_recovery, name, "UTF-8", byte_substitute: "<%02x>")

    [
      {"direct invalid strict", fn -> codec.decode_to_utf8(small_strict) end,
       fn -> codec.decode_to_utf8(large_strict) end, byte_size(large_strict), :direct_error},
      {"direct invalid discard", fn -> codec.decode_discard(small_recovery) end,
       fn -> codec.decode_discard(large_recovery) end, byte_size(large_recovery), :ok},
      {"public invalid strict", fn -> Iconvex.convert(small_strict, name, "UTF-8") end,
       fn -> Iconvex.convert(large_strict, name, "UTF-8") end, byte_size(large_strict),
       :public_error},
      {"public invalid discard",
       fn -> Iconvex.convert(small_recovery, name, "UTF-8", invalid: :discard) end,
       fn -> Iconvex.convert(large_recovery, name, "UTF-8", invalid: :discard) end,
       byte_size(large_recovery), :ok},
      {"public invalid replace",
       fn -> Iconvex.convert(small_recovery, name, "UTF-8", byte_substitute: "<%02x>") end,
       fn -> Iconvex.convert(large_recovery, name, "UTF-8", byte_substitute: "<%02x>") end,
       byte_size(large_recovery), :ok}
    ]
  end

  defp benchmark_and_gate(
         name,
         family,
         {operation, small_fun, large_fun, input_bytes, expectation}
       ) do
    microseconds = median_us(large_fun, expectation)
    mib_per_second = input_bytes / 1_048_576 / (microseconds / 1_000_000)

    IO.puts(
      Enum.join(
        [name, operation, Float.round(mib_per_second, 2), microseconds],
        "\t"
      )
    )

    throughput_floor = @throughput_floors |> Map.fetch!(family) |> Map.fetch!(operation)

    IO.puts(
      "#{name} #{operation} throughput floor: " <>
        "#{Float.round(mib_per_second, 2)} >= #{throughput_floor} Mi input bytes/s"
    )

    if mib_per_second < throughput_floor do
      raise "#{name} #{operation} throughput #{mib_per_second} is below #{throughput_floor}"
    end

    small_reductions = median_reductions(small_fun, expectation)
    large_reductions = median_reductions(large_fun, expectation)
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

  defp median_us(function, expectation) do
    Enum.each(1..@warmups, fn _ -> assert_result(function.(), expectation) end)

    for _ <- 1..@samples do
      :erlang.garbage_collect()
      {microseconds, result} = :timer.tc(function)
      assert_result(result, expectation)
      microseconds
    end
    |> Enum.sort()
    |> Enum.at(div(@samples, 2))
  end

  defp median_reductions(function, expectation) do
    for(_ <- 1..@reduction_samples, do: isolated_reductions(function, expectation))
    |> Enum.sort()
    |> Enum.at(div(@reduction_samples, 2))
  end

  defp isolated_reductions(function, expectation) do
    parent = self()
    token = make_ref()

    {_pid, monitor} =
      spawn_monitor(fn ->
        :erlang.garbage_collect()
        {:reductions, before_count} = Process.info(self(), :reductions)
        assert_result(function.(), expectation)
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

  defp verify_reverse_policy_boundary do
    for codec <- [Iconvex.Specs.TI83PlusLarge, Iconvex.Specs.TI83PlusSmall] do
      {:ok, <<0x11>>} = codec.encode([0x207B, 0x00B9])
      {:ok, <<0xCB>>} = codec.encode([?x, 0x0305])
      {:ok, <<0xCC>>} = codec.encode([?y, 0x0305])
      {:ok, <<0xD8>>} = codec.encode([?p, 0x0302])
      {:ok, <<?1, ?0>>} = codec.encode([?1, ?0])
      {:ok, <<?), ?)>>} = codec.encode([?), ?)])
    end
  end

  defp corpus(alphabet, bytes) do
    copies = div(bytes + byte_size(alphabet) - 1, byte_size(alphabet))
    alphabet |> :binary.copy(copies) |> binary_part(0, bytes)
  end

  defp recovery_corpus(invalid, bytes) do
    corpus(<<0x11, 0xCB, 0x41, invalid>>, bytes)
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
            "no exact normalized TI-83 alias was listed"
        )

      aliases ->
        IO.puts(
          "GNU support listing includes exact normalized TI-83 aliases after querying iconv -l " <>
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

  defp assert_result({:ok, _result}, :ok), do: :ok
  defp assert_result({:error, :invalid_sequence, _offset, _sequence}, :direct_error), do: :ok

  defp assert_result(
         {:error, %Iconvex.Error{kind: :invalid_sequence}},
         :public_error
       ),
       do: :ok

  defp assert_result(error, expectation),
    do: raise("TI-83 benchmark expected #{expectation}, got: #{inspect(error)}")
end

if "--gnu-probe-only" in System.argv() do
  Iconvex.Specs.TI83Plus2002Benchmark.report_gnu_status()
else
  Iconvex.Specs.TI83Plus2002Benchmark.run()
end
