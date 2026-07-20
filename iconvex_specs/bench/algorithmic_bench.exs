sample = String.duplicate("Hello Καλημέρα 日本語 हिन्दी 😀\n", 64)
codepoints = String.to_charlist(sample)
iterations = 2_000

codecs = [
  Iconvex.Specs.BOCU1,
  Iconvex.Specs.CESU8,
  Iconvex.Specs.IMAPUTF7,
  Iconvex.Specs.JavaModifiedUTF8,
  Iconvex.Specs.SCSU,
  Iconvex.Specs.UTFEBCDIC,
  Iconvex.Specs.UTF5
]

bench = fn label, fun ->
  for _ <- 1..200, do: fun.()
  started = System.monotonic_time()
  for _ <- 1..iterations, do: fun.()
  elapsed = System.monotonic_time() - started
  seconds = System.convert_time_unit(elapsed, :native, :nanosecond) / 1_000_000_000
  IO.puts("#{label}: #{Float.round(iterations / seconds, 1)} ops/s")
end

Enum.each(codecs, fn codec ->
  {:ok, encoded} = codec.encode(codepoints)

  bench.("#{codec.canonical_name()} encode #{length(codepoints)} scalars", fn ->
    codec.encode(codepoints)
  end)

  bench.("#{codec.canonical_name()} decode #{byte_size(encoded)} bytes", fn ->
    codec.decode(encoded)
  end)
end)
