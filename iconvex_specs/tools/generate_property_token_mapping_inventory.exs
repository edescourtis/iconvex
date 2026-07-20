Mix.Task.run("app.start")

arguments =
  case System.argv() do
    ["--" | arguments] -> arguments
    arguments -> arguments
  end

{options, arguments, invalid} =
  OptionParser.parse(arguments,
    strict: [output: :string, check: :boolean]
  )

unless arguments == [] and invalid == [] do
  Mix.raise(
    "usage: mix run tools/generate_property_token_mapping_inventory.exs -- " <>
      "[--output PATH] [--check]"
  )
end

output =
  options
  |> Keyword.get(
    :output,
    Path.expand("../SUPPORTED_PROPERTY_TOKEN_MAPPING_INVENTORY.csv", __DIR__)
  )
  |> Path.expand()

profile_name = fn
  :unique -> "exact"
  :minimum_decimal_token -> "readable-minimum-token-reverse"
  :lossless_vpua_1 -> "lossless-vpua-1"
end

rows =
  Iconvex.Specs.property_token_mappings()
  |> Enum.map(fn module ->
    metadata = module.metadata()

    Enum.join(
      [
        metadata.mapping_name,
        inspect(module),
        Atom.to_string(metadata.unihan_property),
        profile_name.(metadata.reverse_policy),
        metadata.assigned_tokens,
        metadata.reverse_scalars,
        metadata.grammar,
        Atom.to_string(metadata.transport),
        "no",
        "no"
      ],
      ","
    )
  end)

contents =
  Enum.join(
    [
      "mapping_name,module,unicode_property,profile,assigned_tokens,reverse_scalars,grammar,transport,codec_registry,gnu_libiconv_1_19_exact_alias"
      | rows
    ],
    "\n"
  ) <> "\n"

relative_output = Path.relative_to_cwd(output)

if options[:check] do
  if File.exists?(output) and File.read!(output) == contents do
    IO.puts("#{relative_output} is current (#{length(rows)} property-token mappings)")
  else
    Mix.raise("#{relative_output} is out of date")
  end
else
  output |> Path.dirname() |> File.mkdir_p!()
  File.write!(output, contents)
  IO.puts("wrote #{length(rows)} property-token mappings to #{relative_output}")
end
