defmodule Iconvex.Specs.Tools.ImportWindowsBestFit do
  @moduledoc false

  @code_pages [
    874,
    932,
    936,
    949,
    950,
    1250,
    1251,
    1252,
    1253,
    1254,
    1255,
    1256,
    1257,
    1258,
    1361
  ]
  @aggregate_sha256 "0a18f4eab7105aa7f5e54fb7dd6a2b9c1f72dd794e2d517a5e502e5c65c7e430"
  @source_root_url "https://www.unicode.org/Public/MAPPINGS/VENDORS/MICSFT/WindowsBestFit"

  def run do
    root = Path.expand("..", __DIR__)
    committed = Path.join([root, "priv", "sources", "windows-best-fit"])
    source_root = System.get_env("WINDOWS_BEST_FIT_SOURCE_DIR") || committed
    assert_source_set!(source_root)
    copy_sources(source_root, committed)
    table_dir = Path.join(root, "priv/tables")
    File.mkdir_p!(table_dir)

    encodings =
      @code_pages
      |> Enum.with_index(1)
      |> Enum.map(&import(&1, committed, table_dir))

    manifest = %{
      aggregate_sha256: @aggregate_sha256,
      encodings: encodings,
      format: 1,
      source_root_url: @source_root_url
    }

    File.write!(
      Path.join(root, "priv/windows_best_fit_manifest.etf"),
      :erlang.term_to_binary(manifest, [:deterministic, :compressed])
    )

    write_support_matrix(root, encodings)
    IO.puts("wrote #{length(encodings)} Microsoft best-fit converter profiles")
  end

  defp assert_source_set!(source_root) do
    digest =
      Enum.reduce(@code_pages, :crypto.hash_init(:sha256), fn code_page, context ->
        file = "bestfit#{code_page}.txt"

        context
        |> :crypto.hash_update(file)
        |> :crypto.hash_update(<<0>>)
        |> :crypto.hash_update(File.read!(Path.join(source_root, file)))
      end)
      |> :crypto.hash_final()
      |> Base.encode16(case: :lower)

    unless digest == @aggregate_sha256,
      do: Mix.raise("Microsoft best-fit source-set SHA-256 mismatch: #{digest}")
  end

  defp copy_sources(source_root, committed) do
    if Path.expand(source_root) != Path.expand(committed) do
      File.mkdir_p!(committed)

      Enum.each(@code_pages, fn code_page ->
        file = "bestfit#{code_page}.txt"
        File.cp!(Path.join(source_root, file), Path.join(committed, file))
      end)
    end
  end

  defp import({code_page, index}, committed, table_dir) do
    file = "bestfit#{code_page}.txt"
    source = File.read!(Path.join(committed, file))
    %{decode: decode_rows, encode: encode_rows} = parse(source)
    decode = reduce_decode(decode_rows)
    encode = reduce_encode(encode_rows)
    id = String.to_atom("windows_best_fit_#{code_page}")
    table = build_table(decode, encode)

    File.write!(
      Path.join(table_dir, "#{id}.etf"),
      :erlang.term_to_binary(table, [:deterministic, :compressed])
    )

    %{
      aliases: ["bestfit#{code_page}", "Windows-Best-Fit-#{code_page}"],
      code_page: code_page,
      decode_duplicates: length(decode_rows) - map_size(decode),
      decode_mappings: map_size(decode),
      encode_duplicates: length(encode_rows) - map_size(encode),
      encode_mappings: map_size(encode),
      id: id,
      index: index,
      max_input: table.max_input,
      name: "WINDOWS-BESTFIT-#{code_page}",
      sha256: sha256(source),
      source_file: file,
      source_url: "#{@source_root_url}/#{file}"
    }
  end

  defp parse(source) do
    source
    |> String.split("\n")
    |> Enum.reduce(%{decode: [], encode: [], state: nil}, fn line, acc ->
      cond do
        String.starts_with?(line, "MBTABLE") ->
          %{acc | state: :mb}

        String.starts_with?(line, "DBCSRANGE") ->
          %{acc | state: nil}

        String.starts_with?(line, "DBCSTABLE") ->
          [lead] = Regex.run(~r/LeadByte\s*=\s*0x([0-9A-Fa-f]+)/, line, capture: :all_but_first)
          %{acc | state: {:dbcs, String.to_integer(lead, 16)}}

        String.starts_with?(line, "WCTABLE") ->
          %{acc | state: :wc}

        true ->
          parse_row(line, acc)
      end
    end)
    |> Map.delete(:state)
    |> Map.update!(:decode, &Enum.reverse/1)
    |> Map.update!(:encode, &Enum.reverse/1)
  end

  defp parse_row(line, %{state: state} = acc) do
    case Regex.run(~r/^0x([0-9A-Fa-f]+)\s+0x([0-9A-Fa-f]+)/, line, capture: :all_but_first) do
      [left, right] ->
        left = String.to_integer(left, 16)
        right = String.to_integer(right, 16)

        case state do
          :mb -> Map.update!(acc, :decode, &[{<<left>>, right} | &1])
          {:dbcs, lead} -> Map.update!(acc, :decode, &[{<<lead, left>>, right} | &1])
          :wc -> Map.update!(acc, :encode, &[{left, encoded_bytes(right)} | &1])
          nil -> acc
        end

      nil ->
        acc
    end
  end

  defp encoded_bytes(value) when value <= 0xFF, do: <<value>>
  defp encoded_bytes(value), do: <<value::16-big>>

  defp reduce_decode(rows),
    do:
      Enum.reduce(rows, %{}, fn {bytes, codepoint}, map ->
        Map.put_new(map, bytes, {codepoint})
      end)

  defp reduce_encode(rows),
    do:
      Enum.reduce(rows, %{}, fn {codepoint, bytes}, map ->
        Map.put_new(map, {codepoint}, bytes)
      end)

  defp build_table(decode, encode) do
    {one, many} =
      Enum.reduce(decode, {%{}, %{}}, fn {bytes, codepoints}, {one, many} ->
        if byte_size(bytes) == 1,
          do: {Map.put(one, :binary.first(bytes), codepoints), many},
          else: {one, Map.put(many, bytes, codepoints)}
      end)

    prefixes =
      Enum.reduce(many, MapSet.new(), fn {bytes, _codepoints}, result ->
        Enum.reduce(1..(byte_size(bytes) - 1), result, fn size, prefixes ->
          MapSet.put(prefixes, binary_part(bytes, 0, size))
        end)
      end)

    %{
      encode: encode,
      many: many,
      max_codepoints: 1,
      max_input: decode |> Map.keys() |> Enum.map(&byte_size/1) |> Enum.max(),
      one: 0..255 |> Enum.map(&Map.get(one, &1)) |> List.to_tuple(),
      prefixes: prefixes
    }
  end

  defp write_support_matrix(root, encodings) do
    header = [
      "# Microsoft best-fit converter profiles",
      "",
      "Pinned from the Unicode Consortium's Microsoft WindowsBestFit archive.",
      "These are explicitly directional converter profiles: MB/DBCS tables define",
      "decoding and WC tables define canonical plus best-fit encoding.",
      "",
      "| Profile | Decode mappings | Encode mappings | Source SHA-256 |",
      "|---|---:|---:|---|"
    ]

    rows =
      Enum.map(encodings, fn entry ->
        "| `#{entry.name}` | #{entry.decode_mappings} | #{entry.encode_mappings} | `#{entry.sha256}` |"
      end)

    File.write!(
      Path.join(root, "WINDOWS_BEST_FIT_ENCODINGS.md"),
      Enum.join(header ++ rows, "\n") <> "\n"
    )
  end

  defp sha256(contents), do: :crypto.hash(:sha256, contents) |> Base.encode16(case: :lower)
end

Iconvex.Specs.Tools.ImportWindowsBestFit.run()
