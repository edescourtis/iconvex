variants = [
  {1, Iconvex.Specs.ICULMBCS1},
  {2, Iconvex.Specs.ICULMBCS2},
  {3, Iconvex.Specs.ICULMBCS3},
  {4, Iconvex.Specs.ICULMBCS4},
  {5, Iconvex.Specs.ICULMBCS5},
  {6, Iconvex.Specs.ICULMBCS6},
  {8, Iconvex.Specs.ICULMBCS8},
  {11, Iconvex.Specs.ICULMBCS11},
  {16, Iconvex.Specs.ICULMBCS16},
  {17, Iconvex.Specs.ICULMBCS17},
  {18, Iconvex.Specs.ICULMBCS18},
  {19, Iconvex.Specs.ICULMBCS19}
]

benchmark_trials = 3

prefix =
  [
    System.get_env("ICONVEX_ICU_PREFIX"),
    "/opt/homebrew/Cellar/icu4c@78/78.3",
    "/opt/homebrew/opt/icu4c@78"
  ]
  |> Enum.reject(&is_nil/1)
  |> Enum.find(fn path ->
    uconv = Path.join([path, "bin", "uconv"])

    File.regular?(uconv) and
      case System.cmd(uconv, ["--version"]) do
        {version, 0} -> version =~ "ICU 78.3"
        _other -> false
      end
  end) || raise "an ICU 78.3 development prefix is required"

cc = System.find_executable("cc") || raise "a C compiler is required"
source = Path.join(__DIR__, "icu_lmbcs_oracle.c")

temporary =
  Path.join(System.tmp_dir!(), "iconvex-lmbcs-bench-#{System.unique_integer([:positive])}")

File.mkdir_p!(temporary)
oracle = Path.join(temporary, "icu_lmbcs_oracle")

{_output, 0} =
  System.cmd(cc, [
    "-O3",
    "-std=c11",
    "-Wall",
    "-Wextra",
    "-I#{Path.join(prefix, "include")}",
    "-L#{Path.join(prefix, "lib")}",
    "-Wl,-rpath,#{Path.join(prefix, "lib")}",
    source,
    "-licuuc",
    "-licudata",
    "-o",
    oracle
  ])

median_native_ns = fn function, iterations ->
  for _ <- 1..10, do: function.()

  for _ <- 1..5 do
    :erlang.garbage_collect()
    started = System.monotonic_time()
    for _ <- 1..iterations, do: function.()
    elapsed = System.monotonic_time() - started
    System.convert_time_unit(elapsed, :native, :nanosecond) / iterations
  end
  |> Enum.sort()
  |> Enum.at(2)
end

oracle_ns = fn operation, encoding, input_path, iterations ->
  {output, 0} =
    System.cmd(oracle, [
      operation,
      encoding,
      input_path,
      Integer.to_string(iterations)
    ])

  [nanoseconds, output_length, _checksum] = String.split(output)
  {String.to_float(nanoseconds), String.to_integer(output_length)}
end

text = String.duplicate("Hello-é-Ω-Ж-א-ش-ก-日本語-한국어-中文-😀-", 64)
codepoints = String.to_charlist(text)
utf8_path = Path.join(temporary, "workload.utf8")
File.write!(utf8_path, text)
utf16_units = byte_size(:unicode.characters_to_binary(text, :utf8, {:utf16, :big})) |> div(2)
uconv = Path.join([prefix, "bin", "uconv"])

try do
  rows =
    Enum.flat_map(variants, fn {group, module} ->
      {:ok, encoded} = module.encode(codepoints)
      {:ok, ^codepoints} = module.decode(encoded)
      encoded_path = Path.join(temporary, "lmbcs-#{group}.bin")
      File.write!(encoded_path, encoded)

      {oracle_encoded, 0} =
        System.cmd(uconv, [
          "--block-size",
          "1000000",
          "-f",
          "UTF-8",
          "-t",
          "LMBCS-#{group}",
          utf8_path
        ])

      true = encoded == oracle_encoded

      measurements =
        for _trial <- 1..benchmark_trials do
          native_encode_ns = median_native_ns.(fn -> module.encode(codepoints) end, 12)
          native_decode_ns = median_native_ns.(fn -> module.decode(encoded) end, 12)

          {icu_encode_ns, encoded_size} =
            oracle_ns.("encode", "LMBCS-#{group}", utf8_path, 300)

          {icu_decode_ns, decoded_units} =
            oracle_ns.("decode", "LMBCS-#{group}", encoded_path, 300)

          true = encoded_size == byte_size(encoded)
          true = decoded_units == utf16_units

          %{
            encode: {native_encode_ns, icu_encode_ns},
            decode: {native_decode_ns, icu_decode_ns}
          }
        end

      select_median_ratio = fn operation ->
        measurements
        |> Enum.map(&Map.fetch!(&1, operation))
        |> Enum.sort_by(fn {native_ns, icu_ns} -> native_ns / icu_ns end)
        |> Enum.at(div(benchmark_trials, 2))
      end

      {native_encode_ns, icu_encode_ns} = select_median_ratio.(:encode)
      {native_decode_ns, icu_decode_ns} = select_median_ratio.(:decode)

      [
        {group, "encode", length(codepoints), byte_size(encoded), native_encode_ns,
         icu_encode_ns},
        {group, "decode", length(codepoints), byte_size(encoded), native_decode_ns, icu_decode_ns}
      ]
    end)

  IO.puts("group\toperation\tscalars\tbytes\tnative us/op\tICU us/op\tratio")

  Enum.each(rows, fn {group, operation, scalars, bytes, native_ns, icu_ns} ->
    ratio = native_ns / icu_ns

    IO.puts(
      "LMBCS-#{group}\t#{operation}\t#{scalars}\t#{bytes}\t" <>
        "#{Float.round(native_ns / 1_000, 3)}\t#{Float.round(icu_ns / 1_000, 3)}\t" <>
        "#{Float.round(ratio, 2)}x"
    )

    if ratio > 30.0,
      do: raise("LMBCS-#{group} #{operation} exceeds the 30x ceiling: #{ratio}x")
  end)

  small = String.to_charlist(String.duplicate("A-é-Ω-日本語-😀-", 32))
  large = small ++ small
  {:ok, small_encoded} = Iconvex.Specs.ICULMBCS16.encode(small)
  {:ok, large_encoded} = Iconvex.Specs.ICULMBCS16.encode(large)

  linearity = [
    {"encode", median_native_ns.(fn -> Iconvex.Specs.ICULMBCS16.encode(small) end, 30),
     median_native_ns.(fn -> Iconvex.Specs.ICULMBCS16.encode(large) end, 30)},
    {"decode", median_native_ns.(fn -> Iconvex.Specs.ICULMBCS16.decode(small_encoded) end, 30),
     median_native_ns.(fn -> Iconvex.Specs.ICULMBCS16.decode(large_encoded) end, 30)}
  ]

  Enum.each(linearity, fn {operation, small_ns, large_ns} ->
    growth = large_ns / small_ns
    IO.puts("LMBCS-16 #{operation} 2x input growth: #{Float.round(growth, 2)}x")
    if growth > 3.0, do: raise("LMBCS #{operation} failed linear scaling: #{growth}x")
  end)
after
  File.rm_rf(temporary)
end
