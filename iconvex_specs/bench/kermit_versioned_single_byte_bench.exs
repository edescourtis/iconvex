bench = fn fun, logical_bytes ->
  validate = fn
    {:ok, _output} -> :ok
    {_output, 0} -> :ok
    other -> raise "benchmark conversion failed: #{inspect(other)}"
  end

  for _ <- 1..2 do
    fun.() |> validate.()
    :erlang.garbage_collect()
  end

  median_us =
    for _ <- 1..7 do
      :erlang.garbage_collect()
      {microseconds, result} = :timer.tc(fun)
      validate.(result)
      microseconds
    end
    |> Enum.sort()
    |> Enum.at(3)

  {logical_bytes / 1_048_576 / (median_us / 1_000_000), median_us}
end

corpus = fn alphabet ->
  copies = div(1_048_576, byte_size(alphabet)) + 1
  alphabet |> :binary.copy(copies) |> binary_part(0, 1_048_576)
end

valid_alphabet = fn encoding, excluded ->
  for byte <- 0x00..0xFF,
      byte not in excluded,
      match?({:ok, _}, Iconvex.convert(<<byte>>, encoding, "UTF-8")),
      into: <<>>,
      do: <<byte>>
end

profiles = [
  {"Greek ISO / ELOT 928", "GREEK-ISO", "ELOT_928", [0xA4, 0xA5, 0xAA]},
  {"Hebrew ISO historical", "HEBREW-ISO", "HEBREW", [0xAF, 0xFD, 0xFE]},
  {"Latin-6 ISO", "LATIN6-ISO", "ISO-8859-10", []},
  {"Macintosh Latin", "MACINTOSH-LATIN", "MACICELAND", [0xF0]}
]

gnu = System.get_env("GNU_ICONV", "/opt/homebrew/opt/libiconv/bin/iconv")

unless File.regular?(gnu) do
  raise "GNU iconv executable not found at #{gnu}; set GNU_ICONV"
end

tmp =
  Path.join(System.tmp_dir!(), "iconvex-kermit-sbcs-bench-#{System.unique_integer([:positive])}")

File.mkdir_p!(tmp)

try do
  IO.puts("profile\tdirection\tIconvex MiB/s\tGNU MiB/s\tGNU/Iconvex")

  for {label, encoding, gnu_encoding, excluded} <- profiles do
    units = encoding |> valid_alphabet.(excluded) |> corpus.()
    {:ok, utf8} = Iconvex.convert(units, encoding, "UTF-8")

    encoded_path = Path.join(tmp, "#{encoding}.bin")
    utf8_path = Path.join(tmp, "#{encoding}.utf8")
    File.write!(encoded_path, units)
    File.write!(utf8_path, utf8)

    measurements = [
      {"decode", fn -> Iconvex.convert(units, encoding, "UTF-8") end,
       fn ->
         System.cmd(gnu, ["-f", gnu_encoding, "-t", "UTF-8", encoded_path],
           stderr_to_stdout: true
         )
       end},
      {"encode", fn -> Iconvex.convert(utf8, "UTF-8", encoding) end,
       fn ->
         System.cmd(gnu, ["-f", "UTF-8", "-t", gnu_encoding, utf8_path], stderr_to_stdout: true)
       end}
    ]

    for {direction, iconvex_fun, gnu_fun} <- measurements do
      {iconvex_rate, _iconvex_us} = bench.(iconvex_fun, byte_size(units))
      {gnu_rate, _gnu_us} = bench.(gnu_fun, byte_size(units))
      ratio = gnu_rate / iconvex_rate

      IO.puts(
        Enum.join(
          [
            label,
            direction,
            Float.round(iconvex_rate, 2),
            Float.round(gnu_rate, 2),
            Float.round(ratio, 2)
          ],
          "\t"
        )
      )

      if ratio > 30.0 do
        raise "#{encoding} #{direction} exceeds the 30x GNU performance ceiling"
      end
    end
  end
after
  File.rm_rf!(tmp)
end
