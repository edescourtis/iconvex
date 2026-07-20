defmodule Iconvex.Specs.Tools.ImportLegacyComputingN5028 do
  @moduledoc false

  @proposal_url "https://www.unicode.org/wg2/docs/n5028-19025-terminals-prop.pdf"
  @proposal_sha256 "e64a54b4b223b5e6a9d686a7a7ddd1fc98d0bc88585059be02078b082a760e61"
  @mapping_aggregate "db0d977777647f236d685df6043a784b5d5325e6f780b08167fba3138e9edc84"

  @canonical_names %{
    "ADAMOS7" => "COLECO-ADAM-OS7",
    "ADAMSWTR" => "COLECO-ADAM-SMARTWRITER",
    "AMSCPC" => "AMSTRAD-CPC",
    "AMSCPM" => "AMSTRAD-CPM-PLUS",
    "APL2ALT1" => "APPLE-II-ALTERNATE-1-VIDEO",
    "APL2ALT2" => "APPLE-II-ALTERNATE-2-VIDEO",
    "APL2ICHG" => "APPLE-II-INTERCHANGE",
    "APL2PRIM" => "APPLE-II-PRIMARY-VIDEO",
    "ATARI8IG" => "ATASCII-GRAPHICS-INTERCHANGE",
    "ATARI8II" => "ATASCII-INTERNATIONAL-INTERCHANGE",
    "ATARI8VG" => "ATASCII-GRAPHICS-VIDEO",
    "ATARI8VI" => "ATASCII-INTERNATIONAL-VIDEO",
    "ATARISTI" => "ATARI-ST-INTERCHANGE",
    "ATARISTV" => "ATARI-ST-VIDEO",
    "C64IALT" => "PETSCII-C64-ALTERNATE-INTERCHANGE",
    "C64IPRI" => "PETSCII-C64-PRIMARY-INTERCHANGE",
    "C64VALT" => "PETSCII-C64-ALTERNATE-VIDEO",
    "C64VPRI" => "PETSCII-C64-PRIMARY-VIDEO",
    "COCOICHG" => "TRS-80-COCO-SEMIGRAPHICS4-INTERCHANGE",
    "COCOSGR4" => "TRS-80-COCO-SEMIGRAPHICS4-VIDEO",
    "COCOSGR6" => "TRS-80-COCO-SEMIGRAPHICS6-VIDEO",
    "CPETIALT" => "PETSCII-PET-ALTERNATE-INTERCHANGE",
    "CPETIPRI" => "PETSCII-PET-PRIMARY-INTERCHANGE",
    "CPETVALT" => "PETSCII-PET-ALTERNATE-VIDEO",
    "CPETVPRI" => "PETSCII-PET-PRIMARY-VIDEO",
    "CVICIALT" => "PETSCII-VIC20-ALTERNATE-INTERCHANGE",
    "CVICIPRI" => "PETSCII-VIC20-PRIMARY-INTERCHANGE",
    "CVICVALT" => "PETSCII-VIC20-ALTERNATE-VIDEO",
    "CVICVPRI" => "PETSCII-VIC20-PRIMARY-VIDEO",
    "IBMPCICH" => "CP437-N5028-INTERCHANGE",
    "IBMPCVID" => "CP437-N5028-VIDEO",
    "MINITLG0" => "MINITEL-G0",
    "MINITLG1" => "MINITEL-G1",
    "MSX" => "MSX-INTERNATIONAL",
    "ORICG0" => "ORICSCII-G0",
    "ORICG1" => "ORICSCII-G1",
    "RISCEFF" => "RISC-OS-EFF-LATIN1",
    "RISCOSB" => "RISC-OS-BFONT",
    "RISCOSI" => "RISC-OS-LATIN1-INTERCHANGE",
    "RISCOSV" => "RISC-OS-LATIN1-VIDEO",
    "SINCLRQL" => "SINCLAIR-QL",
    "TELTXTG0" => "TELETEXT-G0",
    "TELTXTG1" => "TELETEXT-G1",
    "TELTXTG2" => "TELETEXT-G2",
    "TELTXTG3" => "TELETEXT-G3",
    "TI994A" => "TI-99-4A",
    "TRSM1ICH" => "TRS-80-MODEL-I-INTERCHANGE",
    "TRSM1ORG" => "TRS-80-MODEL-I-ORIGINAL-VIDEO",
    "TRSM1REV" => "TRS-80-MODEL-I-REVISED-VIDEO",
    "TRSM3IIN" => "TRS-80-MODEL-III-INTERNATIONAL-INTERCHANGE",
    "TRSM3IJP" => "TRS-80-MODEL-III-KATAKANA-INTERCHANGE",
    "TRSM3IRV" => "TRS-80-MODEL-III-REVERSE-INTERCHANGE",
    "TRSM3VIN" => "TRS-80-MODEL-III-INTERNATIONAL-VIDEO",
    "TRSM3VJP" => "TRS-80-MODEL-III-KATAKANA-VIDEO",
    "TRSM3VRV" => "TRS-80-MODEL-III-REVERSE-VIDEO",
    "TRSM4AIA" => "TRS-80-MODEL-4A-ALTERNATE-INTERCHANGE",
    "TRSM4AIP" => "TRS-80-MODEL-4A-PRIMARY-INTERCHANGE",
    "TRSM4AIR" => "TRS-80-MODEL-4A-REVERSE-INTERCHANGE",
    "TRSM4AVA" => "TRS-80-MODEL-4A-ALTERNATE-VIDEO",
    "TRSM4AVP" => "TRS-80-MODEL-4A-PRIMARY-VIDEO",
    "TRSM4AVR" => "TRS-80-MODEL-4A-REVERSE-VIDEO",
    "ZX80" => "ZX80",
    "ZX81" => "ZX81",
    "ZXDESKTP" => "ZX-SPECTRUM-DESKTOP",
    "ZXFZXKOI" => "ZX-SPECTRUM-FZX-KOI8",
    "ZXFZXLT1" => "ZX-SPECTRUM-FZX-LATIN1",
    "ZXFZXLT5" => "ZX-SPECTRUM-FZX-LATIN5",
    "ZXFZXPUA" => "ZX-SPECTRUM-FZX-PUA",
    "ZXFZXSLT" => "ZX-SPECTRUM-FZX-CP1252",
    "ZXSPCTRM" => "ZX-SPECTRUM"
  }

  @special_aliases %{
    "AMSCPM" => ["ZX-SPECTRUM-PLUS3", "AMSTRAD-PCW"],
    "APL2ICHG" => ["APPLE-II"],
    "ATARI8IG" => ["ATASCII", "ATARI-ASCII", "ATASCII-CHR"],
    "C64IPRI" => ["PETSCII", "PETSCII-C64", "COMMODORE-64-PETSCII"],
    "MSX" => ["MSX", "MSX-CHARSET"],
    "TRSM1ICH" => ["TRS-80", "TRS-80-MODEL-I"],
    "ZX80" => ["ZX80-CHARSET"],
    "ZX81" => ["ZX81-CHARSET"],
    "ZXSPCTRM" => ["ZX-SPECTRUM-CHARSET"]
  }

  def run do
    root = Path.expand("..", __DIR__)
    proposal = proposal_path(root)
    assert_hash!(proposal, @proposal_sha256, "N5028 proposal")
    attachments = attachment_directory(root, proposal)
    source_dir = Path.join([root, "priv", "sources", "wg2-n5028"])
    table_dir = Path.join(root, "priv/tables")
    File.mkdir_p!(source_dir)
    File.mkdir_p!(table_dir)

    mapping_paths = Path.wildcard(Path.join(attachments, "*.TXT")) |> Enum.sort()
    unless length(mapping_paths) == 70, do: raise("expected 70 N5028 mapping attachments")
    assert_aggregate!(mapping_paths)

    readme = Path.join(attachments, "ReadMe.txt")
    File.write!(Path.join(source_dir, "ReadMe.txt"), File.read!(readme))

    entries =
      mapping_paths
      |> Enum.with_index(1)
      |> Enum.map(fn {path, index} -> import_mapping(path, index, source_dir, table_dir) end)

    sources =
      [readme | mapping_paths]
      |> Enum.map(fn path ->
        %{file: Path.basename(path), sha256: sha256(File.read!(path))}
      end)
      |> Enum.sort_by(& &1.file)

    manifest = %{
      attachment_count: 72,
      document: "WG2 N5028 / L2/19-025",
      encodings: entries,
      mapping_aggregate_sha256: @mapping_aggregate,
      proposal_sha256: @proposal_sha256,
      proposal_url: @proposal_url,
      sources: sources
    }

    File.write!(
      Path.join(root, "priv/legacy_computing_n5028_manifest.etf"),
      :erlang.term_to_binary(manifest, [:deterministic])
    )

    write_support_matrix(root, entries)

    IO.puts("wrote #{length(entries)} N5028 codecs from #{length(mapping_paths)} mappings")
  end

  defp write_support_matrix(root, entries) do
    rows =
      Enum.map_join(entries, "\n", fn entry ->
        aliases = Enum.map_join(entry.aliases, ", ", &"`#{&1}`")

        "| `#{entry.name}` | #{aliases} | `#{entry.source_file}` | " <>
          "#{entry.decode_mappings} | #{entry.encode_mappings} |"
      end)

    document = """
    # Unicode/WG2 N5028 Legacy Computing Encodings

    Generated by `tools/import_legacy_computing_n5028.exs`; do not edit by hand.

    - Proposal: `WG2 N5028 / L2/19-025`
    - Proposal SHA-256: `#{@proposal_sha256}`
    - Mapping aggregate SHA-256: `#{@mapping_aggregate}`
    - Complete embedded mapping attachments: **#{length(entries)}/#{length(entries)}**

    | Encoding | Aliases | Attachment | Decode mappings | Encode mappings |
    |---|---|---|---:|---:|
    #{rows}
    """

    File.write!(Path.join(root, "LEGACY_COMPUTING_N5028.md"), document)
  end

  defp import_mapping(path, index, source_dir, table_dir) do
    filename = Path.basename(path)
    basename = Path.rootname(filename)
    content = File.read!(path)
    File.write!(Path.join(source_dir, filename), content)
    mappings = parse(content)
    table = build_table(mappings)
    id = String.to_atom("n5028_#{String.downcase(basename, :ascii)}")

    File.write!(
      Path.join(table_dir, "#{id}.etf"),
      :erlang.term_to_binary(table, [:deterministic])
    )

    canonical = Map.fetch!(@canonical_names, basename)

    aliases =
      [basename | Map.get(@special_aliases, basename, [])]
      |> Enum.reject(&(&1 == canonical))
      |> Enum.uniq()

    %{
      aliases: aliases,
      decode_mappings: length(mappings),
      encode_mappings: map_size(table.encode),
      id: id,
      index: index,
      name: canonical,
      source_file: filename
    }
  end

  defp parse(content) do
    content
    |> String.split("\n")
    |> Enum.flat_map(fn line ->
      case Regex.run(
             ~r/^0x([0-9A-Fa-f]+)\s+((?:0x[0-9A-Fa-f]+)(?:\+0x[0-9A-Fa-f]+)*)/,
             line
           ) do
        [_, encoded, unicode] ->
          encoded = if rem(byte_size(encoded), 2) == 0, do: encoded, else: "0" <> encoded

          codepoints =
            unicode
            |> String.split("+")
            |> Enum.map(fn "0x" <> hex -> String.to_integer(hex, 16) end)
            |> List.to_tuple()

          [{Base.decode16!(encoded, case: :mixed), codepoints}]

        nil ->
          []
      end
    end)
  end

  defp build_table(mappings) do
    {one, many, encode} =
      Enum.reduce(mappings, {%{}, %{}, %{}}, fn {bytes, codepoints}, {one, many, encode} ->
        {one, many} =
          if byte_size(bytes) == 1,
            do: {Map.put_new(one, :binary.first(bytes), codepoints), many},
            else: {one, Map.put_new(many, bytes, codepoints)}

        {one, many, Map.put_new(encode, codepoints, bytes)}
      end)

    prefixes =
      Enum.reduce(many, MapSet.new(), fn {bytes, _codepoints}, acc ->
        Enum.reduce(1..(byte_size(bytes) - 1), acc, fn size, inner ->
          MapSet.put(inner, binary_part(bytes, 0, size))
        end)
      end)

    %{
      encode: encode,
      many: many,
      max_codepoints: encode |> Map.keys() |> Enum.map(&tuple_size/1) |> Enum.max(),
      max_input: mappings |> Enum.map(fn {bytes, _} -> byte_size(bytes) end) |> Enum.max(),
      one: 0..255 |> Enum.map(&Map.get(one, &1)) |> List.to_tuple(),
      prefixes: prefixes
    }
  end

  defp proposal_path(root) do
    case System.get_env("N5028_PDF") do
      nil ->
        path = Path.join([root, "tmp", "pdfs", "n5028-sources", "n5028-19025-terminals-prop.pdf"])

        unless File.regular?(path) do
          case System.cmd("curl", ["-fsSL", @proposal_url], stderr_to_stdout: true) do
            {content, 0} -> File.write!(path, content)
            {message, status} -> raise("N5028 download failed (#{status}): #{message}")
          end
        end

        path

      path ->
        path
    end
  end

  defp attachment_directory(root, proposal) do
    case System.get_env("N5028_ATTACHMENT_DIR") do
      nil ->
        output = Path.join([root, "tmp", "n5028-extracted"])
        File.rm_rf!(output)
        File.mkdir_p!(output)
        executable = System.get_env("PDFDETACH") || "pdfdetach"

        case System.cmd(executable, ["-saveall", "-o", output, proposal], stderr_to_stdout: true) do
          {_message, 0} -> output
          {message, status} -> raise("pdfdetach failed (#{status}): #{message}")
        end

      path ->
        path
    end
  end

  defp assert_aggregate!(paths) do
    context =
      Enum.reduce(paths, :crypto.hash_init(:sha256), fn path, acc ->
        acc
        |> :crypto.hash_update(Path.basename(path))
        |> :crypto.hash_update(<<0>>)
        |> :crypto.hash_update(File.read!(path))
      end)

    actual = context |> :crypto.hash_final() |> Base.encode16(case: :lower)
    unless actual == @mapping_aggregate, do: raise("mapping aggregate mismatch: #{actual}")
  end

  defp assert_hash!(path, expected, label) do
    actual = path |> File.read!() |> sha256()
    unless actual == expected, do: raise("#{label} SHA-256 mismatch: #{actual}")
  end

  defp sha256(content), do: :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)
end

Iconvex.Specs.Tools.ImportLegacyComputingN5028.run()
