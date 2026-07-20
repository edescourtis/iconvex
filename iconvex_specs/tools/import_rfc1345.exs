defmodule Iconvex.Specs.Tools.ImportRFC1345 do
  @source_sha256 "d1a4b6a3d6514f8ea96b74e49af40edae5c8edfcc1b1e7d9d7caebc9d622e3b0"
  @source_url "https://www.rfc-editor.org/rfc/rfc1345.txt"
  @errata_sha256 "d11430dad27d385a6ec8872963e265f480c349cc1c18e0a6e9951e1f55d56ed7"
  @errata_url "https://errata.rfc-editor.org/search/?rfc_number=1345&presentation=records"
  @ignored_tokens ["??", "__"]
  @mapping_sources [
    %{
      file: "CP936.TXT",
      name: "CP936.TXT",
      sha256: "b86f601c575e9ab457380b6f7abef03c75499cc6075bdc8b4b27f3f2de74bf6a",
      url: "https://www.unicode.org/Public/MAPPINGS/VENDORS/MICSFT/WINDOWS/CP936.TXT"
    },
    %{
      file: "JIS0208.TXT",
      name: "JIS0208.TXT",
      sha256: "1c571870457f19c97720631fa83ee491549a96ba1436da1296786a67d8632e87",
      url: "https://www.unicode.org/Public/MAPPINGS/OBSOLETE/EASTASIA/JIS/JIS0208.TXT"
    },
    %{
      file: "JIS0212.TXT",
      name: "JIS0212.TXT",
      sha256: "477820bb3055bbcc90880d788cd95607d221dc94457bae249231adecf13c12e6",
      url: "https://www.unicode.org/Public/MAPPINGS/OBSOLETE/EASTASIA/JIS/JIS0212.TXT"
    },
    %{
      file: "KSX1001.TXT",
      name: "KSX1001.TXT",
      sha256: "d8d2a35206ac0ea2865f5d801c9d6717f735bf46f263a658a64a960abe59e371",
      url: "https://www.unicode.org/Public/MAPPINGS/OBSOLETE/EASTASIA/KSC/KSX1001.TXT"
    }
  ]

  def run do
    root = Path.expand("..", __DIR__)
    source_path = Path.join(root, "priv/sources/rfc1345.txt")
    source = File.read!(source_path)
    assert_source!(source)
    errata_path = Path.join(root, "priv/sources/rfc1345_errata.html")
    errata = File.read!(errata_path)
    assert_digest!(errata, @errata_sha256, "RFC 1345 errata")
    {mapping_sources, secondary_mappings} = load_mapping_sources!(root)

    mnemonic_rows = source |> parse_mnemonic_rows() |> apply_mnemonic_errata()
    mnemonics = Map.new(mnemonic_rows)
    errata_charsets = parse_errata_charsets(errata)
    charsets = apply_errata(parse_charsets(source), errata_charsets)

    IO.puts(
      "applying #{length(errata_charsets)} complete RFC errata tables: " <>
        Enum.map_join(errata_charsets, ", ", & &1.name)
    )

    unless length(charsets) == 145 do
      Mix.raise("expected 145 RFC 1345 charsets, got #{length(charsets)}")
    end

    output = Path.join(root, "priv/tables")
    File.mkdir_p!(output)

    manifest =
      charsets
      |> Enum.with_index(1)
      |> Enum.map(fn {charset, index} ->
        id = String.to_atom("rfc1345_#{String.pad_leading(Integer.to_string(index), 3, "0")}")
        {table, metadata} = build_table(charset, mnemonics, secondary_mappings)
        write_table(output, id, table)

        Map.merge(metadata, %{
          id: id,
          index: index,
          name: charset.name,
          aliases: aliases(charset),
          source: "RFC 1345"
        })
      end)

    expected = MapSet.new(Enum.map(manifest, &"#{&1.id}.etf"))

    output
    |> Path.join("rfc1345_*.etf")
    |> Path.wildcard()
    |> Enum.each(fn path ->
      unless MapSet.member?(expected, Path.basename(path)), do: File.rm!(path)
    end)

    data = %{
      format: 1,
      source: %{name: "RFC 1345", sha256: @source_sha256, url: @source_url},
      errata_source: %{
        name: "RFC 1345 Errata",
        sha256: @errata_sha256,
        url: @errata_url
      },
      mapping_sources: mapping_sources,
      encodings: manifest
    }

    File.write!(
      Path.join(root, "priv/rfc1345_manifest.etf"),
      :erlang.term_to_binary(data, [:deterministic])
    )

    File.write!(
      Path.join(root, "priv/rfc1345_mnemonics.etf"),
      :erlang.term_to_binary(
        %{format: 1, mappings: mnemonic_rows, source: data.source},
        [:deterministic, :compressed]
      )
    )

    write_supported_encodings!(root, manifest)

    total_mappings = Enum.sum(Enum.map(manifest, & &1.decode_mappings))
    total_combinations = Enum.sum(Enum.map(manifest, & &1.combinations))

    IO.puts(
      "wrote #{length(manifest)} RFC 1345 codecs, #{total_mappings} decode mappings, " <>
        "#{total_combinations} combining mappings"
    )
  end

  defp assert_source!(source) do
    assert_digest!(source, @source_sha256, "RFC 1345")
  end

  defp assert_digest!(source, expected, label) do
    actual = :crypto.hash(:sha256, source) |> Base.encode16(case: :lower)
    unless actual == expected, do: Mix.raise("#{label} SHA-256 mismatch: #{actual}")
  end

  defp load_mapping_sources!(root) do
    contents =
      Map.new(@mapping_sources, fn source ->
        content = File.read!(Path.join([root, "priv", "sources", source.file]))
        assert_digest!(content, source.sha256, source.name)
        {source.name, content}
      end)

    sources = Enum.map(@mapping_sources, &Map.take(&1, [:name, :sha256, :url]))

    mappings = %{
      "GB_2312-80" => parse_cp936_grid(Map.fetch!(contents, "CP936.TXT")),
      "JIS_C6226-1983" => parse_jis0208_grid(Map.fetch!(contents, "JIS0208.TXT")),
      "JIS_X0212-1990" => parse_two_column_grid(Map.fetch!(contents, "JIS0212.TXT")),
      "KS_C_5601-1987" => parse_two_column_grid(Map.fetch!(contents, "KSX1001.TXT"))
    }

    {sources, mappings}
  end

  defp parse_jis0208_grid(source) do
    parse_grid(source, ~r/^0x[0-9A-F]+\s+0x([0-9A-F]{4})\s+0x([0-9A-F]+)/i, fn code ->
      code
    end)
  end

  defp parse_two_column_grid(source) do
    parse_grid(source, ~r/^0x([0-9A-F]{4})\s+0x([0-9A-F]+)/i, fn code -> code end)
  end

  defp parse_cp936_grid(source) do
    parse_grid(source, ~r/^0x([0-9A-F]{4})\s+0x([0-9A-F]+)/i, fn code ->
      <<high, low>> = <<String.to_integer(code, 16)::16>>

      if high in 0xA1..0xFE and low in 0xA1..0xFE do
        Base.encode16(<<high - 0x80, low - 0x80>>)
      end
    end)
  end

  defp parse_grid(source, pattern, normalize_code) do
    source
    |> String.split("\n")
    |> Enum.reduce(%{}, fn line, mappings ->
      case Regex.run(pattern, line, capture: :all_but_first) do
        [code, unicode] ->
          case normalize_code.(code) do
            nil ->
              mappings

            normalized ->
              Map.put_new(mappings, hex_bytes(normalized), String.to_integer(unicode, 16))
          end

        nil ->
          mappings
      end
    end)
  end

  defp hex_bytes(value) do
    value
    |> String.to_integer(16)
    |> then(&<<&1::16>>)
  end

  defp parse_mnemonic_rows(source) do
    [_, table_and_rest] = String.split(source, "3.  CHARACTER MNEMONIC TABLE", parts: 2)
    [table | _] = String.split(table_and_rest, "4.  CHARSETS", parts: 2)

    table
    |> String.split("\n")
    |> Enum.flat_map(fn line ->
      case Regex.run(~r/^ (\S+)\s+([0-9a-f]{4,6})\s+/i, line, capture: :all_but_first) do
        [mnemonic, hex] -> [{mnemonic, String.to_integer(hex, 16)}]
        nil -> []
      end
    end)
  end

  # Verified RFC Erratum 2813 corrects two accidental uppercase mnemonics for
  # lowercase letters. Without it the supposedly unambiguous transport syntax
  # has two duplicate tokens.
  defp apply_mnemonic_errata(rows) do
    Enum.map(rows, fn
      {"N->", 0x1E4B} -> {"n->", 0x1E4B}
      {"S.-.", 0x1E69} -> {"s.-.", 0x1E69}
      row -> row
    end)
  end

  defp parse_charsets(source) do
    [_, tables_and_rest] = String.split(source, "5.  CHARSET TABLES", parts: 2)
    [tables | _] = String.split(tables_and_rest, "ACKNOWLEDGEMENTS", parts: 2)

    parse_charset_tables(tables)
  end

  defp parse_charset_tables(tables) do
    {charsets, current, directive} =
      tables |> String.split("\n") |> Enum.reduce({[], nil, nil}, &parse_line/2)

    charsets
    |> flush_charset(flush_directive(current, directive))
    |> Enum.reverse()
  end

  defp parse_errata_charsets(html) do
    html
    |> String.split(~s(<div class="card mb-4">))
    |> Enum.flat_map(fn card ->
      with [id] <- Regex.run(~r/Errata-ID:.*?eid(\d+)/s, card, capture: :all_but_first),
           [block] <-
             Regex.run(
               ~r/<p>It should say:<\/p>\s*<pre[^>]*><code>(.*?)<\/code><\/pre>/s,
               card,
               capture: :all_but_first
             ),
           decoded <- html_decode(block),
           [%{name: name} = charset] <- parse_charset_tables(decoded),
           true <- assignment_count(charset) == 256 or name == "IBM423" do
        [Map.put(charset, :errata, String.to_integer(id))]
      else
        _ -> []
      end
    end)
  end

  defp apply_errata(charsets, corrections) do
    corrections = Map.new(corrections, &{&1.name, &1})

    Enum.map(charsets, fn charset ->
      Map.get(corrections, charset.name, Map.put(charset, :errata, nil))
    end)
  end

  defp assignment_count(charset) do
    charset.directives
    |> Enum.reduce(0, fn
      %{keyword: "code"} = directive, count ->
        count + length(code_assignment_tokens(directive))

      %{keyword: "code2"} = directive, count ->
        count + length(code2_assignment_tokens(directive))

      %{keyword: "codex", args: args}, count ->
        [_prefix, row_start, row_end, column_start, column_end | _] = String.split(args)
        rows = number(row_end) - number(row_start) + 1
        columns = number(column_end) - number(column_start) + 1
        count + rows * columns

      _, count ->
        count
    end)
  end

  defp html_decode(value) do
    value
    |> String.replace("&lt;", "<")
    |> String.replace("&gt;", ">")
    |> String.replace("&quot;", "\"")
    |> String.replace("&#x27;", "'")
    |> String.replace("&#39;", "'")
    |> String.replace("&amp;", "&")
    |> String.replace("\r", "")
  end

  defp parse_line(line, state) do
    if noise?(line) do
      state
    else
      case Regex.run(~r/^\s*&(\w+)\s*(.*)$/, line, capture: :all_but_first) do
        ["charset", args] -> start_charset(state, args)
        [keyword, args] -> start_directive(state, keyword, args)
        nil -> append_data(state, line)
      end
    end
  end

  defp start_charset({charsets, current, directive}, args) do
    current = flush_directive(current, directive)
    charsets = flush_charset(charsets, current)
    name = args |> String.split() |> hd()
    {charsets, %{name: name, directives: []}, nil}
  end

  defp start_directive({charsets, current, directive}, keyword, args) do
    current = flush_directive(current, directive)
    {charsets, current, %{keyword: keyword, args: String.trim(args), data: []}}
  end

  defp append_data({charsets, nil, directive}, _line), do: {charsets, nil, directive}
  defp append_data({charsets, current, nil}, _line), do: {charsets, current, nil}

  defp append_data({charsets, current, directive}, line) do
    if directive.keyword in ["code", "code2", "comb2"] do
      data = String.trim(line)

      if data == "",
        do: {charsets, current, directive},
        else: {charsets, current, %{directive | data: [data | directive.data]}}
    else
      {charsets, current, directive}
    end
  end

  defp flush_directive(nil, _directive), do: nil
  defp flush_directive(current, nil), do: current

  defp flush_directive(current, directive) do
    directive = %{directive | data: Enum.reverse(directive.data)}
    %{current | directives: [directive | current.directives]}
  end

  defp flush_charset(charsets, nil), do: charsets

  defp flush_charset(charsets, current) do
    [%{current | directives: Enum.reverse(current.directives)} | charsets]
  end

  defp noise?(line) do
    line == "" or String.contains?(line, "RFC 1345") or
      String.contains?(line, "Simonsen") or String.starts_with?(line, "\f")
  end

  defp aliases(charset) do
    source_aliases =
      for %{keyword: "alias", args: args} <- charset.directives do
        args |> String.split() |> hd()
      end

    case charset.name do
      # ISO-IR-170 registers the invariant 82-character repertoire already
      # represented by RFC 1345's INVARIANT table.
      "INVARIANT" -> ["ISO-IR-170" | source_aliases]
      _ -> source_aliases
    end
  end

  defp build_table(charset, mnemonics, secondary_mappings) do
    bits =
      charset.directives
      |> Enum.find_value(8, fn
        %{keyword: "bits", args: args} -> args |> String.split() |> hd() |> number()
        _ -> nil
      end)

    layout_error = layout_error(charset)
    secondary = Map.get(secondary_mappings, charset.name)

    assignments =
      if layout_error do
        []
      else
        Enum.flat_map(charset.directives, fn
          %{keyword: "code"} = directive -> code_assignments(directive)
          %{keyword: "code2"} = directive -> code2_assignments(directive)
          %{keyword: "codex"} = directive -> codex_assignments(directive)
          _ -> []
        end)
      end

    {decode, encode, mnemonic_bytes, undefined, unresolved} =
      Enum.reduce(assignments, {%{}, %{}, %{}, 0, if(layout_error, do: 256, else: 0)}, fn
        {bytes, mnemonic}, acc ->
          add_assignment(acc, bytes, mnemonic, mnemonics, charset.name, secondary)
      end)

    encode =
      if layout_error do
        encode
      else
        Enum.reduce(charset.directives, encode, fn
          %{keyword: "duplicate", args: args}, encode ->
            [code, mnemonic | _] = String.split(args)

            if mnemonic in @ignored_tokens do
              encode
            else
              codepoint = fetch_mnemonic!(mnemonics, mnemonic, charset.name)
              Map.put_new(encode, {codepoint}, byte_sequence!([number(code)], "&duplicate"))
            end

          _directive, encode ->
            encode
        end)
      end

    {decode, encode, combinations} =
      if layout_error do
        {decode, encode, 0}
      else
        Enum.reduce(charset.directives, {decode, encode, 0}, fn
          %{keyword: "comb2"} = directive, acc ->
            add_combinations(
              acc,
              directive_tokens(directive),
              mnemonic_bytes,
              mnemonics,
              charset.name
            )

          _directive, acc ->
            acc
        end)
      end

    many = Map.reject(decode, fn {bytes, _codepoints} -> byte_size(bytes) == 1 end)

    one =
      0..255
      |> Enum.map(fn byte -> Map.get(decode, <<byte>>) end)
      |> List.to_tuple()

    table = %{
      one: one,
      many: many,
      prefixes: prefix_set(Map.keys(many)),
      encode: encode,
      max_input: decode |> Map.keys() |> Enum.map(&byte_size/1) |> Enum.max(fn -> 1 end),
      max_codepoints: 1
    }

    metadata = %{
      bits: bits,
      decode_mappings: map_size(decode),
      encode_mappings: map_size(encode),
      combinations: combinations,
      duplicate_mappings: Enum.count(charset.directives, &(&1.keyword == "duplicate")),
      errata: charset.errata,
      intentional_undefined_positions: undefined,
      layout_error: layout_error,
      non_roundtrip_encode_mappings: non_roundtrip_encode_mappings(decode, encode),
      unresolved_spec_positions: unresolved
    }

    {table, metadata}
  end

  defp code_assignments(directive) do
    [start | inline] = String.split(directive.args)
    tokens = inline ++ data_tokens(directive)
    start = number(start)

    Enum.with_index(tokens, start)
    |> Enum.map(fn {mnemonic, byte} -> {byte_sequence!([byte], "&code"), mnemonic} end)
  end

  defp layout_error(charset) do
    Enum.find_value(charset.directives, fn
      %{keyword: "code"} = directive ->
        [start | _] = String.split(directive.args)
        count = length(code_assignment_tokens(directive))
        last = number(start) + count - 1
        if last > 255, do: {:code_byte_overflow, last}, else: nil

      _ ->
        nil
    end)
  end

  defp code_assignment_tokens(directive) do
    [_start | inline] = String.split(directive.args)
    inline ++ data_tokens(directive)
  end

  defp code2_assignments(directive) do
    [row, column | inline] = String.split(directive.args)
    row = number(row)
    column = number(column)
    tokens = inline ++ data_tokens(directive)

    Enum.with_index(tokens, column)
    |> Enum.map(fn {mnemonic, current_column} ->
      {byte_sequence!([row + 32, current_column + 32], "&code2"), mnemonic}
    end)
  end

  defp code2_assignment_tokens(directive) do
    [_row, _column | inline] = String.split(directive.args)
    inline ++ data_tokens(directive)
  end

  defp codex_assignments(directive) do
    [prefix, row_start, row_end, column_start, column_end | _] = String.split(directive.args)

    for row <- number(row_start)..number(row_end),
        column <- number(column_start)..number(column_end) do
      mnemonic =
        prefix <>
          String.pad_leading(Integer.to_string(row), 2, "0") <>
          String.pad_leading(Integer.to_string(column), 2, "0")

      {byte_sequence!([row + 32, column + 32], "&codex"), mnemonic}
    end
  end

  defp add_assignment(
         {decode, encode, mnemonic_bytes, undefined, unresolved},
         _bytes,
         mnemonic,
         _map,
         _name,
         _secondary
       )
       when mnemonic in @ignored_tokens do
    {decode, encode, mnemonic_bytes, undefined + 1, unresolved}
  end

  defp add_assignment(
         {decode, encode, mnemonic_bytes, undefined, unresolved},
         bytes,
         mnemonic,
         map,
         name,
         secondary
       ) do
    case Map.fetch(map, mnemonic) do
      {:ok, codepoint} ->
        {
          Map.put_new(decode, bytes, {codepoint}),
          Map.put_new(encode, {codepoint}, bytes),
          Map.put_new(mnemonic_bytes, mnemonic, bytes),
          undefined,
          unresolved
        }

      :error ->
        if String.match?(mnemonic, ~r/^[cjk][0-9]{4}$/i) do
          add_secondary_mapping(
            {decode, encode, mnemonic_bytes, undefined, unresolved},
            bytes,
            secondary
          )
        else
          Mix.raise("unknown mnemonic #{inspect(mnemonic)} in #{name}")
        end
    end
  end

  defp add_secondary_mapping(
         {decode, encode, mnemonic_bytes, undefined, unresolved},
         _bytes,
         nil
       ) do
    {decode, encode, mnemonic_bytes, undefined, unresolved + 1}
  end

  defp add_secondary_mapping(
         {decode, encode, mnemonic_bytes, undefined, unresolved},
         bytes,
         mappings
       ) do
    case Map.fetch(mappings, bytes) do
      {:ok, codepoint} ->
        {
          Map.put_new(decode, bytes, {codepoint}),
          Map.put_new(encode, {codepoint}, bytes),
          mnemonic_bytes,
          undefined,
          unresolved
        }

      :error ->
        {decode, encode, mnemonic_bytes, undefined + 1, unresolved}
    end
  end

  defp add_combinations({decode, encode, count}, [], _bytes, _mnemonics, _name),
    do: {decode, encode, count}

  defp add_combinations({decode, encode, count}, [first | pairs], bytes, mnemonics, name) do
    if rem(length(pairs), 2) != 0 do
      Mix.raise("odd &comb2 token count in #{name}: #{inspect([first | pairs])}")
    end

    first_bytes = Map.fetch!(bytes, first)

    pairs
    |> Enum.chunk_every(2)
    |> Enum.reduce({decode, encode, count}, fn [second, result], {decode, encode, count} ->
      second_bytes = Map.fetch!(bytes, second)
      codepoint = fetch_mnemonic!(mnemonics, result, name)
      sequence = first_bytes <> second_bytes

      {
        Map.put_new(decode, sequence, {codepoint}),
        Map.put_new(encode, {codepoint}, sequence),
        count + 1
      }
    end)
  end

  defp fetch_mnemonic!(mnemonics, mnemonic, charset) do
    case Map.fetch(mnemonics, mnemonic) do
      {:ok, codepoint} -> codepoint
      :error -> Mix.raise("unknown mnemonic #{inspect(mnemonic)} in #{charset}")
    end
  end

  defp data_tokens(directive) do
    directive.data |> Enum.flat_map(&String.split/1)
  end

  defp directive_tokens(directive), do: String.split(directive.args) ++ data_tokens(directive)

  defp number("x" <> value), do: String.to_integer(value, 16)
  defp number("o" <> value), do: String.to_integer(value, 8)
  defp number(value), do: String.to_integer(value)

  defp byte_sequence!(bytes, directive) do
    if Enum.all?(bytes, &(&1 in 0..255)) do
      :erlang.list_to_binary(bytes)
    else
      Mix.raise("#{directive} byte overflow: #{inspect(bytes)}")
    end
  end

  defp prefix_set(binaries) do
    Enum.reduce(binaries, MapSet.new(), fn binary, set ->
      if byte_size(binary) > 1 do
        Enum.reduce(1..(byte_size(binary) - 1), set, fn size, set ->
          MapSet.put(set, binary_part(binary, 0, size))
        end)
      else
        set
      end
    end)
  end

  defp non_roundtrip_encode_mappings(decode, encode) do
    Enum.count(encode, fn {codepoints, bytes} -> Map.get(decode, bytes) != codepoints end)
  end

  defp write_table(output, id, table) do
    File.write!(
      Path.join(output, "#{id}.etf"),
      :erlang.term_to_binary(table, compressed: 9)
    )
  end

  defp write_supported_encodings!(root, manifest) do
    complete = Enum.count(manifest, &(&1.unresolved_spec_positions == 0))
    mappings = Enum.sum(Enum.map(manifest, & &1.decode_mappings))

    rows =
      Enum.map_join(manifest, "\n", fn entry ->
        status =
          if entry.unresolved_spec_positions == 0, do: "complete", else: "quarantined partial"

        aliases = entry.aliases |> Enum.join(", ") |> String.replace("|", "\\|")

        "| `#{entry.name}` | #{aliases} | #{entry.decode_mappings} | " <>
          "#{entry.intentional_undefined_positions} | #{entry.unresolved_spec_positions} | #{status} |"
      end)

    document = """
    # Supported Public-Specification Encodings

    Generated by `tools/import_rfc1345.exs`; do not edit by hand.

    ## Algorithmic codecs

    | Encoding | Aliases | Specification | Repertoire status |
    |---|---|---|---|
    | `BOCU-1` | BOCU1, csBOCU-1 | Unicode Technical Note #6 | all 1,112,064 scalars |
    | `CESU-8` | CESU8, csCESU-8 | Unicode Technical Report #26 | all 1,112,064 scalars |
    | `UTF-7-IMAP` | IMAP-UTF-7, IMAP-MODIFIED-UTF-7 | RFC 3501 §5.1.3 | all 1,112,064 scalars |
    | `JAVA-MODIFIED-UTF-8` | MUTF-8, JAVA-MUTF-8 | Java DataInput/DataOutput | all 1,112,064 scalars |
    | `SCSU` | csSCSU | Unicode Technical Standard #6 | all 1,112,064 scalars |
    | `UTF-EBCDIC` | UTF_EBCDIC, UTFEBCDIC | Unicode Technical Report #16 | all 1,112,064 scalars |
    | `X-USER-DEFINED` | x_user_defined | WHATWG Encoding Standard | complete 256-byte repertoire |

    See `ALGORITHMIC_DIFFERENTIAL.md` for whole-repertoire hashes and ICU
    cross-decoding evidence.

    ## RFC 1345 coded character sets

    - RFC coded character sets catalogued: #{length(manifest)}
    - Complete and registerable: #{complete}
    - Quarantined partial definitions: #{length(manifest) - complete}
    - Concrete decode mappings: #{mappings}
    - RFC combining mappings: #{Enum.sum(Enum.map(manifest, & &1.combinations))}

    “Intentional undefined” means the specification explicitly has `??`/`__` or
    the pinned mapping source leaves the cell unassigned. “Unresolved” means the
    public sources are insufficient or internally malformed; those names are not
    registered with Iconvex.

    | Encoding | RFC aliases | Mappings | Undefined | Unresolved | Status |
    |---|---|---:|---:|---:|---|
    #{rows}
    """

    path = Path.join(root, "SUPPORTED_ENCODINGS.md")
    marker = "## RFC 1345 coded character sets"

    # This importer owns the RFC table, not the independently maintained
    # package inventory, non-octet, packed-profile, and source-audit sections
    # that precede it. Preserve that prefix so rerunning a source importer can
    # never erase unrelated generated evidence.
    document =
      with {:ok, existing} <- File.read(path),
           [prefix, _old_rfc] <- String.split(existing, marker, parts: 2),
           [_generated_prefix, generated_rfc] <- String.split(document, marker, parts: 2) do
        prefix <> marker <> generated_rfc
      else
        _ -> document
      end

    File.write!(path, document)
  end
end

Iconvex.Specs.Tools.ImportRFC1345.run()
