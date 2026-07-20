Mix.Task.run("app.start")

output = Path.expand("../SUPPORTED_CODEC_INVENTORY.csv", __DIR__)

csv_field = fn value ->
  if String.contains?(value, [",", "\"", "\n", "\r"]) do
    "\"" <> String.replace(value, "\"", "\"\"") <> "\""
  else
    value
  end
end

rows =
  Iconvex.Extras.codecs()
  |> Enum.sort_by(&{&1.canonical_name(), inspect(&1)})
  |> Enum.map(fn codec ->
    [
      codec.canonical_name(),
      codec.aliases() |> Enum.sort() |> Enum.join("|"),
      inspect(codec),
      to_string(codec.stateful?())
    ]
    |> Enum.map_join(",", csv_field)
  end)

contents = Enum.join(["canonical,aliases,module,stateful" | rows], "\n") <> "\n"
File.write!(output, contents)

IO.puts("wrote #{length(rows)} codec rows to #{Path.relative_to_cwd(output)}")
