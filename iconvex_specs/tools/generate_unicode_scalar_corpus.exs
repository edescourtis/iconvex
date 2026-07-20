root = Path.expand("..", __DIR__)
path = Path.join(root, "test/fixtures/all-unicode-scalars.utf32be")
File.mkdir_p!(Path.dirname(path))

File.open!(path, [:write, :binary], fn file ->
  for plane <- 0..16 do
    first = plane * 0x10000
    last = min(first + 0xFFFF, 0x10FFFF)

    bytes =
      for codepoint <- first..last,
          codepoint not in 0xD800..0xDFFF,
          into: <<>>,
          do: <<codepoint::unsigned-big-32>>

    IO.binwrite(file, bytes)
  end
end)

corpus = File.read!(path)
digest = corpus |> then(&:crypto.hash(:sha256, &1)) |> Base.encode16(case: :lower)
IO.puts("#{path}: #{byte_size(corpus)} bytes; SHA-256 #{digest}")
