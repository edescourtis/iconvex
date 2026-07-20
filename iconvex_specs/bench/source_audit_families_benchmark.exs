defmodule Iconvex.Specs.SourceAuditFamiliesBenchmark do
  @moduledoc false

  @quick "--quick" in System.argv()
  @calibrate "--calibrate" in System.argv()
  @samples if(@quick, do: 5, else: 9)
  @warmups 2
  @units if(@quick, do: 8_192, else: 65_536)
  @small_units 2_048
  @large_units 4_096
  @slowdown_ceiling 30.0
  # Stateful escape codecs can cross a table/escape-mode boundary between the
  # two samples. Keep a hard super-linear guard while allowing that fixed-mode
  # transition overhead.
  @scaling_bounds {1.20, 4.00}

  # Populated only from a successful production/quick calibration run. Every
  # executable floor is this measured rate / @slowdown_ceiling.
  @recorded_mib_per_second %{
    {"utf8-mac", :encode} => 20.483,
    {"utf8-mac", :decode} => 14.513,
    {"cpython-iso2022-jp-ext", :encode} => 22.993,
    {"cpython-iso2022-jp-ext", :decode} => 3.873,
    {"dotnet-x-europa", :encode} => 32.442,
    {"dotnet-x-europa", :decode} => 107.021,
    {"dotnet-cp50227", :encode} => 24.001,
    {"dotnet-cp50227", :decode} => 8.937,
    {"glibc-ibm423", :encode} => 18.355,
    {"glibc-ibm423", :decode} => 11.035,
    {"windows-best-fit-1252", :encode} => 20.736,
    {"windows-best-fit-1252", :decode} => 11.322,
    {"iana-amiga1251", :encode} => 36.975,
    {"iana-amiga1251", :decode} => 107.021,
    {"iana-pcl-hp-desktop", :encode} => 14.694,
    {"iana-pcl-hp-desktop", :decode} => 11.855,
    {"iana-iso10646-basic", :encode} => 18.780,
    {"iana-iso10646-basic", :decode} => 90.843,
    {"ibm-ccsid-1200", :encode} => 24.381,
    {"ibm-ccsid-1200", :decode} => 24.342
  }

  @seed [
    ?A,
    ?z,
    ?0,
    ?!,
    0x00A3,
    0x00E9,
    0x03A9,
    0x0410,
    0x3042,
    0x30A2,
    0x4E2D,
    0x56FD,
    0x9999,
    0x20AC,
    0xFF76,
    0x1F600
  ]

  @cases [
    %{id: "utf8-mac", family: "utf8-mac", codec: Iconvex.Specs.UTF8Mac},
    %{id: "cpython-iso2022-jp-ext", family: "cpython", codec: Iconvex.Specs.CPythonISO2022JPExt},
    %{id: "dotnet-x-europa", family: "dotnet", codec: Iconvex.Specs.DotnetXEuropa},
    %{id: "dotnet-cp50227", family: "dotnet", codec: Iconvex.Specs.DotnetCP50227},
    %{id: "glibc-ibm423", family: "glibc", codec: Iconvex.Specs.GlibcIBM423},
    %{
      id: "windows-best-fit-1252",
      family: "windows-best-fit",
      codec: Iconvex.Specs.WindowsBestFit.Codecs.C8
    },
    %{id: "iana-amiga1251", family: "iana", codec: Iconvex.Specs.IANAAmiga1251},
    %{
      id: "iana-pcl-hp-desktop",
      family: "iana",
      codec: Iconvex.Specs.IANAPCLSymbolSets.Codecs.C1
    },
    %{
      id: "iana-iso10646-basic",
      family: "iana",
      codec: Iconvex.Specs.IANAISO10646Profiles.Codecs.Basic
    },
    %{id: "ibm-ccsid-1200", family: "ibm-ccsid", codec: Iconvex.Specs.IBMUnicodeCCSIDs.Codec}
  ]

  def run do
    IO.puts("schema\ticonvex-source-audit-families-benchmark\t1")
    IO.puts("mode\t#{if(@quick, do: "quick", else: "production")}")
    IO.puts("calibration\t#{@calibrate}")

    IO.puts(
      "columns\tfamily\tprofile\toperation\tinput_bytes\tmedian_us\t" <>
        "mib_per_second\tfloor_mib_per_second\tsmall_reductions\t" <>
        "large_reductions\treduction_scaling"
    )

    Enum.each(@cases, &benchmark_case/1)
    cpython_comparison()

    IO.puts(
      "summary\t#{length(@cases)} representative profiles\t" <>
        "#{@slowdown_ceiling |> trunc()}x floors\tall performance gates passed"
    )
  end

  defp benchmark_case(spec) do
    timing = corpus(spec.codec, @units)
    small = corpus(spec.codec, @small_units)
    large = corpus(spec.codec, @large_units)

    benchmark_operation(spec, :encode, timing, small, large)
    benchmark_operation(spec, :decode, timing, small, large)
  end

  defp benchmark_operation(spec, operation, timing, small, large) do
    {timing_fun, expected, input_bytes} = operation(spec.codec, operation, timing)
    {small_fun, small_expected, _small_bytes} = operation(spec.codec, operation, small)
    {large_fun, large_expected, _large_bytes} = operation(spec.codec, operation, large)

    assert_result!(timing_fun.(), expected, spec.id, operation)
    median_us = median_us(timing_fun, expected, spec.id, operation)
    small_reductions = reductions(small_fun, small_expected, spec.id, operation)
    large_reductions = reductions(large_fun, large_expected, spec.id, operation)
    scaling = large_reductions / max(small_reductions, 1)
    mib_per_second = input_bytes / 1_048_576 / (median_us / 1_000_000)
    floor = floor_for(spec.id, operation)

    gate!(spec.id, operation, mib_per_second, floor, scaling)

    IO.puts(
      Enum.join(
        [
          "result",
          spec.family,
          spec.id,
          operation,
          input_bytes,
          median_us,
          decimal(mib_per_second),
          decimal(floor),
          small_reductions,
          large_reductions,
          decimal(scaling)
        ],
        "\t"
      )
    )
  end

  defp corpus(codec, units) do
    round_trippable =
      Enum.filter(@seed, fn codepoint ->
        case codec.encode([codepoint]) do
          {:ok, encoded} -> codec.decode(encoded) == {:ok, [codepoint]}
          _ -> false
        end
      end)

    if round_trippable == [], do: raise("#{inspect(codec)} has no benchmark seed")

    codepoints =
      round_trippable
      |> Stream.cycle()
      |> Enum.take(units)

    {:ok, encoded} = codec.encode(codepoints)
    {:ok, ^codepoints} = codec.decode(encoded)
    %{codepoints: codepoints, encoded: encoded, utf8: List.to_string(codepoints)}
  end

  defp operation(codec, :encode, corpus),
    do: {fn -> codec.encode(corpus.codepoints) end, {:ok, corpus.encoded}, byte_size(corpus.utf8)}

  defp operation(codec, :decode, corpus),
    do:
      {fn -> codec.decode(corpus.encoded) end, {:ok, corpus.codepoints},
       byte_size(corpus.encoded)}

  defp median_us(fun, expected, id, operation) do
    repeat(@warmups, fn -> assert_result!(fun.(), expected, id, operation) end)

    1..@samples
    |> Enum.map(fn _ ->
      :erlang.garbage_collect()
      started = System.monotonic_time()
      assert_result!(fun.(), expected, id, operation)

      (System.monotonic_time() - started)
      |> System.convert_time_unit(:native, :microsecond)
      |> max(1)
    end)
    |> Enum.sort()
    |> Enum.at(div(@samples, 2))
  end

  defp reductions(fun, expected, id, operation) do
    parent = self()

    pid =
      spawn(fn ->
        receive do
          :go ->
            {:reductions, before_count} = Process.info(self(), :reductions)
            result = fun.()
            {:reductions, after_count} = Process.info(self(), :reductions)
            send(parent, {:reductions, self(), result, after_count - before_count})
        end
      end)

    send(pid, :go)

    receive do
      {:reductions, ^pid, result, count} ->
        assert_result!(result, expected, id, operation)
        count
    after
      30_000 -> raise("#{id} #{operation} reduction sample timed out")
    end
  end

  defp floor_for(id, operation) do
    case Map.fetch(@recorded_mib_per_second, {id, operation}) do
      {:ok, recorded} ->
        recorded / @slowdown_ceiling

      :error ->
        if @calibrate,
          do: 0.0,
          else: raise("missing calibrated floor for #{id} #{operation}")
    end
  end

  defp gate!(id, operation, rate, floor, scaling) do
    unless @calibrate or rate >= floor do
      raise "#{id} #{operation} #{decimal(rate)} MiB/s is below #{decimal(floor)} MiB/s"
    end

    {minimum_scaling, maximum_scaling} = @scaling_bounds

    unless scaling >= minimum_scaling and scaling <= maximum_scaling do
      raise "#{id} #{operation} reduction scaling #{decimal(scaling)} is outside " <>
              "#{minimum_scaling}..#{maximum_scaling}"
    end
  end

  defp cpython_comparison do
    spec = Enum.find(@cases, &(&1.id == "cpython-iso2022-jp-ext"))
    corpus = corpus(spec.codec, 1_024)

    case System.find_executable("python3") do
      nil ->
        IO.puts(
          "comparator\tcpython\tunavailable\tpython3 not found; native floors remain active"
        )

      python ->
        for operation <- [:encode, :decode] do
          {native_fun, expected, _bytes} = operation(spec.codec, operation, corpus)
          native_us = median_us(native_fun, expected, spec.id, operation)
          {oracle_us, oracle} = python_oracle(python, operation, corpus)
          assert_result!(oracle, expected, "CPython oracle", operation)
          ratio = native_us / max(oracle_us, 1)

          if ratio > @slowdown_ceiling do
            raise "#{spec.id} #{operation} is #{decimal(ratio)}x CPython, above #{@slowdown_ceiling}x"
          end

          IO.puts(
            "comparator\tcpython\t#{operation}\t#{native_us}\t#{oracle_us}\t#{decimal(ratio)}"
          )
        end
    end
  end

  defp python_oracle(python, :encode, corpus) do
    script = """
    import sys,time
    value=bytes.fromhex(sys.argv[1]).decode('utf-8')
    loops=int(sys.argv[2])
    started=time.perf_counter_ns()
    for _ in range(loops): result=value.encode('iso2022_jp_ext')
    print(max(1,(time.perf_counter_ns()-started)//loops//1000))
    print(result.hex())
    """

    python_result(python, script, Base.encode16(corpus.utf8, case: :lower), {:binary, :encode})
  end

  defp python_oracle(python, :decode, corpus) do
    script = """
    import sys,time
    value=bytes.fromhex(sys.argv[1])
    loops=int(sys.argv[2])
    started=time.perf_counter_ns()
    for _ in range(loops): result=value.decode('iso2022_jp_ext')
    print(max(1,(time.perf_counter_ns()-started)//loops//1000))
    print(result.encode('utf-8').hex())
    """

    python_result(python, script, Base.encode16(corpus.encoded, case: :lower), {:utf8, :decode})
  end

  defp python_result(python, script, hex, {kind, operation}) do
    {output, 0} = System.cmd(python, ["-c", script, hex, "20"], stderr_to_stdout: true)
    [microseconds, result] = String.split(output, "\n", trim: true)

    expected =
      case kind do
        :binary -> {:ok, Base.decode16!(result, case: :mixed)}
        :utf8 -> {:ok, result |> Base.decode16!(case: :mixed) |> String.to_charlist()}
      end

    {String.to_integer(microseconds), expected}
  rescue
    error -> raise "CPython #{operation} comparator failed: #{Exception.message(error)}"
  end

  defp assert_result!(actual, expected, _id, _operation) when actual == expected, do: :ok

  defp assert_result!(actual, expected, id, operation),
    do: raise("#{id} #{operation} result mismatch: #{inspect(actual)} != #{inspect(expected)}")

  defp repeat(count, fun), do: Enum.each(1..count, fn _ -> fun.() end)
  defp decimal(value), do: :erlang.float_to_binary(value / 1, decimals: 3)
end

Iconvex.Specs.SourceAuditFamiliesBenchmark.run()
