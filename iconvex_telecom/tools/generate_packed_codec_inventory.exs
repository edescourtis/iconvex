Mix.Task.run("app.start")

output = Path.expand("../SUPPORTED_PACKED_CODEC_INVENTORY.csv", __DIR__)

rows =
  Iconvex.Telecom.Packed.profiles()
  |> Enum.map(fn profile ->
    Enum.join(
      [
        profile.canonical,
        profile.unit_bits,
        profile.standard_order,
        inspect(profile.codec),
        "#{profile.canonical}-PACKED-MSB|#{profile.canonical}-PACKED-LSB"
      ],
      ","
    )
  end)

contents =
  Enum.join(["canonical,unit_bits,standard_order,module,packed_names" | rows], "\n") <> "\n"

File.write!(output, contents)
IO.puts("wrote #{length(rows)} packed codec rows to #{Path.relative_to_cwd(output)}")
