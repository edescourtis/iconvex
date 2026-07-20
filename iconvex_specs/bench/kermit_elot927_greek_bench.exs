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

corpus = fn alphabet ->
  copies = div(1_048_576, byte_size(alphabet)) + 1
  alphabet |> :binary.copy(copies) |> binary_part(0, 1_048_576)
end

standard_alphabet =
  0x00..0x7F
  |> Enum.reject(&(&1 in [0x4A, 0x57, 0x6A]))
  |> :binary.list_to_bin()

kermit_alphabet = :binary.list_to_bin(Enum.to_list(0x00..0x7F))

for {label, encoding, units} <- [
      {"Standard ELOT 927", "ELOT-927", corpus.(standard_alphabet)},
      {"Kermit ELOT927", "KERMIT-ELOT927-GREEK", corpus.(kermit_alphabet)}
    ] do
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
