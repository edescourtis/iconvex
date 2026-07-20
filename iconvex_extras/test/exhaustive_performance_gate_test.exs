runner = Path.expand("../tools/exhaustive_unicode_differential.exs", __DIR__)
source = File.read!(runner)

source_without_entrypoint =
  String.replace(
    source,
    "\nIconvex.ExhaustiveUnicodeDifferential.run(System.argv())\n",
    "\n"
  )

unless source_without_entrypoint != source,
  do: raise("could not remove exhaustive runner entrypoint")

Code.compile_string(source_without_entrypoint, runner)

defmodule Iconvex.ExhaustivePerformanceGateTest do
  use ExUnit.Case, async: false

  alias Iconvex.ExhaustiveUnicodeDifferential, as: Differential
  alias Iconvex.Extras.CodecSupport

  @root Path.expand("..", __DIR__)
  @runner Path.join(@root, "tools/exhaustive_unicode_differential.exs")
  @helper Path.join(@root, "tools/gnu_iconv_engine_benchmark.c")

  test "reports forward and reverse slowdown independently" do
    result = result("DIRECTIONAL", 310, 10, 20, 10)

    report =
      Path.join(System.tmp_dir!(), "iconvex-directional-#{System.unique_integer([:positive])}.md")

    on_exit(fn -> File.rm(report) end)

    Differential.write_report!(
      report,
      @root,
      <<0>>,
      "/bin/echo",
      [result],
      1,
      30.0,
      benchmark_metadata(),
      execution_metadata()
    )

    contents = File.read!(report)

    assert contents =~ "Performance failures: **1**"
    assert contents =~ "| Worst slowdown | Forward slowdown | Reverse slowdown |"
    assert contents =~ "| `DIRECTIONAL` | PASS | 31.00x | 31.00x | 2.00x |"
    assert contents =~ "| 310 | 10 | 20 | 10 |"
  end

  test "documents the isolated repeated-sample benchmark method" do
    result = result("SAMPLED", 10, 10, 10, 10)

    report =
      Path.join(System.tmp_dir!(), "iconvex-sampled-#{System.unique_integer([:positive])}.md")

    on_exit(fn -> File.rm(report) end)

    Differential.write_report!(
      report,
      @root,
      <<0>>,
      "/bin/echo",
      [result],
      1,
      30.0,
      benchmark_metadata(),
      execution_metadata()
    )

    contents = File.read!(report)

    assert function_exported?(Differential, :timing_sample_count, 0)
    assert Differential.timing_sample_count() == 3
    assert contents =~ "fastest of **3** isolated samples"
    assert contents =~ "Timing unit: **microseconds"
    assert contents =~ "GNU engine forward µs"
    assert contents =~ "GNU engine reverse µs"
    assert contents =~ "one untimed Iconvex conversion before each directional timing"
    assert contents =~ "Every timed sample output must equal that warm output"
  end

  test "binds the captured execution environment and timing constants into the report" do
    report =
      Path.join(
        System.tmp_dir!(),
        "iconvex-execution-bound-#{System.unique_integer([:positive])}.md"
      )

    on_exit(fn -> File.rm(report) end)

    Differential.write_report!(
      report,
      @root,
      <<0>>,
      "/bin/echo",
      [result("ENVIRONMENT", 10, 10, 10, 10)],
      1,
      30.0,
      benchmark_metadata(),
      execution_metadata()
    )

    contents = File.read!(report)

    assert contents =~ "Elixir version: `fixture-elixir`"
    assert contents =~ "OTP release: `fixture-otp`"
    assert contents =~ "ERTS version: `fixture-erts`"
    assert contents =~ "OS family/name: `fixture-family/fixture-name`"
    assert contents =~ "OS version: `98.76.54-fixture`"
    assert contents =~ "System architecture: `fixture-architecture`"
    assert contents =~ "Schedulers online: **17**"
    assert contents =~ "Word size: **64 bits (8 bytes)**"
    assert contents =~ "Timing samples per direction: **3**"
    assert contents =~ "Minimum calibrated sample duration: **1,000,000 ns**"
    assert contents =~ "Maximum calibrated batch iterations: **1,048,576**"

    captured = Differential.execution_metadata()

    assert captured.elixir_version == System.version()
    assert captured.otp_release == System.otp_release()
    assert captured.erts_version == List.to_string(:erlang.system_info(:version))

    assert captured.system_architecture ==
             List.to_string(:erlang.system_info(:system_architecture))

    assert captured.schedulers_online == :erlang.system_info(:schedulers_online)
    assert captured.word_size_bytes == :erlang.system_info(:wordsize)
    assert captured.timing_samples == 3
    assert captured.minimum_sample_ns == 1_000_000
    assert captured.maximum_batch_iterations == 1_048_576
  end

  test "RED: warms once and verifies every timed Iconvex sample against that output" do
    counter = :counters.new(1, [])

    conversion = fn ->
      :counters.add(counter, 1, 1)
      Process.sleep(2)
      <<0x41>>
    end

    assert function_exported?(Differential, :warm_and_timed_us, 1)
    assert {<<0x41>>, elapsed_us} = Differential.warm_and_timed_us(conversion)
    assert elapsed_us > 0
    assert :counters.get(counter, 1) == 4

    changing_counter = :counters.new(1, [])

    changing_conversion = fn ->
      :counters.add(changing_counter, 1, 1)
      Process.sleep(2)

      if :counters.get(changing_counter, 1) == 1 do
        :warm
      else
        :changed
      end
    end

    assert_raise RuntimeError, ~r/timed Iconvex output differs from untimed warm output/, fn ->
      Differential.warm_and_timed_us(changing_conversion)
    end
  end

  test "RED: validates sample output only after the calibrated timing window returns" do
    timed_mfa = {Differential, :timed_batch_us, 2}
    validate_mfa = {Differential, :validate_timed_output!, 2}
    parent = self()
    tracer = spawn_link(fn -> forward_traces(parent) end)

    :erlang.trace(self(), true, [:call, {:tracer, tracer}])
    :erlang.trace_pattern(timed_mfa, true, [:local])

    try do
      assert :erlang.trace_pattern(validate_mfa, true, [:local]) == 1

      assert {<<0x41>>, elapsed_us} =
               Differential.warm_and_timed_us(fn ->
                 Process.sleep(2)
                 <<0x41>>
               end)

      assert elapsed_us > 0

      calls =
        for _index <- 1..6 do
          assert_receive {:trace_event, {:trace, _pid, :call, {module, function, arguments}}},
                         1_000

          {module, function, length(arguments)}
        end

      assert calls ==
               List.flatten(
                 List.duplicate(
                   [
                     {Differential, :timed_batch_us, 2},
                     {Differential, :validate_timed_output!, 2}
                   ],
                   3
                 )
               )
    after
      :erlang.trace_pattern(timed_mfa, false, [:local])
      :erlang.trace_pattern(validate_mfa, false, [:local])
      :erlang.trace(self(), false, [:call])
      send(tracer, :stop)
    end
  end

  test "binds the offline engine helper and exact GNU library into the report" do
    assert File.regular?(@helper)

    helper_source = File.read!(@helper)
    runner_source = File.read!(@runner)

    assert helper_source =~ "CLOCK_MONOTONIC"
    assert helper_source =~ "iconv_open"
    assert helper_source =~ "engine_us="
    assert helper_source =~ "read_input"

    refute runner_source =~ "timed(fn -> gnu_convert_file!"
    refute runner_source =~ "iconvex_ms / max(gnu_ms, 1)"

    report =
      Path.join(
        System.tmp_dir!(),
        "iconvex-helper-bound-#{System.unique_integer([:positive])}.md"
      )

    on_exit(fn -> File.rm(report) end)

    Differential.write_report!(
      report,
      @root,
      <<0>>,
      "/bin/echo",
      [result("BOUND", 10, 10, 10, 10)],
      1,
      30.0,
      benchmark_metadata(),
      execution_metadata()
    )

    contents = File.read!(report)

    assert contents =~ "GNU CLI executable: `/bin/echo`"
    assert contents =~ "GNU libiconv header: `/gnu/include/iconv.h`"
    assert contents =~ "GNU libiconv header SHA-256: `header-digest`"
    assert contents =~ "GNU timing helper source: `/source/gnu_iconv_engine_benchmark.c`"
    assert contents =~ "GNU timing helper source SHA-256: `helper-source-digest`"
    assert contents =~ "GNU timing helper executable: `/helper/gnu_iconv_engine_benchmark`"
    assert contents =~ "GNU timing helper executable SHA-256: `helper-executable-digest`"
    assert contents =~ "GNU libiconv benchmark artifact: `/gnu/lib/libiconv.a`"
    assert contents =~ "GNU libiconv benchmark artifact SHA-256: `library-digest`"
    assert contents =~ "GNU benchmark timings exclude process startup, file I/O, and stdout"
    assert contents =~ "GNU CLI output remains the byte-correctness oracle"
  end

  test "uses the helper's internal microseconds instead of command wall time" do
    unique = System.unique_integer([:positive])
    helper = Path.join(System.tmp_dir!(), "iconvex-fake-engine-helper-#{unique}.sh")
    input = Path.join(System.tmp_dir!(), "iconvex-fake-engine-input-#{unique}.bin")

    File.write!(
      helper,
      "#!/bin/sh\nsleep 0.05\nprintf 'engine_us=123\\nsamples=3\\ninput_bytes=1\\noutput_bytes=1\\n'\n"
    )

    File.chmod!(helper, 0o755)
    File.write!(input, <<0>>)

    on_exit(fn ->
      File.rm(helper)
      File.rm(input)
    end)

    assert Differential.gnu_engine_time!(helper, input, "ASCII", "UTF-8") == 123
  end

  test "renders a failed conversion without dividing zero timing placeholders" do
    failed =
      result("FAILED", 0, 0, 0, 0)
      |> Map.put(:status, "FAIL")
      |> Map.put(:mismatch, "conversion failed")

    report =
      Path.join(System.tmp_dir!(), "iconvex-failed-row-#{System.unique_integer([:positive])}.md")

    on_exit(fn -> File.rm(report) end)

    Differential.write_report!(
      report,
      @root,
      <<0>>,
      "/bin/echo",
      [failed],
      1,
      30.0,
      benchmark_metadata(),
      execution_metadata()
    )

    assert File.read!(report) =~ "| `FAILED` | FAIL | - | - | - |"
  end

  test "real GNU 1.19 helper ignores unrepresentable code points and matches CLI sizes" do
    iconv =
      System.get_env("GNU_ICONV") ||
        Enum.find(
          [
            "/opt/homebrew/opt/libiconv/bin/iconv",
            "/tmp/libiconv-1.19-extra-install/bin/iconv"
          ],
          &File.regular?/1
        )

    if iconv do
      {version, 0} = System.cmd(iconv, ["--version"])
      assert version =~ "GNU libiconv 1.19"

      benchmark = Differential.prepare_gnu_benchmark!(iconv)
      corpus = Path.join(@root, "test/fixtures/all-unicode-codepoints.ucs4be")

      for codec <- ["US-ASCII", "CP943"] do
        {cli_output, 0} =
          System.cmd(iconv, ["-f", "UCS-4BE", "-t", codec <> "//IGNORE", corpus])

        measurement =
          Differential.gnu_engine_measure!(benchmark.helper, corpus, "UCS-4BE", codec)

        assert measurement.engine_us > 0
        assert measurement.output_bytes == byte_size(cli_output)
      end
    else
      # Ordinary package tests do not require an external C toolchain/reference.
      # The source-level contracts above remain active on those hosts.
      assert File.regular?(@helper)
    end
  end

  test "real all-codepoint UTF-8 and US-ASCII smoke remains within the 30x engine gate" do
    iconv =
      System.get_env("GNU_ICONV") ||
        Enum.find(
          [
            "/opt/homebrew/opt/libiconv/bin/iconv",
            "/tmp/libiconv-1.19-extra-install/bin/iconv"
          ],
          &File.regular?/1
        )

    if iconv do
      {version, 0} = System.cmd(iconv, ["--version"])
      assert version =~ "GNU libiconv 1.19"

      benchmark = Differential.prepare_gnu_benchmark!(iconv)
      corpus_path = Path.join(@root, "test/fixtures/all-unicode-codepoints.ucs4be")
      corpus = File.read!(corpus_path)

      results =
        for codec <- ["UTF-8", "US-ASCII"] do
          result = Differential.compare_codec(codec, corpus, corpus_path, iconv, benchmark)
          assert result.status == "PASS", "#{codec}: #{result.mismatch}"
          result
        end

      assert Differential.performance_breaches(results, 30.0) == []
    else
      assert File.regular?(@helper)
    end
  end

  test "gates forward and reverse breaches independently" do
    forward_only = result("FORWARD", 310, 10, 1, 10)
    reverse_only = result("REVERSE", 1, 10, 310, 10)
    passing = result("PASSING", 300, 10, 300, 10)

    assert Differential.performance_breaches(
             [forward_only, reverse_only, passing],
             30.0
           ) == [
             %{codec: "FORWARD", direction: :forward, slowdown: 31.0},
             %{codec: "REVERSE", direction: :reverse, slowdown: 31.0}
           ]
  end

  test "Extras hotspots use specialized linear discard paths without changing table results" do
    assert CodecSupport.optimized_discard_paths() == %{
             cp943: [:decode],
             euc_jisx0213: [:decode, :encode]
           }

    assert CodecSupport.optimization_cache_sizes() == %{
             cp943_decode: 65_536 * 4,
             euc_jisx0213_double_decode: 65_536 * 8,
             euc_jisx0213_triple_decode: 65_536 * 8
           }

    for id <- [:cp943, :euc_jisx0213] do
      entry = %{id: id, table_app: :iconvex_extras}
      table = Iconvex.Tables.fetch!(entry)

      encoded =
        table.many
        |> Map.keys()
        |> Enum.sort()
        |> IO.iodata_to_binary()

      assert CodecSupport.decode_discard(id, encoded) ==
               Iconvex.TableCodec.decode_discard(entry, encoded)
    end

    entry = %{id: :euc_jisx0213, table_app: :iconvex_extras}
    table = Iconvex.Tables.fetch!(entry)

    {{first, second}, _bytes} =
      Enum.find(table.encode, fn {key, _bytes} -> tuple_size(key) == 2 end)

    {{single}, _bytes} = Enum.find(table.encode, fn {key, _bytes} -> tuple_size(key) == 1 end)
    codepoints = [single, first, second, 0x10FFFF]

    assert CodecSupport.encode_discard(:euc_jisx0213, codepoints) ==
             Iconvex.TableCodec.encode_discard(entry, codepoints)
  end

  test "CP943 and EUC-JISX0213 decode valid multibyte streams directly to UTF-8" do
    assert CodecSupport.optimized_utf8_paths() == [:cp943, :euc_jisx0213]

    for id <- CodecSupport.optimized_utf8_paths() do
      entry = %{id: id, table_app: :iconvex_extras}
      table = Iconvex.Tables.fetch!(entry)

      encoded =
        table.many
        |> Map.keys()
        |> Enum.sort()
        |> IO.iodata_to_binary()

      assert {:ok, codepoints} = Iconvex.TableCodec.decode(entry, encoded)
      expected = :unicode.characters_to_binary(codepoints, :unicode, :utf8)
      assert CodecSupport.decode_to_utf8(id, encoded) == {:ok, expected}

      invalid = if id == :cp943, do: <<0x81>>, else: <<0x8F, 0xA1>>
      assert CodecSupport.decode_to_utf8(id, invalid) == :miss
    end
  end

  test "EUC-JISX0213 emits explicit UCS-4 directly from its dense decode caches" do
    direct_mfa = {CodecSupport, :decode_euc_jisx0213_to_ucs4_discard, 2}
    utf8_mfa = {CodecSupport, :decode_to_utf8, 2}

    Code.ensure_loaded!(CodecSupport)
    assert function_exported?(CodecSupport, :decode_euc_jisx0213_to_ucs4_discard, 2)

    entry = %{id: :euc_jisx0213, table_app: :iconvex_extras}
    table = Iconvex.Tables.fetch!(entry)

    encoded =
      table.many
      |> Map.keys()
      |> Enum.sort()
      |> IO.iodata_to_binary()

    assert {:ok, codepoints} = Iconvex.TableCodec.decode_discard(entry, encoded)
    assert {:ok, expected_big} = Iconvex.UnicodeCodec.encode(%{id: :ucs4be}, codepoints)
    assert {:ok, expected_little} = Iconvex.UnicodeCodec.encode(%{id: :ucs4le}, codepoints)

    Enum.each([direct_mfa, utf8_mfa], &:erlang.trace_pattern(&1, true, [:local, :call_count]))

    try do
      assert CodecSupport.decode_to_ucs4_discard(:euc_jisx0213, encoded, :big) ==
               {:ok, expected_big}

      assert :erlang.trace_info(direct_mfa, :call_count) == {:call_count, 1}
      assert :erlang.trace_info(utf8_mfa, :call_count) == {:call_count, 0}
    after
      Enum.each([direct_mfa, utf8_mfa], &:erlang.trace_pattern(&1, false, [:local, :call_count]))
    end

    assert CodecSupport.decode_euc_jisx0213_to_ucs4_discard(encoded, :little) ==
             {:ok, expected_little}
  end

  test "dense decode caches are rebuilt when a provider table changes without a VM restart" do
    id = :cp943
    entry = %{id: id, table_app: :iconvex_extras}
    table = Iconvex.Tables.fetch!(entry)
    {bytes, {original}} = Enum.find(table.many, fn {_bytes, value} -> tuple_size(value) == 1 end)
    replacement = if original == 0x2603, do: 0x2604, else: 0x2603

    assert CodecSupport.decode_to_utf8(id, bytes) == {:ok, <<original::utf8>>}

    cache_key = {{Iconvex.Tables, :table}, :iconvex_extras, id}
    previous = :persistent_term.get(cache_key)
    cache_version = {1, Application.spec(:iconvex_extras, :vsn) || ~c"unloaded"}
    changed = put_in(table, [:many, bytes], {replacement})

    :persistent_term.put(cache_key, {1, cache_version, changed})
    on_exit(fn -> :persistent_term.put(cache_key, previous) end)

    assert CodecSupport.decode_to_utf8(id, bytes) == {:ok, <<replacement::utf8>>}
  end

  test "generated fixed codecs expose direct UCS-4 discard adapters with table parity" do
    modules = Iconvex.Extras.Codecs.modules()
    stateful = Iconvex.Extras.Codecs.Iso2022Jp3

    for module <- modules -- [stateful] do
      assert function_exported?(module, :decode_to_ucs4_discard, 2), inspect(module)
      assert function_exported?(module, :encode_from_ucs4_discard, 2), inspect(module)
    end

    for id <- [:cp858, :ebcdic037, :cp943, :dec_hanyu, :euc_jisx0213, :shift_jisx0213] do
      entry = %{id: id, table_app: :iconvex_extras}
      table = Iconvex.Tables.fetch!(entry)

      encoded =
        if table.max_input == 1 do
          IO.iodata_to_binary(for byte <- 0..0xFF, do: <<byte>>)
        else
          table.many
          |> Map.keys()
          |> Enum.sort()
          |> IO.iodata_to_binary()
        end

      encoded =
        if MapSet.size(table.prefixes) == 0 do
          encoded
        else
          encoded <> <<0xFF>> <> Enum.min_by(table.prefixes, &byte_size/1)
        end

      assert {:ok, codepoints} = Iconvex.TableCodec.decode_discard(entry, encoded)
      assert {:ok, expected} = Iconvex.UnicodeCodec.encode(%{id: :ucs4be}, codepoints)

      assert CodecSupport.decode_to_ucs4_discard(id, encoded, :big) == {:ok, expected}
    end

    corpus = Path.join(@root, "test/fixtures/all-unicode-codepoints.ucs4be") |> File.read!()
    assert {:ok, codepoints} = Iconvex.UnicodeCodec.decode(%{id: :ucs4be}, corpus)

    for id <- [:cp858, :ebcdic037] do
      entry = %{id: id, table_app: :iconvex_extras}
      assert expected = Iconvex.TableCodec.encode_discard(entry, codepoints)
      assert CodecSupport.encode_from_ucs4_discard(id, corpus, :big) == expected
    end

    shift_entry = %{id: :shift_jisx0213, table_app: :iconvex_extras}
    shift_table = Iconvex.Tables.fetch!(shift_entry)

    pair_corpus =
      shift_table.encode
      |> Map.keys()
      |> Enum.filter(&(tuple_size(&1) == 2))
      |> Enum.sort()
      |> Enum.flat_map(&Tuple.to_list/1)
      |> then(&(&1 ++ [0x110000]))
      |> Enum.map(fn codepoint -> <<codepoint::unsigned-big-32>> end)
      |> IO.iodata_to_binary()

    assert {:ok, pair_codepoints} = Iconvex.UnicodeCodec.decode(%{id: :ucs4be}, pair_corpus)
    assert pair_expected = Iconvex.TableCodec.encode_discard(shift_entry, pair_codepoints)

    assert CodecSupport.encode_from_ucs4_discard(:shift_jisx0213, pair_corpus, :big) ==
             pair_expected
  end

  test "JISX0213 direct UCS-4 encoding bypasses lookups for provably unmapped ranges" do
    skipped? = fn codepoint ->
      codepoint in 0xA000..0xEFFF or codepoint in 0x10000..0x1FFFF or
        codepoint > 0x2A6B2
    end

    for id <- [:euc_jisx0213, :shift_jisx0213] do
      encode = Iconvex.Tables.fetch!(%{id: id, table_app: :iconvex_extras}).encode

      refute Enum.any?(encode, fn
               {{codepoint}, _bytes} -> skipped?.(codepoint)
               {{first, _second}, _bytes} -> skipped?.(first)
             end)
    end

    input =
      for codepoint <- [?A, 0xA000, 0xEFFF, 0x10000, 0x1FFFF, 0x2A6B3, 0x10FFFF],
          into: <<>>,
          do: <<codepoint::unsigned-big-32>>

    for id <- [:euc_jisx0213, :shift_jisx0213] do
      assert CodecSupport.encode_from_ucs4_discard(id, input, :big) == {:ok, "A"}
    end

    unmapped = :binary.copy(<<0x30000::unsigned-big-32>>, 50_000)
    assert CodecSupport.encode_from_ucs4_discard(:shift_jisx0213, unmapped, :big) == {:ok, ""}

    {:reductions, before_reductions} = Process.info(self(), :reductions)
    assert CodecSupport.encode_from_ucs4_discard(:shift_jisx0213, unmapped, :big) == {:ok, ""}
    {:reductions, after_reductions} = Process.info(self(), :reductions)

    assert after_reductions - before_reductions < 300_000
  end

  defp result(
         codec,
         iconvex_forward_us,
         gnu_forward_engine_us,
         iconvex_reverse_us,
         gnu_reverse_engine_us
       ) do
    %{
      codec: codec,
      status: "PASS",
      encoded_bytes: 1,
      encoded_sha256: "encoded",
      roundtrip_codepoints: 1,
      roundtrip_sha256: "roundtrip",
      iconvex_forward_us: iconvex_forward_us,
      gnu_forward_engine_us: gnu_forward_engine_us,
      iconvex_reverse_us: iconvex_reverse_us,
      gnu_reverse_engine_us: gnu_reverse_engine_us,
      mismatch: nil
    }
  end

  defp benchmark_metadata do
    %{
      header_path: "/gnu/include/iconv.h",
      header_sha256: "header-digest",
      helper: "/helper/gnu_iconv_engine_benchmark",
      helper_source_path: "/source/gnu_iconv_engine_benchmark.c",
      helper_source_sha256: "helper-source-digest",
      helper_executable_sha256: "helper-executable-digest",
      library_path: "/gnu/lib/libiconv.a",
      library_sha256: "library-digest",
      prefix: "/gnu"
    }
  end

  defp execution_metadata do
    %{
      elixir_version: "fixture-elixir",
      otp_release: "fixture-otp",
      erts_version: "fixture-erts",
      os_family: "fixture-family",
      os_name: "fixture-name",
      os_version: "98.76.54-fixture",
      system_architecture: "fixture-architecture",
      schedulers_online: 17,
      word_size_bytes: 8,
      timing_samples: 3,
      minimum_sample_ns: 1_000_000,
      maximum_batch_iterations: 1_048_576
    }
  end

  defp forward_traces(parent) do
    receive do
      :stop ->
        :ok

      message ->
        send(parent, {:trace_event, message})
        forward_traces(parent)
    end
  end
end
