bench = fn label, fun, bytes ->
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

  mib_per_second = bytes / 1_048_576 / (median_us / 1_000_000)
  IO.puts("#{label}\t#{Float.round(mib_per_second, 2)} MiB/s\t#{median_us} us")
end

units = 1..32 |> Enum.to_list() |> :binary.list_to_bin() |> :binary.copy(32_768)

for codec <- [
      "CDC-DISPLAY-CODE-63",
      "CDC-DISPLAY-CODE-64",
      "CDC-DISPLAY-CODE-ASCII-63",
      "CDC-DISPLAY-CODE-ASCII-64"
    ] do
  {:ok, utf8} = Iconvex.convert(units, codec, "UTF-8")

  bench.(
    "#{codec} decode",
    fn -> Iconvex.convert(units, codec, "UTF-8") end,
    byte_size(units)
  )

  bench.(
    "#{codec} encode",
    fn -> Iconvex.convert(utf8, "UTF-8", codec) end,
    byte_size(units)
  )
end
