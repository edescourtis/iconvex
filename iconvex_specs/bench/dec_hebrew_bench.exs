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

profiles = [
  {"SI-960", :binary.list_to_bin(Enum.to_list(0x00..0x7F))},
  {"DEC-HEBREW-8",
   :binary.list_to_bin(
     Enum.filter(0x00..0xFF, fn byte ->
       match?({:ok, [_]}, Iconvex.Specs.DECHebrew8.decode(<<byte>>))
     end)
   )}
]

for {encoding, alphabet} <- profiles do
  repeats = div(1_048_576 + byte_size(alphabet) - 1, byte_size(alphabet))
  units = :binary.copy(alphabet, repeats) |> binary_part(0, 1_048_576)
  {:ok, utf8} = Iconvex.convert(units, encoding, "UTF-8")

  bench.(
    "#{encoding} decode to UTF-8",
    fn -> Iconvex.convert(units, encoding, "UTF-8") end,
    byte_size(units)
  )

  bench.(
    "#{encoding} encode from UTF-8",
    fn -> Iconvex.convert(utf8, "UTF-8", encoding) end,
    byte_size(units)
  )
end

si960_units = :binary.copy(:binary.list_to_bin(Enum.to_list(0x00..0x7F)), 8_192)
{:ok, si960_utf8} = Iconvex.convert(si960_units, "SI-960", "UTF-8")

for order <- [:msb, :lsb] do
  {:ok, packed} = Iconvex.Specs.Packed.encode_from_utf8(si960_utf8, "SI-960", order)

  bench.(
    "SI-960 packed #{order} encode",
    fn -> Iconvex.Specs.Packed.encode_from_utf8(si960_utf8, "SI-960", order) end,
    byte_size(si960_units)
  )

  bench.(
    "SI-960 packed #{order} decode",
    fn -> Iconvex.Specs.Packed.decode_to_utf8(packed, "SI-960", order) end,
    byte_size(si960_units)
  )
end
