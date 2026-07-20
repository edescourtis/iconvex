bench = fn label, fun, bytes ->
  for _ <- 1..3, do: fun.()

  best_us =
    for _ <- 1..9 do
      {microseconds, {:ok, _result}} = :timer.tc(fun)
      microseconds
    end
    |> Enum.min()

  mib_per_second = bytes / 1_048_576 / (best_us / 1_000_000)
  IO.puts("#{label}\t#{Float.round(mib_per_second, 2)} MiB/s\t#{best_us} us")
end

units = :binary.copy(<<33, 34, 35, 36, 37, 38, 39, 40>>, 131_072)
{:ok, ecma_codepoints} = Iconvex.Specs.ECMA1.decode(units)
{:ok, dec_codepoints} = Iconvex.Specs.DECSIXBIT.decode(units)

bench.("ECMA-1 decode", fn -> Iconvex.Specs.ECMA1.decode(units) end, byte_size(units))
bench.("ECMA-1 encode", fn -> Iconvex.Specs.ECMA1.encode(ecma_codepoints) end, byte_size(units))

bench.(
  "DEC-SIXBIT decode",
  fn -> Iconvex.Specs.DECSIXBIT.decode(units) end,
  byte_size(units)
)

bench.(
  "DEC-SIXBIT encode",
  fn -> Iconvex.Specs.DECSIXBIT.encode(dec_codepoints) end,
  byte_size(units)
)
