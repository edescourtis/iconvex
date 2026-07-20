bench = fn label, fun, mib_bytes ->
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

  mib_per_second = mib_bytes / 1_048_576 / (median_us / 1_000_000)
  IO.puts("#{label}\t#{Float.round(mib_per_second, 2)} MiB/s\t#{median_us} us")
end

ascii64 = 0..127 |> Enum.to_list() |> :binary.list_to_bin() |> :binary.copy(8_192)
ascii63 = 0..127 |> Enum.reject(&(&1 == ?%)) |> :binary.list_to_bin() |> :binary.copy(8_256)

for {codec, utf8} <- [
      {"CDC-6-12-DISPLAY-CODE-63", ascii63},
      {"CDC-6-12-DISPLAY-CODE-64", ascii64}
    ] do
  {:ok, encoded} = Iconvex.convert(utf8, "UTF-8", codec)

  bench.(
    "#{codec} decode",
    fn -> Iconvex.convert(encoded, codec, "UTF-8") end,
    byte_size(encoded)
  )

  bench.(
    "#{codec} encode",
    fn -> Iconvex.convert(utf8, "UTF-8", codec) end,
    byte_size(utf8)
  )
end

{:ok, packed} =
  Iconvex.Specs.Packed.encode_from_utf8(ascii64, "CDC-6-12-DISPLAY-CODE-64", :msb)

bench.(
  "CDC-6-12-DISPLAY-CODE-64 packed decode",
  fn ->
    Iconvex.Specs.Packed.decode_to_utf8(packed, "CDC-6-12-DISPLAY-CODE-64", :msb)
  end,
  bit_size(packed) / 8
)

bench.(
  "CDC-6-12-DISPLAY-CODE-64 packed encode",
  fn ->
    Iconvex.Specs.Packed.encode_from_utf8(ascii64, "CDC-6-12-DISPLAY-CODE-64", :msb)
  end,
  byte_size(ascii64)
)

{:ok, packed_lsb} =
  Iconvex.Specs.Packed.encode_from_utf8(ascii64, "CDC-6-12-DISPLAY-CODE-64", :lsb)

bench.(
  "CDC-6-12-DISPLAY-CODE-64 packed LSB decode",
  fn ->
    Iconvex.Specs.Packed.decode_to_utf8(packed_lsb, "CDC-6-12-DISPLAY-CODE-64", :lsb)
  end,
  packed_lsb.bit_size / 8
)

bench.(
  "CDC-6-12-DISPLAY-CODE-64 packed LSB encode",
  fn ->
    Iconvex.Specs.Packed.encode_from_utf8(ascii64, "CDC-6-12-DISPLAY-CODE-64", :lsb)
  end,
  byte_size(ascii64)
)
