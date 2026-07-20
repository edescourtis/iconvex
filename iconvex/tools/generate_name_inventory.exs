Mix.Task.run("app.start")

output = Path.expand("../SUPPORTED_NAME_INVENTORY.csv", __DIR__)

rows =
  Iconvex.Registry.builtin_aliases()
  |> Enum.map(fn {name, id} ->
    {:ok, entry} = Iconvex.Registry.builtin_resolve(id)
    fields = [name, entry.canonical]

    if Enum.any?(fields, &String.contains?(&1, [",", "\n", "\r"])) do
      Mix.raise("name inventory field needs CSV quoting: #{inspect(fields)}")
    end

    Enum.join(fields, ",")
  end)
  |> Enum.sort()

contents = Enum.join(["name,canonical" | rows], "\n") <> "\n"
File.write!(output, contents)

IO.puts("wrote #{length(rows)} core names to #{Path.relative_to_cwd(output)}")
