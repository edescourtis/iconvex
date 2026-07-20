bench = fn label, fun, source_bytes ->
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

  mib_per_second = source_bytes / 1_048_576 / (median_us / 1_000_000)
  IO.puts("#{label}\t#{Float.round(mib_per_second, 2)} MiB/s\t#{median_us} us")
end

alphabet = :binary.list_to_bin(Enum.to_list(0x00..0x7F))
units = :binary.copy(alphabet, 8_192)
{:ok, utf8} = Iconvex.convert(units, "SHORT-KOI", "UTF-8")

bench.(
  "SHORT-KOI decode to UTF-8",
  fn -> Iconvex.convert(units, "SHORT-KOI", "UTF-8") end,
  byte_size(units)
)

bench.(
  "SHORT-KOI encode from UTF-8",
  fn -> Iconvex.convert(utf8, "UTF-8", "SHORT-KOI") end,
  byte_size(units)
)

for order <- [:msb, :lsb] do
  {:ok, packed} = Iconvex.Specs.Packed.encode_from_utf8(utf8, "SHORT-KOI", order)

  bench.(
    "SHORT-KOI packed #{order} encode",
    fn -> Iconvex.Specs.Packed.encode_from_utf8(utf8, "SHORT-KOI", order) end,
    byte_size(units)
  )

  bench.(
    "SHORT-KOI packed #{order} decode",
    fn -> Iconvex.Specs.Packed.decode_to_utf8(packed, "SHORT-KOI", order) end,
    byte_size(units)
  )
end
