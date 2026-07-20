alias Iconvex.Specs.RFC1345

iterations = 20_000
single_byte = :binary.copy(<<0xC1, 0x81, 0xF0>>, 256)
combining = :binary.copy(<<0xC2, ?e>>, 256)

bench = fn label, fun ->
  for _ <- 1..2_000, do: fun.()
  started = System.monotonic_time()
  for _ <- 1..iterations, do: fun.()
  elapsed = System.monotonic_time() - started
  seconds = System.convert_time_unit(elapsed, :native, :nanosecond) / 1_000_000_000
  IO.puts("#{label}: #{Float.round(iterations / seconds, 1)} ops/s")
end

bench.("EBCDIC-US decode 768 bytes", fn -> RFC1345.decode("EBCDIC-US", single_byte) end)
bench.("T.61 decode 512 bytes", fn -> RFC1345.decode("T.61-8bit", combining) end)
