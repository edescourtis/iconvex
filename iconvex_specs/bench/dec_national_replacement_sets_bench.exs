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
  {"United Kingdom", "DEC-NRC-UNITED-KINGDOM"},
  {"Dutch", "DEC-NRC-DUTCH"},
  {"Finnish", "DEC-NRC-FINNISH"},
  {"French", "DEC-NRC-FRENCH"},
  {"French Canadian", "DEC-NRC-FRENCH-CANADIAN"},
  {"German", "DEC-NRC-GERMAN"},
  {"Italian", "DEC-NRC-ITALIAN"},
  {"Norwegian/Danish", "DEC-NRC-NORWEGIAN-DANISH"},
  {"Portuguese", "DEC-NRC-PORTUGUESE"},
  {"Spanish", "DEC-NRC-SPANISH"},
  {"Swedish", "DEC-NRC-SWEDISH"},
  {"Swiss", "DEC-NRC-SWISS"}
]

units = :binary.copy(:binary.list_to_bin(Enum.to_list(0x00..0x7F)), 8_192)

for {label, encoding} <- profiles do
  {:ok, utf8} = Iconvex.convert(units, encoding, "UTF-8")

  bench.(
    "#{label} decode to UTF-8",
    fn -> Iconvex.convert(units, encoding, "UTF-8") end,
    byte_size(units)
  )

  bench.(
    "#{label} encode from UTF-8",
    fn -> Iconvex.convert(utf8, "UTF-8", encoding) end,
    byte_size(units)
  )
end

for {label, encoding} <- [
      {"Dutch", "DEC-NRC-DUTCH"},
      {"French", "DEC-NRC-FRENCH"}
    ] do
  {:ok, utf8} = Iconvex.convert(units, encoding, "UTF-8")

  for order <- [:msb, :lsb] do
    {:ok, packed} = Iconvex.Specs.Packed.encode_from_utf8(utf8, encoding, order)

    bench.(
      "#{label} packed #{order} encode",
      fn -> Iconvex.Specs.Packed.encode_from_utf8(utf8, encoding, order) end,
      byte_size(units)
    )

    bench.(
      "#{label} packed #{order} decode",
      fn -> Iconvex.Specs.Packed.decode_to_utf8(packed, encoding, order) end,
      byte_size(units)
    )
  end
end
