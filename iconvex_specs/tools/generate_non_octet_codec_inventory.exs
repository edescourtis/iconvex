Mix.Task.run("app.start")

output = Path.expand("../SUPPORTED_NON_OCTET_CODEC_INVENTORY.csv", __DIR__)

csv_field = fn value ->
  if String.contains?(value, [",", "\"", "\n", "\r"]) do
    "\"" <> String.replace(value, "\"", "\"\"") <> "\""
  else
    value
  end
end

rows =
  Iconvex.Specs.non_octet_codecs()
  |> Enum.sort_by(& &1.canonical_name())
  |> Enum.map(fn codec ->
    transports = codec.transport_codecs() |> Enum.map(& &1.canonical_name()) |> Enum.join("|")

    aliases =
      if Code.ensure_loaded?(codec) and function_exported?(codec, :aliases, 0),
        do: codec.aliases() |> Enum.sort() |> Enum.join("|"),
        else: ""

    [codec.canonical_name(), aliases, inspect(codec), codec.unit_bits(), transports]
    |> Enum.map(&to_string/1)
    |> Enum.map_join(",", csv_field)
  end)

contents = Enum.join(["canonical,aliases,module,unit_bits,transports" | rows], "\n") <> "\n"
File.write!(output, contents)

IO.puts("wrote #{length(rows)} non-octet codec rows to #{Path.relative_to_cwd(output)}")
