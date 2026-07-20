defmodule Iconvex.ExhaustiveUnicodeDifferential do
  @codepoint_count 1_114_112
  @scalar_count 1_112_064
  @surrogate_count 2_048
  @corpus_name "all-unicode-codepoints.ucs4be"
  @source_encoding "UCS-4BE"

  def run(argv) do
    options = parse_args(argv)
    root = Path.expand("..", __DIR__)
    corpus_path = options[:corpus] || Path.join(root, "test/fixtures/#{@corpus_name}")
    report_path = options[:report] || Path.join(root, "EXHAUSTIVE_UNICODE_DIFFERENTIAL.md")
    iconv = options[:iconv] || System.get_env("GNU_ICONV") || find_iconv!()

    generate_corpus!(corpus_path)
    corpus = File.read!(corpus_path)
    verify_corpus!(corpus)
    verify_reference!(iconv)

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
    IO.puts("Codecs: #{length(codecs)}")

    started = System.monotonic_time(:millisecond)

    results =
      codecs
      |> Enum.with_index(1)
      |> Enum.map(fn {codec, index} ->
        result = compare_codec(codec, corpus, corpus_path, iconv)

        IO.puts(
          "[#{index}/#{length(codecs)}] #{codec}: #{result.status} " <>
            "(#{result.iconvex_ms} ms Iconvex, #{result.gnu_ms} ms GNU)"
        )

        result
      end)

    elapsed = System.monotonic_time(:millisecond) - started
    write_report!(report_path, root, corpus, iconv, results, elapsed)

    failures = Enum.reject(results, &(&1.status == "PASS"))

    if failures == [] do
      IO.puts("PASS: #{length(results)}/#{length(results)} codecs, 0 mismatches")
      IO.puts("Report: #{report_path}")
    else
      IO.puts(:stderr, "FAIL: #{length(failures)} codec mismatch(es); report: #{report_path}")
      System.halt(1)
    end
  end

  defp compare_codec(codec, corpus, corpus_path, iconv) do
    {ours_forward, ours_forward_ms} =
      timed(fn ->
        Iconvex.convert!(corpus, @source_encoding, codec, unrepresentable: :discard)
      end)

    {gnu_forward, gnu_forward_ms} =
      timed(fn -> gnu_convert_file!(iconv, corpus_path, @source_encoding, codec, true) end)

    {ours_back_from_ours, ours_back_ms} =
      timed(fn -> Iconvex.convert!(ours_forward, codec, @source_encoding, invalid: :discard) end)

    {gnu_back_from_gnu, gnu_back_ms} =
      timed(fn -> gnu_convert!(iconv, gnu_forward, codec, @source_encoding, true) end)

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
      iconvex_ms: ours_forward_ms + ours_back_ms,
      gnu_ms: gnu_forward_ms + gnu_back_ms,
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
        iconvex_ms: 0,
        gnu_ms: 0,
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
    path =
      Path.join(
        System.tmp_dir!(),
        "iconvex-differential-#{System.unique_integer([:positive, :monotonic])}.bin"
      )

    File.write!(path, input)

    try do
      gnu_convert_file!(iconv, path, from, to, discard?)
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

  defp write_report!(path, root, corpus, iconv, results, elapsed) do
    passed = Enum.count(results, &(&1.status == "PASS"))
    mismatches = length(results) - passed
    {version, 0} = System.cmd(iconv, ["--version"])
    version = version |> String.split("\n") |> hd()
    runner_path = Path.join(root, "tools/exhaustive_unicode_differential.exs")
    runner_digest = runner_path |> File.read!() |> sha256()
    runtime_digest = runtime_digest(root)

    rows =
      Enum.map(results, fn result ->
        details = result.mismatch || "-"

        "| `#{result.codec}` | #{result.status} | #{result.encoded_bytes} | " <>
          "`#{result.encoded_sha256}` | #{result.roundtrip_codepoints} | " <>
          "`#{result.roundtrip_sha256}` | #{result.iconvex_ms} | #{result.gnu_ms} | " <>
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
      "- Unicode code points: **#{format_integer(@codepoint_count)}/#{format_integer(@codepoint_count)}**\n",
      "- Unicode scalar values: **#{format_integer(@scalar_count)}**\n",
      "- Non-scalar surrogate code points: **#{format_integer(@surrogate_count)}**\n",
      "- Codecs passed: **#{passed}/#{length(results)}**\n",
      "- Mismatches: **#{mismatches}**\n",
      "- Corpus: `test/fixtures/#{@corpus_name}` (sequential UCS-4BE; surrogate range included as non-scalar code points)\n",
      "- Corpus bytes: **#{byte_size(corpus)}**\n",
      "- Corpus SHA-256: `#{sha256(corpus)}`\n",
      "- Runtime artifact SHA-256: `#{runtime_digest}`\n",
      "- Differential runner SHA-256: `#{runner_digest}`\n",
      "- Reference: **#{version}**, built with `--enable-extra-encodings`\n",
      "- Total measured wall time: **#{elapsed} ms**\n\n",
      "Times cover forward conversion plus own-stream reverse conversion. Hashes are ",
      "shared only after byte equality succeeds.\n\n",
      "| Codec | Result | Encoded bytes | Encoded SHA-256 | Round-trip code points | Round-trip SHA-256 | Iconvex ms | GNU ms | Difference |\n",
      "|---|---:|---:|---|---:|---|---:|---:|---|\n",
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

  defp parse_args(["--only", codec | rest], options),
    do: parse_args(rest, Keyword.update(options, :only, [codec], &[codec | &1]))

  defp parse_args([unknown | _rest], _options), do: raise("unknown argument: #{unknown}")

  defp canonical!(name) do
    case Iconvex.canonical_name(name) do
      {:ok, canonical} -> canonical
      :error -> raise "unknown Iconvex codec: #{name}"
    end
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

  defp runtime_digest(root) do
    files =
      ["lib/**/*.ex", "priv/**/*.etf", "mix.exs"]
      |> Enum.flat_map(&Path.wildcard(Path.join(root, &1)))
      |> Enum.filter(&File.regular?/1)
      |> Enum.sort()

    files
    |> Enum.map(fn path ->
      relative = Path.relative_to(path, root)
      [relative, <<0>>, path |> File.read!() |> sha256(), "\n"]
    end)
    |> sha256()
  end

  defp timed(fun) do
    started = System.monotonic_time(:millisecond)
    value = fun.()
    {value, System.monotonic_time(:millisecond) - started}
  end

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

  defp one_line(text), do: String.replace(text, ~r/\s+/, " ") |> String.trim()
end

Iconvex.ExhaustiveUnicodeDifferential.run(System.argv())
