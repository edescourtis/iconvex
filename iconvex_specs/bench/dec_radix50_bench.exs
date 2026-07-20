bench = fn label, fun, packed_bytes ->
  for _ <- 1..3 do
    fun.()
    :erlang.garbage_collect()
  end

  median_us =
    for _ <- 1..9 do
      :erlang.garbage_collect()
      {microseconds, {:ok, _result}} = :timer.tc(fun)
      microseconds
    end
    |> Enum.sort()
    |> Enum.at(4)

  mib_per_second = packed_bytes / 1_048_576 / (median_us / 1_000_000)
  IO.puts("#{label}\t#{Float.round(mib_per_second, 2)} packed MiB/s\t#{median_us} us")
end

words =
  for group <- [~c"ABC", ~c"X2B", ~c"$9.", ~c"XYZ"],
      do: elem(Iconvex.Specs.DECRadix50.pack_codepoints(group), 1)

big = words |> Enum.map(&<<&1::16-big>>) |> IO.iodata_to_binary() |> :binary.copy(131_072)
little = words |> Enum.map(&<<&1::16-little>>) |> IO.iodata_to_binary() |> :binary.copy(131_072)
{:ok, utf8} = Iconvex.convert(big, "DEC-RADIX-50-16BE", "UTF-8")

bench.(
  "DEC-RADIX-50 16BE decode",
  fn -> Iconvex.convert(big, "DEC-RADIX-50-16BE", "UTF-8") end,
  byte_size(big)
)

bench.(
  "DEC-RADIX-50 16BE encode",
  fn -> Iconvex.convert(utf8, "UTF-8", "DEC-RADIX-50-16BE") end,
  byte_size(big)
)

bench.(
  "DEC-RADIX-50 16LE decode",
  fn -> Iconvex.convert(little, "DEC-RADIX-50-16LE", "UTF-8") end,
  byte_size(little)
)

bench.(
  "DEC-RADIX-50 16LE encode",
  fn -> Iconvex.convert(utf8, "UTF-8", "DEC-RADIX-50-16LE") end,
  byte_size(little)
)

{:ok, pdp10_be_word} = Iconvex.convert("SYMBOL", "UTF-8", "DEC-RADIX-50-36BIT-40BE")
{:ok, pdp10_le_word} = Iconvex.convert("SYMBOL", "UTF-8", "DEC-RADIX-50-36BIT-40LE")
pdp10_be = :binary.copy(pdp10_be_word, 200_000)
pdp10_le = :binary.copy(pdp10_le_word, 200_000)
pdp10_utf8 = :binary.copy("SYMBOL", 200_000)

bench.(
  "DEC-RADIX-50 36BIT/40BE decode",
  fn -> Iconvex.convert(pdp10_be, "DEC-RADIX-50-36BIT-40BE", "UTF-8") end,
  byte_size(pdp10_be)
)

bench.(
  "DEC-RADIX-50 36BIT/40BE encode",
  fn -> Iconvex.convert(pdp10_utf8, "UTF-8", "DEC-RADIX-50-36BIT-40BE") end,
  byte_size(pdp10_be)
)

bench.(
  "DEC-RADIX-50 36BIT/40LE decode",
  fn -> Iconvex.convert(pdp10_le, "DEC-RADIX-50-36BIT-40LE", "UTF-8") end,
  byte_size(pdp10_le)
)

bench.(
  "DEC-RADIX-50 36BIT/40LE encode",
  fn -> Iconvex.convert(pdp10_utf8, "UTF-8", "DEC-RADIX-50-36BIT-40LE") end,
  byte_size(pdp10_le)
)

{:ok, pdp9_be_word} = Iconvex.convert("SYM", "UTF-8", "DEC-RADIX-50-18BIT-24BE")
{:ok, pdp9_le_word} = Iconvex.convert("SYM", "UTF-8", "DEC-RADIX-50-18BIT-24LE")
pdp9_be = :binary.copy(pdp9_be_word, 333_333)
pdp9_le = :binary.copy(pdp9_le_word, 333_333)
pdp9_utf8 = :binary.copy("SYM", 333_333)

bench.(
  "DEC-RADIX-50 18BIT/24BE decode",
  fn -> Iconvex.convert(pdp9_be, "DEC-RADIX-50-18BIT-24BE", "UTF-8") end,
  byte_size(pdp9_be)
)

bench.(
  "DEC-RADIX-50 18BIT/24BE encode",
  fn -> Iconvex.convert(pdp9_utf8, "UTF-8", "DEC-RADIX-50-18BIT-24BE") end,
  byte_size(pdp9_be)
)

bench.(
  "DEC-RADIX-50 18BIT/24LE decode",
  fn -> Iconvex.convert(pdp9_le, "DEC-RADIX-50-18BIT-24LE", "UTF-8") end,
  byte_size(pdp9_le)
)

bench.(
  "DEC-RADIX-50 18BIT/24LE encode",
  fn -> Iconvex.convert(pdp9_utf8, "UTF-8", "DEC-RADIX-50-18BIT-24LE") end,
  byte_size(pdp9_le)
)
