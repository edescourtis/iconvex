defmodule Iconvex.ExhaustiveUnicodeDifferential do
  @codepoint_count 1_114_112
  @scalar_count 1_112_064
  @surrogate_count 2_048
  @corpus_name "all-unicode-codepoints.ucs4be"
  @source_encoding "UCS-4BE"
  @default_max_slowdown 30.0
  @timing_samples 3
  @minimum_sample_ns 1_000_000
  @maximum_batch_iterations 1_048_576

  def run(argv) do
    options = parse_args(argv)
    root = Path.expand("..", __DIR__)
    corpus_path = options[:corpus] || Path.join(root, "test/fixtures/#{@corpus_name}")
    report_path = options[:report] || Path.join(root, "EXHAUSTIVE_UNICODE_DIFFERENTIAL.md")
    iconv = options[:iconv] || System.get_env("GNU_ICONV") || find_iconv!()
    max_slowdown = options[:max_slowdown] || @default_max_slowdown
    execution_metadata = execution_metadata()

    generate_corpus!(corpus_path)
    corpus = File.read!(corpus_path)
    verify_corpus!(corpus)
    verify_reference!(iconv)
    benchmark = prepare_gnu_benchmark!(iconv)

    codecs =
      case options[:only] do
        nil -> Iconvex.encodings()
        names -> Enum.map(names, &canonical!/1)
      end

    IO.puts("Unicode code points: #{format_integer(@codepoint_count)}")
    IO.puts("Unicode scalars: #{format_integer(@scalar_count)}")
    IO.puts("Non-scalar surrogate code points: #{format_integer(@surrogate_count)}")
    IO.puts("Corpus: #{corpus_path} (#{byte_size(corpus)} bytes, #{sha256(corpus)})")
    IO.puts("GNU reference: #{iconv}")
    IO.puts("GNU engine helper: #{benchmark.helper}")
    IO.puts("GNU benchmark library: #{benchmark.library_path}")
    IO.puts("Codecs: #{length(codecs)}")

    started = System.monotonic_time(:millisecond)

    results =
      codecs
      |> Enum.with_index(1)
      |> Enum.map(fn {codec, index} ->
        result = compare_codec(codec, corpus, corpus_path, iconv, benchmark)

        IO.puts(
          "[#{index}/#{length(codecs)}] #{codec}: #{result.status} " <>
            "(forward #{result.iconvex_forward_us}/#{result.gnu_forward_engine_us} µs, " <>
            "reverse #{result.iconvex_reverse_us}/#{result.gnu_reverse_engine_us} µs " <>
            "Iconvex/GNU-engine)"
        )

        result
      end)

    elapsed = System.monotonic_time(:millisecond) - started

    write_report!(
      report_path,
      root,
      corpus,
      iconv,
      results,
      elapsed,
      max_slowdown,
      benchmark,
      execution_metadata
    )

    failures = Enum.reject(results, &(&1.status == "PASS"))
    performance_failures = performance_breaches(results, max_slowdown)

    if failures == [] and performance_failures == [] do
      IO.puts(
        "PASS: #{length(results)}/#{length(results)} codecs, 0 mismatches, " <>
          "all <= #{format_slowdown(max_slowdown)} GNU"
      )

      IO.puts("Report: #{report_path}")
    else
      IO.puts(
        :stderr,
        "FAIL: #{length(failures)} codec mismatch(es), " <>
          "#{length(performance_failures)} slowdown breach(es); report: #{report_path}"
      )

      System.halt(1)
    end
  end

  @doc false
  def compare_codec(codec, corpus, corpus_path, iconv, benchmark) do
    {ours_forward, ours_forward_us} =
      warm_and_timed_us(fn ->
        Iconvex.convert!(corpus, @source_encoding, codec, unrepresentable: :discard)
      end)

    # GNU CLI output is the byte-correctness oracle. Its process, input, and
    # stdout costs are deliberately absent from the engine-only timing below.
    gnu_forward = gnu_convert_file!(iconv, corpus_path, @source_encoding, codec, true)

    gnu_forward_measurement =
      gnu_engine_measure!(benchmark.helper, corpus_path, @source_encoding, codec)

    unless gnu_forward_measurement.output_bytes == byte_size(gnu_forward) do
      raise "GNU helper/CLI output-size mismatch: #{@source_encoding} -> #{codec}: " <>
              "#{gnu_forward_measurement.output_bytes}/#{byte_size(gnu_forward)}"
    end

    {ours_back_from_ours, ours_back_us} =
      warm_and_timed_us(fn ->
        Iconvex.convert!(ours_forward, codec, @source_encoding, invalid: :discard)
      end)

    {gnu_back_from_gnu, gnu_reverse_engine_us} =
      with_temp_input(gnu_forward, fn path ->
        correctness = gnu_convert_file!(iconv, path, codec, @source_encoding, true)
        measurement = gnu_engine_measure!(benchmark.helper, path, codec, @source_encoding)

        unless measurement.output_bytes == byte_size(correctness) do
          raise "GNU helper/CLI output-size mismatch: #{codec} -> #{@source_encoding}: " <>
                  "#{measurement.output_bytes}/#{byte_size(correctness)}"
        end

        {correctness, measurement.engine_us}
      end)

    # Cross-decodes prevent matching encoder bugs from hiding decoder differences.
    ours_back_from_gnu =
      Iconvex.convert!(gnu_forward, codec, @source_encoding, invalid: :discard)

    gnu_back_from_ours = gnu_convert!(iconv, ours_forward, codec, @source_encoding, true)

    comparisons = [
      {"forward", ours_forward, gnu_forward},
      {"own round-trip", ours_back_from_ours, gnu_back_from_gnu},
      {"Iconvex decode of GNU bytes", ours_back_from_gnu, gnu_back_from_gnu},
      {"GNU decode of Iconvex bytes", gnu_back_from_ours, ours_back_from_ours}
    ]

    mismatch =
      Enum.find_value(comparisons, fn {stage, ours, gnu} ->
        if ours == gnu, do: nil, else: mismatch(stage, ours, gnu)
      end)

    %{
      codec: codec,
      status: if(mismatch, do: "FAIL", else: "PASS"),
      encoded_bytes: byte_size(ours_forward),
      encoded_sha256: sha256(ours_forward),
      roundtrip_codepoints: div(byte_size(ours_back_from_ours), 4),
      roundtrip_sha256: sha256(ours_back_from_ours),
      iconvex_forward_us: ours_forward_us,
      gnu_forward_engine_us: gnu_forward_measurement.engine_us,
      iconvex_reverse_us: ours_back_us,
      gnu_reverse_engine_us: gnu_reverse_engine_us,
      mismatch: mismatch
    }
  rescue
    exception ->
      %{
        codec: codec,
        status: "FAIL",
        encoded_bytes: 0,
        encoded_sha256: "-",
        roundtrip_codepoints: 0,
        roundtrip_sha256: "-",
        iconvex_forward_us: 0,
        gnu_forward_engine_us: 0,
        iconvex_reverse_us: 0,
        gnu_reverse_engine_us: 0,
        mismatch: Exception.format(:error, exception, __STACKTRACE__) |> one_line()
      }
  end

  defp generate_corpus!(path) do
    expected_size = @codepoint_count * 4

    if not File.regular?(path) or File.stat!(path).size != expected_size do
      File.mkdir_p!(Path.dirname(path))

      File.open!(path, [:write, :binary], fn file ->
        for plane <- 0..16 do
          first = plane * 0x10000
          last = min(first + 0xFFFF, 0x10FFFF)

          bytes =
            for codepoint <- first..last,
                into: <<>>,
                do: <<codepoint::unsigned-big-32>>

          IO.binwrite(file, bytes)
        end
      end)
    end
  end

  defp verify_corpus!(corpus) do
    unless byte_size(corpus) == @codepoint_count * 4 do
      raise "wrong corpus size: #{byte_size(corpus)}"
    end

    {count, surrogate_count, last} =
      for <<codepoint::unsigned-big-32 <- corpus>>, reduce: {0, 0, -1} do
        {count, surrogate_count, previous} ->
          unless codepoint == previous + 1 and codepoint <= 0x10FFFF do
            raise "invalid or unordered corpus code point: U+#{Integer.to_string(codepoint, 16)}"
          end

          surrogate_count = surrogate_count + if(codepoint in 0xD800..0xDFFF, do: 1, else: 0)
          {count + 1, surrogate_count, codepoint}
      end

    unless count == @codepoint_count and surrogate_count == @surrogate_count and
             last == 0x10FFFF do
      raise "incomplete corpus: #{count} code points, #{surrogate_count} surrogates, " <>
              "last U+#{Integer.to_string(last, 16)}"
    end
  end

  defp verify_reference!(iconv) do
    {version, 0} = System.cmd(iconv, ["--version"])

    unless version =~ "GNU libiconv 1.19" do
      raise "reference must be GNU libiconv 1.19, got: #{one_line(version)}"
    end

    {list, 0} = System.cmd(iconv, ["-l"])
    groups = list |> String.split("\n", trim: true) |> length()

    unless groups >= 198 do
      raise "reference must use --enable-extra-encodings: expected at least 198 groups, got #{groups}"
    end

    missing =
      Enum.reject(Iconvex.encodings(), fn codec ->
        match?({_, 0}, System.cmd(iconv, ["-f", "UTF-8", "-t", codec, "/dev/null"]))
      end)

    unless missing == [], do: raise("GNU reference cannot open: #{Enum.join(missing, ", ")}")
  end

  defp gnu_convert!(iconv, input, from, to, discard?) do
    with_temp_input(input, &gnu_convert_file!(iconv, &1, from, to, discard?))
  end

  defp with_temp_input(input, fun) do
    path =
      Path.join(
        System.tmp_dir!(),
        "iconvex-differential-#{System.unique_integer([:positive, :monotonic])}.bin"
      )

    File.write!(path, input)

    try do
      fun.(path)
    after
      File.rm(path)
    end
  end

  defp gnu_convert_file!(iconv, path, from, to, discard?) do
    target = if discard?, do: to <> "//IGNORE", else: to
    args = ["-f", from, "-t", target]

    case System.cmd(iconv, args ++ [path]) do
      {output, 0} -> output
      {_output, status} -> raise "GNU iconv exited #{status}: #{from} -> #{to}"
    end
  end

  @doc false
  def gnu_engine_time!(helper, input_path, from, to) do
    gnu_engine_measure!(helper, input_path, from, to).engine_us
  end

  @doc false
  def gnu_engine_measure!(helper, input_path, from, to) do
    args = [
      "--samples",
      Integer.to_string(@timing_samples),
      "--from",
      from,
      "--to",
      to <> "//IGNORE",
      "--input",
      input_path
    ]

    case System.cmd(helper, args, stderr_to_stdout: true) do
      {output, 0} ->
        fields =
          output
          |> String.split("\n", trim: true)
          |> Map.new(fn line ->
            case String.split(line, "=", parts: 2) do
              [key, value] -> {key, value}
              _ -> raise "invalid GNU engine helper output: #{one_line(output)}"
            end
          end)

        engine_us = parse_positive_number!(fields, "engine_us", output)
        samples = parse_positive_integer!(fields, "samples", output)
        input_bytes = parse_nonnegative_integer!(fields, "input_bytes", output)
        output_bytes = parse_nonnegative_integer!(fields, "output_bytes", output)

        unless fields["libiconv_version"] in [nil, "1.19"] do
          raise "GNU engine helper is not libiconv 1.19: #{one_line(output)}"
        end

        unless samples == @timing_samples do
          raise "GNU engine helper used #{samples} samples, expected #{@timing_samples}"
        end

        unless input_bytes == File.stat!(input_path).size do
          raise "GNU engine helper read #{input_bytes} bytes, expected #{File.stat!(input_path).size}"
        end

        %{engine_us: engine_us, output_bytes: output_bytes}

      {output, status} ->
        raise "GNU engine helper exited #{status}: #{from} -> #{to}: #{one_line(output)}"
    end
  end

  defp parse_positive_integer!(fields, key, output) do
    case Map.fetch(fields, key) do
      {:ok, value} ->
        case Integer.parse(value) do
          {integer, ""} when integer > 0 -> integer
          _ -> raise "invalid #{key} in GNU engine helper output: #{one_line(output)}"
        end

      :error ->
        raise "missing #{key} in GNU engine helper output: #{one_line(output)}"
    end
  end

  defp parse_positive_number!(fields, key, output) do
    case Map.fetch(fields, key) do
      {:ok, value} ->
        case Float.parse(value) do
          {number, ""} when number > 0 -> number
          _ -> raise "invalid #{key} in GNU engine helper output: #{one_line(output)}"
        end

      :error ->
        raise "missing #{key} in GNU engine helper output: #{one_line(output)}"
    end
  end

  defp parse_nonnegative_integer!(fields, key, output) do
    case Map.fetch(fields, key) do
      {:ok, value} ->
        case Integer.parse(value) do
          {integer, ""} when integer >= 0 -> integer
          _ -> raise "invalid #{key} in GNU engine helper output: #{one_line(output)}"
        end

      :error ->
        raise "missing #{key} in GNU engine helper output: #{one_line(output)}"
    end
  end

  defp mismatch(stage, ours, gnu) do
    offset = first_difference(ours, gnu, 0)

    "#{stage} differs at byte #{offset}; " <>
      "Iconvex=#{hex_window(ours, offset)} GNU=#{hex_window(gnu, offset)}; " <>
      "sizes=#{byte_size(ours)}/#{byte_size(gnu)}"
  end

  defp first_difference(<<a, ours::binary>>, <<b, gnu::binary>>, offset) when a == b,
    do: first_difference(ours, gnu, offset + 1)

  defp first_difference(_ours, _gnu, offset), do: offset

  defp hex_window(binary, offset) do
    size = min(16, max(byte_size(binary) - offset, 0))
    if size == 0, do: "<eof>", else: binary_part(binary, offset, size) |> Base.encode16()
  end

  @doc false
  def write_report!(
        path,
        root,
        corpus,
        iconv,
        results,
        elapsed,
        max_slowdown,
        benchmark,
        execution_metadata
      ) do
    passed = Enum.count(results, &(&1.status == "PASS"))
    mismatches = length(results) - passed
    performance_failures = results |> performance_breaches(max_slowdown) |> length()
    {version, 0} = System.cmd(iconv, ["--version"])
    version = version |> String.split("\n") |> hd()
    runner_path = Path.join(root, "tools/exhaustive_unicode_differential.exs")
    runner_digest = runner_path |> File.read!() |> sha256()
    runtime_digest = combined_runtime_digest(root)

    rows =
      Enum.map(results, fn result ->
        details = result.mismatch || "-"

        {worst_slowdown, forward_slowdown, reverse_slowdown} =
          if result.status == "PASS" do
            {
              format_slowdown(slowdown(result)),
              format_slowdown(slowdown(result, :forward)),
              format_slowdown(slowdown(result, :reverse))
            }
          else
            {"-", "-", "-"}
          end

        "| `#{result.codec}` | #{result.status} | #{worst_slowdown} | " <>
          "#{forward_slowdown} | " <>
          "#{reverse_slowdown} | " <>
          "#{result.encoded_bytes} | " <>
          "`#{result.encoded_sha256}` | #{result.roundtrip_codepoints} | " <>
          "`#{result.roundtrip_sha256}` | #{result.iconvex_forward_us} | " <>
          "#{result.gnu_forward_engine_us} | #{result.iconvex_reverse_us} | " <>
          "#{result.gnu_reverse_engine_us} | " <>
          "#{String.replace(details, "|", "\\|")} |\n"
      end)

    document = [
      "# Exhaustive Unicode Differential\n\n",
      "Generated by `tools/exhaustive_unicode_differential.exs`. ",
      "Every Unicode code point from U+0000 through U+10FFFF is converted from ",
      "UCS-4BE into every fixed codec, including all 2,048 surrogate code points, ",
      "using Iconvex's discard policies and GNU's `//IGNORE`, converted back, and ",
      "compared byte-for-byte. Cross-decoding ",
      "both encoded streams independently checks decoders too.\n\n",
      "## Execution environment\n\n",
      "- Elixir version: `#{execution_metadata.elixir_version}`\n",
      "- OTP release: `#{execution_metadata.otp_release}`\n",
      "- ERTS version: `#{execution_metadata.erts_version}`\n",
      "- OS family/name: `#{execution_metadata.os_family}/#{execution_metadata.os_name}`\n",
      "- OS version: `#{execution_metadata.os_version}`\n",
      "- System architecture: `#{execution_metadata.system_architecture}`\n",
      "- Schedulers online: **#{execution_metadata.schedulers_online}**\n",
      "- Word size: **#{execution_metadata.word_size_bytes * 8} bits (#{execution_metadata.word_size_bytes} bytes)**\n\n",
      "## Corpus and reference\n\n",
      "- Unicode code points: **#{format_integer(@codepoint_count)}/#{format_integer(@codepoint_count)}**\n",
      "- Unicode scalar values: **#{format_integer(@scalar_count)}**\n",
      "- Non-scalar surrogate code points: **#{format_integer(@surrogate_count)}**\n",
      "- Codecs passed: **#{passed}/#{length(results)}**\n",
      "- Mismatches: **#{mismatches}**\n",
      "- Performance ceiling: **#{format_slowdown(max_slowdown)} GNU**\n",
      "- Performance failures: **#{performance_failures}**\n",
      "- Corpus: `test/fixtures/#{@corpus_name}` (sequential UCS-4BE; surrogate range included as non-scalar code points)\n",
      "- Corpus bytes: **#{byte_size(corpus)}**\n",
      "- Corpus SHA-256: `#{sha256(corpus)}`\n",
      "- Combined runtime artifact SHA-256: `#{runtime_digest}`\n",
      "- Differential runner SHA-256: `#{runner_digest}`\n",
      "- Reference: **#{version}**, built with `--enable-extra-encodings`\n",
      "- GNU CLI executable: `#{Path.expand(iconv)}`\n",
      "- GNU libiconv header: `#{benchmark.header_path}`\n",
      "- GNU libiconv header SHA-256: `#{benchmark.header_sha256}`\n",
      "- Timing unit: **microseconds (µs)**\n",
      "- GNU benchmark prefix: `#{benchmark.prefix}`\n",
      "- GNU timing helper source: `#{benchmark.helper_source_path}`\n",
      "- GNU timing helper source SHA-256: `#{benchmark.helper_source_sha256}`\n",
      "- GNU timing helper executable: `#{benchmark.helper}`\n",
      "- GNU timing helper executable SHA-256: `#{benchmark.helper_executable_sha256}`\n",
      "- GNU libiconv benchmark artifact: `#{benchmark.library_path}`\n",
      "- GNU libiconv benchmark artifact SHA-256: `#{benchmark.library_sha256}`\n",
      "- Timing samples per direction: **#{execution_metadata.timing_samples}**\n",
      "- Minimum calibrated sample duration: **#{format_integer(execution_metadata.minimum_sample_ns)} ns**\n",
      "- Maximum calibrated batch iterations: **#{format_integer(execution_metadata.maximum_batch_iterations)}**\n",
      "- Total measured wall time: **#{elapsed} ms**\n\n",
      "Each directional timing is the fastest of **#{execution_metadata.timing_samples}** isolated samples; ",
      "the full measured wall time includes every sample. The runner performs one untimed ",
      "Iconvex conversion before each directional timing to initialize lazy caches and ",
      "capture the correctness result. Every timed sample output must equal that warm output; ",
      "the warm conversion is excluded from the reported timing. Iconvex receives an ",
      "already-resident BEAM binary and is measured with the BEAM monotonic ",
      "clock. Sub-millisecond conversions are repeated in calibrated batches and ",
      "reported as fractional microseconds per conversion, without a denominator clamp. ",
      "The offline C helper reads each input before opening its ",
      "internal `CLOCK_MONOTONIC` timing window and times only in-memory GNU ",
      "libiconv conversion. GNU benchmark timings exclude process startup, file I/O, and stdout. ",
      "GNU CLI output remains the byte-correctness oracle; helper output is never ",
      "used as correctness data.\n\n",
      "Forward and own-stream reverse ratios are timed, reported, and gated ",
      "independently; worst slowdown is the greater directional ratio. Hashes are ",
      "shared only after byte equality succeeds.\n\n",
      "| Codec | Result | Worst slowdown | Forward slowdown | Reverse slowdown | Encoded bytes | Encoded SHA-256 | Round-trip code points | Round-trip SHA-256 | Iconvex forward µs | GNU engine forward µs | Iconvex reverse µs | GNU engine reverse µs | Difference |\n",
      "|---|---:|---:|---:|---:|---:|---|---:|---|---:|---:|---:|---:|---|\n",
      rows
    ]

    File.write!(path, document)
  end

  defp parse_args(argv), do: parse_args(argv, [])
  defp parse_args([], options), do: options
  defp parse_args(["--" | rest], options), do: parse_args(rest, options)

  defp parse_args(["--iconv", path | rest], options),
    do: parse_args(rest, Keyword.put(options, :iconv, Path.expand(path)))

  defp parse_args(["--corpus", path | rest], options),
    do: parse_args(rest, Keyword.put(options, :corpus, Path.expand(path)))

  defp parse_args(["--report", path | rest], options),
    do: parse_args(rest, Keyword.put(options, :report, Path.expand(path)))

  defp parse_args(["--max-slowdown", value | rest], options) do
    case Float.parse(value) do
      {number, ""} when number > 0 ->
        parse_args(rest, Keyword.put(options, :max_slowdown, number))

      _ ->
        raise "--max-slowdown must be a positive number"
    end
  end

  defp parse_args(["--only", codec | rest], options),
    do: parse_args(rest, Keyword.update(options, :only, [codec], &[codec | &1]))

  defp parse_args([unknown | _rest], _options), do: raise("unknown argument: #{unknown}")

  defp canonical!(name) do
    case Iconvex.canonical_name(name) do
      {:ok, canonical} -> canonical
      :error -> raise "unknown Iconvex codec: #{name}"
    end
  end

  @doc false
  def prepare_gnu_benchmark!(iconv) do
    prefix = iconv |> Path.expand() |> Path.dirname() |> Path.dirname()
    source = Path.join(__DIR__, "gnu_iconv_engine_benchmark.c")
    include_dir = Path.join(prefix, "include")
    header = Path.join(include_dir, "iconv.h")
    library = find_gnu_library!(prefix)
    library_dir = Path.dirname(library)

    unless File.regular?(source), do: raise("missing GNU engine benchmark helper: #{source}")
    unless File.regular?(header), do: raise("missing GNU libiconv header: #{header}")

    source_bytes = File.read!(source)
    header_bytes = File.read!(header)
    library_bytes = File.read!(library)
    source_sha256 = sha256(source_bytes)
    header_sha256 = sha256(header_bytes)
    library_sha256 = sha256(library_bytes)
    build_id = sha256([source_bytes, <<0>>, library_bytes]) |> binary_part(0, 20)
    build_dir = Path.join(System.tmp_dir!(), "iconvex-gnu-engine-#{build_id}")
    helper = Path.join(build_dir, "gnu_iconv_engine_benchmark")
    temporary = helper <> ".#{System.unique_integer([:positive, :monotonic])}.tmp"

    compiler =
      System.get_env("CC") || System.find_executable("cc") || raise("C compiler not found")

    File.mkdir_p!(build_dir)

    args = [
      "-std=c11",
      "-O3",
      "-Wall",
      "-Wextra",
      "-Werror",
      "-I",
      include_dir,
      source,
      library,
      "-Wl,-rpath,#{library_dir}",
      "-o",
      temporary
    ]

    case System.cmd(compiler, args, stderr_to_stdout: true) do
      {_, 0} ->
        File.rename!(temporary, helper)
        File.chmod!(helper, 0o755)

      {output, status} ->
        File.rm(temporary)
        raise "GNU engine benchmark helper compile exited #{status}: #{one_line(output)}"
    end

    %{
      header_path: header,
      header_sha256: header_sha256,
      helper: helper,
      helper_source_path: source,
      helper_source_sha256: source_sha256,
      helper_executable_sha256: helper |> File.read!() |> sha256(),
      library_path: library,
      library_sha256: library_sha256,
      prefix: prefix
    }
  end

  defp find_gnu_library!(prefix) do
    library_dir = Path.join(prefix, "lib")

    candidates =
      [
        Path.join(library_dir, "libiconv.dylib"),
        Path.join(library_dir, "libiconv.so")
      ] ++
        Path.wildcard(Path.join(library_dir, "libiconv.so.*")) ++
        [Path.join(library_dir, "libiconv.a")]

    Enum.find(candidates, &File.regular?/1) ||
      raise "GNU libiconv benchmark library not found below #{library_dir}"
  end

  defp find_iconv! do
    candidates = [
      "/opt/homebrew/opt/libiconv/bin/iconv",
      "/tmp/libiconv-1.19-extra-install/bin/iconv",
      "/tmp/libiconv-1.19-install/bin/iconv"
    ]

    Enum.find(candidates, &File.regular?/1) ||
      raise "GNU_ICONV or --iconv must point to GNU libiconv 1.19"
  end

  defp combined_runtime_digest(extras_root) do
    core_root = Mix.Project.deps_paths() |> Map.fetch!(:iconvex) |> Path.expand()

    [{"iconvex", core_root}, {"iconvex_extras", extras_root}]
    |> Enum.flat_map(fn {label, root} ->
      ["lib/**/*.ex", "priv/**/*.etf", "mix.exs"]
      |> Enum.flat_map(&Path.wildcard(Path.join(root, &1)))
      |> Enum.filter(&File.regular?/1)
      |> Enum.map(fn path -> {Path.join(label, Path.relative_to(path, root)), path} end)
    end)
    |> Enum.sort_by(&elem(&1, 0))
    |> Enum.map(fn {relative, path} ->
      [relative, <<0>>, path |> File.read!() |> sha256(), "\n"]
    end)
    |> sha256()
  end

  @doc false
  def timing_sample_count, do: @timing_samples

  @doc false
  def execution_metadata do
    {os_family, os_name} = :os.type()

    %{
      elixir_version: System.version(),
      otp_release: System.otp_release(),
      erts_version: :erlang.system_info(:version) |> List.to_string(),
      os_family: Atom.to_string(os_family),
      os_name: Atom.to_string(os_name),
      os_version: format_os_version(:os.version()),
      system_architecture: :erlang.system_info(:system_architecture) |> List.to_string(),
      schedulers_online: :erlang.system_info(:schedulers_online),
      word_size_bytes: :erlang.system_info(:wordsize),
      timing_samples: @timing_samples,
      minimum_sample_ns: @minimum_sample_ns,
      maximum_batch_iterations: @maximum_batch_iterations
    }
  end

  @doc false
  def warm_and_timed_us(fun) when is_function(fun, 0) do
    warm_output = fun.()
    timed_us(fun, warm_output)
  end

  defp timed_us(fun, warm_output) do
    Enum.reduce(1..@timing_samples, nil, fn _sample, best ->
      :erlang.garbage_collect()
      {value, elapsed_us} = timed_batch_us(fun, 1)
      validate_timed_output!(value, warm_output)

      case best do
        nil -> {value, elapsed_us}
        {_best_value, best_elapsed} when elapsed_us < best_elapsed -> {value, elapsed_us}
        best -> best
      end
    end)
  end

  defp validate_timed_output!(timed_output, warm_output) do
    unless timed_output === warm_output do
      raise "timed Iconvex output differs from untimed warm output"
    end

    :ok
  end

  defp timed_batch_us(fun, iterations) do
    started = System.monotonic_time()
    value = run_iterations(fun, iterations)
    elapsed_native = System.monotonic_time() - started
    elapsed_ns = System.convert_time_unit(elapsed_native, :native, :nanosecond)

    if elapsed_ns >= @minimum_sample_ns or iterations >= @maximum_batch_iterations do
      {value, elapsed_ns / iterations / 1_000}
    else
      timed_batch_us(fun, iterations * 2)
    end
  end

  defp run_iterations(fun, 1), do: fun.()

  defp run_iterations(fun, iterations) do
    Enum.reduce(1..iterations, nil, fn _iteration, _value -> fun.() end)
  end

  @doc false
  def performance_breaches(results, max_slowdown) do
    for result <- results,
        result.status == "PASS",
        direction <- [:forward, :reverse],
        ratio = slowdown(result, direction),
        ratio > max_slowdown do
      %{codec: result.codec, direction: direction, slowdown: ratio}
    end
  end

  defp slowdown(result),
    do: max(slowdown(result, :forward), slowdown(result, :reverse))

  defp slowdown(
         %{iconvex_forward_us: iconvex_us, gnu_forward_engine_us: gnu_engine_us},
         :forward
       ),
       do: iconvex_us / gnu_engine_us

  defp slowdown(
         %{iconvex_reverse_us: iconvex_us, gnu_reverse_engine_us: gnu_engine_us},
         :reverse
       ),
       do: iconvex_us / gnu_engine_us

  defp format_slowdown(value), do: :erlang.float_to_binary(value / 1, decimals: 2) <> "x"

  defp sha256(binary),
    do: binary |> then(&:crypto.hash(:sha256, &1)) |> Base.encode16(case: :lower)

  defp format_integer(integer) do
    integer
    |> Integer.to_string()
    |> String.reverse()
    |> String.graphemes()
    |> Enum.chunk_every(3)
    |> Enum.map_join(",", &Enum.join/1)
    |> String.reverse()
  end

  defp format_os_version({major, minor, release}),
    do: Enum.join([major, minor, release], ".")

  defp format_os_version(version) when is_list(version), do: List.to_string(version)
  defp format_os_version(version), do: to_string(version)

  defp one_line(text), do: String.replace(text, ~r/\s+/, " ") |> String.trim()
end

Iconvex.ExhaustiveUnicodeDifferential.run(System.argv())
