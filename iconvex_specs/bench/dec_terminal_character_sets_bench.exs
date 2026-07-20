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

technical_defined =
  Enum.reject(0x21..0x7E, &(&1 in [0x38, 0x39, 0x3A, 0x3B, 0x52, 0x54, 0x55, 0x6D, 0x75]))

profiles = [
  {"DEC-SPECIAL", :binary.list_to_bin(Enum.to_list(0x21..0x7E))},
  {"DEC-SPECIAL-GR", :binary.list_to_bin(Enum.to_list(0xA1..0xFE))},
  {"DEC-TECHNICAL", :binary.list_to_bin(technical_defined)},
  {"DEC-TECHNICAL-GR", :binary.list_to_bin(Enum.map(technical_defined, &(&1 + 0x80)))}
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

for encoding <- ["DEC-SPECIAL", "DEC-TECHNICAL"] do
  alphabet =
    if encoding == "DEC-SPECIAL",
      do: :binary.list_to_bin(Enum.to_list(0x21..0x7E)),
      else: :binary.list_to_bin(technical_defined)

  repeats = div(1_048_576 + byte_size(alphabet) - 1, byte_size(alphabet))
  units = :binary.copy(alphabet, repeats) |> binary_part(0, 1_048_576)
  {:ok, utf8} = Iconvex.convert(units, encoding, "UTF-8")

  for order <- [:msb, :lsb] do
    {:ok, packed} = Iconvex.Specs.Packed.encode_from_utf8(utf8, encoding, order)

    bench.(
      "#{encoding} packed #{order} encode",
      fn -> Iconvex.Specs.Packed.encode_from_utf8(utf8, encoding, order) end,
      byte_size(units)
    )

    bench.(
      "#{encoding} packed #{order} decode",
      fn -> Iconvex.Specs.Packed.decode_to_utf8(packed, encoding, order) end,
      byte_size(units)
    )
  end
end
