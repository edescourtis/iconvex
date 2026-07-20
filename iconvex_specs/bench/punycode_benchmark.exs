alias Iconvex.Specs.Punycode

oracle =
  Path.expand("../priv/sources/rfc3492/cpython-3.14.6-punycode.py", __DIR__)

python = System.find_executable("python3") || raise "python3 executable required"
samples = 7

workloads = [
  {"mixed", String.to_charlist(String.duplicate("Hello-Καλημέρα-日本語-हिन्दी-😀-", 12)), 300},
  {"unique", Enum.to_list(0x1000..0x10BF), 300}
]

median_native_ns = fn function, iterations ->
  for _ <- 1..25, do: function.()

  for _ <- 1..samples do
    :erlang.garbage_collect()
    started = System.monotonic_time()
    for _ <- 1..iterations, do: function.()
    elapsed = System.monotonic_time() - started
    System.convert_time_unit(elapsed, :native, :nanosecond) / iterations
  end
  |> Enum.sort()
  |> Enum.at(div(samples, 2))
end

python_script = """
import importlib.util, statistics, sys, time

sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('pinned_punycode', sys.argv[1])
punycode = importlib.util.module_from_spec(spec)
spec.loader.exec_module(punycode)
text = ''.join(chr(int(value, 16)) for value in sys.argv[2].split(','))
encoded = bytes.fromhex(sys.argv[3])
iterations = int(sys.argv[4])
samples = int(sys.argv[5])

def median_ns(function):
    for _ in range(25):
        function()
    timings = []
    for _ in range(samples):
        started = time.perf_counter_ns()
        for _ in range(iterations):
            function()
        timings.append((time.perf_counter_ns() - started) / iterations)
    return statistics.median(timings)

expected = punycode.punycode_encode(text)
print(expected.hex())
print(f'{median_ns(lambda: punycode.punycode_encode(text)):.3f}')
print(f'{median_ns(lambda: punycode.punycode_decode(encoded, "strict")):.3f}')
"""

rows =
  Enum.flat_map(workloads, fn {name, codepoints, iterations} ->
    {:ok, encoded} = Punycode.encode(codepoints)
    {:ok, ^codepoints} = Punycode.decode(encoded)

    points = Enum.map_join(codepoints, ",", &Integer.to_string(&1, 16))

    {python_output, 0} =
      System.cmd(python, [
        "-c",
        python_script,
        oracle,
        points,
        Base.encode16(encoded, case: :lower),
        Integer.to_string(iterations),
        Integer.to_string(samples)
      ])

    [oracle_hex, python_encode_text, python_decode_text] =
      String.split(python_output, "\n", trim: true)

    true = oracle_hex == Base.encode16(encoded, case: :lower)
    python_encode_ns = String.to_float(python_encode_text)
    python_decode_ns = String.to_float(python_decode_text)
    native_encode_ns = median_native_ns.(fn -> Punycode.encode(codepoints) end, iterations)
    native_decode_ns = median_native_ns.(fn -> Punycode.decode(encoded) end, iterations)

    [
      {name, "encode", length(codepoints), byte_size(encoded), native_encode_ns,
       python_encode_ns},
      {name, "decode", length(codepoints), byte_size(encoded), native_decode_ns, python_decode_ns}
    ]
  end)

IO.puts("workload\toperation\tscalars\tbytes\tnative us/op\tCPython us/op\tratio")

Enum.each(rows, fn {name, operation, scalars, bytes, native_ns, python_ns} ->
  ratio = native_ns / python_ns

  IO.puts(
    "#{name}\t#{operation}\t#{scalars}\t#{bytes}\t" <>
      "#{Float.round(native_ns / 1_000, 3)}\t#{Float.round(python_ns / 1_000, 3)}\t" <>
      "#{Float.round(ratio, 2)}x"
  )

  if ratio > 30.0 do
    raise "#{name} #{operation} exceeds the 30x performance ceiling: #{ratio}x"
  end
end)

alternating_scalars = fn count ->
  low = 0x1000
  high = low + count - 1

  0..(count - 1)
  |> Enum.map(fn index ->
    if rem(index, 2) == 0,
      do: low + div(index, 2),
      else: high - div(index, 2)
  end)
end

reductions = fn function, expected ->
  {:reductions, before_count} = Process.info(self(), :reductions)
  ^expected = function.()
  {:reductions, after_count} = Process.info(self(), :reductions)
  after_count - before_count
end

IO.puts("\nalgorithmic scaling (1,000 -> 2,000 scalars)")
IO.puts("workload\toperation\treduction ratio\ttime ratio")

for {name, small, large} <- [
      {"ordered", Enum.to_list(0x1000..0x13E7), Enum.to_list(0x1000..0x17CF)},
      {"alternating", alternating_scalars.(1_000), alternating_scalars.(2_000)}
    ] do
  {:ok, small_encoded} = Punycode.encode(small)
  {:ok, large_encoded} = Punycode.encode(large)

  paths = [
    {"encode", fn -> Punycode.encode(small) end, {:ok, small_encoded},
     fn -> Punycode.encode(large) end, {:ok, large_encoded}},
    {"decode", fn -> Punycode.decode(small_encoded) end, {:ok, small},
     fn -> Punycode.decode(large_encoded) end, {:ok, large}}
  ]

  for {operation, small_fun, small_result, large_fun, large_result} <- paths do
    # Warm before counting scheduler reductions so the hard gate measures the
    # algorithm, not module loading or one-time table construction.
    ^small_result = small_fun.()
    ^large_result = large_fun.()

    small_reductions = reductions.(small_fun, small_result)
    large_reductions = reductions.(large_fun, large_result)
    reduction_ratio = large_reductions / small_reductions
    small_ns = median_native_ns.(small_fun, 10)
    large_ns = median_native_ns.(large_fun, 10)
    time_ratio = large_ns / small_ns

    IO.puts(
      "#{name}\t#{operation}\t#{Float.round(reduction_ratio, 3)}x\t" <>
        "#{Float.round(time_ratio, 3)}x"
    )

    if reduction_ratio >= 3.0 do
      raise "#{name} #{operation} failed the sub-quadratic reduction gate: " <>
              "#{reduction_ratio}x"
    end
  end
end
