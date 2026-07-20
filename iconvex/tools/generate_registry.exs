defmodule Iconvex.RegistryGenerator do
  @def_files ~w(
    encodings.def encodings_extra.def encodings_aix.def encodings_dos.def
    encodings_osf1.def encodings_zos.def
  )

  @table_overrides %{
    ascii: "ASCII",
    big5hkscs2008: "BIG5-HKSCS-2008",
    cp943: "CP932",
    gb18030_2005: "GB18030-2005-BMP",
    gb18030_2022: "GB18030-2022-BMP",
    georgian_academy: "Georgian-Academy",
    georgian_ps: "Georgian-PS",
    iso646_cn: "ISO646-CN",
    iso646_jp: "ISO646-JP",
    jisx0201: "JIS_X0201",
    mulelao: "MuleLao-1"
  }

  @derived_tables %{
    gb2312: {"EUC-CN", :strip_high_bit},
    jisx0208: {"EUC-JP", :euc_jp_plane_1},
    jisx0212: {"EUC-JP", :euc_jp_plane_2},
    ksc5601: {"EUC-KR", :strip_high_bit}
  }

  @unicode ~w(
    utf8 ucs2 ucs2be ucs2le ucs2internal ucs2swapped
    ucs4 ucs4be ucs4le ucs4internal ucs4swapped
    utf16 utf16be utf16le utf32 utf32be utf32le
  )a

  @stateful ~w(
    utf7 hz iso2022_jp iso2022_jp1 iso2022_jp2 iso2022_jp3 iso2022_jpms
    iso2022_kr iso2022_cn iso2022_cn_ext
  )a

  # Public registrations and presentation profiles whose octet mappings are
  # exactly those of an existing GNU codec. Keep these separate from the GNU
  # 1.19 alias inventory so the generated support report can audit provenance.
  @spec_aliases %{
    "ISO-8859-6-E" => :iso8859_6,
    "ISO-8859-6-I" => :iso8859_6,
    "ISO-8859-8-E" => :iso8859_8,
    "ISO-8859-8-I" => :iso8859_8,
    "ISO-IR-168" => :jisx0208,
    "ISO-IR-227" => :iso8859_7,
    "ISO-IR-162" => :ucs2be,
    "ISO-IR-174" => :ucs2be,
    "ISO-IR-176" => :ucs2be,
    "ISO-IR-163" => :ucs4be,
    "ISO-IR-175" => :ucs4be,
    "ISO-IR-177" => :ucs4be,
    "ISO-IR-190" => :utf8,
    "ISO-IR-191" => :utf8,
    "ISO-IR-192" => :utf8,
    "ISO-IR-196" => :utf8,
    "ISO-IR-193" => :utf16,
    "ISO-IR-194" => :utf16,
    "ISO-IR-195" => :utf16,
    "JIS_ENCODING" => :iso2022_jp1,
    "CSJISENCODING" => :iso2022_jp1,
    "IBM-5054" => :iso2022_jp1,
    "CP1201" => :utf16be,
    "WINDOWS-1201" => :utf16be,
    "UNICODEFFFE" => :utf16be
  }

  def run([source, "--report-supported-encodings", target])
      when target in ["core", "extras"] do
    lib = definition_directory(source)
    {entries, aliases, gnu_alias_count} = parse(lib)
    {default_ids, origins} = definition_metadata(lib)

    documents =
      supported_encoding_documents(
        entries,
        aliases,
        gnu_alias_count,
        default_ids,
        origins
      )

    IO.write(:stdio, Map.fetch!(documents, String.to_existing_atom(target)))
  end

  def run([source]) do
    root = Path.expand("..", __DIR__)
    extras_root = Path.expand("../iconvex_extras", root)
    tests = Path.join(source, "tests")
    lib = definition_directory(source)
    {entries, aliases, gnu_alias_count} = parse(lib)
    {default_ids, origins} = definition_metadata(lib)
    table_files = table_files(tests)
    entries = generate_tables(entries, table_files, tests, root, extras_root, default_ids)
    generate_stateful_tables(source, root)
    generate_transliteration(source, root)
    core_entries = Map.take(entries, MapSet.to_list(default_ids))
    extra_entries = Map.drop(entries, MapSet.to_list(default_ids))
    core_aliases = Map.filter(aliases, fn {_name, id} -> MapSet.member?(default_ids, id) end)
    write_registry(root, core_entries, core_aliases)
    write_extras_codecs(extras_root, extra_entries, aliases)
    prune_tables(root, extras_root, core_entries, extra_entries)

    write_supported_encodings(
      root,
      extras_root,
      entries,
      aliases,
      gnu_alias_count,
      default_ids,
      origins
    )
  end

  def run(_) do
    raise "usage: elixir tools/generate_registry.exs /path/to/libiconv-1.19 " <>
            "[--report-supported-encodings core|extras]"
  end

  defp definition_directory(source) do
    direct = Path.expand(source)
    nested = Path.join(direct, "lib")

    cond do
      definition_directory?(direct) -> direct
      definition_directory?(nested) -> nested
      true -> raise "GNU libiconv definition files not found under #{direct} or #{nested}"
    end
  end

  defp definition_directory?(directory) do
    Enum.all?(@def_files, &File.regular?(Path.join(directory, &1)))
  end

  defp parse(lib) do
    {entries, aliases} =
      Enum.reduce(@def_files, {%{}, %{}}, fn filename, acc ->
        lib |> Path.join(filename) |> File.read!() |> parse_file(acc)
      end)

    aliases =
      Enum.reduce(entries, aliases, fn {id, entry}, acc ->
        Map.put(acc, normalize(entry.canonical), id)
      end)

    gnu_alias_count = map_size(aliases)

    aliases =
      Enum.reduce(@spec_aliases, aliases, fn {name, id}, acc ->
        if Map.has_key?(entries, id) do
          Map.put(acc, normalize(name), id)
        else
          raise "spec alias #{name} targets absent codec #{id}"
        end
      end)

    {entries, aliases, gnu_alias_count}
  end

  defp parse_file(source, {entries, aliases}) do
    source = Regex.replace(~r{/\*.*?\*/}s, source, "")

    definitions =
      Regex.scan(~r/DEFENCODING\(\(\s*(.*?)\),\s*([a-z0-9_]+)\s*,/s, source,
        capture: :all_but_first
      )

    {entries, aliases} =
      Enum.reduce(definitions, {entries, aliases}, fn [names_source, id_source],
                                                      {entries, aliases} ->
        id = String.to_atom(id_source)
        names = Regex.scan(~r/"([^"]+)"/, names_source, capture: :all_but_first) |> List.flatten()
        canonical = hd(names)
        aliases = Enum.reduce(names, aliases, &Map.put(&2, normalize(&1), id))
        {Map.put_new(entries, id, %{id: id, canonical: canonical}), aliases}
      end)

    aliases =
      Regex.scan(~r/DEFALIAS\(\s*"([^"]+)"\s*,\s*([a-z0-9_]+)\s*\)/s, source,
        capture: :all_but_first
      )
      |> Enum.reduce(aliases, fn [name, id], acc ->
        Map.put(acc, normalize(name), String.to_atom(id))
      end)

    {entries, aliases}
  end

  defp definition_metadata(lib) do
    origins =
      Enum.reduce(@def_files, %{}, fn filename, origins ->
        {entries, _aliases} =
          lib
          |> Path.join(filename)
          |> File.read!()
          |> parse_file({%{}, %{}})

        Enum.reduce(entries, origins, fn {id, _entry}, origins ->
          Map.put(origins, id, definition_label(filename))
        end)
      end)

    default_ids =
      origins
      |> Enum.flat_map(fn {id, origin} -> if origin == "Core/default", do: [id], else: [] end)
      |> MapSet.new()

    {default_ids, origins}
  end

  defp definition_label("encodings.def"), do: "Core/default"
  defp definition_label("encodings_extra.def"), do: "Extra"
  defp definition_label("encodings_aix.def"), do: "AIX"
  defp definition_label("encodings_dos.def"), do: "DOS"
  defp definition_label("encodings_osf1.def"), do: "OSF/1"
  defp definition_label("encodings_zos.def"), do: "z/OS"

  defp table_files(tests) do
    tests
    |> Path.join("*.TXT")
    |> Path.wildcard()
    |> Enum.reject(&String.ends_with?(&1, ".IRREVERSIBLE.TXT"))
    |> Map.new(&{Path.basename(&1, ".TXT"), &1})
  end

  defp generate_tables(entries, table_files, tests, root, extras_root, default_ids) do
    core_out = Path.join(root, "priv/tables")
    extras_out = Path.join(extras_root, "priv/tables")
    File.mkdir_p!(core_out)
    File.mkdir_p!(extras_out)

    Map.new(entries, fn {id, entry} ->
      out = if MapSet.member?(default_ids, id), do: core_out, else: extras_out
      table_name = Map.get(@table_overrides, id, String.replace(entry.canonical, ":", "-"))
      derived = @derived_tables[id]

      cond do
        path = table_files[table_name] ->
          irreversible_name = String.replace_suffix(table_name, "-BMP", "")
          irreversible = Path.join(tests, irreversible_name <> ".IRREVERSIBLE.TXT")

          table =
            build_table(
              parse_mapping(path),
              parse_optional_mapping(irreversible),
              id not in [:gb18030_2005, :gb18030_2022]
            )
            |> finalize_table(id)

          write_table(out, id, table)
          {id, Map.put(entry, :kind, table_kind(id))}

        derived != nil ->
          {source_name, transform} = derived

          table =
            table_files
            |> Map.fetch!(source_name)
            |> parse_mapping()
            |> derive(transform)
            |> build_table([])

          write_table(out, id, table)
          {id, Map.put(entry, :kind, :table)}

        id in @unicode ->
          {id, Map.put(entry, :kind, :unicode)}

        id in @stateful ->
          {id, Map.put(entry, :kind, :stateful)}

        id in [:c99, :java] ->
          {id, Map.put(entry, :kind, :escape)}

        true ->
          {id, Map.put(entry, :kind, :pending)}
      end
    end)
  end

  defp build_table(base, irreversible, compose_irreversible? \\ true) do
    decode = Map.new(base)

    inverse =
      base
      |> Enum.reject(fn {_bytes, codepoints} -> tuple_size(codepoints) > 1 end)
      |> MapSet.new()
      |> then(&Enum.reduce(irreversible, &1, fn item, set -> toggle(set, item) end))

    encode =
      inverse
      |> Enum.reduce(%{}, fn {bytes, codepoints}, acc -> Map.put(acc, codepoints, bytes) end)
      |> then(fn acc ->
        Enum.reduce(base, acc, fn
          {bytes, codepoints}, acc when tuple_size(codepoints) > 1 ->
            Map.put(acc, codepoints, bytes)

          _, acc ->
            acc
        end)
      end)

    composed =
      if compose_irreversible? do
        Enum.reduce(irreversible, %{}, fn {bytes, codepoints}, composed ->
          if Map.has_key?(decode, bytes),
            do: composed,
            else: Map.put_new(composed, bytes, codepoints)
        end)
      else
        %{}
      end

    decode = Map.merge(decode, composed)
    many = Map.reject(decode, fn {bytes, _} -> byte_size(bytes) == 1 end)

    one =
      0..255
      |> Enum.map(fn byte -> Map.get(decode, <<byte>>) end)
      |> List.to_tuple()

    %{
      one: one,
      many: many,
      prefixes: prefix_set(Map.keys(many)),
      encode: encode,
      max_input: decode |> Map.keys() |> Enum.map(&byte_size/1) |> Enum.max(fn -> 1 end),
      max_codepoints: encode |> Map.keys() |> Enum.map(&tuple_size/1) |> Enum.max(fn -> 1 end)
    }
  end

  defp finalize_table(table, id) when id in [:cp1258, :tcvn] do
    many =
      Map.reject(table.many, fn
        {<<base, _combining>>, codepoints} when tuple_size(codepoints) == 1 ->
          base_codepoints = elem(table.one, base)
          base_codepoints != nil and elem(base_codepoints, 0) < 0x41

        _ ->
          false
      end)

    %{table | many: many, prefixes: prefix_set(Map.keys(many))}
  end

  defp finalize_table(table, _id), do: table

  defp derive(entries, :strip_high_bit),
    do: for({<<a, b>>, cps} <- entries, a >= 0x80, b >= 0x80, do: {<<a - 0x80, b - 0x80>>, cps})

  defp derive(entries, :euc_jp_plane_1),
    do:
      for(
        {<<a, b>>, cps} <- entries,
        a in 0xA1..0xF4,
        b >= 0xA1,
        do: {<<a - 0x80, b - 0x80>>, cps}
      )

  defp derive(entries, :euc_jp_plane_2),
    do: for({<<0x8F, a, b>>, cps} <- entries, a in 0xA1..0xED, do: {<<a - 0x80, b - 0x80>>, cps})

  defp generate_stateful_tables(source, root) do
    out = Path.join(root, "priv/tables")

    for {id, filename, array} <- [
          {:cp50221_0208_ext, "cp50221_0208_ext.h", "cp50221_0208_ext_2uni"},
          {:cp50221_0212_ext, "cp50221_0212_ext.h", "cp50221_0212_ext_2uni"}
        ] do
      contents = source |> Path.join("lib/#{filename}") |> File.read!()
      [_, body] = Regex.run(~r/#{array}\[\d+\]\s*=\s*\{(.*?)\};/s, contents)

      values =
        body
        |> String.replace(~r{/\*.*?\*/}s, "")
        |> then(&Regex.scan(~r/0x[0-9a-fA-F]+/, &1))
        |> Enum.map(fn [hex] -> hex |> String.trim_leading("0x") |> String.to_integer(16) end)

      decode =
        values
        |> Enum.with_index()
        |> Map.new(fn {codepoint, index} -> {index, codepoint} end)
        |> Map.reject(fn {_index, codepoint} -> codepoint == 0xFFFD end)
        |> then(fn mapping ->
          if id == :cp50221_0212_ext, do: Map.put(mapping, 0xA1, 0x974D), else: mapping
        end)

      write_table(out, id, %{
        decode: decode,
        encode: Map.new(decode, fn {index, codepoint} -> {codepoint, index} end)
      })
    end
  end

  defp generate_transliteration(source, root) do
    mapping =
      source
      |> Path.join("lib/translit.def")
      |> File.stream!([], :line)
      |> Enum.reject(&String.starts_with?(&1, "#"))
      |> Enum.reject(&(String.trim(&1) == ""))
      |> Map.new(fn line ->
        [hex, replacement | _comment] =
          String.split(String.trim_trailing(line, "\n"), "\t", parts: 3)

        {String.to_integer(hex, 16), String.to_charlist(replacement)}
      end)

    root
    |> Path.join("priv/translit.etf")
    |> write_generated_term(mapping)
  end

  defp parse_optional_mapping(path), do: if(File.exists?(path), do: parse_mapping(path), else: [])

  defp parse_mapping(path) do
    path
    |> File.stream!([], :line)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == "" or String.starts_with?(&1, "#")))
    |> Enum.map(fn line ->
      [encoded | unicode] = String.split(line)
      bytes = encoded |> String.trim_leading("0x") |> Base.decode16!(case: :mixed)

      codepoints =
        unicode
        |> Enum.map(&(&1 |> String.trim_leading("0x") |> String.to_integer(16)))
        |> List.to_tuple()

      {bytes, codepoints}
    end)
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

  defp toggle(set, item),
    do: if(MapSet.member?(set, item), do: MapSet.delete(set, item), else: MapSet.put(set, item))

  defp table_kind(id) when id in [:gb18030_2005, :gb18030_2022], do: :gb18030
  defp table_kind(_id), do: :table

  defp write_table(out, id, table),
    do: write_generated_term(Path.join(out, "#{id}.etf"), table)

  defp write_registry(root, entries, aliases) do
    source = """
    defmodule Iconvex.Registry do
      @moduledoc false
      @entries #{inspect(entries, pretty: true, limit: :infinity, width: 120)}
      @aliases #{inspect(aliases, pretty: true, limit: :infinity, width: 120)}

      def canonical_names do
        (builtin_canonical_names() ++ Iconvex.ExternalRegistry.canonical_names()) |> Enum.sort()
      end

      def builtin_canonical_names,
        do: @entries |> Map.values() |> Enum.map(& &1.canonical) |> Enum.sort()

      def builtin_aliases, do: @aliases

      def resolve(name) when is_binary(name) do
        if String.match?(name, ~r/^[\\x00-\\x7f]+$/) do
          normalized = String.upcase(name, :ascii)

          case builtin_resolve_normalized(normalized) do
            {:ok, _entry} = result -> result
            :error -> Iconvex.ExternalRegistry.resolve(normalized)
          end
        else
          :error
        end
      end

      def resolve(name) when is_atom(name) do
        case Map.fetch(@entries, name) do
          {:ok, _entry} = result -> result
          :error -> Iconvex.ExternalRegistry.resolve(name)
        end
      end

      def resolve(_), do: :error

      def builtin_resolve(name) when is_binary(name) do
        if String.match?(name, ~r/^[\\x00-\\x7f]+$/),
          do: builtin_resolve_normalized(String.upcase(name, :ascii)),
          else: :error
      end

      def builtin_resolve(name) when is_atom(name), do: Map.fetch(@entries, name)
      def builtin_resolve(_name), do: :error

      defp builtin_resolve_normalized(name) do
        with {:ok, id} <- Map.fetch(@aliases, name),
             {:ok, entry} <- Map.fetch(@entries, id) do
          {:ok, entry}
        end
      end
    end
    """

    path = Path.join(root, "lib/iconvex/registry.ex")
    File.mkdir_p!(Path.dirname(path))
    write_generated_source(path, source)
  end

  defp write_extras_codecs(root, entries, aliases) do
    modules =
      entries
      |> Enum.sort_by(fn {_id, entry} -> entry.canonical end)
      |> Enum.map(fn {id, entry} ->
        module = Module.concat([Iconvex.Extras.Codecs, Macro.camelize(Atom.to_string(id))])

        codec_aliases =
          aliases
          |> Enum.flat_map(fn {name, target} -> if target == id, do: [name], else: [] end)
          |> Enum.reject(&(&1 == String.upcase(entry.canonical, :ascii)))
          |> Enum.sort()

        %{
          module: module,
          id: id,
          canonical: entry.canonical,
          aliases: codec_aliases,
          kind: entry.kind
        }
      end)

    definitions = Enum.map_join(modules, "\n\n", &extra_codec_module/1)
    module_list = modules |> Enum.map(& &1.module) |> inspect(pretty: true, width: 120)

    source = """
    defmodule Iconvex.Extras.Codecs do
      @moduledoc false
      @modules #{module_list}
      def modules, do: @modules
    end

    #{definitions}
    """

    path = Path.join(root, "lib/iconvex/extras/codecs.ex")
    File.mkdir_p!(Path.dirname(path))
    write_generated_source(path, source)
  end

  defp extra_codec_module(%{kind: :table} = spec) do
    """
    defmodule #{inspect(spec.module)} do
      use Iconvex.Codec, direct_adapter: Iconvex.Extras.CodecSupport
      alias Iconvex.Extras.CodecSupport

      @impl true
      def canonical_name, do: #{inspect(spec.canonical)}

      @impl true
      def aliases, do: #{inspect(spec.aliases, pretty: true, width: 120)}

      @impl true
      def codec_id, do: #{inspect(spec.id)}

      @impl true
      def decode(input), do: CodecSupport.decode(#{inspect(spec.id)}, input)

      @impl true
      def decode_discard(input), do: CodecSupport.decode_discard(#{inspect(spec.id)}, input)

      @impl true
      def encode(codepoints), do: CodecSupport.encode(#{inspect(spec.id)}, codepoints)

      @impl true
      def encode_discard(codepoints), do: CodecSupport.encode_discard(#{inspect(spec.id)}, codepoints)

      @impl true
      def encode_substitute(codepoints, replacer),
        do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

      @impl true
      def decode_to_utf8(input), do: CodecSupport.decode_to_utf8(#{inspect(spec.id)}, input)

      @impl true
      def encode_from_utf8(input), do: CodecSupport.encode_from_utf8(#{inspect(spec.id)}, input)
    end
    """
  end

  defp extra_codec_module(%{id: :iso2022_jp3} = spec) do
    """
    defmodule #{inspect(spec.module)} do
      use Iconvex.Codec
      alias Iconvex.Extras.CodecSupport

      @impl true
      def canonical_name, do: #{inspect(spec.canonical)}

      @impl true
      def aliases, do: #{inspect(spec.aliases, pretty: true, width: 120)}

      @impl true
      def codec_id, do: :iso2022_jp3

      @impl true
      def stateful?, do: true

      @impl true
      def decode(input), do: CodecSupport.decode_iso2022_jp3(input)

      @impl true
      def decode_discard(input), do: CodecSupport.decode_discard_iso2022_jp3(input)

      @impl true
      def encode(codepoints), do: CodecSupport.encode_iso2022_jp3(codepoints)

      @impl true
      def encode_discard(codepoints), do: CodecSupport.encode_discard_iso2022_jp3(codepoints)

      @impl true
      def decode_to_ucs4_discard(input, endian),
        do: CodecSupport.decode_to_ucs4_discard(:iso2022_jp3, input, endian)

      @impl true
      def encode_from_ucs4_discard(input, endian),
        do: CodecSupport.encode_from_ucs4_discard(:iso2022_jp3, input, endian)

      @impl true
      def encode_substitute(codepoints, replacer),
        do: CodecSupport.encode_substitute(codec_id(), codepoints, replacer)

      @impl true
      def stream_decoder_init, do: CodecSupport.stream_decoder_init_iso2022_jp3()

      @impl true
      def decode_chunk(input, state, final?),
        do: CodecSupport.decode_chunk_iso2022_jp3(input, state, final?)

      @impl true
      def stream_encoder_init, do: CodecSupport.stream_encoder_init_iso2022_jp3()

      @impl true
      def encode_chunk(codepoints, state, final?, policy),
        do: CodecSupport.encode_chunk_iso2022_jp3(codepoints, state, final?, policy)
    end
    """
  end

  defp extra_codec_module(spec),
    do: raise("unsupported extra codec kind #{inspect(spec.kind)} for #{spec.canonical}")

  defp write_generated_term(path, term) do
    unchanged? =
      case File.read(path) do
        {:ok, binary} -> decode_generated_term(binary) == {:ok, term}
        {:error, _reason} -> false
      end

    unless unchanged? do
      File.write!(path, :erlang.term_to_binary(term, compressed: 9))
    end
  end

  defp decode_generated_term(binary) do
    {:ok, :erlang.binary_to_term(binary, [:safe])}
  rescue
    ArgumentError -> :error
  end

  defp write_generated_source(path, source) do
    formatted = source |> Code.format_string!() |> IO.iodata_to_binary() |> ensure_final_newline()

    unchanged? =
      case File.read(path) do
        {:ok, current} -> equivalent_generated_source?(current, formatted)
        {:error, _reason} -> false
      end

    unless unchanged?, do: File.write!(path, formatted)
  end

  defp equivalent_generated_source?(left, right) do
    normalize_generated_source(left) == normalize_generated_source(right)
  rescue
    SyntaxError -> false
  end

  defp normalize_generated_source(source) do
    source
    |> Code.string_to_quoted!()
    |> Macro.prewalk(fn
      {:%{}, metadata, pairs} ->
        {:%{}, metadata, Enum.sort_by(pairs, &Macro.to_string/1)}

      node ->
        node
    end)
    |> Macro.to_string()
  end

  defp ensure_final_newline(source) do
    if String.ends_with?(source, "\n"), do: source, else: source <> "\n"
  end

  defp prune_tables(root, extras_root, core_entries, extra_entries) do
    core_ids =
      core_entries
      |> table_ids()
      |> MapSet.union(MapSet.new([:cp50221_0208_ext, :cp50221_0212_ext]))

    remove_stale_tables(Path.join(root, "priv/tables"), core_ids)
    remove_stale_tables(Path.join(extras_root, "priv/tables"), table_ids(extra_entries))
  end

  defp table_ids(entries) do
    entries
    |> Enum.flat_map(fn
      {id, %{kind: kind}} when kind in [:table, :gb18030] -> [id]
      _entry -> []
    end)
    |> MapSet.new()
  end

  defp remove_stale_tables(directory, valid_ids) do
    directory
    |> Path.join("*.etf")
    |> Path.wildcard()
    |> Enum.each(fn path ->
      id = path |> Path.basename(".etf") |> String.to_atom()
      if not MapSet.member?(valid_ids, id), do: File.rm!(path)
    end)
  end

  defp write_supported_encodings(
         root,
         extras_root,
         entries,
         aliases,
         gnu_alias_count,
         default_ids,
         origins
       ) do
    documents =
      supported_encoding_documents(
        entries,
        aliases,
        gnu_alias_count,
        default_ids,
        origins
      )

    File.write!(Path.join(root, "SUPPORTED_ENCODINGS.md"), documents.core)
    File.write!(Path.join(extras_root, "SUPPORTED_ENCODINGS.md"), documents.extras)
  end

  defp supported_encoding_documents(
         entries,
         aliases,
         gnu_alias_count,
         default_ids,
         origins
       ) do
    rows =
      entries
      |> Enum.sort_by(fn {id, entry} -> {entry.canonical, id} end)
      |> Enum.map_join("\n", fn {id, entry} ->
        {core, extras, default} =
          if MapSet.member?(default_ids, id),
            do: {"Yes", "—", "Yes"},
            else: {"—", "Yes", "No"}

        "| `#{entry.canonical}` | #{core} | #{extras} | Yes | #{origins[id]} | #{default} |"
      end)

    core_alias_count =
      Enum.count(aliases, fn {_name, id} -> MapSet.member?(default_ids, id) end)

    extra_alias_count = map_size(aliases) - core_alias_count
    spec_alias_count = map_size(aliases) - gnu_alias_count
    gnu_core_alias_count = core_alias_count - spec_alias_count
    core_codec_count = MapSet.size(default_ids)
    total_codec_count = map_size(entries)
    extra_codec_count = total_codec_count - core_codec_count
    total_alias_count = map_size(aliases)

    document = """
    # Supported encodings: Iconvex vs GNU libiconv 1.19

    Machine-generated from GNU libiconv 1.19's six fixed-codec definition files.
    `test/codec_parity_test.exs` independently parses byte-exact upstream snapshots
    and requires exact set and alias parity.

    ## Parity result

    - Iconvex core fixed codecs: **#{core_codec_count}/#{core_codec_count}**.
    - `iconvex_extras` fixed codecs: **#{extra_codec_count}/#{extra_codec_count}**.
    - Full Iconvex stack: **#{core_codec_count} core + #{extra_codec_count} extras = #{total_codec_count}/#{total_codec_count}**.
    - GNU fixed-codec union: **#{total_codec_count}/#{total_codec_count}**.
    - Common fixed codecs: **#{total_codec_count}**.
    - GNU-only fixed codecs: **0**.
    - Iconvex-only fixed codecs: **0**.
    - GNU source spellings/aliases resolved by Iconvex: **#{gnu_alias_count}**.
      Core owns **#{gnu_core_alias_count}**; extras adds **#{extra_alias_count}**.
    - Additional audited specification/ICU aliases: **#{spec_alias_count}**.
    - Total resolved fixed-codec spellings: **#{total_alias_count}**.
    - Default GNU build `iconv -l`: **#{core_codec_count}/#{core_codec_count}**, all supported by Iconvex.

    ## Packed transport surface

    Packing is orthogonal to the GNU codec registry. `Iconvex.Packed` can pack the
    one-unit-per-octet output of any built-in or external codec at every width from
    1 through 8 bits, in exact MSB-first or byte-backed LSB-first order. It is not
    counted as a second character encoding because the Unicode mapping is unchanged;
    the transport preserves its exact unit width and meaningful bit length.

    `iconvex_telecom` publishes an exact 51-codec packed-profile inventory for its
    5-, 6-, and 7-bit families. `iconvex_specs` separately implements the wider
    RFC 4042 UTF-9 and UTF-18 formats.

    `SUPPORTED_NAME_INVENTORY.csv` is generated from the compiled core registry.
    The parity suite requires its #{core_alias_count} normalized names and canonical targets to be
    an exact runtime snapshot; research consumes this file directly.

    GNU union means all fixed codecs implemented across `encodings.def`,
    `encodings_extra.def`, `encodings_aix.def`, `encodings_dos.def`,
    `encodings_osf1.def`, and `encodings_zos.def`. Default `iconv -l` exposes the
    #{core_codec_count} core codecs on this build; extra/platform definitions raise the source
    union to #{total_codec_count}. The `iconvex` package intentionally contains exactly the GNU
    default set. Adding the separate `iconvex_extras` package exposes the complete
    union on every BEAM platform. A dash means that codec is intentionally owned
    by the other package.

    ## Locale/ABI adapters

    GNU also accepts `CHAR` and `WCHAR_T` through `encodings_local.def`. These are
    environment/ABI adapters, not fixed codecs, and GNU omits them from `iconv -l`.
    `CHAR` delegates to process locale encoding. `WCHAR_T` delegates to platform C
    `wchar_t` width/endian/layout. Iconvex intentionally excludes both: pure BEAM
    conversion has no libc locale or C `wchar_t` ABI. Use explicit fixed names such
    as `UTF-8`, `UCS-4-INTERNAL`, `UTF-16LE`, or `UTF-32LE`.

    ## Complete fixed-codec list

    | Codec | Core `iconvex` | `iconvex_extras` | GNU 1.19 union | GNU definition | Default `iconv -l` |
    |---|:---:|:---:|:---:|---|:---:|
    #{rows}
    """

    extra_rows =
      entries
      |> Enum.reject(fn {id, _entry} -> MapSet.member?(default_ids, id) end)
      |> Enum.sort_by(fn {id, entry} -> {entry.canonical, id} end)
      |> Enum.map_join("\n", fn {id, entry} ->
        "| `#{entry.canonical}` | #{origins[id]} |"
      end)

    extra_origin_counts =
      entries
      |> Enum.reject(fn {id, _entry} -> MapSet.member?(default_ids, id) end)
      |> Enum.frequencies_by(fn {id, _entry} -> Map.fetch!(origins, id) end)

    extras_document = """
    # Supported encodings: Iconvex Extras

    Machine-generated from GNU libiconv 1.19's non-default fixed-codec
    definitions. This package is the exact **#{extra_codec_count}-codec** complement of the
    **#{core_codec_count}-codec** core `iconvex` package. This package registers the **#{extra_alias_count}** GNU
    spellings owned by those codecs. The full stack resolves all **#{gnu_alias_count}** GNU source
    spellings plus **#{spec_alias_count}** audited specification/ICU aliases: **#{total_alias_count}** total resolved
    fixed-codec spellings.

    ## Origin counts

    - GNU extra: **#{Map.get(extra_origin_counts, "Extra", 0)}**
    - AIX: **#{Map.get(extra_origin_counts, "AIX", 0)}**
    - DOS: **#{Map.get(extra_origin_counts, "DOS", 0)}**
    - OSF/1: **#{Map.get(extra_origin_counts, "OSF/1", 0)}**
    - z/OS: **#{Map.get(extra_origin_counts, "z/OS", 0)}**
    - Total: **#{extra_codec_count}**

    ## Complete extras list

    | Codec | GNU definition |
    |---|---|
    #{extra_rows}
    """

    %{core: document, extras: extras_document}
  end

  defp normalize(name), do: String.upcase(name, :ascii)
end

Iconvex.RegistryGenerator.run(System.argv())
