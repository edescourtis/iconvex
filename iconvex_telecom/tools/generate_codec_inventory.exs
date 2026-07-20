Mix.Task.run("app.start")

output = Path.expand("../SUPPORTED_CODEC_INVENTORY.csv", __DIR__)

rows =
  Iconvex.Telecom.codecs()
  |> Enum.sort_by(& &1.canonical_name())
  |> Enum.map(fn codec ->
    fields = [
      codec.canonical_name(),
      codec.aliases() |> Enum.sort() |> Enum.join("|"),
      inspect(codec),
      to_string(codec.stateful?())
    ]

    if Enum.any?(fields, &(String.contains?(&1, [",", "\n", "\r"]))) do
      Mix.raise("inventory field needs CSV quoting: #{inspect(fields)}")
    end

    Enum.join(fields, ",")
  end)

contents = Enum.join(["canonical,aliases,module,stateful" | rows], "\n") <> "\n"
File.write!(output, contents)

IO.puts("wrote #{length(rows)} codec rows to #{Path.relative_to_cwd(output)}")
