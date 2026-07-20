source_path =
  case System.argv() do
    [path] -> path
    _ -> Mix.raise("usage: mix run tools/import_aosp_gsm_alphabet.exs PATH/TO/GsmAlphabet.java")
  end

expected_sha256 = "af28d761a4efbdafe6e5c65b23d0b3ace20164454f39db03dc796246772387ba"
source = File.read!(source_path)
actual_sha256 = :crypto.hash(:sha256, source) |> Base.encode16(case: :lower)

if actual_sha256 != expected_sha256 do
  Mix.raise("unexpected GsmAlphabet.java SHA-256: #{actual_sha256}")
end

decode_java_string = fn literal ->
  literal
  |> String.slice(1, byte_size(literal) - 2)
  |> then(fn body ->
    Regex.replace(~r/\\u([0-9a-fA-F]{4})/, body, fn _, hex ->
      <<String.to_integer(hex, 16)::utf8>>
    end)
  end)
  |> then(fn body ->
    Enum.reduce(
      [
        {"\\n", "\n"},
        {"\\r", "\r"},
        {"\\t", "\t"},
        {"\\f", "\f"},
        {"\\\"", "\""},
        {"\\'", "'"},
        {"\\\\", "\\"}
      ],
      body,
      fn {pattern, replacement}, acc -> String.replace(acc, pattern, replacement) end
    )
  end)
end

extract_array = fn marker, next_marker ->
  [_, after_marker] = String.split(source, marker, parts: 2)
  [body | _] = String.split(after_marker, next_marker, parts: 2)

  body =
    body
    |> String.replace(~r{/\*.*?\*/}s, "")
    |> String.replace(~r{//[^\n]*}, "")

  tokens = Regex.scan(~r/"(?:\\.|[^"\\])*"|[+,]/s, body) |> List.flatten()

  {tables, current} =
    Enum.reduce(tokens, {[], []}, fn
      ",", {tables, current} -> {[current |> Enum.reverse() |> Enum.join() | tables], []}
      "+", acc -> acc
      literal, {tables, current} -> {tables, [decode_java_string.(literal) | current]}
    end)

  tables =
    if current == [],
      do: tables,
      else: [current |> Enum.reverse() |> Enum.join() | tables]

  tables |> Enum.reverse() |> List.to_tuple()
end

locking =
  extract_array.(
    "private static final String[] sLanguageTables = {",
    "/**\n     * GSM default extension table"
  )

single_shift =
  extract_array.(
    "private static final String[] sLanguageShiftTables = new String[]{",
    "static {\n        enableCountrySpecificEncodings();"
  )

unless tuple_size(locking) == 14 and tuple_size(single_shift) == 14 do
  Mix.raise("expected 14 locking and 14 single-shift slots")
end

locking
|> Tuple.to_list()
|> Enum.with_index()
|> Enum.each(fn
  {"", 2} -> :ok
  {table, id} ->
    length = table |> String.to_charlist() |> length()

    unless length == 128 do
      Mix.raise("locking table #{id} has #{length} entries")
    end
end)

single_shift
|> Tuple.to_list()
|> Enum.with_index()
|> Enum.each(fn {table, id} ->
  length = table |> String.to_charlist() |> length()

  unless length == 128 do
    Mix.raise("single-shift table #{id} has #{length} entries")
  end
end)

data = %{
  format: 1,
  source: %{
    android_repository_commit: "1cdfff555f4a21f71ccc978290e2e212e2f8b168",
    file_sha256: expected_sha256,
    specification: "3GPP TS 23.038 Release 19 / ETSI TS 123 038 V19.0.0"
  },
  locking:
    locking
    |> Tuple.to_list()
    |> Enum.map(fn
      "" -> nil
      table -> table |> String.to_charlist() |> List.to_tuple()
    end)
    |> List.to_tuple(),
  single_shift:
    single_shift
    |> Tuple.to_list()
    |> Enum.map(fn table ->
      table
      |> String.to_charlist()
      |> Enum.map(fn
        0x20 -> nil
        codepoint -> codepoint
      end)
      |> List.to_tuple()
    end)
    |> List.to_tuple()
}

output = Path.expand("../priv/gsm0338_tables.etf", __DIR__)
File.mkdir_p!(Path.dirname(output))
File.write!(output, :erlang.term_to_binary(data, [:deterministic]))

IO.puts("wrote #{output} (#{File.stat!(output).size} bytes)")
