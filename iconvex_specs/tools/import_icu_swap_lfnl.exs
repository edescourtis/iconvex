defmodule Iconvex.Specs.Tools.ImportICUSwapLFNL do
  @moduledoc false

  @revision "21d1eb0f306e1141c10931e914dfc038c06121da"
  @release "78.3"
  @convrtrs_sha256 "29340d12f664416d51c9b9d8d34e6364a10b456e668eb3155fd5f59beaf743e9"

  @variants [
    {"ibm-37_P100-1995", ["ibm-37-s390", "ibm037-s390"]},
    {"ibm-924_P100-1998", ["ibm-924-s390", "IBM924_LF"]},
    {"ibm-1047_P100-1995", ["ibm-1047-s390", "IBM1047_LF"]},
    {"ibm-1140_P100-1997", ["ibm-1140-s390"]},
    {"ibm-1141_P100-1997", ["ibm-1141-s390", "IBM1141_LF"]},
    {"ibm-1142_P100-1997", ["ibm-1142-s390"]},
    {"ibm-1143_P100-1997", ["ibm-1143-s390"]},
    {"ibm-1144_P100-1997", ["ibm-1144-s390"]},
    {"ibm-1145_P100-1997", ["ibm-1145-s390"]},
    {"ibm-1146_P100-1997", ["ibm-1146-s390"]},
    {"ibm-1147_P100-1997", ["ibm-1147-s390"]},
    {"ibm-1148_P100-1997", ["ibm-1148-s390"]},
    {"ibm-1149_P100-1997", ["ibm-1149-s390"]},
    {"ibm-1153_P100-1999", ["ibm-1153-s390"]},
    {"ibm-12712_P100-1998", ["ibm-12712-s390"]},
    {"ibm-16804_X110-1999", ["ibm-16804-s390"]}
  ]

  def run do
    root = Path.expand("..", __DIR__)
    convrtrs_path = Path.join(root, "priv/sources/icu-#{@release}/convrtrs.txt")
    convrtrs = File.read!(convrtrs_path)
    assert_sha256!(convrtrs, @convrtrs_sha256, "convrtrs.txt")
    assert_alias_rows!(convrtrs)

    current = read_manifest(root, "icu_ucm_manifest.etf").encodings
    archive = read_manifest(root, "icu_archive_manifest.etf").encodings
    table_dir = Path.join(root, "priv/tables")

    encodings =
      @variants
      |> Enum.with_index(1)
      |> Enum.map(fn {{base_name, aliases}, index} ->
        base = find_base!(base_name, current, archive)
        base_table = read_table!(table_dir, base.id)
        {lf_byte, nl_byte, table} = swap_lf_nl!(base_name, base_table)
        id = String.to_atom("icu_swap_lfnl_#{index}")
        write_table!(table_dir, id, table)

        %{
          aliases: aliases,
          base_id: base.id,
          base_name: base_name,
          decode_mappings: tuple_size(base_table.one),
          encode_mappings: map_size(base_table.encode),
          id: id,
          index: index,
          lf_byte: lf_byte,
          name: base_name <> ",swaplfnl",
          nl_byte: nl_byte,
          source_file: base.source_file,
          source_sha256: base.sha256
        }
      end)

    aggregate_sha256 = aggregate_sha256(convrtrs, encodings, root)

    manifest = %{
      aggregate_sha256: aggregate_sha256,
      convrtrs_sha256: @convrtrs_sha256,
      encodings: encodings,
      format: 1,
      release: @release,
      revision: @revision,
      source_url:
        "https://github.com/unicode-org/icu/blob/#{@revision}/icu4c/source/data/mappings/convrtrs.txt"
    }

    File.write!(
      Path.join(root, "priv/icu_swap_lfnl_manifest.etf"),
      :erlang.term_to_binary(manifest, [:deterministic])
    )

    write_support_matrix(root, manifest)
    IO.puts("wrote #{length(encodings)} ICU swaplfnl codecs (#{aggregate_sha256})")
  end

  defp find_base!(name, current, archive) do
    Enum.find(current, &(&1.name == name)) ||
      Enum.find(archive, &(&1.source_name == name)) ||
      raise "missing base mapping #{name}"
  end

  defp swap_lf_nl!(name, table) do
    lf_index = find_unique_byte!(table.one, {0x0A}, name)
    nl_index = find_unique_byte!(table.one, {0x85}, name)
    lf_byte = <<nl_index>>
    nl_byte = <<lf_index>>

    one =
      table.one
      |> put_elem(nl_index, {0x0A})
      |> put_elem(lf_index, {0x85})

    encode =
      table.encode
      |> Map.put({0x0A}, lf_byte)
      |> Map.put({0x85}, nl_byte)

    {lf_byte, nl_byte, %{table | one: one, encode: encode}}
  end

  defp find_unique_byte!(one, codepoints, name) do
    bytes =
      one
      |> Tuple.to_list()
      |> Enum.with_index()
      |> Enum.filter(fn {mapped, _byte} -> mapped == codepoints end)
      |> Enum.map(&elem(&1, 1))

    case bytes do
      [byte] -> byte
      _ -> raise "#{name}: expected one byte for #{inspect(codepoints)}, got #{inspect(bytes)}"
    end
  end

  defp assert_alias_rows!(source) do
    for {name, aliases} <- @variants do
      row =
        source
        |> String.split("\n")
        |> Enum.find(&String.starts_with?(&1, name <> ",swaplfnl"))

      unless row && Enum.all?(aliases, &String.contains?(row, &1)) do
        raise "missing ICU alias declaration for #{name}: #{inspect(aliases)}"
      end
    end
  end

  defp aggregate_sha256(convrtrs, encodings, root) do
    encodings
    |> Enum.reduce(:crypto.hash_update(:crypto.hash_init(:sha256), convrtrs), fn entry, hash ->
      source_root =
        if String.starts_with?(Atom.to_string(entry.base_id), "icu_archive_") do
          "icu-data-archive"
        else
          "icu-#{@release}"
        end

      source = File.read!(Path.join([root, "priv/sources", source_root, entry.source_file]))

      hash
      |> :crypto.hash_update(entry.name)
      |> :crypto.hash_update(<<0>>)
      |> :crypto.hash_update(source)
    end)
    |> :crypto.hash_final()
    |> Base.encode16(case: :lower)
  end

  defp write_support_matrix(root, manifest) do
    header = [
      "# ICU `swaplfnl` EBCDIC converter revisions",
      "",
      "Generated from ICU #{manifest.release} `convrtrs.txt` at revision",
      "`#{manifest.revision}`. The option exchanges the EBCDIC byte positions",
      "for Unicode LF (U+000A) and NL (U+0085), matching ICU's S/390 mode.",
      "",
      "Aggregate source SHA-256: `#{manifest.aggregate_sha256}`.",
      "",
      "| Canonical encoding | Aliases | LF byte | NL byte | Base source |",
      "|---|---|---:|---:|---|"
    ]

    rows =
      Enum.map(manifest.encodings, fn entry ->
        "| `#{entry.name}` | #{Enum.map_join(entry.aliases, ", ", &"`#{&1}`")} | " <>
          "`#{Base.encode16(entry.lf_byte)}` | `#{Base.encode16(entry.nl_byte)}` | " <>
          "`#{entry.source_file}` (`#{entry.source_sha256}`) |"
      end)

    File.write!(
      Path.join(root, "ICU_SWAP_LFNL_ENCODINGS.md"),
      Enum.join(header ++ rows, "\n") <> "\n"
    )
  end

  defp read_manifest(root, file),
    do: root |> Path.join("priv/#{file}") |> File.read!() |> :erlang.binary_to_term()

  defp read_table!(dir, id),
    do: dir |> Path.join("#{id}.etf") |> File.read!() |> :erlang.binary_to_term()

  defp write_table!(dir, id, table),
    do: File.write!(Path.join(dir, "#{id}.etf"), :erlang.term_to_binary(table, [:deterministic]))

  defp assert_sha256!(contents, expected, label) do
    actual = :crypto.hash(:sha256, contents) |> Base.encode16(case: :lower)
    unless actual == expected, do: raise("#{label} SHA-256 mismatch: #{actual}")
  end
end

Iconvex.Specs.Tools.ImportICUSwapLFNL.run()
