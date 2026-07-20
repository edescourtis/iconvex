Mix.Task.run("app.start")

output = Path.expand("../SUPPORTED_PACKED_CODEC_INVENTORY.csv", __DIR__)

csv_field = fn value ->
  if String.contains?(value, [",", "\"", "\n", "\r"]) do
    "\"" <> String.replace(value, "\"", "\"\"") <> "\""
  else
    value
  end
end

rows =
  Iconvex.Specs.Packed.all_profiles()
  |> Enum.map(fn profile ->
    aliases =
      if Code.ensure_loaded?(profile.codec) and function_exported?(profile.codec, :aliases, 0),
        do: profile.codec.aliases() |> Enum.sort() |> Enum.join("|"),
        else: ""

    [
      profile.canonical,
      aliases,
      profile.unit_bits,
      profile.standard_order,
      inspect(profile.codec),
      "#{profile.canonical}-PACKED-MSB|#{profile.canonical}-PACKED-LSB"
    ]
    |> Enum.map(&to_string/1)
    |> Enum.map_join(",", csv_field)
  end)

contents =
  Enum.join(["canonical,aliases,unit_bits,standard_order,module,packed_names" | rows], "\n") <>
    "\n"

File.write!(output, contents)
IO.puts("wrote #{length(rows)} packed codec rows to #{Path.relative_to_cwd(output)}")
