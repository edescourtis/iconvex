Mix.Task.run("app.start")

output = Path.expand("../SUPPORTED_RAW_TRANSPORT_INVENTORY.csv", __DIR__)

csv_field = fn value ->
  if String.contains?(value, [",", "\"", "\n", "\r"]) do
    "\"" <> String.replace(value, "\"", "\"\"") <> "\""
  else
    value
  end
end

rows =
  Iconvex.Specs.RawTransports.profiles()
  |> Enum.map(fn profile ->
    [
      profile.canonical,
      profile.mode,
      inspect(profile.module),
      profile.input_semantics,
      profile.input_unit_bits,
      profile.card_unit_bits,
      profile.standard_packed_order,
      Enum.join(profile.library_packed_orders, "|"),
      Enum.join(profile.transport_names, "|"),
      profile.unicode_codec_registered
    ]
    |> Enum.map(fn
      nil -> ""
      value -> to_string(value)
    end)
    |> Enum.map_join(",", csv_field)
  end)

header =
  "canonical,mode,module,input_semantics,input_unit_bits,card_unit_bits," <>
    "standard_packed_order,library_packed_orders,transport_names," <>
    "unicode_codec_registered"

contents = Enum.join([header | rows], "\n") <> "\n"
File.write!(output, contents)
IO.puts("wrote #{length(rows)} raw transport rows to #{Path.relative_to_cwd(output)}")
