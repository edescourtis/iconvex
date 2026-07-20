families = [
  {"SBCS", "aix-IBM_1046-4.3.6"},
  {"DBCS", "ibm-835_P100-1995"},
  {"MBCS", "euc-jp-2007"},
  {"four-byte MBCS", "ibm-5487_P100-2001"},
  {"SI/SO MBCS", "ibm-25546_P100-1997"}
]

iterations = 1_000

median = fn values ->
  sorted = Enum.sort(values)
  Enum.at(sorted, div(length(sorted), 2))
end

measure = fn fun ->
  for _ <- 1..100, do: fun.()

  samples =
    for _ <- 1..9 do
      started = System.monotonic_time()
      for _ <- 1..iterations, do: fun.()
      System.monotonic_time() - started
    end

  elapsed = median.(samples)
  seconds = System.convert_time_unit(elapsed, :native, :nanosecond) / 1_000_000_000
  iterations / seconds
end

Enum.each(families, fn {family, source_name} ->
  entry = Enum.find(Iconvex.Specs.ICUArchive.encodings(), &(&1.source_name == source_name))
  codec = Enum.at(Iconvex.Specs.ICUArchive.codecs(), entry.index - 1)
  table = Iconvex.Tables.fetch!(entry.id)

  scalars =
    table.encode
    |> Map.keys()
    |> Enum.filter(fn key ->
      tuple_size(key) == 1 and elem(key, 0) not in 0xD800..0xDFFF
    end)
    |> Enum.sort()
    |> Enum.take(256)
    |> Enum.flat_map(&Tuple.to_list/1)
    |> then(&:lists.flatten(List.duplicate(&1, 4)))

  {:ok, encoded} = codec.encode(scalars)
  {:ok, ^scalars} = codec.decode(encoded)
  encode_rate = measure.(fn -> codec.encode(scalars) end)
  decode_rate = measure.(fn -> codec.decode(encoded) end)

  IO.puts(
    "#{family} #{source_name}: encode #{Float.round(encode_rate, 1)} ops/s, " <>
      "decode #{Float.round(decode_rate, 1)} ops/s, #{length(scalars)} scalars, " <>
      "#{byte_size(encoded)} bytes"
  )
end)
