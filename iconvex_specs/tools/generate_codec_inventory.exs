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
  Iconvex.Specs.registrations()
  |> Enum.sort_by(&{&1.canonical, inspect(&1.codec)})
  |> Enum.map(fn registration ->
    [
      registration.canonical,
      registration.aliases |> Enum.sort() |> Enum.join("|"),
      inspect(registration.codec),
      to_string(registration.codec.stateful?())
    ]
    |> Enum.map_join(",", csv_field)
  end)

contents = Enum.join(["canonical,aliases,module,stateful" | rows], "\n") <> "\n"
File.write!(output, contents)

IO.puts("wrote #{length(rows)} codec rows to #{Path.relative_to_cwd(output)}")
